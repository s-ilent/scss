using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;
using System.IO;
using System.Text.RegularExpressions;
using System.Text;
using System.Globalization;
using System.Linq;

// Based on Kaj Shader Optimizer, v9, licensed under MIT license
// https://github.com/DarthShader/Kaj-Unity-Shaders/blob/master/Shaders/Kaj/Editor/KajShaderOptimizer.cs
// Thanks, Kaj!

namespace SilentCelShading.Unity.Baking
{
    public enum LightMode
    {
        Always=1,
        ForwardBase=2,
        ForwardAdd=4,
        Deferred=8,
        ShadowCaster=16,
        MotionVectors=32,
        PrepassBase=64,
        PrepassFinal=128,
        Vertex=256,
        VertexLMRGBM=512,
        VertexLM=1024
    }

    public class ShaderOptimizer
    {
        public static bool RemoveUnityBranches = true;

        public static readonly string LODCrossFadePropertyName = "_LODCrossfade";
        public static readonly string IgnoreProjectorPropertyName = "_IgnoreProjector";
        public static readonly string ForceNoShadowCastingPropertyName = "_ForceNoShadowCasting";
        public static readonly string AnimatedPropertySuffix = "Animated";
        public static readonly string DisabledLightModesPropertyName = "_LightModes";
        public static readonly string UseInlineSamplerStatesPropertyName = "_InlineSamplerStates";
        private static bool UseInlineSamplerStates = true;

        public static readonly string OptimizerEnabledKeyword = "FINALPASS";

        public static readonly string GeometryShaderEnabledPropertyName = "group_toggle_Geometry";
        public static readonly string TessellationEnabledPropertyName = "group_toggle_Tessellation";
        private static bool UseGeometry = true;
        private static bool UseGeometryForwardBase = true;
        private static bool UseGeometryForwardAdd = true;
        private static bool UseGeometryShadowCaster = true;
        private static bool UseGeometryMeta = true;
        private static bool UseTessellation = false;
        private static bool UseTessellationForwardBase = true;
        private static bool UseTessellationForwardAdd = true;
        private static bool UseTessellationShadowCaster = true;
        private static bool UseTessellationMeta = false;

        public static readonly string TessellationMaxFactorPropertyName = "_TessellationFactorMax";
        public static readonly string LogHeader = "Shader Baking: ";

        enum LightModeType { None, ForwardBase, ForwardAdd, ShadowCaster, Meta, DepthOnly, DepthNormals };
        private static LightModeType CurrentLightmode = LightModeType.None;

        public static readonly string[] InlineSamplerStateNames = new string[]
        {
            "_linear_repeat", "_linear_clamp", "_linear_mirror", "_linear_mirroronce",
            "_point_repeat", "_point_clamp", "_point_mirror", "_point_mirroronce",
            "_trilinear_repeat", "_trilinear_clamp", "_trilinear_mirror", "_trilinear_mirroronce"
        };

        public static readonly HashSet<string> DefaultUnityShaderIncludes = new HashSet<string>()
        {
            "UnityUI.cginc", "AutoLight.cginc", "GLSLSupport.glslinc", "HLSLSupport.cginc",
            "Lighting.cginc", "SpeedTreeBillboardCommon.cginc", "SpeedTreeCommon.cginc",
            "SpeedTreeVertex.cginc", "SpeedTreeWind.cginc", "TerrainEngine.cginc",
            "TerrainSplatmapCommon.cginc", "Tessellation.cginc", "UnityBuiltin2xTreeLibrary.cginc",
            "UnityBuiltin3xTreeLibrary.cginc", "UnityCG.cginc", "UnityCG.glslinc",
            "UnityCustomRenderTexture.cginc", "UnityDeferredLibrary.cginc", "UnityDeprecated.cginc",
            "UnityGBuffer.cginc", "UnityGlobalIllumination.cginc", "UnityImageBasedLighting.cginc",
            "UnityInstancing.cginc", "UnityLightingCommon.cginc", "UnityMetaPass.cginc",
            "UnityPBSLighting.cginc", "UnityShaderUtilities.cginc", "UnityShaderVariables.cginc",
            "UnityShadowLibrary.cginc", "UnitySprites.cginc", "UnityStandardBRDF.cginc",
            "UnityStandardConfig.cginc", "UnityStandardCore.cginc", "UnityStandardCoreForward.cginc",
            "UnityStandardCoreForwardSimple.cginc", "UnityStandardInput.cginc",
            "UnityStandardMeta.cginc", "UnityStandardParticleInstancing.cginc",
            "UnityStandardParticles.cginc", "UnityStandardParticleShadow.cginc",
            "UnityStandardShadow.cginc", "UnityStandardUtils.cginc",
            "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl",
            "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl",
            "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl",
            "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl",
            "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl",
            "Packages/com.unity.render-pipelines.core/ShaderLibrary/FoveatedRenderingKeywords.hlsl",
            "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ProbeVolumeVariants.hlsl",
            "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl",
            "Packages/com.unity.render-pipelines.core/ShaderLibrary/MetaPass.hlsl",
            "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MotionVectorsCommon.hlsl"
        };

        public static readonly HashSet<char> ValidSeparators = new HashSet<char>() { ' ', '\t', '\r', '\n', ';', ',', '.', '(', ')', '[', ']', '{', '}', '>', '<', '=', '!', '&', '|', '^', '+', '-', '*', '/', '#' };

