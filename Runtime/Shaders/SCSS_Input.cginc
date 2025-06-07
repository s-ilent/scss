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

#if (defined(_METALLICGLOSSMAP) || defined(_SPECGLOSSMAP))
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

#ifndef UNITY_SAMPLE_TEX2D_SAMPLER_LOD
#define UNITY_SAMPLE_TEX2D_SAMPLER_LOD(tex,samplertex,coord,lod) tex.Sample (sampler##samplertex,coord,lod)
#endif
#ifndef UNITY_SAMPLE_TEX2D_LOD
#define UNITY_SAMPLE_TEX2D_LOD(tex,coord,lod) tex.Sample (sampler##tex,coord,lod)
#endif

// Disable PBR dielectric setup in cel specular mode.
#if defined(_SPECGLOSSMAP)
	#undef unity_ColorSpaceDielectricSpec
	#define unity_ColorSpaceDielectricSpec half4(0, 0, 0, 1)
#endif 

//---------------------------------------

UNITY_DECLARE_TEX2D(_MainTex); uniform half4 _MainTex_ST; uniform half4 _MainTex_TexelSize;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ColorMask); uniform half4 _ColorMask_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_BumpMap); uniform half4 _BumpMap_ST;

#if defined(_BACKFACE)
UNITY_DECLARE_TEX2D_NOSAMPLER(_MainTexBackface); // Texel size assumed same as _MainTex.
#endif

// Workaround for shadow compiler error. 
#if defined(SCSS_SHADOWS_INCLUDED)
UNITY_DECLARE_TEX2D(_ClippingMask); uniform half4 _ClippingMask_ST;
#else
UNITY_DECLARE_TEX2D_NOSAMPLER(_ClippingMask); uniform half4 _ClippingMask_ST;
#endif

uniform float4 _EmissionColor;
uniform float _EmissionRimPower;
uniform half _EmissionMode;
uniform float4 _EmissionColor2nd;
uniform float _EmissionRimPower2nd;
uniform half _EmissionMode2nd;


#if defined(_EMISSION)
UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap); uniform half4 _EmissionMap_ST; uniform half4 _EmissionMap_TexelSize;
uniform half _EmissionUVSec;
UNITY_DECLARE_TEX2D(_DetailEmissionMap); uniform half4 _DetailEmissionMap_ST; uniform half4 _DetailEmissionMap_TexelSize;
uniform float _DetailEmissionUVSec;
uniform float4 _EmissionDetailParams;
uniform float _UseEmissiveLightSense;
uniform float _EmissiveLightSenseStart;
uniform float _EmissiveLightSenseEnd;
#endif

#if defined(_EMISSION_2ND)
UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap2nd); uniform half4 _EmissionMap2nd_ST; uniform half4 _EmissionMap2nd_TexelSize;
uniform half _EmissionUVSec2nd;
UNITY_DECLARE_TEX2D(_DetailEmissionMap2nd); uniform half4 _DetailEmissionMap2nd_ST; uniform half4 _DetailEmissionMap2nd_TexelSize;
uniform float _DetailEmissionUVSec2nd;
uniform float4 _EmissionDetailParams2nd;
uniform float _UseEmissiveLightSense2nd;
uniform float _EmissiveLightSenseStart2nd;
uniform float _EmissiveLightSenseEnd2nd;
#endif

#if defined(_AUDIOLINK)
UNITY_DECLARE_TEX2D_NOSAMPLER(_AudiolinkMaskMap); uniform half4 _AudiolinkMaskMap_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_AudiolinkSweepMap); uniform half4 _AudiolinkSweepMap_ST;
uniform float _AudiolinkIntensity;
uniform float _AudiolinkMaskMapUVSec;
uniform float _AudiolinkSweepMapUVSec;
// Not implemented yet
// uniform float _UseAudiolinkLightSense;
// uniform float _AudiolinkLightSenseStart;
// uniform float _AudiolinkLightSenseEnd;
#endif

// _SpecColor is defined deep in Standard/UnityCG land, in UnityLightingCommon.cginc
// For easy compatibility with Standard, we don't rename it. 
// This is a safety for the shadowcaster pass, which does not include it.
#ifndef UNITY_LIGHTING_COMMON_INCLUDED
float4 _SpecColor;
#endif

