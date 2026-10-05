using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using Object = UnityEngine.Object;

namespace SilentCelShading.Unity.BulkEditor
{
    public class SCSS_BulkEditorHost : IDisposable
    {
        public Material WorkingMaterial { get; private set; }
        public Material BaselineMaterial { get; private set; }

        private MaterialEditor materialEditor;
        private Inspector inspectorInstance;

        private Dictionary<string, SCSSPropertySnapshot> baselineSnapshots = new Dictionary<string, SCSSPropertySnapshot>();
        private HashSet<string> includedProperties = new HashSet<string>();

        public bool IsValid => WorkingMaterial != null && materialEditor != null;

        public SCSS_BulkEditorHost(Material sourceMaterial)
        {
            if (sourceMaterial == null) return;

            WorkingMaterial = new Material(sourceMaterial) { hideFlags = HideFlags.HideAndDontSave, name = "Bulk Edit Working" };
            BaselineMaterial = new Material(sourceMaterial) { hideFlags = HideFlags.HideAndDontSave, name = "Bulk Edit Baseline" };

            materialEditor = (MaterialEditor)Editor.CreateEditor(WorkingMaterial);
            inspectorInstance = new Inspector();

            CaptureBaseline();
        }

        public void DrawGUI()
        {
            if (!IsValid) return;
            var props = MaterialEditor.GetMaterialProperties(new Object[] { WorkingMaterial });

            SCSS_BulkEditorContext.IsActive = true;
            SCSS_BulkEditorContext.CurrentHost = this;

            EditorGUI.BeginChangeCheck();

            EditorGUI.indentLevel++; // <--- Pushes ALL properties right
            inspectorInstance.OnGUI(materialEditor, props);
            EditorGUI.indentLevel--; // <--- Restores it

            if (EditorGUI.EndChangeCheck())
            {
                UpdateChangedProperties(props);
            }

            SCSS_BulkEditorContext.IsActive = false;
            SCSS_BulkEditorContext.CurrentHost = null;
        }

        private void CaptureBaseline()
        {
            var props = MaterialEditor.GetMaterialProperties(new Object[] { BaselineMaterial });
            baselineSnapshots.Clear();
            foreach (var prop in props)
            {
                baselineSnapshots[prop.name] = new SCSSPropertySnapshot(prop);
            }
        }

        public List<SCSSPropertySnapshot> GetChangedSnapshots()
        {
            var changed = new List<SCSSPropertySnapshot>();
            var currentProps = MaterialEditor.GetMaterialProperties(new Object[] { WorkingMaterial });

            foreach (var prop in currentProps)
            {
                if (baselineSnapshots.TryGetValue(prop.name, out var baseline))
                {
                    var current = new SCSSPropertySnapshot(prop);
                    if (!baseline.Equals(current))
                    {
                        changed.Add(current);
                    }
                }
            }
            return changed;
        }

        public List<SCSSPropertySnapshot> GetSnapshotsToApply()
        {
            var snapshots = new List<SCSSPropertySnapshot>();
            var props = MaterialEditor.GetMaterialProperties(new Object[] { WorkingMaterial });

            foreach (var prop in props)
            {
                if (includedProperties.Contains(prop.name))
                {
                    snapshots.Add(new SCSSPropertySnapshot(prop));
                }
            }
            return snapshots;
        }

        private void UpdateChangedProperties(MaterialProperty[] currentProps)
        {
            foreach (var prop in currentProps)
            {
                var currentSnapshot = new SCSSPropertySnapshot(prop);
                if (baselineSnapshots.TryGetValue(prop.name, out var baseline))
                {
                    if (!baseline.Equals(currentSnapshot))
                    {
                        // Auto-include property if it was changed
                        includedProperties.Add(prop.name);
                    }
                }
            }
        }

        public bool IsPropertyIncluded(string name) => includedProperties.Contains(name);

        public void SetPropertyIncluded(string name, bool include)
        {
            if (include) includedProperties.Add(name);
            else includedProperties.Remove(name);
        }

        public void Dispose()
        {
            if (materialEditor != null) Object.DestroyImmediate(materialEditor);
            if (WorkingMaterial != null) Object.DestroyImmediate(WorkingMaterial);
            if (BaselineMaterial != null) Object.DestroyImmediate(BaselineMaterial);
        }
    }
}
