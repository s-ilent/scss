using UnityEditor;
using UnityEngine;
using System;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;
using static SilentCelShading.Unity.InspectorCommon;

// Parts of this file are based on https://github.com/Microsoft/MixedRealityToolkit-Unity/
//	Copyright (c) Microsoft Corporation. All rights reserved.
//	Licensed under the MIT License.

namespace SilentCelShading.Unity
{
	public class Inspector : SCSSShaderGUI
	{

		public enum ShadowMaskType
		{
			Occlusion,
			Tone,
			Auto
		}

		public enum LightRampType
		{
			Horizontal,
			Vertical,
			None
		}

		public enum ToneSeparationType
		{
			Combined,
			Separate
		}

		public enum IndirectShadingType
		{
			Dynamic,
			Directional,
			Flatten
		}

		public static class LightrampStyles
		{
			public static GUIContent lightingRamp = new GUIContent("Lighting Ramp", "Specifies the falloff of the lighting. In other words, it controls how light affects your model and how soft or sharp the transition between light and shadow is. \nNote: If a Lighting Ramp is not set, the material will have no shading.");
			public static GUIContent shadowMask = new GUIContent("Shadow Mask", "In Occlusion mode, specifies areas of shadow influence. RGB darkens, alpha lightens. In Tone mode, specifies colour of shading to use. RGB tints, alpha darkens.");

			public static GUIContent shadowLift = new GUIContent("Shadow Lift", "Increasing this warps the lighting received to make more things lit.");
			public static GUIContent indirectLightBoost = new GUIContent("Indirect Lighting Boost", "Blends the lighting of shadows with the lighting of direct light, making them brighter.");
			public static GUIContent shadowMaskPow = new GUIContent("Shadow Mask Lightening", "Sets the power of the shadow mask.");

			public static GUIContent lightRampType = new GUIContent("Lighting Ramp Type", "For if you use lightramps that run from bottom to top instead of left to right, or none at all.");
			public static GUIContent shadowMaskType = new GUIContent("Shadow Mask Style", "Changes how the shadow mask is used.");
			public static GUIContent vertexColorType = new GUIContent("Vertex Colour Type", "Sets how the vertex colour should be used. Outline only affects the colour of outlines. Additional data uses the red channel for outline width and the green for ramp softness. ");

			public static GUIContent gradientEditorButton = new GUIContent("Open Gradient Editor","Opens the gradient editor window with the current material focused. This allows you to create a new lighting ramp and view the results on this material in realtime.");
		} 

		public static class CrosstoneStyles
		{
			public static GUIContent useToneSeparation = new GUIContent("Tone Blending Mode", "Specifies the method used to blend tone with the albedo texture. Combined will merge one over the other, while Seperate will not.");
			public static GUIContent shadeMap1 = new GUIContent("1st Shading Tone", "Specifies the colour of shading to use for the first gradation. Tinted by the colour field.");
			public static GUIContent shadeMap1Color = new GUIContent("1st Shading Colour");
			public static GUIContent shadeMap1Step = new GUIContent("1st Shading Breakpoint", "Sets the point at which the shading begins to transition from lit to shaded, based on the light hitting the material.");
			public static GUIContent shadeMap1Feather = new GUIContent("1st Shading Width", "Sets the width of the transition between lit and shaded.");
			public static GUIContent shadeMap2 = new GUIContent("2nd Shading Tone", "Specifies the colour of shading to use for the second gradation. Tinted by the colour field.");
			public static GUIContent shadeMap2Color = new GUIContent("2nd Shading Colour");
			public static GUIContent shadeMap2Step = new GUIContent("2nd Shading Breakpoint", "Sets the point at which the shading begins to transition from shaded to fully shaded, based on the light hitting the material.");
			public static GUIContent shadeMap2Feather = new GUIContent("1st Shading Width", "Sets the width of the transition between shaded and fully shaded.");
			public static GUIContent shadingGradeMap = new GUIContent("Shading Adjustment Map", "Adds additional shading to darkened regions, and acts as occlusion. The slider adjusts the map further.");
			public static GUIContent shadingGradeMapLevel = new GUIContent("Shading Adjustment Level", "Modifies the middle point of the shading adjustment.");
		} 

#region MaterialProperty definitions
		protected MaterialProperty mainTexture;
		protected MaterialProperty color;
		protected MaterialProperty colorMask;
		protected MaterialProperty albedoAlphaMode;
		protected MaterialProperty clippingMask;

		protected MaterialProperty outlineMode;
		protected MaterialProperty outlineWidth;
		protected MaterialProperty outlineColor;
		protected MaterialProperty outlineMask;
		protected MaterialProperty emissionMap;
		protected MaterialProperty emissionDetailMask;
		protected MaterialProperty emissionDetailParams;
		protected MaterialProperty emissionColor;
		protected MaterialProperty customFresnelColor;

		protected MaterialProperty normalMap;
		protected MaterialProperty normalMapScale;

		protected MaterialProperty useDetailMaps;
		protected MaterialProperty detailAlbedoMap;
		protected MaterialProperty detailAlbedoMapScale;
		protected MaterialProperty detailNormalMap;
		protected MaterialProperty detailNormalMapScale;
		protected MaterialProperty specularDetailMask;
		protected MaterialProperty specularDetailStrength;
		protected MaterialProperty uvSetSecondary;

		protected MaterialProperty specularMap;
		protected MaterialProperty specularTint;
		protected MaterialProperty smoothness;
		protected MaterialProperty anisotropy;
		protected MaterialProperty useMetallic;
		protected MaterialProperty celSpecularSoftness;
		protected MaterialProperty celSpecularSteps;

		protected MaterialProperty useFresnel;
		protected MaterialProperty fresnelWidth;
		protected MaterialProperty fresnelStrength;
		protected MaterialProperty fresnelTint;

		protected MaterialProperty useFresnelLightMask;
		protected MaterialProperty fresnelLightMask;
		protected MaterialProperty fresnelTintInv;
		protected MaterialProperty fresnelWidthInv;
		protected MaterialProperty fresnelStrengthInv;

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