#if defined(_SPECULAR)
UNITY_DECLARE_TEX2D_NOSAMPLER(_SpecGlossMap); uniform half4 _SpecGlossMap_ST;
uniform float _UseMetallic;
uniform float _SpecularType;
uniform float _Smoothness;
uniform float _UseEnergyConservation;
uniform float _Anisotropy;
uniform float _CelSpecularSoftness;
uniform float _CelSpecularSteps;
uniform fixed _SpecularHighlights;
uniform fixed _GlossyReflections;
UNITY_DECLARE_TEX2D_NOSAMPLER(_SpecIridescenceRamp);
uniform float4 _SpecIridescenceRamp_TexelSize;
#else
// Default to zero
uniform float _SpecularType;
uniform float _UseEnergyConservation;
uniform float _Anisotropy; // Can not be removed yet.
#endif

#if defined(SCSS_CROSSTONE)
UNITY_DECLARE_TEX2D_NOSAMPLER(_1st_ShadeMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_2nd_ShadeMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_ShadingGradeMap);
// CrossTone
uniform float4 _1st_ShadeColor;
uniform float4 _2nd_ShadeColor;
uniform float _1st_ShadeColor_Step;
uniform float _1st_ShadeColor_Feather;
uniform float _2nd_ShadeColor_Step;
uniform float _2nd_ShadeColor_Feather;

uniform float _Tweak_ShadingGradeMapLevel;
uniform float _CrosstoneToneSeparation;
uniform float _Crosstone2ndSeparation;

uniform float4 _ShadowBorderColor;
uniform float _ShadowBorderRange;
#else
#define _CrosstoneToneSeparation float(0)
#define _Crosstone2ndSeparation float(0)
#endif

#if !defined(SCSS_CROSSTONE)
SamplerState _RampLinearClampSampler;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ShadowMask); uniform half4 _ShadowMask_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_Ramp); uniform half4 _Ramp_ST;
uniform float _LightRampType;
uniform float4 _ShadowMaskColor;
uniform float _ShadowMaskType;
uniform float _IndirectLightingBoost;
uniform float _Shadow;
uniform float _ShadowLift;
#endif

uniform float4 _Color;

#if defined(_BACKFACE)
uniform float4 _ColorBackface;
#endif

uniform float _BumpScale;
uniform float _Cutoff;
uniform float _AlphaSharp;
uniform float _UVSec;
uniform float _DetailNormalMapUVSec;
uniform float _SpecularDetailMaskUVSec;
uniform float _AlbedoAlphaMode;
uniform float _Tweak_Transparency;

uniform float _ToggleHueControls;
uniform float _ShiftHue;
uniform float _ShiftSaturation;
uniform float _ShiftValue;

uniform float _UseFresnel;
uniform float _UseFresnelLightMask;
uniform float4 _FresnelTint;
uniform float _FresnelWidth;
uniform float _FresnelStrength;
uniform float _FresnelLightMask;
uniform float4 _FresnelTintInv;
uniform float _FresnelWidthInv;
uniform float _FresnelStrengthInv;

uniform float4 _CustomFresnelColor;

uniform float _LightingCalculationType;

// Note: Sampler is declared in Utils
UNITY_DECLARE_TEX2D_NOSAMPLER(_MatcapMask); uniform half4 _MatcapMask_ST; 
UNITY_DECLARE_TEX2D_NOSAMPLER(_Matcap1); uniform half4 _Matcap1_ST; 
UNITY_DECLARE_TEX2D_NOSAMPLER(_Matcap2); uniform half4 _Matcap2_ST; 
UNITY_DECLARE_TEX2D_NOSAMPLER(_Matcap3); uniform half4 _Matcap3_ST; 
UNITY_DECLARE_TEX2D_NOSAMPLER(_Matcap4); uniform half4 _Matcap4_ST; 

uniform float _UseMatcap;
uniform float _Matcap1Strength;
uniform float _Matcap2Strength;
uniform float _Matcap3Strength;
uniform float _Matcap4Strength;
uniform float _Matcap1Blend;
uniform float _Matcap2Blend;
uniform float _Matcap3Blend;
uniform float _Matcap4Blend;
uniform float4 _Matcap1Tint;
uniform float4 _Matcap2Tint;
uniform float4 _Matcap3Tint;
uniform float4 _Matcap4Tint;

