#ifndef COMPAT_BIRP_INCLUDED
#define COMPAT_BIRP_INCLUDED

#include "UnityCG.cginc"
#include "UnityLightingCommon.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"
#include "UnityGlobalIllumination.cginc"
#include "SCSS_CompatLightingData.hlsl"

// --------------------------------------------------------------------------
// Macros
// --------------------------------------------------------------------------
#define SAMPLE_RAW_DEPTH(uv) SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv)
#define UNITY_CALC_FOG_FACTOR_RAW(coord) UNITY_CALC_FOG_FACTOR(coord)
#define SCSS_SAMPLE_SCREEN_COLOR(uv) tex2D(_CameraOpaqueTexture, uv)// Wrappers
#define SCSS_GET_SHADOW_COORD(i) i._ShadowCoord
// #define SCSS_LIGHT_ATTENUATION(destName, input, worldPos) UNITY_LIGHT_ATTENUATION(destName, input, worldPos)
// Hijack UNITY_SHADOW_ATTENUATION directly to isolate shadows from distance and cookies.
#define SCSS_LIGHT_ATTENUATION(destName, input, worldPos) half destName = UNITY_SHADOW_ATTENUATION(input, worldPos);

#if defined(SCSS_USE_HALF_FLOAT) && (defined(UNITY_COMPILER_HLSL) || defined(UNITY_COMPILER_DXC))
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

// Safety net for things that can't be used in Standard's codepaths on weaker hardware
// Following implementation in Unity 2020's built-in pipeline

#if defined(SHADER_TARGET_SURFACE_ANALYSIS)
    // For surface shader code analysis pass, disable some features that don't affect inputs/outputs
    #undef UNITY_SPECCUBE_BOX_PROJECTION
    #undef UNITY_SPECCUBE_BLENDING
    #undef UNITY_USE_DITHER_MASK_FOR_ALPHABLENDED_SHADOWS
#elif SHADER_TARGET < 30
    #undef UNITY_SPECCUBE_BOX_PROJECTION
    #undef UNITY_SPECCUBE_BLENDING
    #undef UNITY_ENABLE_DETAIL_NORMALMAP
    #ifdef _PARALLAXMAP
        #undef _PARALLAXMAP
    #endif
#endif
#if (SHADER_TARGET < 30) || defined(SHADER_API_GLES)
    #undef UNITY_USE_DITHER_MASK_FOR_ALPHABLENDED_SHADOWS
#endif

#ifndef UNITY_SAMPLE_FULL_SH_PER_PIXEL
    // Lightmap UVs and ambient color from SHL2 are shared in the vertex to pixel interpolators. Do full SH evaluation in the pixel shader when static lightmap and LIGHTPROBE_SH is enabled.
    #define UNITY_SAMPLE_FULL_SH_PER_PIXEL (LIGHTMAP_ON && LIGHTPROBE_SH)

    // Shaders might fail to compile due to shader instruction count limit. Leave only baked lightmaps on SM20 hardware.
    #if UNITY_SAMPLE_FULL_SH_PER_PIXEL && (SHADER_TARGET < 25)
        #undef UNITY_SAMPLE_FULL_SH_PER_PIXEL
        #undef LIGHTPROBE_SH
    #endif
#endif

// --------------------------------------------------------------------------
// Helpers (Available to shaders, but NOT used by the API below)
// --------------------------------------------------------------------------

float4x4 GetObjectToWorldMatrix()
{
    return unity_ObjectToWorld;
}

// bgolus's method for "fixing" screen space directional shadows and anti-aliasing
// https://forum.unity.com/threads/fixing-screen-space-directional-shadows-and-anti-aliasing.379902/
// Searches the depth buffer for the depth closest to the current fragment to sample the shadow from.
// This reduces the visible aliasing.

