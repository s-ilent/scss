#ifndef SCSS_INPUT_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_INPUT_INCLUDED

#include "SCSS_Utils.cginc"
#include "SCSS_Attributes.cginc"

//---------------------------------------
// Keyword squeezing.

#if (defined(_DETAIL_MULX2) || defined(_DETAIL_MUL) || defined(_DETAIL_ADD) || defined(_DETAIL_LERP))
    #define _DETAIL
#endif

#if (defined(_METALLICGLOSSMAP) || defined(_SPECGLOSSMAP) || defined(_SPEC_GLINTY))
    #define _SPECULAR
#else
    #define _SPECULARHIGHLIGHTS_OFF
    #define _GLOSSYREFLECTIONS_OFF
#endif

#if (defined(_SUNDISK_NONE))
    #define _SUBSURFACE
#endif

//---------------------------------------
// Utility functions.
#if defined(SHADER_API_GLES) || defined(SHADER_API_GLCORE) || defined(SHADER_API_GLES3)
    #ifndef UNITY_SAMPLE_TEX2D_SAMPLER_LOD
        #define UNITY_SAMPLE_TEX2D_SAMPLER_LOD(tex, samplertex, coord, lod) textureLod(tex, coord, lod)
    #endif
    #ifndef UNITY_SAMPLE_TEX2D_LOD
        #define UNITY_SAMPLE_TEX2D_LOD(tex, coord, lod) textureLod(tex, coord, lod)
    #endif
#else
    #ifndef UNITY_SAMPLE_TEX2D_SAMPLER_LOD
        #define UNITY_SAMPLE_TEX2D_SAMPLER_LOD(tex,samplertex,coord,lod) tex.SampleLevel (sampler##samplertex,coord,lod)
    #endif
    #ifndef UNITY_SAMPLE_TEX2D_LOD
        #define UNITY_SAMPLE_TEX2D_LOD(tex,coord,lod) tex.SampleLevel (sampler##tex,coord,lod)
    #endif
#endif

// Disable PBR dielectric setup in cel specular mode.
#if defined(_SPECGLOSSMAP)
    #undef unity_ColorSpaceDielectricSpec
    #define unity_ColorSpaceDielectricSpec half4(0, 0, 0, 1)
#endif


// =========================================================================
// TEXTURES AND SAMPLERS
// =========================================================================
// In order to support URP's SRP Batcher, Textures and SamplerStates
// must be declared strictly outside of the UnityPerMaterial CBuffer.

UNITY_DECLARE_TEX2D(_MainTex);
UNITY_DECLARE_TEX2D_NOSAMPLER(_ColorMask);
UNITY_DECLARE_TEX2D_NOSAMPLER(_BumpMap);

#if defined(SCSS_IS_URP)
    // Forces memory consistency for the SRP Batcher
    #define SCSS_ENABLE_ALL_PROPS 1
#endif

#if defined(_BACKFACE) || defined(SCSS_ENABLE_ALL_PROPS)
UNITY_DECLARE_TEX2D_NOSAMPLER(_MainTexBackface); // Texel size assumed same as _MainTex.
#endif

// Workaround for shadow compiler error.
#if defined(SCSS_SHADOWS_INCLUDED)
UNITY_DECLARE_TEX2D(_ClippingMask);
#else
UNITY_DECLARE_TEX2D_NOSAMPLER(_ClippingMask);
#endif

#if defined(_EMISSION) || defined(SCSS_ENABLE_ALL_PROPS)
UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap);
UNITY_DECLARE_TEX2D(_DetailEmissionMap);
#endif

#if defined(_EMISSION_2ND) || defined(SCSS_ENABLE_ALL_PROPS)
UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap2nd);
UNITY_DECLARE_TEX2D(_DetailEmissionMap2nd);
#endif

#if defined(_AUDIOLINK) || defined(SCSS_ENABLE_ALL_PROPS)
UNITY_DECLARE_TEX2D_NOSAMPLER(_AudiolinkMaskMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_AudiolinkSweepMap);
#endif

#if defined(_SPECULAR) || defined(SCSS_ENABLE_ALL_PROPS)
UNITY_DECLARE_TEX2D_NOSAMPLER(_SpecGlossMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_SpecIridescenceRamp);
#endif

