using UnityEditor;
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;

// Parts of this file are based on https://github.com/Microsoft/MixedRealityToolkit-Unity/
// licensed under the MIT license. 

namespace SilentCelShading.Unity
{
	public class InspectorCommon
	{
		public enum OutlineMode
		{
			None,
			Tinted,
			Colored
		}

		public enum AlbedoAlphaMode
		{
			Transparency,
			Smoothness,
			ClippingMask
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

		public enum MatcapType
		{
			Disable,
			Standard,
			Anisotropic
		}

		public enum VertexColorType
		{
			Color = 0,
			OutlineColor = 1,
			AdditionalData = 2
		}

		public static class CommonStyles
		{
			public static string mainOptionsTitle = "Main Options";
			public static string renderingOptionsTitle = "Rendering Options";
			public static string shadingOptionsTitle = "Shading Options";
			public static string outlineOptionsTitle = "Outline Options";
			public static string advancedOptionsTitle = "Advanced Options";
			public static GUIContent matcapTitle = new GUIContent("Matcap", "Enables the use of material capture textures.");

			public static string albedoMapAlphaSmoothnessName = "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A";
			public static readonly string[] albedoAlphaModeNames = Enum.GetNames(typeof(AlbedoAlphaMode));

			public static GUIContent manualButton = new GUIContent("This shader has a manual. Check it out!","For information on new features, old features, and just how to use the shader in general, check out the manual on the shader wiki!");
		}

		static private TextAsset inspectorData;
		public static Dictionary<string, GUIContent> styles = new Dictionary<string, GUIContent>();

		public static void LoadInspectorData()
		{
			char[] recordSep = new char[] {'\n'};
			char[] fieldSep = new char[] {'\t'};
			if (styles.Count == 0)
			{
					string[] guids = AssetDatabase.FindAssets("t:TextAsset SCSS_InspectorData." + Application.systemLanguage);
					if (guids.Length == 0)
					{
						guids = AssetDatabase.FindAssets("t:TextAsset SCSS_InspectorData.English");
					}
					inspectorData = (TextAsset)AssetDatabase.LoadAssetAtPath(AssetDatabase.GUIDToAssetPath(guids[0]), typeof(TextAsset));

				string[] records = inspectorData.text.Split(recordSep, System.StringSplitOptions.RemoveEmptyEntries);
				foreach (string record in records)
				{
					string[] fields = record.Split(fieldSep, 3, System.StringSplitOptions.None); 
					if (fields.Length != 3) {Debug.Log("Field " + fields[0] + " only has " + fields.Length + " fields!");};
					if (fields[0] != null) styles[fields[0]] = new GUIContent(fields[1], fields[2]);  
					
				}	
			}		
		}

        public static void WithGroupVertical(Action action)
        {
            EditorGUILayout.BeginVertical();
            action();
            EditorGUILayout.EndVertical();
        }

        public static void WithGroupHorizontal(Action action)
        {
            EditorGUILayout.BeginHorizontal();
            action();
            EditorGUILayout.EndHorizontal();
        }

		public static bool WithChangeCheck(Action action)
		{
			EditorGUI.BeginChangeCheck();
			action();
			return EditorGUI.EndChangeCheck();
		}

		public static Material[] WithMaterialPropertyDropdown(MaterialProperty prop, string[] options, MaterialEditor editor)
		{
			int selection = (int)prop.floatValue;
			EditorGUI.BeginChangeCheck();
			selection = EditorGUILayout.Popup(prop.displayName, (int)selection, options);

			if (EditorGUI.EndChangeCheck())
			{
				editor.RegisterPropertyChangeUndo(prop.displayName);
				prop.floatValue = (float)selection;
				return Array.ConvertAll(prop.targets, target => (Material)target);
			}

			return new Material[0];

		}
    }
}