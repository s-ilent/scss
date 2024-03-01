using UnityEditor;
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;
using static SilentCelShading.Unity.InspectorCommon;
using SilentCelShading.Unity.Baking;

// Parts of this file are based on https://github.com/Microsoft/MixedRealityToolkit-Unity/
//	Copyright (c) Microsoft Corporation. All rights reserved.
//	Licensed under the MIT License.

namespace SilentCelShading.Unity
{
	public class Inspector : SCSSShaderGUI
	{

		public enum ShadowMaskType
		{
			Occlusion, Tone, Auto
		}

		public enum LightRampType
		{
			Horizontal, Vertical, None
		}

		public enum ToneSeparationType
		{
			Combined, Separate
		}

		public enum IndirectShadingType
		{
			Dynamic, Directional, Flatten
		}

		public enum TransparencyMode
		{
			Soft, Sharp
		}

		public enum SpecularMetallicMode
		{
			Specular, Metalness
		}

		public enum DetailEmissionMode
		{
			Phase, AudioLink
		}

		public enum DetailMapType
		{
			Albedo = 0,  Normal = 1, Specular = 2
		}

		public enum DetailBlendMode
		{
			Multiply2x = 0, Multiply = 1, Add = 2, AlphaBlend = 3,
		}
		
		public enum TintApplyMode
		{
			Tint = 0, HSV = 1
		}
		public enum UVLayers
		{
			UV0 = 0, UV1 = 1, UV2 = 2, UV3 = 3
		}
		public enum FurMode
		{
			None = 0, On = 1
		}

		protected Material target;
		protected MaterialEditor editor;
    	private MaterialPropertyHandler ph;

    	public int scssSettingsComplexityMode = (int)SettingsComplexityMode.Simple;

		public enum MaterialType
		{
			Lightramp, Crosstone
		}

		public enum MaterialGeomType
		{
			None, Outline, Fur
		}

		public MaterialType lightType;
		public MaterialGeomType geomType;
		public bool isBaked;
		public bool needsRefresh = true;

    //-------------------------------------------------------------------------
    // GUI stuff
    //-------------------------------------------------------------------------

		public enum SettingsComplexityMode
		{
			Complex, Normal, Simple
		}

		protected GUIStyle scmStyle;
		protected GUIStyle sectionHeader;
		protected GUIStyle sectionHeaderBox;

		protected void InitialiseStyles()
		{
			if (scmStyle != null || sectionHeader != null || sectionHeaderBox != null) return;
			scmStyle = new GUIStyle("DropDownButton");
			sectionHeader = new GUIStyle(EditorStyles.miniBoldLabel);
			sectionHeader.padding.left = 24;
			sectionHeader.padding.right = -24;
			sectionHeaderBox = new GUIStyle( GUI.skin.box );
			sectionHeaderBox.alignment = TextAnchor.MiddleLeft;
			sectionHeaderBox.padding.left = 5;
			sectionHeaderBox.padding.right = -5;
			sectionHeaderBox.padding.top = 0;
			sectionHeaderBox.padding.bottom = 0;
		}
		
		protected Rect DrawSectionHeaderArea(GUIContent content)
		{
            Rect r = EditorGUILayout.GetControlRect(true,0,EditorStyles.layerMaskField);
				r.x -= 2.0f;
				r.y += 2.0f;
				r.height = 18.0f;
				r.width -= 0.0f;
			GUI.Box(r, EditorGUIUtility.IconContent("d_FilterByType"), sectionHeaderBox);
			EditorGUILayout.LabelField(content, sectionHeader);
			return r;
		}

		private void DisabledGUIIfBaked(Action guiAction)
		{
			using (new EditorGUI.DisabledScope(isBaked == true))
			{
				guiAction();
			}
		}
		
    //-------------------------------------------------------------------------
    // Main
    //-------------------------------------------------------------------------

		protected void CheckShaderType(Material material)
		{
			// Check material type.
			// First, the name has to reflect the shading type. 
			// Theoretically, we could scan the properties, but checking the name seems good enough.
			const string crosstoneName = "Crosstone";
			if (material.shader.name.Contains(crosstoneName)) lightType = MaterialType.Crosstone;

			const string lightrampName = "Lightramp";
			if (material.shader.name.Contains(lightrampName)) lightType = MaterialType.Lightramp;

			// Next, the name has to reflect the geom shader type.
			// Outline and fur properties exist for both variants, so check the name again.
			geomType = MaterialGeomType.None;
			const string outlineName = "(Outline)";
			if (material.shader.name.Contains(outlineName)) geomType = MaterialGeomType.Outline;
			const string furName = "(Fur)";
			if (material.shader.name.Contains(furName)) geomType = MaterialGeomType.Fur;

			// Shader baking moves the shader to Hidden, but that could mean other things too. 
			MaterialProperty bakedSettings = ph.Property("__Baked");
			isBaked = (bakedSettings != null && bakedSettings.floatValue == 1);
		}

		protected override void MaterialChanged(Material material)
		{
			InitialiseStyles();
			CheckShaderType(material);
			
			UnbakedCheck(material);

			if (!Int32.TryParse(EditorUserSettings.GetConfigValue("scss_settings_complexity_mode"), out scssSettingsComplexityMode))
			{
				scssSettingsComplexityMode = (int)SettingsComplexityMode.Simple;
			}

			// Handle old materials
			UpgradeMatcaps(material);
			UpgradeDetailMaps(material);

			SetupMaterialWithAlbedo(material, 
				ph.Property("_MainTex"), 
				ph.Property("_AlbedoAlphaMode"));

				
			MaterialProperty outlineProp = ph.Property("_OutlineMode");
			if (outlineProp != null)
			{
				SetupMaterialWithOutlineMode(material, (OutlineMode)outlineProp.floatValue);
			}
				
			MaterialProperty furProp = ph.Property("_FurMode");
			if (furProp != null)
			{
				SetupMaterialWithFurMode(material, (FurMode)furProp.floatValue);
			}

			MaterialProperty specProp = ph.Property("_SpecularType");
			if (specProp != null)
			{
				SetupMaterialWithSpecularType(material, (SpecularType)specProp.floatValue);
			}

			base.MaterialChanged(material);
		}

