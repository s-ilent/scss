using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace SilentCelShading.Unity.BulkEditor
{
    public static class SCSS_BulkEditorContext
    {
        public static bool IsActive { get; set; }
        public static SCSS_BulkEditorHost CurrentHost { get; set; }
    }

    /// <summary>
    /// Stores the state of a property so we can calculate diffs.
    /// </summary>
    public class SCSSPropertySnapshot
    {
        public string Name { get; }
        public MaterialProperty.PropType Type { get; }
        public float FloatValue { get; }
        public Vector4 VectorValue { get; }
        public Color ColorValue { get; }
        public Texture TextureValue { get; }
        public Vector2 TextureScale { get; }
        public Vector2 TextureOffset { get; }

        public SCSSPropertySnapshot(MaterialProperty prop)
        {
            Name = prop.name;
            Type = prop.type;

            switch (Type)
            {
                case MaterialProperty.PropType.Color: ColorValue = prop.colorValue; break;
                case MaterialProperty.PropType.Vector: VectorValue = prop.vectorValue; break;
                case MaterialProperty.PropType.Float:
                case MaterialProperty.PropType.Range: FloatValue = prop.floatValue; break;
                case MaterialProperty.PropType.Texture:
                    TextureValue = prop.textureValue;
                    var st = prop.textureScaleAndOffset;
                    TextureScale = new Vector2(st.x, st.y);
                    TextureOffset = new Vector2(st.z, st.w);
                    break;
            }
        }

        public bool Equals(SCSSPropertySnapshot other)
        {
            if (other == null || Type != other.Type) return false;
            switch (Type)
            {
                case MaterialProperty.PropType.Color: return ColorValue == other.ColorValue;
                case MaterialProperty.PropType.Vector: return VectorValue == other.VectorValue;
                case MaterialProperty.PropType.Float:
                case MaterialProperty.PropType.Range: return Mathf.Approximately(FloatValue, other.FloatValue);
                case MaterialProperty.PropType.Texture: return TextureValue == other.TextureValue && TextureScale == other.TextureScale && TextureOffset == other.TextureOffset;
                default: return false;
            }
        }

        public void ApplyTo(Material material)
        {
            if (material == null || !material.HasProperty(Name)) return;

            switch (Type)
            {
                case MaterialProperty.PropType.Color: material.SetColor(Name, ColorValue); break;
                case MaterialProperty.PropType.Vector: material.SetVector(Name, VectorValue); break;
                case MaterialProperty.PropType.Float:
                case MaterialProperty.PropType.Range: material.SetFloat(Name, FloatValue); break;
                case MaterialProperty.PropType.Texture:
                    material.SetTexture(Name, TextureValue);
                    material.SetTextureScale(Name, TextureScale);
                    material.SetTextureOffset(Name, TextureOffset);
                    break;
            }
        }
    }
}