		protected MaterialProperty useAnimation;
		protected MaterialProperty animationSpeed;
		protected MaterialProperty animationTotalFrames;
		protected MaterialProperty animationFrameNumber;
		protected MaterialProperty animationColumns;
		protected MaterialProperty animationRows;

		protected MaterialProperty useVanishing;
		protected MaterialProperty vanishingStart;
		protected MaterialProperty vanishingEnd;

		protected MaterialProperty lightingRamp;
		protected MaterialProperty shadowLift; 
		protected MaterialProperty shadowMask;
		protected MaterialProperty shadowMaskPow;
		protected MaterialProperty shadowMaskColor;
		protected MaterialProperty indirectLightBoost;
		protected MaterialProperty lightRampType;
		protected MaterialProperty shadowMaskType;

		protected MaterialProperty useToneSeparation;
		protected MaterialProperty shadeMap1;
		protected MaterialProperty shadeMap1Color;
		protected MaterialProperty shadeMap1Step;
		protected MaterialProperty shadeMap1Feather;
		protected MaterialProperty shadeMap2;
		protected MaterialProperty shadeMap2Color;
		protected MaterialProperty shadeMap2Step;
		protected MaterialProperty shadeMap2Feather;
		protected MaterialProperty shadingGradeMap;
		protected MaterialProperty shadingGradeMapLevel;

		protected MaterialProperty vertexColorType;

		protected MaterialProperty lightingCalculationType;
		protected MaterialProperty indirectShadingType;
		protected MaterialProperty lightSkew;
		protected MaterialProperty pixelSampleMode;
		protected MaterialProperty highlights;
		protected MaterialProperty reflections;
		protected MaterialProperty diffuseGeomShadowFactor;
		protected MaterialProperty lightWrappingCompensationFactor;
#endregion

		protected bool usingLightramp = true; // Compatibility
		protected bool usingCrosstone = false;

		protected void CheckShaderType(Material material)
		{
			// Check material type
			const string crosstoneName = "Crosstone";
			usingCrosstone = material.shader.name.Contains(crosstoneName);

			const string lightrampName = "Lightramp";
			usingLightramp = material.shader.name.Contains(lightrampName);

			// Short circuit for old materials.
			const string hiddenName = "Old";
			if (material.shader.name.Contains(hiddenName)) UpgradeVariantCheck(material);
		}

		public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
		{ 
			Material material = (Material)materialEditor.target;

			CheckShaderType(material);

			base.OnGUI(materialEditor, props);

			MainOptions(materialEditor, material);
			if (usingLightramp) LightrampOptions(materialEditor, material);
			if (usingCrosstone) CrosstoneOptions(materialEditor, material);
			RenderingOptions(materialEditor, material);
			MatcapOptions(materialEditor, material);
			SubsurfaceOptions(materialEditor, material);
			DetailMapOptions(materialEditor, material);
			AnimationOptions(materialEditor, material);
			VanishingOptions(materialEditor, material);
			OutlineOptions(materialEditor, material);
			AdvancedOptions(materialEditor, material);
		}

		protected void FindLightrampProperties(MaterialProperty[] props)
		{
			lightingRamp = FindProperty("_Ramp", props);
			indirectLightBoost = FindProperty("_IndirectLightingBoost", props);
			shadowLift = FindProperty("_ShadowLift", props);
			shadowMask = FindProperty("_ShadowMask", props);
			shadowMaskPow = FindProperty("_Shadow", props);
			shadowMaskColor = FindProperty("_ShadowMaskColor", props);
			lightRampType = FindProperty("_LightRampType", props);
			shadowMaskType = FindProperty("_ShadowMaskType", props);
		}

		protected void FindCrosstoneProperties(MaterialProperty[] props)
		{
 			useToneSeparation = FindProperty("_CrosstoneToneSeparation", props);
 			shadeMap1 = FindProperty("_1st_ShadeMap", props);
 			shadeMap1Color = FindProperty("_1st_ShadeColor", props);
 			shadeMap1Step = FindProperty("_1st_ShadeColor_Step", props);
 			shadeMap1Feather = FindProperty("_1st_ShadeColor_Feather", props);
 			shadeMap2 = FindProperty("_2nd_ShadeMap", props);
 			shadeMap2Color = FindProperty("_2nd_ShadeColor", props);
 			shadeMap2Step = FindProperty("_2nd_ShadeColor_Step", props);
 			shadeMap2Feather = FindProperty("_2nd_ShadeColor_Feather", props);
 			shadingGradeMap = FindProperty("_ShadingGradeMap", props);
 			shadingGradeMapLevel = FindProperty("_Tweak_ShadingGradeMapLevel", props);
		}

		protected void FindMatcapProperties(MaterialProperty[] props)
		{
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
		}

		protected void FindSpecularProperties(MaterialProperty[] props)
		{
			specularMap = FindProperty("_SpecGlossMap", props);
			specularTint = FindProperty("_SpecColor", props);
			smoothness = FindProperty("_Smoothness", props);
			celSpecularSoftness = FindProperty("_CelSpecularSoftness", props);
			celSpecularSteps = FindProperty("_CelSpecularSteps", props);
			anisotropy = FindProperty("_Anisotropy", props);
			useMetallic = FindProperty("_UseMetallic", props);
			useEnergyConservation = FindProperty("_UseEnergyConservation", props);
			specularType = FindProperty("_SpecularType", props);

			highlights = FindProperty("_SpecularHighlights", props, false);
			reflections = FindProperty("_GlossyReflections", props, false); 
		}

		protected void FindScatteringProperties(MaterialProperty[] props)
		{
			useSubsurfaceScattering = FindProperty("_UseSubsurfaceScattering", props);
			thicknessMap = FindProperty("_ThicknessMap", props);
			thicknessMapPower = FindProperty("_ThicknessMapPower", props);
			thicknessInvert = FindProperty("_ThicknessMapInvert", props);
			scatteringColor = FindProperty("_SSSCol", props);
			scatteringIntensity = FindProperty("_SSSIntensity", props);
			scatteringPower = FindProperty("_SSSPow", props);
			scatteringDistortion = FindProperty("_SSSDist", props);
			scatteringAmbient = FindProperty("_SSSAmbient", props);
		}