void correctedScreenShadowsForMSAA(float4 _ShadowCoord, inout float shadow)
{
    #ifdef SHADOWS_SCREEN
    #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED

    float2 screenUV = _ShadowCoord.xy / _ShadowCoord.w;
    shadow = tex2D(_ShadowMapTexture, screenUV).r;

    float fragDepth = _ShadowCoord.z / _ShadowCoord.w;
    float depth_raw = tex2D(_CameraDepthTexture, screenUV).r;

    float depthDiff = abs(fragDepth - depth_raw);
    float diffTest = 1.0 / 100000.0;

    if (depthDiff > diffTest)
    {
        float2 texelSize = _CameraDepthTexture_TexelSize.xy;
        float4 offsetDepths = 0;

        float2 uvOffsets[5] = {
            float2(1.0, 0.0) * texelSize,
            float2(-1.0, 0.0) * texelSize,
            float2(0.0, 1.0) * texelSize,
            float2(0.0, -1.0) * texelSize,
            float2(0.0, 0.0)
        };

        offsetDepths.x = tex2D(_CameraDepthTexture, screenUV + uvOffsets[0]).r;
        offsetDepths.y = tex2D(_CameraDepthTexture, screenUV + uvOffsets[1]).r;
        offsetDepths.z = tex2D(_CameraDepthTexture, screenUV + uvOffsets[2]).r;
        offsetDepths.w = tex2D(_CameraDepthTexture, screenUV + uvOffsets[3]).r;

        float4 offsetDiffs = abs(fragDepth - offsetDepths);

        float diffs[4] = {offsetDiffs.x, offsetDiffs.y, offsetDiffs.z, offsetDiffs.w};

        int lowest = 4;
        float tempDiff = depthDiff;
        for (int i=0; i<4; i++)
        {
            if(diffs[i] < tempDiff)
            {
                tempDiff = diffs[i];
                lowest = i;
            }
        }

        shadow = tex2D(_ShadowMapTexture, screenUV + uvOffsets[lowest]).r;
    }
    #endif //SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED
    #endif //SHADOWS_SCREEN
}

#ifndef UNITY_STANDARD_BRDF_INCLUDED
half RoughnessToPerceptualRoughness(half roughness)
{
    return sqrt(roughness);
}

half RoughnessToPerceptualSmoothness(half roughness)
{
    return 1.0 - sqrt(roughness);
}

half PerceptualSmoothnessToRoughness(half perceptualSmoothness)
{
    return (1.0 - perceptualSmoothness) * (1.0 - perceptualSmoothness);
}

half PerceptualSmoothnessToPerceptualRoughness(half perceptualSmoothness)
{
    return (1.0 - perceptualSmoothness);
}

half PerceptualRoughnessToPerceptualSmoothness(half perceptualRoughness)
{
    return (1.0 - perceptualRoughness);
}
#endif // UNITY_STANDARD_BRDF_INCLUDED

float2 GetNormalizedScreenSpaceUV(float4 positionCS)
{
    float2 normalizedUV = positionCS.xy / _ScreenParams.xy;

    #if UNITY_UV_STARTS_AT_TOP
        normalizedUV.y = 1.0 - normalizedUV.y;
    #endif

    return normalizedUV;
}

float2 GetNormalizedScreenSpaceUV(float2 positionCS)
{
    return GetNormalizedScreenSpaceUV(float4(positionCS.x, positionCS.y, 0.0, 0.0));
}


// --------------------------------------------------------------------------
// Implementation
// --------------------------------------------------------------------------

CompatSHData CGetSHData(float3 positionWS, float3 normalWS)
{
    CompatSHData d;
    d.SHAr = unity_SHAr;
    d.SHAg = unity_SHAg;
    d.SHAb = unity_SHAb;
    d.SHBr = unity_SHBr;
    d.SHBg = unity_SHBg;
    d.SHBb = unity_SHBb;
    d.SHC  = unity_SHC;
    d.isAPV = false;
    return d;
}

float3 CGetIndirectSpecular(float3 reflectionDir, float3 positionWS, float2 screenUV, float perceptualRoughness, float occlusion)
{
    // BIRP requires setting up the GI Input struct to get box projection logic
    UnityGIInput d;
    UNITY_INITIALIZE_OUTPUT(UnityGIInput, d);
    d.worldPos = positionWS;
    d.worldViewDir = -1; // Not needed for indirect spec if reflUVW is set
    d.probeHDR[0] = unity_SpecCube0_HDR;
    d.probeHDR[1] = unity_SpecCube1_HDR;
    #if defined(UNITY_SPECCUBE_BOX_PROJECTION) || defined(UNITY_SPECCUBE_BLENDING)
    d.boxMin[0] = unity_SpecCube0_BoxMin;
    d.boxMin[1] = unity_SpecCube1_BoxMin;
    d.boxMax[0] = unity_SpecCube0_BoxMax;
    d.boxMax[1] = unity_SpecCube1_BoxMax;
    d.probePosition[0] = unity_SpecCube0_ProbePosition;
    d.probePosition[1] = unity_SpecCube1_ProbePosition;
    #endif

    Unity_GlossyEnvironmentData g;
    g.roughness = perceptualRoughness;
    g.reflUVW = reflectionDir;

    return UnityGI_IndirectSpecular(d, occlusion, g);
}