        public static readonly HashSet<string> ValidPropertyDataTypes = new HashSet<string>()
        {
            "int", "float", "float2", "float3", "float4", "half", "half2", "half3", "half4", "fixed", "fixed2", "fixed3", "fixed4"
        };

        public enum RenderPipeline { BuiltIn, URP, Other };

        public static readonly string[] PreprocessStructureStart = new string[] { "CGINCLUDE", "CBUFFER_START(UnityPerMaterial)" };
        public static readonly string[] PreprocessStructureEnd = new string[] { "ENDCG", "CBUFFER_END" };
        public static readonly string[] CodeBlockStart = new string[] { "CGPROGRAM", "HLSLPROGRAM" };
        public static readonly string[] CodeBlockEnd = new string[] { "ENDCG", "ENDHLSL" };

        public enum PropertyType { Vector, Float }

        public class PropertyData
        {
            public PropertyType type;
            public string name;
            public Vector4 value;
            public string lastDeclarationType;

            public void ToCode(StringBuilder sb)
            {
                switch (type)
                {
                    case PropertyType.Float:
                        string constantValue;
                        if (lastDeclarationType == "int")
                            constantValue = value.x.ToString("F0", CultureInfo.InvariantCulture);
                        else
                            constantValue = value.x.ToString("0.0####################", CultureInfo.InvariantCulture);

                        sb.Append("float(" + constantValue + ")");
                        break;
                    case PropertyType.Vector:
                        sb.Append("float4(");
                        sb.Append(value.x.ToString(CultureInfo.InvariantCulture)); sb.Append(",");
                        sb.Append(value.y.ToString(CultureInfo.InvariantCulture)); sb.Append(",");
                        sb.Append(value.z.ToString(CultureInfo.InvariantCulture)); sb.Append(",");
                        sb.Append(value.w.ToString(CultureInfo.InvariantCulture));
                        sb.Append(")");
                        break;
                }
            }
        }

        public class Macro
        {
            public string name;
            public string[] args;
            public string contents;
        }

        public class ParsedShaderFile
        {
            public string filePath;
            public string[] lines;
        }

        public class TextureProperty
        {
            public string name;
            public Texture texture;
            public int uv;
            public Vector2 scale;
            public Vector2 offset;
        }

        public class GrabPassReplacement
        {
            public string originalName;
            public string newName;
        }

        private static string GetColorMaskString(int colorMask)
        {
            if (colorMask == 0) return "0";
            string mask = "";
            if ((colorMask & 8) != 0) mask += "R";
            if ((colorMask & 4) != 0) mask += "G";
            if ((colorMask & 2) != 0) mask += "B";
            if ((colorMask & 1) != 0) mask += "A";
            return mask;
        }

        public static RenderPipeline GetActiveRenderPipeline()
        {
            var pipelineAsset = UnityEngine.Rendering.GraphicsSettings.defaultRenderPipeline;
            if (pipelineAsset != null)
            {
                if (pipelineAsset.GetType().Name == "UniversalRenderPipelineAsset")
                    return RenderPipeline.URP;
                else
                    return RenderPipeline.Other;
            }
            return RenderPipeline.BuiltIn;
        }