		protected void FindDetailMapProperties(MaterialProperty[] props)
		{
			useDetailMaps = FindProperty("_UseDetailMaps", props);
			detailAlbedoMap = FindProperty("_DetailAlbedoMap", props);
			detailAlbedoMapScale = FindProperty("_DetailAlbedoMapScale", props);
			detailNormalMap = FindProperty("_DetailNormalMap", props);
			detailNormalMapScale = FindProperty("_DetailNormalMapScale", props);
			specularDetailMask = FindProperty("_SpecularDetailMask", props);
			specularDetailStrength = FindProperty("_SpecularDetailStrength", props);
			uvSetSecondary = FindProperty("_UVSec", props);
		}

		protected void FindAnimationProperties(MaterialProperty[] props)
		{
			useAnimation = FindProperty("_UseAnimation", props);
			animationSpeed = FindProperty("_AnimationSpeed", props);
			animationTotalFrames = FindProperty("_TotalFrames", props);
			animationFrameNumber = FindProperty("_FrameNumber", props);
			animationColumns = FindProperty("_Columns", props);
			animationRows = FindProperty("_Rows", props);
		}

		protected void FindVanishingProperties(MaterialProperty[] props)
		{
			vanishingStart = FindProperty("_VanishingStart", props);
			vanishingEnd = FindProperty("_VanishingEnd", props);
			useVanishing = FindProperty("_UseVanishing", props);
		}

		protected override void FindProperties(MaterialProperty[] props)
		{ 
			base.FindProperties(props);

			mainTexture = FindProperty("_MainTex", props);
			color = FindProperty("_Color", props);
			colorMask = FindProperty("_ColorMask", props);
			albedoAlphaMode = FindProperty("_AlbedoAlphaMode", props);
			clippingMask = FindProperty("_ClippingMask", props);

			alphaCutoff = FindProperty("_Cutoff", props);
			alphaSharp = FindProperty("_AlphaSharp", props);

			normalMap = FindProperty("_BumpMap", props);
			normalMapScale = FindProperty("_BumpScale", props);

			outlineMode = FindProperty("_OutlineMode", props);
			outlineWidth = FindProperty("_outline_width", props);
			outlineColor = FindProperty("_outline_color", props);
			outlineMask = FindProperty("_OutlineMask", props);

			emissionMap = FindProperty("_EmissionMap", props);
			emissionDetailMask = FindProperty("_DetailEmissionMap", props);
			emissionDetailParams = FindProperty("_EmissionDetailParams", props);
			emissionColor = FindProperty("_EmissionColor", props);
			customFresnelColor = FindProperty("_CustomFresnelColor", props);

			useFresnel = FindProperty("_UseFresnel", props);
			fresnelWidth = FindProperty("_FresnelWidth", props);
			fresnelStrength = FindProperty("_FresnelStrength", props);
			fresnelTint = FindProperty("_FresnelTint", props);

			useFresnelLightMask = FindProperty("_UseFresnelLightMask", props);
			fresnelLightMask = FindProperty("_FresnelLightMask", props);
			fresnelTintInv = FindProperty("_FresnelTintInv", props);
			fresnelWidthInv = FindProperty("_FresnelWidthInv", props);
			fresnelStrengthInv = FindProperty("_FresnelStrengthInv", props);

			if (usingLightramp) FindLightrampProperties(props);
			if (usingCrosstone) FindCrosstoneProperties(props);
			FindMatcapProperties(props);
			FindSpecularProperties(props);
			FindScatteringProperties(props);
			FindDetailMapProperties(props);
			FindAnimationProperties(props);
			FindVanishingProperties(props);

			vertexColorType = FindProperty("_VertexColorType", props);

			lightingCalculationType = FindProperty("_LightingCalculationType", props);
			indirectShadingType = FindProperty("_IndirectShadingType", props);
			lightSkew = FindProperty("_LightSkew", props);
			pixelSampleMode = FindProperty("_PixelSampleMode", props); 
			diffuseGeomShadowFactor = FindProperty("_DiffuseGeomShadowFactor", props); 
			lightWrappingCompensationFactor = FindProperty("_LightWrappingCompensationFactor", props); 
		}

		protected override void MaterialChanged(Material material)
		{
			// Handle old materials
			UpgradeMatcaps(material);
			UpgradeVariantCheck(material);

			SetupMaterialWithAlbedo(material, 
				mainTexture, 
				albedoAlphaMode);
			SetupMaterialWithOutlineMode(material, 
				(OutlineMode)outlineMode.floatValue);

			SetMaterialKeywords(material);

			base.MaterialChanged(material);
		}

		protected void MainOptions(MaterialEditor materialEditor, Material material)
		{ 
			EditorGUIUtility.labelWidth = 0f;
			EditorGUILayout.Space();
			
			{
				EditorGUI.BeginChangeCheck();
				GUILayout.Label(CommonStyles.mainOptionsTitle, EditorStyles.boldLabel);

				materialEditor.TexturePropertySingleLine(CommonStyles.mainTexture, mainTexture, color);
				materialEditor.TexturePropertySingleLine(CommonStyles.normalMap, normalMap, normalMapScale);

				if ((AlbedoAlphaMode)albedoAlphaMode.floatValue == AlbedoAlphaMode.ClippingMask)
				{
					materialEditor.TexturePropertySingleLine(CommonStyles.clippingMask, clippingMask);
				}

				EditorGUI.indentLevel += 2;
				if ((RenderingMode)renderingMode.floatValue == RenderingMode.Cutout)
				{
					materialEditor.ShaderProperty(alphaCutoff, CommonStyles.alphaCutoff.text);
					materialEditor.ShaderProperty(alphaSharp, CommonStyles.alphaSharp.text);
				}
				EditorGUI.indentLevel -= 2;
				materialEditor.TexturePropertySingleLine(CommonStyles.colorMask, colorMask);
				EditorGUILayout.Space();
			}
			EditorGUI.EndChangeCheck();

			EditorGUI.BeginChangeCheck();
			materialEditor.TextureScaleOffsetProperty(mainTexture);
			if (EditorGUI.EndChangeCheck())
			emissionMap.textureScaleAndOffset = mainTexture.textureScaleAndOffset;			 
			EditorGUILayout.Space();
		}

