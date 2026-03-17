#ifndef COMPAT_URP_INCLUDED
#define COMPAT_URP_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "Packages/com.unity.render-pipelines.core/Runtime/Lighting/ProbeVolume/ProbeVolume.hlsl"

#include "SCSS_CompatLightingData.hlsl"

// --------------------------------------------------------------------------
// Macros
// --------------------------------------------------------------------------
#define UnityObjectToClipPos(x) TransformObjectToHClip(x)
#define UnityObjectToWorldNormal(x) TransformObjectToWorldNormal(x)
#define UnityObjectToWorldDir(x) TransformObjectToWorldDir(x)
#define UnityWorldToObjectDir(x) TransformWorldToObjectDir(x)
#define UnityWorldSpaceViewDir(x) GetWorldSpaceViewDir(x)
#define _WorldSpaceCameraPos GetCameraPositionWS()

/*
// Todo: Enabling this causes some insane visual artifacts. 
#if defined(SCSS_USE_HALF_FLOAT) && (defined(UNITY_COMPILER_HLSL) || defined(UNITY_COMPILER_DXC))
#define UNITY_UNIFIED_SHADER_PRECISION_MODEL 1
#define TARGET_HALF // Require fp16 optimizations
#define half min16float
#define half2 min16float2
#define half3 min16float3
#define half4 min16float4
#define half2x2 min16float2x2
#define half3x3 min16float3x3
#define half4x4 min16float4x4
#define half2x3 min16float2x3
#define half2x4 min16float2x4
#define half3x2 min16float3x2
#define half3x4 min16float3x4
#define half4x2 min16float4x2
#define half4x3 min16float4x3
#define fixed min10float
#define fixed2 min10float2
#define fixed3 min10float3
#define fixed4 min10float4
#endif
*/

#define unity_ColorSpaceDielectricSpec kDielectricSpec
#define UNITY_PI PI
#define UNITY_INV_PI INV_PI
#define TransformStereoScreenSpaceTex(uv, w) UnityStereoTransformScreenSpaceTex(uv)
#define unity_ColorSpaceDouble half4(4.59479341h, 4.59479341h, 4.59479341h, 2.0h)
#ifdef UNITY_COLORSPACE_GAMMA
    #undef unity_ColorSpaceDouble
    #define unity_ColorSpaceDouble half4(2.0h, 2.0h, 2.0h, 2.0h)
#endif

#define fixed half
#define _LightShadowData _MainLightShadowParams

#ifdef UNITY_SHADOW_COORDS
    #undef UNITY_SHADOW_COORDS
#endif
#define UNITY_SHADOW_COORDS(idx) float4 shadowCoord : TEXCOORD##idx;

#ifdef UNITY_TRANSFER_SHADOW
    #undef UNITY_TRANSFER_SHADOW
#endif
#define UNITY_TRANSFER_SHADOW(o, uv) \
    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz); \
    o.shadowCoord = GetShadowCoord(vertexInput);

float3 _LightDirection;
float3 _LightPosition;

#define V2F_SHADOW_CASTER_NOPOS float3 positionWS_Shadow : TEXCOORD15;

#define TRANSFER_SHADOW_CASTER_NOPOS(o, opos) \
    opos = SCSS_GetShadowPositionHClip(v);

// Normal transformation matrix. 
// In BIRP it's the inverse transpose of Model-View. 
// In URP, we often want World space normals, so we use the inverse transpose of the Model matrix (which is the transpose of WorldToObject).
#ifndef UNITY_MATRIX_IT_MV
#define UNITY_MATRIX_IT_MV transpose(GetWorldToObjectMatrix())
#endif

// Handle tangent signs for mirrored meshes.
#undef unity_WorldTransformParams
#define unity_WorldTransformParams float4(0, 0, 0, GetOddNegativeScale())

#define SCSS_GET_NORMAL_MATRIX(mv) transpose(GetWorldToObjectMatrix())

#define SCSS_GET_SHADOW_COORD(i) i.shadowCoord
#define SCSS_GET_SHADOW_COORD_WS(posWS) TransformWorldToShadowCoord(posWS)

#define SCSS_LIGHT_ATTENUATION(destName, input, worldPos) \
    destName = MainLightRealtimeShadow(input.shadowCoord);

#define UNITY_INITIALIZE_OUTPUT(type, name) ZERO_INITIALIZE(type, name)

#define SHADOW_CASTER_FRAGMENT(i) return 0;

#define SAMPLE_RAW_DEPTH(uv) SampleSceneDepth(uv)
#define SCSS_SAMPLE_SCREEN_COLOR(uv) SampleSceneColor(uv)
#define UNITY_CALC_FOG_FACTOR_RAW(coord) ComputeFogFactor(coord)

#define GammaToLinearSpace(c) SRGBToLinear(c)
inline void correctedScreenShadowsForMSAA(float4 _ShadowCoord, inout float shadow) {}

