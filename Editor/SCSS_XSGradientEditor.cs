using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
using UnityEditorInternal;
using static SilentCelShading.Unity.InspectorCommon;

namespace SilentCelShading.Unity
{
public class XSGradientEditor : EditorWindow
{
    private const int gradients_min = 1;
    public const int gradients_max = 16;

    [SerializeField]
    public List<int> gradients_index = new List<int>(new int[1] { 0 });

    [SerializeField]
    public List<Gradient> gradients = new List<Gradient>(gradients_max);

    public Texture2D tex;

    private string finalFilePath;

    [SerializeField]
    private bool isLinear = false;

    public enum RampWidth
    {
        _64 = 64,
        _128 = 128,
        _256 = 256,
        _512 = 512
    }

    public enum RampLayerHeight
    {
        _1 = 1,
        _2 = 2,
        _4 = 4,
        _8 = 8,
        _16 = 16
    }

    private static readonly string[] rampWidthLabels = new string[] { "64", "128", "256", "512" };
    private static readonly int[] rampWidthValues = new int[] { 64, 128, 256, 512 };

    private static readonly string[] rampHeightLabels = new string[] { "1", "2", "4", "8", "16" };
    private static readonly int[] rampHeightValues = new int[] { 1, 2, 4, 8, 16 };

    [SerializeField]
    private int resWidth = 256;

    [SerializeField]
    private int layerHeight = 8;

    public static Material focusedMat;
    private Material explicitMat;
    private Material oldActiveMat;
    private Texture oldTexture;
    private string rampProperty = "_Ramp";

    private ReorderableList gradList;
    private SerializedObject serializedObj;
    private SerializedProperty gradientsProp;
    private SerializedProperty gradientsIndexProp;

    private SCSSMultiGradient multiGrad;
    private bool dHelpText = true;

    // Resolves explicit material override or falls back to active selection
    private Material ResolvedMaterial
    {
        get
        {
            if (explicitMat != null) return explicitMat;
            if (Selection.activeObject is Material selMat) return selMat;
            return focusedMat;
        }
    }

    protected GUIContent GetInspectorGUIContent(string i)
    {
        if (!styles.TryGetValue(i, out GUIContent style))
        {
            style = new GUIContent(i);
        }
        return style;
    }

    protected string GetInspectorData(string i)
    {
        if (!styles.TryGetValue(i, out GUIContent style))
        {
            return i;
        }
        return style.text;
    }

    [MenuItem("Tools/Silent's Cel Shading/Gradient Editor")]
    public static void Init()
    {
        XSGradientEditor window = EditorWindow.GetWindow<XSGradientEditor>(false, "SCSS Gradient Editor", true);
        window.minSize = new Vector2(490, 500);
    }

    public static string findAssetPath(string finalFilePath)
    {
        string[] guids = AssetDatabase.FindAssets("SCSS_XSGradientEditor", null);
        if (guids.Length == 0) return "Assets";
        string untouchedString = AssetDatabase.GUIDToAssetPath(guids[0]);
        string[] splitString = untouchedString.Split('/');

        ArrayUtility.RemoveAt(ref splitString, splitString.Length - 1);
        ArrayUtility.RemoveAt(ref splitString, splitString.Length - 1);

        finalFilePath = string.Join("/", splitString);
        return finalFilePath;
    }

    private void OnEnable()
    {
        while (gradients.Count < gradients_max)
        {
            gradients.Add(new Gradient());
        }

        serializedObj = new SerializedObject(this);
        gradientsProp = serializedObj.FindProperty("gradients");
        gradientsIndexProp = serializedObj.FindProperty("gradients_index");

        InitReorderableList();
    }

    private void OnSelectionChange()
    {
        if (explicitMat == null)
        {
            Repaint();
        }
    }