#if defined(SCSS_CROSSTONE) || defined(SCSS_ENABLE_ALL_PROPS)
UNITY_DECLARE_TEX2D_NOSAMPLER(_1st_ShadeMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_2nd_ShadeMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_ShadingGradeMap);
#endif

#if !defined(SCSS_CROSSTONE) || defined(SCSS_ENABLE_ALL_PROPS)
SamplerState _RampLinearClampSampler;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ShadowMask);
UNITY_DECLARE_TEX2D_NOSAMPLER(_Ramp);
#endif

// Note: Sampler is declared in Utils
UNITY_DECLARE_TEX2D_NOSAMPLER(_MatcapMask);
UNITY_DECLARE_TEX2D_NOSAMPLER(_Matcap1);
UNITY_DECLARE_TEX2D_NOSAMPLER(_Matcap2);
UNITY_DECLARE_TEX2D_NOSAMPLER(_Matcap3);
UNITY_DECLARE_TEX2D_NOSAMPLER(_Matcap4);

#if defined(_SUBSURFACE) || defined(SCSS_ENABLE_ALL_PROPS)
UNITY_DECLARE_TEX2D_NOSAMPLER(_ThicknessMap);
#endif

#if defined(_HATCHING) || defined(SCSS_ENABLE_ALL_PROPS)
sampler2D _HatchingTex;
#endif

UNITY_DECLARE_TEX2D_NOSAMPLER(_DetailAlbedoMask);

#if defined(_DETAIL) || defined(SCSS_ENABLE_ALL_PROPS)
// Detail maps need seperate samplers, in case the user specifies clamp mode.
sampler2D _DetailMap1;
sampler2D _DetailMap2;
sampler2D _DetailMap3;
sampler2D _DetailMap4;
#endif

#if (defined(SHADER_STAGE_VERTEX) || defined(SHADER_STAGE_GEOMETRY)) || defined(SCSS_ENABLE_ALL_PROPS)
    // Outline options
    #if defined(SCSS_OUTLINE) || defined(SCSS_ENABLE_ALL_PROPS)
    UNITY_DECLARE_TEX2D(_OutlineMask);
    #endif

    // Fur options
    #if defined(SCSS_FUR) || defined(SCSS_ENABLE_ALL_PROPS)
    UNITY_DECLARE_TEX2D(_FurMask);
    #endif
#endif

#if defined(SCSS_FUR) || defined(SCSS_ENABLE_ALL_PROPS)
UNITY_DECLARE_TEX2D_NOSAMPLER(_FurNoise);
#endif


// =========================================================================
// MATERIAL PROPERTIES (CBUFFER)
// =========================================================================

// In URP, the SRP Batcher requires all material properties (floats, vectors)
// to be defined within a strictly structured CBuffer called UnityPerMaterial.
// Note that this block can't define unused properties, so SCSS_ENABLE_ALL_PROPS
// does not affect SCSS_CROSSTONE.

#if defined(SCSS_IS_URP)
CBUFFER_START(UnityPerMaterial)
#endif

// --- Main Textures & Tints ---
half4 _Color;
half4 _MainTex_ST;
half4 _MainTex_TexelSize;
half4 _ClippingMask_ST;

#if defined(_BACKFACE) || defined(SCSS_ENABLE_ALL_PROPS)
half4 _ColorBackface;
#endif

half _BumpScale;
half _Cutoff;
half _AlphaSharp;
half _UVSec;
half _DetailNormalMapUVSec;
half _SpecularDetailMaskUVSec;
half _AlbedoAlphaMode;
half _Tweak_Transparency;

half _ToggleHueControls;
half _ShiftHue;
half _ShiftSaturation;
half _ShiftValue;

half4 _LightSkew;
half _PixelSampleMode;
half _VertexColorType;
half _VertexColorRType;
half _VertexColorGType;
half _VertexColorBType;
half _VertexColorAType;

half _DiffuseGeomShadowFactor;
half _LightWrappingCompensationFactor;
half _IndirectShadingType;

// --- Emission ---
half4 _EmissionColor;
half _EmissionRimPower;
half _EmissionMode;

#if defined(_EMISSION) || defined(SCSS_ENABLE_ALL_PROPS)
half4 _EmissionMap_ST;
half4 _EmissionMap_TexelSize;
half _EmissionUVSec;
half4 _DetailEmissionMap_ST;
half4 _DetailEmissionMap_TexelSize;
half _DetailEmissionUVSec;
half4 _EmissionDetailParams;
#endif

