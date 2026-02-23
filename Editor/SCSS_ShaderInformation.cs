#if AVATAR_OPTIMIZER && UNITY_EDITOR

using System;
using System.Collections.Generic;
using Anatawa12.AvatarOptimizer.API;
using UnityEditor;
using UnityEngine;

namespace SilentCelShading.Unity.Editor
{
    [InitializeOnLoad]
    internal class SCSS_ShaderInformation : ShaderInformation
    {
        static SCSS_ShaderInformation()
        {
            // Register all SCSS variants using their GUIDs found in the .meta files
            var guids = new[]
            {
                "d1d977b65342e1a4eb8b71e69e46e1ff", // Crosstone (Fur)
                "a9a812ee108476f4eae9c507264cc297", // Crosstone (No Outline)
                "932c3f8bb2ba7d04480beb8e4c98b2a8", // Crosstone
                "a02577692ffe3bb4dac195a8db713239", // Flat Lit Toon (Fur)
                "369d2ecd6fc95bc469360ddecf6b2155", // Flat Lit Toon (No Outline)
                "a883b384ca4bc054aa10b5f554ae85a3", // Flat Lit Toon
            };

            var info = new SCSS_ShaderInformation();
            foreach (var guid in guids)
            {
                ShaderInformationRegistry.RegisterShaderInformationWithGUID(guid, info);
            }
        }

        public override ShaderInformationKind SupportedInformationKind => ShaderInformationKind.TextureAndUVUsage;