        protected void LightrampOptions(MaterialEditor materialEditor, Material material)
        { 
			EditorGUILayout.LabelField(CommonStyles.shadingOptionsTitle, EditorStyles.boldLabel);

            var lMode = (LightRampType)lightRampType.floatValue;
            EditorGUI.BeginChangeCheck();
            
            lMode = (LightRampType)EditorGUILayout.Popup("Lighting Ramp Type", (int)lMode, Enum.GetNames(typeof(LightRampType)));

            if (EditorGUI.EndChangeCheck())
            {
                materialEditor.RegisterPropertyChangeUndo("Lighting Ramp Type");
                lightRampType.floatValue = (float)lMode;

                foreach (var obj in lightRampType.targets)
                {
                    SetupMaterialWithLightRampType((Material)obj, (LightRampType)material.GetFloat("_LightRampType"));
                }

            } 
            if (((LightRampType)material.GetFloat("_LightRampType")) != LightRampType.None) 
            {

                GUILayout.BeginHorizontal();
                materialEditor.TexturePropertySingleLine(LightrampStyles.lightingRamp, lightingRamp);
                if (GUILayout.Button(LightrampStyles.gradientEditorButton, "button"))
                {
                    XSGradientEditor.callGradientEditor(material);
                }
                GUILayout.EndHorizontal();
            }
            materialEditor.ShaderProperty(shadowLift, LightrampStyles.shadowLift);
            materialEditor.ShaderProperty(indirectLightBoost, LightrampStyles.indirectLightBoost);
            //
            EditorGUILayout.Space();

            materialEditor.TexturePropertySingleLine(LightrampStyles.shadowMask, shadowMask, shadowMaskColor);

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

            materialEditor.ShaderProperty(shadowMaskPow, LightrampStyles.shadowMaskPow); 
        }

		protected void CrosstoneOptions(MaterialEditor materialEditor, Material material)
		{ 
			EditorGUILayout.LabelField(CommonStyles.shadingOptionsTitle, EditorStyles.boldLabel);

			materialEditor.ShaderProperty(useToneSeparation, CrosstoneStyles.useToneSeparation);

            EditorGUILayout.Space();
			materialEditor.TexturePropertySingleLine(CrosstoneStyles.shadeMap1, shadeMap1, shadeMap1Color);
			materialEditor.ShaderProperty(shadeMap1Step, CrosstoneStyles.shadeMap1Step);
			materialEditor.ShaderProperty(shadeMap1Feather, CrosstoneStyles.shadeMap1Feather);
			
			EditorGUILayout.Space();
			materialEditor.TexturePropertySingleLine(CrosstoneStyles.shadeMap2, shadeMap2, shadeMap2Color);
			materialEditor.ShaderProperty(shadeMap2Step, CrosstoneStyles.shadeMap2Step);
			materialEditor.ShaderProperty(shadeMap2Feather, CrosstoneStyles.shadeMap2Feather);
			
			EditorGUILayout.Space();
			materialEditor.TexturePropertySingleLine(CrosstoneStyles.shadingGradeMap, shadingGradeMap, shadingGradeMapLevel);
		}

		protected void RenderingOptions(MaterialEditor materialEditor, Material material)
		{ 
			EditorGUILayout.Space();
			EditorGUILayout.LabelField(CommonStyles.renderingOptionsTitle, EditorStyles.boldLabel);

			SpecularOptions(materialEditor, material);
			RimlightOptions(materialEditor, material);

			EditorGUI.BeginChangeCheck();
			materialEditor.TexturePropertySingleLine(CommonStyles.emissionMap, emissionMap, emissionColor);  
			materialEditor.ShaderProperty(customFresnelColor, CommonStyles.customFresnelColor, 2);			
			EditorGUILayout.Space();
			
			EditorGUI.EndChangeCheck();
		}

		protected void AnimationOptions(MaterialEditor materialEditor, Material material)
		{ 
			EditorGUI.BeginChangeCheck();
			materialEditor.ShaderProperty(useAnimation, CommonStyles.useAnimation);
			if (PropertyEnabled(useAnimation))
			{
				materialEditor.ShaderProperty(animationSpeed, CommonStyles.animationSpeed);
				materialEditor.ShaderProperty(animationTotalFrames, CommonStyles.animationTotalFrames);
				materialEditor.ShaderProperty(animationFrameNumber, CommonStyles.animationFrameNumber);
				materialEditor.ShaderProperty(animationColumns, CommonStyles.animationColumns);
				materialEditor.ShaderProperty(animationRows, CommonStyles.animationRows);
			}

		}

		protected void VanishingOptions(MaterialEditor materialEditor, Material material)
		{ 
			EditorGUI.BeginChangeCheck();
			materialEditor.ShaderProperty(useVanishing, CommonStyles.useVanishing);
			if (PropertyEnabled(useVanishing))
			{
				materialEditor.ShaderProperty(vanishingStart, CommonStyles.vanishingStart);
				materialEditor.ShaderProperty(vanishingEnd, CommonStyles.vanishingEnd);
			}

		}

