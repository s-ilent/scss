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

		public enum SettingsComplexityMode
		{
			Complex,
			Normal,
			Simple
		}

		public enum TransparencyMode
		{
			Soft,
			Sharp
		}

		public enum DetailEmissionMode
		{
			Phase,
			AudioLink
		}

		protected Material target;
		protected MaterialEditor editor;
		protected Dictionary<string, MaterialProperty> props = new Dictionary<string, MaterialProperty>();

    	public int scssSettingsComplexityMode = 1;

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

		protected override void FindProperties(MaterialProperty[] matProps)
		{ 
			base.FindProperties(matProps);
			
			foreach (MaterialProperty prop in matProps)
			{
				props[prop.name] = FindProperty(prop.name, matProps, false);
			}
		}

		protected override void MaterialChanged(Material material)
		{
			InitialiseStyles();

			if (!Int32.TryParse(EditorUserSettings.GetConfigValue("scss_settings_complexity_mode"), out scssSettingsComplexityMode))
			{
				scssSettingsComplexityMode = 1;
			}

			// Handle old materials
			UpgradeMatcaps(material);
			UpgradeVariantCheck(material);

			SetupMaterialWithAlbedo(material, 
				props["_MainTex"], 
				props["_AlbedoAlphaMode"]);

				
			MaterialProperty outlineProp;
			if (props.TryGetValue("_OutlineMode", out outlineProp))
			{
				SetupMaterialWithOutlineMode(material, (OutlineMode)outlineProp.floatValue);
			}

			MaterialProperty specProp;
			if (props.TryGetValue("_SpecularType", out specProp))
			{
				SetupMaterialWithSpecularType(material, (SpecularType)specProp.floatValue);
			}
			
			SetMaterialKeywords(material);

			base.MaterialChanged(material);
		}
		
		protected MaterialProperty Property(string i)
		{
			MaterialProperty prop;
			if (props.TryGetValue(i, out prop))
			{
				return prop;
			} 
			return null;
		}

		protected GUIContent Content(string i)
		{
			GUIContent style;
			if (!styles.TryGetValue(i, out style))
			{
				style = new GUIContent(i);
			}
			return style;
		}

		protected Rect DisabledLabel(GUIContent style)
		{
			EditorGUI.BeginDisabledGroup(true);
			Rect rect = EditorGUILayout.GetControlRect();
			EditorGUI.LabelField(rect, style);
			EditorGUI.EndDisabledGroup();
			return rect;
		}

		protected Rect TexturePropertySingleLine(string i)
		{
			MaterialProperty prop = Property(i);
			GUIContent style = Content(i);
			if (prop != null) 
			{
				return editor.TexturePropertySingleLine(style, prop);
			} else {
				return DisabledLabel(style);
			}
		}

		protected Rect TexturePropertySingleLine(string i, string i2)
		{
			GUIContent style = Content(i);
			MaterialProperty prop = Property(i);
			MaterialProperty prop2 = Property(i2);
			if (prop != null) 
			{
				return editor.TexturePropertySingleLine(style, prop, prop2);
			} else {
				return DisabledLabel(style);
			}
		}

		protected Rect TexturePropertySingleLine(string i, string i2, string i3)
		{
			GUIContent style = Content(i);
			MaterialProperty prop = Property(i);
			MaterialProperty prop2 = Property(i2);
			MaterialProperty prop3 = Property(i3);
			if (prop != null) 
			{
				return editor.TexturePropertySingleLine(style, prop, prop2, prop3);
			} else {
				return DisabledLabel(style);
			}
		}

		protected Rect TextureColorPropertyWithColorReset(string tex, string col)
		{
            bool hadTexture = props[tex].textureValue != null;
			Rect returnRect = TexturePropertySingleLine(tex, col);
			
            float brightness = props[col].colorValue.maxColorComponent;
            if (props[tex].textureValue != null && !hadTexture && brightness <= 0f)
                props[col].colorValue = Color.white;
			return returnRect;
		}

		protected Rect TextureColorPropertyWithColorReset(string tex, string col, string prop)
		{
            bool hadTexture = props[tex].textureValue != null;
			Rect returnRect = TexturePropertySingleLine(tex, col, prop);
			
            float brightness = props[col].colorValue.maxColorComponent;
            if (props[tex].textureValue != null && !hadTexture && brightness <= 0f)
                props[col].colorValue = Color.white;
			return returnRect;
		}

		protected Rect TexturePropertyWithHDRColor(string i, string i2)
		{
			GUIContent style = Content(i);
			MaterialProperty prop = Property(i);
			MaterialProperty prop2 = Property(i2);
			if (prop != null) 
			{
				return editor.TexturePropertyWithHDRColor(style, prop, prop2, false);
			} else {
				return DisabledLabel(style);
			}
		}

		protected bool ShaderProperty(string i)
		{
			MaterialProperty prop;
			GUIContent style;

			if (!styles.TryGetValue(i, out style))
			{
				style = new GUIContent(i);
			}

			if (props.TryGetValue(i, out prop))
			{
				editor.ShaderProperty(prop, style);
				return true;
			} else {
				DisabledLabel(style);
			}
			return false;
		}

		protected bool TogglePropertyHeader(string i, bool display = true)
		{
			if (display) return ShaderProperty(i);
			return false;
		}
		
        protected static void Vector2Property(MaterialProperty property, GUIContent name)
        {
            EditorGUI.BeginChangeCheck();
            Vector2 vector2 = EditorGUILayout.Vector2Field(name,new Vector2(property.vectorValue.x, property.vectorValue.y),null);
            if (EditorGUI.EndChangeCheck())
                property.vectorValue = new Vector4(vector2.x, vector2.y, property.vectorValue.z, property.vectorValue.w);
        }
        protected static void Vector2PropertyZW(MaterialProperty property, GUIContent name)
        {
            EditorGUI.BeginChangeCheck();
            Vector2 vector2 = EditorGUILayout.Vector2Field(name,new Vector2(property.vectorValue.z, property.vectorValue.w),null);
            if (EditorGUI.EndChangeCheck())
                property.vectorValue = new Vector4(property.vectorValue.x, property.vectorValue.y, vector2.x, vector2.y);
        }

        protected void DrawShaderPropertySameLine(string i) {
			MaterialProperty prop;

        	int HEADER_HEIGHT = 22; // Arktoon default
            Rect r = EditorGUILayout.GetControlRect(true,0,EditorStyles.layerMaskField);
            r.y -= HEADER_HEIGHT;
            r.height = MaterialEditor.GetDefaultPropertyHeight(props[i]);

			if (props.TryGetValue(i, out prop))
			{
				editor.ShaderProperty(r, prop, " ");
			} 
        }

		protected GUIStyle scmStyle;
		protected GUIStyle sectionHeader;
		protected GUIStyle sectionHeaderBox;

		protected void InitialiseStyles()
		{
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

		public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] matProps)
		{ 
			this.target = materialEditor.target as Material;
			this.editor = materialEditor;
			Material material = this.target;

			CheckShaderType(material);
			
			ShaderBakeHeader();
			
			bool isBaked = false;
			{
				MaterialProperty bakedSettings;
				props.TryGetValue("__Baked", out bakedSettings);
				isBaked = (bakedSettings != null && bakedSettings.floatValue == 1);
			}

            if (isBaked) EditorGUI.BeginDisabledGroup(true);
			base.OnGUI(materialEditor, matProps);
            if (isBaked) EditorGUI.EndDisabledGroup();
			SettingsComplexityArea();
            if (isBaked) EditorGUI.BeginDisabledGroup(true);
			MainOptions();
			ShadingOptions();
			
			switch ((SettingsComplexityMode)scssSettingsComplexityMode)
			{
				case SettingsComplexityMode.Simple:
					DrawSectionHeaderArea(Content("s_renderingOptions"));
					EmissionOptions();
					OutlineOptions();
            if (isBaked) EditorGUI.EndDisabledGroup();
					ManualButtonArea();
            if (isBaked) EditorGUI.BeginDisabledGroup(true);
					break;
				case SettingsComplexityMode.Normal:
					RenderingOptions();
					OutlineOptions();
					EmissionOptions();
            if (isBaked) EditorGUI.EndDisabledGroup();
					ManualButtonArea();
            if (isBaked) EditorGUI.BeginDisabledGroup(true);
					AdvancedOptions();
					break;
				default:
				case SettingsComplexityMode.Complex:
					RenderingOptions();
					OutlineOptions();
					DetailOptions();
					EmissionOptions();
					MiscOptions();
            if (isBaked) EditorGUI.EndDisabledGroup();
					ManualButtonArea();
            if (isBaked) EditorGUI.BeginDisabledGroup(true);
					AdvancedOptions();
					break;
			}
            if (isBaked) EditorGUI.EndDisabledGroup();
			
			FooterOptions();
		}

		protected string[] SettingsComplexityModeOptions = new string[]
		{
			"Complex", "Normal", "Simple"
		};

		protected void SettingsComplexityArea()
		{
			SettingsComplexityModeOptions[0] = Content("s_fullComplexity").text;
			SettingsComplexityModeOptions[1] = Content("s_normalComplexity").text;
			SettingsComplexityModeOptions[2] = Content("s_simpleComplexity").text;
			EditorGUILayout.Space();

			if (WithChangeCheck(() =>
			{
				scssSettingsComplexityMode = EditorGUILayout.Popup(scssSettingsComplexityMode, SettingsComplexityModeOptions, scmStyle);
			})) 
			{
				EditorUserSettings.SetConfigValue("scss_settings_complexity_mode", scssSettingsComplexityMode.ToString());
			}
		}

		protected void ShaderBakeHeader()
		{
            Rect r = EditorGUILayout.GetControlRect(true,0,EditorStyles.layerMaskField);
				r.x -= 12.0f;
				r.y -= 8.0f;
				r.height = 18.0f;
				r.width += 4.0f;
			float maxWidth = 128.0f;
			Rect r2 = r;
				r2.x = r.width - maxWidth + 14.0f;
				r2.width = maxWidth;
			GUI.Box(r, "", EditorStyles.toolbar);

			GUIContent s_bakeButton;
			MaterialProperty shaderOptimizer;
			// Create the GUIContent for the button so it can be rendered.
			if (!props.TryGetValue("__Baked", out shaderOptimizer))
			{
				s_bakeButton = new GUIContent ("s_bakeButton");
			}
			else
			{
				// Determine whether we're baking or unbaking materials. 
				if (shaderOptimizer.floatValue == 1) 
				{
					if (!styles.TryGetValue("s_bakeButtonRevert", out s_bakeButton)) 
						s_bakeButton = new GUIContent ("s_bakeButtonRevert");
				} 
				else
				{
					if (editor.targets.Length == 1)
					{
						if (!styles.TryGetValue("s_bakeButton", out s_bakeButton)) 
							s_bakeButton = new GUIContent ("s_bakeButton");
					} 
					else 
					{
						if (!styles.TryGetValue("s_bakeButtonPlural", out s_bakeButton)) 
							s_bakeButton = new GUIContent ("s_bakeButtonPlural");
						s_bakeButton = new GUIContent(s_bakeButton);
						s_bakeButton.text = String.Format(s_bakeButton.text, "" + editor.targets.Length.ToString());
					}
				}
			}
			// Draw the button. Because of Unity shenanigans, if we don't always draw the button, 
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
			EditorGUILayout.LabelField("", EditorStyles.label); // Spacing only
		}
		
		protected void MainOptions()
		{ 
			EditorGUILayout.Space();
		
			DrawSectionHeaderArea(Content("s_mainOptions"));

			EditorGUILayout.Space();
			TexturePropertySingleLine("_MainTex", "_Color");

			TexturePropertySingleLine("_BumpMap", "_BumpScale");

			TexturePropertySingleLine("_ColorMask");

			// For Standard compatibility, but not sure what the purpose is
			if (WithChangeCheck(() => 
			{
				editor.TextureScaleOffsetProperty(props["_MainTex"]);
			}))
			{
				props["_EmissionMap"].textureScaleAndOffset = props["_MainTex"].textureScaleAndOffset;		
			}

			if ((AlbedoAlphaMode)props["_AlbedoAlphaMode"].floatValue == AlbedoAlphaMode.ClippingMask)
			{
				EditorGUILayout.Space();
				TexturePropertySingleLine("_ClippingMask", "_Tweak_Transparency");
				editor.TextureScaleOffsetProperty(props["_ClippingMask"]);
			}
			EditorGUILayout.Space();

			if ((RenderingMode)props[BaseStyles.renderingModeName].floatValue > 0)
			{
				foreach (Material mat in WithMaterialPropertyDropdown(props["_AlphaSharp"], Enum.GetNames(typeof(TransparencyMode)), editor))
				{
					SetupMaterialWithTransparencyMode(mat, (TransparencyMode)props["_AlphaSharp"].floatValue);
				}
				ShaderProperty("_Cutoff");
			}
		}

		protected void ShadingOptions()
		{
			EditorGUILayout.Space();
			DrawSectionHeaderArea(Content("s_shadingOptions"));
			if (usingLightramp) LightrampOptions();
			if (usingCrosstone) CrosstoneOptions();
		}

		protected void RenderingOptions()
		{ 
			EditorGUILayout.Space();
			DrawSectionHeaderArea(Content("s_renderingOptions"));

			SpecularOptions();
			RimlightOptions();
			MatcapOptions();
		}

		protected void DetailOptions()
		{
			EditorGUILayout.Space();
			DrawSectionHeaderArea(Content("s_detailOptions"));
			SubsurfaceOptions();
			DetailMapOptions();
		}

		protected void EmissionOptions()
		{
			EditorGUILayout.Space();

			MaterialProperty emissionMapProp;
			if (props.TryGetValue("_EmissionMap", out emissionMapProp)) 
			{
				bool hadEmissionTexture = emissionMapProp.textureValue != null;
				TexturePropertyWithHDRColor("_EmissionMap", "_EmissionColor");
				// If texture was assigned and color was black set color to white
				float brightness = props["_EmissionColor"].colorValue.maxColorComponent;
				if (emissionMapProp.textureValue != null && !hadEmissionTexture && brightness <= 0f)
					props["_EmissionColor"].colorValue = Color.white;
				EditorGUILayout.Space();
			}

			if (ShaderProperty("_UseAdvancedEmission") && PropertyEnabled(props["_UseAdvancedEmission"]))
			{
				target.EnableKeyword("_EMISSION");
				TexturePropertySingleLine("_DetailEmissionMap");
				editor.TextureScaleOffsetProperty(props["_DetailEmissionMap"]);
				ShaderProperty("_DetailEmissionUVSec");
				EditorGUI.indentLevel ++;
				
				WithMaterialPropertyDropdown(props["_EmissionDetailType"], Enum.GetNames(typeof(DetailEmissionMode)), editor);
				MaterialProperty deProp;
				if (props.TryGetValue("_EmissionDetailType", out deProp))
				{
					switch ((DetailEmissionMode)deProp.floatValue)
					{
						case DetailEmissionMode.Phase:
						//ShaderProperty("_EmissionDetailParams");
						Vector2Property(props["_EmissionDetailParams"], Content("s_EmissionDetailScroll"));
						Vector2PropertyZW(props["_EmissionDetailParams"], Content("s_EmissionDetailPhase"));
						break;
						case DetailEmissionMode.AudioLink:
						// AudioLink
						ShaderProperty("_alColorR");
						ShaderProperty("_alColorG");
						ShaderProperty("_alColorB");
						ShaderProperty("_alColorA");
						ShaderProperty("_alBandR");
						ShaderProperty("_alBandG");
						ShaderProperty("_alBandB");
						ShaderProperty("_alBandA");
						ShaderProperty("_alModeR");
						ShaderProperty("_alModeG");
						ShaderProperty("_alModeB");
						ShaderProperty("_alModeA");
						ShaderProperty("_alTimeRange");
						ShaderProperty("_alUseFallback");
						ShaderProperty("_alFallbackBPM");
						ShaderProperty("_UseEmissiveLightSense");
						ShaderProperty("_EmissiveLightSenseStart");
						ShaderProperty("_EmissiveLightSenseEnd");
						break;
						default:
						break;
					}
				}
            	EditorGUI.indentLevel --;
			} else {
				target.DisableKeyword("_EMISSION");
			}
			EditorGUILayout.Space();
			ShaderProperty("_CustomFresnelColor");
			// For some reason, this property doesn't have spacing after it
			EditorGUILayout.Space();
		}

		protected void MiscOptions()
		{
			EditorGUILayout.Space();
			DrawSectionHeaderArea(Content("s_miscOptions"));
			EditorGUILayout.Space();
			ShaderProperty("_PixelSampleMode");
			AnimationOptions();
			VanishingOptions();
		}

        protected void LightrampOptions()
        { 
			EditorGUILayout.Space();
			
			foreach (Material mat in WithMaterialPropertyDropdown(props["_LightRampType"], Enum.GetNames(typeof(LightRampType)), editor))
			{
				SetupMaterialWithLightRampType(mat, (LightRampType)props["_LightRampType"].floatValue);
			}
			
            if ((LightRampType)props["_LightRampType"].floatValue != LightRampType.None) 
            {
                WithGroupHorizontal(() => 
				{
					TexturePropertySingleLine("_Ramp");
					if (GUILayout.Button(Content("s_gradientEditorButton"), "button"))
					{
						XSGradientEditor.callGradientEditor(target);
					}
				});
            }
            ShaderProperty("_ShadowLift");
            ShaderProperty("_IndirectLightingBoost");
            
            EditorGUILayout.Space();

            TexturePropertySingleLine("_ShadowMask", "_ShadowMaskColor");

			foreach (Material mat in WithMaterialPropertyDropdown(props["_ShadowMaskType"], Enum.GetNames(typeof(ShadowMaskType)), editor))
			{
				SetupMaterialWithShadowMaskType(mat, (ShadowMaskType)props["_ShadowMaskType"].floatValue);
			}

            ShaderProperty("_Shadow");
        }
		
		protected void CrosstoneOptions()
		{ 
            EditorGUILayout.Space();
			WithGroupHorizontal(() => {
				TextureColorPropertyWithColorReset("_1st_ShadeMap", "_1st_ShadeColor");
				WithMaterialPropertyDropdownNoLabel(props["_CrosstoneToneSeparation"], Enum.GetNames(typeof(ToneSeparationType)), editor);
			});
			ShaderProperty("_1st_ShadeColor_Step");
			ShaderProperty("_1st_ShadeColor_Feather");
            EditorGUILayout.Space();
			
			WithGroupHorizontal(() => {
				TextureColorPropertyWithColorReset("_2nd_ShadeMap", "_2nd_ShadeColor");
				WithMaterialPropertyDropdownNoLabel(props["_Crosstone2ndSeparation"], Enum.GetNames(typeof(ToneSeparationType)), editor);
			});
			ShaderProperty("_2nd_ShadeColor_Step");
			ShaderProperty("_2nd_ShadeColor_Feather");
            EditorGUILayout.Space();

			TexturePropertySingleLine("_ShadingGradeMap", "_Tweak_ShadingGradeMapLevel");
		}

		protected void SpecularOptions()
		{	
            EditorGUILayout.Space();
			MaterialProperty specProp;
			if (props.TryGetValue("_SpecularType", out specProp))
			{
				foreach (Material mat in WithMaterialPropertyDropdown(specProp, Enum.GetNames(typeof(SpecularType)), editor))
				{
					SetupMaterialWithSpecularType(mat, (SpecularType)specProp.floatValue);
				}
				TogglePropertyHeader("_SpecularType", false);

				switch ((SpecularType)specProp.floatValue)
				{
					case SpecularType.Standard:
					case SpecularType.Cloth:
					TextureColorPropertyWithColorReset("_SpecGlossMap", "_SpecColor");
					ShaderProperty("_Smoothness");
					ShaderProperty("_UseMetallic");
					ShaderProperty("_UseEnergyConservation");
					break;
					case SpecularType.Cel:
					TextureColorPropertyWithColorReset("_SpecGlossMap", "_SpecColor");
					ShaderProperty("_Smoothness");
					ShaderProperty("_CelSpecularSoftness");
					ShaderProperty("_CelSpecularSteps");
					ShaderProperty("_UseMetallic");
					ShaderProperty("_UseEnergyConservation");
					break;
					case SpecularType.Anisotropic:
					TextureColorPropertyWithColorReset("_SpecGlossMap", "_SpecColor");
					ShaderProperty("_Smoothness");
					ShaderProperty("_Anisotropy");
					ShaderProperty("_UseMetallic");
					ShaderProperty("_UseEnergyConservation");
					break;
					case SpecularType.CelStrand:
					TextureColorPropertyWithColorReset("_SpecGlossMap", "_SpecColor");
					ShaderProperty("_Smoothness");
					ShaderProperty("_CelSpecularSoftness");
					ShaderProperty("_CelSpecularSteps");
					ShaderProperty("_Anisotropy");
					ShaderProperty("_UseMetallic");
					ShaderProperty("_UseEnergyConservation");
					break;
					case SpecularType.Disable:
					default:
					break;
				}	
			}
		}

		protected void RimlightOptions()
		{	
            EditorGUILayout.Space();
			MaterialProperty rimProp;
			if (props.TryGetValue("_UseFresnel", out rimProp))
			{
				TogglePropertyHeader("_UseFresnel");
				bool isTintable = 
					(AmbientFresnelType)rimProp.floatValue == AmbientFresnelType.Lit
					|| (AmbientFresnelType)rimProp.floatValue == AmbientFresnelType.Ambient;

				if (PropertyEnabled(rimProp))
				{
					ShaderProperty("_FresnelWidth");
					ShaderProperty("_FresnelStrength");
					if (isTintable) ShaderProperty("_FresnelTint");	

					ShaderProperty("_UseFresnelLightMask");
					if (PropertyEnabled(props["_UseFresnelLightMask"]))
					{
						ShaderProperty("_FresnelLightMask");
						if (isTintable) ShaderProperty("_FresnelTintInv");
						ShaderProperty("_FresnelWidthInv");
						ShaderProperty("_FresnelStrengthInv");
					}
				}
			}
		}

		private void DrawMatcapField(string texture, string blend, string tint, string strength)
		{
			WithGroupHorizontal(() => {
				TextureColorPropertyWithColorReset(texture, tint);
				WithMaterialPropertyDropdownNoLabel(props[blend], Enum.GetNames(typeof(MatcapBlendModes)), editor);
			});
			EditorGUI.indentLevel+=2;
			ShaderProperty(strength);
			EditorGUI.indentLevel-=2;
		}

		protected void MatcapOptions()
		{ 
			EditorGUILayout.Space();
			MaterialProperty matcapProp;
			if (props.TryGetValue("_UseMatcap", out matcapProp))
			{
				var mMode = (MatcapType)matcapProp.floatValue;
				if (WithChangeCheck(() => 
				{
					mMode = (MatcapType)EditorGUILayout.Popup(Content("_UseMatcap"), 
					(int)mMode, Enum.GetNames(typeof(MatcapType)));
				})) {
					editor.RegisterPropertyChangeUndo(Content("_UseMatcap").text);
					matcapProp.floatValue = (float)mMode;
				}
				TogglePropertyHeader("_UseMatcap", false);

				if (PropertyEnabled(matcapProp))
				{
					TexturePropertySingleLine("_MatcapMask");
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
			if (TogglePropertyHeader("_UseSubsurfaceScattering"))
			{
				if (PropertyEnabled(props["_UseSubsurfaceScattering"]))
				{
					TexturePropertySingleLine("_ThicknessMap");
					ShaderProperty("_ThicknessMapPower");
					ShaderProperty("_ThicknessMapInvert");
					ShaderProperty("_SSSCol");
					ShaderProperty("_SSSIntensity");
					ShaderProperty("_SSSPow");
					ShaderProperty("_SSSDist");
					ShaderProperty("_SSSAmbient");
				}
			}
		}

		protected void DetailMapOptions()
		{	  
            EditorGUILayout.Space();
			if (TogglePropertyHeader("_UseDetailMaps")){
				if (PropertyEnabled(props["_UseDetailMaps"])) 
				{
					target.EnableKeyword("_DETAIL_MULX2");
					TexturePropertySingleLine("_DetailAlbedoMap", "_DetailAlbedoMapScale");
					TexturePropertySingleLine("_DetailNormalMap", "_DetailNormalMapScale");
					TexturePropertySingleLine("_SpecularDetailMask", "_SpecularDetailStrength");
					
					editor.TextureScaleOffsetProperty(props["_DetailAlbedoMap"]);
					ShaderProperty("_UVSec");
				} else {
					target.DisableKeyword("_DETAIL_MULX2");
				}
			}
		}

		protected void AnimationOptions()
		{
            EditorGUILayout.Space();
			if (TogglePropertyHeader("_UseAnimation") && PropertyEnabled(props["_UseAnimation"]))
			{
				ShaderProperty("_AnimationSpeed");
				ShaderProperty("_TotalFrames");
				ShaderProperty("_FrameNumber");
				ShaderProperty("_Columns");
				ShaderProperty("_Rows");
			}

		}

		protected void VanishingOptions()
		{ 
            EditorGUILayout.Space();
			if (TogglePropertyHeader("_UseVanishing") && PropertyEnabled(props["_UseVanishing"]))
			{
				ShaderProperty("_VanishingStart");
				ShaderProperty("_VanishingEnd");
			}
		}

		protected void OutlineOptions()
		{ 
			EditorGUILayout.Space();
			
			MaterialProperty outlineProp;
			if (props.TryGetValue("_OutlineMode", out outlineProp))
			{
				foreach (Material mat in WithMaterialPropertyDropdown(outlineProp, Enum.GetNames(typeof(OutlineMode)), editor))
				{
					SetupMaterialWithOutlineMode(mat, (OutlineMode)outlineProp.floatValue);
				}
				TogglePropertyHeader("_OutlineMode", false);

				switch ((OutlineMode)outlineProp.floatValue)
				{
					case OutlineMode.Tinted:
					case OutlineMode.Colored:
					TexturePropertySingleLine("_OutlineMask");
					ShaderProperty("_outline_color");
					ShaderProperty("_outline_width");
					break;
					case OutlineMode.None:
					default:
					break;
				}	  
			}
		}

		protected void ManualButtonArea()
		{
			EditorGUILayout.Space();
			
			DrawSectionHeaderArea(Content("Resources"));

            Rect r = EditorGUILayout.GetControlRect(true,0,EditorStyles.layerMaskField);
				r.x -= 2.0f;
				r.y += 2.0f;
				r.height = 18.0f;
			Rect r2 = r;
				r2.width = r.width / 2.0f;
			//GUI.Box(r, EditorGUIUtility.IconContent("Toolbar"), EditorStyles.toolbar);
			if (GUI.Button(r2, Content("s_manualButton"), EditorStyles.miniButtonLeft)) Application.OpenURL("https://gitlab.com/s-ilent/SCSS/wikis/Manual/Setting-Overview");
				r2.x += r2.width;
			if (GUI.Button(r2, Content("s_socialButton"), EditorStyles.miniButtonRight)) Application.OpenURL("https://discord.gg/uHJx4g629K");
			EditorGUILayout.LabelField("", EditorStyles.label);
		}

		protected void AdvancedOptions()
		{
			EditorGUILayout.Space();

			DrawSectionHeaderArea(Content("s_advancedOptions"));

			EditorGUILayout.Space();

			foreach (Material mat in WithMaterialPropertyDropdown(props["_VertexColorType"], Enum.GetNames(typeof(VertexColorType)), editor))
			{
				SetupMaterialWithVertexColorType(mat, (VertexColorType)props["_VertexColorType"].floatValue);
			}

			foreach (Material mat in WithMaterialPropertyDropdown(props["_AlbedoAlphaMode"], CommonStyles.albedoAlphaModeNames, editor))
			{
				SetupMaterialWithAlbedo(mat, props["_MainTex"], props["_AlbedoAlphaMode"]);
			}

			foreach (Material mat in WithMaterialPropertyDropdown(props["_LightingCalculationType"], Enum.GetNames(typeof(LightingCalculationType)), editor))
			{
				SetupMaterialWithLightingCalculationType(mat, (LightingCalculationType)props["_LightingCalculationType"].floatValue);
			}

			ShaderProperty("_IndirectShadingType");

			EditorGUILayout.Space();

			ShaderProperty("_DiffuseGeomShadowFactor");
			ShaderProperty("_LightWrappingCompensationFactor");

			ShaderProperty("_LightSkew");

			MaterialProperty specProp;
			if (props.TryGetValue("_SpecularType", out specProp) && specProp.floatValue >= 1.0f) 
			{
				if (WithChangeCheck(() => 
				{
					ShaderProperty("_SpecularHighlights");
					ShaderProperty("_GlossyReflections");
				})) {
					MaterialChanged(target);
				}
			};

			StencilOptions(editor, target);
		}

		protected void FooterOptions()
		{
			EditorGUILayout.Space();

			if (WithChangeCheck(() => 
			{
				editor.ShaderProperty(renderQueueOverride, BaseStyles.renderQueueOverride);
			})) {
				MaterialChanged(target);
			}

			// Show the RenderQueueField but do not allow users to directly manipulate it. That is done via the renderQueueOverride.
			GUI.enabled = false;
			editor.RenderQueueField();

			if (!GUI.enabled && !target.enableInstancing)
			{
				target.enableInstancing = true;
			}

			editor.EnableInstancingField();
		}

		protected static void SetupMaterialWithTransparencyMode(Material material, TransparencyMode shadowMaskType)
		{
			switch ((TransparencyMode)material.GetFloat("_AlphaSharp"))
			{
				case TransparencyMode.Sharp:
				material.SetFloat("_AlphaSharp", 1);
				break;
				default:
				case TransparencyMode.Soft:
				material.SetFloat("_AlphaSharp", 0);
				break;
			}
		}

		protected static void SetupMaterialWithShadowMaskType(Material material, ShadowMaskType shadowMaskType)
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

		protected static void SetupMaterialWithLightRampType(Material material, LightRampType lightRampType)
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
			(props["_Matcap1"].textureValue == null && props["_Matcap2"].textureValue == null &&
				props["_Matcap3"].textureValue == null && props["_Matcap4"].textureValue == null) &&
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
		 		props["_Matcap2"].textureValue = additiveMatcap;
		 		props["_Matcap2Blend"].floatValue = (float)MatcapBlendModes.Additive;
		 		props["_Matcap2Strength"].floatValue = additiveStrength ?? 1;
		 	}
		 	if (multiplyMatcap) 
		 	{
		 		props["_Matcap4"].textureValue = multiplyMatcap;
		 		props["_Matcap4Blend"].floatValue = (float)MatcapBlendModes.Multiply;
		 		props["_Matcap4Strength"].floatValue = multiplyStrength ?? 0; 
			// Multiply at 1.0 is usually wrong. This also prevents oldMatcaps from being true.
		 	}
		 	if (medianMatcap) 
		 	{
		 		props["_Matcap3"].textureValue = medianMatcap;
		 		props["_Matcap3Blend"].floatValue = (float)MatcapBlendModes.Median;
		 		props["_Matcap3Strength"].floatValue = medianStrength ?? 1;
		 	}
		 }
		}
		// Taken from Standard. Only Standard keywords are set here!
		protected static void SetMaterialKeywords(Material material)
		{
				// Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
				// (MaterialProperty value might come from renderer material property block)
			SetKeyword(material, "_NORMALMAP", 
				GetTextureProperty(material, "_BumpMap") && GetTextureProperty(material, "_DetailNormalMap"));
				/*
				SetKeyword(material, "_SPECGLOSSMAP", GetTextureProperty(material, "_SpecGlossMap"));
				SetKeyword(material, "_PARALLAXMAP", GetTextureProperty(material, "_ParallaxMap"));
				SetKeyword(material, "_DETAIL_MULX2", GetTextureProperty(material, "_DetailAlbedoMap") 
					&& GetTextureProperty(material, "_DetailNormalMap")
					&& GetTextureProperty(material, "_DetailEmissionMap")
					&& GetTextureProperty(material, "_SpecularDetailMask"));
				*/
/*
				// A material's GI flag internally keeps track of whether emission is enabled at all, it's enabled but has no effect
				// or is enabled and may be modified at runtime. This state depends on the values of the current flag and emissive color.
				// The fixup routine makes sure that the material is in the correct state if/when changes are made to the mode or color.
					MaterialEditor.FixupEmissiveFlag(material);
					bool shouldEmissionBeEnabled = (material.globalIlluminationFlags & MaterialGlobalIlluminationFlags.EmissiveIsBlack) == 0;
					SetKeyword(material, "_EMISSION", shouldEmissionBeEnabled);
*/
		}

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            // Cache old shader properties with potentially different names than the new shader.
            Vector4? textureScaleOffset = null;
            float? cullMode = GetFloatProperty(material, "_Cull");

            Texture normalMapTexture = GetTextureProperty(material, "_BumpMap");
            float? normalMapScale = GetFloatProperty(material, "_BumpScale");

            Texture emissionTexture = GetTextureProperty(material, "_EmissionMap");
            Color? emissionColor = GetColorProperty(material, "_EmissionColor");

 			float? useToneSeparation = GetFloatProperty(material, "_CrosstoneToneSeparation");
 			float? use2ndSeparation = GetFloatProperty(material, "_Crosstone2ndSeparation");

            //shadeMap1 = GetFloatProperty(material, "_1st_ShadeMap");
            //Color? shadeMap1Color = GetFloatProperty(material, "_1st_ShadeColor");
            float? shadeMap1Step = GetFloatProperty(material, "_1st_ShadeColor_Step");
            float? shadeMap1Feather = GetFloatProperty(material, "_1st_ShadeColor_Feather");
            //shadeMap2 = GetFloatProperty(material, "_2nd_ShadeMap");
            //Color? shadeMap2Color = GetFloatProperty(material, "_2nd_ShadeColor");
            float? shadeMap2Step = GetFloatProperty(material, "_2nd_ShadeColor_Step");
            float? shadeMap2Feather = GetFloatProperty(material, "_2nd_ShadeColor_Feather");

            float? useMatcap = GetFloatProperty(material, "_UseMatcap");
            Texture matcapMask = GetTextureProperty(material, "_MatcapMask");
            Texture matcapTexture = GetTextureProperty(material, "_Matcap1");
            float? matcapBlend = GetFloatProperty(material, "_Matcap1Blend");
            float? matcapStrength = GetFloatProperty(material, "_Matcap1Strength");
            Color? matcapTint = GetColorProperty(material, "_Matcap1Tint");

            float? specularType = GetFloatProperty(material, "_SpecularType");
            Texture specularMap = GetTextureProperty(material, "_SpecGlossMap");
            Texture specularDetailMask = GetTextureProperty(material, "_SpecularDetailMask");
            Color? specularTint = GetColorProperty(material, "_SpecColor");
            float? smoothness = GetFloatProperty(material, "_Smoothness");
            float? celSpecularSoftness = GetFloatProperty(material, "_CelSpecularSoftness");

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
            Texture outlineMask = GetTextureProperty(material, "_OutlineMask");

            int? stencilReference = GetIntProperty(material, "_Stencil");
            int? stencilComparison = GetIntProperty(material, "_StencilComp");
            int? stencilOperation = GetIntProperty(material, "_StencilOp");
            int? stencilFail = GetIntProperty(material, "_StencilFail");

            if (oldShader)
            {
            	if (oldShader.name.Contains("UnityChanToonShader"))
                {
                    normalMapTexture = GetTextureProperty(material, "_NormalMap");
                    // _Tweak_ShadingGradeMapLevel is named the same.

					if (GetFloatProperty(material, "_Inverse_Clipping") == 1) Debug.Log("Note: Inverse clipping currently not supported.");
					if (GetTextureProperty(material, "_ClippingMask")) SetFloatProperty(material, "_AlbedoAlphaMode", (float)AlbedoAlphaMode.ClippingMask);

                    // Tone seperation is based on whether BaseAs1st is set.
                    // 2nd seperation is based on whether 1stAs2nd is set.
                    useToneSeparation = GetFloatProperty(material, "_Use_BaseAs1st");
                    if (useToneSeparation.HasValue) useToneSeparation = 1.0f - useToneSeparation;
                    use2ndSeparation = GetFloatProperty(material, "_Use_1stAs2nd");
                    if (use2ndSeparation.HasValue) use2ndSeparation = 1.0f - use2ndSeparation;

					// Emission properties are not fully supported.
					emissionTexture = GetTextureProperty(material, "_Emissive_Tex");
					emissionColor = GetColorProperty(material, "_Emissive_Color");

                    // HighColor is only supported in Specular mode
                    specularMap = GetTextureProperty(material, "_HighColor_Tex");
					if (specularMap) { specularDetailMask = GetTextureProperty(material, "_Set_HighColorMask"); }
					else { specularMap = GetTextureProperty(material, "_Set_HighColorMask"); };
                    specularType = GetFloatProperty(material, "_Is_SpecularToHighColor");
					//if (specularDetailMask.HasValue) 
                    if (specularType.HasValue) specularType = (float)SpecularType.Cel * specularType;
                    specularTint = GetColorProperty(material, "_HighColor");
					{
						Color specularTint_var = (specularTint.HasValue)? (specularTint.Value) : (Color.white);
						specularTint_var.a *= 0.1f;
						specularTint = specularTint_var;
					}

                    smoothness = GetFloatProperty(material, "_HighColor_Power");
                    if (smoothness.HasValue) smoothness = 1.0f - smoothness;
					celSpecularSoftness = GetFloatProperty(material, "_Is_SpecularToHighColor");

                    // Rim lighting works differently here, but there's not much we can do about it. 
                    useFresnel = GetFloatProperty(material, "_RimLight");
                    if (useFresnel.HasValue) if (useFresnel > 0.0f) useFresnel = (float)AmbientFresnelType.Lit;
                    fresnelTint = GetColorProperty(material, "_RimLightColor");
                    fresnelWidth = GetFloatProperty(material, "_RimLight_Power");
                    if (fresnelWidth.HasValue) fresnelWidth = fresnelWidth * 10;
                    fresnelStrength = GetFloatProperty(material, "_RimLight_FeatherOff");
                    if (fresnelStrength.HasValue) fresnelStrength = 1.0f - fresnelStrength;

                    //GetFloatProperty(material, "_RimLight_FeatherOff");
                    useFresnelLightMask = GetFloatProperty(material, "_LightDirection_MaskOn");
                    fresnelLightMask = GetFloatProperty(material, "_Tweak_LightDirection_MaskLevel");
                    if (fresnelLightMask.HasValue) fresnelLightMask += 1.0f;
                    //GetFloatProperty(material, "_Add_Antipodean_RimLight");
                    fresnelTintInv = GetColorProperty(material, "_Ap_RimLightColor");
                    fresnelWidthInv = GetFloatProperty(material, "_Ap_RimLight_Power");
                    if (fresnelWidthInv.HasValue) fresnelWidthInv = fresnelWidthInv * 10;
                    fresnelStrengthInv = GetFloatProperty(material, "_Ap_RimLight_FeatherOff");
                    if (fresnelStrengthInv.HasValue) fresnelStrengthInv = 1.0f - fresnelStrengthInv;
                    //GetTextureProperty(material, "_Set_RimLightMask");

                    // Matcap properties are not fully supported
                    useMatcap = GetFloatProperty(material, "_MatCap");
                    matcapTexture = GetTextureProperty(material, "_MatCap_Sampler");
                    matcapMask = GetTextureProperty(material, "_Set_MatcapMask");
                    // _MatCapColor is not yet supported.
                    // _Is_LightColor_MatCap is not supported.
                    matcapBlend = GetFloatProperty(material, "_Is_BlendAddToMatCap");
                    if (matcapBlend.HasValue) matcapBlend = 1.0f - matcapBlend;
					// This seems to be used as a strength setting.
					matcapStrength = 1.0f - GetFloatProperty(material, "_Tweak_MatcapMaskLevel");
            		matcapTint = GetColorProperty(material, "_MatCapColor");
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
                    outlineMode = 1.0f;
                    if (oldShader.name.Contains("NoOutline"))
                    {
                    	outlineMode = 0.0f;
                	}
                    outlineColor = GetColorProperty(material, "_Outline_Color");
            		outlineWidth = GetFloatProperty(material, "_Outline_Width") * 0.1f;
            		outlineMask = GetTextureProperty(material, "_Outline_Sampler");

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
            if (emissionTexture)
            {
                material.SetTexture("_EmissionMap", emissionTexture);
            }

            SetFloatProperty(material, "_BumpScale", normalMapScale);
            SetColorProperty(material, "_EmissionColor", emissionColor);
            SetFloatProperty(material, "_CrosstoneToneSeparation", useToneSeparation);
            SetFloatProperty(material, "_Crosstone2ndSeparation", use2ndSeparation);
            SetFloatProperty(material, "_1st_ShadeColor_Step", shadeMap1Step);
            SetFloatProperty(material, "_1st_ShadeColor_Feather", shadeMap1Feather);
            SetFloatProperty(material, "_2nd_ShadeColor_Step", shadeMap2Step);
            SetFloatProperty(material, "_2nd_ShadeColor_Feather", shadeMap2Feather);
            SetFloatProperty(material, "_UseMatcap", useMatcap);
            SetFloatProperty(material, "_Matcap1Blend", matcapBlend);
            SetColorProperty(material, "_Matcap1Tint", matcapTint);
            SetFloatProperty(material, "_SpecularType", specularType);
            SetColorProperty(material, "_SpecColor", specularTint);
            SetFloatProperty(material, "_Smoothness", smoothness);
            SetFloatProperty(material, "_CelSpecularSoftness", celSpecularSoftness);
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
			if (specularType.HasValue) SetupMaterialWithSpecularType(material, (SpecularType)specularType);

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
	                    mode = RenderingMode.Cutout;
	                }
	            	if (oldShader.name.Contains("Transparent"))
	                {
	                    mode = RenderingMode.Fade;
	                }
	            }

                material.SetFloat(BaseStyles.renderingModeName, (float)mode);

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

        protected static void SetupMaterialWithVertexColorType(Material material, VertexColorType vertexColorType)
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
        		case VertexColorType.Ignore:
        		material.SetFloat("_VertexColorType", 3);
        		break;
        		default:
        		break;
        	}
        }
        
        protected static void SetupMaterialWithLightingCalculationType(Material material, LightingCalculationType LightingCalculationType)
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
        		case LightingCalculationType.Biased:
        		material.SetFloat("_LightingCalculationType", 4);
        		break;
        		default:
        		case LightingCalculationType.Unbiased:
        		material.SetFloat("_LightingCalculationType", 0);
        		break;
        	}
        }

	    protected static void UpgradeVariantCheck(Material material)
	    {
	        const string oldNoOutlineName = "☓ No Outline";
	        string newShaderName = "Silent's Cel Shading/Lightramp";
	        const string upgradeNotice = 
	        "Note: Updated the shader for material {0} to the new format.";
	        string[] currentShaderName = material.shader.name.Split('/');
	        // If they're the No Outline variant, it'll be in the path
	        var currentlyNoOutline = currentShaderName[currentShaderName.Length - 2].Equals(oldNoOutlineName);
	        newShaderName = currentlyNoOutline
	        ? newShaderName
	        : newShaderName + " (Outline)";
	        // Old shaders start with "Hidden/Silent's Cel Shading Shader/Old/"
	        if (currentShaderName[0] == "Hidden" && currentShaderName[2] == "Old")
	        {
	            // SetupMaterialWithRenderingMode
	            Shader finalShader = Shader.Find(newShaderName);
	            // If we can't find it, pass.
	            if (finalShader != null) {
	                material.shader = finalShader;
	                Debug.Log(String.Format(upgradeNotice, material.name, material.shader.name, newShaderName));
	            }
	        }
	    }

	}
}