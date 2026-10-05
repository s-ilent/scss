using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace SilentCelShading.Unity.BulkEditor
{
    public static class SCSS_BulkEditorScanner
    {
        /// <summary>
        /// Scans the provided GameObjects and returns a grouped list of SCSS Material Entries.
        /// </summary>
        public static List<SCSSMaterialEntry> CollectMaterials(GameObject[] selection, bool includeInactive, bool includeHidden)
        {
            var usages = new List<SCSSMaterialUsage>();

            if (selection == null || selection.Length == 0)
                return new List<SCSSMaterialEntry>();

            foreach (var root in selection)
            {
                if (root == null) continue;

                var renderers = root.GetComponentsInChildren<Renderer>(includeInactive);
                foreach (var renderer in renderers)
                {
                    if (renderer == null) continue;

                    // Respect Scene Visibility (the eye icon in the hierarchy)
                    if (!includeHidden && SceneVisibilityManager.instance.IsHidden(renderer.gameObject))
                        continue;

                    var sharedMaterials = renderer.sharedMaterials;
                    for (int i = 0; i < sharedMaterials.Length; i++)
                    {
                        var material = sharedMaterials[i];
                        if (!IsValidSCSSMaterial(material)) continue;

                        string path = BuildRendererPath(root.transform, renderer.transform);
                        usages.Add(new SCSSMaterialUsage(material, renderer, i, path));
                    }
                }
            }

            // Group usages by Material
            var grouped = new Dictionary<Material, SCSSMaterialEntry>();
            foreach (var usage in usages)
            {
                if (!grouped.TryGetValue(usage.Material, out var entry))
                {
                    entry = new SCSSMaterialEntry(usage.Material);
                    entry.IsBaked = usage.Material.HasProperty("__Baked") && usage.Material.GetFloat("__Baked") == 1f;
                    grouped[usage.Material] = entry;
                }
                entry.Usages.Add(usage);
            }

            // Return sorted alphabetically by Material name
            return grouped.Values.OrderBy(e => e.DisplayName, StringComparer.OrdinalIgnoreCase).ToList();
        }

        private static bool IsValidSCSSMaterial(Material material)
        {
            if (material == null || material.shader == null) return false;

            string shaderName = material.shader.name;
            // Check if it's one of the SCSS shaders (handles both standard, Crosstone, and baked Hidden variants)
            return shaderName.Contains("Silent's Cel Shading") &&
                   (shaderName.Contains("Crosstone") || shaderName.Contains("Lightramp"));
        }

        private static string BuildRendererPath(Transform root, Transform target)
        {
            if (target == null) return string.Empty;
            if (root == target) return target.name;

            var path = target.name;
            var parent = target.parent;
            while (parent != null && parent != root.parent)
            {
                path = parent.name + "/" + path;
                parent = parent.parent;
            }
            return path;
        }
    }
}
