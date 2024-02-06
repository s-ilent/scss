using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEditor;
using Object = UnityEngine.Object;

#if UNITY_2020_2_OR_NEWER
using UnityEditor.AssetImporters;
#else
using UnityEditor.Experimental.AssetImporters;
#endif

namespace SilentCelShading.Unity
{
[CanEditMultipleObjects]
[ScriptedImporter(k_VersionNumber, SCSS_XSGradientImporter.kFileExtension)]
public class SCSS_XSGradientImporter : ScriptedImporter
{
    public int rampWidth = 256;
    public int rampHeight = 8;

    public bool isLinear = false;

    public List<Gradient> gradients = new List<Gradient>();

#if UNITY_2020_1_OR_NEWER
        const int k_VersionNumber = 202010;
#else
        const int k_VersionNumber = 201940;
#endif

    /// The file extension used for gradient assets without leading dot.
    public const string kFileExtension = "scss_gradient";

    public override void OnImportAsset(AssetImportContext ctx)
    {
        // The final texture should be rampWidth long and rampHeight * ramp count high. 
        int numGradients = gradients.Count;
        int width = rampWidth;
        int height = rampHeight * numGradients;
        
        Texture2D tex = Texture2D.whiteTexture;
        if (width * height > 0)
        {
            tex = new Texture2D(width, height, TextureFormat.RGBA32, false);
            for (int y = 0; y < height; y++) // Per gradient
            {
                for (int x = 0; x < width; x++) // Per pixel
                {
                    int gradientIndex = y / rampHeight;
                    Color grad_col = gradients[gradientIndex].Evaluate((float)x / (float)width);
                    tex.SetPixel(x, y, isLinear ? grad_col.gamma : grad_col);
                }
            }
        } 
        ctx.AddObjectToAsset("gradient", tex);
        ctx.SetMainObject(tex);
    }
    
    [MenuItem("Assets/Create/SCSS Gradient", priority = 310)]
    static void CreateSCSSGradientMenuItem()
    {
        var kGradientassetContent = "This file represents a Gradient asset for Unity.\nYou need the 'SCSS Gradient' package to properly import this file in Unity.";
        // https://forum.unity.com/threads/how-to-implement-create-new-asset.759662/
        string directoryPath = "Assets";
        foreach (Object obj in Selection.GetFiltered(typeof(Object), SelectionMode.Assets))
        {
            directoryPath = AssetDatabase.GetAssetPath(obj);
            if (!string.IsNullOrEmpty(directoryPath) && File.Exists(directoryPath))
            {
                directoryPath = Path.GetDirectoryName(directoryPath);
                break;
            }
        }
        directoryPath = directoryPath.Replace("\\", "/");
        if (directoryPath.Length > 0 && directoryPath[directoryPath.Length - 1] != '/')
            directoryPath += "/";
        if (string.IsNullOrEmpty(directoryPath))
            directoryPath = "Assets/";
        var fileName = string.Format("New Gradient.{0}", kFileExtension);
        directoryPath = AssetDatabase.GenerateUniqueAssetPath(directoryPath + fileName);
        ProjectWindowUtil.CreateAssetWithContent(directoryPath, kGradientassetContent);
    }
}

[CanEditMultipleObjects]
[CustomEditor(typeof(SCSS_XSGradientImporter))]
public class SCSS_XSGradientImporterEditor: ScriptedImporterEditor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
    }
}
}