		public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] matProps)
		{ 
			target = materialEditor.target as Material;
			editor = materialEditor;

			if (needsRefresh || ph == null || materialEditor != editor)
			{
        		ph = new MaterialPropertyHandler(matProps, editor);
				needsRefresh = false;
			}

			// This only checks a single material target, but that's okay because you can't select
			// more than one shader type at the same time.
			CheckShaderType(this.target);

			DrawInspectorHeader();

			if (isBaked) // Show a guide for when the shader is baked but the bake button is unavailable. 
			{
				EditorGUILayout.HelpBox(ph.Content("s_bakeDepreciateWarning").text, MessageType.Warning); 
			}

        	using (new EditorGUI.DisabledScope(isBaked == true))
			{
				base.OnGUI(materialEditor, matProps);
			}
			SettingsComplexityArea();
			
			RenderOptions((SettingsComplexityMode)scssSettingsComplexityMode);
			
			FooterOptions();
		}

		protected string[] SettingsComplexityModeOptions = new string[]
		{
			"Complex", "Normal", "Simple"
		};

		protected void SettingsComplexityArea()
		{
			SettingsComplexityModeOptions[0] = ph.Content("s_fullComplexity").text;
			SettingsComplexityModeOptions[1] = ph.Content("s_normalComplexity").text;
			SettingsComplexityModeOptions[2] = ph.Content("s_simpleComplexity").text;
			EditorGUILayout.Space();

			if (WithChangeCheck(() =>
			{
				scssSettingsComplexityMode = EditorGUILayout.Popup(scssSettingsComplexityMode, SettingsComplexityModeOptions, scmStyle);
			})) 
			{
				EditorUserSettings.SetConfigValue("scss_settings_complexity_mode", scssSettingsComplexityMode.ToString());
			}
		}

		private InspectorLanguageSelection currentLanguage;

		protected void DrawInspectorHeader()
		{
			#if UNITY_2019_1_OR_NEWER
            Rect r = EditorGUILayout.GetControlRect(true,0,EditorStyles.layerMaskField);
				r.x -= 24.0f;
				r.y -= 8.0f;
				r.height = 18.0f;
				r.width += 28.0f;
			float maxWidth = 128.0f;
			Rect r2 = r;
				r2.x = r.width - maxWidth - 13.0f;
				r2.width = maxWidth;
			Rect r3 = r;
				r3.x = 14.0f + 4.0f;
				r3.width = maxWidth;
			#else
            Rect r = EditorGUILayout.GetControlRect(true,0,EditorStyles.layerMaskField);
				r.x -= 12.0f;
				r.y -= 8.0f;
				r.height = 18.0f;
				r.width += 4.0f;
			float maxWidth = 128.0f;
			Rect r2 = r;
				r2.x = r.width - maxWidth + 14.0f;
				r2.width = maxWidth;
			Rect r3 = r;
				r3.x = 14.0f + 4.0f;
				r3.width = maxWidth;
			#endif
			GUI.Box(r, "", EditorStyles.toolbar);

			GUIContent s_bakeButton;
			MaterialProperty shaderOptimizer = ph.Property("__Baked");
			// Create the GUIContent for the button so it can be rendered.
			if (shaderOptimizer == null)
			{
				s_bakeButton = new GUIContent ("s_bakeButton");
			}
			else
			{
				// Determine whether we're baking or unbaking materials. 
				if (shaderOptimizer.floatValue == 1) 
				{
					s_bakeButton = ph.Content("s_bakeButtonRevert");
				} 
				else
				{
					if (editor.targets.Length == 1)
					{
						s_bakeButton = ph.Content("s_bakeButton");
					} 
					else 
					{
						s_bakeButton = ph.Content("s_bakeButtonPlural");
						s_bakeButton.text = String.Format(s_bakeButton.text, "" + editor.targets.Length.ToString());
					}
				}
			}
			
			
			var language = GetInspectorLanguage();
			switch(inspectorLanguage)
			{
				case SystemLanguage.English:
					currentLanguage = InspectorLanguageSelection.English; 
					break;
				case SystemLanguage.Japanese:
					currentLanguage = InspectorLanguageSelection.日本語;
					break;
				default:
					break;
			}
				
			if (WithChangeCheck(() => 
			{
        		currentLanguage = (InspectorLanguageSelection) EditorGUI.EnumPopup(r3, currentLanguage);
			}))
			{
				UpdateInspectorLanguage(currentLanguage);
			}
			
			/**
			// There are some issues with baking in Unity 2022 that I'm not sure how to fix, so the button is disabled.
			
			// Draw the bake button. Because of Unity shenanigans, if we don't always draw the button, 
			// the layout will explode on the first update of the inspector.
			if (GUI.Button(r2, s_bakeButton, EditorStyles.miniButtonMid))
			{
				// If it's a mixed value, then only allow baking. It shouldn't be a mixed value,
				// but a material might think it's baked when it isn't, which needs to be handled anyway.
				if (shaderOptimizer.hasMixedValue)
				{
					foreach (Material m in editor.targets)
					{
						m.SetFloat(shaderOptimizer.name, 1);
						MaterialProperty[] props = MaterialEditor.GetMaterialProperties(new UnityEngine.Object[] { m });
						if (!ShaderOptimizer.Lock(m, props)) // Error locking shader, revert property
							m.SetFloat(shaderOptimizer.name, 0);
					}	

				}
				else
				{
					shaderOptimizer.floatValue = shaderOptimizer.floatValue == 1 ? 0 : 1;
					if (shaderOptimizer.floatValue == 1)
					{
						foreach (Material m in editor.targets)
						{
							MaterialProperty[] props = MaterialEditor.GetMaterialProperties(new UnityEngine.Object[] { m });
							if (!ShaderOptimizer.Lock(m, props))
								m.SetFloat(shaderOptimizer.name, 0);
						}
					}
					else
					{
						foreach (Material m in editor.targets)
						{
							if (!ShaderOptimizer.Unlock(m))
								m.SetFloat(shaderOptimizer.name, 1);
							MaterialChanged(m);
						}
					}
				}
			}
			}
			**/ 
			EditorGUILayout.LabelField("", EditorStyles.label); // Spacing only
		}
		

		[Flags]
		public enum Options
		{
			MainOptions = 1 << 0,
			ShadingOptions = 1 << 1,
			RenderingOptions = 1 << 2,
			OutlineOptions = 1 << 3,
			FurOptions = 1 << 4,
			EmissionOptions = 1 << 5,
			BackfaceOptions = 1 << 6,
			DetailOptions = 1 << 7,
			MiscOptions = 1 << 8,
			RuntimeLightOptions = 1 << 9,
			InventoryOptions = 1 << 10,
			ManualButtonArea = 1 << 11,
			AdvancedOptions = 1 << 12
		}

		public Options GetOptionsForComplexity(SettingsComplexityMode mode)
		{
			Options options = 0;
			switch (mode)
			{
				case SettingsComplexityMode.Simple:
					options = Options.MainOptions | Options.ShadingOptions | Options.EmissionOptions | Options.OutlineOptions;
					break;
				case SettingsComplexityMode.Normal:
					options = Options.MainOptions | Options.ShadingOptions | Options.RenderingOptions | Options.OutlineOptions | Options.FurOptions | Options.EmissionOptions | Options.RuntimeLightOptions | Options.InventoryOptions | Options.AdvancedOptions;
					break;
				case SettingsComplexityMode.Complex:
					options = (Options)~0; // All options are included in the Complex mode
					break;
			}
			return options;
		}

		public Options GetActiveOptions()
		{
			Options activeOptions = 0;
			// Todo: Check each option and if it's active, add it to activeOptions
			// For example:
			// if (IsOptionActive("MainOptions")) activeOptions |= Options.MainOptions;
			return activeOptions;
		}

		public void ExecuteOption(Options option)
		{
			switch (option)
			{
				case Options.MainOptions:
					DisabledGUIIfBaked(() => MainOptions());
					break;
				case Options.ShadingOptions:
					DisabledGUIIfBaked(() => ShadingOptions());
					break;
				case Options.RenderingOptions:
					DisabledGUIIfBaked(() => RenderingOptions());
					break;
				case Options.OutlineOptions:
					DisabledGUIIfBaked(() => OutlineOptions());
					break;
				case Options.FurOptions:
					DisabledGUIIfBaked(() => FurOptions());
					break;
				case Options.EmissionOptions:
					DisabledGUIIfBaked(() => EmissionOptions());
					break;
				case Options.BackfaceOptions:
					DisabledGUIIfBaked(() => BackfaceOptions());
					break;
				case Options.DetailOptions:
					DisabledGUIIfBaked(() => DetailOptions());
					break;
				case Options.MiscOptions:
					DisabledGUIIfBaked(() => MiscOptions());
					break;
				case Options.RuntimeLightOptions:
					RuntimeLightOptions();
					break;
				case Options.InventoryOptions:
					InventoryOptions();
					break;
				case Options.ManualButtonArea:
					ManualButtonArea();
					break;
				case Options.AdvancedOptions:
					DisabledGUIIfBaked(() => AdvancedOptions());
					break;
				default:
					throw new ArgumentOutOfRangeException(nameof(option), option, null);
			}
		}

		public void RenderOptions(SettingsComplexityMode mode)
		{
			Options complexityOptions = GetOptionsForComplexity(mode);
			Options activeOptions = GetActiveOptions();
			Options optionsToRender = complexityOptions | activeOptions;

			foreach (Options option in Enum.GetValues(typeof(Options)))
			{
				if ((optionsToRender & option) == option)
				{
					using (new EditorGUI.DisabledScope(isBaked == true))
					{
						// Call the corresponding method for the option
						ExecuteOption(option);
					}
				}
			}
		}
		
		protected void MainOptions()
		{ 
			EditorGUILayout.Space();
		
			DrawSectionHeaderArea(ph.Content("s_mainOptions"));

			EditorGUILayout.Space();

			WithGroupHorizontal(() => {
				ph.TexturePropertySingleLine("_MainTex", "_Color");
				ph.ShaderProperty("_UseBackfaceTexture");
			});

			ph.TexturePropertySingleLine("_BumpMap", "_BumpScale");

			ph.TexturePropertySingleLine("_ColorMask", "_ToggleHueControls");
				
			MaterialProperty hueProp = ph.Property("_ToggleHueControls");
			if (hueProp != null && hueProp.floatValue == (float)TintApplyMode.HSV)
			{
				ph.ShaderProperty("_ShiftHue");
				ph.ShaderProperty("_ShiftSaturation");
				ph.ShaderProperty("_ShiftValue");
			}
			
			ph.TextureScaleOffsetProperty("_MainTex");

			MaterialProperty alphaProp = ph.Property("_AlbedoAlphaMode");
			if (alphaProp != null && alphaProp.floatValue == (float)AlbedoAlphaMode.ClippingMask)
			{
				EditorGUILayout.Space();
				ph.TexturePropertySingleLine("_ClippingMask", "_Tweak_Transparency");
    			ph.TextureScaleOffsetProperty("_ClippingMask");
			}
			EditorGUILayout.Space();

			MaterialProperty renderMode = ph.Property(BaseStyles.renderingModeName);
			if (renderMode != null && (RenderingMode)renderMode.floatValue > 0)
			{
				ph.ShaderProperty("_AlphaSharp");
				ph.ShaderProperty("_Cutoff");
			}
		}

		protected void BackfaceOptions()
		{ 
			if (ph.PropertyEnabled("_UseBackfaceTexture"))
			{
				target.EnableKeyword("_BACKFACE"); // Possibly redundant, but not sure
				ph.TexturePropertySingleLine("_MainTexBackface", "_ColorBackface");
			}
		}

		protected void ShadingOptions()
		{
			EditorGUILayout.Space();
			DrawSectionHeaderArea(ph.Content("s_shadingOptions"));
			if (lightType == MaterialType.Lightramp) LightrampOptions();
			if (lightType == MaterialType.Crosstone) CrosstoneOptions();
		}

		protected void RenderingOptions()
		{ 
			EditorGUILayout.Space();
			DrawSectionHeaderArea(ph.Content("s_renderingOptions"));
			SpecularOptions();
			RimlightOptions();
			MatcapOptions();
		}

		protected void DetailOptions()
		{
			EditorGUILayout.Space();
			DrawSectionHeaderArea(ph.Content("s_detailOptions"));
			DetailMapOptions();
			SubsurfaceOptions();
			ContactShadowOptions();
		}

		protected void EmissionOptions()
		{
			EditorGUILayout.Space();
			DrawSectionHeaderArea(ph.Content("s_emissionOptions"));
			EditorGUILayout.Space();
			MaterialProperty emissionMapProp = ph.Property("_EmissionMap");
			WithGroupHorizontal(() => {
				if (emissionMapProp != null) 
				{
					bool hadEmissionTexture = emissionMapProp.textureValue != null;
					ph.TexturePropertyWithHDRColor("_EmissionMap", "_EmissionColor");
					// If texture was assigned and color was black set color to white
					float brightness = ph.Property("_EmissionColor").colorValue.maxColorComponent;
					if (emissionMapProp.textureValue != null && !hadEmissionTexture && brightness <= 0f)
						ph.Property("_EmissionColor").colorValue = Color.white;

					ph.PropertyDropdownNoLabel("_EmissionUVSec", Enum.GetNames(typeof(UVLayers)), editor);
				}
			});
			ph.TextureScaleOffsetProperty("_EmissionMap");
			EditorGUILayout.Space();

			if (ph.ShaderProperty("_UseAdvancedEmission") && ph.PropertyEnabled("_UseAdvancedEmission"))
			{
				target.EnableKeyword("_EMISSION");
				WithGroupHorizontal(() => {
					ph.TexturePropertySingleLine("_DetailEmissionMap");
					ph.PropertyDropdownNoLabel("_DetailEmissionUVSec", Enum.GetNames(typeof(UVLayers)), editor);
				});
				EditorGUI.indentLevel ++;
				EditorGUI.indentLevel ++;
				ph.TextureScaleOffsetProperty("_DetailEmissionMap");
				ph.Vector2Property("_EmissionDetailParams", "s_EmissionDetailScroll", 0, 1);
				ph.Vector2Property("_EmissionDetailParams", "s_EmissionDetailPhase", 2, 3);
				EditorGUILayout.Space();
            	EditorGUI.indentLevel --;
            	EditorGUI.indentLevel --;
			} else {
				target.DisableKeyword("_EMISSION");
			}
			EditorGUILayout.Space();
			
			if (ph.ShaderProperty("_UseEmissiveAudiolink") && ph.PropertyEnabled("_UseEmissiveAudiolink"))
			{
				target.EnableKeyword("_AUDIOLINK");
				WithGroupHorizontal(() => {
					ph.TexturePropertySingleLine("_AudiolinkMaskMap");
					ph.PropertyDropdownNoLabel("_AudiolinkMaskMapUVSec", Enum.GetNames(typeof(UVLayers)), editor);
				});
				EditorGUI.indentLevel ++;
				EditorGUI.indentLevel ++;
				ph.TextureScaleOffsetProperty("_AudiolinkMaskMap");
            	EditorGUI.indentLevel --;
            	EditorGUI.indentLevel --;
				WithGroupHorizontal(() => {
					ph.TexturePropertySingleLine("_AudiolinkSweepMap");
					ph.PropertyDropdownNoLabel("_AudiolinkSweepMapUVSec", Enum.GetNames(typeof(UVLayers)), editor);
				});
				EditorGUI.indentLevel ++;
				EditorGUI.indentLevel ++;
				ph.TextureScaleOffsetProperty("_AudiolinkSweepMap");
				EditorGUILayout.Space();
				ph.ShaderProperty("_AudiolinkIntensity");
				// AudioLink properties
				ph.ShaderProperty("_alColorR");
				ph.ShaderProperty("_alColorG");
				ph.ShaderProperty("_alColorB");
				ph.ShaderProperty("_alColorA");
				ph.ShaderProperty("_alBandR");
				ph.ShaderProperty("_alBandG");
				ph.ShaderProperty("_alBandB");
				ph.ShaderProperty("_alBandA");
				ph.ShaderProperty("_alModeR");
				ph.ShaderProperty("_alModeG");
				ph.ShaderProperty("_alModeB");
				ph.ShaderProperty("_alModeA");
				ph.ShaderProperty("_alTimeRangeR");
				ph.ShaderProperty("_alTimeRangeG");
				ph.ShaderProperty("_alTimeRangeB");
				ph.ShaderProperty("_alTimeRangeA");
				ph.ShaderProperty("_alUseFallback");
				ph.ShaderProperty("_alFallbackBPM");
				// Not implemented yet
				//EditorGUILayout.Space();
				//ph.ShaderProperty("_UseAudiolinkLightSense");
				//ph.ShaderProperty("_AudiolinkLightSenseStart");
				//ph.ShaderProperty("_AudiolinkLightSenseEnd");
            	EditorGUI.indentLevel --;
            	EditorGUI.indentLevel --;
			} else {
				target.DisableKeyword("_AUDIOLINK");
			}
			EditorGUILayout.Space();
			ph.ShaderProperty("_CustomFresnelColor");
			EditorGUILayout.Space();
			ph.ShaderProperty("_UseEmissiveLightSense");
			ph.ShaderProperty("_EmissiveLightSenseStart");
			ph.ShaderProperty("_EmissiveLightSenseEnd");
			// For some reason, this property doesn't have spacing after it
			EditorGUILayout.Space();
		}

		protected void MiscOptions()
		{
			EditorGUILayout.Space();
			DrawSectionHeaderArea(ph.Content("s_miscOptions"));
			EditorGUILayout.Space();
			ph.ShaderProperty("_PixelSampleMode");
			AnimationOptions();
			VanishingOptions();
			ProximityShadowOptions();
		}

        protected void LightrampOptions()
        { 
			EditorGUILayout.Space();
			
			ph.ShaderProperty("_LightRampType");
			MaterialProperty lrProp = ph.Property("_LightRampType");
			if (lrProp != null && (LightRampType)lrProp.floatValue != LightRampType.None)
            {
                WithGroupHorizontal(() => 
				{
					ph.TexturePropertySingleLine("_Ramp");
					if (GUILayout.Button(ph.Content("s_gradientEditorButton"), "button"))
					{
						XSGradientEditor.callGradientEditor(target);
					}
				});
            }
            ph.ShaderProperty("_ShadowLift");
            ph.ShaderProperty("_IndirectLightingBoost");
            
            EditorGUILayout.Space();

            ph.ShaderProperty("_ShadowMaskType");
            ph.TexturePropertySingleLine("_ShadowMask", "_ShadowMaskColor");
            ph.ShaderProperty("_Shadow");
        }

		protected void CrosstoneOptions()
		{ 
            EditorGUILayout.Space();
			WithGroupHorizontal(() => {
				ph.TextureColorPropertyWithColorReset("_1st_ShadeMap", "_1st_ShadeColor");
				ph.PropertyDropdownNoLabel("_CrosstoneToneSeparation", Enum.GetNames(typeof(ToneSeparationType)), editor);
			});
			ph.ShaderProperty("_1st_ShadeColor_Step");
			ph.ShaderProperty("_1st_ShadeColor_Feather");
            EditorGUILayout.Space();
			
			WithGroupHorizontal(() => {
				ph.TextureColorPropertyWithColorReset("_2nd_ShadeMap", "_2nd_ShadeColor");
				ph.PropertyDropdownNoLabel("_Crosstone2ndSeparation", Enum.GetNames(typeof(ToneSeparationType)), editor);
			});
			ph.ShaderProperty("_2nd_ShadeColor_Step");
			ph.ShaderProperty("_2nd_ShadeColor_Feather");

			// Visual tweaks to improve readability
            EditorGUILayout.Space();
			WithGroupHorizontal(() => {
				ph.ShaderProperty("_ShadowBorderColor");
				EditorGUILayout.LabelField(" "); // Visual consistency
			});
			EditorGUI.indentLevel+=2;
			ph.ShaderProperty("_ShadowBorderRange");
			EditorGUI.indentLevel-=2;
            EditorGUILayout.Space();

			ph.TexturePropertySingleLine("_ShadingGradeMap", "_Tweak_ShadingGradeMapLevel");
		}

		protected void SpecularOptions()
		{	
            EditorGUILayout.Space();
			MaterialProperty specProp = ph.Property("_SpecularType");
			if (specProp != null)
			{
				foreach (Material mat in ph.PropertyDropdown("_SpecularType", Enum.GetNames(typeof(SpecularType)), editor))
				{
					SetupMaterialWithSpecularType(mat, (SpecularType)specProp.floatValue);
				}
				ph.TogglePropertyHeader("_SpecularType", false);

	            if ((SpecularType)ph.Property("_SpecularType").floatValue != SpecularType.Disable) 
	            {
					WithGroupHorizontal(() => {
						ph.TextureColorPropertyWithColorReset("_SpecGlossMap", "_SpecColor");
						ph.PropertyDropdownNoLabel("_UseMetallic", Enum.GetNames(typeof(SpecularMetallicMode)), editor);
					});

					switch ((SpecularType)specProp.floatValue)
					{
						case SpecularType.Standard:
						case SpecularType.Cloth:
						ph.ShaderProperty("_Smoothness");
						ph.ShaderProperty("_UseEnergyConservation");
						break;
						case SpecularType.Cel:
						ph.ShaderProperty("_Smoothness");
						ph.ShaderProperty("_CelSpecularSoftness");
						ph.ShaderProperty("_CelSpecularSteps");
						ph.ShaderProperty("_UseEnergyConservation");
						break;
						case SpecularType.Anisotropic:
						ph.ShaderProperty("_Smoothness");
						ph.ShaderProperty("_Anisotropy");
						ph.ShaderProperty("_UseEnergyConservation");
						break;
						case SpecularType.CelStrand:
						ph.ShaderProperty("_Smoothness");
						ph.ShaderProperty("_CelSpecularSoftness");
						ph.ShaderProperty("_CelSpecularSteps");
						ph.ShaderProperty("_Anisotropy");
						ph.ShaderProperty("_UseEnergyConservation");
						break;
						case SpecularType.Disable:
						default:
						break;
					}	
					ph.ShaderProperty("_UseIridescenceRamp");
					ph.TexturePropertySingleLine("_SpecIridescenceRamp");
				}
			}
		}

		protected void RimlightOptions()
		{	
            EditorGUILayout.Space();
			MaterialProperty rimProp = ph.Property("_UseFresnel");
			if (rimProp != null)
			{
				ph.TogglePropertyHeader("_UseFresnel");
				bool isTintable = 
					(AmbientFresnelType)rimProp.floatValue == AmbientFresnelType.Lit
					|| (AmbientFresnelType)rimProp.floatValue == AmbientFresnelType.Ambient;

				if (PropertyEnabled(rimProp))
				{
					ph.ShaderProperty("_FresnelWidth");
					ph.ShaderProperty("_FresnelStrength");
					if (isTintable) ph.ShaderProperty("_FresnelTint");	

					ph.ShaderProperty("_UseFresnelLightMask");
					if (ph.PropertyEnabled("_UseFresnelLightMask"))
					{
						ph.ShaderProperty("_FresnelLightMask");
						if (isTintable) ph.ShaderProperty("_FresnelTintInv");
						ph.ShaderProperty("_FresnelWidthInv");
						ph.ShaderProperty("_FresnelStrengthInv");
					}
				}
			}
		}

		private void DrawMatcapField(string texture, string blend, string tint, string strength)
		{
			WithGroupHorizontal(() => {
				ph.TextureColorPropertyWithColorReset(texture, tint);
				ph.PropertyDropdownNoLabel(blend, Enum.GetNames(typeof(MatcapBlendModes)), editor);
			});
			EditorGUI.indentLevel+=2;
			ph.ShaderProperty(strength);
			EditorGUI.indentLevel-=2;
		}

		protected void MatcapOptions()
		{ 
			EditorGUILayout.Space();
			MaterialProperty matcapProp = ph.Property("_UseMatcap");
			if (matcapProp != null)
			{
				var mMode = (MatcapType)matcapProp.floatValue;
				if (WithChangeCheck(() => 
				{
					mMode = (MatcapType)EditorGUILayout.Popup(ph.Content("_UseMatcap"), 
					(int)mMode, Enum.GetNames(typeof(MatcapType)));
				})) {
					editor.RegisterPropertyChangeUndo(ph.Content("_UseMatcap").text);
					matcapProp.floatValue = (float)mMode;
				}
				ph.TogglePropertyHeader("_UseMatcap", false);

				if (PropertyEnabled(matcapProp))
				{
					ph.TexturePropertySingleLine("_MatcapMask");
					DrawMatcapField("_Matcap1", "_Matcap1Blend", "_Matcap1Tint", "_Matcap1Strength");
					DrawMatcapField("_Matcap2", "_Matcap2Blend", "_Matcap2Tint", "_Matcap2Strength");
					DrawMatcapField("_Matcap3", "_Matcap3Blend", "_Matcap3Tint", "_Matcap3Strength");
					DrawMatcapField("_Matcap4", "_Matcap4Blend", "_Matcap4Tint", "_Matcap4Strength");
				}
			}
		}

		protected void SubsurfaceOptions()
		{ 
            EditorGUILayout.Space();
			if (ph.TogglePropertyHeader("_UseSubsurfaceScattering"))
			{
				if (ph.PropertyEnabled("_UseSubsurfaceScattering"))
				{
					WithGroupHorizontal(() => {
						ph.TexturePropertySingleLine("_ThicknessMap");
						ph.ShaderProperty("_ThicknessMapInvert");
					});
					EditorGUI.indentLevel+=2;
					ph.ShaderProperty("_ThicknessMapPower");
					ph.ShaderProperty("_SSSCol");
					ph.ShaderProperty("_SSSIntensity");
					ph.ShaderProperty("_SSSPow");
					ph.ShaderProperty("_SSSDist");
					ph.ShaderProperty("_SSSAmbient");
					EditorGUI.indentLevel-=2;
				}
			}
		}


		protected void ContactShadowOptions()
		{ 
            EditorGUILayout.Space();
			if (ph.TogglePropertyHeader("_UseContactShadows"))
			{
				if (ph.PropertyEnabled("_UseContactShadows"))
				{
					ph.ShaderProperty("_ContactShadowDistance"); 
					ph.ShaderProperty("_ContactShadowSteps"); 
				}
			}
		}

		private void DrawDetailField(string texture, string uvSec, string blend, string type, string strength)
		{
			WithGroupHorizontal(() => {
				ph.TextureColorPropertyWithColorReset(texture, uvSec);
				ph.PropertyDropdownNoLabel(type, Enum.GetNames(typeof(DetailMapType)), editor);

				// Disable the blend mode field when the type is Normal
				EditorGUI.BeginDisabledGroup(ph.Property(type).floatValue == (float)DetailMapType.Normal);
				ph.PropertyDropdownNoLabel(blend, Enum.GetNames(typeof(DetailBlendMode)), editor);
				EditorGUI.EndDisabledGroup();
			});
			ph.TextureScaleOffsetProperty(texture);
			EditorGUI.indentLevel+=2;
			ph.ShaderProperty(strength);
			EditorGUI.indentLevel-=2;
		}


		protected void DetailMapOptions()
		{ 
			EditorGUILayout.Space();
			MaterialProperty detailProp = ph.Property("_UseDetailMaps");
			bool isEnabled = ph.ShaderProperty("_UseDetailMaps");
			
			if (detailProp == null)
				return;

			if (isEnabled && PropertyEnabled(detailProp))
			{
				target.EnableKeyword("_DETAIL_MULX2");
				
				ph.TexturePropertySingleLine("_DetailAlbedoMask");
            	EditorGUILayout.Space();
				DrawDetailField("_DetailMap1", "_DetailMap1UV", "_DetailMap1Blend", "_DetailMap1Type", "_DetailMap1Strength");
            	EditorGUILayout.Space();
				DrawDetailField("_DetailMap2", "_DetailMap2UV", "_DetailMap2Blend", "_DetailMap2Type", "_DetailMap2Strength");
            	EditorGUILayout.Space();
				DrawDetailField("_DetailMap3", "_DetailMap3UV", "_DetailMap3Blend", "_DetailMap3Type", "_DetailMap3Strength");
            	EditorGUILayout.Space();
				DrawDetailField("_DetailMap4", "_DetailMap4UV", "_DetailMap4Blend", "_DetailMap4Type", "_DetailMap4Strength");
			}
			else
			{
				target.DisableKeyword("_DETAIL_MULX2");
			}
		}


		protected void AnimationOptions()
		{
            EditorGUILayout.Space();
			if (ph.TogglePropertyHeader("_UseAnimation") && ph.PropertyEnabled("_UseAnimation"))
			{
				ph.ShaderProperty("_AnimationSpeed");
				ph.ShaderProperty("_TotalFrames");
				ph.ShaderProperty("_FrameNumber");
				ph.ShaderProperty("_Columns");
				ph.ShaderProperty("_Rows");
			}

		}

		protected void VanishingOptions()
		{ 
            EditorGUILayout.Space();
			if (ph.TogglePropertyHeader("_UseVanishing") && ph.PropertyEnabled("_UseVanishing"))
			{
				ph.ShaderProperty("_VanishingStart");
				ph.ShaderProperty("_VanishingEnd");
			}
		}

		protected void ProximityShadowOptions()
		{ 
            EditorGUILayout.Space();
			if (ph.TogglePropertyHeader("_UseProximityShadow") && ph.PropertyEnabled("_UseProximityShadow"))
			{
				ph.ShaderProperty("_ProximityShadowDistance");
				ph.ShaderProperty("_ProximityShadowDistancePower");
				ph.ShaderProperty("_ProximityShadowFrontColor");
				ph.ShaderProperty("_ProximityShadowBackColor");
			}
		}

		protected void OutlineOptions()
		{ 
			EditorGUILayout.Space();
			
			MaterialProperty outlineProp = ph.Property("_OutlineMode");
			if (outlineProp != null)
			{
				using (new EditorGUI.DisabledScope(geomType == MaterialGeomType.Fur))
				{
					foreach (Material mat in ph.PropertyDropdown("_OutlineMode", Enum.GetNames(typeof(OutlineMode)), editor))
					{
						SetupMaterialWithOutlineMode(mat, (OutlineMode)outlineProp.floatValue);
					}
					ph.TogglePropertyHeader("_OutlineMode", false);

					switch ((OutlineMode)outlineProp.floatValue)
					{
						case OutlineMode.Tinted:
						case OutlineMode.Colored:
						ph.TexturePropertySingleLine("_OutlineMask");
						ph.ShaderProperty("_outline_color");
						ph.ShaderProperty("_outline_width");
						ph.ShaderProperty("_OutlineZPush");
						break;
						case OutlineMode.None:
						default:
						break;
					}	 
				} 
			}
		}
		
		protected void FurOptions()
		{ 
			EditorGUILayout.Space();
			
			MaterialProperty furProp = ph.Property("_FurMode");
			if (furProp != null)
			{
				using (new EditorGUI.DisabledScope(geomType == MaterialGeomType.Outline))
				{
					foreach (Material mat in ph.PropertyDropdown("_FurMode", Enum.GetNames(typeof(FurMode)), editor))
					{
						SetupMaterialWithFurMode(mat, (FurMode)furProp.floatValue);
					}
					ph.TogglePropertyHeader("_FurMode", false);

					switch ((FurMode)furProp.floatValue)
					{
						case FurMode.On:
						ph.TexturePropertySingleLine("_FurMask");
						ph.ShaderProperty("_FurNoise");
						ph.ShaderProperty("_FurLength");
						ph.ShaderProperty("_FurRandomization");
						ph.ShaderProperty("_FurThickness");
						ph.ShaderProperty("_FurGravity");
						ph.ShaderProperty("_FurLayerCount");
						break;
						case FurMode.None:
						default:
						break;
					}	  
				}
			}
		}

		protected void ManualButtonArea()
		{
			EditorGUILayout.Space();
			
			DrawSectionHeaderArea(ph.Content("Resources"));

            Rect r = EditorGUILayout.GetControlRect(true,0,EditorStyles.layerMaskField);
				r.x -= 2.0f;
				r.y += 2.0f;
				r.height = 18.0f;
			Rect r2 = r;
				r2.width = r.width / 3.0f;
			//GUI.Box(r, EditorGUIUtility.IconContent("Toolbar"), EditorStyles.toolbar);
			if (GUI.Button(r2, ph.Content("s_manualButton"), EditorStyles.miniButtonLeft)) Application.OpenURL("https://gitlab.com/s-ilent/SCSS/wikis/Manual/Setting-Overview");
				r2.x += r2.width;
			if (GUI.Button(r2, ph.Content("s_socialButton"), EditorStyles.miniButtonRight)) Application.OpenURL("https://discord.gg/uHJx4g629K");
				r2.x += r2.width;
			if (GUI.Button(r2, ph.Content("s_fanboxButton"), EditorStyles.miniButtonRight)) Application.OpenURL("https://s-ilent.fanbox.cc/");
			EditorGUILayout.LabelField("", EditorStyles.label);
		}

		protected void RuntimeLightOptions()
		{
			EditorGUILayout.Space();
			ph.ShaderProperty("_LightMultiplyAnimated");
			ph.ShaderProperty("_LightClampAnimated");
			ph.ShaderProperty("_LightAddAnimated");
		}

		protected void InventoryOptions()
		{
			EditorGUILayout.Space();
			DrawSectionHeaderArea(ph.Content("s_inventoryOptions"));
			EditorGUILayout.Space();

			const uint maxItems = 16;

			bool[] enabledItems = new bool[maxItems];
			float toggleOptionWidth = (EditorGUIUtility.currentViewWidth / 5.0f); // blursed

			MaterialProperty invProp = ph.Property("_UseInventory");
			if (invProp != null)
			{
				using (new EditorGUI.DisabledScope(isBaked == true))
				{
					ph.TogglePropertyHeader("_UseInventory");
					if (PropertyEnabled(invProp)) ph.ShaderProperty("_InventoryStride");
				}
				if (PropertyEnabled(invProp))
				{
					for (int i = 1; i <= maxItems; i++)
					{
						enabledItems[i-1] = ph.Property(String.Format("_InventoryItem{0:00}Animated", i))?.floatValue == 1 ? true : false;
					}
					EditorGUI.BeginChangeCheck();
					for (int i = 0; i < (maxItems/4); i++)
					{	EditorGUILayout.BeginHorizontal("Box");
						enabledItems[i*4+0] = EditorGUILayout.ToggleLeft(
							(i*4+1).ToString(), enabledItems[i*4+0], GUILayout.Width(toggleOptionWidth));
						enabledItems[i*4+1] = EditorGUILayout.ToggleLeft(
							(i*4+2).ToString(), enabledItems[i*4+1], GUILayout.Width(toggleOptionWidth));
						enabledItems[i*4+2] = EditorGUILayout.ToggleLeft(
							(i*4+3).ToString(), enabledItems[i*4+2], GUILayout.Width(toggleOptionWidth));
						enabledItems[i*4+3] = EditorGUILayout.ToggleLeft(
							(i*4+4).ToString(), enabledItems[i*4+3], GUILayout.Width(toggleOptionWidth));
						EditorGUILayout.EndHorizontal();
					};
					if (EditorGUI.EndChangeCheck())
					{
					for (int i = 1; i <= maxItems; i++)
						{
							ph.Property(String.Format("_InventoryItem{0:00}Animated", i)).floatValue = enabledItems[i-1] ? 1 : 0;
						}
					};
				}
			}
		}

		protected void AdvancedOptions()
		{
			EditorGUILayout.Space();

			DrawSectionHeaderArea(ph.Content("s_advancedOptions"));

			EditorGUILayout.Space();

			ph.ShaderProperty("_VertexColorType");

			foreach (Material mat in ph.PropertyDropdown("_AlbedoAlphaMode", CommonStyles.albedoAlphaModeNames, editor))
			{
				SetupMaterialWithAlbedo(mat, ph.Property("_MainTex"), ph.Property("_AlbedoAlphaMode"));
			}

			ph.ShaderProperty("_LightingCalculationType");
			ph.ShaderProperty("_IndirectShadingType");

			EditorGUILayout.Space();

			ph.ShaderProperty("_DiffuseGeomShadowFactor");
			ph.ShaderProperty("_LightWrappingCompensationFactor");

			ph.ShaderProperty("_LightSkew");

			MaterialProperty specProp = ph.Property("_SpecularType");
			if (specProp != null && specProp.floatValue >= 1.0f) 
			{
				if (WithChangeCheck(() => 
				{
					ph.ShaderProperty("_SpecularHighlights");
					ph.ShaderProperty("_GlossyReflections");
				})) {
					MaterialChanged(target);
				}
			};

			StencilOptions(editor, target);
		}

		protected void FooterOptions()
		{
			EditorGUILayout.Space();

			// Only draw the header if Simple mode is active. 
			if (scssSettingsComplexityMode == (int)SettingsComplexityMode.Simple)
			{
				DrawSectionHeaderArea(ph.Content("s_advancedOptions"));
				EditorGUILayout.Space();
			}

			if (WithChangeCheck(() => 
			{
				editor.ShaderProperty(renderQueueOverride, BaseStyles.renderQueueOverride);
			})) {
				MaterialChanged(target);
			}

			// Show the RenderQueueField but do not allow users to directly manipulate it. That is done via the renderQueueOverride.
			
			using (new EditorGUI.DisabledScope(true))
			{
				editor.RenderQueueField();
			}

			editor.EnableInstancingField();
		}

    //-------------------------------------------------------------------------
    // Upgrading and consistency enforcement logic
    //-------------------------------------------------------------------------

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
			(ph.Property("_Matcap1").textureValue == null && ph.Property("_Matcap2").textureValue == null &&
				ph.Property("_Matcap3").textureValue == null && ph.Property("_Matcap4").textureValue == null) &&
		 GetTextureProperty(material, "_AdditiveMatcap"); // Only exists in old materials.
		 if (oldMatcaps)
		 {
		// GetFloat is bugged but GetTexture is not, so we use GetFloatProperty so we can handle null.
		 	float? additiveStrength = GetFloatProperty(material, "_AdditiveMatcapStrength");
		 	float? multiplyStrength = GetFloatProperty(material, "_MultiplyMatcapStrength");
		 	float? medianStrength = GetFloatProperty(material, "_MidBlendMatcapStrength");
		 	Texture additiveMatcap = GetTextureProperty(material, "_AdditiveMatcap");
		 	Texture multiplyMatcap = GetTextureProperty(material, "_MultiplyMatcap");
		 	Texture medianMatcap = GetTextureProperty(material, "_MidBlendMatcap");

		// Mask layout is RGBA
		 	if (additiveMatcap)
		 	{
		 		ph.Property("_Matcap2").textureValue = additiveMatcap;
		 		ph.Property("_Matcap2Blend").floatValue = (float)MatcapBlendModes.Additive;
		 		ph.Property("_Matcap2Strength").floatValue = additiveStrength ?? 1;
		 	}
		 	if (multiplyMatcap) 
		 	{
		 		ph.Property("_Matcap4").textureValue = multiplyMatcap;
		 		ph.Property("_Matcap4Blend").floatValue = (float)MatcapBlendModes.Multiply;
		 		ph.Property("_Matcap4Strength").floatValue = multiplyStrength ?? 0; 
			// Multiply at 1.0 is usually wrong. This also prevents oldMatcaps from being true.
		 	}
		 	if (medianMatcap) 
		 	{
		 		ph.Property("_Matcap3").textureValue = medianMatcap;
		 		ph.Property("_Matcap3Blend").floatValue = (float)MatcapBlendModes.Median;
		 		ph.Property("_Matcap3Strength").floatValue = medianStrength ?? 1;
		 	}
		 }
		}

		protected void UpgradeDetailMaps(Material material)
		{
			// Only transfer details if the new details don't exist. 
			bool newDetails = 
			(material.GetTexture("_DetailAlbedoMask") != null) ||
			(material.GetTexture("_DetailMap1") != null) ||
			(material.GetTexture("_DetailMap2") != null) ||
			(material.GetTexture("_DetailMap3") != null) ||
			(material.GetTexture("_DetailMap4") != null);

			if (newDetails) return;

			bool oldDetails = 
			(material.GetFloat("_UseDetailMaps") == 1.0) &&
			(material.GetTexture("_DetailAlbedoMap") != null) &&
			(material.GetTexture("_DetailNormalMap") != null) &&
			(material.GetTexture("_SpecularDetailMask") != null);

			if (oldDetails)
			{
				Texture detailAlbedoMap = material.GetTexture("_DetailAlbedoMap");
				Texture detailNormalMap = material.GetTexture("_DetailNormalMap");
				Texture specularDetailMask = material.GetTexture("_SpecularDetailMask");

				float? detailAlbedoMapScale = material.GetFloat("_DetailAlbedoMapScale");
				float? detailNormalMapScale = material.GetFloat("_DetailNormalMapScale");
				float? specularDetailStrength = material.GetFloat("_SpecularDetailStrength");

				if (detailAlbedoMap)
				{
					material.SetTexture("_DetailMap1", detailAlbedoMap);
					material.SetFloat("_DetailMap1Type", 0.0f); // Albedo
					material.SetFloat("_DetailMap1Blend", material.GetFloat("_DetailAlbedoBlendMode"));
					material.SetFloat("_DetailMap1Strength", detailAlbedoMapScale ?? 1);
				}
				if (detailNormalMap)
				{
					material.SetTexture("_DetailMap2", detailNormalMap);
					material.SetFloat("_DetailMap2Type", 1.0f); // Normal
					material.SetFloat("_DetailMap2Blend", 0.0f); // Default blend mode
					material.SetFloat("_DetailMap2Strength", detailNormalMapScale ?? 1);
				}
				if (specularDetailMask)
				{
					material.SetTexture("_DetailMap3", specularDetailMask);
					material.SetFloat("_DetailMap3Type", 2.0f); // Specular
					material.SetFloat("_DetailMap3Blend", 0.0f); // Default blend mode
					material.SetFloat("_DetailMap3Strength", specularDetailStrength ?? 1);
				}
			}
		}

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
			// Refresh the material property handler. However, because we don't have the material properties array,
			// and writing the code to make one seems like too much work, just set a flag and have OnGUI do it.
			needsRefresh = true;

			// Use nullable types for Color and float, because Texture is nullable.
			// However, note that SetTexture happily accepts null and will treat that as a command to clear the texture.
			// Randomly wiping texture assignments is generally not liked by users. 
			Dictionary<string, Color?> tColor = new Dictionary<string, Color?>();
			Dictionary<string, float?> tFloat = new Dictionary<string, float?>();
			Dictionary<string, Texture> tTexture = new Dictionary<string, Texture>();

            // Cache old shader properties with potentially different names than the new shader.
            Vector4? textureScaleOffset = null;
            float? cullMode = GetFloatProperty(material, "_Cull");
			
			// Register properties that already exist but may be overridden.
			List<string> colorProps = new List<string>
			{
				"_EmissionColor",
				"_FresnelTint",
				"_FresnelTintInv",
				"_Matcap1Tint",
				"_outline_color",
				"_SpecColor"
			};

			List<string> floatProps = new List<string>
			{
				"_BumpScale",
				"_CelSpecularSoftness",
				"_FresnelLightMask",
				"_FresnelStrength",
				"_FresnelStrengthInv",
				"_FresnelWidth",
				"_FresnelWidthInv",
				"_Matcap1Blend",
				"_Matcap1Strength",
				"_outline_width",
				"_OutlineMode",
				"_Smoothness",
				"_SpecularType",
				"_UseFresnel",
				"_UseFresnelLightMask",
				"_UseMatcap"
			};
			
			List<string> floatPropsCrosstone = new List<string>
			{
				"_1st_ShadeColor_Feather",
				"_1st_ShadeColor_Step",
				"_2nd_ShadeColor_Feather",
				"_2nd_ShadeColor_Step",
				"_Crosstone2ndSeparation",
				"_CrosstoneToneSeparation",
			};

			List<string> textureProps = new List<string>
			{
				"_BumpMap",
				"_EmissionMap",
				"_Matcap1",
				"_MatcapMask",
				"_OutlineMask",
				"_SpecGlossMap",
			};

			List<string> texturePropsCrosstone = new List<string>
			{
				"_1st_ShadeMap",
				"_2nd_ShadeMap",
				"_ShadingGradeMap",
			};
			
			// Todo: Nothing Lightramp here because we don't transfer from any shaders that use ramps.
			List<string> emptyList = new List<string> {};

			floatProps.AddRange(newShader.name.Contains("Crosstone") ? floatPropsCrosstone : emptyList );
			textureProps.AddRange(newShader.name.Contains("Crosstone") ? texturePropsCrosstone : emptyList );

			foreach (string p in colorProps) { tColor[p] = GetColorProperty(material, p); };
			foreach (string p in floatProps) { tFloat[p] = GetFloatProperty(material, p); };
			foreach (string p in textureProps) { tTexture[p] = GetTextureProperty(material, p); };

            int? stencilReference = GetIntProperty(material, "_Stencil");
            int? stencilComparison = GetIntProperty(material, "_StencilComp");
            int? stencilOperation = GetIntProperty(material, "_StencilOp");
            int? stencilFail = GetIntProperty(material, "_StencilFail");

            if (oldShader)
            {
				if (oldShader.name.Contains("Silent's Cel Shading"))
				{
					// Handle the case where someone swaps the outline mode by changing from 
					// the (Outline) to the no outline shader.
					if (oldShader.name.Contains("Outline") && !newShader.name.Contains("Outline"))
					{
						tFloat["_OutlineMode"] = 0.0f;
					}
					if (!oldShader.name.Contains("Outline") && newShader.name.Contains("Outline"))
					{
						tFloat["_OutlineMode"] = 1.0f;
					}
					// Handle transferring from really old versions.
					if (oldShader.name.Contains(TransparentCutoutShadersPath))
					{
						tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Cutout;
						tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Cutout;
					}
					else if (oldShader.name.Contains(TransparentShadersPath))
					{
						tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Fade;
						tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Fade;
					}
				}
            	if (oldShader.name.Contains("UnityChanToonShader") || oldShader.name.Contains("Toon (Built-in)"))
                {
					// Build translation table.
                    tTexture["_BumpMap"] = GetTextureProperty(material, "_NormalMap");
                    // _Tweak_ShadingGradeMapLevel is named the same.

					if (GetFloatProperty(material, "_Inverse_Clipping") == 1) Debug.Log("Note: Inverse clipping currently not supported.");
					if (GetTextureProperty(material, "_ClippingMask")) tFloat["_AlbedoAlphaMode"] = (float)AlbedoAlphaMode.ClippingMask;
                    tFloat["_Tweak_Transparency"] = GetFloatProperty(material, "_Tweak_transparency");
                    tFloat["_Cutoff"] = 1.0f - GetFloatProperty(material, "_Clipping_Level") ?? 0;
					
                    // Tone seperation is based on whether BaseAs1st is set.
                    // 2nd seperation is based on whether 1stAs2nd is set.
                    tFloat["_CrosstoneToneSeparation"] = 1.0f - GetFloatProperty(material, "_Use_BaseAs1st") ?? 0;
                    tFloat["_Crosstone2ndSeparation"] = 1.0f - GetFloatProperty(material, "_Use_1stAs2nd") ?? 0;
					
                    if (oldShader.name.Contains("DoubleShadeWithFeather"))
                    {
                        tFloat["_1st_ShadeColor_Step"]    = GetFloatProperty(material, "_BaseColor_Step");
                        tFloat["_1st_ShadeColor_Feather"] = GetFloatProperty(material, "_BaseShade_Feather");
                        tFloat["_2nd_ShadeColor_Step"]    = GetFloatProperty(material, "_ShadeColor_Step");
                        tFloat["_2nd_ShadeColor_Feather"] = GetFloatProperty(material, "_1st2nd_Shades_Feather");
                    }

					// Emission properties are not fully supported.
					tTexture["_EmissionMap"] = GetTextureProperty(material, "_Emissive_Tex");
					tColor["_EmissionColor"] = GetColorProperty(material, "_Emissive_Color");

                    // HighColor is only supported in Specular mode
                    Texture highColorTex = GetTextureProperty(material, "_HighColor_Tex");
					Texture highColorMask = GetTextureProperty(material, "_Set_HighColorMask");
					if (highColorTex) 
					{ 
						tTexture["_SpecGlossMap"] = highColorTex;
						// Setup specular detail mask in slot 3
						tTexture["_DetailMap3"] = highColorMask; 
						tFloat["_DetailMap3Type"] = 2.0f; // Specular
						tFloat["_DetailMap3Blend"] = 0.0f; // Default blend mode
						tFloat["_DetailMap3Strength"] = 1.0f;
					} else { 
						tTexture["_SpecGlossMap"] = highColorMask; 
					};

                    tFloat["_SpecularType"] = (float)SpecularType.Cel * GetFloatProperty(material, "_Is_SpecularToHighColor") ?? 0 ;

                    tColor["_SpecColor"] = new Vector4(1,1,1,0.1f) * GetColorProperty(material, "_HighColor") ?? (Color.white);

                    float? smoothness = GetFloatProperty(material, "_HighColor_Power");
                    if (smoothness.HasValue) tFloat["_Smoothness"] = 1.0f - smoothness;
					tFloat["_CelSpecularSoftness"] = GetFloatProperty(material, "_Is_SpecularToHighColor");

                    // Rim lighting works differently here, but there's not much we can do about it. 
					tFloat["_UseFresnel"] = (float)AmbientFresnelType.Lit * GetFloatProperty(material, "_RimLight") ?? 0;
                    tColor["_FresnelTint"] = GetColorProperty(material, "_RimLightColor");
					tFloat["_FresnelWidth"] = GetFloatProperty(material, "_RimLight_Power") ?? 0 * 10;
                    tFloat["_FresnelStrength"] = 1.0f - GetFloatProperty(material, "_RimLight_FeatherOff") ?? 0;

                    tFloat["_UseFresnelLightMask"] = GetFloatProperty(material, "_LightDirection_MaskOn");
                    tFloat["_FresnelLightMask"] = 1.0f + GetFloatProperty(material, "_Tweak_LightDirection_MaskLevel") ?? 0;
                    //GetFloatProperty(material, "_Add_Antipodean_RimLight");
                    tColor["_FresnelTintInv"] = GetColorProperty(material, "_Ap_RimLightColor");
                    tFloat["_FresnelWidthInv"] = 10 * GetFloatProperty(material, "_Ap_RimLight_Power") ?? 0;
                    tFloat["_FresnelStrengthInv"] = 1.0f - GetFloatProperty(material, "_Ap_RimLight_FeatherOff") ?? 0;
                    //GetTextureProperty(material, "_Set_RimLightMask");

                    // Matcap properties are not fully supported
                    tFloat["_UseMatcap"] = GetFloatProperty(material, "_MatCap");
                    tTexture["_Matcap1"] = GetTextureProperty(material, "_MatCap_Sampler");
                    tTexture["_MatcapMask"] = GetTextureProperty(material, "_Set_MatcapMask");
                    tColor["_Matcap1Tint"] = GetColorProperty(material, "_MatCapColor");
                    // _Is_LightColor_MatCap is not supported.
                    tFloat["_Matcap1Blend"] = 1.0f - GetFloatProperty(material, "_Is_BlendAddToMatCap") ?? 0;
					// This seems to be used as a strength setting.
					tFloat["_Matcap1Strength"] = 1.0f - GetFloatProperty(material, "_Tweak_MatcapMaskLevel");
                    // _Tweak_MatCapUV, _Rotate_MatCapUV are not yet supported.
                    // _Is_NormalMapForMatCap, _NormalMapForMatCap, _BumpScaleMatcap, _Rotate_NormalMapForMatCapUV
                    // are not supported.

                    tFloat["_OutlineMode"] = 1.0f;
                    if (oldShader.name.Contains("NoOutline"))
                    {
                    	tFloat["_OutlineMode"] = 0.0f;
                	}
                    tColor["_outline_color"] = GetColorProperty(material, "_Outline_Color");
            		tFloat["_outline_width"] = 0.1f * GetFloatProperty(material, "_Outline_Width") ?? 1.0f;
					tFloat["_OutlineZPush"] = GetFloatProperty(material, "_Offset_Z");
            		tTexture["_OutlineMask"] = GetTextureProperty(material, "_Outline_Sampler");

                    // Stencil properties
                    if (oldShader.name.Contains("StencilMask"))
                    {
                    	//Debug.Log(GetIntProperty(material, "_StencilNo") % 256);
                    	stencilReference = (int)GetIntProperty(material, "_StencilNo") % 256;
                    	stencilComparison = (int)CompareFunction.Always;
                    	stencilOperation = (int)StencilOp.Replace;
						stencilFail = (int)StencilOp.Replace;

                	}
                    if (oldShader.name.Contains("StencilOut"))
                    {
                    	//Debug.Log(GetIntProperty(material, "_StencilNo") % 256);
                    	stencilReference = (int)GetIntProperty(material, "_StencilNo") % 256;
                    	stencilComparison = (int)CompareFunction.NotEqual;
                    	stencilOperation = (int)StencilOp.Keep;
						stencilFail = (int)StencilOp.Keep;
                	}

					// Transparency modes
	            	if (oldShader.name.Contains("Clipping"))
	                {
						// Treat Clipping as cutout
	                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Cutout;
                    	tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Cutout;
	                }
	            	if (oldShader.name.Contains("TransClipping"))
	                {
						// TransClipping mode depends on a depth prepass with cutout
						// This is difficult to support and would have low performance, and more importantly,
						// alpha to coverage can replicate it pretty well, so set to cutout.
	                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Cutout;
                    	tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Cutout;
	                }
	            	if (oldShader.name.Contains("Transparent"))
	                {
						// Treat Transparent mode as Fade transparency.
	                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Fade;
                    	tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Fade;
	                }
					
                }
            	if (oldShader.name.Contains("Reflex Shader 2"))
                {
					// Todo
				}
            	if (oldShader.name.Contains("lilToon"))
                {
	            	if (oldShader.name.Contains("Cutout"))
	                {
	                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Cutout;
                    	tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Cutout;
						tTexture["_ClippingMask"] = GetTextureProperty(material, "_AlphaMask");
	                }
	            	if (oldShader.name.Contains("Transparent"))
	                {
						// Treat Transparent mode as Fade transparency.
	                    tFloat[BaseStyles.renderingModeName] = (float)RenderingMode.Fade;
                    	tFloat[BaseStyles.customRenderingModeName] = (float)CustomRenderingMode.Fade;
	                }
                    if (oldShader.name.Contains("Outline"))
                    {
                    	tFloat["_OutlineMode"] = 1.0f;
                	}

					tColor["_1st_ShadeColor"] = GetColorProperty(material, "_ShadowColor");
					tTexture["_1st_ShadeMap"] = GetTextureProperty(material, "_ShadowColorTex");
                    tFloat["_1st_ShadeColor_Step"]    = GetFloatProperty(material, "_ShadowBorder");
                    tFloat["_1st_ShadeColor_Feather"] = 2.0f * GetFloatProperty(material, "_ShadowBlur") ?? 0;

					tColor["_2nd_ShadeColor"] = GetColorProperty(material, "_Shadow2ndColor");
					tTexture["_2nd_ShadeMap"] = GetTextureProperty(material, "_Shadow2ndColorTex");
                    tFloat["_2nd_ShadeColor_Step"]    = GetFloatProperty(material, "_Shadow2ndBorder");
                    tFloat["_2nd_ShadeColor_Feather"] = 2.0f * GetFloatProperty(material, "_Shadow2ndBlur") ?? 0;

                    tFloat["_UseMatcap"] = GetFloatProperty(material, "_UseMatCap");
                    tColor["_Matcap1Tint"] = GetColorProperty(material, "_MatCapColor");
                    tTexture["_Matcap1"] = GetTextureProperty(material, "_MatCapTex");
					tFloat["_Matcap1Strength"] = GetFloatProperty(material, "_MatCapBlend");
                    tTexture["_MatcapMask"] = GetTextureProperty(material, "_MatCapBlendMask");
					float? matcapType = GetFloatProperty(material, "_MatCapBlendMode");
                    switch ( matcapType )
					{
						case 0f: tFloat["_Matcap1Blend"] = (float)MatcapBlendModes.Additive; break;
						case 1f: tFloat["_Matcap1Blend"] = (float)MatcapBlendModes.Additive; break;
						case 2f: tFloat["_Matcap1Blend"] = (float)MatcapBlendModes.Median; break;
						case 3f: tFloat["_Matcap1Blend"] = (float)MatcapBlendModes.Multiply; break;
					};
					
					tFloat["_UseFresnel"] = (float)AmbientFresnelType.Lit * GetFloatProperty(material, "_UseRim") ?? 0;
                    tColor["_FresnelTint"] = GetColorProperty(material, "_RimColor");
					tFloat["_FresnelWidth"] = GetFloatProperty(material, "_RimBorder");
                    tFloat["_FresnelStrength"] = 1.0f - GetFloatProperty(material, "_RimBlur") ?? 0;
					//tFloat["_FresnelPower"] = GetFloatProperty(material, "_RimFresnelPower");

					tColor["_outline_color"] = GetColorProperty(material, "_OutlineColor");
            		tFloat["_outline_width"] = GetFloatProperty(material, "_OutlineWidth");
					tTexture["_OutlineMask"] = GetTextureProperty(material, "_OutlineWidthMask");

					tColor["_EmissionColor"] = GetColorProperty(material, "_EmissionColor") * GetFloatProperty(material, "_UseEmission");

				}
            }

			float? outlineMode = tFloat["_OutlineMode"];
			float? specularType = tFloat["_SpecularType"];

            base.AssignNewShaderToMaterial(material, oldShader, newShader);

            // Apply old shader properties to the new shader.
            SetVectorProperty(material, "_MainTex_ST", textureScaleOffset);
            SetShaderFeatureActive(material, null, "_CullMode", cullMode);

			// Assign gathered properties. 
			foreach (KeyValuePair<string, Color?> e in tColor)    { SetColorProperty(material, e.Key, e.Value); };
			foreach (KeyValuePair<string, float?> e in tFloat)    { SetFloatProperty(material, e.Key, e.Value); };

			// SetTexture can clear textures, while Set...Property will only set if not null. 
			foreach (KeyValuePair<string, Texture> e in tTexture) 
			{ 
				if (e.Value == null) continue;
				material.SetTexture(e.Key, e.Value); 
			};

			SetIntProperty(material, "_Stencil", stencilReference);
			SetIntProperty(material, "_StencilComp", stencilComparison);
			SetIntProperty(material, "_StencilOp", stencilOperation);
			SetIntProperty(material, "_StencilFail", stencilFail);

            if (outlineMode.HasValue) SetupMaterialWithOutlineMode(material, (OutlineMode)outlineMode);
			if (specularType.HasValue) SetupMaterialWithSpecularType(material, (SpecularType)specularType);

            // Setup the rendering mode based on the old shader.
            if (oldShader == null || !oldShader.name.Contains(LegacyShadersPath))
            {
                SetupMaterialWithRenderingMode(material, (RenderingMode)material.GetFloat(BaseStyles.renderingModeName), CustomRenderingMode.Opaque, -1);
            }
			else
            {
                MaterialChanged(material);
            }
        }

		protected static void SetupMaterialWithAlbedo(Material material, MaterialProperty albedoMap, MaterialProperty albedoAlphaMode)
		{
			switch ((AlbedoAlphaMode)albedoAlphaMode.floatValue)
			{
				case AlbedoAlphaMode.Transparency:
				{
					material.DisableKeyword(CommonStyles.albedoMapAlphaSmoothnessName);
				}
				break;

				case AlbedoAlphaMode.Smoothness:
				{
					material.EnableKeyword(CommonStyles.albedoMapAlphaSmoothnessName);
				}
				break;
			}
		}

		protected static void SetupMaterialWithOutlineMode(Material material, OutlineMode outlineMode)
		{
			string[] oldShaderName = material.shader.name.Split('/');
            const string outlineName = " (Outline)"; //
            var currentlyOutline = oldShaderName[oldShaderName.Length - 1].Contains(outlineName);
            switch ((OutlineMode)outlineMode)
            {
            	case OutlineMode.None:
            	if (currentlyOutline) {
            		string[] newShaderName = oldShaderName;
            		string newSubShader = oldShaderName[oldShaderName.Length - 1].Replace(outlineName, "");
            		newShaderName[oldShaderName.Length - 1] = newSubShader;
            		Shader finalShader = Shader.Find(String.Join("/", newShaderName));
                    // If we can't find it, pass.
            		if (finalShader != null) {
            			material.shader = finalShader;
            		}
            	}
            	break;
            	case OutlineMode.Tinted:
            	case OutlineMode.Colored:
            	if (!currentlyOutline) {
            		string[] newShaderName = oldShaderName;
            		string newSubShader = oldShaderName[oldShaderName.Length - 1] + outlineName;
            		newShaderName[oldShaderName.Length - 1] = newSubShader;
            		Shader finalShader = Shader.Find(String.Join("/", newShaderName));
                    // If we can't find it, pass.
            		if (finalShader != null) {
            			material.shader = finalShader;
            		}
            	}
            	break;
            }
        }

		protected static void SetupMaterialWithFurMode(Material material, FurMode furMode)
		{
			string[] oldShaderName = material.shader.name.Split('/');
			const string furName = " (Fur)";
			var currentlyFur = oldShaderName[oldShaderName.Length - 1].Contains(furName);
			switch ((FurMode)furMode)
			{
				case FurMode.None:
				if (currentlyFur) {
					string[] newShaderName = oldShaderName;
					string newSubShader = oldShaderName[oldShaderName.Length - 1].Replace(furName, "");
					newShaderName[oldShaderName.Length - 1] = newSubShader;
					Shader finalShader = Shader.Find(String.Join("/", newShaderName));
					// If we can't find it, pass.
					if (finalShader != null) {
						material.shader = finalShader;
					}
				}
				break;
				case FurMode.On:
				if (!currentlyFur) {
					string[] newShaderName = oldShaderName;
					string newSubShader = oldShaderName[oldShaderName.Length - 1] + furName;
					newShaderName[oldShaderName.Length - 1] = newSubShader;
					Shader finalShader = Shader.Find(String.Join("/", newShaderName));
					// If we can't find it, pass.
					if (finalShader != null) {
						material.shader = finalShader;
					}
				}
				break;
			}
		}

        protected static void SetupMaterialWithSpecularType(Material material, SpecularType specularType)
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

		protected static void UnbakedCheck(Material material)
		{
			// Unset __Baked if the shader is not in Hidden
			// Also, check if the shader is in a BakedShaders directory
			if (material.GetFloat("__Baked") == 1)
			{
				Shader shader = material.shader;
				string shaderFilePath = AssetDatabase.GetAssetPath(shader);
				
				bool isInBakedShaders = shaderFilePath.IndexOf("BakedShaders", StringComparison.OrdinalIgnoreCase) >= 0;
				bool isInHiddenShaders = shader.name.StartsWith("Hidden/", StringComparison.OrdinalIgnoreCase);

				if (isInBakedShaders || isInHiddenShaders)
				{
					// Gracefully unlock it. 
					ShaderOptimizer.Unlock(material);
					material.SetFloat("__Baked", 0.0f);
				}
				else
				{
					// The shader has __Baked set, but is not using a baked shader.
					// Just remove the flag.
					material.SetFloat("__Baked", 0.0f);
				}
			}
		}

	}
}