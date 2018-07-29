using UnityEditor;
using UnityEngine;
using System;

// Parts of this file are based on https://github.com/Microsoft/MixedRealityToolkit-Unity/
// licensed under the MIT license. 

namespace FlatLitToon.Unity
{
    public class Inspector : ShaderGUI
    {

        public enum OutlineMode
        {
            None,
            Tinted,
            Colored
        }

        public enum RenderingMode
        {
            Opaque,
            TransparentCutout,
            Transparent,
            PremultipliedTransparent,
            Additive,
            Custom
        }

        public enum CustomRenderingMode
        {
            Opaque,
            TransparentCutout,
            Transparent
        }

        public enum AlbedoAlphaMode
        {
            Transparency,
            Metallic,
            Smoothness
        }

        public enum DepthWrite
        {
            Off,
            On
        }

        public static class Styles
        {
            public static string mainOptionsTitle = "Main Options";
            public static string renderingOptionsTitle = "Rendering Options";
            public static string shadingOptionsTitle = "Shading Options";
            public static string outlineOptionsTitle = "Outline Options";
            public static string advancedOptionsTitle = "Advanced Options";

            public static string renderTypeName = "RenderType";
            public static string renderingModeName = "_Mode";
            public static string customRenderingModeName = "_CustomMode";
            public static string sourceBlendName = "_SrcBlend";
            public static string destinationBlendName = "_DstBlend";
            public static string blendOperationName = "_BlendOp";
            public static string depthTestName = "_ZTest";
            public static string depthWriteName = "_ZWrite";
            public static string colorWriteMaskName = "_ColorWriteMask";
            public static string alphaTestOnName = "_ALPHATEST_ON";
            public static string alphaBlendOnName = "_ALPHABLEND_ON";
            public static readonly string[] renderingModeNames = Enum.GetNames(typeof(RenderingMode));
            public static readonly string[] customRenderingModeNames = Enum.GetNames(typeof(CustomRenderingMode));
            public static readonly string[] albedoAlphaModeNames = Enum.GetNames(typeof(AlbedoAlphaMode));
            public static readonly string[] depthWriteNames = Enum.GetNames(typeof(DepthWrite));
            public static GUIContent sourceBlend = new GUIContent("Source Blend", "Blend Mode of Newly Calculated Color");
            public static GUIContent destinationBlend = new GUIContent("Destination Blend", "Blend Mode of Exisiting Color");
            public static GUIContent blendOperation = new GUIContent("Blend Operation", "Operation for Blending New Color With Exisiting Color");
            public static GUIContent depthTest = new GUIContent("Depth Test", "How Should Depth Testing Be Performed.");
            public static GUIContent depthWrite = new GUIContent("Depth Write", "Controls Whether Pixels From This Object Are Written to the Depth Buffer");
            public static GUIContent colorWriteMask = new GUIContent("Color Write Mask", "Color Channel Writing Mask");
            public static GUIContent cullMode = new GUIContent("Cull Mode", "Triangle Culling Mode");
            public static GUIContent renderQueueOverride = new GUIContent("Render Queue Override", "Manually Override the Render Queue");

            public static GUIContent mainTexture = new GUIContent("Main Texture", "Main Color Texture (RGB)");
            public static GUIContent alphaCutoff = new GUIContent("Alpha Cutoff", "Threshold for transparency cutoff");
            public static GUIContent colorMask = new GUIContent("Tint Mask", "Masks Color Tinting (G)");
            public static GUIContent normalMap = new GUIContent("Normal Map", "Normal Map (RGB)");
            public static GUIContent specularMap = new GUIContent("Specular Map", "Specular Map (RGB)");
            public static GUIContent emissionMap = new GUIContent("Emission", "Emission (RGB)");
            public static GUIContent lightingRamp = new GUIContent("Lighting Ramp", "Lighting Ramp (RGB) \nNote: If a Lighting Ramp is not set, the material will have no shading.");
            public static GUIContent shadowMask = new GUIContent("Shadow Mask (optional)", "Specifies areas of shadow influence. RGB is darkening, Alpha is lightening.");