half4 _EmissionColor2nd;
half _EmissionRimPower2nd;
half _EmissionMode2nd;

#if defined(_EMISSION_2ND) || defined(SCSS_ENABLE_ALL_PROPS)
half4 _EmissionMap2nd_ST;
half4 _EmissionMap2nd_TexelSize;
half _EmissionUVSec2nd;
half4 _DetailEmissionMap2nd_ST;
half4 _DetailEmissionMap2nd_TexelSize;
half _DetailEmissionUVSec2nd;
half4 _EmissionDetailParams2nd;
#endif

half _UseEmissiveLightSense;
half _EmissiveLightSenseStart;
half _EmissiveLightSenseEnd;
// Not implemented yet
// half _UseEmissiveLightSense2nd;
// half _EmissiveLightSenseStart2nd;
// half _EmissiveLightSenseEnd2nd;

// --- AudioLink ---
#if defined(_AUDIOLINK) || defined(SCSS_ENABLE_ALL_PROPS)
half4 _AudiolinkMaskMap_ST;
half4 _AudiolinkSweepMap_ST;
half _AudiolinkIntensity;
half _AudiolinkMaskMapUVSec;
half _AudiolinkSweepMapUVSec;
// Not implemented yet
// half _UseAudiolinkLightSense;
// half _AudiolinkLightSenseStart;
// half _AudiolinkLightSenseEnd;
#endif

// --- Specular ---
// _SpecColor is defined deep in Standard/UnityCG land, in UnityLightingCommon.cginc
// For easy compatibility with Standard, we don't rename it.
// This is a safety for the shadowcaster pass, which does not include it.
#if defined(SCSS_ENABLE_ALL_PROPS)
    half4 _SpecColor; // Must be inside CBUFFER for URP SRP Batcher
#else
    #ifndef UNITY_LIGHTING_COMMON_INCLUDED
    half4 _SpecColor;
    #endif
#endif

#if defined(_SPECULAR) || defined(SCSS_ENABLE_ALL_PROPS)
half _UseMetallic;
half _SpecularType;
half _Smoothness;
half _UseEnergyConservation;
half _Anisotropy;
half _CelSpecularSoftness;
half _CelSpecularSteps;
half _SpecularGlintSize;
half _SpecularGlintDensity;
half _SpecularHighlights;
half _GlossyReflections;
half4 _SpecIridescenceRamp_TexelSize;
#else
// Default to zero
half _SpecularType;
half _UseEnergyConservation;
half _Anisotropy; // Can not be removed yet.
#endif

// --- CrossTone ---
#if defined(SCSS_CROSSTONE)
half4 _1st_ShadeColor;
half4 _2nd_ShadeColor;
half _1st_ShadeColor_Step;
half _1st_ShadeColor_Feather;
half _2nd_ShadeColor_Step;
half _2nd_ShadeColor_Feather;

half _Tweak_ShadingGradeMapLevel;
half _CrosstoneToneSeparation;
half _Crosstone2ndSeparation;

half4 _ShadowBorderColor;
half _ShadowBorderRange;
#endif

// --- Ramped (Non-Crosstone) ---
#if !defined(SCSS_CROSSTONE)
half4 _ShadowMask_ST;
half _LightRampType;
half4 _ShadowMaskColor;
half _ShadowMaskType;
half _IndirectLightingBoost;
half _Shadow;
half _ShadowLift;
#endif

// --- Fresnel ---
half _UseFresnel;
half _UseFresnelLightMask;
half4 _FresnelTint;
half _FresnelWidth;
half _FresnelStrength;
half _FresnelLightMask;
half4 _FresnelTintInv;
half _FresnelWidthInv;
half _FresnelStrengthInv;
half4 _CustomFresnelColor;

// --- Matcaps ---
half4 _MatcapMask_ST;
half4 _Matcap1_ST;
half4 _Matcap2_ST;
half4 _Matcap3_ST;
half4 _Matcap4_ST;

half _UseMatcap;
half _Matcap1Strength;
half _Matcap2Strength;
half _Matcap3Strength;
half _Matcap4Strength;
half _Matcap1Blend;
half _Matcap2Blend;
half _Matcap3Blend;
half _Matcap4Blend;
half4 _Matcap1Tint;
half4 _Matcap2Tint;
half4 _Matcap3Tint;
half4 _Matcap4Tint;