#if defined(_SUBSURFACE)
UNITY_DECLARE_TEX2D_NOSAMPLER(_ThicknessMap); uniform half4 _ThicknessMap_ST;
uniform float _UseSubsurfaceScattering;
uniform float _ThicknessMapPower;
uniform float _ThicknessMapInvert;
uniform float3 _SSSCol;
uniform float _SSSIntensity;
uniform float _SSSPow;
uniform float _SSSDist;
uniform float _SSSAmbient;
#endif

#if defined(_HATCHING)
sampler2D _HatchingTex;
half _HatchingScale;
half _HatchingMovementFPS;
half _HatchingShadingAdd;
half _HatchingShadingMul;
half _HatchingRimAdd;
half _HatchingAlbedoMul;
#endif

uniform float4 _LightSkew;
uniform float _PixelSampleMode;
uniform float _VertexColorType;
uniform float _VertexColorRType;
uniform float _VertexColorGType;
uniform float _VertexColorBType;
uniform float _VertexColorAType;

uniform float _DiffuseGeomShadowFactor;
uniform float _LightWrappingCompensationFactor;
uniform float _IndirectShadingType;

// Animation
uniform float _UseAnimation;
uniform float _AnimationSpeed;
uniform int _TotalFrames;
uniform int _FrameNumber;
uniform int _Columns;
uniform int _Rows;