            public static GUIContent smoothness = new GUIContent("Smoothness", "Smoothness");
            public static GUIContent specularMult = new GUIContent("Specular Multiplier", "Boosts the intensity of specular lights when higher than 1. Going higher than 1 can cause problems.");
            public static GUIContent useFresnel = new GUIContent("Use Ambient Fresnel", "Applies an additional rim lighting effect.");
            public static GUIContent fresnelWidth = new GUIContent("Ambient Fresnel Width", "Sets the width of the ambient fresnel lighting.");
            public static GUIContent fresnelStrength = new GUIContent("Ambient Fresnel Softness", "Sets the sharpness of the fresnel. ");
            public static GUIContent customFresnelColor = new GUIContent("Emissive Fresnel", "RGB sets the colour of the additive fresnel. Alpha controls the power/width of the effect.");
            public static GUIContent shadowLift = new GUIContent("Shadow Lift", "Increasing this warps the lighting received to make more things lit.");
            public static GUIContent indirectLightBoost = new GUIContent("Indirect Lighting Boost", "Replaces the lighting of shadows with the lighting of direct light, making them brighter.");
            public static GUIContent shadowMaskPow = new GUIContent("Shadow Mask Strength", "Sets the power of the shadow mask.");
            public static GUIContent outlineColor = new GUIContent("Outline Colour", "Sets the colour used for outlines. In tint mode, this is multiplied against the texture.");
            public static GUIContent outlineWidth = new GUIContent("Outline Width", "Sets the width of outlines in cm.");

            public static GUIContent useEnergyConservation = new GUIContent("Use Energy Conservation", "Reduces the intensity of the diffuse on specular areas. Technically correct, but not finished yet. ");

            public static GUIContent useMatcap = new GUIContent("Use Matcap", "Enables the use of material capture textures.");
            public static GUIContent additiveMatcap = new GUIContent("Additive Matcap", "Additive Matcap (RGB)");
            public static GUIContent multiplyMatcap = new GUIContent("Multiply Matcap", "Multiply Matcap (RGB)");

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

        protected MaterialProperty mainTexture;
        protected MaterialProperty color;
        protected MaterialProperty colorMask;
        protected MaterialProperty lightingRamp;
        protected MaterialProperty shadowMaskPow;
        protected MaterialProperty shadowLift; 
        protected MaterialProperty shadowMask;
        protected MaterialProperty indirectLightBoost;
        protected MaterialProperty outlineMode;
        protected MaterialProperty outlineWidth;
        protected MaterialProperty outlineColor;
        protected MaterialProperty emissionMap;
        protected MaterialProperty emissionColor;
        protected MaterialProperty customFresnelColor;
        protected MaterialProperty normalMap;
        protected MaterialProperty specularMap;
        protected MaterialProperty smoothness;
        protected MaterialProperty specularMult;

        protected MaterialProperty useFresnel;
        protected MaterialProperty fresnelWidth;
        protected MaterialProperty fresnelStrength;

        protected MaterialProperty alphaCutoff;

        protected MaterialProperty useEnergyConservation;

        protected MaterialProperty useMatcap;
        protected MaterialProperty additiveMatcap;
        protected MaterialProperty multiplyMatcap;

        protected void FindProperties(MaterialProperty[] props)
            { 
                renderingMode = FindProperty(Styles.renderingModeName, props);
                customRenderingMode = FindProperty(Styles.customRenderingModeName, props);
                sourceBlend = FindProperty(Styles.sourceBlendName, props);
                destinationBlend = FindProperty(Styles.destinationBlendName, props);
                blendOperation = FindProperty(Styles.blendOperationName, props);
                depthTest = FindProperty(Styles.depthTestName, props);
                depthWrite = FindProperty(Styles.depthWriteName, props);
                colorWriteMask = FindProperty(Styles.colorWriteMaskName, props);
                cullMode = FindProperty("_CullMode", props);
                renderQueueOverride = FindProperty("_RenderQueueOverride", props);

                mainTexture = FindProperty("_MainTex", props);
                color = FindProperty("_Color", props);
                colorMask = FindProperty("_ColorMask", props);
                lightingRamp = FindProperty("_LightingRamp", props);
                shadowMaskPow = FindProperty("_Shadow", props);
                shadowLift = FindProperty("_ShadowLift", props);
                indirectLightBoost = FindProperty("_IndirectLightingBoost", props);
                shadowMask = FindProperty("_ShadowMask", props);
                //fresnel = FindProperty("_Fresnel", props);
                outlineMode = FindProperty("_OutlineMode", props);
                outlineWidth = FindProperty("_outline_width", props);
                outlineColor = FindProperty("_outline_color", props);
                emissionMap = FindProperty("_EmissionMap", props);
                emissionColor = FindProperty("_EmissionColor", props);
                customFresnelColor = FindProperty("_CustomFresnelColor", props);
                specularMap = FindProperty("_SpecularMap", props);
                smoothness = FindProperty("_Smoothness", props);
                specularMult = FindProperty("_SpecularMult", props);
                useFresnel = FindProperty("_UseFresnel", props);
                fresnelWidth = FindProperty("_FresnelWidth", props);
                fresnelStrength = FindProperty("_FresnelStrength", props);
                normalMap = FindProperty("_BumpMap", props);
                alphaCutoff = FindProperty("_Cutoff", props);

                useEnergyConservation = FindProperty("_UseEnergyConservation", props);

                useMatcap = FindProperty("_UseMatcap", props);
                additiveMatcap = FindProperty("_AdditiveMatcap", props);
                multiplyMatcap = FindProperty("_MultiplyMatcap", props);
            }

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            
            Material material = (Material)materialEditor.target;