// --- Subsurface ---
#if defined(_SUBSURFACE) || defined(SCSS_ENABLE_ALL_PROPS)
half _UseSubsurfaceScattering;
half _ThicknessMapPower;
half _ThicknessMapInvert;
half3 _SSSCol;
half _SSSIntensity;
half _SSSPow;
half _SSSDist;
half _SSSAmbient;
#endif

// --- Hatching ---
#if defined(_HATCHING) || defined(SCSS_ENABLE_ALL_PROPS)
half _HatchingScale;
half _HatchingMovementFPS;
half _HatchingShadingAdd;
half _HatchingShadingMul;
half _HatchingRimAdd;
half _HatchingAlbedoMul;
#endif

// --- Alpha Fresnel ---
half _UseAlphaFresnel;
half _AlphaFresnelWidth;
half _AlphaFresnelSharpness;
half _AlphaFresnelStrength;
half _AlphaFresnelInvert;
half _AlphaFresnelThreshold;

// --- Animation ---
half _UseAnimation;
half _AnimationSpeed;
int _TotalFrames;
int _FrameNumber;
int _Columns;
int _Rows;

// --- AudioLink ---
#if defined(SCSS_USE_AUDIOLINK) || defined(SCSS_ENABLE_ALL_PROPS)
half _alModeR;
half _alModeG;
half _alModeB;
half _alModeA;

half _alBandR;
half _alBandG;
half _alBandB;
half _alBandA;

half4 _alColorR;
half4 _alColorG;
half4 _alColorB;
half4 _alColorA;

half _alTimeRangeR;
half _alTimeRangeG;
half _alTimeRangeB;
half _alTimeRangeA;

half _alUseFallback;
half _alFallbackBPM;
#endif

// --- Vanishing ---
half _UseVanishing;
half _VanishingStart;
half _VanishingEnd;

// --- Proximity Shadow ---
half _UseProximityShadow;
half _ProximityShadowDistance;
half _ProximityShadowDistancePower;
half4 _ProximityShadowFrontColor;
half4 _ProximityShadowBackColor;

// --- Inventory ---
half _UseInventory;
half _InventoryUVSec;
#if (defined(SHADER_STAGE_VERTEX) || defined(SHADER_STAGE_GEOMETRY)) || defined(SCSS_ENABLE_ALL_PROPS)
half _InventoryStride;
half _InventoryItem01Animated;
half _InventoryItem02Animated;
half _InventoryItem03Animated;
half _InventoryItem04Animated;
half _InventoryItem05Animated;
half _InventoryItem06Animated;
half _InventoryItem07Animated;
half _InventoryItem08Animated;
half _InventoryItem09Animated;
half _InventoryItem10Animated;
half _InventoryItem11Animated;
half _InventoryItem12Animated;
half _InventoryItem13Animated;
half _InventoryItem14Animated;
half _InventoryItem15Animated;
half _InventoryItem16Animated;
#endif

// --- Light adjustment ---
half _LightingCalculationType;
half _LightMultiplyAnimated;
half _LightClampAnimated;
half _LightAddAnimated;

// --- Contact shadows ---
#if defined(_CONTACTSHADOWS) || defined(SCSS_ENABLE_ALL_PROPS)
half _ContactShadowDistance;
uint _ContactShadowSteps;
#endif

// --- Detail maps ---
#if defined(_DETAIL) || defined(SCSS_ENABLE_ALL_PROPS)
half4 _DetailMap1_ST; half4 _DetailMap1_TexelSize;
half4 _DetailMap2_ST; half4 _DetailMap2_TexelSize;
half4 _DetailMap3_ST; half4 _DetailMap3_TexelSize;
half4 _DetailMap4_ST; half4 _DetailMap4_TexelSize;
half _DetailMap1UV; half _DetailMap1Type; half _DetailMap1Blend; half _DetailMap1Strength;
half _DetailMap2UV; half _DetailMap2Type; half _DetailMap2Blend; half _DetailMap2Strength;
half _DetailMap3UV; half _DetailMap3Type; half _DetailMap3Blend; half _DetailMap3Strength;
half _DetailMap4UV; half _DetailMap4Type; half _DetailMap4Blend; half _DetailMap4Strength;
#endif

// --- SDF options ---
half _SDFMode;
half _SDFSmoothness;
int _SDFFrontVector;
int _SDFRightVector;

