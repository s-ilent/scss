using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using UnityEngine.Rendering;
using static SilentCelShading.Unity.InspectorCommon;

namespace SilentCelShading.Unity
{
    public partial class Inspector
    {
        /// <summary>
        /// Interface for mapping properties from a source shader to SCSS during a shader swap.
        /// </summary>
        internal interface IPropertyConverter
        {
            bool IsMatch(Shader oldShader);
            void ConvertProperties(
                Material material, Shader oldShader, Shader newShader,
                Dictionary<string, Color?> tColor,
                Dictionary<string, float?> tFloat,
                Dictionary<string, Texture> tTexture,
                ref int? stencilReference,
                ref int? stencilComparison,
                ref int? stencilOperation,
                ref int? stencilFail);
        }

        /// <summary>
        /// Handles properties when swapping between different versions or variants of SCSS.
        /// </summary>
        internal class SCSSPropertyConverter : IPropertyConverter
        {
            public bool IsMatch(Shader oldShader) => oldShader != null && oldShader.name.Contains("Silent's Cel Shading");

            public void ConvertProperties(Material material, Shader oldShader, Shader newShader, Dictionary<string, Color?> tColor, Dictionary<string, float?> tFloat, Dictionary<string, Texture> tTexture, ref int? stencilReference, ref int? stencilComparison, ref int? stencilOperation, ref int? stencilFail)
            {
                // Toggle outline mode when switching between Outline and No-Outline shader variants
                if (oldShader.name.Contains("Outline") && !newShader.name.Contains("Outline"))
                {
                    tFloat["_OutlineMode"] = 0.0f;
                }
                if (!oldShader.name.Contains("Outline") && newShader.name.Contains("Outline"))
                {
                    tFloat["_OutlineMode"] = 1.0f;
                }

                // Map old shader paths to current rendering modes
                if (oldShader.name.Contains(SCSSShaderGUI.TransparentCutoutShadersPath))
                {
                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Cutout;
                    tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Cutout;
                }
                else if (oldShader.name.Contains(SCSSShaderGUI.TransparentShadersPath))
                {
                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Fade;
                    tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Fade;
                }
            }
        }

        /// <summary>
        /// Handles property mapping from UnityChanToonShader (UTS2) to SCSS.
        /// </summary>
        internal class UTSPropertyConverter : IPropertyConverter
        {
            public bool IsMatch(Shader oldShader) => oldShader != null && (oldShader.name.Contains("UnityChanToonShader") || oldShader.name.Contains("Toon (Built-in)"));