    private void InitReorderableList()
    {
        gradList = new ReorderableList(serializedObj, gradientsIndexProp, true, true, true, true);

        // Calculate element height to accommodate boundary dividing lines
        gradList.elementHeightCallback = (int index) =>
        {
            int total = gradientsIndexProp.arraySize;
            float baseHeight = EditorGUIUtility.singleLineHeight + 14f;
            if (index == total - 1) baseHeight += 12f; // Space for closing 1.00 divider
            return baseHeight;
        };

        gradList.drawHeaderCallback = (Rect rect) =>
        {
            EditorGUI.LabelField(rect, $"Ramp Layers ({gradients_index.Count}) & Vertex Color Boundaries (0.00 → 1.00)", EditorStyles.boldLabel);
        };

        gradList.drawElementCallback = (Rect rect, int index, bool isActive, bool isFocused) =>
        {
            if (index >= gradients_index.Count || index >= gradientsIndexProp.arraySize) return;

            int total = gradientsIndexProp.arraySize;
            int gradIdx = gradients_index[index];

            // 1. Top Boundary Threshold Line: T_k = index / total
            float topThreshold = total > 0 ? (float)index / total : 0f;
            Rect topDividerRect = new Rect(rect.x, rect.y + 1f, rect.width, 10f);
            DrawThresholdDivider(topDividerRect, topThreshold);

            // 2. Gradient Row: Full-width gradient field between thresholds
            float rowY = rect.y + 12f;
            float rowHeight = EditorGUIUtility.singleLineHeight;
            Rect gradRect = new Rect(rect.x + 12f, rowY, rect.width - 16f, rowHeight);

            if (gradIdx >= 0 && gradIdx < gradientsProp.arraySize)
            {
                SerializedProperty gradElem = gradientsProp.GetArrayElementAtIndex(gradIdx);
                EditorGUI.PropertyField(gradRect, gradElem, GUIContent.none);
            }

            // 3. Bottom Closing Threshold Line: 1.00
            if (index == total - 1)
            {
                Rect bottomDividerRect = new Rect(rect.x, rowY + rowHeight + 2f, rect.width, 10f);
                DrawThresholdDivider(bottomDividerRect, 1.00f);
            }
        };

        gradList.onAddCallback = (ReorderableList list) =>
        {
            if (gradients_index.Count >= gradients_max) return;

            serializedObj.Update();
            int nextUnused = 0;
            for (int i = 0; i < gradients_max; i++)
            {
                if (!gradients_index.Contains(i))
                {
                    nextUnused = i;
                    break;
                }
            }

            int newIndex = gradientsIndexProp.arraySize;
            gradientsIndexProp.InsertArrayElementAtIndex(newIndex);
            gradientsIndexProp.GetArrayElementAtIndex(newIndex).intValue = nextUnused;
            serializedObj.ApplyModifiedProperties();

            BakeTextureAndApplyToMaterial();
        };

        gradList.onRemoveCallback = (ReorderableList list) =>
        {
            if (gradientsIndexProp.arraySize > gradients_min && list.index >= 0 && list.index < gradientsIndexProp.arraySize)
            {
                serializedObj.Update();
                gradientsIndexProp.DeleteArrayElementAtIndex(list.index);
                list.index = Mathf.Clamp(list.index - 1, 0, gradientsIndexProp.arraySize - 1);
                serializedObj.ApplyModifiedProperties();

                BakeTextureAndApplyToMaterial();
            }
        };

        gradList.onReorderCallback = (ReorderableList list) =>
        {
            serializedObj.ApplyModifiedProperties();
            BakeTextureAndApplyToMaterial();
        };
    }

    private void DrawThresholdDivider(Rect rect, float thresholdValue)
    {
        Color dividerColor = EditorGUIUtility.isProSkin ? new Color(0.4f, 0.4f, 0.4f, 0.8f) : new Color(0.6f, 0.6f, 0.6f, 0.8f);
        Color textColor = EditorGUIUtility.isProSkin ? new Color(0.7f, 0.85f, 1f, 0.95f) : new Color(0.15f, 0.35f, 0.7f, 1f);

        float lineY = rect.y + 5f;
        float labelWidth = 42f;

        // Left Line
        EditorGUI.DrawRect(new Rect(rect.x, lineY, 16f, 1f), dividerColor);

        // Threshold Label (e.g. 0.00, 0.50, 1.00)
        GUIStyle thresholdStyle = new GUIStyle(EditorStyles.miniLabel)
        {
            normal = { textColor = textColor },
            fontStyle = FontStyle.Bold,
            alignment = TextAnchor.MiddleCenter
        };

        EditorGUI.LabelField(new Rect(rect.x + 18f, rect.y - 2f, labelWidth, 14f), thresholdValue.ToString("F2"), thresholdStyle);

        // Right Line
        float rightLineX = rect.x + 18f + labelWidth + 2f;
        float rightLineWidth = Mathf.Max(10f, (rect.x + rect.width) - rightLineX);
        EditorGUI.DrawRect(new Rect(rightLineX, lineY, rightLineWidth, 1f), dividerColor);
    }