// --- Outline options ---
#if (defined(SHADER_STAGE_VERTEX) || defined(SHADER_STAGE_GEOMETRY)) || defined(SCSS_ENABLE_ALL_PROPS)
    #if defined(SCSS_OUTLINE) || defined(SCSS_ENABLE_ALL_PROPS)
    half _OutlineZPush;
    half _outline_width;
    half _OutlineCalculationMode;
    half _OutlineNearDistance;
    half _OutlineFarDistance;
    #endif

    // --- Fur options ---
    #if defined(SCSS_FUR) || defined(SCSS_ENABLE_ALL_PROPS)
    half _FurLength;
    half _FurMode;
    half _FurLayerCount;
    half _FurRandomization;
    half _FurGravity;
    #endif
#endif

#if defined(SCSS_OUTLINE) || defined(SCSS_ENABLE_ALL_PROPS)
half _OutlineMode;
half4 _outline_color;
#endif

#if defined(SCSS_FUR) || defined(SCSS_ENABLE_ALL_PROPS)
half4 _FurNoise_ST;
half _FurThickness;
#endif

#if defined(SCSS_IS_URP)
CBUFFER_END
#endif

// Fallbacks for when feature blocks are stripped from non-SRP paths
#if !defined(SCSS_OUTLINE) && !defined(SCSS_ENABLE_ALL_PROPS)
static const half4 _outline_color = half4(0,0,0,0);
#endif
#if !defined(SCSS_CROSSTONE)
static const half _CrosstoneToneSeparation = half(0);
static const half _Crosstone2ndSeparation = half(0);
#endif


// =========================================================================
// SHADER LOGIC & STRUCTS
// =========================================================================

#if defined(_AUDIOLINK)
#include "SCSS_AudioLink.cginc"
#endif

struct SCSS_AnimData
{
    half speed;
    int totalFrames;
    int offset;
    int columns;
    int rows;
};

// For main animation params.
SCSS_AnimData initialiseAnimParam()
{
    SCSS_AnimData anim = (SCSS_AnimData)0;
    anim.speed = _AnimationSpeed;
    anim.totalFrames = _TotalFrames;
    anim.offset = _FrameNumber;
    anim.columns = _Columns;
    anim.rows = _Rows;
    return anim;
};

float2 AnimateTexcoords(float2 texcoord, SCSS_AnimData anim)
{
    float2 spriteUV = texcoord;
    if (_UseAnimation)
    {
        float currentFrame = anim.offset + frac(_Time[0] * anim.speed) * anim.totalFrames;

        float frame = floor(clamp(currentFrame, 0, anim.totalFrames));

        float2 offPerFrame = float2((1 / (float)anim.columns), (1 / (float)anim.rows));

        float2 spriteSize = texcoord * offPerFrame;

        float2 currentSprite =
                float2(frame * offPerFrame.x,  1 - offPerFrame.y);

        float rowIndex;
        float mod = modf(frame / (float)anim.columns, rowIndex);
        currentSprite.y -= rowIndex * offPerFrame.y;
        currentSprite.x -= rowIndex * anim.columns * offPerFrame.x;

        spriteUV = (spriteSize + currentSprite);
    }
    return spriteUV;
}

void applyVanishing (inout half alpha) {
    const float3 baseWorldPos = GetObjectToWorldMatrix()._m03_m13_m23;
    float closeDist = distance(_WorldSpaceCameraPos, baseWorldPos);
    half vanishing = saturate(lerpstep(_VanishingStart, _VanishingEnd, closeDist));
    alpha = lerp(alpha, alpha * vanishing, _UseVanishing);
}

// Proximity Shadow
// A neat gimmick to darken meshes that are right up against the camera, to fake
// the shadows from your camera/face being up against them.
half4 getNearShading(float3 worldPos, bool isFrontFace)
{
#if defined(UNITY_STANDARD_BRDF_INCLUDED)
    // Disable in mirrors.
    if (inMirror()) return 0;
#endif
    if (_UseProximityShadow == 0) return 0;

    half depth = distance(_WorldSpaceCameraPos, worldPos);
    // Transform clip pos depth into linear depth. Then, remove the near-clip plane.

    depth = max(0, depth/_ProximityShadowDistance);
    depth = saturate(depth);
    depth = 1.0 - pow(depth, abs(_ProximityShadowDistancePower));

    half4 shadowColor = isFrontFace ? _ProximityShadowFrontColor : _ProximityShadowBackColor;
    depth *= shadowColor.a;

    return half4(shadowColor.rgb, depth);
}