            public void ConvertProperties(Material material, Shader oldShader, Shader newShader, Dictionary<string, Color?> tColor, Dictionary<string, float?> tFloat, Dictionary<string, Texture> tTexture, ref int? stencilReference, ref int? stencilComparison, ref int? stencilOperation, ref int? stencilFail)
            {
                tTexture["_BumpMap"] = SCSSShaderGUI.GetTextureProperty(material, "_NormalMap");

                if (SCSSShaderGUI.GetFloatProperty(material, "_Inverse_Clipping") == 1) Debug.Log("Note: Inverse clipping currently not supported.");
                if (SCSSShaderGUI.GetTextureProperty(material, "_ClippingMask")) tFloat["_AlbedoAlphaMode"] = (float)AlbedoAlphaMode.ClippingMask;
                tFloat["_Tweak_Transparency"] = SCSSShaderGUI.GetFloatProperty(material, "_Tweak_transparency");
                tFloat["_Cutoff"] = 1.0f - SCSSShaderGUI.GetFloatProperty(material, "_Clipping_Level") ?? 0;

                // Map tone separation based on the UTS2 base/1st/2nd shade logic
                tFloat["_CrosstoneToneSeparation"] = 1.0f - SCSSShaderGUI.GetFloatProperty(material, "_Use_BaseAs1st") ?? 0;
                tFloat["_Crosstone2ndSeparation"] = 1.0f - SCSSShaderGUI.GetFloatProperty(material, "_Use_1stAs2nd") ?? 0;

                if (oldShader.name.Contains("DoubleShadeWithFeather"))
                {
                    tFloat["_1st_ShadeColor_Step"] = SCSSShaderGUI.GetFloatProperty(material, "_BaseColor_Step");
                    tFloat["_1st_ShadeColor_Feather"] = SCSSShaderGUI.GetFloatProperty(material, "_BaseShade_Feather");
                    tFloat["_2nd_ShadeColor_Step"] = SCSSShaderGUI.GetFloatProperty(material, "_ShadeColor_Step");
                    tFloat["_2nd_ShadeColor_Feather"] = SCSSShaderGUI.GetFloatProperty(material, "_1st2nd_Shades_Feather");
                }

                tTexture["_EmissionMap"] = SCSSShaderGUI.GetTextureProperty(material, "_Emissive_Tex");
                tColor["_EmissionColor"] = SCSSShaderGUI.GetColorProperty(material, "_Emissive_Color");

                // Map HighColor/Specular mask to SCSS Specular Map or Detail Map 3
                Texture highColorTex = SCSSShaderGUI.GetTextureProperty(material, "_HighColor_Tex");
                Texture highColorMask = SCSSShaderGUI.GetTextureProperty(material, "_Set_HighColorMask");
                if (highColorTex)
                {
                    tTexture["_SpecGlossMap"] = highColorTex;
                    tTexture["_DetailMap3"] = highColorMask;
                    tFloat["_DetailMap3Type"] = 2.0f; // Specular type
                    tFloat["_DetailMap3Blend"] = 0.0f; // Default (Multiply2x)
                    tFloat["_DetailMap3Strength"] = 1.0f;
                }
                else
                {
                    tTexture["_SpecGlossMap"] = highColorMask;
                }

                tFloat["_SpecularType"] = (float)SpecularType.Cel * SCSSShaderGUI.GetFloatProperty(material, "_Is_SpecularToHighColor") ?? 0;
                tColor["_SpecColor"] = new Vector4(1, 1, 1, 0.1f) * SCSSShaderGUI.GetColorProperty(material, "_HighColor") ?? (Color.white);
                float? smoothness = SCSSShaderGUI.GetFloatProperty(material, "_HighColor_Power");
                if (smoothness.HasValue) tFloat["_Smoothness"] = 1.0f - smoothness;
                tFloat["_CelSpecularSoftness"] = SCSSShaderGUI.GetFloatProperty(material, "_Is_SpecularToHighColor");

                // Rim lighting mapping
                tFloat["_UseFresnel"] = (float)AmbientFresnelType.Lit * SCSSShaderGUI.GetFloatProperty(material, "_RimLight") ?? 0;
                tColor["_RimColor"] = SCSSShaderGUI.GetColorProperty(material, "_RimLightColor");
                tFloat["_FresnelWidth"] = SCSSShaderGUI.GetFloatProperty(material, "_RimLight_Power") ?? 0 * 10;
                tFloat["_FresnelStrength"] = 1.0f - SCSSShaderGUI.GetFloatProperty(material, "_RimLight_FeatherOff") ?? 0;

                tFloat["_UseFresnelLightMask"] = SCSSShaderGUI.GetFloatProperty(material, "_LightDirection_MaskOn");
                tFloat["_FresnelLightMask"] = 1.0f + SCSSShaderGUI.GetFloatProperty(material, "_Tweak_LightDirection_MaskLevel") ?? 0;
                tColor["_FresnelTintInv"] = SCSSShaderGUI.GetColorProperty(material, "_Ap_RimLightColor");
                tFloat["_FresnelWidthInv"] = 10 * SCSSShaderGUI.GetFloatProperty(material, "_Ap_RimLight_Power") ?? 10 * 0;
                tFloat["_FresnelStrengthInv"] = 1.0f - SCSSShaderGUI.GetFloatProperty(material, "_Ap_RimLight_FeatherOff") ?? 0;

                // Matcap mapping
                tFloat["_UseMatcap"] = SCSSShaderGUI.GetFloatProperty(material, "_MatCap");
                tTexture["_Matcap1"] = SCSSShaderGUI.GetTextureProperty(material, "_MatCap_Sampler");
                tTexture["_MatcapMask"] = SCSSShaderGUI.GetTextureProperty(material, "_Set_MatcapMask");
                tColor["_Matcap1Tint"] = SCSSShaderGUI.GetColorProperty(material, "_MatCapColor");
                tFloat["_Matcap1Blend"] = 1.0f - SCSSShaderGUI.GetFloatProperty(material, "_Is_BlendAddToMatCap") ?? 0;
                tFloat["_Matcap1Strength"] = 1.0f - SCSSShaderGUI.GetFloatProperty(material, "_Tweak_MatcapMaskLevel") ?? 0;

                // Outline mapping
                tFloat["_OutlineMode"] = oldShader.name.Contains("NoOutline") ? 0.0f : 1.0f;
                tColor["_outline_color"] = SCSSShaderGUI.GetColorProperty(material, "_Outline_Color");
                tFloat["_outline_width"] = 0.1f * SCSSShaderGUI.GetFloatProperty(material, "_Outline_Width") ?? 1.0f;
                tFloat["_OutlineZPush"] = SCSSShaderGUI.GetFloatProperty(material, "_Offset_Z");
                tTexture["_OutlineMask"] = SCSSShaderGUI.GetTextureProperty(material, "_Outline_Sampler");

                // Stencil mapping
                if (oldShader.name.Contains("StencilMask"))
                {
                    stencilReference = (int)SCSSShaderGUI.GetIntProperty(material, "_StencilNo") % 256;
                    stencilComparison = (int)CompareFunction.Always;
                    stencilOperation = (int)StencilOp.Replace;
                    stencilFail = (int)StencilOp.Replace;
                }
                if (oldShader.name.Contains("StencilOut"))
                {
                    stencilReference = (int)SCSSShaderGUI.GetIntProperty(material, "_StencilNo") % 256;
                    stencilComparison = (int)CompareFunction.NotEqual;
                    stencilOperation = (int)StencilOp.Keep;
                    stencilFail = (int)StencilOp.Keep;
                }

                // Rendering mode mapping based on UTS2 naming
                if (oldShader.name.Contains("Clipping") || oldShader.name.Contains("TransClipping"))
                {
                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Cutout;
                    tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Cutout;
                }
                if (oldShader.name.Contains("Transparent"))
                {
                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Fade;
                    tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Fade;
                }
            }
        }