CompatLight CGetMainLight(float3 positionWS, float2 screenUV, float4 shadowCoord, float4 shadowMask, float occlusion, float atten)
{
    CompatLight l;
    bool isDirectional = _WorldSpaceLightPos0.w < 0.5;

    #if defined(UNITY_PASS_FORWARDADD)
    #else
    half4x4 unity_WorldToLight = (half4x4)0;
    #endif

    if (isDirectional) {
        l.direction = Unity_SafeNormalize(_WorldSpaceLightPos0.xyz);
        l.attenuation = 1.0;
    } else {
        float3 lightVec = _WorldSpaceLightPos0.xyz - positionWS;
        l.direction = Unity_SafeNormalize(lightVec);

        float distanceSquare = dot(lightVec, lightVec);
        half range = length(unity_WorldToLight._m02_m12_m22);
        float attenUV = sqrt(distanceSquare) / (1.0 / range);
        float unityLightFalloff = saturate(1.0 / (1.0 + 25.0 * attenUV * attenUV) * saturate((1.0 - attenUV) * 5.0));
        l.attenuation = unityLightFalloff;
    }

    l.color = _LightColor0.rgb;

    #if defined(DIRECTIONAL_COOKIE)
        float2 dirCookieCoord = mul(unity_WorldToLight, float4(positionWS, 1)).xy;
        half dirCookie = tex2D(_LightTexture0, dirCookieCoord).w;
        l.color *= dirCookie;
    #endif

    #if defined(SPOT)
        float4 cookieCoord = mul(unity_WorldToLight, float4(positionWS, 1));
        half spotCookie = tex2D(_LightTexture0, cookieCoord.xy / cookieCoord.w + 0.5).w;
        l.color *= (cookieCoord.z > 0) ? spotCookie : 0.0;
    #endif

    #if defined(POINT_COOKIE)
        float3 pointCookieCoord = mul(unity_WorldToLight, float4(positionWS, 1)).xyz;
        half pointCookie = texCUBE(_LightTexture0, pointCookieCoord).w;
        l.color *= pointCookie;
    #endif

    l.shadowAttenuation = atten; // Baked result of UNITY_LIGHT_ATTENUATION
    l.shadowStrength = 1.0 - _LightShadowData.r;
    l.layerMask = 0;
    return l;
}

CompatLightIterator CInitLightLoop(float2 screenUV, float3 positionWS)
{
    CompatLightIterator iter;
    iter.index = 0;

    #if (defined(UNITY_PASS_FORWARDBASE) && defined(VERTEXLIGHT_ON))
        iter.count = 4; // Loop 4 Vertex Lights
    #else
        iter.count = 0; // ForwardAdd handles lights via passes, so loop is 0
    #endif

    // Not used: URP only.
    iter.instanceID = 0;
    iter.tileData = 0;
    return iter;
}

bool CGetNextLight(inout CompatLightIterator iter, float3 positionWS, float4 shadowMask, float occlusion, out CompatLight outLight)
{
    outLight = (CompatLight) 0;

    #if (defined(UNITY_PASS_FORWARDBASE) && defined(VERTEXLIGHT_ON))
    while (iter.index < iter.count)
    {
        int i = iter.index;
        iter.index++;

        if (any(unity_LightColor[i].rgb))
        {
            float3 lightPos = float3(unity_4LightPosX0[i], unity_4LightPosY0[i], unity_4LightPosZ0[i]);
            float3 toLight = lightPos - positionWS;
            float lengthSq = dot(toLight, toLight);
            float attenSq = unity_4LightAtten0[i];

            outLight.color = unity_LightColor[i].rgb;
            outLight.direction = Unity_SafeNormalize(toLight);

            // Unity Vertex Light Attenuation with pop-in fix. Thanks d4rkplay3r and error.mdl!
            // unity_4LightAtten0 contains (25.0 / range^2).
            // Standard Curve: 1.0 / (1.0 + 25.0 * (d/r)^2)
            float atten = 1.0 / (1.0 + lengthSq * attenSq);

            // Cutoff Curve: 1.0 - (25.0 * (d/r)^2) / 25.0  -> 1.0 - (d/r)^2
            // This ensures attenuation hits exactly 0 at d = r.
            float cutoff = saturate(1.0 - (lengthSq * attenSq / 25.0));

            // Combine for smooth falloff without popping
            outLight.attenuation = min(atten, cutoff * cutoff);
            outLight.shadowAttenuation = 1.0;
            outLight.shadowStrength = 0.0;
            outLight.layerMask = 0;
            return true;
        }
    }
    #endif
    return false;
}

#endif