inline half getInventoryMask(float2 in_texcoord)
{
    // Initialise mask. This will cut things out.
    half inventoryMask = 0.0;
#if (defined(SHADER_STAGE_VERTEX) || defined(SHADER_STAGE_GEOMETRY))
    // Which UV section are we in?
    uint itemID = floor((in_texcoord.x) / _InventoryStride);

    // Create an array to store the _InventoryItemAnimated values
    half _InventoryItemAnimated[17] =
    {
        1,
        _InventoryItem01Animated,
        _InventoryItem02Animated,
        _InventoryItem03Animated,
        _InventoryItem04Animated,
        _InventoryItem05Animated,
        _InventoryItem06Animated,
        _InventoryItem07Animated,
        _InventoryItem08Animated,
        _InventoryItem09Animated,
        _InventoryItem10Animated,
        _InventoryItem11Animated,
        _InventoryItem12Animated,
        _InventoryItem13Animated,
        _InventoryItem14Animated,
        _InventoryItem15Animated,
        _InventoryItem16Animated
    };

    // If the item ID is zero or below, always render.
    // But if it's higher, check against toggles.
    if (itemID <= 16)
    {
        inventoryMask += _InventoryItemAnimated[itemID];
    }
    else
    {
        // Higher than 16? Enabled by default
        inventoryMask += 1;
    }
#endif
    return round(inventoryMask);
}

//-------------------------------------------------------------------------------------
// Input functions

struct SCSS_ShadingParam
{
    float3x3 tangentToWorld;  // TBN matrix
    float3  position;         // world-space position
    half3  normal;           // normalized transformed normal, in world space
    half3  view;             // normalized vector from the fragment to the eye
    half3  geometricNormal;  // normalized geometric normal, in world space
    half3  reflected;        // reflection of view about normal
    half NoV;                // dot(normal, view), always strictly >= MIN_N_DOT_V

    half anisotropy;
    half3 anisotropicT;
    half3 anisotropicB;

    half2 normalizedViewportCoord;
    half4 uv;
    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
        half4 lightmapUV;
    #endif
    half attenuation;
    float4 shadowCoord;
    half isOutline;
    half furDepth;
};

void computeShadingParams (inout SCSS_ShadingParam shading, VertexOutput i, bool frontFacing)
{
    half3x3 tangentToWorld;
    tangentToWorld[0] = i.tangentToWorldAndPackedData[0].xyz;
    tangentToWorld[1] = i.tangentToWorldAndPackedData[1].xyz;
    tangentToWorld[2] = i.tangentToWorldAndPackedData[2].xyz;
    tangentToWorld = frontFacing ? tangentToWorld : -tangentToWorld;

    shading.tangentToWorld = transpose(tangentToWorld);
    shading.geometricNormal = normalize(i.tangentToWorldAndPackedData[2].xyz);

    shading.normalizedViewportCoord = GetNormalizedScreenSpaceUV(i.pos);

    shading.normal = shading.geometricNormal;
    shading.position = i.worldPos;
    shading.view = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);

    // Initialize to geometric NoV.
    shading.NoV = clampNoV(dot(shading.normal, shading.view));

    #if defined(SCSS_OUTLINE)
        shading.isOutline = i.extraData.x;
    #else
        shading.isOutline = false;
    #endif

    #if defined(SCSS_FUR)
        shading.furDepth = i.extraData.x;
    #else
        shading.furDepth = false;
    #endif

    shading.uv = i.uvPack0;

    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
        half2 lightmapUV = i.uvPack0.zw * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif

    shading.attenuation = 1.0;
    #if defined(USING_SHADOWS_UNITY) && !defined(UNITY_PASS_SHADOWCASTER)
        shading.shadowCoord = SCSS_GET_SHADOW_COORD(i);
        SCSS_LIGHT_ATTENUATION(atten, i, shading.position)

        shading.attenuation = atten;
    #else
        shading.shadowCoord = 0;
    #endif

    #if defined(SCSS_FUR)
        // Fur probably shouldn't have main light shadows when it doesn't write to the shadowcaster.
        // But the visual artifacts are small, and outlines have the same artifacts.
        // Maybe it should be user-controllable instead.
        // shading.attenuation = 1.0f;
    #endif

    #if defined(SCSS_SCREEN_SHADOW_FILTER) && defined(USING_SHADOWS_UNITY) && !defined(UNITY_PASS_SHADOWCASTER)
        correctedScreenShadowsForMSAA(shading.shadowCoord, shading.attenuation);
    #endif

    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
        GetBakedAttenuation(shading.attenuation, lightmapUV, shading.position);
    #endif

    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
        shading.lightmapUV = lightmapUV;
    #endif
}