            FindProperties(props);
            Initialise(material);

            RenderingModeOptions(materialEditor);
            MainOptions(materialEditor, material);
            RenderingOptions(materialEditor, material);
            MatcapOptions(materialEditor, material);
            OutlineOptions(materialEditor, material);
            AdvancedOptions(materialEditor, material);

        }

        protected void Initialise(Material material)
        {
            if (!initialised)
            {
                MaterialChanged(material);
                initialised = true;
            }
        }

        protected void MaterialChanged(Material material)
        {
            /* Not used yet.
            SetupMaterialWithAlbedo(material, albedoMap, albedoAlphaMode);
            */
            SetupMaterialWithRenderingMode(material, (RenderingMode)renderingMode.floatValue, (CustomRenderingMode)customRenderingMode.floatValue, (int)renderQueueOverride.floatValue);
        }

        protected void RenderingModeOptions(MaterialEditor materialEditor)
        {
            EditorGUI.BeginChangeCheck();

            EditorGUI.showMixedValue = renderingMode.hasMixedValue;
            RenderingMode mode = (RenderingMode)renderingMode.floatValue;
            EditorGUI.BeginChangeCheck();
            mode = (RenderingMode)EditorGUILayout.Popup(renderingMode.displayName, (int)mode, Styles.renderingModeNames);

            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo(renderingMode.displayName);
                renderingMode.floatValue = (float)mode;
            }

            EditorGUI.showMixedValue = false;

            if (EditorGUI.EndChangeCheck())
            {
                UnityEngine.Object[] targets = renderingMode.targets;

                foreach (UnityEngine.Object target in targets)
                {
                    MaterialChanged((Material)target);
                }
            }

            if ((RenderingMode)renderingMode.floatValue == RenderingMode.Custom)
            {
                EditorGUI.indentLevel += 2;
                customRenderingMode.floatValue = EditorGUILayout.Popup(customRenderingMode.displayName, (int)customRenderingMode.floatValue, Styles.customRenderingModeNames);
                materialEditor.ShaderProperty(sourceBlend, Styles.sourceBlend);
                materialEditor.ShaderProperty(destinationBlend, Styles.destinationBlend);
                materialEditor.ShaderProperty(blendOperation, Styles.blendOperation);
                materialEditor.ShaderProperty(depthTest, Styles.depthTest);
                depthWrite.floatValue = EditorGUILayout.Popup(depthWrite.displayName, (int)depthWrite.floatValue, Styles.depthWriteNames);
                materialEditor.ShaderProperty(colorWriteMask, Styles.colorWriteMask);
                EditorGUI.indentLevel -= 2;
            }

            materialEditor.ShaderProperty(cullMode, Styles.cullMode);
        }

        protected void MainOptions(MaterialEditor materialEditor, Material material)
        { 
            EditorGUIUtility.labelWidth = 0f;
            EditorGUILayout.Space();
            
            EditorGUI.BeginChangeCheck();
            {
                GUILayout.Label(Styles.mainOptionsTitle, EditorStyles.boldLabel, new GUILayoutOption[0]);

                materialEditor.TexturePropertySingleLine(Styles.mainTexture, mainTexture, color);
                EditorGUI.indentLevel += 2;
                if ((RenderingMode)renderingMode.floatValue == RenderingMode.TransparentCutout)
                {
                    materialEditor.ShaderProperty(alphaCutoff, Styles.alphaCutoff.text);
                }
                materialEditor.TexturePropertySingleLine(Styles.colorMask, colorMask);
                EditorGUI.indentLevel -= 2;
                materialEditor.TexturePropertySingleLine(Styles.normalMap, normalMap);
                EditorGUILayout.Space();

                EditorGUI.BeginChangeCheck();
                materialEditor.TextureScaleOffsetProperty(mainTexture);
                if (EditorGUI.EndChangeCheck())
                    emissionMap.textureScaleAndOffset = mainTexture.textureScaleAndOffset;          
            }
            EditorGUI.EndChangeCheck();
        }