        public static bool Lock(Material material, MaterialProperty[] props)
        {
            RenderPipeline pipeline = GetActiveRenderPipeline();
            if (pipeline == RenderPipeline.Other)
            {
                Debug.LogError(LogHeader + "Locking is not supported for this render pipeline.");
                return false;
            }

            Shader shader = material.shader;
            string shaderFilePath = AssetDatabase.GetAssetPath(shader);
            string materialFilePath = AssetDatabase.GetAssetPath(material);
            string materialFolder = Path.GetDirectoryName(materialFilePath);
            string smallguid = Guid.NewGuid().ToString().Split('-')[0];
            string newShaderName = "Hidden/" + shader.name + "/" + material.name + "-" + smallguid;
            string newShaderDirectory = materialFolder + "/BakedShaders/" + material.name + "-" + smallguid + "/";

            StringBuilder definesSB = new StringBuilder();
            definesSB.Append(Environment.NewLine);
            definesSB.Append("#define ");
            definesSB.Append(OptimizerEnabledKeyword);
            definesSB.Append(Environment.NewLine);

            foreach (string keyword in material.shaderKeywords)
            {
                if (keyword == "") continue;
                definesSB.Append("#define ");
                definesSB.Append(keyword);
                definesSB.Append(Environment.NewLine);
            }

            List<PropertyData> constantProps = new List<PropertyData>();
            foreach (MaterialProperty prop in props)
            {
                if (prop == null) continue;

                switch (prop.type)
                {
                    case MaterialProperty.PropType.Float:
                    case MaterialProperty.PropType.Range:
#if UNITY_2022_1_OR_NEWER
                    case MaterialProperty.PropType.Int:
#endif
                        definesSB.Append("#define PROP");
                        definesSB.Append(prop.name.ToUpperInvariant());
                        definesSB.Append(' ');
                        definesSB.Append(prop.floatValue.ToString(CultureInfo.InvariantCulture));
                        definesSB.Append(Environment.NewLine);
                        break;
                    case MaterialProperty.PropType.Texture:
                        if (prop.textureValue != null)
                        {
                            definesSB.Append("#define PROP");
                            definesSB.Append(prop.name.ToUpperInvariant());
                            definesSB.Append(Environment.NewLine);
                        }
                        break;
                }

                if (prop.name.EndsWith(AnimatedPropertySuffix)) continue;
                else if (prop.name == UseInlineSamplerStatesPropertyName)
                {
                    UseInlineSamplerStates = (prop.floatValue == 1);
                    continue;
                }
                else if (prop.name.StartsWith(GeometryShaderEnabledPropertyName))
                {
                    if (prop.name == GeometryShaderEnabledPropertyName) UseGeometry = (prop.floatValue == 1);
                    else if (prop.name == GeometryShaderEnabledPropertyName + "ForwardBase") UseGeometryForwardBase = (prop.floatValue == 1);
                    else if (prop.name == GeometryShaderEnabledPropertyName + "ForwardAdd") UseGeometryForwardAdd = (prop.floatValue == 1);
                    else if (prop.name == GeometryShaderEnabledPropertyName + "ShadowCaster") UseGeometryShadowCaster = (prop.floatValue == 1);
                    else if (prop.name == GeometryShaderEnabledPropertyName + "Meta") UseGeometryMeta = (prop.floatValue == 1);
                }
                else if (prop.name.StartsWith(TessellationEnabledPropertyName))
                {
                    if (prop.name == TessellationEnabledPropertyName) UseTessellation = (prop.floatValue == 1);
                    else if (prop.name == TessellationEnabledPropertyName + "ForwardBase") UseTessellationForwardBase = (prop.floatValue == 1);
                    else if (prop.name == TessellationEnabledPropertyName + "ForwardAdd") UseTessellationForwardAdd = (prop.floatValue == 1);
                    else if (prop.name == TessellationEnabledPropertyName + "ShadowCaster") UseTessellationShadowCaster = (prop.floatValue == 1);
                    else if (prop.name == TessellationEnabledPropertyName + "Meta") UseTessellationMeta = (prop.floatValue == 1);
                }

                MaterialProperty animatedProp = Array.Find(props, x => x.name == prop.name + AnimatedPropertySuffix);
                if (animatedProp != null && animatedProp.floatValue == 1)
                    continue;

                PropertyData propData;
                switch (prop.type)
                {
                    case MaterialProperty.PropType.Color:
                        propData = new PropertyData();
                        propData.type = PropertyType.Vector;
                        propData.name = prop.name;
                        if ((prop.flags & MaterialProperty.PropFlags.HDR) != 0)
                        {
                            if ((prop.flags & MaterialProperty.PropFlags.Gamma) != 0) propData.value = prop.colorValue.linear;
                            else propData.value = prop.colorValue;
                        }
                        else if ((prop.flags & MaterialProperty.PropFlags.Gamma) != 0) propData.value = prop.colorValue;
                        else propData.value = prop.colorValue.linear;
                        constantProps.Add(propData);
                        break;
                    case MaterialProperty.PropType.Vector:
                        propData = new PropertyData();
                        propData.type = PropertyType.Vector;
                        propData.name = prop.name;
                        propData.value = prop.vectorValue;
                        constantProps.Add(propData);
                        break;
                    case MaterialProperty.PropType.Float:
                    case MaterialProperty.PropType.Range:
#if UNITY_2022_1_OR_NEWER
                    case MaterialProperty.PropType.Int:
#endif
                        propData = new PropertyData();
                        propData.type = PropertyType.Float;
                        propData.name = prop.name;
                        propData.value = new Vector4(prop.floatValue, 0, 0, 0);
                        constantProps.Add(propData);
                        break;
                    case MaterialProperty.PropType.Texture:
                        animatedProp = Array.Find(props, x => x.name == prop.name + "_ST" + AnimatedPropertySuffix);
                        if (!(animatedProp != null && animatedProp.floatValue == 1))
                        {
                            PropertyData ST = new PropertyData();
                            ST.type = PropertyType.Vector;
                            ST.name = prop.name + "_ST";
                            Vector2 offset = material.GetTextureOffset(prop.name);
                            Vector2 scale = material.GetTextureScale(prop.name);
                            ST.value = new Vector4(scale.x, scale.y, offset.x, offset.y);
                            constantProps.Add(ST);
                        }
                        animatedProp = Array.Find(props, x => x.name == prop.name + "_TexelSize" + AnimatedPropertySuffix);
                        if (!(animatedProp != null && animatedProp.floatValue == 1))
                        {
                            PropertyData TexelSize = new PropertyData();
                            TexelSize.type = PropertyType.Vector;
                            TexelSize.name = prop.name + "_TexelSize";
                            Texture t = prop.textureValue;
                            if (t != null) TexelSize.value = new Vector4(1.0f / t.width, 1.0f / t.height, t.width, t.height);
                            else TexelSize.value = new Vector4(1.0f, 1.0f, 1.0f, 1.0f);
                            constantProps.Add(TexelSize);
                        }
                        break;
                }
            }
            string optimizerDefines = definesSB.ToString();

            List<string> disabledLightModes = new List<string>();
            var disabledLightModesProperty = Array.Find(props, x => x.name == DisabledLightModesPropertyName);
            if (disabledLightModesProperty != null)
            {
                int lightModesMask = (int)disabledLightModesProperty.floatValue;
                if ((lightModesMask & (int)LightMode.ForwardAdd) != 0) disabledLightModes.Add("ForwardAdd");
                if ((lightModesMask & (int)LightMode.ShadowCaster) != 0) disabledLightModes.Add("ShadowCaster");
            }

            List<ParsedShaderFile> shaderFiles = new List<ParsedShaderFile>();
            List<Macro> macros = new List<Macro>();
            if (!ParseShaderFilesRecursive(shaderFiles, newShaderDirectory, shaderFilePath, macros))
                return false;

            Dictionary<string, PropertyData> constantPropsDictionary = constantProps.GroupBy(x => x.name).Select(g => g.First()).ToDictionary(x => x.name);
            Macro[] macrosArray = macros.ToArray();
            List<GrabPassReplacement> grabPassVariables = new List<GrabPassReplacement>();

            foreach (ParsedShaderFile psf in shaderFiles)
            {
                if (psf.filePath.EndsWith(".shader", StringComparison.Ordinal) || psf.filePath.EndsWith(".hlsl", StringComparison.Ordinal))
                {
                    for (int i=0; i<psf.lines.Length;i++)
                    {
                        string trimmedLine = psf.lines[i].TrimStart();
                        if (trimmedLine.StartsWith("Shader", StringComparison.Ordinal))
                        {
                            string originalSgaderName = psf.lines[i].Split('\"')[1];
                            psf.lines[i] = psf.lines[i].Replace(originalSgaderName, newShaderName);
                        }
                        else if (trimmedLine.StartsWith("//#pragmamulti_compile_LOD_FADE_CROSSFADE", StringComparison.Ordinal))
                        {
                            MaterialProperty crossfadeProp = Array.Find(props, x => x.name == LODCrossFadePropertyName);
                            if (crossfadeProp != null && crossfadeProp.floatValue == 1)
                                psf.lines[i] = psf.lines[i].Replace("//#pragma", "#pragma");
                        }
                        else if (trimmedLine.StartsWith("//\"IgnoreProjector\"=\"True\"", StringComparison.Ordinal))
                        {
                            MaterialProperty projProp = Array.Find(props, x => x.name == IgnoreProjectorPropertyName);
                            if (projProp != null && projProp.floatValue == 1)
                                psf.lines[i] = psf.lines[i].Replace("//\"IgnoreProjector", "\"IgnoreProjector");
                        }
                        else if (trimmedLine.StartsWith("//\"ForceNoShadowCasting\"=\"True\"", StringComparison.Ordinal))
                        {
                            MaterialProperty forceNoShadowsProp = Array.Find(props, x => x.name == ForceNoShadowCastingPropertyName);
                            if (forceNoShadowsProp != null && forceNoShadowsProp.floatValue == 1)
                                psf.lines[i] = psf.lines[i].Replace("//\"ForceNoShadowCasting", "\"ForceNoShadowCasting");
                        }
                        else if (trimmedLine.StartsWith("GrabPass {", StringComparison.Ordinal))
                        {
                            GrabPassReplacement gpr = new GrabPassReplacement();
                            string[] splitLine = trimmedLine.Split('\"');
                            if (splitLine.Length == 1) gpr.originalName = "_GrabTexture";
                            else gpr.originalName = splitLine[1];

                            gpr.newName = material.GetTag("GrabPass" + grabPassVariables.Count, false, "_GrabTexture");
                            psf.lines[i] = "GrabPass { \"" + gpr.newName + "\" }";
                            grabPassVariables.Add(gpr);
                        }
                        else if (trimmedLine.StartsWith(PreprocessStructureStart[(int) pipeline], StringComparison.Ordinal))
                        {
                            for (int j = i + 1; j < psf.lines.Length; j++)
                                if (psf.lines[j].TrimStart().StartsWith(PreprocessStructureEnd[(int) pipeline], StringComparison.Ordinal))
                                {
                                    ReplaceShaderValues(material, psf.lines, i + 1, j, props, constantPropsDictionary, macrosArray, grabPassVariables.ToArray());
                                    break;
                                }
                        }
                        else if (trimmedLine.StartsWith(CodeBlockStart[(int) pipeline], StringComparison.Ordinal))
                        {
                            psf.lines[i] += optimizerDefines;
                            for (int j = i + 1; j < psf.lines.Length; j++)
                                if (psf.lines[j].TrimStart().StartsWith(CodeBlockEnd[(int) pipeline], StringComparison.Ordinal))
                                {
                                    ReplaceShaderValues(material, psf.lines, i + 1, j, props, constantPropsDictionary, macrosArray, grabPassVariables.ToArray());
                                    break;
                                }
                        }
                        else if (trimmedLine.StartsWith("Tags", StringComparison.Ordinal))
                        {
                            string lineFullyTrimmed = trimmedLine.Replace(" ", "").Replace("\t", "");
                            if (lineFullyTrimmed.Contains("\"LightMode\"=\""))
                            {
                                string lightModeName = lineFullyTrimmed.Split('\"')[3];

                                if (lightModeName == "ForwardBase") CurrentLightmode = LightModeType.ForwardBase;
                                else if (lightModeName == "ForwardAdd") CurrentLightmode = LightModeType.ForwardAdd;
                                else if (lightModeName == "ShadowCaster") CurrentLightmode = LightModeType.ShadowCaster;
                                else if (lightModeName == "Meta") CurrentLightmode = LightModeType.Meta;
                                else CurrentLightmode = LightModeType.None;

                                if (disabledLightModes.Contains(lightModeName))
                                {
                                    int j = i - 1;
                                    for (; j >= 0; j--)
                                        if (psf.lines[j].Replace(" ", "").Replace("\t", "") == "Pass") break;
                                    for (; j < psf.lines.Length; j++)
                                    {
                                        if (psf.lines[j].Replace(" ", "").Replace("\t", "") == "ENDCG") break;
                                        psf.lines[j] = "";
                                    }
                                    for (; j < psf.lines.Length; j++)
                                    {
                                        string temp = psf.lines[j];
                                        psf.lines[j] = "";
                                        if (temp.Replace(" ", "").Replace("\t", "") == "}") break;
                                    }
                                }
                            }
                        }
                        else if (trimmedLine.StartsWith("ColorMask", StringComparison.Ordinal))
                        {
                            Match regMatch = Regex.Match(trimmedLine, @"\[\w+\]");
                            if(regMatch.Success)
                            {
                                string trimmedRegMatch = regMatch.Value.Trim('[', ']');
                                if (constantPropsDictionary.ContainsKey(trimmedRegMatch))
                                {
                                    PropertyData colorMaskProp = constantPropsDictionary[trimmedRegMatch];
                                    psf.lines[i] = psf.lines[i].Replace(regMatch.Value, GetColorMaskString((int)colorMaskProp.value.x));
                                }
                            }
                        }
                        else if (trimmedLine.StartsWith("Cull", StringComparison.OrdinalIgnoreCase))
                        {
                            Match regMatch = Regex.Match(trimmedLine, @"\[\w+\]");
                            if(regMatch.Success)
                            {
                                string trimmedRegMatch = regMatch.Value.Trim('[', ']');
                                if (constantPropsDictionary.ContainsKey(trimmedRegMatch))
                                {
                                    PropertyData cullModeProp = constantPropsDictionary[trimmedRegMatch];
                                    psf.lines[i] = psf.lines[i].Replace(regMatch.Value, ((UnityEngine.Rendering.CullMode)cullModeProp.value.x).ToString());
                                }
                            }
                        }
                    }
                }
                else
                    ReplaceShaderValues(material, psf.lines, 0, psf.lines.Length, props, constantPropsDictionary, macrosArray, grabPassVariables.ToArray());

                int totalLen = psf.lines.Length * 2;
                foreach (string line in psf.lines) totalLen += line.Length;

                StringBuilder sb = new StringBuilder(totalLen);
                foreach (string line in psf.lines) sb.AppendLine(line);
                string output = sb.ToString();

                string newShaderFilePath = Path.GetFileName(psf.filePath);
                (new FileInfo(newShaderDirectory + newShaderFilePath)).Directory.Create();
                try
                {
                    StreamWriter sw = new StreamWriter(newShaderDirectory + newShaderFilePath);
                    sw.Write(output);
                    sw.Close();
                }
                catch (IOException e)
                {
                    Debug.LogError(LogHeader + "Processed shader file " + newShaderDirectory + newShaderFilePath + " could not be written.  " + e);
                    return false;
                }
            }

            AssetDatabase.Refresh();

            material.SetOverrideTag("OriginalShader", shader.name);
            material.SetOverrideTag("BakedShaderFolder", material.name + "-" + smallguid);

            foreach (string keyword in material.shaderKeywords)
                material.DisableKeyword(keyword);

            string renderType = material.GetTag("RenderType", false, "");
            int renderQueue = material.renderQueue;

            Shader newShader = Shader.Find(newShaderName);
            if (newShader == null)
            {
                Debug.LogError(LogHeader + "Generated shader " + newShaderName + " could not be found");
                return false;
            }
            material.shader = newShader;
            material.SetOverrideTag("RenderType", renderType);
            material.renderQueue = renderQueue;

            return true;
        }