#define TransformViewToProjection(v) mul((float3x3)GetViewToHClipMatrix(), v)
#ifndef UNITY_MATRIX_IT_MV
#define UNITY_MATRIX_IT_MV mul(GetWorldToViewMatrix(), GetObjectToWorldMatrix())
#endif

// Legacy Macro Mapping for SCSS_Input
#ifndef UNITY_DECLARE_TEX2D
#define UNITY_DECLARE_TEX2D(tex) TEXTURE2D(tex); SAMPLER(sampler##tex)
#endif
#ifndef UNITY_DECLARE_TEX2D_NOSAMPLER
#define UNITY_DECLARE_TEX2D_NOSAMPLER(tex) TEXTURE2D(tex)
#endif
#ifndef UNITY_SAMPLE_TEX2D
#define UNITY_SAMPLE_TEX2D(tex, uv) SAMPLE_TEXTURE2D(tex, sampler##tex, uv)
#endif
#ifndef FresnelTerm
#define FresnelTerm(f0, cosA) F_Schlick(f0, cosA)
#endif
#ifndef SmoothnessToPerceptualRoughness
#define SmoothnessToPerceptualRoughness(smoothness) (1.0 - smoothness)
#endif
#ifndef UNITY_SAMPLE_TEX2D_SAMPLER
#define UNITY_SAMPLE_TEX2D_SAMPLER(tex, samplertex, uv) SAMPLE_TEXTURE2D(tex, sampler##samplertex, uv)
#endif
#ifndef UNITY_SAMPLE_TEX2D_LOD
#define UNITY_SAMPLE_TEX2D_LOD(tex, uv, lod) SAMPLE_TEXTURE2D_LOD(tex, sampler##tex, uv, lod)
#endif
#ifndef UNITY_SAMPLE_TEX2D_SAMPLER_LOD
#define UNITY_SAMPLE_TEX2D_SAMPLER_LOD(tex, samplertex, uv, lod) SAMPLE_TEXTURE2D_LOD(tex, sampler##samplertex, uv, lod)
#endif

// --------------------------------------------------------------------------
// Implementation
// --------------------------------------------------------------------------

real4 ConvertAPVtoUnitySH(float3 L1_Axis, float L0_Axis) {
    return real4(L1_Axis.x, L1_Axis.y, L1_Axis.z, L0_Axis);
}

CompatSHData CGetSHData(float3 positionWS, float3 normalWS)
{
    CompatSHData d;
    ZERO_INITIALIZE(CompatSHData, d);
    d.isAPV = false;

    #if defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2)
    if (_EnableProbeVolumes)
    {
        APVSample apv = SampleAPV(positionWS, normalWS, 0xFFFFFFFF, 0);
        if (apv.status != APV_SAMPLE_STATUS_INVALID)
        {
            apv.Decode();
            d.SHAr = ConvertAPVtoUnitySH(apv.L1_R, apv.L0.r);
            d.SHAg = ConvertAPVtoUnitySH(apv.L1_G, apv.L0.g);
            d.SHAb = ConvertAPVtoUnitySH(apv.L1_B, apv.L0.b);
            d.isAPV = true;
        }
    }
    #endif

    if (!d.isAPV)
    {
        d.SHAr = unity_SHAr;
        d.SHAg = unity_SHAg;
        d.SHAb = unity_SHAb;
        d.SHBr = unity_SHBr;
        d.SHBg = unity_SHBg;
        d.SHBb = unity_SHBb;
        d.SHC  = unity_SHC;
    }
    return d;
}

float3 CGetIndirectSpecular(float3 reflectionDir, float3 positionWS, float2 screenUV, float perceptualRoughness, float occlusion)
{
    // Uses the 5-argument version to support Forward+ clustering if active
    return GlossyEnvironmentReflection(reflectionDir, positionWS, perceptualRoughness, occlusion, screenUV);
}

CompatLight CGetMainLight(float3 positionWS, float2 screenUV, float4 shadowCoord, float4 shadowMask, float occlusion, float atten)
{
    InputData id;
    ZERO_INITIALIZE(InputData, id);
    id.positionWS = positionWS;
    id.shadowMask = shadowMask;
    id.shadowCoord = shadowCoord;
    id.normalizedScreenSpaceUV = screenUV;

    // Create AO Factor. This handles URP's SSAO sampling using screenUV and combines it with material occlusion.
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(screenUV, occlusion);
    Light urpLight = GetMainLight(id, shadowMask, aoFactor);

    CompatLight l;
    l.direction = urpLight.direction;
    l.color = urpLight.color; // Includes AO and Cookie
    l.attenuation = urpLight.distanceAttenuation;
    l.shadowAttenuation = urpLight.shadowAttenuation;
    l.layerMask = urpLight.layerMask;
    return l;
}