        protected void RenderingOptions(MaterialEditor materialEditor, Material material)
        { 
            EditorGUILayout.Space();
            
            EditorGUI.BeginChangeCheck();
            {

                EditorGUILayout.LabelField(Styles.renderingOptionsTitle, EditorStyles.boldLabel);
                materialEditor.TexturePropertySingleLine(Styles.specularMap, specularMap);
                materialEditor.ShaderProperty(smoothness, Styles.smoothness);
                //materialEditor.ShaderProperty(specularMult, Styles.specularMult);
                materialEditor.ShaderProperty(useEnergyConservation, Styles.useEnergyConservation);
                EditorGUILayout.Space();

                materialEditor.ShaderProperty(useFresnel, Styles.useFresnel);

                if (PropertyEnabled(useFresnel))
                {
                    materialEditor.ShaderProperty(fresnelWidth, Styles.fresnelWidth);
                    materialEditor.ShaderProperty(fresnelStrength, Styles.fresnelStrength);
                }
                EditorGUILayout.Space();

                materialEditor.TexturePropertySingleLine(Styles.emissionMap, emissionMap, emissionColor);  
                materialEditor.ShaderProperty(customFresnelColor, Styles.customFresnelColor, 2);         
                EditorGUILayout.Space();

                EditorGUILayout.LabelField(Styles.shadingOptionsTitle, EditorStyles.boldLabel);
                materialEditor.TexturePropertySingleLine(Styles.lightingRamp, lightingRamp);
                materialEditor.ShaderProperty(shadowLift, Styles.shadowLift);
                materialEditor.ShaderProperty(indirectLightBoost, Styles.indirectLightBoost);
                materialEditor.TexturePropertySingleLine(Styles.shadowMask, shadowMask);
                materialEditor.ShaderProperty(shadowMaskPow, Styles.shadowMaskPow); 
            }
            EditorGUI.EndChangeCheck();
        }

        protected void MatcapOptions(MaterialEditor materialEditor, Material material)
        { 
            EditorGUILayout.Space();
            
            EditorGUI.BeginChangeCheck();
            {
                materialEditor.ShaderProperty(useMatcap, Styles.useMatcap);

                if (PropertyEnabled(useMatcap))
                {
                    materialEditor.TexturePropertySingleLine(Styles.additiveMatcap, additiveMatcap);
                    materialEditor.TexturePropertySingleLine(Styles.multiplyMatcap, multiplyMatcap);
                }
            } 
            EditorGUI.EndChangeCheck();
        }

        protected void OutlineOptions(MaterialEditor materialEditor, Material material)
        { 
                EditorGUILayout.Space();
                var oMode = (OutlineMode)outlineMode.floatValue;

                EditorGUI.BeginChangeCheck();
                EditorGUILayout.LabelField(Styles.outlineOptionsTitle, EditorStyles.boldLabel);
                oMode = (OutlineMode)EditorGUILayout.Popup("Outline Mode", (int)oMode, Enum.GetNames(typeof(OutlineMode)));
                
                if (EditorGUI.EndChangeCheck())
                {
                    materialEditor.RegisterPropertyChangeUndo("Outline Mode");
                    outlineMode.floatValue = (float)oMode;

                    foreach (var obj in outlineMode.targets)
                    {
                        SetupMaterialWithOutlineMode((Material)obj, (OutlineMode)material.GetFloat("_OutlineMode"));
                    }

                }
                switch (oMode)
                {
                    case OutlineMode.Tinted:
                    case OutlineMode.Colored:
                        materialEditor.ShaderProperty(outlineColor, Styles.outlineColor, 2);
                        materialEditor.ShaderProperty(outlineWidth, Styles.outlineWidth, 2);
                        break;
                    case OutlineMode.None:
                    default:
                        break;
                }     
        }

        protected void AdvancedOptions(MaterialEditor materialEditor, Material material)
        {
            EditorGUILayout.Space();
            GUILayout.Label(Styles.advancedOptionsTitle, EditorStyles.boldLabel, new GUILayoutOption[0]);

            EditorGUI.BeginChangeCheck();

            materialEditor.ShaderProperty(renderQueueOverride, Styles.renderQueueOverride);

            if (EditorGUI.EndChangeCheck())
            {
                MaterialChanged(material);
            }

            // Show the RenderQueueField but do not allow users to directly manipulate it. That is done via the renderQueueOverride.
            GUI.enabled = false;
            materialEditor.RenderQueueField();

            if (!GUI.enabled && !material.enableInstancing)
            {
                material.enableInstancing = true;
            }

            materialEditor.EnableInstancingField();
        }