struct SCSS_AnimData
{
	float speed;
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

// Vanishing
uniform float _UseVanishing;
uniform float _VanishingStart;
uniform float _VanishingEnd;

void applyVanishing (inout float alpha) {
    const fixed3 baseWorldPos = unity_ObjectToWorld._m03_m13_m23;
    float closeDist = distance(_WorldSpaceCameraPos, baseWorldPos);
    float vanishing = saturate(lerpstep(_VanishingStart, _VanishingEnd, closeDist));
    alpha = lerp(alpha, alpha * vanishing, _UseVanishing);
}

// Proximity Shadow
// A neat gimmick to darken meshes that are right up against the camera, to fake
// the shadows from your camera/face being up against them.
uniform float _UseProximityShadow;
uniform float _ProximityShadowDistance;
uniform float _ProximityShadowDistancePower;
uniform float4 _ProximityShadowFrontColor;
uniform float4 _ProximityShadowBackColor;

float4 getNearShading(float3 worldPos, bool isFrontFace)
{
#if defined(UNITY_STANDARD_BRDF_INCLUDED)
	// Disable in mirrors.
    if (inMirror()) return 0;
#endif
    if (_UseProximityShadow == 0) return 0;

    float depth = distance(_WorldSpaceCameraPos, worldPos);
    // Transform clip pos depth into linear depth. Then, remove the near-clip plane. 

    depth = max(0, depth/_ProximityShadowDistance);
    depth = saturate(depth);
    depth = 1.0 - pow(depth, abs(_ProximityShadowDistancePower));

    float4 shadowColor = isFrontFace ? _ProximityShadowFrontColor : _ProximityShadowBackColor;
    depth *= shadowColor.a;

    return float4(shadowColor.rgb, depth);
}

// Inventory 
uniform fixed _UseInventory;
uniform fixed _InventoryUVSec;
#if (defined(SHADER_STAGE_VERTEX) || defined(SHADER_STAGE_GEOMETRY))
uniform float _InventoryStride;
uniform fixed _InventoryItem01Animated;
uniform fixed _InventoryItem02Animated;
uniform fixed _InventoryItem03Animated;
uniform fixed _InventoryItem04Animated;
uniform fixed _InventoryItem05Animated;
uniform fixed _InventoryItem06Animated;
uniform fixed _InventoryItem07Animated;
uniform fixed _InventoryItem08Animated;
uniform fixed _InventoryItem09Animated;
uniform fixed _InventoryItem10Animated;
uniform fixed _InventoryItem11Animated;
uniform fixed _InventoryItem12Animated;
uniform fixed _InventoryItem13Animated;
uniform fixed _InventoryItem14Animated;
uniform fixed _InventoryItem15Animated;
uniform fixed _InventoryItem16Animated;
#endif

inline float getInventoryMask(float2 in_texcoord)
{
    // Initialise mask. This will cut things out.
    float inventoryMask = 0.0;
#if (defined(SHADER_STAGE_VERTEX) || defined(SHADER_STAGE_GEOMETRY))
    // Which UV section are we in?
    uint itemID = floor((in_texcoord.x) / _InventoryStride);

    // Create an array to store the _InventoryItemAnimated values
    float _InventoryItemAnimated[17] = 
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

// Light adjustment
uniform float _LightMultiplyAnimated;
uniform float _LightClampAnimated;
uniform float _LightAddAnimated;

// Contact shadows
#if defined(_CONTACTSHADOWS)
uniform float _ContactShadowDistance;
uniform uint _ContactShadowSteps;
#endif

// Detail masks
UNITY_DECLARE_TEX2D_NOSAMPLER(_DetailAlbedoMask);
#if defined(_DETAIL)
// Detail maps need seperate samplers, in case the user specifies clamp mode. 
uniform sampler2D _DetailMap1; uniform half4 _DetailMap1_ST; uniform half4 _DetailMap1_TexelSize; 
uniform sampler2D _DetailMap2; uniform half4 _DetailMap2_ST; uniform half4 _DetailMap2_TexelSize; 
uniform sampler2D _DetailMap3; uniform half4 _DetailMap3_ST; uniform half4 _DetailMap3_TexelSize; 
uniform sampler2D _DetailMap4; uniform half4 _DetailMap4_ST; uniform half4 _DetailMap4_TexelSize; 
uniform float _DetailMap1UV; uniform float _DetailMap1Type; uniform float _DetailMap1Blend; uniform float _DetailMap1Strength; 
uniform float _DetailMap2UV; uniform float _DetailMap2Type; uniform float _DetailMap2Blend; uniform float _DetailMap2Strength; 
uniform float _DetailMap3UV; uniform float _DetailMap3Type; uniform float _DetailMap3Blend; uniform float _DetailMap3Strength; 
uniform float _DetailMap4UV; uniform float _DetailMap4Type; uniform float _DetailMap4Blend; uniform float _DetailMap4Strength; 
#endif

// SDF options
uniform float _SDFMode;
uniform float _SDFSmoothness;

#if defined(_AUDIOLINK)
#include "SCSS_AudioLink.cginc"
#endif



#if (defined(SHADER_STAGE_VERTEX) || defined(SHADER_STAGE_GEOMETRY))
// Outline options
#if defined(SCSS_OUTLINE)
UNITY_DECLARE_TEX2D(_OutlineMask); uniform half4 _OutlineMask_ST; 
uniform float _OutlineZPush;
uniform float _outline_width;
uniform float _OutlineCalculationMode;
uniform float _OutlineNearDistance;
uniform float _OutlineFarDistance;
#endif
// Fur options
#if defined(SCSS_FUR)
UNITY_DECLARE_TEX2D(_FurMask);
uniform float _FurLength;
uniform float _FurMode;
uniform float _FurLayerCount;
uniform float _FurRandomization;
uniform float _FurGravity;
#endif
#endif

#if defined(SCSS_OUTLINE)
uniform float _OutlineMode;
uniform float4 _outline_color;
#else
float4 _outline_color = float4(0,0,0,0);
#endif

#if defined(SCSS_FUR)
UNITY_DECLARE_TEX2D_NOSAMPLER(_FurNoise); float4 _FurNoise_ST;
uniform float _FurThickness;
#endif

//-------------------------------------------------------------------------------------
// Input functions

struct SCSS_ShadingParam
{
	float3  position;         // world-space position
	float3x3 tangentToWorld;  // TBN matrix
    float3  normal;           // normalized transformed normal, in world space
	float3  view;             // normalized vector from the fragment to the eye
    float3  geometricNormal;  // normalized geometric normal, in world space
    float3  reflected;        // reflection of view about normal
    float NoV;                // dot(normal, view), always strictly >= MIN_N_DOT_V

    float2 normalizedViewportCoord;
	#if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
    	float2 lightmapUV;
    #endif
    float attenuation;
    float isOutline;
	float furDepth;
    float3 ambient;

	#if defined(VERTEXLIGHT_ON)
		half4 vertexLight;  
	#endif
};

void computeShadingParams (inout SCSS_ShadingParam shading, VertexOutput i, bool frontFacing)
{
    float3x3 tangentToWorld;
    tangentToWorld[0] = i.tangentToWorldAndPackedData[0].xyz;
    tangentToWorld[1] = i.tangentToWorldAndPackedData[1].xyz;
    tangentToWorld[2] = i.tangentToWorldAndPackedData[2].xyz;
    tangentToWorld = frontFacing ? tangentToWorld : -tangentToWorld;

    shading.tangentToWorld = transpose(tangentToWorld);
    shading.geometricNormal = normalize(i.tangentToWorldAndPackedData[2].xyz);

    shading.normalizedViewportCoord = i.pos.xy * (0.5 / i.pos.w) + 0.5;

    shading.normal = (shading.geometricNormal);
    shading.position = i.worldPos;
    shading.view = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
	
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

    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
    	float2 lightmapUV = i.uvPack0.zw * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif
	
    UNITY_LIGHT_ATTENUATION(atten, i, shading.position)

	#if defined(SCSS_FUR)
		// Fur probably shouldn't have main light shadows when it doesn't write to the shadowcaster.
		// But the visual artifacts are small, and outlines have the same artifacts.
		// Maybe it should be user-controllable instead. 
		// atten = 1.0f;
    #endif

	#if defined(SCSS_SCREEN_SHADOW_FILTER) && defined(USING_SHADOWS_UNITY) && !defined(UNITY_PASS_SHADOWCASTER)
		correctedScreenShadowsForMSAA(i._ShadowCoord, atten);
	#endif

	#if defined(USING_SHADOWS_UNITY) && !defined(UNITY_PASS_SHADOWCASTER)
	float3 lightPos = UnityWorldSpaceLightDir(i.worldPos.xyz);
		#if defined(_CONTACTSHADOWS)
		// Only calculate contact shadows if we're not in shadow. 
		if (atten > 0)
		{
			float contactShadows = screenSpaceContactShadow(lightPos, i.worldPos.xyz, i.pos.xy, _ContactShadowDistance, _ContactShadowSteps);
			contactShadows = 1.0 - contactShadows;
			contactShadows = _LightShadowData.r + contactShadows * (1-_LightShadowData.r);
			atten *= contactShadows * contactShadows;
		}
		#endif
	#endif

    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
    	GetBakedAttenuation(atten, lightmapUV, shading.position);
    #endif

	#if defined(VERTEXLIGHT_ON)
		shading.vertexLight = i.vertexLight;
	#endif

    shading.attenuation = atten;

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
	float3 normalTangent;

	half occlusion;
	half2 sdf;
	half sdfSmoothness;

	half3 specColor; half specOcclusion;
	half3 anisotropyDirection;
	float oneMinusReflectivity, smoothness, perceptualRoughness;

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
	material.normalTangent = float3(0.0, 0.0, 1.0);
	material.occlusion = 1.0;
	material.specColor = 0.0;
	material.specOcclusion = 1.0;
	material.oneMinusReflectivity = 1.0;
	material.smoothness = 0.0;
	material.perceptualRoughness = 1.0;
	material.softness = 0.0;
	material.emission = 0.0;
	material.thickness = 1.0;

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

half3 AlbedoHQ(float2 coord)
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

    float4 sample0 = UNITY_SAMPLE_TEX2D(_MainTex, offset.xz);
    float4 sample1 = UNITY_SAMPLE_TEX2D(_MainTex, offset.yz);
    float4 sample2 = UNITY_SAMPLE_TEX2D(_MainTex, offset.xw);
    float4 sample3 = UNITY_SAMPLE_TEX2D(_MainTex, offset.yw);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return lerp(
        lerp(sample3, sample2, sx),
        lerp(sample1, sample0, sx), sy);
}

float3 applyDetailBlendMode(int blendOp, half3 a, half3 b, half t)
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
    }
}

void applyDetail(inout SCSS_Input c, sampler2D src, half2 detailUV, const int destMode, const int blendMode, float blendStrength)
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
    }
}

float2 applyScaleOffset(float2 uv, float4 scaleOffset)
{
	// Potential future expansion? Right now, just makes code cleaner.
	return uv * scaleOffset.xy + scaleOffset.zw;
}

#endif // SCSS_INPUT_INCLUDED