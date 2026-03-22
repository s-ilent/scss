using UnityEditor;
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;
using Object = UnityEngine.Object;
using static SilentCelShading.Unity.InspectorCommon;

namespace SilentCelShading.Unity
{
public class MaterialPropertyHandler
{
    private Dictionary<string, MaterialProperty> props = new Dictionary<string, MaterialProperty>();
    private MaterialEditor editor;

    public void Refresh(MaterialProperty[] matProps, MaterialEditor materialEditor)
    {
        // When the shader is changed, some properties won't be in props...
        this.editor = materialEditor;
        foreach (MaterialProperty prop in matProps)
        {
            //props[prop.name] = editor.target.FindProperty(prop.name, matProps, false);
            props[prop.name] = prop;
        }
    }

    public MaterialPropertyHandler(MaterialProperty[] matProps, MaterialEditor materialEditor)
    {
        Refresh(matProps, materialEditor);
    }

    //-------------------------------------------------------------------------
    // Normal methods below...
    //-------------------------------------------------------------------------

	public MaterialProperty Property(string i)
	{
		MaterialProperty prop;
		if (props.TryGetValue(i, out prop))
		{
			return prop;
		}
		return null;
	}

	public GUIContent Content(string i)
	{
		GUIContent style;
		if (!styles.TryGetValue(i, out style))
		{
			style = new GUIContent(i);
            styles[i] = style;  // Add the new GUIContent to the dictionary
		}
		return style;
	}

	public bool ShaderProperty(string i)
	{
		MaterialProperty prop;
		GUIContent style;

		if (!styles.TryGetValue(i, out style))
		{
			style = new GUIContent(i);
            styles[i] = style;  // Add the new GUIContent to the dictionary
		}

		if (props.TryGetValue(i, out prop))
		{
			editor.ShaderProperty(prop, style);
			return true;
		}
        else
        {
			DisabledLabel(style);
		}

		return false;
	}

    public bool PropertyEnabled(string propertyName)
    {
        MaterialProperty prop = Property(propertyName);
        return prop != null && prop.floatValue == 1;
    }

	public Rect DisabledLabel(GUIContent style)
	{
		EditorGUI.BeginDisabledGroup(true);
		Rect rect = EditorGUILayout.GetControlRect();
		EditorGUI.LabelField(rect, style);
		EditorGUI.EndDisabledGroup();
		return rect;
	}

    public Rect GetControlRectForSingleLine()
    {
        const float extraSpacing = 2f; // The shader properties needs a little more vertical spacing due to the mini texture field (looks cramped without)
		const float singleLineHeight = 16f;
        return EditorGUILayout.GetControlRect(true, singleLineHeight + extraSpacing, EditorStyles.layerMaskField);
    }

    public void TextureScaleOffsetProperty(string i)
    {
		MaterialProperty prop = Property(i);
		GUIContent style = Content(i);
        // Can't return Rect as Editor function does not support it.
		if (prop != null)
		{
            editor.TextureScaleOffsetProperty(prop);
        } else {
			DisabledLabel(style);
		}
    }

	public Rect TexturePropertySingleLine(string i)
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

	public Rect TexturePropertySingleLine(string i, string i2)
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

	public Rect TexturePropertySingleLine(string i, string i2, string i3)
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

	public Rect TextureColorPropertyWithColorReset(string tex, string col)
	{
		MaterialProperty texProp = Property(tex);
		MaterialProperty colProp = Property(col);

		if (texProp == null || colProp == null)
			return DisabledLabel(Content(tex));

		bool hadTexture = texProp.textureValue != null;
		Rect returnRect = TexturePropertySingleLine(tex, col);

		float brightness = colProp.colorValue.maxColorComponent;
		if (texProp.textureValue != null && !hadTexture && brightness <= 0f)
			colProp.colorValue = Color.white;
		return returnRect;
	}

	public Rect TextureColorPropertyWithColorReset(string tex, string col, string prop)
	{
		MaterialProperty texProp = Property(tex);
		MaterialProperty colProp = Property(col);
		MaterialProperty propProp = Property(prop);

		if (texProp == null || colProp == null || propProp == null)
			return DisabledLabel(Content(tex));

		bool hadTexture = texProp.textureValue != null;
		Rect returnRect = TexturePropertySingleLine(tex, col, prop);

		float brightness = colProp.colorValue.maxColorComponent;
		if (texProp.textureValue != null && !hadTexture && brightness <= 0f)
			colProp.colorValue = Color.white;
		return returnRect;
	}


	public Rect TexturePropertyWithHDRColor(string i, string i2)
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

	// Match to UnityCsReference
    public void ExtraPropertyAfterTexture(Rect r, MaterialProperty property, bool adjustLabelWidth = true)
    {
        #if UNITY_6000_0_OR_NEWER
            // Newer Unity versions use propertyType and ShaderPropertyType
            bool isFloatOrColor = (property.propertyType == ShaderPropertyType.Float || property.propertyType == ShaderPropertyType.Color);
        #else
            // Older Unity versions use type and MaterialProperty.PropType
            bool isFloatOrColor = (property.type == MaterialProperty.PropType.Float || property.type == MaterialProperty.PropType.Color);
        #endif

        if (adjustLabelWidth && isFloatOrColor && r.width > EditorGUIUtility.fieldWidth)
        {
            float oldLabelWidth = EditorGUIUtility.labelWidth;
            EditorGUIUtility.labelWidth = r.width - EditorGUIUtility.fieldWidth;
            editor.ShaderProperty(r, property, " ");
            EditorGUIUtility.labelWidth = oldLabelWidth;
            return;
        }

        editor.ShaderProperty(r, property, string.Empty);
    }