    public void OnGUI()
    {
        if (serializedObj == null || gradientsProp == null)
        {
            serializedObj = new SerializedObject(this);
            gradientsProp = serializedObj.FindProperty("gradients");
            gradientsIndexProp = serializedObj.FindProperty("gradients_index");
            InitReorderableList();
        }

        serializedObj.Update();

        bool guiChanged = false;
        EditorGUILayout.Space();

        DrawMaterialField(ref guiChanged);
        DrawResolutionControls(ref guiChanged);

        EditorGUILayout.Space();

        EditorGUI.BeginChangeCheck();
        gradList.DoLayoutList();
        if (EditorGUI.EndChangeCheck())
        {
            guiChanged = true;
        }

        if (serializedObj.ApplyModifiedProperties() || guiChanged)
        {
            BakeTextureAndApplyToMaterial();
        }

        HandleActiveMaterialChange();

        EditorGUILayout.Space();
        drawMGInputOutput();

        EditorGUILayout.Space();
        DrawSaveButton();

        EditorGUILayout.Space();
        DrawPostSaveOptions(ref guiChanged);

        drawHelpText();
    }

    private void DrawMaterialField(ref bool guiChanged)
    {
        using (new EditorGUILayout.VerticalScope(EditorStyles.helpBox))
        {
            var targetMat = ResolvedMaterial;
            bool isOverridden = explicitMat != null;

            using (new EditorGUILayout.HorizontalScope())
            {
                EditorGUI.BeginChangeCheck();
                GUIContent label = new GUIContent("Target Material", "Drag a Material to lock editing to it, or leave empty to auto-follow selection.");
                
                Material displayedMat = isOverridden ? explicitMat : targetMat;
                Material newMat = (Material)EditorGUILayout.ObjectField(label, displayedMat, typeof(Material), true);
                
                if (EditorGUI.EndChangeCheck())
                {
                    explicitMat = newMat;
                    guiChanged = true;
                }

                if (isOverridden)
                {
                    if (GUILayout.Button(new GUIContent("Reset", "Return to auto-following selection"), EditorStyles.miniButton, GUILayout.Width(45)))
                    {
                        explicitMat = null;
                        guiChanged = true;
                        GUI.FocusControl(null);
                    }
                }
                else
                {
                    GUILayout.Label("(Selection)", EditorStyles.miniLabel, GUILayout.Width(60));
                }
            }

            if (targetMat != null)
            {
                if (targetMat.HasProperty("_Ramp"))
                {
                    rampProperty = "_Ramp";
                }
                else
                {
                    EditorGUI.BeginChangeCheck();
                    rampProperty = EditorGUILayout.TextField(GetInspectorGUIContent("ge_rampPropertyField"), rampProperty);
                    if (EditorGUI.EndChangeCheck()) guiChanged = true;

                    if (!targetMat.HasProperty(rampProperty))
                    {
                        EditorGUILayout.HelpBox(GetInspectorData("ge_rampPropertyError"), MessageType.Warning);
                    }
                }
            }
        }
    }

    private void DrawResolutionControls(ref bool guiChanged)
    {
        using (new EditorGUILayout.HorizontalScope())
        {
            // Width
            EditorGUILayout.LabelField("Width", GUILayout.Width(42));
            EditorGUI.BeginChangeCheck();
            resWidth = EditorGUILayout.IntPopup(resWidth, rampWidthLabels, rampWidthValues, GUILayout.Width(60));
            if (EditorGUI.EndChangeCheck()) guiChanged = true;
            EditorGUILayout.LabelField("px", EditorStyles.miniLabel, GUILayout.Width(22));

            GUILayout.Space(12);

            // Layer Height
            EditorGUILayout.LabelField("Layer Height", GUILayout.Width(78));
            EditorGUI.BeginChangeCheck();
            layerHeight = EditorGUILayout.IntPopup(layerHeight, rampHeightLabels, rampHeightValues, GUILayout.Width(50));
            if (EditorGUI.EndChangeCheck()) guiChanged = true;
            EditorGUILayout.LabelField("px", EditorStyles.miniLabel, GUILayout.Width(22));

            GUILayout.FlexibleSpace();

            // Total Size Summary
            int totalHeight = gradients_index.Count * layerHeight;
            EditorGUILayout.LabelField($"Total: {resWidth}×{totalHeight}px", EditorStyles.miniBoldLabel, GUILayout.Width(110));
        }
    }