		protected void RimlightOptions(MaterialEditor materialEditor, Material material)
		{	
			EditorGUI.BeginChangeCheck();
			materialEditor.ShaderProperty(useFresnel, CommonStyles.useFresnel);
			bool isTintable = 
				(AmbientFresnelType)useFresnel.floatValue == AmbientFresnelType.Lit
				|| (AmbientFresnelType)useFresnel.floatValue == AmbientFresnelType.Ambient;

			if (PropertyEnabled(useFresnel))
			{
				materialEditor.ShaderProperty(fresnelWidth, CommonStyles.fresnelWidth);
				materialEditor.ShaderProperty(fresnelStrength, CommonStyles.fresnelStrength);
				if (isTintable) materialEditor.ShaderProperty(fresnelTint, CommonStyles.fresnelTint);	

				materialEditor.ShaderProperty(useFresnelLightMask, CommonStyles.useFresnelLightMask);
				if (PropertyEnabled(useFresnelLightMask))
				{
					EditorGUI.indentLevel += 2;
					materialEditor.ShaderProperty(fresnelLightMask, CommonStyles.fresnelLightMask);
					if (isTintable) materialEditor.ShaderProperty(fresnelTintInv, CommonStyles.fresnelTintInv);
					materialEditor.ShaderProperty(fresnelWidthInv, CommonStyles.fresnelWidthInv);
					materialEditor.ShaderProperty(fresnelStrengthInv, CommonStyles.fresnelStrengthInv);
					EditorGUI.indentLevel -= 2;
				}
			}
			EditorGUILayout.Space();
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
				materialEditor.TexturePropertySingleLine(CommonStyles.specularMap, specularMap, specularTint);
				materialEditor.ShaderProperty(smoothness, CommonStyles.smoothness);
				materialEditor.ShaderProperty(useMetallic, CommonStyles.useMetallic);
				materialEditor.ShaderProperty(useEnergyConservation, CommonStyles.useEnergyConservation);
				break;
				case SpecularType.Cel:
				materialEditor.TexturePropertySingleLine(CommonStyles.specularMap, specularMap, specularTint);
				materialEditor.ShaderProperty(smoothness, CommonStyles.smoothness);
				materialEditor.ShaderProperty(celSpecularSoftness, CommonStyles.celSpecularSoftness);
				materialEditor.ShaderProperty(celSpecularSteps, CommonStyles.celSpecularSteps);
				materialEditor.ShaderProperty(useMetallic, CommonStyles.useMetallic);
				materialEditor.ShaderProperty(useEnergyConservation, CommonStyles.useEnergyConservation);
				break;
				case SpecularType.Anisotropic:
				materialEditor.TexturePropertySingleLine(CommonStyles.specularMap, specularMap, specularTint);
				materialEditor.ShaderProperty(smoothness, CommonStyles.smoothness);
				materialEditor.ShaderProperty(anisotropy, CommonStyles.anisotropy);
				materialEditor.ShaderProperty(useMetallic, CommonStyles.useMetallic);
				materialEditor.ShaderProperty(useEnergyConservation, CommonStyles.useEnergyConservation);
				break;
				case SpecularType.CelStrand:
				materialEditor.TexturePropertySingleLine(CommonStyles.specularMap, specularMap, specularTint);
				materialEditor.ShaderProperty(smoothness, CommonStyles.smoothness);
				materialEditor.ShaderProperty(celSpecularSoftness, CommonStyles.celSpecularSoftness);
				materialEditor.ShaderProperty(celSpecularSteps, CommonStyles.celSpecularSteps);
				materialEditor.ShaderProperty(anisotropy, CommonStyles.anisotropy);
				materialEditor.ShaderProperty(useMetallic, CommonStyles.useMetallic);
				materialEditor.ShaderProperty(useEnergyConservation, CommonStyles.useEnergyConservation);
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
			materialEditor.ShaderProperty(useDetailMaps, CommonStyles.useDetailMaps);

			if (PropertyEnabled(useDetailMaps)) 
			{
				material.EnableKeyword("_DETAIL_MULX2");
				materialEditor.TexturePropertySingleLine(CommonStyles.detailAlbedoMap, detailAlbedoMap, detailAlbedoMapScale);
				materialEditor.TexturePropertySingleLine(CommonStyles.detailNormalMap, detailNormalMap, detailNormalMapScale);
				materialEditor.TexturePropertySingleLine(CommonStyles.specularDetailMask, specularDetailMask, specularDetailStrength);
				materialEditor.TexturePropertySingleLine(CommonStyles.emissionDetailMask, emissionDetailMask);
				materialEditor.ShaderProperty(emissionDetailParams, CommonStyles.emissionDetailParams);
				
				materialEditor.TextureScaleOffsetProperty(detailAlbedoMap);
				materialEditor.ShaderProperty(uvSetSecondary, CommonStyles.uvSet);
			} else {
				material.DisableKeyword("_DETAIL_MULX2");
			}
			EditorGUILayout.Space();

			EditorGUI.EndChangeCheck();	 
		}

		protected void MatcapOptions(MaterialEditor materialEditor, Material material)
		{ 
			EditorGUILayout.Space();
			EditorGUILayout.LabelField(CommonStyles.matcapTitle, EditorStyles.boldLabel);
			
			var mMode = (MatcapType)useMatcap.floatValue;

			EditorGUI.BeginChangeCheck();
			
			mMode = (MatcapType)EditorGUILayout.Popup("Matcap Style", 
				(int)mMode, Enum.GetNames(typeof(MatcapType)));
			if (EditorGUI.EndChangeCheck())
			{
				materialEditor.RegisterPropertyChangeUndo("Matcap Style");
				useMatcap.floatValue = (float)mMode;
			}

			EditorGUI.BeginChangeCheck();
			if (PropertyEnabled(useMatcap))
			{
				materialEditor.TexturePropertySingleLine(CommonStyles.matcapMask, matcapMask);
				materialEditor.TexturePropertySingleLine(CommonStyles.matcap1Tex, matcap1, matcap1Strength, matcap1Blend);
				materialEditor.TexturePropertySingleLine(CommonStyles.matcap2Tex, matcap2, matcap2Strength, matcap2Blend);
				materialEditor.TexturePropertySingleLine(CommonStyles.matcap3Tex, matcap3, matcap3Strength, matcap3Blend);
				materialEditor.TexturePropertySingleLine(CommonStyles.matcap4Tex, matcap4, matcap4Strength, matcap4Blend);
			}
			
			EditorGUI.EndChangeCheck();
		}

