#ifndef COMPAT_LIGHTING_DATA_INCLUDED
#define COMPAT_LIGHTING_DATA_INCLUDED

// --------------------------------------------------------------------------
// Precision & Type Compatibility
// --------------------------------------------------------------------------
#if !defined(real)
    #if defined(SHADER_API_MOBILE) || defined(SHADER_API_SWITCH)
        #define real half
        #define real3 half3
        #define real4 half4
    #else
        #define real float
        #define real3 float3
        #define real4 float4
    #endif
#endif

// --------------------------------------------------------------------------
// Data Containers
// --------------------------------------------------------------------------

struct CompatSHData
{
    real4 SHAr;
    real4 SHAg;
    real4 SHAb;
    real4 SHBr;
    real4 SHBg;
    real4 SHBb;
    real4 SHC;
    bool isAPV;
};

struct CompatLight
{
    float3 direction;         // Normalized L
    float3 color;             // Intensity included
    half  attenuation;        // Distance * Angle falloff
    half  shadowAttenuation;  // Realtime Shadows (0..1)
    half  shadowStrength;     // Shadow strength
    uint   layerMask;         // URP Light Layers
};

struct CompatLightIterator
{
    int index;
    int count;
    uint instanceID;
    uint4 tileData;
};

// --------------------------------------------------------------------------
// Math Helpers (Available to shaders, but NOT used by the API below)
// --------------------------------------------------------------------------

// Lagarde and de Rousiers 2014, "Moving Frostbite to PBR"
float SpecularAO_Lagarde(float NoV, float visibility, float roughness)
{
    return saturate(pow(NoV + visibility, exp2(-16.0 * roughness - 1.0)) - 1.0 + visibility);
}

// --------------------------------------------------------------------------
// API Prototypes
// --------------------------------------------------------------------------

// Fetch SH data. Position and Normal required for APV (URP).
CompatSHData CGetSHData(float3 positionWS, float3 normalWS);

// Fetch Indirect Specular (Reflections). ScreenUV required for Forward+ clustering (URP). Occlusion required for URP mixing.
float3 CGetIndirectSpecular(float3 reflectionDir, float3 positionWS, float2 screenUV, float perceptualRoughness, float occlusion);

// Fetch Main Light. ScreenUV and Occlusion required for SSAO/AO application (URP).
CompatLight CGetMainLight(float3 positionWS, float2 screenUV, float4 shadowCoord, float4 shadowMask, float occlusion, float atten);

// Initialize Light Loop. ScreenUV required for Forward+ clustering (URP).
CompatLightIterator CInitLightLoop(float2 screenUV, float3 positionWS);

// Get Next Light. Occlusion required for SSAO/AO application (URP).
bool CGetNextLight(inout CompatLightIterator iter, float3 positionWS, float4 shadowMask, float occlusion, out CompatLight outLight);

#endif