    private void DrawPostSaveOptions(ref bool guiChanged)
    {
        using (new EditorGUILayout.HorizontalScope())
        {
            EditorGUI.BeginChangeCheck();
            isLinear = GUILayout.Toggle(isLinear, GetInspectorGUIContent("ge_linearCheckbox"));
            dHelpText = GUILayout.Toggle(dHelpText, GetInspectorGUIContent("ge_helpCheckbox"));
            if (EditorGUI.EndChangeCheck())
            {
                guiChanged = true;
                BakeTextureAndApplyToMaterial();
            }
        }
    }

    private void HandleActiveMaterialChange()
    {
        var current = ResolvedMaterial;
        if (oldActiveMat != current)
        {
            if (oldTexture != null)
            {
                if (oldTexture == EditorGUIUtility.whiteTexture) oldTexture = null;
                if (oldActiveMat != null && oldActiveMat.HasProperty(rampProperty))
                {
                    oldActiveMat.SetTexture(rampProperty, oldTexture);
                }
                oldTexture = null;
            }
            oldActiveMat = current;
            BakeTextureAndApplyToMaterial();
        }
    }

    private void BakeTextureAndApplyToMaterial()
    {
        int width = resWidth;
        int rowHeight = layerHeight;
        int layerCount = Mathf.Max(1, gradients_index.Count);
        int totalHeight = layerCount * rowHeight;

        if (tex == null || tex.width != width || tex.height != totalHeight)
        {
            if (tex != null) DestroyImmediate(tex);
            tex = new Texture2D(width, totalHeight, TextureFormat.RGBA32, false);
            tex.wrapMode = TextureWrapMode.Clamp;
        }

        for (int layer = 0; layer < layerCount; layer++)
        {
            int gradIdx = gradients_index[Mathf.Min(layer, gradients_index.Count - 1)];
            var grad = gradients[gradIdx];

            for (int r = 0; r < rowHeight; r++)
            {
                int y = layer * rowHeight + r;
                for (int x = 0; x < width; x++)
                {
                    Color grad_col = grad.Evaluate((float)x / (float)width);
                    tex.SetPixel(x, y, isLinear ? grad_col.gamma : grad_col);
                }
            }
        }
        tex.Apply(false, false);

        var current = ResolvedMaterial;
        if (current != null && current.HasProperty(rampProperty))
        {
            if (oldTexture == null)
            {
                oldTexture = current.GetTexture(rampProperty) ?? EditorGUIUtility.whiteTexture;
            }
            current.SetTexture(rampProperty, tex);
        }
    }

    private void DrawSaveButton()
    {
        if (GUILayout.Button(GetInspectorGUIContent("ge_saveRampButton"), GUILayout.Height(28f)))
        {
            finalFilePath = findAssetPath(finalFilePath);
            string path = EditorUtility.SaveFilePanel(GetInspectorData("ge_saveRampButton"), finalFilePath + "/Textures/Shadow Ramps/Generated", "gradient", "png");
            if (path.Length != 0)
            {
                BakeTextureAndApplyToMaterial();
                bool success = GenTexture(tex, path);
                var current = ResolvedMaterial;
                if (success && current != null)
                {
                    string s = path.Substring(path.IndexOf("Assets"));
                    Texture ramp = AssetDatabase.LoadAssetAtPath<Texture>(s);
                    if (ramp != null)
                    {
                        current.SetTexture(rampProperty, ramp);
                        oldTexture = null;
                    }
                }
            }
        }
    }

    private bool GenTexture(Texture2D targetTex, string path)
    {
        byte[] pngData = targetTex.EncodeToPNG();
        if (pngData != null)
        {
            File.WriteAllBytes(path, pngData);
            AssetDatabase.Refresh();
            return ChangeImportSettings(path);
        }
        return false;
    }

