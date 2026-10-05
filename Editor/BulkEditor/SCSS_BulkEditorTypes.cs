using System.Collections.Generic;
using UnityEngine;

namespace SilentCelShading.Unity.BulkEditor
{
    /// <summary>
    /// Represents a single instance of a material assigned to a specific slot on a Renderer.
    /// </summary>
    public class SCSSMaterialUsage
    {
        public Material Material { get; }
        public Renderer Renderer { get; }
        public int SlotIndex { get; }
        public string DisplayPath { get; }

        public SCSSMaterialUsage(Material material, Renderer renderer, int slotIndex, string displayPath)
        {
            Material = material;
            Renderer = renderer;
            SlotIndex = slotIndex;
            DisplayPath = displayPath;
        }
    }

    /// <summary>
    /// Groups all usages of a specific Material together for the Left Pane UI.
    /// </summary>
    public class SCSSMaterialEntry
    {
        public Material Material { get; }
        public bool IsSelected { get; set; } = true;
        public bool IsExpanded { get; set; } = false; // For the foldout UI
        public bool IsBaked { get; set; } = false;
        public List<SCSSMaterialUsage> Usages { get; } = new List<SCSSMaterialUsage>();

        public SCSSMaterialEntry(Material material)
        {
            Material = material;
        }

        public string DisplayName => Material != null ? Material.name : "(Missing Material)";
    }
}
