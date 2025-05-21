#ifndef SCSS_UNITYGI_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_UNITYGI_INCLUDED

#include "UnityLightingCommon.cginc"
#include "UnityImageBasedLighting.cginc"
#include "UnityGlobalIllumination.cginc"
#include "SCSS_Lighting.cginc"

#ifndef FLT_EPS
#define FLT_EPS 1e-5
#endif 

//------------------------------------------------------------------------------

// https://github.com/z3y/shaders/blob/d52e2831a82ffd7dba0a070edf6fad6b1a5d4ed3/Shaders/ShaderLibrary/EnvironmentBRDF.cginc
// Based on z3y's implementation of Filament's indirect specular distribution
Texture2D _DFG;
SamplerState sampler_DFG;

half3 PrefilteredDFG_LUT(half NoV, half perceptualRoughness)
{
    return _DFG.SampleLevel(sampler_DFG, float2(NoV, perceptualRoughness), 0);
}

half3 specularDFG(half3 dfg, half3 f0, bool isCloth = false)
{
    if (isCloth)
    {
        return f0 * dfg.zzz;
    } 
    return lerp(dfg.xxx, dfg.yyy, f0);
}

half3 specularDFGEnergyCompensation(half3 dfg, half3 f0, bool isCloth = false)
{
    if (isCloth)
    {
        return 1.0;
    } 
    return 1.0 + f0 * (1.0 / dfg.y - 1.0);
}

float SpecularAO_Lagarde(float NoV, float visibility, float roughness) {
    // Lagarde and de Rousiers 2014, "Moving Frostbite to PBR"
    return saturate(pow(NoV + visibility, exp2(-16.0 * roughness - 1.0)) - 1.0 + visibility);
}

bool isReflectionProbeActive()
{
#ifndef SHADER_TARGET_SURFACE_ANALYSIS // Required to use GetDimensions
    float height, width;
    unity_SpecCube0.GetDimensions(width, height);
    return !(height * width < 32);
#endif
    return 1;
}

inline UnityGI UnityGlobalIllumination_SCSS (UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
{
    float localNoV = max(0.002, dot(normalWorld, data.worldViewDir));
    occlusion = SpecularAO_Lagarde(localNoV, occlusion, glossIn.roughness);
    UnityGI o_gi = UnityGI_Base(data, occlusion, normalWorld);
    SHdata sh = SampleProbes(data.worldPos);
    float3 dominantDir;
    o_gi.indirect.diffuse = SampleIrradiance(normalWorld, sh, dominantDir);
    o_gi.indirect.specular = isReflectionProbeActive()
    ? UnityGI_IndirectSpecular(data, occlusion, glossIn)
    : o_gi.indirect.diffuse;
    return o_gi;
}

UnityGI GetUnityGI(float3 lightColor, float3 lightDirection, float3 normalDirection,float3 viewDirection, 
float3 viewReflectDirection, float attenuation, float occlusion, float roughness, float3 worldPos){
    UnityLight light;
    light.color = lightColor;
    light.dir = lightDirection;
    light.ndotl = max(0.0h,dot( normalDirection, lightDirection));
    UnityGIInput d = (UnityGIInput) 0;
    d.light = light;
    d.worldPos = worldPos;
    d.worldViewDir = viewDirection;
    d.atten = attenuation;
    d.ambient = 0.0h;

#ifdef UNITY_SPECCUBE_BOX_PROJECTION
    d.boxMax[0] = unity_SpecCube0_BoxMax;
    d.boxMax[1] = unity_SpecCube1_BoxMax;
    d.probePosition[0] = unity_SpecCube0_ProbePosition;
    d.probePosition[1] = unity_SpecCube1_ProbePosition;
#endif

#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION) || defined(UNITY_ENABLE_REFLECTION_BUFFERS)
    d.boxMin[0] = unity_SpecCube0_BoxMin;
    d.boxMin[1] = unity_SpecCube1_BoxMin;
#endif

    d.probeHDR[0] = unity_SpecCube0_HDR;
    d.probeHDR[1] = unity_SpecCube1_HDR;

    Unity_GlossyEnvironmentData ugls_en_data;
    ugls_en_data.roughness = roughness;
    ugls_en_data.reflUVW = viewReflectDirection;
    UnityGI gi = UnityGlobalIllumination_SCSS(d, occlusion, normalDirection, ugls_en_data );
    return gi;
}

#endif // SCSS_UNITYGI_INCLUDED