        /// <summary>
        /// Handles property mapping from lilToon to SCSS.
        /// </summary>
        internal class LilToonPropertyConverter : IPropertyConverter
        {
            public bool IsMatch(Shader oldShader) => oldShader != null && oldShader.name.Contains("lilToon");

            public void ConvertProperties(Material material, Shader oldShader, Shader newShader, Dictionary<string, Color?> tColor, Dictionary<string, float?> tFloat, Dictionary<string, Texture> tTexture, ref int? stencilReference, ref int? stencilComparison, ref int? stencilOperation, ref int? stencilFail)
            {
                // Rendering mode mapping
                if (oldShader.name.Contains("Cutout"))
                {
                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Cutout;
                    tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Cutout;
                    tTexture["_ClippingMask"] = SCSSShaderGUI.GetTextureProperty(material, "_AlphaMask");
                }
                if (oldShader.name.Contains("Transparent"))
                {
                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Fade;
                    tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Fade;
                }
                tFloat["_OutlineMode"] = oldShader.name.Contains("Outline") ? 1.0f : 0.0f;

                // Shade/Shadow properties
                tColor["_1st_ShadeColor"] = SCSSShaderGUI.GetColorProperty(material, "_ShadowColor");
                tTexture["_1st_ShadeMap"] = SCSSShaderGUI.GetTextureProperty(material, "_ShadowColorTex");
                tFloat["_1st_ShadeColor_Step"] = SCSSShaderGUI.GetFloatProperty(material, "_ShadowBorder");
                tFloat["_1st_ShadeColor_Feather"] = 2.0f * SCSSShaderGUI.GetFloatProperty(material, "_ShadowBlur") ?? 0;

                tColor["_2nd_ShadeColor"] = SCSSShaderGUI.GetColorProperty(material, "_Shadow2ndColor");
                tTexture["_2nd_ShadeMap"] = SCSSShaderGUI.GetTextureProperty(material, "_ShadowColorTex");
                tFloat["_2nd_ShadeColor_Step"] = SCSSShaderGUI.GetFloatProperty(material, "_Shadow2ndBorder");
                tFloat["_2nd_ShadeColor_Feather"] = 2.0f * SCSSShaderGUI.GetFloatProperty(material, "_Shadow2ndBlur") ?? 0;

                tFloat["_UseMatcap"] = SCSSShaderGUI.GetFloatProperty(material, "_UseMatCap");
                
                // Map lilToon matcap alpha to SCSS intensity instead of tint alpha
                float matcap1Strength = SCSSShaderGUI.GetFloatProperty(material, "_MatCapBlend") ?? 1.0f;
                Color? matcap1Color = SCSSShaderGUI.GetColorProperty(material, "_MatCapColor");
                if (matcap1Color.HasValue)
                {
                    tColor["_Matcap1Tint"] = new Color(matcap1Color.Value.r, matcap1Color.Value.g, matcap1Color.Value.b, 1.0f);
                    matcap1Strength *= matcap1Color.Value.a;
                }
                tFloat["_Matcap1Strength"] = matcap1Strength;

                tTexture["_Matcap1"] = SCSSShaderGUI.GetTextureProperty(material, "_MatCapTex");
                tTexture["_MatcapMask"] = SCSSShaderGUI.GetTextureProperty(material, "_MatCapBlendMask");

                float? matcapType = SCSSShaderGUI.GetFloatProperty(material, "_MatCapBlendMode");
                if (matcapType.HasValue)
                {
                    switch (matcapType.Value)
                    {
                        case 0f: tFloat["_Matcap1Blend"] = (float)MatcapBlendModes.Additive; break;
                        case 1f: tFloat["_Matcap1Blend"] = (float)MatcapBlendModes.Additive; break;
                        case 2f: tFloat["_Matcap1Blend"] = (float)MatcapBlendModes.Median; break;
                        case 3f: tFloat["_Matcap1Blend"] = (float)MatcapBlendModes.Multiply; break;
                    }
                }

                // Secondary Matcap support
                if (SCSSShaderGUI.GetFloatProperty(material, "_UseMatCap2nd") == 1)
                {
                    tFloat["_UseMatcap"] = 1.0f;
                    tTexture["_Matcap2"] = SCSSShaderGUI.GetTextureProperty(material, "_MatCap2ndTex");
                    
                    float matcap2Strength = SCSSShaderGUI.GetFloatProperty(material, "_MatCap2ndBlend") ?? 1.0f;
                    Color? matcap2Color = SCSSShaderGUI.GetColorProperty(material, "_MatCap2ndColor");
                    if (matcap2Color.HasValue)
                    {
                        tColor["_Matcap2Tint"] = new Color(matcap2Color.Value.r, matcap2Color.Value.g, matcap2Color.Value.b, 1.0f);
                        matcap2Strength *= matcap2Color.Value.a;
                    }
                    tFloat["_Matcap2Strength"] = matcap2Strength;

                    float? matcap2ndType = SCSSShaderGUI.GetFloatProperty(material, "_MatCap2ndBlendMode");
                    if (matcap2ndType.HasValue)
                    {
                        switch (matcap2ndType.Value)
                        {
                            case 0f: tFloat["_Matcap2Blend"] = (float)MatcapBlendModes.Additive; break;
                            case 1f: tFloat["_Matcap2Blend"] = (float)MatcapBlendModes.Additive; break;
                            case 2f: tFloat["_Matcap2Blend"] = (float)MatcapBlendModes.Median; break;
                            case 3f: tFloat["_Matcap2Blend"] = (float)MatcapBlendModes.Multiply; break;
                        }
                    }
                }

                // Rim light mapping
                tFloat["_UseFresnel"] = (float)AmbientFresnelType.Lit * SCSSShaderGUI.GetFloatProperty(material, "_UseRim") ?? 0;
                tColor["_RimColor"] = SCSSShaderGUI.GetColorProperty(material, "_RimColor");
                tFloat["_FresnelWidth"] = SCSSShaderGUI.GetFloatProperty(material, "_RimBorder");
                tFloat["_FresnelStrength"] = 1.0f - SCSSShaderGUI.GetFloatProperty(material, "_RimBlur") ?? 0;

                // Outline mapping
                tColor["_outline_color"] = SCSSShaderGUI.GetColorProperty(material, "_OutlineColor");
                tFloat["_outline_width"] = SCSSShaderGUI.GetFloatProperty(material, "_OutlineWidth");
                tTexture["_OutlineMask"] = SCSSShaderGUI.GetTextureProperty(material, "_OutlineWidthMask");

                tColor["_EmissionColor"] = SCSSShaderGUI.GetColorProperty(material, "_EmissionColor") * (SCSSShaderGUI.GetFloatProperty(material, "_UseEmission") ?? 1.0f);

                // Base material property mapping
                tFloat["_Cutoff"] = SCSSShaderGUI.GetFloatProperty(material, "_Cutoff");
                tFloat["_Cull"] = SCSSShaderGUI.GetFloatProperty(material, "_Cull");

                // Detail map mappings (lilToon 2nd/3rd textures mapped to SCSS Detail Map 1/2)
                tTexture["_DetailMap1"] = SCSSShaderGUI.GetTextureProperty(material, "_Main2ndTex");
                tColor["_DetailMap1Color"] = SCSSShaderGUI.GetColorProperty(material, "_Color2nd");
                tFloat["_DetailMap1Type"] = 0.0f; // Albedo type
                
                // Map lilToon detail blend modes to SCSS equivalents
                float? detail1BlendMode = SCSSShaderGUI.GetFloatProperty(material, "_Main2ndTexBlendMode");
                if (detail1BlendMode.HasValue)
                {
                    switch (detail1BlendMode.Value)
                    {
                        case 0f: tFloat["_DetailMap1Blend"] = 2f; break; // Add
                        case 1f: tFloat["_DetailMap1Blend"] = 1f; break; // Mul
                        case 2f: tFloat["_DetailMap1Blend"] = 4f; break; // Screen
                        case 3f: tFloat["_DetailMap1Blend"] = 3f; break; // AlphaBlend (Replace)
                    }
                }

                tTexture["_DetailMap2"] = SCSSShaderGUI.GetTextureProperty(material, "_Main3rdTex");
                tColor["_DetailMap2Color"] = SCSSShaderGUI.GetColorProperty(material, "_Color3rd");
                tFloat["_DetailMap2Type"] = 0.0f; // Albedo type

                float? detail2BlendMode = SCSSShaderGUI.GetFloatProperty(material, "_Main3rdTexBlendMode");
                if (detail2BlendMode.HasValue)
                {
                    switch (detail2BlendMode.Value)
                    {
                        case 0f: tFloat["_DetailMap2Blend"] = 2f; break; // Add
                        case 1f: tFloat["_DetailMap2Blend"] = 1f; break; // Mul
                        case 2f: tFloat["_DetailMap2Blend"] = 4f; break; // Screen
                        case 3f: tFloat["_DetailMap2Blend"] = 3f; break; // AlphaBlend (Replace)
                    }
                }

                // Map lilToon secondary normal map to SCSS Detail Map 4
                tTexture["_DetailMap4"] = SCSSShaderGUI.GetTextureProperty(material, "_Bump2ndMap");
                tFloat["_DetailMap4Type"] = 1.0f; // Normal type
                tFloat["_DetailMap4Strength"] = SCSSShaderGUI.GetFloatProperty(material, "_Bump2ndScale");
            }
        }

        /// <summary>
        /// Coordinates the selection and execution of property conversion strategies.
        /// </summary>
        internal static class PropertyConverter
        {
            private static readonly List<IPropertyConverter> _converters = new List<IPropertyConverter>
            {
                new SCSSPropertyConverter(),
                new UTSPropertyConverter(),
                new LilToonPropertyConverter()
            };

            public static void Convert(Material material, Shader oldShader, Shader newShader, Dictionary<string, Color?> tColor, Dictionary<string, float?> tFloat, Dictionary<string, Texture> tTexture, ref int? stencilReference, ref int? stencilComparison, ref int? stencilOperation, ref int? stencilFail)
            {
                if (oldShader == null) return;
                foreach (var converter in _converters)
                {
                    if (converter.IsMatch(oldShader))
                    {
                        converter.ConvertProperties(material, oldShader, newShader, tColor, tFloat, tTexture, ref stencilReference, ref stencilComparison, ref stencilOperation, ref stencilFail);
                        break;
                    }
                }
            }
        }
    }
}