        private static bool ParseShaderFilesRecursive(List<ParsedShaderFile> filesParsed, string newTopLevelDirectory, string filePath, List<Macro> macros)
        {
            if (filesParsed.Exists(x => x.filePath == filePath)) return true;

            ParsedShaderFile psf = new ParsedShaderFile();
            psf.filePath = filePath;
            filesParsed.Add(psf);

            string fileContents = null;
            try
            {
                StreamReader sr = new StreamReader(filePath);
                fileContents = sr.ReadToEnd();
                sr.Close();
            }
            catch (FileNotFoundException e)
            {
                Debug.LogError(LogHeader + "Shader file " + filePath + " not found.  " + e);
                return false;
            }
            catch (IOException e)
            {
                Debug.LogError(LogHeader + "Error reading shader file.  " + e);
                return false;
            }

            List<String> macrosList = new List<string>();
            string[] fileLines = fileContents.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);

            for (int i=0; i<fileLines.Length; i++)
            {
                string lineParsed = fileLines[i].TrimStart();
                if (lineParsed.StartsWith("#include", StringComparison.Ordinal))
                {
                    int firstQuotation = lineParsed.IndexOf('\"',0);
                    int lastQuotation = lineParsed.IndexOf('\"',firstQuotation+1);
                    string includeFilename = lineParsed.Substring(firstQuotation+1, lastQuotation-firstQuotation-1);

                    if (DefaultUnityShaderIncludes.Contains(includeFilename) == false)
                    {
                        string includeFullpath = includeFilename;
                        if (includeFilename.StartsWith("Assets/", StringComparison.Ordinal) == false && includeFilename.StartsWith("Packages/", StringComparison.Ordinal) == false)
                            includeFullpath = GetFullPath(includeFilename, Path.GetDirectoryName(filePath));

                        if (!ParseShaderFilesRecursive(filesParsed, newTopLevelDirectory, includeFullpath, macros))
                            return false;

                        fileLines[i] = fileLines[i].Replace(includeFilename, "/"+includeFilename.Split('/').Last());
                    }
                }
                else if (lineParsed.StartsWith("FallBack", StringComparison.Ordinal))
                    fileLines[i] = "//" + fileLines[i];
                else if (lineParsed == "//KSOEvaluateMacro")
                {
                    string macro = "";
                    string lineTrimmed = null;
                    do
                    {
                        i++;
                        lineTrimmed = fileLines[i].TrimEnd();
                        if (lineTrimmed.EndsWith("\\", StringComparison.Ordinal))
                            macro += lineTrimmed.TrimEnd('\\') + Environment.NewLine;
                        else macro += lineTrimmed;
                    }
                    while (lineTrimmed.EndsWith("\\", StringComparison.Ordinal));
                    macrosList.Add(macro);
                }
            }

