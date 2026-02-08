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
#define TRANSFER_SHADOW_CASTER_NOPOS(o, opos) \
    float3 positionWS = TransformObjectToWorld(v.vertex.xyz); \
    float3 normalWS = TransformObjectToWorldNormal(v.normal); \
    positionWS = ApplyShadowBias(positionWS, normalWS, _LightDirection); \
    opos = TransformWorldToHClip(positionWS); \
    if (UNITY_REVERSED_Z) opos.z = min(opos.z, opos.w * UNITY_NEAR_CLIP_VALUE); \
    else opos.z = max(opos.z, opos.w * UNITY_NEAR_CLIP_VALUE); \
    o.pos = opos;

#define SHADOW_CASTER_FRAGMENT(i) return 0;

#define SAMPLE_RAW_DEPTH(uv) SampleSceneDepth(uv)
#define SCSS_SAMPLE_SCREEN_COLOR(uv) SampleSceneColor(uv)
#define UNITY_CALC_FOG_FACTOR_RAW(coord) ComputeFogFactor(coord)

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
            d.SHAr = ConvertAPVtoUnitySH(apv.L1[0], apv.L0.r);
            d.SHAg = ConvertAPVtoUnitySH(apv.L1[1], apv.L0.g);
            d.SHAb = ConvertAPVtoUnitySH(apv.L1[2], apv.L0.b);
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
    iter.index = 0;
    #if USE_FORWARD_PLUS
        iter.count = URP_FP_DIRECTIONAL_LIGHTS_COUNT;
        iter.tileData = ClusterInit(screenUV, positionWS, 0);
    #else
        iter.count = GetAdditionalLightsCount();
    #endif
    return iter;
}

bool CGetNextLight(inout CompatLightIterator iter, float3 positionWS, float4 shadowMask, float occlusion, out CompatLight outLight)
{
    int lightIndex = -1;
    #if USE_FORWARD_PLUS
        if (ClusterNext(iter.tileData, iter.instanceID)) lightIndex = iter.instanceID;
    #else
        if (iter.index < iter.count) { lightIndex = iter.index; iter.index++; }
    #endif

    if (lightIndex >= 0)
    {
        InputData id;
        ZERO_INITIALIZE(InputData, id);
        id.positionWS = positionWS;

        // Additional lights generally don't support SSAO in the same way, but we pass occlusion
        AmbientOcclusionFactor ao;
        ao.directAmbientOcclusion = 1;
        ao.indirectAmbientOcclusion = occlusion;

        Light urpLight = GetAdditionalLight(lightIndex, id, shadowMask, ao);

        outLight.direction = urpLight.direction;
        outLight.color = urpLight.color;
        outLight.attenuation = urpLight.distanceAttenuation;
        outLight.shadowAttenuation = urpLight.shadowAttenuation;
        outLight.layerMask = urpLight.layerMask;
        return true;
    }
    return false;
}

#endif