		protected void SubsurfaceOptions(MaterialEditor materialEditor, Material material)
		{ 
			EditorGUILayout.Space();
			
			EditorGUI.BeginChangeCheck();
			{
				materialEditor.ShaderProperty(useSubsurfaceScattering, CommonStyles.useSubsurfaceScattering);

				if (PropertyEnabled(useSubsurfaceScattering))
				{
					materialEditor.TexturePropertySingleLine(CommonStyles.thicknessMap, thicknessMap);
					materialEditor.ShaderProperty(thicknessMapPower, CommonStyles.thicknessMapPower);
					materialEditor.ShaderProperty(thicknessInvert, CommonStyles.thicknessInvert);
					materialEditor.ShaderProperty(scatteringColor, CommonStyles.scatteringColor);
					materialEditor.ShaderProperty(scatteringIntensity, CommonStyles.scatteringIntensity);
					materialEditor.ShaderProperty(scatteringPower, CommonStyles.scatteringPower);
					materialEditor.ShaderProperty(scatteringDistortion, CommonStyles.scatteringDistortion);
					materialEditor.ShaderProperty(scatteringAmbient, CommonStyles.scatteringAmbient);
				}
			} 
			EditorGUI.EndChangeCheck();
		}

		protected void OutlineOptions(MaterialEditor materialEditor, Material material)
		{ 
			EditorGUILayout.Space();
			var oMode = (OutlineMode)outlineMode.floatValue;

			EditorGUI.BeginChangeCheck();
			EditorGUILayout.LabelField(CommonStyles.outlineOptionsTitle, EditorStyles.boldLabel);
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
				materialEditor.TexturePropertySingleLine(CommonStyles.outlineMask, outlineMask);
				materialEditor.ShaderProperty(outlineColor, CommonStyles.outlineColor);
				materialEditor.ShaderProperty(outlineWidth, CommonStyles.outlineWidth);
				break;
				case OutlineMode.None:
				default:
				break;
			}	  
		}

