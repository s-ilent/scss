using UnityEditor;
using UnityEngine;
using System;
using System.Collections.Generic;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;
using static SilentCelShading.Unity.InspectorCommon;

// Parts of this file are based on https://github.com/Microsoft/MixedRealityToolkit-Unity/
// 	 Copyright (c) Microsoft Corporation. All rights reserved.
// 	 Licensed under the MIT License.

namespace SilentCelShading.Unity
{
    public class SCSSShaderGUI : ShaderGUI
    {
        public enum DepthWrite
        {
            Off,
            On
        }

        public enum RenderingMode
        {
            Opaque = 0,
            Cutout = 1,
            Fade = 2,
            Transparent = 3,
            Additive = 4,
            Custom = 5
        }

        public enum CustomRenderingMode
        {
            Opaque = 0,
            Cutout = 1,
            Fade = 2,
            Premultiplied = 3
        }

        protected static class BaseStyles
        {
            public static string renderTypeName = "RenderType";
            public static string renderingModeName = "_Mode";
            public static string customRenderingModeName = "_CustomMode";
            public static string sourceBlendName = "_SrcBlend";
            public static string destinationBlendName = "_DstBlend";
            public static string blendOperationName = "_BlendOp";
            public static string depthTestName = "_ZTest";
            public static string depthWriteName = "_ZWrite";
            public static string colorWriteMaskName = "_ColorWriteMask";

            public static string cullModeName = "_CullMode";
            public static string renderQueueOverrideName = "_RenderQueueOverride";

            public static string alphaToMaskName = "_AtoCMode";
            public static string alphaTestOnName = "_ALPHATEST_ON";
            public static string alphaBlendOnName = "_ALPHABLEND_ON";
            public static string alphaPremultiplyOnName = "_ALPHAPREMULTIPLY_ON";

            public static readonly string[] renderingModeNames = Enum.GetNames(typeof(RenderingMode));
            public static readonly string[] customRenderingModeNames = Enum.GetNames(typeof(CustomRenderingMode));
            public static readonly string[] depthWriteNames = Enum.GetNames(typeof(DepthWrite));

            public static GUIContent sourceBlend = new GUIContent("Source Blend", "Blend Mode of Newly Calculated Color");
            public static GUIContent destinationBlend = new GUIContent("Destination Blend", "Blend Mode of Exisiting Color");
            public static GUIContent blendOperation = new GUIContent("Blend Operation", "Operation for Blending New Color With Exisiting Color");
            public static GUIContent depthTest = new GUIContent("Depth Test", "How Should Depth Testing Be Performed.");
            public static GUIContent depthWrite = new GUIContent("Depth Write", "Controls Whether Pixels From This Object Are Written to the Depth Buffer");
            public static GUIContent colorWriteMask = new GUIContent("Color Write Mask", "Color Channel Writing Mask");
            public static GUIContent cullMode = new GUIContent("Cull Mode", "Triangle culling mode. Note: Outlines require this to be set to front to work properly.");
            public static GUIContent renderQueueOverride = new GUIContent("Render Queue Override", "Manually set the Render Queue.");

            public static string stencilComparisonName = "_StencilComp";
            public static string stencilOperationName = "_StencilOp";
            public static string stencilFailName = "_StencilFail";
            public static string stencilZFailName = "_StencilZFail";
            public static GUIContent stencilReference = new GUIContent("Stencil Test", "Raising this enables reading or writing a stencil. When set, contains calue to compare against (if Comparison is anything but Always) and/or the value to be written to the buffer (if wither Pass, Fail or ZFail is set to Replace)");
            public static GUIContent stencilComparison = new GUIContent("Stencil Comparison", "The function to be used when reading the stencil value.");
            public static GUIContent stencilOperation = new GUIContent("Stencil Operation", "The operation to be performed when the stencil test passes.");
            public static GUIContent stencilFail = new GUIContent("Stencil Fail", "The operation to be performed when the stencil test fails.");
            public static GUIContent stencilZFail = new GUIContent("Stencil ZFail", "The operation to be performed when the stencil test passes, but the geometry is occluded.");
        }

        protected bool initialised;