struct SCSS_RimLightInput
{
    half width;
    half power;
    half3 tint;
    half alpha;

    half invWidth;
    half invPower;
    half3 invTint;
    half invAlpha;
};

// Contains tonemap colour and shade offset.
struct SCSS_TonemapInput
{
    half3 col;
    half bias;
    half offset;
    half width;
};

struct SCSS_Input
{
    half3 albedo;
    half alpha;
    half3 normalTangent;

    half occlusion;
    half2 sdf;
    half sdfSmoothness;
    half sdfMask;

    half3 specColor; half specOcclusion;
    half oneMinusReflectivity, smoothness, perceptualRoughness;

    half anisotropy;
    half3 anisotropyDirection;

    half softness;
    half3 thickness;

    half4 emission; // rgb: colour, alpha: darkening
    half3 postEffect; // effects applied after shading, affected by lighting

    half4 outlineCol;

    SCSS_RimLightInput rim;
    SCSS_TonemapInput tone[2];
};

void initMaterial(out SCSS_Input material)
{
    material = (SCSS_Input) 0;
    material.albedo = 1.0;
    material.alpha = 1.0;
    material.normalTangent = half3(0.0, 0.0, 1.0);
    material.occlusion = 1.0;
    material.specColor = 0.0;
    material.specOcclusion = 1.0;
    material.oneMinusReflectivity = 1.0;
    material.smoothness = 0.0;
    material.perceptualRoughness = 1.0;
    material.softness = 0.0;
    material.emission = 0.0;
    material.thickness = 1.0;

    material.anisotropy = 0;
    material.anisotropyDirection = half3(1.0, 0.0, 0.0);

    SCSS_RimLightInput rim = (SCSS_RimLightInput) 0;
    rim.width = 0.0;
    rim.power = 0.0;
    rim.tint = 0.0;
    rim.alpha = 0.0;
    rim.invWidth = 0.0;
    rim.invPower = 0.0;
    rim.invTint = 0.0;
    rim.invAlpha = 0.0;

    material.rim = rim;

    material.tone[0].col = 1.0;
    material.tone[0].bias = 1.0;
    material.tone[1].col = 1.0;
    material.tone[1].bias = 1.0;

    material.outlineCol = 0.0;
    material.outlineCol.a = 1.0;
}

struct SCSS_TexCoords
{
    // UV1, UV2, UV3, UV4 (xy only)
    float2 uv[4];
    // Other useful reuseable UVs could go here
};

SCSS_TexCoords initialiseTexCoords(float4 uvPack0, float4 uvPack1)
{
    SCSS_TexCoords tc;
    tc.uv[0] = uvPack0.xy;
    tc.uv[1] = uvPack0.zw;
    tc.uv[2] = uvPack1.xy;
    tc.uv[3] = uvPack1.zw;
    return tc;
}

float2 TexCoords(SCSS_TexCoords tc)
{
    float2 texcoord;
    // Always source albedo from uv0
    texcoord.xy = TRANSFORM_TEX(tc.uv[0], _MainTex);
    // Todo: Determine whether it would be important to sharp sample individual texture coords instead.
    // This causes a bug if mainTex and other textures have different resolutions.
    texcoord.xy = _PixelSampleMode ?
        sharpSample(_MainTex_TexelSize * _MainTex_ST.xyxy, texcoord.xy) : texcoord.xy;
    return texcoord;
}