        protected static void SetupMaterialWithRenderingMode(Material material, RenderingMode mode, CustomRenderingMode customMode, int renderQueueOverride)
        {
            switch (mode)
            {
                case RenderingMode.Opaque:
                    {
                        material.SetOverrideTag(Styles.renderTypeName, Styles.renderingModeNames[(int)RenderingMode.Opaque]);
                        material.SetInt(Styles.customRenderingModeName, (int)CustomRenderingMode.Opaque);
                        material.SetInt(Styles.sourceBlendName, (int)UnityEngine.Rendering.BlendMode.One);
                        material.SetInt(Styles.destinationBlendName, (int)UnityEngine.Rendering.BlendMode.Zero);
                        material.SetInt(Styles.blendOperationName, (int)UnityEngine.Rendering.BlendOp.Add);
                        material.SetInt(Styles.depthTestName, (int)UnityEngine.Rendering.CompareFunction.LessEqual);
                        material.SetInt(Styles.depthWriteName, (int)DepthWrite.On);
                        material.SetInt(Styles.colorWriteMaskName, (int)UnityEngine.Rendering.ColorWriteMask.All);
                        material.DisableKeyword(Styles.alphaTestOnName);
                        material.DisableKeyword(Styles.alphaBlendOnName);
                        material.renderQueue = (renderQueueOverride >= 0) ? renderQueueOverride : (int)UnityEngine.Rendering.RenderQueue.Geometry;
                    }
                    break;

                case RenderingMode.TransparentCutout:
                    {
                        material.SetOverrideTag(Styles.renderTypeName, Styles.renderingModeNames[(int)RenderingMode.TransparentCutout]);
                        material.SetInt(Styles.customRenderingModeName, (int)CustomRenderingMode.TransparentCutout);
                        material.SetInt(Styles.sourceBlendName, (int)UnityEngine.Rendering.BlendMode.One);
                        material.SetInt(Styles.destinationBlendName, (int)UnityEngine.Rendering.BlendMode.Zero);
                        material.SetInt(Styles.blendOperationName, (int)UnityEngine.Rendering.BlendOp.Add);
                        material.SetInt(Styles.depthTestName, (int)UnityEngine.Rendering.CompareFunction.LessEqual);
                        material.SetInt(Styles.depthWriteName, (int)DepthWrite.On);
                        material.SetInt(Styles.colorWriteMaskName, (int)UnityEngine.Rendering.ColorWriteMask.All);
                        material.EnableKeyword(Styles.alphaTestOnName);
                        material.DisableKeyword(Styles.alphaBlendOnName);
                        material.renderQueue = (renderQueueOverride >= 0) ? renderQueueOverride : (int)UnityEngine.Rendering.RenderQueue.AlphaTest;
                    }
                    break;

                case RenderingMode.Transparent:
                    {
                        material.SetOverrideTag(Styles.renderTypeName, Styles.renderingModeNames[(int)RenderingMode.Transparent]);
                        material.SetInt(Styles.customRenderingModeName, (int)CustomRenderingMode.Transparent);
                        material.SetInt(Styles.sourceBlendName, (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                        material.SetInt(Styles.destinationBlendName, (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                        material.SetInt(Styles.blendOperationName, (int)UnityEngine.Rendering.BlendOp.Add);
                        material.SetInt(Styles.depthTestName, (int)UnityEngine.Rendering.CompareFunction.LessEqual);
                        material.SetInt(Styles.depthWriteName, (int)DepthWrite.Off);
                        material.SetInt(Styles.colorWriteMaskName, (int)UnityEngine.Rendering.ColorWriteMask.All);
                        material.DisableKeyword(Styles.alphaTestOnName);
                        material.EnableKeyword(Styles.alphaBlendOnName);
                        material.renderQueue = (renderQueueOverride >= 0) ? renderQueueOverride : (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    }
                    break;

                case RenderingMode.PremultipliedTransparent:
                    {
                        material.SetOverrideTag(Styles.renderTypeName, Styles.renderingModeNames[(int)RenderingMode.Transparent]);
                        material.SetInt(Styles.customRenderingModeName, (int)CustomRenderingMode.Transparent);
                        material.SetInt(Styles.sourceBlendName, (int)UnityEngine.Rendering.BlendMode.One);
                        material.SetInt(Styles.destinationBlendName, (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                        material.SetInt(Styles.blendOperationName, (int)UnityEngine.Rendering.BlendOp.Add);
                        material.SetInt(Styles.depthTestName, (int)UnityEngine.Rendering.CompareFunction.LessEqual);
                        material.SetInt(Styles.depthWriteName, (int)DepthWrite.Off);
                        material.SetInt(Styles.colorWriteMaskName, (int)UnityEngine.Rendering.ColorWriteMask.All);
                        material.DisableKeyword(Styles.alphaTestOnName);
                        material.EnableKeyword(Styles.alphaBlendOnName);
                        material.renderQueue = (renderQueueOverride >= 0) ? renderQueueOverride : (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    }
                    break;

                case RenderingMode.Additive:
                    {
                        material.SetOverrideTag(Styles.renderTypeName, Styles.renderingModeNames[(int)RenderingMode.Transparent]);
                        material.SetInt(Styles.customRenderingModeName, (int)CustomRenderingMode.Transparent);
                        material.SetInt(Styles.sourceBlendName, (int)UnityEngine.Rendering.BlendMode.One);
                        material.SetInt(Styles.destinationBlendName, (int)UnityEngine.Rendering.BlendMode.One);
                        material.SetInt(Styles.blendOperationName, (int)UnityEngine.Rendering.BlendOp.Add);
                        material.SetInt(Styles.depthTestName, (int)UnityEngine.Rendering.CompareFunction.LessEqual);
                        material.SetInt(Styles.depthWriteName, (int)DepthWrite.Off);
                        material.SetInt(Styles.colorWriteMaskName, (int)UnityEngine.Rendering.ColorWriteMask.All);
                        material.DisableKeyword(Styles.alphaTestOnName);
                        material.EnableKeyword(Styles.alphaBlendOnName);
                        material.renderQueue = (renderQueueOverride >= 0) ? renderQueueOverride : (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    }
                    break;

                case RenderingMode.Custom:
                    {
                        material.SetOverrideTag(Styles.renderTypeName, Styles.customRenderingModeNames[(int)customMode]);
                        // _SrcBlend, _DstBlend, _BlendOp, _ZTest, _ZWrite, _ColorWriteMask are controlled by UI.

                        switch (customMode)
                        {
                            case CustomRenderingMode.Opaque:
                                {
                                    
                                    material.DisableKeyword(Styles.alphaTestOnName);
                                    material.DisableKeyword(Styles.alphaBlendOnName);
                                }
                                break;

                            case CustomRenderingMode.TransparentCutout:
                                {
                                    material.EnableKeyword(Styles.alphaTestOnName);
                                    material.DisableKeyword(Styles.alphaBlendOnName);
                                }
                                break;

                            case CustomRenderingMode.Transparent:
                                {
                                    material.DisableKeyword(Styles.alphaTestOnName);
                                    material.EnableKeyword(Styles.alphaBlendOnName);
                                }
                                break;
                        }

                        material.renderQueue = (renderQueueOverride >= 0) ? renderQueueOverride : material.renderQueue;
                    }
                    break;
            }
        }

        public static void SetupMaterialWithOutlineMode(Material material, OutlineMode outlineMode)
        {
            switch ((OutlineMode)material.GetFloat("_OutlineMode"))
            {
                case OutlineMode.None:
                    material.EnableKeyword("NO_OUTLINE");
                    material.DisableKeyword("TINTED_OUTLINE");
                    material.DisableKeyword("COLORED_OUTLINE");
                    break;
                case OutlineMode.Tinted:
                    material.DisableKeyword("NO_OUTLINE");
                    material.EnableKeyword("TINTED_OUTLINE");
                    material.DisableKeyword("COLORED_OUTLINE");
                    break;
                case OutlineMode.Colored:
                    material.DisableKeyword("NO_OUTLINE");
                    material.DisableKeyword("TINTED_OUTLINE");
                    material.EnableKeyword("COLORED_OUTLINE");
                    break;
                default:
                    break;
            }
        }

        protected static bool PropertyEnabled(MaterialProperty property)
        {
            return (property.floatValue != 0.0f);
        }

        protected static float? GetFloatProperty(Material material, string propertyName)
        {
            if (material.HasProperty(propertyName))
            {
                return material.GetFloat(propertyName);
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
    }

}