        protected MaterialProperty renderingMode;
        protected MaterialProperty customRenderingMode;
        protected MaterialProperty sourceBlend;
        protected MaterialProperty destinationBlend;
        protected MaterialProperty blendOperation;
        protected MaterialProperty depthTest;
        protected MaterialProperty depthWrite;
        protected MaterialProperty colorWriteMask;
        protected MaterialProperty cullMode;
        protected MaterialProperty renderQueueOverride;

        protected MaterialProperty stencilReference;
        protected MaterialProperty stencilComparison;
        protected MaterialProperty stencilOperation;
        protected MaterialProperty stencilFail;
        protected MaterialProperty stencilZFail;

        protected const string LegacyShadersPath = "Legacy Shaders/";
        protected const string TransparentShadersPath = "/Transparent/";
        protected const string TransparentCutoutShadersPath = "/Transparent/Cutout/";

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            Material material = (Material)materialEditor.target;

            FindProperties(props);
            Initialise(material);

            RenderingModeOptions(materialEditor);
        }

        protected virtual void FindProperties(MaterialProperty[] props)
        {
            renderingMode = FindProperty(BaseStyles.renderingModeName, props);
            customRenderingMode = FindProperty(BaseStyles.customRenderingModeName, props);
            sourceBlend = FindProperty(BaseStyles.sourceBlendName, props);
            destinationBlend = FindProperty(BaseStyles.destinationBlendName, props);
            blendOperation = FindProperty(BaseStyles.blendOperationName, props);
            depthTest = FindProperty(BaseStyles.depthTestName, props);
            depthWrite = FindProperty(BaseStyles.depthWriteName, props);
            //depthOffsetFactor = FindProperty(BaseStyles.depthOffsetFactorName, props);
            //depthOffsetUnits = FindProperty(BaseStyles.depthOffsetUnitsName, props);
            colorWriteMask = FindProperty(BaseStyles.colorWriteMaskName, props);

            stencilReference = FindProperty("_Stencil", props);
            stencilComparison = FindProperty(BaseStyles.stencilComparisonName, props);
            stencilOperation = FindProperty(BaseStyles.stencilOperationName, props);
            stencilFail  = FindProperty(BaseStyles.stencilFailName, props);
            stencilZFail = FindProperty(BaseStyles.stencilZFailName, props);

            cullMode = FindProperty(BaseStyles.cullModeName, props);
            renderQueueOverride = FindProperty(BaseStyles.renderQueueOverrideName, props);
        }

        protected void Initialise(Material material)
        {
            if (!initialised)
            {
                MaterialChanged(material);
                initialised = true;
            }
        }

        protected virtual void MaterialChanged(Material material)
        {
            SetupMaterialWithRenderingMode(material, 
                (RenderingMode)renderingMode.floatValue, 
                (CustomRenderingMode)customRenderingMode.floatValue, 
                (int)renderQueueOverride.floatValue);
        }


        protected void RenderingModeOptions(MaterialEditor materialEditor)
        {
            EditorGUI.BeginChangeCheck();

            EditorGUI.showMixedValue = renderingMode.hasMixedValue;
            RenderingMode mode = (RenderingMode)renderingMode.floatValue;
            EditorGUI.BeginChangeCheck();
            mode = (RenderingMode)EditorGUILayout.Popup(renderingMode.displayName, (int)mode, BaseStyles.renderingModeNames);

            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo(renderingMode.displayName);
                renderingMode.floatValue = (float)mode;
            }

            EditorGUI.showMixedValue = false;

            if ((RenderingMode)renderingMode.floatValue == RenderingMode.Custom)
            {
                EditorGUI.indentLevel += 2;
                customRenderingMode.floatValue = EditorGUILayout.Popup(customRenderingMode.displayName, (int)customRenderingMode.floatValue, BaseStyles.customRenderingModeNames);
                materialEditor.ShaderProperty(sourceBlend, BaseStyles.sourceBlend);
                materialEditor.ShaderProperty(destinationBlend, BaseStyles.destinationBlend);
                materialEditor.ShaderProperty(blendOperation, BaseStyles.blendOperation);
                materialEditor.ShaderProperty(depthTest, BaseStyles.depthTest);
                depthWrite.floatValue = EditorGUILayout.Popup(depthWrite.displayName, (int)depthWrite.floatValue, BaseStyles.depthWriteNames);
                materialEditor.ShaderProperty(colorWriteMask, BaseStyles.colorWriteMask);
                EditorGUI.indentLevel -= 2;
            }