            foreach (string macroString in macrosList)
            {
                string m = macroString.TrimStart();
                Macro macro = new Macro();

                if (!m.StartsWith("#define", StringComparison.Ordinal)) continue;
                m = m.Remove(0, "#define".Length).TrimStart();

                string allArgs = "";
                if (m.Contains('('))
                {
                    macro.name = m.Split('(')[0];
                    m = m.Remove(0, macro.name.Length + "(".Length);
                    allArgs = m.Split(')')[0];
                    allArgs = allArgs.Trim().Replace(" ","").Replace("\t","");
                    macro.args = allArgs.Split(',');
                    m = m.Remove(0, allArgs.Length + ")".Length).TrimStart();
                    macro.contents = m;
                }
                else continue;
                macros.Add(macro);
            }

            psf.lines = fileLines;
            return true;
        }

        public static string GetFullPath(string relativePath, string basePath)
        {
            while (relativePath.StartsWith("./"))
                relativePath = relativePath.Remove(0, "./".Length);
            while (relativePath.StartsWith("../"))
            {
                basePath = basePath.Remove(basePath.LastIndexOf(Path.DirectorySeparatorChar), basePath.Length - basePath.LastIndexOf(Path.DirectorySeparatorChar));
                relativePath = relativePath.Remove(0, "../".Length);
            }
            return basePath + '/' + relativePath;
        }

