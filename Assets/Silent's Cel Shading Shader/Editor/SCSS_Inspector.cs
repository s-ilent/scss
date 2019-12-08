using UnityEditor;
using UnityEngine;
using System;

// Parts of this file are based on https://github.com/Microsoft/MixedRealityToolkit-Unity/
// licensed under the MIT license. 

namespace SilentCelShading.Unity
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
            Smoothness
        }

        public enum DepthWrite
        {
            Off,
            On
        }

        public enum SpecularType
        {
            Disable,
            Standard,
            Cloth,
            Anisotropic,
            Cel,
            CelStrand
        }

        public enum LightingCalculationType
        {
            Arktoon,
            Standard,
            Cubed,
            Directional
        }

        public enum ShadowMaskType
        {
            Occlusion,
            Tone
        }

        public enum LightRampType
        {
            Horizontal,
            Vertical,
            None
        }

        public enum AmbientFresnelType
        {
            Disable,
            Lit,
            Ambient,
            AmbientAlt
        }

        public enum MatcapBlendModes
        {
            Additive,
            Multiply,
            Median,
        }

        public enum VertexColorType
        {
            Color,
            OutlineColor,
            AdditionalData
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
            public static string albedoMapAlphaSmoothnessName = "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A";
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
            public static GUIContent cullMode = new GUIContent("Cull Mode", "Triangle culling mode. Note: Outlines require this to be set to front to work properly.");
            public static GUIContent renderQueueOverride = new GUIContent("Render Queue Override", "Manually set the Render Queue. Note: VRchat will override this in-game.");

            public static GUIContent mainTexture = new GUIContent("Main Texture", "Main Color Texture (RGBA)");
            public static GUIContent alphaCutoff = new GUIContent("Alpha Cutoff", "Threshold for transparency cutoff");
            public static GUIContent alphaSharp = new GUIContent("Disable Dithering", "Treats transparency cutoff as a hard edge, instead of a soft dithered one.");
            public static GUIContent colorMask = new GUIContent("Tint Mask", "Masks material colour tinting (G) and detail maps (A).");
            public static GUIContent normalMap = new GUIContent("Normal Map", "Normal Map (RGB)");

            public static GUIContent specularMap = new GUIContent("Specular Map", "Specular Map (RGBA, RGB: Specular/Metalness, A: Smoothness)");
            public static GUIContent emissionMap = new GUIContent("Emission", "Emission (RGB)");
            public static GUIContent emissionDetailMask = new GUIContent("Emission Detail Mask", "A map combined with the main emission map to add detail.");
            public static GUIContent emissionDetailParams = new GUIContent("Emission Detail Parameters", "XY: Scroll pow");
            public static GUIContent lightingRamp = new GUIContent("Lighting Ramp", "Specifies the falloff of the lighting. In other words, it controls how light affects your model and how soft or sharp the transition between light and shadow is. \nNote: If a Lighting Ramp is not set, the material will have no shading.");
            public static GUIContent shadowMask = new GUIContent("Shadow Mask", "In Occlusion mode, specifies areas of shadow influence. RGB darkens, alpha lightens. In Tone mode, specifies colour of shading to use. RGB tints, alpha darkens.");
            public static GUIContent specularType = new GUIContent("Specular Style", "Allows you to set the shading used for specular. ");
            public static GUIContent smoothness = new GUIContent("Smoothness", "The smoothness of the material. The specular map's alpha channel is used for this, with this slider being a multiplier.");
            public static GUIContent anisotropy = new GUIContent("Anisotropy", "Direction of the anisotropic specular highlights.");

            public static GUIContent useFresnel = new GUIContent("Rim Lighting Style", "Applies a customisable rim lighting effect.");
            public static GUIContent fresnelWidth = new GUIContent("Rim Width", "Sets the width of the rim lighting.");
            public static GUIContent fresnelStrength = new GUIContent("Rim Softness", "Sets the sharpness of the rim edge. ");
            public static GUIContent fresnelTint = new GUIContent("Rim Tint", "Tints the colours of the rim lighting. To make it brighter, change the brightness to a valur higher than 1.");
            public static GUIContent customFresnelColor = new GUIContent("Emissive Rim", "RGB sets the colour of the additive rim light. Alpha controls the power/width of the effect.");

            public static GUIContent shadowLift = new GUIContent("Shadow Lift", "Increasing this warps the lighting received to make more things lit.");
            public static GUIContent indirectLightBoost = new GUIContent("Indirect Lighting Boost", "Blends the lighting of shadows with the lighting of direct light, making them brighter.");
            public static GUIContent shadowMaskPow = new GUIContent("Shadow Mask Lightening", "Sets the power of the shadow mask.");
            public static GUIContent outlineColor = new GUIContent("Outline Colour", "Sets the colour used for outlines. In tint mode, this is multiplied against the texture.");
            public static GUIContent outlineWidth = new GUIContent("Outline Width", "Sets the width of outlines in cm.");

            public static GUIContent useEnergyConservation = new GUIContent("Use Energy Conservation", "Reduces the intensity of the diffuse on specular areas, to realistically conserve energy.");
            public static GUIContent useMetallic = new GUIContent("Use as Metalness", "Metalness maps are greyscale maps that contain the metalness of a surface. This is different to specular maps, which are RGB (colour) maps that contain the specular parts of a surface.");
            public static GUIContent useMatcap = new GUIContent("Use Matcap", "Enables the use of material capture textures.");
            public static GUIContent matcap1Tex = new GUIContent("Matcap 1", "Matcap (RGB). Controlled by the matcap mask's R channel.");
            public static GUIContent matcap2Tex = new GUIContent("Matcap 2", "Matcap (RGB). Controlled by the matcap mask's G channel.");
            public static GUIContent matcap3Tex = new GUIContent("Matcap 3", "Matcap (RGB). Controlled by the matcap mask's B channel.");
            public static GUIContent matcap4Tex = new GUIContent("Matcap 4", "Matcap (RGB). Controlled by the matcap mask's A channel.");
            public static GUIContent matcapStrength = new GUIContent("Matcap Strength", "Power of the matcap. Higher is stronger.");
            public static GUIContent matcapMask = new GUIContent("Matcap Mask", "Determines the strength of the matcaps by the intensity of the different colour channels.");

            public static GUIContent useSubsurfaceScattering = new GUIContent("Use Subsurface Scattering", "Enables a light scattering effect useful for cloth and skin.");
            public static GUIContent thicknessMap = new GUIContent("Thickness Map", "Thickness Map (RGB)");
            public static GUIContent thicknessMapPower = new GUIContent("Thickness Map Power", "Boosts the intensity of the thickness map.");
            public static GUIContent thicknessInvert = new GUIContent("Invert Thickness", "Inverts the map used for thickness from a scale where 1 produces an effect, to a scale where 0 produces an effect.");
            public static GUIContent scatteringColor = new GUIContent("Scattering Color", "The colour used for the subsurface scattering effect.");
            public static GUIContent scatteringIntensity = new GUIContent("Scattering Intensity", "Strength of the subsurface scattering effect.");
            public static GUIContent scatteringPower = new GUIContent("Scattering Power", "Controls the power of the scattering effect.");
            public static GUIContent scatteringDistortion = new GUIContent("Scattering Distortion", "Controls the level of distortion light receives when passing through the material.");
            public static GUIContent scatteringAmbient = new GUIContent("Scattering Ambient", "Controls the intensity of ambient light received from scattering.");

            public static GUIContent lightRampType = new GUIContent("Lighting Ramp Type", "For if you use lightramps that run from bottom to top instead of left to right, or none at all.");
            public static GUIContent lightingCalculationType = new GUIContent("Lighting Calculation", "Changes how the direct/indirect lighting calculation is performed.");
            public static GUIContent shadowMaskType = new GUIContent("Shadow Mask Style", "Changes how the shadow mask is used.");
            public static GUIContent vertexColorType = new GUIContent("Vertex Colour Type", "Sets how the vertex colour should be used. Outline only affects the colour of outlines. Additional data uses the red channel for outline width and the green for ramp softness. ");

            public static GUIContent lightSkew = new GUIContent("Light Skew", "Skews the direction of the received lighting. The default is (1, 0.1, 1, 0), which corresponds to normal strength on the X and Z axis, while reducing the effect of the Y axis. This essentially stops you from getting those harsh lights from above or below that look so weird on cel shaded models. But that's just a default...");
            public static GUIContent pixelSampleMode = new GUIContent("Pixel Art Mode", "Treats the main texture as pixel art. Great for retro avatars! Note: When using this, you should make sure mipmaps are Enabled and texture sampling is set to Trilinear.");

            public static GUIContent useDetailMaps = new GUIContent("Use Detail Maps", "Applies detail maps over the top of other textures for a more detailed appearance.");
            public static GUIContent detailAlbedoMap = new GUIContent("Detail Albedo x2", "An albedo map multiplied over the main albedo map to provide extra detail.");
            public static GUIContent detailNormalMap = new GUIContent("Detail Normal", "A normal map combined with the main normal map to add extra detail.");
            public static GUIContent specularDetailMask = new GUIContent("Specular Detail Mask", "The detail pattern to use over the specular map.");
            public static GUIContent uvSet = new GUIContent("Secondary UV Source", "Selects which UV channel to use for detail maps.");

            public static GUIContent highlights = new GUIContent("Specular Highlights", "Toggles specular highlights. Only applicable if specular is active.");
            public static GUIContent reflections = new GUIContent("Reflections", "Toggles glossy reflections. Only applicable if specular is active.");
            public static GUIContent manualButton = new GUIContent("This shader has a manual. Check it out!","For information on new features, old features, and just how to use the shader in general, check out the manual on the shader wiki!");
            public static GUIContent gradientEditorButton = new GUIContent("Open Gradient Editor","Opens the gradient editor window with the current material focused. This allows you to create a new lighting ramp and view the results on this material in realtime.");

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

        protected MaterialProperty mainTexture;
        protected MaterialProperty color;
        protected MaterialProperty colorMask;
        protected MaterialProperty albedoAlphaMode;

        protected MaterialProperty outlineMode;
        protected MaterialProperty outlineWidth;
        protected MaterialProperty outlineColor;
        protected MaterialProperty emissionMap;
        protected MaterialProperty emissionDetailMask;
        protected MaterialProperty emissionDetailParams;
        protected MaterialProperty emissionColor;
        protected MaterialProperty customFresnelColor;

        protected MaterialProperty normalMap;

        protected MaterialProperty useDetailMaps;
        protected MaterialProperty detailAlbedoMap;
        protected MaterialProperty detailAlbedoMapScale;
        protected MaterialProperty detailNormalMap;
        protected MaterialProperty detailNormalMapScale;
        protected MaterialProperty specularDetailMask;
        protected MaterialProperty specularDetailStrength;
        protected MaterialProperty uvSetSecondary;

        protected MaterialProperty specularMap;
        protected MaterialProperty smoothness;
        protected MaterialProperty anisotropy;
        protected MaterialProperty useMetallic;

        protected MaterialProperty useFresnel;
        protected MaterialProperty fresnelWidth;
        protected MaterialProperty fresnelStrength;
        protected MaterialProperty fresnelTint;

        protected MaterialProperty alphaCutoff;
        protected MaterialProperty alphaSharp;

        protected MaterialProperty useEnergyConservation;
        protected MaterialProperty specularType;

        protected MaterialProperty useMatcap;
        protected MaterialProperty matcapMask;

        protected MaterialProperty matcap1;
        protected MaterialProperty matcap1Blend;
        protected MaterialProperty matcap1Strength;
        protected MaterialProperty matcap2;
        protected MaterialProperty matcap2Blend;
        protected MaterialProperty matcap2Strength;
        protected MaterialProperty matcap3;
        protected MaterialProperty matcap3Blend;
        protected MaterialProperty matcap3Strength;
        protected MaterialProperty matcap4;
        protected MaterialProperty matcap4Blend;
        protected MaterialProperty matcap4Strength;

        protected MaterialProperty useSubsurfaceScattering;
        protected MaterialProperty thicknessMap;
        protected MaterialProperty thicknessMapPower;
        protected MaterialProperty thicknessInvert;
        protected MaterialProperty scatteringColor;
        protected MaterialProperty scatteringIntensity;
        protected MaterialProperty scatteringPower;
        protected MaterialProperty scatteringDistortion;
        protected MaterialProperty scatteringAmbient;

        protected MaterialProperty lightingRamp;
        protected MaterialProperty shadowLift; 
        protected MaterialProperty shadowMask;
        protected MaterialProperty shadowMaskPow;
        protected MaterialProperty shadowMaskColor;
        protected MaterialProperty indirectLightBoost;
        protected MaterialProperty lightRampType;
        protected MaterialProperty lightingCalculationType;
        protected MaterialProperty shadowMaskType;
        protected MaterialProperty vertexColorType;

        protected MaterialProperty lightSkew;
        protected MaterialProperty pixelSampleMode;
        protected MaterialProperty highlights;
        protected MaterialProperty reflections;

        protected MaterialProperty stencilReference;
        protected MaterialProperty stencilComparison;
        protected MaterialProperty stencilOperation;
        protected MaterialProperty stencilFail;
        protected MaterialProperty stencilZFail;

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
                albedoAlphaMode = FindProperty("_AlbedoAlphaMode", props);
                lightingRamp = FindProperty("_Ramp", props);
                shadowMaskPow = FindProperty("_Shadow", props);
                shadowLift = FindProperty("_ShadowLift", props);
                indirectLightBoost = FindProperty("_IndirectLightingBoost", props);
                shadowMask = FindProperty("_ShadowMask", props);
                shadowMaskColor = FindProperty("_ShadowMaskColor", props);
                outlineMode = FindProperty("_OutlineMode", props);
                outlineWidth = FindProperty("_outline_width", props);
                outlineColor = FindProperty("_outline_color", props);
                emissionMap = FindProperty("_EmissionMap", props);
                emissionDetailMask = FindProperty("_DetailEmissionMap", props);
                emissionDetailParams = FindProperty("_EmissionDetailParams", props);
                emissionColor = FindProperty("_EmissionColor", props);
                customFresnelColor = FindProperty("_CustomFresnelColor", props);
                specularMap = FindProperty("_SpecGlossMap", props);
                smoothness = FindProperty("_Smoothness", props);
                anisotropy = FindProperty("_Anisotropy", props);
                useMetallic = FindProperty("_UseMetallic", props);
                useFresnel = FindProperty("_UseFresnel", props);
                fresnelWidth = FindProperty("_FresnelWidth", props);
                fresnelStrength = FindProperty("_FresnelStrength", props);
                fresnelTint = FindProperty("_FresnelTint", props);
                normalMap = FindProperty("_BumpMap", props);
                alphaCutoff = FindProperty("_Cutoff", props);
                alphaSharp = FindProperty("_AlphaSharp", props);

                useDetailMaps = FindProperty("_UseDetailMaps", props);
                detailAlbedoMap = FindProperty("_DetailAlbedoMap", props);
                detailAlbedoMapScale = FindProperty("_DetailAlbedoMapScale", props);
                detailNormalMap = FindProperty("_DetailNormalMap", props);
                detailNormalMapScale = FindProperty("_DetailNormalMapScale", props);
                specularDetailMask = FindProperty("_SpecularDetailMask", props);
                specularDetailStrength = FindProperty("_SpecularDetailStrength", props);
                uvSetSecondary = FindProperty("_UVSec", props);

                useEnergyConservation = FindProperty("_UseEnergyConservation", props);
                specularType = FindProperty("_SpecularType", props);

                useMatcap = FindProperty("_UseMatcap", props);
                matcapMask = FindProperty("_MatcapMask", props);

                matcap1 = FindProperty("_Matcap1", props);
                matcap1Blend = FindProperty("_Matcap1Blend", props);
                matcap1Strength = FindProperty("_Matcap1Strength", props);
                matcap2 = FindProperty("_Matcap2", props);
                matcap2Blend = FindProperty("_Matcap2Blend", props);
                matcap2Strength = FindProperty("_Matcap2Strength", props);
                matcap3 = FindProperty("_Matcap3", props);
                matcap3Blend = FindProperty("_Matcap3Blend", props);
                matcap3Strength = FindProperty("_Matcap3Strength", props);
                matcap4 = FindProperty("_Matcap4", props);
                matcap4Blend = FindProperty("_Matcap4Blend", props);
                matcap4Strength = FindProperty("_Matcap4Strength", props);

                useSubsurfaceScattering = FindProperty("_UseSubsurfaceScattering", props);
                thicknessMap = FindProperty("_ThicknessMap", props);
                thicknessMapPower = FindProperty("_ThicknessMapPower", props);
                thicknessInvert = FindProperty("_ThicknessMapInvert", props);
                scatteringColor = FindProperty("_SSSCol", props);
                scatteringIntensity = FindProperty("_SSSIntensity", props);
                scatteringPower = FindProperty("_SSSPow", props);
                scatteringDistortion = FindProperty("_SSSDist", props);
                scatteringAmbient = FindProperty("_SSSAmbient", props);

                lightRampType = FindProperty("_LightRampType", props);
                lightingCalculationType = FindProperty("_LightingCalculationType", props);
                shadowMaskType = FindProperty("_ShadowMaskType", props);
                vertexColorType = FindProperty("_VertexColorType", props);

                lightSkew = FindProperty("_LightSkew", props);
                pixelSampleMode = FindProperty("_PixelSampleMode", props); 

                stencilReference = FindProperty("_Stencil", props);
                stencilComparison = FindProperty(Styles.stencilComparisonName, props);
                stencilOperation = FindProperty(Styles.stencilOperationName, props);
                stencilFail  = FindProperty(Styles.stencilFailName, props);
                stencilZFail = FindProperty(Styles.stencilZFailName, props);

                highlights = FindProperty("_SpecularHighlights", props, false);
                reflections = FindProperty("_GlossyReflections", props, false);
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
            SubsurfaceOptions(materialEditor, material);
            DetailMapOptions(materialEditor, material);
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
            SetupMaterialWithAlbedo(material, mainTexture, albedoAlphaMode);
            SetupMaterialWithRenderingMode(material, (RenderingMode)renderingMode.floatValue, (CustomRenderingMode)customRenderingMode.floatValue, (int)renderQueueOverride.floatValue);
            SetupMaterialWithOutlineMode(material, (OutlineMode)outlineMode.floatValue);

            // Handle old materials
            UpgradeMatcaps(material);

            SetMaterialKeywords(material);
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
            
            {
                EditorGUI.BeginChangeCheck();
                GUILayout.Label(Styles.mainOptionsTitle, EditorStyles.boldLabel, new GUILayoutOption[0]);

                materialEditor.TexturePropertySingleLine(Styles.mainTexture, mainTexture, color);
                EditorGUI.indentLevel += 2;
                if ((RenderingMode)renderingMode.floatValue == RenderingMode.TransparentCutout)
                {
                    materialEditor.ShaderProperty(alphaCutoff, Styles.alphaCutoff.text);
                    materialEditor.ShaderProperty(alphaSharp, Styles.alphaSharp.text);
                }
                materialEditor.TexturePropertySingleLine(Styles.colorMask, colorMask);
                EditorGUI.indentLevel -= 2;
                materialEditor.TexturePropertySingleLine(Styles.normalMap, normalMap);
                EditorGUILayout.Space();
            }
                EditorGUI.EndChangeCheck();

                EditorGUI.BeginChangeCheck();
                materialEditor.TextureScaleOffsetProperty(mainTexture);
                if (EditorGUI.EndChangeCheck())
                    emissionMap.textureScaleAndOffset = mainTexture.textureScaleAndOffset;          
                EditorGUILayout.Space();
        }

        protected void RenderingOptions(MaterialEditor materialEditor, Material material)
        { 
                EditorGUILayout.Space();
                EditorGUILayout.LabelField(Styles.renderingOptionsTitle, EditorStyles.boldLabel);

                SpecularOptions(materialEditor, material);
                
                EditorGUI.BeginChangeCheck();
                materialEditor.ShaderProperty(useFresnel, Styles.useFresnel);

                if (PropertyEnabled(useFresnel))
                {
                    materialEditor.ShaderProperty(fresnelWidth, Styles.fresnelWidth);
                    materialEditor.ShaderProperty(fresnelStrength, Styles.fresnelStrength);
                    materialEditor.ShaderProperty(fresnelTint, Styles.fresnelTint);         
                }
                EditorGUILayout.Space();

                materialEditor.TexturePropertySingleLine(Styles.emissionMap, emissionMap, emissionColor);  
                materialEditor.ShaderProperty(customFresnelColor, Styles.customFresnelColor, 2);         
                EditorGUILayout.Space();

                EditorGUILayout.LabelField(Styles.shadingOptionsTitle, EditorStyles.boldLabel);
                if (((LightRampType)material.GetFloat("_LightRampType")) != LightRampType.None) 
                {

                    GUILayout.BeginHorizontal();
                    materialEditor.TexturePropertySingleLine(Styles.lightingRamp, lightingRamp);
                    if (GUILayout.Button(Styles.gradientEditorButton, "button"))
                    {
                        XSGradientEditor.callGradientEditor(material);
                    }
                    GUILayout.EndHorizontal();
                }
                materialEditor.ShaderProperty(shadowLift, Styles.shadowLift);
                materialEditor.ShaderProperty(indirectLightBoost, Styles.indirectLightBoost);
                //
                EditorGUILayout.Space();

                materialEditor.TexturePropertySingleLine(Styles.shadowMask, shadowMask, shadowMaskColor);

                var sMode = (ShadowMaskType)shadowMaskType.floatValue;
                EditorGUI.BeginChangeCheck();
            
                sMode = (ShadowMaskType)EditorGUILayout.Popup("Shadow Mask Style", (int)sMode, Enum.GetNames(typeof(ShadowMaskType)));

                if (EditorGUI.EndChangeCheck())
                {
                    materialEditor.RegisterPropertyChangeUndo("Shadow Mask Style");
                    shadowMaskType.floatValue = (float)sMode;

                    foreach (var obj in shadowMaskType.targets)
                    {
                        SetupMaterialWithShadowMaskType((Material)obj, (ShadowMaskType)material.GetFloat("_ShadowMaskType"));
                    }

                } 

                materialEditor.ShaderProperty(shadowMaskPow, Styles.shadowMaskPow); 
            
            EditorGUI.EndChangeCheck();
        }

        protected void SpecularOptions(MaterialEditor materialEditor, Material material)
        {             
            var sMode = (SpecularType)specularType.floatValue;
            EditorGUI.BeginChangeCheck();
            
                sMode = (SpecularType)EditorGUILayout.Popup("Specular Style", (int)sMode, Enum.GetNames(typeof(SpecularType)));

                if (EditorGUI.EndChangeCheck())
                {
                    materialEditor.RegisterPropertyChangeUndo("Specular Style");
                    specularType.floatValue = (float)sMode;

                    foreach (var obj in specularType.targets)
                    {
                        SetupMaterialWithSpecularType((Material)obj, (SpecularType)material.GetFloat("_SpecularType"));
                    }

                } 

                switch (sMode)
                {
                    case SpecularType.Standard:
                    case SpecularType.Cloth:
                    case SpecularType.Cel:
                        materialEditor.TexturePropertySingleLine(Styles.specularMap, specularMap);
                        materialEditor.ShaderProperty(smoothness, Styles.smoothness);
                        materialEditor.ShaderProperty(useMetallic, Styles.useMetallic);
                        materialEditor.ShaderProperty(useEnergyConservation, Styles.useEnergyConservation);
                        break;
                    case SpecularType.Anisotropic:
                    case SpecularType.CelStrand:
                        materialEditor.TexturePropertySingleLine(Styles.specularMap, specularMap);
                        materialEditor.ShaderProperty(smoothness, Styles.smoothness);
                        materialEditor.ShaderProperty(anisotropy, Styles.anisotropy);
                        materialEditor.ShaderProperty(useMetallic, Styles.useMetallic);
                        materialEditor.ShaderProperty(useEnergyConservation, Styles.useEnergyConservation);
                        break;
                    case SpecularType.Disable:
                    default:
                        break;
                }   

                EditorGUILayout.Space();
        }

        protected void DetailMapOptions(MaterialEditor materialEditor, Material material)
        {     
                EditorGUILayout.Space();

                EditorGUI.BeginChangeCheck();
                materialEditor.ShaderProperty(useDetailMaps, Styles.useDetailMaps);

                if (PropertyEnabled(useDetailMaps)) 
                {
                    material.EnableKeyword("_DETAIL_MULX2");
                    materialEditor.TexturePropertySingleLine(Styles.detailAlbedoMap, detailAlbedoMap, detailAlbedoMapScale);
                    materialEditor.TexturePropertySingleLine(Styles.detailNormalMap, detailNormalMap, detailNormalMapScale);
                    materialEditor.TexturePropertySingleLine(Styles.specularDetailMask, specularDetailMask, specularDetailStrength);
                    materialEditor.TexturePropertySingleLine(Styles.emissionDetailMask, emissionDetailMask);
                    materialEditor.ShaderProperty(emissionDetailParams, Styles.emissionDetailParams);
                
                    materialEditor.TextureScaleOffsetProperty(detailAlbedoMap);
                    materialEditor.ShaderProperty(uvSetSecondary, Styles.uvSet);
                } else {
                    material.DisableKeyword("_DETAIL_MULX2");
                }
                EditorGUILayout.Space();
                
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
                    materialEditor.TexturePropertySingleLine(Styles.matcapMask, matcapMask);
                    materialEditor.TexturePropertySingleLine(Styles.matcap1Tex, matcap1, matcap1Strength, matcap1Blend);
                    materialEditor.TexturePropertySingleLine(Styles.matcap2Tex, matcap2, matcap2Strength, matcap2Blend);
                    materialEditor.TexturePropertySingleLine(Styles.matcap3Tex, matcap3, matcap3Strength, matcap3Blend);
                    materialEditor.TexturePropertySingleLine(Styles.matcap4Tex, matcap4, matcap4Strength, matcap4Blend);
                }
            } 
            EditorGUI.EndChangeCheck();
        }

        protected void SubsurfaceOptions(MaterialEditor materialEditor, Material material)
        { 
            EditorGUILayout.Space();
            
            EditorGUI.BeginChangeCheck();
            {
                materialEditor.ShaderProperty(useSubsurfaceScattering, Styles.useSubsurfaceScattering);

                if (PropertyEnabled(useSubsurfaceScattering))
                {
                    materialEditor.TexturePropertySingleLine(Styles.thicknessMap, thicknessMap);
                    materialEditor.ShaderProperty(thicknessMapPower, Styles.thicknessMapPower);
                    materialEditor.ShaderProperty(thicknessInvert, Styles.thicknessInvert);
                    materialEditor.ShaderProperty(scatteringColor, Styles.scatteringColor);
                    materialEditor.ShaderProperty(scatteringIntensity, Styles.scatteringIntensity);
                    materialEditor.ShaderProperty(scatteringPower, Styles.scatteringPower);
                    materialEditor.ShaderProperty(scatteringDistortion, Styles.scatteringDistortion);
                    materialEditor.ShaderProperty(scatteringAmbient, Styles.scatteringAmbient);
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

        protected void StencilOptions(MaterialEditor materialEditor, Material material)
        {
        materialEditor.ShaderProperty(stencilReference, Styles.stencilReference);

            if (stencilReference.floatValue > 0)
            {
                materialEditor.ShaderProperty(stencilComparison, Styles.stencilComparison, 2);
                materialEditor.ShaderProperty(stencilOperation, Styles.stencilOperation, 2);
                materialEditor.ShaderProperty(stencilFail, Styles.stencilFail, 2);
                materialEditor.ShaderProperty(stencilZFail, Styles.stencilZFail, 2);
            }
            else
            {
                // When stencil is disable, revert to the default stencil operations. Note, when tested on D3D11 hardware the stencil state 
                // is still set even when the CompareFunction.Disabled is selected, but this does not seem to affect performance.
                material.SetInt(Styles.stencilComparisonName, (int)UnityEngine.Rendering.CompareFunction.Disabled);
                material.SetInt(Styles.stencilOperationName, (int)UnityEngine.Rendering.StencilOp.Keep);
                material.SetInt(Styles.stencilFailName, (int)UnityEngine.Rendering.StencilOp.Keep);
                material.SetInt(Styles.stencilZFailName, (int)UnityEngine.Rendering.StencilOp.Keep);
            }
            EditorGUILayout.Space();
        }

        protected void AdvancedOptions(MaterialEditor materialEditor, Material material)
        {
            EditorGUILayout.Space();
            if (GUILayout.Button(Styles.manualButton, "button"))
            {
               Application.OpenURL("https://gitlab.com/s-ilent/SCSS/wikis/Manual/Setting-Overview");
            }
            EditorGUILayout.Space();

            GUILayout.Label(Styles.advancedOptionsTitle, EditorStyles.boldLabel, new GUILayoutOption[0]);

            var lMode = (LightRampType)lightRampType.floatValue;
            EditorGUI.BeginChangeCheck();
            
            lMode = (LightRampType)EditorGUILayout.Popup("Light Ramp Type", (int)lMode, Enum.GetNames(typeof(LightRampType)));

            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo("Light Ramp Type");
                lightRampType.floatValue = (float)lMode;

                foreach (var obj in lightRampType.targets)
                {
                    SetupMaterialWithLightRampType((Material)obj, (LightRampType)material.GetFloat("_LightRampType"));
                }

            } 

            var vcMode = (VertexColorType)vertexColorType.floatValue;
            EditorGUI.BeginChangeCheck();
            
            vcMode = (VertexColorType)EditorGUILayout.Popup("Vertex Colour Type", (int)vcMode, Enum.GetNames(typeof(VertexColorType)));

            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo("Vertex Colour Type");
                vertexColorType.floatValue = (float)vcMode;

                foreach (var obj in vertexColorType.targets)
                {
                    SetupMaterialWithVertexColorType((Material)obj, (VertexColorType)material.GetFloat("_VertexColorType"));
                }

            } 

            EditorGUI.BeginChangeCheck();

            materialEditor.ShaderProperty(pixelSampleMode, Styles.pixelSampleMode);

            var aaMode = (AlbedoAlphaMode)albedoAlphaMode.floatValue;
            EditorGUI.BeginChangeCheck();

            aaMode = (AlbedoAlphaMode)EditorGUILayout.Popup(albedoAlphaMode.displayName, (int)aaMode, Styles.albedoAlphaModeNames);

            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo("Albedo Alpha Mode");
                albedoAlphaMode.floatValue = (float)aaMode;

                foreach (var obj in albedoAlphaMode.targets)
                {
                    SetupMaterialWithAlbedo((Material)obj, mainTexture, albedoAlphaMode);
                }

            } 

            EditorGUI.BeginChangeCheck();

            if (highlights != null)
                materialEditor.ShaderProperty(highlights, Styles.highlights);
            if (reflections != null)
                materialEditor.ShaderProperty(reflections, Styles.reflections);

            if (EditorGUI.EndChangeCheck())
            {
                MaterialChanged(material);
            }

            var lcMode = (LightingCalculationType)lightingCalculationType.floatValue;

            lcMode = (LightingCalculationType)EditorGUILayout.Popup("Lighting Calculation", (int)lcMode, Enum.GetNames(typeof(LightingCalculationType)));

            if (EditorGUI.EndChangeCheck())
                {
                    materialEditor.RegisterPropertyChangeUndo("Lighting Calculation");
                    lightingCalculationType.floatValue = (float)lcMode;

                    foreach (var obj in lightingCalculationType.targets)
                    {
                        SetupMaterialWithLightingCalculationType((Material)obj, (LightingCalculationType)material.GetFloat("_LightingCalculationType"));
                    }

                } 

            materialEditor.ShaderProperty(lightSkew, Styles.lightSkew);

            StencilOptions(materialEditor, material);

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

        protected static void SetupMaterialWithAlbedo(Material material, MaterialProperty albedoMap, MaterialProperty albedoAlphaMode)
        {
            switch ((AlbedoAlphaMode)albedoAlphaMode.floatValue)
            {
                case AlbedoAlphaMode.Transparency:
                    {
                        material.DisableKeyword(Styles.albedoMapAlphaSmoothnessName);
                    }
                    break;

                case AlbedoAlphaMode.Smoothness:
                    {
                        material.EnableKeyword(Styles.albedoMapAlphaSmoothnessName);
                    }
                    break;
            }
        }

        protected static void SetupMaterialWithRenderingMode(Material material, RenderingMode mode, CustomRenderingMode customMode, int renderQueueOverride)
        {
            // If we aren't switching to Custom, then set default values for all RenderingMode types. Otherwise keep whatever user had before
            if (mode != RenderingMode.Custom)
            {
                material.SetInt(Styles.blendOperationName, (int)UnityEngine.Rendering.BlendOp.Add);
                material.SetInt(Styles.depthTestName, (int)UnityEngine.Rendering.CompareFunction.LessEqual);
                // material.SetFloat(Styles.depthOffsetFactorName, 0.0f);
                // material.SetFloat(Styles.depthOffsetUnitsName, 0.0f);
                material.SetInt(Styles.colorWriteMaskName, (int)UnityEngine.Rendering.ColorWriteMask.All);
            }

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
            string[] oldShaderName = material.shader.name.Split('/');
            const string noOutlineName = "☓ No Outline";
            var currentlyNoOutline = oldShaderName[oldShaderName.Length - 2].Equals(noOutlineName);
            switch ((OutlineMode)outlineMode)
            {
            case OutlineMode.None:
                if (!currentlyNoOutline) {
                    string[] newShaderName = new string[oldShaderName.Length + 1];
                    for (int x = 0; x < oldShaderName.Length - 1; x++)
                    {
                        newShaderName[x] = oldShaderName[x];
                    }
                    newShaderName[newShaderName.Length - 2] = noOutlineName;
                    newShaderName[newShaderName.Length - 1] = oldShaderName[oldShaderName.Length - 1];
                    Shader finalShader = Shader.Find(String.Join("/", newShaderName));
                    // If we can't find it, pass.
                    if (finalShader != null) {
                        material.shader = finalShader;
                    }
                }
                break;
            case OutlineMode.Tinted:
            case OutlineMode.Colored:
                if (currentlyNoOutline) {
                    string[] newShaderName = new string[oldShaderName.Length - 1];
                    for (int x = 0; x < oldShaderName.Length - 2; x++)
                    {
                        newShaderName[x] = oldShaderName[x];
                    }
                    newShaderName[oldShaderName.Length - 2] = oldShaderName[oldShaderName.Length - 1];
                    Shader finalShader = Shader.Find(String.Join("/", newShaderName));
                    // If we can't find it, pass.
                    if (finalShader != null) {
                        material.shader = finalShader;
                    }
                }
                break;
            }
        }

        public static void SetupMaterialWithSpecularType(Material material, SpecularType specularType)
        {
            // Note: _METALLICGLOSSMAP is used to avoid keyword problems with VRchat.
            // It's only a coincidence that the metallic map needs to be present.
            // Note: _SPECGLOSSMAP is used to switch to a version that doesn't sample
            // reflection probes. 
            switch ((SpecularType)material.GetFloat("_SpecularType"))
            {
                case SpecularType.Standard:
                    material.SetFloat("_SpecularType", 1);
                    material.EnableKeyword("_METALLICGLOSSMAP");
                    material.DisableKeyword("_SPECGLOSSMAP");
                    break;
                case SpecularType.Cloth:
                    material.SetFloat("_SpecularType", 2);
                    material.EnableKeyword("_METALLICGLOSSMAP");
                    material.DisableKeyword("_SPECGLOSSMAP");
                    break;
                case SpecularType.Anisotropic:
                    material.SetFloat("_SpecularType", 3);
                    material.EnableKeyword("_METALLICGLOSSMAP");
                    material.DisableKeyword("_SPECGLOSSMAP");
                    break;
                case SpecularType.Cel:
                    material.SetFloat("_SpecularType", 4);
                    material.EnableKeyword("_SPECGLOSSMAP");
                    material.DisableKeyword("_METALLICGLOSSMAP");
                    break;
                case SpecularType.CelStrand:
                    material.SetFloat("_SpecularType", 5);
                    material.EnableKeyword("_SPECGLOSSMAP");
                    material.DisableKeyword("_METALLICGLOSSMAP");
                    break;
                case SpecularType.Disable:
                    material.SetFloat("_SpecularType", 0);
                    material.DisableKeyword("_METALLICGLOSSMAP");
                    material.DisableKeyword("_SPECGLOSSMAP");
                    break;
                default:
                    break;
            }
        }

        public static void SetupMaterialWithShadowMaskType(Material material, ShadowMaskType shadowMaskType)
        {
            switch ((ShadowMaskType)material.GetFloat("_ShadowMaskType"))
            {
                case ShadowMaskType.Occlusion:
                    material.SetFloat("_ShadowMaskType", 0);
                    break;
                case ShadowMaskType.Tone:
                    material.SetFloat("_ShadowMaskType", 1);
                    break;
                default:
                    break;
            }
        }

        public static void SetupMaterialWithLightRampType(Material material, LightRampType lightRampType)
        {
            switch ((LightRampType)material.GetFloat("_LightRampType"))
            {
                case LightRampType.Horizontal:
                    material.SetFloat("_LightRampType", 0);
                    break;
                case LightRampType.Vertical:
                    material.SetFloat("_LightRampType", 1);
                    break;
                case LightRampType.None:
                    material.SetFloat("_LightRampType", 2);
                    break;
                default:
                    break;
            }
        }

        public static void SetupMaterialWithVertexColorType(Material material, VertexColorType vertexColorType)
        {
            switch ((VertexColorType)material.GetFloat("_VertexColorType"))
            {
                case VertexColorType.Color:
                    material.SetFloat("_VertexColorType", 0);
                    break;
                case VertexColorType.OutlineColor:
                    material.SetFloat("_VertexColorType", 1);
                    break;
                case VertexColorType.AdditionalData:
                    material.SetFloat("_VertexColorType", 2);
                    break;
                default:
                    break;
            }
        }
            
        public static void SetupMaterialWithLightingCalculationType(Material material, LightingCalculationType LightingCalculationType)
        {
            switch ((LightingCalculationType)material.GetFloat("_LightingCalculationType"))
            {   
                case LightingCalculationType.Standard:
                    material.SetFloat("_LightingCalculationType", 1);
                    break;
                case LightingCalculationType.Cubed:
                    material.SetFloat("_LightingCalculationType", 2);
                    break;
                case LightingCalculationType.Directional:
                    material.SetFloat("_LightingCalculationType", 3);
                    break;
                default:
                case LightingCalculationType.Arktoon:
                    material.SetFloat("_LightingCalculationType", 0);
                    break;
            }
        }

protected void UpgradeMatcaps(Material material)
{
    // Check if the new properties exist.
    // NOTE: This is written with the current Unity behaviour in mind.
    // - GetFloat returns NULL for properties not in the CURRENT shader.
    // - GetTexture returns textures for properties not in the current shader.
    // If GetFloat gets changed, intensity transfer will work.
    // If GetTexture gets changed, the whole thing will break. 

    bool oldMatcaps = 
        (material.GetFloat("_UseMatcap") == 1.0) &&
        (material.GetFloat("_Matcap1Strength") == 1.0 && material.GetFloat("_Matcap2Strength") == 1.0 &&
         material.GetFloat("_Matcap3Strength") == 1.0 && material.GetFloat("_Matcap4Strength") == 1.0) &&
        (matcap1.textureValue == null && matcap2.textureValue == null &&
         matcap3.textureValue == null && matcap4.textureValue == null) &&
         material.GetTexture("_AdditiveMatcap"); // Only exists in old materials.
    if (oldMatcaps)
        {
        // GetFloat is bugged but GetTexture is not, so we use GetFloatProperty so we can handle null.
        float? additiveStrength = GetFloatProperty(material, "_AdditiveMatcapStrength");
        float? multiplyStrength = GetFloatProperty(material, "_MultiplyMatcapStrength");
        float? medianStrength = GetFloatProperty(material, "_MidBlendMatcapStrength");
        Texture additiveMatcap = material.GetTexture("_AdditiveMatcap");
        Texture multiplyMatcap = material.GetTexture("_MultiplyMatcap");
        Texture medianMatcap = material.GetTexture("_MidBlendMatcap");

        // Mask layout is RGBA
        if (additiveMatcap)
        {
            matcap2.textureValue = additiveMatcap;
            matcap2Blend.floatValue = (float)MatcapBlendModes.Additive;
            matcap2Strength.floatValue = additiveStrength ?? 1;
        }
        if (multiplyMatcap) 
        {
            matcap4.textureValue = multiplyMatcap;
            matcap4Blend.floatValue = (float)MatcapBlendModes.Multiply;
            matcap4Strength.floatValue = multiplyStrength ?? 0; 
            // Multiply at 1.0 is usually wrong. This also prevents oldMatcaps fron being true.
        }
        if (medianMatcap) 
        {
            matcap3.textureValue = medianMatcap;
            matcap3Blend.floatValue = (float)MatcapBlendModes.Median;
            matcap3Strength.floatValue = medianStrength ?? 1;
        }
        }
}

        // Taken from Standard. Only Standard keywords are set here!
        protected static void SetMaterialKeywords(Material material)
        {
            // Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
            // (MaterialProperty value might come from renderer material property block)
            SetKeyword(material, "_NORMALMAP", material.GetTexture("_BumpMap") && material.GetTexture("_DetailNormalMap"));
            /*
            SetKeyword(material, "_SPECGLOSSMAP", material.GetTexture("_SpecGlossMap"));
            SetKeyword(material, "_PARALLAXMAP", material.GetTexture("_ParallaxMap"));
            SetKeyword(material, "_DETAIL_MULX2", material.GetTexture("_DetailAlbedoMap") 
                && material.GetTexture("_DetailNormalMap")
                && material.GetTexture("_DetailEmissionMap")
                && material.GetTexture("_SpecularDetailMask"));
            */

            // A material's GI flag internally keeps track of whether emission is enabled at all, it's enabled but has no effect
            // or is enabled and may be modified at runtime. This state depends on the values of the current flag and emissive color.
            // The fixup routine makes sure that the material is in the correct state if/when changes are made to the mode or color.
            MaterialEditor.FixupEmissiveFlag(material);
            bool shouldEmissionBeEnabled = (material.globalIlluminationFlags & MaterialGlobalIlluminationFlags.EmissiveIsBlack) == 0;
            SetKeyword(material, "_EMISSION", shouldEmissionBeEnabled);
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

        protected static void SetKeyword(Material m, string keyword, bool state)
        {
            if (state)
                m.EnableKeyword(keyword);
            else
                m.DisableKeyword(keyword);
        }
    }

}