            materialEditor.ShaderProperty(cullMode, BaseStyles.cullMode);

            if (EditorGUI.EndChangeCheck())
            {
                Object[] targets = renderingMode.targets;

                foreach (Object target in targets)
                {
                    MaterialChanged((Material)target);
                }
            }
        }

        protected void StencilOptions(MaterialEditor materialEditor, Material material)
        {
        materialEditor.ShaderProperty(stencilReference, BaseStyles.stencilReference);

            if (stencilReference.floatValue > 0)
            {
                materialEditor.ShaderProperty(stencilComparison, BaseStyles.stencilComparison, 2);
                materialEditor.ShaderProperty(stencilOperation, BaseStyles.stencilOperation, 2);
                materialEditor.ShaderProperty(stencilFail, BaseStyles.stencilFail, 2);
                materialEditor.ShaderProperty(stencilZFail, BaseStyles.stencilZFail, 2);
            }
            else
            {
                // When stencil is disable, revert to the default stencil operations. Note, when tested on D3D11 hardware the stencil state 
                // is still set even when the CompareFunction.Disabled is selected, but this does not seem to affect performance.
                material.SetInt(BaseStyles.stencilComparisonName, (int)CompareFunction.Disabled);
                material.SetInt(BaseStyles.stencilOperationName, (int)StencilOp.Keep);
                material.SetInt(BaseStyles.stencilFailName, (int)StencilOp.Keep);
                material.SetInt(BaseStyles.stencilZFailName, (int)StencilOp.Keep);
            }
            EditorGUILayout.Space();
        }

        public struct BlendModeProperties
        {
            public int SourceBlendName;
            public int DestinationBlendName;
            public int BlendOperationName;
            public int DepthTestName;
            public int DepthWriteName;
            public int AlphaToMaskName;
            public int ColorWriteMaskName;
            public bool AlphaTestOn;
            public bool AlphaBlendOn;
            public bool AlphaPremultiplyOn;
            public int RenderQueue;
        }

        private static readonly Dictionary<RenderingMode, BlendModeProperties> blendModeProperties = new Dictionary<RenderingMode, BlendModeProperties>
        {
            {
                RenderingMode.Opaque,
                new BlendModeProperties
                {
                    SourceBlendName = (int)BlendMode.One,
                    DestinationBlendName = (int)BlendMode.Zero,
                    BlendOperationName = (int)BlendOp.Add,
                    DepthTestName = (int)CompareFunction.LessEqual,
                    DepthWriteName = (int)DepthWrite.On,
                    AlphaToMaskName = (int)DepthWrite.Off,
                    ColorWriteMaskName = (int)ColorWriteMask.All,
                    AlphaTestOn = false,
                    AlphaBlendOn = false,
                    AlphaPremultiplyOn = false,
                    RenderQueue = (int)RenderQueue.Geometry
                }
            },
            {
                RenderingMode.Cutout,
                new BlendModeProperties
                {
                    SourceBlendName = (int)BlendMode.One,
                    DestinationBlendName = (int)BlendMode.Zero,
                    BlendOperationName = (int)BlendOp.Add,
                    DepthTestName = (int)CompareFunction.LessEqual,
                    DepthWriteName = (int)DepthWrite.On,
                    AlphaToMaskName = (int)DepthWrite.On,
                    ColorWriteMaskName = (int)ColorWriteMask.All,
                    AlphaTestOn = true,
                    AlphaBlendOn = false,
                    AlphaPremultiplyOn = false,
                    RenderQueue = (int)RenderQueue.AlphaTest
                }
            },
            {
                RenderingMode.Fade,
                new BlendModeProperties
                {
                    SourceBlendName = (int)BlendMode.SrcAlpha,
                    DestinationBlendName = (int)BlendMode.OneMinusSrcAlpha,
                    BlendOperationName = (int)BlendOp.Add,
                    DepthTestName = (int)CompareFunction.LessEqual,
                    DepthWriteName = (int)DepthWrite.Off,
                    AlphaToMaskName = (int)DepthWrite.Off,
                    ColorWriteMaskName = (int)ColorWriteMask.All,
                    AlphaTestOn = false,
                    AlphaBlendOn = true,
                    AlphaPremultiplyOn = false,
                    RenderQueue = (int)RenderQueue.Transparent
                }
            },
            {
                RenderingMode.Transparent,
                new BlendModeProperties
                {
                    SourceBlendName = (int)BlendMode.One,
                    DestinationBlendName = (int)BlendMode.OneMinusSrcAlpha,
                    BlendOperationName = (int)BlendOp.Add,
                    DepthTestName = (int)CompareFunction.LessEqual,
                    DepthWriteName = (int)DepthWrite.Off,
                    AlphaToMaskName = (int)DepthWrite.Off,
                    ColorWriteMaskName = (int)ColorWriteMask.All,
                    AlphaTestOn = false,
                    AlphaBlendOn = false,
                    AlphaPremultiplyOn = true,
                    RenderQueue = (int)RenderQueue.Transparent
                }
            },
            {
                RenderingMode.Additive,
                new BlendModeProperties
                {
                    SourceBlendName = (int)BlendMode.One,
                    DestinationBlendName = (int)BlendMode.One,
                    BlendOperationName = (int)BlendOp.Add,
                    DepthTestName = (int)CompareFunction.LessEqual,
                    DepthWriteName = (int)DepthWrite.Off,
                    AlphaToMaskName = (int)DepthWrite.Off,
                    ColorWriteMaskName = (int)ColorWriteMask.All,
                    AlphaTestOn = false,
                    AlphaBlendOn = true,
                    AlphaPremultiplyOn = false,
                    RenderQueue = (int)RenderQueue.Transparent
                }
            }
        };

        private static void ApplyBlendModeProperties(Material material, BlendModeProperties properties)
        {
            material.SetInt(BaseStyles.sourceBlendName, properties.SourceBlendName);
            material.SetInt(BaseStyles.destinationBlendName, properties.DestinationBlendName);
            material.SetInt(BaseStyles.blendOperationName, properties.BlendOperationName);
            material.SetInt(BaseStyles.depthTestName, properties.DepthTestName);
            material.SetInt(BaseStyles.depthWriteName, properties.DepthWriteName);
            material.SetInt(BaseStyles.alphaToMaskName, properties.AlphaToMaskName);
            material.SetInt(BaseStyles.colorWriteMaskName, properties.ColorWriteMaskName);

            SetKeyword(material, BaseStyles.alphaTestOnName, properties.AlphaTestOn);
            SetKeyword(material, BaseStyles.alphaBlendOnName, properties.AlphaBlendOn);
            SetKeyword(material, BaseStyles.alphaPremultiplyOnName, properties.AlphaPremultiplyOn);

            material.renderQueue = properties.RenderQueue;
        }

        private static void SetDefaultValues(Material material)
        {
            material.SetInt(BaseStyles.blendOperationName, (int)BlendOp.Add);
            material.SetInt(BaseStyles.depthTestName, (int)CompareFunction.LessEqual);
            material.SetInt(BaseStyles.colorWriteMaskName, (int)ColorWriteMask.All);
        }

        private static void SetCustom(Material material, CustomRenderingMode customMode)
        {
            material.SetOverrideTag(BaseStyles.renderTypeName, BaseStyles.customRenderingModeNames[(int)customMode]);

            switch (customMode)
            {
                case CustomRenderingMode.Opaque:
                    SetKeyword(material, BaseStyles.alphaTestOnName, false);
                    SetKeyword(material, BaseStyles.alphaBlendOnName, false);
                    SetKeyword(material, BaseStyles.alphaPremultiplyOnName, false);
                    material.SetInt(BaseStyles.alphaToMaskName, (int)DepthWrite.Off);
                    break;
                case CustomRenderingMode.Cutout:
                    SetKeyword(material, BaseStyles.alphaTestOnName, true);
                    SetKeyword(material, BaseStyles.alphaBlendOnName, false);
                    SetKeyword(material, BaseStyles.alphaPremultiplyOnName, false);
                    material.SetInt(BaseStyles.alphaToMaskName, (int)DepthWrite.On);
                    break;
                case CustomRenderingMode.Fade:
                    SetKeyword(material, BaseStyles.alphaTestOnName, false);
                    SetKeyword(material, BaseStyles.alphaBlendOnName, true);
                    SetKeyword(material, BaseStyles.alphaPremultiplyOnName, false);
                    material.SetInt(BaseStyles.alphaToMaskName, (int)DepthWrite.Off);
                    break;
                case CustomRenderingMode.Premultiplied:
                    SetKeyword(material, BaseStyles.alphaTestOnName, false);
                    SetKeyword(material, BaseStyles.alphaBlendOnName, false);
                    SetKeyword(material, BaseStyles.alphaPremultiplyOnName, true);
                    material.SetInt(BaseStyles.alphaToMaskName, (int)DepthWrite.Off);
                    break;
            }

        }

        protected static void SetupMaterialWithRenderingMode(Material material, RenderingMode mode, CustomRenderingMode customMode, int renderQueueOverride)
        {
            if (mode != RenderingMode.Custom)
            {
                ApplyBlendModeProperties(material, blendModeProperties[mode]);
            }
            else
            {
                SetCustom(material, customMode);
            }

            // If Stencil is set to NotEqual, raise the queue by 1.
            if (material.GetInt("_StencilComp") == (int)CompareFunction.NotEqual)
            {
                material.renderQueue += 1;
            }
            
            material.renderQueue = (renderQueueOverride >= 0) ? renderQueueOverride : material.renderQueue;
        }

        protected static bool PropertyEnabled(MaterialProperty property)
        {
            return (property.floatValue != 0.0f);
        }

        protected static Texture GetTextureProperty(Material material, string propertyName)
        {
            if (material.HasProperty(propertyName))
            {
                return material.GetTexture(propertyName);
            }

            return null;
        }

        protected static float? GetFloatProperty(Material material, string propertyName)
        {
            if (material.HasProperty(propertyName))
            {
                return material.GetFloat(propertyName);
            }

            return null;
        }

        protected static int? GetIntProperty(Material material, string propertyName)
        {
            if (material.HasProperty(propertyName))
            {
                return material.GetInt(propertyName);
            }

            return null;
        }

        protected static Vector4? GetVectorProperty(Material material, string propertyName)
        {
            if (material.HasProperty(propertyName))
            {
                return material.GetVector(propertyName);
            }

            return null;
        }

        protected static Color? GetColorProperty(Material material, string propertyName)
        {
            if (material.HasProperty(propertyName))
            {
                return material.GetColor(propertyName);
            }

            return null;
        }

        protected static void SetShaderFeatureActive(Material material, string keywordName, string propertyName, float? propertyValue)
        {
            if (propertyValue.HasValue)
            {
                if (keywordName != null)
                {
                    if (!propertyValue.Value.Equals(0.0f))
                    {
                        material.EnableKeyword(keywordName);
                    }
                    else
                    {
                        material.DisableKeyword(keywordName);
                    }
                }

                material.SetFloat(propertyName, propertyValue.Value);
            }
        }

        protected static void SetFloatProperty(Material material, string keywordName, string propertyName, float? propertyValue)
        {
            if (propertyValue.HasValue)
            {
                if (keywordName != null)
                {
                    if (propertyValue.Value != 0.0f)
                    {
                        material.EnableKeyword(keywordName);
                    }
                    else
                    {
                        material.DisableKeyword(keywordName);
                    }
                }

                material.SetFloat(propertyName, propertyValue.Value);
            }
        }


        protected static void SetFloatProperty(Material material, string propertyName, float? propertyValue)
        {
            if (propertyValue.HasValue)
            {
                material.SetFloat(propertyName, propertyValue.Value);
            }
        }

        protected static void SetVectorProperty(Material material, string propertyName, Vector4? propertyValue)
        {
            if (propertyValue.HasValue)
            {
                material.SetVector(propertyName, propertyValue.Value);
            }
        }

        protected static void SetColorProperty(Material material, string propertyName, Color? propertyValue)
        {
            if (propertyValue.HasValue)
            {
                material.SetColor(propertyName, propertyValue.Value);
            }
        }

        protected static void SetIntProperty(Material material, string propertyName, int? propertyValue)
        {
            if (propertyValue.HasValue)
            {
                material.SetInt(propertyName, propertyValue.Value);
            }
        }

        protected static void SetKeyword(Material m, string keyword, bool state)
        {
            if (state)
                m.EnableKeyword(keyword);
            else
                m.DisableKeyword(keyword);
        }
    
    }
}