        private static void ReplaceShaderValues(Material material, string[] lines, int startLine, int endLine,
            MaterialProperty[] props, Dictionary<string,PropertyData> constants, Macro[] macros, GrabPassReplacement[] grabPassVariables)
        {
            List <TextureProperty> uniqueSampledTextures = new List<TextureProperty>();

            for (int i=startLine;i<endLine;i++)
            {
                string lineTrimmed = lines[i].TrimStart();
                string[] tokens = lineTrimmed.Split(new char[]{' ', '\t', '(', ')', '[', ']', '+', '-', '*', '/', '.', ',', ';', '=', '!'}, StringSplitOptions.RemoveEmptyEntries);

                if (lineTrimmed.StartsWith("#pragma geometry", StringComparison.Ordinal))
                {
                    if (!UseGeometry) lines[i] = "//" + lines[i];
                    else
                    {
                        switch (CurrentLightmode)
                        {
                            case LightModeType.ForwardBase: if (!UseGeometryForwardBase) lines[i] = "//" + lines[i]; break;
                            case LightModeType.ForwardAdd: if (!UseGeometryForwardAdd) lines[i] = "//" + lines[i]; break;
                            case LightModeType.ShadowCaster: if (!UseGeometryShadowCaster) lines[i] = "//" + lines[i]; break;
                            case LightModeType.Meta: if (!UseGeometryMeta) lines[i] = "//" + lines[i]; break;
                        }
                    }
                }
                else if (lineTrimmed.StartsWith("#pragma hull", StringComparison.Ordinal) || lineTrimmed.StartsWith("#pragma domain", StringComparison.Ordinal))
                {
                    if (!UseTessellation) lines[i] = "//" + lines[i];
                    else
                    {
                        switch (CurrentLightmode)
                        {
                            case LightModeType.ForwardBase: if (!UseTessellationForwardBase) lines[i] = "//" + lines[i]; break;
                            case LightModeType.ForwardAdd: if (!UseTessellationForwardAdd) lines[i] = "//" + lines[i]; break;
                            case LightModeType.ShadowCaster: if (!UseTessellationShadowCaster) lines[i] = "//" + lines[i]; break;
                            case LightModeType.Meta: if (!UseTessellationMeta) lines[i] = "//" + lines[i]; break;
                        }
                    }
                }
                else if (lineTrimmed.StartsWith("#pragma shader_feature", StringComparison.Ordinal) || lineTrimmed.StartsWith("#pragma shader_feature_local", StringComparison.Ordinal))
                {
                    lines[i] = "//" + lines[i];
                }
                else if (UseInlineSamplerStates && lineTrimmed.StartsWith("//KSOInlineSamplerState", StringComparison.Ordinal))
                {
                    string lineParsed = lineTrimmed.Replace(" ","").Replace("\t","");
                    int firstParenthesis = lineParsed.IndexOf('(');
                    int lastParenthesis = lineParsed.IndexOf(')');
                    string argsString = lineParsed.Substring(firstParenthesis+1, lastParenthesis - firstParenthesis-1);
                    string[] args = argsString.Split(',');
                    MaterialProperty texProp = Array.Find(props, x => x.name == args[1]);
                    if (texProp != null)
                    {
                        Texture t = texProp.textureValue;
                        int inlineSamplerIndex = 0;
                        if (t != null)
                        {
                            switch (t.filterMode)
                            {
                                case FilterMode.Bilinear: break;
                                case FilterMode.Point: inlineSamplerIndex += 1 * 4; break;
                                case FilterMode.Trilinear: inlineSamplerIndex += 2 * 4; break;
                            }
                            switch (t.wrapMode)
                            {
                                case TextureWrapMode.Repeat: break;
                                case TextureWrapMode.Clamp: inlineSamplerIndex += 1; break;
                                case TextureWrapMode.Mirror: inlineSamplerIndex += 2; break;
                                case TextureWrapMode.MirrorOnce: inlineSamplerIndex += 3; break;
                            }
                        }
                        lines[i+1] = lines[i+1].Replace(args[0], InlineSamplerStateNames[inlineSamplerIndex]);
                    }
                }
                else if (lineTrimmed.StartsWith("//KSODuplicateTextureCheckStart", StringComparison.Ordinal))
                {
                    uniqueSampledTextures = new List<TextureProperty>();
                }
                else if (lineTrimmed.StartsWith("//KSODuplicateTextureCheck", StringComparison.Ordinal))
                {
                    string lineParsed = lineTrimmed.Replace(" ", "").Replace("\t", "");
                    int firstParenthesis = lineParsed.IndexOf('(');
                    int lastParenthesis = lineParsed.IndexOf(')');
                    string argName = lineParsed.Substring(firstParenthesis+1, lastParenthesis-firstParenthesis-1);
                    if (Array.Exists(props, x => x.name == argName))
                    {
                        MaterialProperty argProp = Array.Find(props, x => x.name == argName);
                        if (argProp.textureValue != null)
                        {
                            int UV = 0;
                            if (Array.Exists(props, x => x.name == argName + "UV"))
                                UV = (int)(Array.Find(props, x => x.name == argName + "UV").floatValue);

                            Vector2 texScale = material.GetTextureScale(argName);
                            Vector2 texOffset = material.GetTextureOffset(argName);

                            if (uniqueSampledTextures.Exists(x => (x.texture == argProp.textureValue)
                                                               && (x.uv == UV) && (x.scale == texScale) && x.offset == texOffset))
                            {
                                string texName = uniqueSampledTextures.Find(x => (x.texture == argProp.textureValue) && (x.uv == UV)).name;
                                lines[i] = argName + "_var = " + texName + "_var;";
                            }
                            else
                            {
                                TextureProperty tp = new TextureProperty();
                                tp.name = argName;
                                tp.texture = argProp.textureValue;
                                tp.uv = UV;
                                tp.scale = texScale;
                                tp.offset = texOffset;
                                uniqueSampledTextures.Add(tp);
                            }
                        }
                    }
                }
                else if (lineTrimmed.StartsWith("[maxtessfactor(", StringComparison.Ordinal))
                {
                    MaterialProperty maxTessFactorProperty = Array.Find(props, x => x.name == TessellationMaxFactorPropertyName);
                    if (maxTessFactorProperty != null)
                    {
                        float maxTessellation = maxTessFactorProperty.floatValue;
                        MaterialProperty maxTessFactorAnimatedProperty = Array.Find(props, x => x.name == TessellationMaxFactorPropertyName + AnimatedPropertySuffix);
                        if (maxTessFactorAnimatedProperty != null && maxTessFactorAnimatedProperty.floatValue == 1)
                            maxTessellation = 64.0f;
                        lines[i] = "[maxtessfactor(" + maxTessellation.ToString(".0######") + ")]";
                    }
                }

                foreach (Macro macro in macros)
                {
                    int macroIndex;
                    if ((macroIndex = lines[i].IndexOf(macro.name + "(", StringComparison.Ordinal)) != -1)
                    {
                        string lineParsed = lineTrimmed.Replace(" ","").Replace("\t","");
                        if (lineParsed.StartsWith("#define", StringComparison.Ordinal)) continue;

                        int firstParenthesis = macroIndex + macro.name.Length;
                        int lastParenthesis = lines[i].IndexOf(')', macroIndex + macro.name.Length+1);
                        string allArgs = lines[i].Substring(firstParenthesis+1, lastParenthesis-firstParenthesis-1);
                        string[] args = allArgs.Split(',');

                        string newContents = macro.contents;
                        for (int j=0; j<args.Length;j++)
                        {
                            args[j] = args[j].Trim();
                            int argIndex;
                            int lastIndex = 0;
                            while ((argIndex = newContents.IndexOf(macro.args[j], lastIndex, StringComparison.Ordinal)) != -1)
                            {
                                lastIndex = argIndex+1;
                                char charLeft = ' ';
                                if (argIndex-1 >= 0) charLeft = newContents[argIndex-1];
                                char charRight = ' ';
                                if (argIndex+macro.args[j].Length < newContents.Length) charRight = newContents[argIndex+macro.args[j].Length];

                                if (ValidSeparators.Contains(charLeft) && ValidSeparators.Contains(charRight))
                                {
                                    StringBuilder sbm = new StringBuilder(newContents.Length - macro.args[j].Length + args[j].Length);
                                    sbm.Append(newContents, 0, argIndex);
                                    sbm.Append(args[j]);
                                    sbm.Append(newContents, argIndex + macro.args[j].Length, newContents.Length - argIndex - macro.args[j].Length);
                                    newContents = sbm.ToString();
                                }
                            }
                        }
                        newContents = newContents.Replace("##", "");
                        StringBuilder sb = new StringBuilder(lines[i].Length + newContents.Length);
                        sb.Append(lines[i], 0, macroIndex);
                        sb.Append(newContents);
                        sb.Append(lines[i], lastParenthesis+1, lines[i].Length - lastParenthesis-1);
                        lines[i] = sb.ToString();
                    }
                }

                for(int t=0;t<tokens.Length;t++)
                {
                    string token = tokens[t];
                    if (constants.ContainsKey(token))
                    {
                        PropertyData constant = constants[token];
                        int constantIndex;
                        int lastIndex = 0;
                        bool declarationFound = false;

                        while ((constantIndex = lines[i].IndexOf(constant.name, lastIndex, StringComparison.Ordinal)) != -1)
                        {
                            lastIndex = constantIndex + 1;
                            char charLeft = ' ';
                            if (constantIndex - 1 >= 0) charLeft = lines[i][constantIndex - 1];
                            char charRight = ' ';
                            if (constantIndex + constant.name.Length < lines[i].Length) charRight = lines[i][constantIndex + constant.name.Length];

                            if (!(ValidSeparators.Contains(charLeft) && ValidSeparators.Contains(charRight)))
                                continue;

                            if (charLeft == '*' && charRight == '*' && constantIndex >= 2 && lines[i][constantIndex - 2] == '/')
                                continue;

                            if (!declarationFound && t > 0)
                            {
                                if (ValidPropertyDataTypes.Contains(tokens[t-1]) && lines[i].Substring(constantIndex + constant.name.Length).TrimStart().StartsWith(";", StringComparison.Ordinal))
                                {
                                    constant.lastDeclarationType = tokens[t-1];
                                    declarationFound = true;
                                    continue;
                                }
                            }

                            StringBuilder sb = new StringBuilder(lines[i].Length * 2);
                            sb.Append(lines[i], 0, constantIndex);
                            constant.ToCode(sb);
                            sb.Append(lines[i], constantIndex + constant.name.Length, lines[i].Length - constantIndex - constant.name.Length);
                            lines[i] = sb.ToString();
                        }
                    }
                }

                foreach (GrabPassReplacement gpr in grabPassVariables)
                {
                    int lastIndex = 0;
                    int gbIndex;
                    while ((gbIndex = lines[i].IndexOf(gpr.originalName, lastIndex, StringComparison.Ordinal)) != -1)
                    {
                        lastIndex = gbIndex+1;
                        char charLeft = ' ';
                        if (gbIndex-1 >= 0) charLeft = lines[i][gbIndex-1];
                        char charRight = ' ';
                        if (gbIndex + gpr.originalName.Length < lines[i].Length) charRight = lines[i][gbIndex + gpr.originalName.Length];

                        if (!(ValidSeparators.Contains(charLeft) && ValidSeparators.Contains(charRight)))
                            continue;

                        StringBuilder sb = new StringBuilder(lines[i].Length * 2);
                        sb.Append(lines[i], 0, gbIndex);
                        sb.Append(gpr.newName);
                        sb.Append(lines[i], gbIndex+gpr.originalName.Length, lines[i].Length-gbIndex-gpr.originalName.Length);
                        lines[i] = sb.ToString();
                    }
                }

                if (RemoveUnityBranches)
                    lines[i] = lines[i].Replace("UNITY_BRANCH", "").Replace("[branch]", "");
            }
        }

