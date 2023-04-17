using UnityEditor;
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;
using System.Linq;

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
			Transparency = 0,
			Smoothness = 1,
			ClippingMask = 2
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
			Unbiased = 0,
			Standard = 1,
			Cubed = 2,
			Directional = 3, 
			Biased = 4
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
			AdditionalData = 2,
			Ignore = 3
		}

		public static class CommonStyles
		{
			public static string albedoMapAlphaSmoothnessName = "_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A";
			public static readonly string[] albedoAlphaModeNames = Enum.GetNames(typeof(AlbedoAlphaMode));
		}

		public class SCSSBoot : AssetPostprocessor {
			private static void OnPostprocessAllAssets(string[] importedAssets, string[] deletedAssets, string[] movedAssets,
			string[] movedFromAssetPaths) {
			var isUpdated = importedAssets.Any(path => path.StartsWith("Assets/")) &&
							importedAssets.Any(path => path.Contains("SCSS_InspectorData"));

			if (isUpdated) {
				InitializeOnLoad();
			}
			}

			[InitializeOnLoadMethod]
			private static void InitializeOnLoad() {
			InspectorCommon.LoadInspectorData();
			}
		}

		static public SystemLanguage inspectorLanguage;
		static private TextAsset inspectorData;
		public static Dictionary<string, GUIContent> styles = new Dictionary<string, GUIContent>();

		private static void UpdateInspectorLanguageSetting()
		{
			string inspectorLanguageSetting = EditorUserSettings.GetConfigValue("scss_editor_language");
			// Initial setup of editor language
			if (inspectorLanguageSetting == null)
			{
				inspectorLanguage = Application.systemLanguage;
			} 
			// Load editor language
			else
			{
				inspectorLanguage = (SystemLanguage) Enum.Parse(typeof(SystemLanguage), inspectorLanguageSetting);
			}
		}

		public static void LoadInspectorData()
		{
			UpdateInspectorLanguageSetting();

			char[] recordSep = new char[] {'\n'};
			char[] fieldSep = new char[] {'\t'};
			//if (styles.Count == 0)
			{
					string[] guids = AssetDatabase.FindAssets("t:TextAsset SCSS_InspectorData." + inspectorLanguage);
					if (guids.Length == 0)
					{
						Debug.LogWarning("SCSS: Failed to load localisation file.");
						guids = AssetDatabase.FindAssets("t:TextAsset SCSS_InspectorData.English");
					}
					inspectorData = (TextAsset)AssetDatabase.LoadAssetAtPath(AssetDatabase.GUIDToAssetPath(guids[0]), typeof(TextAsset));

				string[] records = inspectorData.text.Split(recordSep, System.StringSplitOptions.RemoveEmptyEntries);
				foreach (string record in records)
				{
					string[] fields = record.Split(fieldSep, 3, System.StringSplitOptions.None); 
					if (fields.Length != 3) {Debug.LogWarning("Field " + fields[0] + " only has " + fields.Length + " fields!");};
					if (fields[0] != null) styles[fields[0]] = new GUIContent(fields[1], fields[2]);  
					
				}	
			}		
		}
        internal static bool ButtonWithDropdownList(GUIContent content, string[] buttonNames, GenericMenu.MenuFunction2 callback) {
            var style = new GUIStyle("DropDownButton");
            var rect = GUILayoutUtility.GetRect(content, style);

            var dropDownRect = rect;
            const float kDropDownButtonWidth = 20f;
            dropDownRect.xMin = dropDownRect.xMax - kDropDownButtonWidth;

            if (Event.current.type == EventType.MouseDown && dropDownRect.Contains(Event.current.mousePosition)) {
                var menu = new GenericMenu();
                for (int i = 0; i != buttonNames.Length; i++)
                    menu.AddItem(new GUIContent(buttonNames[i]), false, callback, i);

                menu.DropDown(rect);
                Event.current.Use();

                return false;
            }

            return GUI.Button(rect, content, style);
        }

		// Selectable languages 
		public enum InspectorLanguageSelection
		{
			English, 日本語
		}

		public static SystemLanguage GetInspectorLanguage()
		{
			return inspectorLanguage;
		}

		public static void UpdateInspectorLanguage(InspectorLanguageSelection selectedLanguage)
		{
			switch(selectedLanguage)
			{
				case InspectorLanguageSelection.English:
					inspectorLanguage = SystemLanguage.English;
					break;
				case InspectorLanguageSelection.日本語:
					inspectorLanguage = SystemLanguage.Japanese;
					break;
			}
			// Update configuration
			EditorUserSettings.SetConfigValue("scss_editor_language", inspectorLanguage.ToString());
			// Reload localisation file
			LoadInspectorData();

		}
		

		public static void DrawInspectorLanguageDropdown()
		{
			InspectorLanguageSelection selectedLanguage = InspectorLanguageSelection.English;

			switch(inspectorLanguage)
			{
				case SystemLanguage.English:
					selectedLanguage = InspectorLanguageSelection.English; 
					break; 
				case SystemLanguage.Japanese:
					selectedLanguage = InspectorLanguageSelection.日本語;
					break;
			}

			
			if (WithChangeCheck(() => 
			{
            	selectedLanguage = (InspectorLanguageSelection)EditorGUILayout.EnumPopup("Language", selectedLanguage);
			}))
			{
				UpdateInspectorLanguage(selectedLanguage);
			}
		}

        public static void WithGroupVertical(Action action)
        {
            EditorGUILayout.BeginVertical();
            action();
            EditorGUILayout.EndVertical();
        }

		// Warning: Do not use BeginHorizontal with ShaderProperty because it causes issues with the layout.
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

		public static void WithGUIDisable(bool disable, Action action)
		{
			bool prevState = GUI.enabled;
			GUI.enabled = disable;
			action();
			GUI.enabled = prevState;
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
		public static Material[] WithMaterialPropertyDropdown(MaterialProperty prop, GUIContent label, string[] options, MaterialEditor editor)
		{
			int selection = (int)prop.floatValue;
			EditorGUI.BeginChangeCheck();
			selection = EditorGUILayout.Popup(label, (int)selection, options);

			if (EditorGUI.EndChangeCheck())
			{
				editor.RegisterPropertyChangeUndo(prop.displayName);
				prop.floatValue = (float)selection;
				return Array.ConvertAll(prop.targets, target => (Material)target);
			}

			return new Material[0];

		}
		
		public static Material[] WithMaterialPropertyDropdownNoLabel(MaterialProperty prop, string[] options, MaterialEditor editor)
		{
			int selection = (int)prop.floatValue;
			EditorGUI.BeginChangeCheck();
			selection = EditorGUILayout.Popup((int)selection, options);

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