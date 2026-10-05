using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace SilentCelShading.Unity.BulkEditor
{
    public enum ApplyOperationType { DirectApply, DuplicateApply }

    public class SCSSBulkOperationHistory
    {
        public ApplyOperationType Type { get; }
        public List<MaterialBackup> Backups { get; } = new List<MaterialBackup>();
        public List<RendererSlotRestore> Restores { get; } = new List<RendererSlotRestore>();
        public List<string> CreatedAssetPaths { get; } = new List<string>();

        public SCSSBulkOperationHistory(ApplyOperationType type) { Type = type; }
    }

    public class MaterialBackup
    {
        public Material TargetMaterial { get; }
        public Material BackupMaterial { get; }

        public MaterialBackup(Material targetMaterial)
        {
            TargetMaterial = targetMaterial;
            BackupMaterial = new Material(targetMaterial) { hideFlags = HideFlags.HideAndDontSave };
        }

        public void Restore()
        {
            if (TargetMaterial != null && BackupMaterial != null)
            {
                TargetMaterial.CopyPropertiesFromMaterial(BackupMaterial);
                TargetMaterial.shaderKeywords = BackupMaterial.shaderKeywords;
            }
        }
    }

    public class RendererSlotRestore
    {
        public Renderer Renderer { get; }
        public int SlotIndex { get; }
        public Material OriginalMaterial { get; }

        public RendererSlotRestore(Renderer renderer, int slotIndex, Material originalMaterial)
        {
            Renderer = renderer;
            SlotIndex = slotIndex;
            OriginalMaterial = originalMaterial;
        }

        public void Restore()
        {
            if (Renderer == null) return;
            var mats = Renderer.sharedMaterials;
            if (SlotIndex >= 0 && SlotIndex < mats.Length)
            {
                mats[SlotIndex] = OriginalMaterial;
                Renderer.sharedMaterials = mats;
                EditorUtility.SetDirty(Renderer);
            }
        }
    }

    public static class SCSS_BulkEditorOperations
    {
        private static Stack<SCSSBulkOperationHistory> historyStack = new Stack<SCSSBulkOperationHistory>();

        public static bool CanRevert => historyStack.Count > 0;

        public static void ApplyDirect(List<SCSSMaterialEntry> selectedEntries, List<SCSSPropertySnapshot> snapshots)
        {
            if (selectedEntries.Count == 0 || snapshots.Count == 0) return;

            var history = new SCSSBulkOperationHistory(ApplyOperationType.DirectApply);

            // Gather unique materials
            var targetMaterials = new HashSet<Material>();
            foreach (var entry in selectedEntries)
                if (entry.IsSelected && entry.Material != null)
                    targetMaterials.Add(entry.Material);

            // Record Undo and Backup
            Undo.RecordObjects(new List<Material>(targetMaterials).ToArray(), "SCSS Bulk Apply");
            foreach (var mat in targetMaterials)
            {
                history.Backups.Add(new MaterialBackup(mat));

                // Apply Snapshots
                foreach (var snapshot in snapshots)
                {
                    snapshot.ApplyTo(mat);
                }
                Inspector.ValidateMaterial(mat);
                EditorUtility.SetDirty(mat);
            }

            historyStack.Push(history);
            AssetDatabase.SaveAssets();
        }

        public static void DuplicateAndApply(List<SCSSMaterialEntry> selectedEntries, List<SCSSPropertySnapshot> snapshots)
        {
            if (selectedEntries.Count == 0 || snapshots.Count == 0) return;

            EnsureOutputFolder("Assets/SCSS Edited Materials");
            var history = new SCSSBulkOperationHistory(ApplyOperationType.DuplicateApply);

            foreach (var entry in selectedEntries)
            {
                if (!entry.IsSelected || entry.Material == null) continue;

                // Create duplicated material
                string uniquePath = AssetDatabase.GenerateUniqueAssetPath($"Assets/SCSS Edited Materials/{entry.Material.name}_Edited.mat");
                Material duplicatedMat = new Material(entry.Material) { name = Path.GetFileNameWithoutExtension(uniquePath) };

                // Apply properties to the clone
                foreach (var snapshot in snapshots)
                {
                    snapshot.ApplyTo(duplicatedMat);
                }

                AssetDatabase.CreateAsset(duplicatedMat, uniquePath);
                history.CreatedAssetPaths.Add(uniquePath);

                // Reassign on renderers
                foreach (var usage in entry.Usages)
                {
                    if (usage.Renderer == null) continue;

                    history.Restores.Add(new RendererSlotRestore(usage.Renderer, usage.SlotIndex, entry.Material));
                    Undo.RecordObject(usage.Renderer, "SCSS Duplicate & Apply");

                    var mats = usage.Renderer.sharedMaterials;
                    mats[usage.SlotIndex] = duplicatedMat;
                    usage.Renderer.sharedMaterials = mats;

                    EditorUtility.SetDirty(usage.Renderer);
                }
            }

            historyStack.Push(history);
            AssetDatabase.SaveAssets();
        }

        public static void RevertLast()
        {
            if (historyStack.Count == 0) return;

            var history = historyStack.Pop();

            if (history.Type == ApplyOperationType.DirectApply)
            {
                var mats = new List<Material>();
                foreach (var backup in history.Backups) mats.Add(backup.TargetMaterial);

                Undo.RecordObjects(mats.ToArray(), "SCSS Revert Bulk Apply");
                foreach (var backup in history.Backups) backup.Restore();
            }
            else if (history.Type == ApplyOperationType.DuplicateApply)
            {
                var renderers = new HashSet<Renderer>();
                foreach (var restore in history.Restores) renderers.Add(restore.Renderer);

                Undo.RecordObjects(new List<Renderer>(renderers).ToArray(), "SCSS Revert Duplicate");
                foreach (var restore in history.Restores) restore.Restore();

                // Delete generated assets
                foreach (var path in history.CreatedAssetPaths)
                {
                    AssetDatabase.DeleteAsset(path);
                }
            }

            AssetDatabase.SaveAssets();
        }

        private static void EnsureOutputFolder(string path)
        {
            if (!AssetDatabase.IsValidFolder(path))
            {
                string parent = Path.GetDirectoryName(path).Replace("\\", "/");
                string folder = Path.GetFileName(path);
                if (!AssetDatabase.IsValidFolder(parent)) EnsureOutputFolder(parent);
                AssetDatabase.CreateFolder(parent, folder);
            }
        }
    }
}