        public override void GetMaterialInformation(MaterialInformationCallback matInfo)
        {
            // --- Common Helpers ---
            
            // SCSS uses _MainTex_ST for almost all main layer textures (ColorMask, Bump, etc)
            var mainTexST = matInfo.GetVector("_MainTex_ST");
            Matrix2x3? mainUVMatrix = mainTexST.HasValue 
                ? Matrix2x3.NewScaleOffset(mainTexST.Value) 
                : null;

            // Helper to register a texture using UV0 and MainTex Tiling/Offset
            void RegisterMainUV(string propName, string samplerProp = "_MainTex")
            {
                matInfo.RegisterTextureUVUsage(propName, samplerProp, UsingUVChannels.UV0, mainUVMatrix);
            }

            // Helper to determine UV channel from a property (0=UV0, 1=UV1, etc)
            UsingUVChannels GetUVChannel(string propName)
            {
                return matInfo.GetFloat(propName) switch
                {
                    0 => UsingUVChannels.UV0,
                    1 => UsingUVChannels.UV1,
                    2 => UsingUVChannels.UV2,
                    3 => UsingUVChannels.UV3,
                    _ => UsingUVChannels.UV0 | UsingUVChannels.UV1 // Fallback/Unknown
                };
            }

            // Helper to get Matrix from a specific _ST property
            Matrix2x3? GetCustomMatrix(string stPropName)
            {
                var st = matInfo.GetVector(stPropName);
                return st.HasValue ? Matrix2x3.NewScaleOffset(st.Value) : null;
            }

            // --- Base Textures ---

            RegisterMainUV("_MainTex");
            RegisterMainUV("_ColorMask");
            RegisterMainUV("_ClippingMask");
            RegisterMainUV("_BumpMap"); // SCSS uses MainTex UVs for Normal Map in Forward.cginc

            // Backface feature
            if (matInfo.GetFloat("_UseBackfaceTexture") == 1.0f)
            {
                RegisterMainUV("_MainTexBackface");
            }

            // --- Specular ---
            // _SpecularType: 0=Off, but we register usage regardless if texture exists
            RegisterMainUV("_SpecGlossMap");
            
            // Iridescence uses NoV (View direction), not Mesh UV
            matInfo.RegisterTextureUVUsage("_SpecIridescenceRamp", "_MainTex", UsingUVChannels.NonMesh, null);

            // --- Matcaps ---
            // Matcaps are View-Space/NonMesh
            if (matInfo.GetFloat("_UseMatCap") > 0)
            {
                RegisterMainUV("_MatcapMask"); // Mask follows mesh UV
                matInfo.RegisterTextureUVUsage("_Matcap1", "_Matcap1", UsingUVChannels.NonMesh, null);
                matInfo.RegisterTextureUVUsage("_Matcap2", "_Matcap2", UsingUVChannels.NonMesh, null);
                matInfo.RegisterTextureUVUsage("_Matcap3", "_Matcap3", UsingUVChannels.NonMesh, null);
                matInfo.RegisterTextureUVUsage("_Matcap4", "_Matcap4", UsingUVChannels.NonMesh, null);
            }

            // --- Crosstone Specifics ---
            // These share UV0 and _MainTex_ST logic according to SCSS_Forward.cginc
            RegisterMainUV("_1st_ShadeMap");
            RegisterMainUV("_2nd_ShadeMap");
            RegisterMainUV("_ShadingGradeMap");

            // --- Lightramp Specifics ---
            // _ShadowMask uses UV0. Based on SCSS_Forward it uses _MainTex_ST logic implicitly via sampling macro
            RegisterMainUV("_ShadowMask");
            
            // Ramp is a lookup texture
            matInfo.RegisterTextureUVUsage("_Ramp", SamplerStateInformation.LinearClampSampler, UsingUVChannels.NonMesh, null);

            // --- Outline ---
            if (matInfo.GetFloat("_OutlineMode") != 0.0f)
            {
                // SCSS_ForwardVertex.cginc: TRANSFORM_TEX(postTexcoords.uv[0], _MainTex)
                // It uses MainTex ST
                RegisterMainUV("_OutlineMask"); 
            }

            // --- Fur ---
            if (matInfo.GetFloat("_FurMode") != 0.0f)
            {
                RegisterMainUV("_FurMask");
                // Fur Noise has its own ST
                matInfo.RegisterTextureUVUsage("_FurNoise", "_MainTex", UsingUVChannels.UV0, GetCustomMatrix("_FurNoise_ST"));
            }

            // --- Emission ---
            // _EmissionMap
            UsingUVChannels emUV = GetUVChannel("_EmissionUVSec");
            matInfo.RegisterTextureUVUsage("_EmissionMap", "_MainTex", emUV, GetCustomMatrix("_EmissionMap_ST"));

            // _DetailEmissionMap
            UsingUVChannels detEmUV = GetUVChannel("_DetailEmissionUVSec");
            matInfo.RegisterTextureUVUsage("_DetailEmissionMap", "_DetailEmissionMap", detEmUV, GetCustomMatrix("_DetailEmissionMap_ST"));

            // _EmissionMap2nd
            UsingUVChannels emUV2 = GetUVChannel("_EmissionUVSec2nd");
            matInfo.RegisterTextureUVUsage("_EmissionMap2nd", "_MainTex", emUV2, GetCustomMatrix("_EmissionMap2nd_ST"));

            // _DetailEmissionMap2nd
            UsingUVChannels detEmUV2 = GetUVChannel("_DetailEmissionUVSec2nd");
            matInfo.RegisterTextureUVUsage("_DetailEmissionMap2nd", "_DetailEmissionMap2nd", detEmUV2, GetCustomMatrix("_DetailEmissionMap2nd_ST"));

            // --- Detail Maps ---
            if (matInfo.GetFloat("_UseDetailMaps") == 1.0f)
            {
                RegisterMainUV("_DetailAlbedoMask");

                // Detail maps have individual UV Selectors and STs
                matInfo.RegisterTextureUVUsage("_DetailMap1", "_DetailMap1", GetUVChannel("_DetailMap1UV"), GetCustomMatrix("_DetailMap1_ST"));
                matInfo.RegisterTextureUVUsage("_DetailMap2", "_DetailMap2", GetUVChannel("_DetailMap2UV"), GetCustomMatrix("_DetailMap2_ST"));
                matInfo.RegisterTextureUVUsage("_DetailMap3", "_DetailMap3", GetUVChannel("_DetailMap3UV"), GetCustomMatrix("_DetailMap3_ST"));
                matInfo.RegisterTextureUVUsage("_DetailMap4", "_DetailMap4", GetUVChannel("_DetailMap4UV"), GetCustomMatrix("_DetailMap4_ST"));
            }

            // --- AudioLink ---
            if (matInfo.GetFloat("_UseEmissiveAudiolink") == 1.0f)
            {
                matInfo.RegisterTextureUVUsage("_AudiolinkMaskMap", "_MainTex", GetUVChannel("_AudiolinkMaskMapUVSec"), GetCustomMatrix("_AudiolinkMaskMap_ST"));
                matInfo.RegisterTextureUVUsage("_AudiolinkSweepMap", "_MainTex", GetUVChannel("_AudiolinkSweepMapUVSec"), GetCustomMatrix("_AudiolinkSweepMap_ST"));
            }

            // --- Hatching ---
            if (matInfo.GetFloat("_UseHatching") == 1.0f)
            {
                // Hatching is triplanar/screen based or heavily modified UVs
                matInfo.RegisterTextureUVUsage("_HatchingTex", "_HatchingTex", UsingUVChannels.NonMesh, null);
            }

            // --- Subsurface / Thickness ---
            if (matInfo.GetFloat("_UseSubsurfaceScattering") == 1.0f)
            {
                // Thickness follows main UVs
                RegisterMainUV("_ThicknessMap");
            }
            
            // --- DFG Texture (Internal) ---
            matInfo.RegisterTextureUVUsage("_DFG", SamplerStateInformation.LinearClampSampler, UsingUVChannels.NonMesh, null);
        }
    }
}
#endif // AVATAR_OPTIMIZER && UNITY_EDITOR