CompatLightIterator CInitLightLoop(float2 screenUV, float3 positionWS)
{
    CompatLightIterator iter;
    ZERO_INITIALIZE(CompatLightIterator, iter);
    iter.index = 0;
    
    // USE_CLUSTER_LIGHT_LOOP is defined by URP's Core.hlsl if either _FORWARD_PLUS 
    // or _CLUSTER_LIGHT_LOOP are enabled via #pragma.
    #if USE_CLUSTER_LIGHT_LOOP
        // In clustered rendering, 'count' tracks the number of Directional Lights, which are processed BEFORE the grid.
        iter.count = min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS);
        
        ClusterIterator clusterIter = ClusterInit(screenUV, positionWS, 0);
        
        // Pack ClusterIterator into uint4 tileData
        iter.tileData.x = clusterIter.tileWordsOffset;
        iter.tileData.y = clusterIter.zBinWordsOffset;
        iter.tileData.z = clusterIter.tileMask;
        iter.tileData.w = clusterIter.entityIndexNextMax;
    #else
        // In standard Forward, 'count' is just the total active lights
        iter.count = GetAdditionalLightsCount();
    #endif
    
    return iter;
}


bool CGetNextLight(inout CompatLightIterator iter, float3 positionWS, float4 shadowMask, float occlusion, out CompatLight outLight)
{
    ZERO_INITIALIZE(CompatLight, outLight);
    int lightIndex = -1;
    bool foundValidLight = false;

    // We use a while loop here to automatically skip mixed/baked lights in Clustered rendering
    // without exiting the outer shader loop prematurely.
    while (!foundValidLight)
    {
        lightIndex = -1;

        #if USE_CLUSTER_LIGHT_LOOP
            // Phase 1: Directional Lights (Not in the cluster grid)
            if (iter.index < iter.count)
            {
                lightIndex = iter.index;
                iter.index++;
            }
            // Phase 2: Clustered Point/Spot Lights
            else
            {
                ClusterIterator clusterIter;
                clusterIter.tileWordsOffset = iter.tileData.x;
                clusterIter.zBinWordsOffset = iter.tileData.y;
                clusterIter.tileMask = iter.tileData.z;
                clusterIter.entityIndexNextMax = iter.tileData.w;

                uint entityIndex;
                if (ClusterNext(clusterIter, entityIndex)) 
                {
                    // CRITICAL: Offset the cluster index by the directional light count!
                    lightIndex = (int)entityIndex + URP_FP_DIRECTIONAL_LIGHTS_COUNT;
                    
                    // Save state back to iterator
                    iter.tileData.z = clusterIter.tileMask;
                    iter.tileData.w = clusterIter.entityIndexNextMax;
                }
                else
                {
                    return false; // Grid is empty, end of lighting loop
                }
            }
        #else
            // Standard Forward Lighting Loop
            if (iter.index < iter.count) 
            { 
                lightIndex = iter.index; 
                iter.index++; 
            }
            else
            {
                return false; // End of lighting loop
            }
        #endif

        if (lightIndex >= 0)
        {
            // Subtractive mixed lighting check for Clustered Forward
            // (If a light is baked, its alpha channel holds > 0. Skip it so we don't light the object twice).
            #if USE_CLUSTER_LIGHT_LOOP && defined(LIGHTMAP_ON) && defined(LIGHTMAP_SHADOW_MIXING)
                if (_AdditionalLightsColor[lightIndex].a > 0.0h)
                    continue; // Skip this iteration, find the next light immediately
            #endif

            foundValidLight = true;
        }
    }

    if (foundValidLight)
    {
        InputData id;
        ZERO_INITIALIZE(InputData, id);
        id.positionWS = positionWS;
        id.shadowMask = shadowMask;
        // id.normalizedScreenSpaceUV is unnecessary for GetAdditionalLight

        // Pass occlusion
        AmbientOcclusionFactor ao;
        ao.directAmbientOcclusion = 1.0;
        ao.indirectAmbientOcclusion = occlusion;

        Light urpLight = GetAdditionalLight((uint)lightIndex, id, shadowMask, ao);

        outLight.direction = urpLight.direction;
        outLight.color = urpLight.color;
        outLight.attenuation = urpLight.distanceAttenuation;
        outLight.shadowAttenuation = urpLight.shadowAttenuation;
        outLight.layerMask = urpLight.layerMask;
        
        return true;
    }
    
    return false;
}

inline float3 UnityWorldSpaceLightDir(in float3 worldPos)
{
    return _MainLightPosition.xyz - worldPos * _MainLightPosition.w;
}

float3 Unity_SafeNormalize(float3 inVec)
{
    float dp3 = dot(inVec, inVec);
    return dp3 == 0.0 ? float3(0,0,0) : inVec * rsqrt(dp3);
}

#define Unity_SafeNormalize SafeNormalize

half3 UnpackScaleNormal(half4 packednormal, half bumpScale)
{
    return UnpackNormalScale(packednormal, bumpScale);
}

#endif