        public static bool Unlock (Material material)
        {
            string originalShaderName = material.GetTag("OriginalShader", false, "");
            if (originalShaderName == "")
            {
                Debug.LogError(LogHeader + "Original shader not saved to material, could not unlock shader");
                return false;
            }
            Shader originalShader = Shader.Find(originalShaderName);
            if (originalShader == null)
            {
                Debug.LogError(LogHeader + "Original shader " + originalShaderName + " could not be found");
                return false;
            }

            string renderType = material.GetTag("RenderType", false, "");
            int renderQueue = material.renderQueue;
            material.shader = originalShader;
            material.SetOverrideTag("RenderType", renderType);
            material.renderQueue = renderQueue;

            string shaderDirectory = material.GetTag("BakedShaderFolder", false, "");
            if (shaderDirectory == "")
            {
                Debug.LogError(LogHeader + "Optimized shader folder could not be found, not deleting anything");
                return false;
            }
            string materialFilePath = AssetDatabase.GetAssetPath(material);
            string materialFolder = Path.GetDirectoryName(materialFilePath);
            string newShaderDirectory = materialFolder + "/BakedShaders/" + shaderDirectory;

            FileUtil.DeleteFileOrDirectory(newShaderDirectory + "/");
            FileUtil.DeleteFileOrDirectory(newShaderDirectory + ".meta");

            return true;
        }
    }
}