		protected void AdvancedOptions(MaterialEditor materialEditor, Material material)
		{
			EditorGUILayout.Space();
			if (GUILayout.Button(CommonStyles.manualButton, "button"))
			{
				Application.OpenURL("https://gitlab.com/s-ilent/SCSS/wikis/Manual/Setting-Overview");
			}
			EditorGUILayout.Space();

			GUILayout.Label(CommonStyles.advancedOptionsTitle, EditorStyles.boldLabel);

			EditorGUI.BeginChangeCheck();

			materialEditor.ShaderProperty(pixelSampleMode, CommonStyles.pixelSampleMode);

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

			var aaMode = (AlbedoAlphaMode)albedoAlphaMode.floatValue;
			EditorGUI.BeginChangeCheck();

			aaMode = (AlbedoAlphaMode)EditorGUILayout.Popup(albedoAlphaMode.displayName, (int)aaMode, CommonStyles.albedoAlphaModeNames);

			if (EditorGUI.EndChangeCheck())
			{
				materialEditor.RegisterPropertyChangeUndo("Albedo Alpha Mode");
				albedoAlphaMode.floatValue = (float)aaMode;

				foreach (var obj in albedoAlphaMode.targets)
				{
					SetupMaterialWithAlbedo((Material)obj, mainTexture, albedoAlphaMode);
				}

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

			materialEditor.ShaderProperty(indirectShadingType, CommonStyles.indirectShadingType);

			EditorGUILayout.Space();

			materialEditor.ShaderProperty(diffuseGeomShadowFactor, CommonStyles.diffuseGeomShadowFactor);
			materialEditor.ShaderProperty(lightWrappingCompensationFactor, CommonStyles.lightWrappingCompensationFactor);

			materialEditor.ShaderProperty(lightSkew, CommonStyles.lightSkew);

			EditorGUI.BeginChangeCheck();

			if (highlights != null)
			materialEditor.ShaderProperty(highlights, CommonStyles.highlights);
			if (reflections != null)
			materialEditor.ShaderProperty(reflections, CommonStyles.reflections);

			if (EditorGUI.EndChangeCheck())
			{
				MaterialChanged(material);
			}

			EditorGUILayout.Space();

			StencilOptions(materialEditor, material);

			EditorGUI.BeginChangeCheck();

			materialEditor.ShaderProperty(renderQueueOverride, BaseStyles.renderQueueOverride);

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
				case ShadowMaskType.Auto:
				material.SetFloat("_ShadowMaskType", 2);
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

protected float? GetSerializedMaterialFloat(Material material, string propName)
{
	float? floatVal = new SerializedObject(material).FindProperty("m_SavedProperties.m_Floats." + propName).floatValue;
	return floatVal;
}

protected Vector4? GetSerializedMaterialVector4(Material material, string propName)
{
	Vector4? colorVal = new SerializedObject(material).FindProperty("m_SavedProperties.m_Colors." + propName).colorValue;
	return colorVal;
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
			// Multiply at 1.0 is usually wrong. This also prevents oldMatcaps from being true.
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
			SetKeyword(material, "_NORMALMAP", 
				material.GetTexture("_BumpMap") && material.GetTexture("_DetailNormalMap"));
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

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            // Cache old shader properties with potentially different names than the new shader.
            Vector4? textureScaleOffset = null;
            float? cullMode = GetFloatProperty(material, "_Cull");

            Texture normalMapTexture = material.GetTexture("_BumpMap");
            float? normalMapScale = GetFloatProperty(material, "_BumpScale");
            Color? emissionColor = GetColorProperty(material, "_EmissionColor");

 			float? useToneSeparation = GetFloatProperty(material, "_CrosstoneToneSeparation");

            //shadeMap1 = GetFloatProperty(material, "_1st_ShadeMap");
            //Color? shadeMap1Color = GetFloatProperty(material, "_1st_ShadeColor");
            float? shadeMap1Step = GetFloatProperty(material, "_1st_ShadeColor_Step");
            float? shadeMap1Feather = GetFloatProperty(material, "_1st_ShadeColor_Feather");
            //shadeMap2 = GetFloatProperty(material, "_2nd_ShadeMap");
            //Color? shadeMap2Color = GetFloatProperty(material, "_2nd_ShadeColor");
            float? shadeMap2Step = GetFloatProperty(material, "_2nd_ShadeColor_Step");
            float? shadeMap2Feather = GetFloatProperty(material, "_2nd_ShadeColor_Feather");

            float? useMatcap = GetFloatProperty(material, "_UseMatcap");
            Texture matcapMask = material.GetTexture("_MatcapMask");
            Texture matcapTexture = material.GetTexture("_Matcap1");
            float? matcapBlend = GetFloatProperty(material, "_Matcap1Blend");

            float? specularType = GetFloatProperty(material, "_SpecularType");
            Texture specularMap = material.GetTexture("_SpecGlossMap");
            Color? specularTint = GetColorProperty(material, "_SpecColor");
            float? smoothness = GetFloatProperty(material, "_Smoothness");

            float? useFresnel = GetFloatProperty(material, "_UseFresnel");
            float? fresnelWidth = GetFloatProperty(material, "_FresnelWidth");
            float? fresnelStrength = GetFloatProperty(material, "_FresnelStrength");
            Color? fresnelTint = GetColorProperty(material, "_FresnelTint");

            float? useFresnelLightMask = GetFloatProperty(material, "_UseFresnelLightMask");
            float? fresnelLightMask = GetFloatProperty(material, "_FresnelLightMask");
            Color? fresnelTintInv = GetColorProperty(material, "_FresnelTintInv");
            float? fresnelWidthInv = GetFloatProperty(material, "_FresnelWidthInv");
            float? fresnelStrengthInv = GetFloatProperty(material, "_FresnelStrengthInv");

            float? outlineMode = GetFloatProperty(material, "_OutlineMode");
            float? outlineWidth = GetFloatProperty(material, "_outline_width");
            Color? outlineColor = GetColorProperty(material, "_outline_color");
            Texture outlineMask = material.GetTexture("_OutlineMask");

            int? stencilReference = GetIntProperty(material, "_Stencil");
            int? stencilComparison = GetIntProperty(material, "_StencilComp");
            int? stencilOperation = GetIntProperty(material, "_StencilOp");
            int? stencilFail = GetIntProperty(material, "_StencilFail");

            if (oldShader)
            {
            	if (oldShader.name.Contains("UnityChanToonShader"))
                {
                    normalMapTexture = material.GetTexture("_NormalMap");
                    // _Tweak_ShadingGradeMapLevel is named the same.

                    // Tone seperation is based on whether BaseAs1st is set.
                    // 1stAs2nd is seperate, but supporting it would be overengineering.
                    useToneSeparation = GetFloatProperty(material, "_Use_BaseAs1st");
                    if (useToneSeparation.HasValue) useToneSeparation = (float)1.0 - useToneSeparation;

                    // HighColor is only supported in Specular mode
                    specularMap = material.GetTexture("_HighColor_Tex");
                    specularType = GetFloatProperty(material, "_Is_SpecularToHighColor");
                    if (specularType.HasValue) specularType = (float)SpecularType.Cel * specularType;
                    specularTint = GetColorProperty(material, "_HighColor");
                    smoothness = GetFloatProperty(material, "_HighColor_Power");
                    if (smoothness.HasValue) smoothness = (float)1.0 - smoothness;

                    // Rim lighting works differently here, but there's not much we can do about it. 
                    useFresnel = GetFloatProperty(material, "_RimLight");
                    if (useFresnel.HasValue) useFresnel = (float)1.0 + useFresnel;
                    fresnelTint = GetColorProperty(material, "_RimLightColor");
                    fresnelWidth = GetFloatProperty(material, "_RimLight_Power");
                    if (fresnelWidth.HasValue) fresnelWidth = fresnelWidth * 10;
                    fresnelStrength = GetFloatProperty(material, "_RimLight_FeatherOff");
                    if (fresnelStrength.HasValue) fresnelStrength = (float)1.0 - fresnelStrength;

                    //GetFloatProperty(material, "_RimLight_FeatherOff");
                    useFresnelLightMask = GetFloatProperty(material, "_LightDirection_MaskOn");
                    fresnelLightMask = GetFloatProperty(material, "_Tweak_LightDirection_MaskLevel");
                    if (fresnelLightMask.HasValue) fresnelLightMask += (float)1.0;
                    //GetFloatProperty(material, "_Add_Antipodean_RimLight");
                    fresnelTintInv = GetColorProperty(material, "_Ap_RimLightColor");
                    fresnelWidthInv = GetFloatProperty(material, "_Ap_RimLight_Power");
                    if (fresnelWidthInv.HasValue) fresnelWidthInv = fresnelWidthInv * 10;
                    fresnelStrengthInv = GetFloatProperty(material, "_Ap_RimLight_FeatherOff");
                    if (fresnelStrengthInv.HasValue) fresnelStrengthInv = (float)1.0 - fresnelStrengthInv;
                    //material.GetTexture("_Set_RimLightMask");

                    // Matcap properties are not fully supported
                    useMatcap = GetFloatProperty(material, "_MatCap");
                    matcapTexture = material.GetTexture("_MatCap_Sampler");
                    matcapMask = material.GetTexture("_Set_MatcapMask");
                    // _MatCapColor is not yet supported.
                    // _Is_LightColor_MatCap is not supported.
                    matcapBlend = GetFloatProperty(material, "_Is_BlendAddToMatCap");
                    if (matcapBlend.HasValue) matcapBlend = (float)1.0 - matcapBlend;
                    // _Tweak_MatCapUV, _Rotate_MatCapUV are not yet supported.
                    // _Is_NormalMapForMatCap, _NormalMapForMatCap, _BumpScaleMatcap, _Rotate_NormalMapForMatCapUV
                    // are not supported.

                    if (oldShader.name.Contains("DoubleShadeWithFeather"))
                    {
                        shadeMap1Step = GetFloatProperty(material, "_BaseColor_Step");
                        shadeMap1Feather = GetFloatProperty(material, "_BaseShade_Feather");
                        shadeMap2Step = GetFloatProperty(material, "_ShadeColor_Step");
                        shadeMap2Feather = GetFloatProperty(material, "_1st2nd_Shades_Feather");
                    }
                    outlineMode = (float)1.0;
                    if (oldShader.name.Contains("NoOutline"))
                    {
                    	outlineMode = (float)0.0;
                	}
                    outlineColor = GetColorProperty(material, "_Outline_Color");
            		outlineWidth = GetFloatProperty(material, "_Outline_Width") * (float)0.1;
            		outlineMask = material.GetTexture("_Outline_Sampler");

                    // Stencil properties
                    if (oldShader.name.Contains("StencilMask"))
                    {
                    	Debug.Log(GetIntProperty(material, "_StencilNo") % 256);
                    	stencilReference = (int)GetIntProperty(material, "_StencilNo") % 256;
                    	stencilComparison = (int)CompareFunction.Always;
                    	stencilOperation = (int)StencilOp.Replace;
						stencilFail = (int)StencilOp.Replace;

                	}
                    if (oldShader.name.Contains("StencilOut"))
                    {
                    	Debug.Log(GetIntProperty(material, "_StencilNo") % 256);
                    	stencilReference = (int)GetIntProperty(material, "_StencilNo") % 256;
                    	stencilComparison = (int)CompareFunction.NotEqual;
                    	stencilOperation = (int)StencilOp.Keep;
						stencilFail = (int)StencilOp.Keep;
                	}


                }
            }

            base.AssignNewShaderToMaterial(material, oldShader, newShader);

            // Apply old shader properties to the new shader.
            SetColorProperty(material, "_EmissionColor", emissionColor);
            SetVectorProperty(material, "_MainTex_ST", textureScaleOffset);
            SetShaderFeatureActive(material, null, "_CullMode", cullMode);

            if (normalMapTexture)
            {
                material.SetTexture("_BumpMap", normalMapTexture);
            }
            if (matcapTexture)
            {
                material.SetTexture("_Matcap1", matcapTexture);
            }
            if (matcapMask)
            {
                material.SetTexture("_MatcapMask", matcapMask);
            }
            if (specularMap)
            {
                material.SetTexture("_SpecGlossMap", specularMap);
            }
            if (outlineMask)
            {
                material.SetTexture("_OutlineMask", outlineMask);
            }

            SetFloatProperty(material, "_BumpScale", normalMapScale);
            SetColorProperty(material, "_EmissionColor", emissionColor);
            SetFloatProperty(material, "_CrosstoneToneSeparation", useToneSeparation);
            SetFloatProperty(material, "_1st_ShadeColor_Step", shadeMap1Step);
            SetFloatProperty(material, "_1st_ShadeColor_Feather", shadeMap1Feather);
            SetFloatProperty(material, "_2nd_ShadeColor_Step", shadeMap2Step);
            SetFloatProperty(material, "_2nd_ShadeColor_Feather", shadeMap2Feather);
            SetFloatProperty(material, "_UseMatcap", useMatcap);
            SetFloatProperty(material, "_Matcap1Blend", matcapBlend);
            SetFloatProperty(material, "_SpecularType", specularType);
            SetColorProperty(material, "_SpecColor", specularTint);
            SetFloatProperty(material, "_Smoothness", smoothness);
            SetFloatProperty(material, "_UseFresnel", useFresnel);
            SetFloatProperty(material, "_FresnelWidth", fresnelWidth);
            SetFloatProperty(material, "_FresnelStrength", fresnelStrength);
            SetColorProperty(material, "_FresnelTint", fresnelTint);
            SetFloatProperty(material, "_UseFresnelLightMask", useFresnelLightMask);
            SetFloatProperty(material, "_FresnelLightMask", fresnelLightMask);
            SetColorProperty(material, "_FresnelTintInv", fresnelTintInv);
            SetFloatProperty(material, "_FresnelWidthInv", fresnelWidthInv);
            SetFloatProperty(material, "_FresnelStrengthInv", fresnelStrengthInv);

            SetFloatProperty(material, "_OutlineMode", outlineMode);
            SetColorProperty(material, "_outline_color", outlineColor);
            SetFloatProperty(material, "_outline_width", outlineWidth);

			SetIntProperty(material, "_Stencil", stencilReference);
			SetIntProperty(material, "_StencilComp", stencilComparison);
			SetIntProperty(material, "_StencilOp", stencilOperation);
			SetIntProperty(material, "_StencilFail", stencilFail);

            if (outlineMode.HasValue) SetupMaterialWithOutlineMode(material, (OutlineMode)outlineMode);

            // Setup the rendering mode based on the old shader.
            if (oldShader == null || !oldShader.name.Contains(LegacyShadersPath))
            {
                SetupMaterialWithRenderingMode(material, (RenderingMode)material.GetFloat(BaseStyles.renderingModeName), CustomRenderingMode.Opaque, -1);
            }
            else
            {
                RenderingMode mode = RenderingMode.Opaque;

                if (oldShader.name.Contains(TransparentCutoutShadersPath))
                {
                    mode = RenderingMode.Cutout;
                }
                else if (oldShader.name.Contains(TransparentShadersPath))
                {
                    mode = RenderingMode.Fade;
                }

            	if (oldShader.name.Contains("UnityChanToonShader"))
                {
	            	if (oldShader.name.Contains("Clipping"))
	                {
	                    mode = RenderingMode.Cutout;
	                }
	            	if (oldShader.name.Contains("TransClipping"))
	                {
	                    mode = RenderingMode.Fade;
	                }
	            }

                material.SetFloat(BaseStyles.renderingModeName, (float)mode);

                MaterialChanged(material);
            }
        }

	}
}