    private bool ChangeImportSettings(string path)
    {
        string s = path.Substring(path.LastIndexOf("Assets"));
        TextureImporter texture = (TextureImporter)TextureImporter.GetAtPath(s);
        if (texture != null)
        {
            texture.wrapMode = TextureWrapMode.Clamp;
            texture.maxTextureSize = 512;
            texture.mipmapEnabled = false;
            texture.textureCompression = TextureImporterCompression.Uncompressed;
            texture.SaveAndReimport();
            AssetDatabase.Refresh();
            return true;
        }
        else
        {
            Debug.Log(GetInspectorGUIContent("ge_noAssetPathError"));
        }
        return false;
    }

    private void drawMGInputOutput()
    {
        GUILayout.BeginHorizontal();
        SCSSMultiGradient old_multiGrad = multiGrad;
        multiGrad = (SCSSMultiGradient)EditorGUILayout.ObjectField(GetInspectorGUIContent("ge_multiGradientPreset"), multiGrad, typeof(SCSSMultiGradient), false);
        if (multiGrad != old_multiGrad)
        {
            serializedObj.Update();
            if (multiGrad != null)
            {
                gradients = multiGrad.gradients;
                gradients_index = multiGrad.order;
            }
            else
            {
                List<Gradient> new_Grads = new List<Gradient>();
                for (int i = 0; i < gradients.Count; i++)
                {
                    new_Grads.Add(reflessGradient(gradients[i]));
                }
                gradients = new_Grads;
                gradients_index = reflessIndexes(gradients_index);
            }
            serializedObj.ApplyModifiedProperties();
            InitReorderableList();
            BakeTextureAndApplyToMaterial();
        }

        if (GUILayout.Button(GetInspectorGUIContent("ge_saveNewButton"), EditorStyles.miniButton, GUILayout.ExpandWidth(false)))
        {
            finalFilePath = findAssetPath(finalFilePath);
            string path = EditorUtility.SaveFilePanel(GetInspectorData("ge_saveMultiGradient"), finalFilePath + "/Textures/Shadow Ramps/MGPresets", "MultiGradient", "asset");
            if (path.Length != 0)
            {
                path = path.Substring(Application.dataPath.Length - "Assets".Length);
                SCSSMultiGradient _multiGrad = ScriptableObject.CreateInstance<SCSSMultiGradient>();
                _multiGrad.uniqueName = Path.GetFileNameWithoutExtension(path);
                foreach (Gradient grad in gradients)
                {
                    _multiGrad.gradients.Add(reflessGradient(grad));
                }
                _multiGrad.order.AddRange(gradients_index);
                multiGrad = _multiGrad;
                AssetDatabase.CreateAsset(_multiGrad, path);
                gradients = multiGrad.gradients;
                gradients_index = multiGrad.order;
                InitReorderableList();
                AssetDatabase.SaveAssets();
            }
        }
        GUILayout.EndHorizontal();
    }

    private Gradient reflessGradient(Gradient old_grad)
    {
        Gradient grad = new Gradient();
        grad.SetKeys(old_grad.colorKeys, old_grad.alphaKeys);
        grad.mode = old_grad.mode;
        return grad;
    }

    private List<int> reflessIndexes(List<int> old_indexes)
    {
        return new List<int>(old_indexes);
    }

    private void drawHelpText()
    {
        if (dHelpText)
        {
            EditorGUILayout.Space();
            EditorGUILayout.HelpBox(GetInspectorData("ge_basicHelp"), MessageType.Info);
            EditorGUILayout.HelpBox("The boundary values (0.00, 0.50, 1.00...) indicate vertex color thresholds where one ramp layer transitions to the next. The total output texture height equals (Layers × Layer Height).", MessageType.Info);
        }
    }

    private void OnDestroy()
    {
        var current = ResolvedMaterial;
        if (current != null && oldTexture != null)
        {
            if (oldTexture == EditorGUIUtility.whiteTexture) oldTexture = null;
            if (current.HasProperty(rampProperty)) current.SetTexture(rampProperty, oldTexture);
            oldTexture = null;
            focusedMat = null;
            explicitMat = null;
        }

        if (tex != null)
        {
            DestroyImmediate(tex);
        }
    }

    public static void callGradientEditor(Material focusedMat = null)
    {
        XSGradientEditor.focusedMat = focusedMat;
        XSGradientEditor.Init();
    }
}
}