    static public Rect GetRectAfterLabelWidth(Rect r)
    {
        return new Rect(r.x + EditorGUIUtility.labelWidth, r.y, r.width - EditorGUIUtility.labelWidth, EditorGUIUtility.singleLineHeight);
    }

	public Material[] PropertyDropdown(string i, string[] options, MaterialEditor editor)
	{
		MaterialProperty prop;
		GUIContent style;

		if (!styles.TryGetValue(i, out style))
		{
			style = new GUIContent(i);
		}

		if (props.TryGetValue(i, out prop))
		{
			return WithMaterialPropertyDropdown(prop, style, options, editor);
		} else {
			DisabledLabel(style);
			return new Material[0];
		}

	}
	public Material[] PropertyDropdownNoLabel(string i, string[] options, MaterialEditor editor)
	{
		MaterialProperty prop;
		GUIContent style;

		if (!styles.TryGetValue(i, out style))
		{
			style = new GUIContent(i);
		}

		if (props.TryGetValue(i, out prop))
		{
			return WithMaterialPropertyDropdownNoLabel(prop, options, editor);
		} else {
			DisabledLabel(style);
			return new Material[0];
		}

	}


    public void DrawShaderPropertySameLine(string i) {
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

    protected static void Vector2Property(MaterialProperty property, GUIContent name, int index1, int index2)
    {
        EditorGUI.BeginChangeCheck();
        Vector2 vector2 = EditorGUILayout.Vector2Field(name, new Vector2(property.vectorValue[index1], property.vectorValue[index2]), null);
        if (EditorGUI.EndChangeCheck())
        {
            Vector4 vector4 = property.vectorValue;
            vector4[index1] = vector2.x;
            vector4[index2] = vector2.y;
            property.vectorValue = vector4;
        }
    }

    public void Vector2Property(string propertyName, string contentName, int index1, int index2)
    {
        MaterialProperty property = Property(propertyName);
        GUIContent name = Content(contentName);
        if (property != null && name != null)
        {
            Vector2Property(property, name, index1, index2);
        }
    }

    public GUIStyle sectionHeader;
    public GUIStyle sectionHeaderBox;

    public void InitialiseStyles()
	{
		sectionHeader = new GUIStyle(EditorStyles.miniBoldLabel);
        sectionHeader.padding.left = 24;
        sectionHeader.padding.right = -24;

		sectionHeaderBox = new GUIStyle(GUI.skin.box);
        sectionHeaderBox.alignment = TextAnchor.MiddleLeft;
        sectionHeaderBox.padding.left = 5;
        sectionHeaderBox.padding.right = -5;
        sectionHeaderBox.padding.top = 0;
        sectionHeaderBox.padding.bottom = 0;
	}

    public Rect DrawSectionHeaderArea(GUIContent content)
    {
        InitialiseStyles();
        Rect r = EditorGUILayout.GetControlRect(true, 0, EditorStyles.layerMaskField);
        r.x -= 2.0f;
        r.y += 2.0f;
        r.height = 18.0f;
        r.width -= 0.0f;
        GUI.Box(r, EditorGUIUtility.IconContent("d_FilterByType"), sectionHeaderBox);
        EditorGUILayout.LabelField(content, sectionHeader);
        return r;
    }

    public void BeginSection(string contentKey)
    {
        EditorGUILayout.Space();
        DrawSectionHeaderArea(Content(contentKey));
    }

    public float Float(string i)
    {
        MaterialProperty prop = Property(i);
        return prop != null ? prop.floatValue : 0f;
    }

    public void WithGroupHorizontal(Action action)
    {
        EditorGUILayout.BeginHorizontal();
        action();
        EditorGUILayout.EndHorizontal();
    }

    public void TexColorDropdownLine(string tex, string col, string dropdown, Type enumType)
    {
        WithGroupHorizontal(() => {
            TextureColorPropertyWithColorReset(tex, col);
            PropertyDropdownNoLabel(dropdown, Enum.GetNames(enumType), editor);
        });
    }

    public void EnumProperty(string i, Type enumType, Action<Material, float> onDraw = null)
    {
        MaterialProperty prop = Property(i);
        if (prop != null)
        {
            foreach (Material mat in PropertyDropdown(i, Enum.GetNames(enumType), editor))
            {
                onDraw?.Invoke(mat, prop.floatValue);
            }
        }
    }

    public void DrawIf(bool condition, params string[] propertyNames)
    {
        if (!condition) return;
        foreach (var name in propertyNames)
        {
            ShaderProperty(name);
        }
    }

    public void ShaderProperties(params string[] propertyNames)
    {
        foreach (var name in propertyNames)
        {
            ShaderProperty(name);
        }
    }
}
}