half4 AlbedoHQ(float2 coord)
{
    coord = coord * _MainTex_TexelSize.zw - 0.5;
    float2 fxy = frac(coord.xy);
    coord -= fxy;

    float4 xcubic = cubic_weights(fxy.x);
    float4 ycubic = cubic_weights(fxy.y);

    float4 c = coord.xxyy + float4(-0.5, 1.5, -0.5, 1.5);
    float4 s = float4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    float4 offset = c + float4(xcubic.yw, ycubic.yw) / s;

    offset *= _MainTex_TexelSize.xxyy;

    half4 sample0 = UNITY_SAMPLE_TEX2D(_MainTex, offset.xz);
    half4 sample1 = UNITY_SAMPLE_TEX2D(_MainTex, offset.yz);
    half4 sample2 = UNITY_SAMPLE_TEX2D(_MainTex, offset.xw);
    half4 sample3 = UNITY_SAMPLE_TEX2D(_MainTex, offset.yw);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return lerp(
        lerp(sample3, sample2, sx),
        lerp(sample1, sample0, sx), sy);
}

half3 applyDetailBlendMode(int blendOp, half3 a, half3 b, half t)
{
    switch(blendOp)
    {
        default:
        case 0: // Multiply 2x
            return a * LerpWhiteTo_local (b * unity_ColorSpaceDouble.rgb, t);
        case 1: // Multiply
            return a * LerpWhiteTo_local (b, t);
        case 2: // Additive
            return a + b * t;
        case 3: // Alpha Blend
            return lerp(a, b, t);
        case 4: // Screen
            return max(a + (b - a * b) * t, a);
        case 5: // Subtract
            return max(0, a - b * t);
    }
}

void applyDetail(inout SCSS_Input c, sampler2D src, half2 detailUV, const int destMode, const int blendMode, half blendStrength)
{
    // Detail has to target multiple things due to tone maps and specular properties
    // Albedo:   c.albedo, c.tone[0], c.tone[1]
    // Normal:   c.normalTangent
    // Specular: c.specColor, c.smoothness

    // Detail for albedo has a special property where the alpha affects the blending.

    // Skip if intensity is zero.
    if (blendStrength < 1.0/255.0) return;

    half4 detailMap = tex2D(src, detailUV);
    switch(destMode)
    {
        case 0: // Albedo
            detailMap.a *= blendStrength;
            c.albedo = applyDetailBlendMode(blendMode, c.albedo, detailMap.rgb, detailMap.a);
            if (_CrosstoneToneSeparation) c.tone[0].col = applyDetailBlendMode(blendMode, c.tone[0].col, detailMap.rgb, detailMap.a);
            if (_Crosstone2ndSeparation) c.tone[1].col = applyDetailBlendMode(blendMode, c.tone[1].col, detailMap.rgb, detailMap.a);
            break;
        case 1: // Normal
            detailMap.xyz = UnpackScaleNormal(detailMap, blendStrength);
            c.normalTangent = BlendNormalsPD(c.normalTangent, detailMap.xyz);
            break;
        case 2: // Specular
            c.specColor = applyDetailBlendMode(blendMode, c.specColor, detailMap.rgb, blendStrength);
            c.smoothness = applyDetailBlendMode(blendMode, c.smoothness, detailMap.a, blendStrength);
            c.oneMinusReflectivity = OneMinusReflectivityFromMetallic_local(c.specColor);
            break;
        case 3: // Alpha
            detailMap.a *= blendStrength;
            c.alpha = applyDetailBlendMode(blendMode, c.alpha, detailMap.r, detailMap.a);
            break;
    }
}

float2 applyScaleOffset(float2 uv, half4 scaleOffset)
{
    // Potential future expansion? Right now, just makes code cleaner.
    return uv * scaleOffset.xy + scaleOffset.zw;
}


half getAlphaFresnel(half NdotV, half width, half sharpness, half strength, bool invert, half mask)
{
    half rimRaw = smoothstep(min(sharpness, width), width, NdotV);
    half rim = saturate(1.0 - rimRaw);

    rim = lerp(1.0, rim, strength);
    if (invert)
    {
        rim = 1.0 - rim;
    }
    return lerp(1.0, rim, mask);
}

void applyAlphaFresnel(inout half inAlpha, half NoV)
{
    if (_UseAlphaFresnel)
    {
        half feather = 0.05;
        half cutOff = smoothstep(_AlphaFresnelThreshold, _AlphaFresnelThreshold + feather, inAlpha);
        half mask = 1.0 - cutOff;

        half fresnelFactor = getAlphaFresnel(
            NoV,
            _AlphaFresnelWidth,
            _AlphaFresnelSharpness,
            _AlphaFresnelStrength,
            _AlphaFresnelInvert,
            mask
        );

        inAlpha *= fresnelFactor;
    }
}

#endif // SCSS_INPUT_INCLUDED
