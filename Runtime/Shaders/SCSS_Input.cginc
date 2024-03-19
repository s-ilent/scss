#ifndef SCSS_INPUT_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_INPUT_INCLUDED

//---------------------------------------

// Keyword squeezing. 

#if (defined(_DETAIL_MULX2) || defined(_DETAIL_MUL) || defined(_DETAIL_ADD) || defined(_DETAIL_LERP))
    #define _DETAIL
#endif

#if (defined(_METALLICGLOSSMAP) || defined(_SPECGLOSSMAP))
	#define _SPECULAR
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

//---------------------------------------

#if defined(_AUDIOLINK)
#include "SCSS_AudioLink.cginc"
#endif

UNITY_DECLARE_TEX2D(_MainTex); uniform half4 _MainTex_ST; uniform half4 _MainTex_TexelSize;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ColorMask); uniform half4 _ColorMask_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_BumpMap); uniform half4 _BumpMap_ST;

#if defined(_BACKFACE)
UNITY_DECLARE_TEX2D(_MainTexBackface); // Texel size assumed same as _MainTex.
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
UNITY_DECLARE_TEX2D(_AudiolinkMaskMap); uniform half4 _AudiolinkMaskMap_ST;
UNITY_DECLARE_TEX2D(_AudiolinkSweepMap); uniform half4 _AudiolinkSweepMap_ST;
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
UNITY_DECLARE_TEX2D_NOSAMPLER(_ShadowMask); uniform half4 _ShadowMask_ST;
uniform sampler2D _Ramp; uniform half4 _Ramp_ST;
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

#if defined(SCSS_OUTLINE)
uniform float _OutlineMode;
uniform float _OutlineZPush;
uniform float _outline_width;
#endif
uniform float4 _outline_color;

uniform float _LightingCalculationType;


UNITY_DECLARE_TEX2D_NOSAMPLER(_MatcapMask); uniform half4 _MatcapMask_ST; 
uniform sampler2D _Matcap1; uniform half4 _Matcap1_ST; 
uniform sampler2D _Matcap2; uniform half4 _Matcap2_ST; 
uniform sampler2D _Matcap3; uniform half4 _Matcap3_ST; 
uniform sampler2D _Matcap4; uniform half4 _Matcap4_ST; 

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

uniform float4 _LightSkew;
uniform float _PixelSampleMode;
uniform float _VertexColorType;

uniform float _DiffuseGeomShadowFactor;
uniform float _LightWrappingCompensationFactor;

uniform float _IndirectShadingType;

uniform float _UseInteriorOutline;
uniform float _InteriorOutlineWidth;

uniform sampler2D _OutlineMask; uniform half4 _OutlineMask_ST; 

// Animation
uniform float _UseAnimation;
uniform float _AnimationSpeed;
uniform int _TotalFrames;
uniform int _FrameNumber;
uniform int _Columns;
uniform int _Rows;

// Vanishing
uniform float _UseVanishing;
uniform float _VanishingStart;
uniform float _VanishingEnd;

// Proximity Shadow
uniform float _UseProximityShadow;
uniform float _ProximityShadowDistance;
uniform float _ProximityShadowDistancePower;
uniform float4 _ProximityShadowFrontColor;
uniform float4 _ProximityShadowBackColor;

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
uniform sampler2D _DetailMap1; uniform half4 _DetailMap1_ST; uniform half4 _DetailMap1_TexelSize; 
uniform sampler2D _DetailMap2; uniform half4 _DetailMap2_ST; uniform half4 _DetailMap2_TexelSize; 
uniform sampler2D _DetailMap3; uniform half4 _DetailMap3_ST; uniform half4 _DetailMap3_TexelSize; 
uniform sampler2D _DetailMap4; uniform half4 _DetailMap4_ST; uniform half4 _DetailMap4_TexelSize; 
uniform float _DetailMap1UV; uniform float _DetailMap1Type; uniform float _DetailMap1Blend; uniform float _DetailMap1Strength; 
uniform float _DetailMap2UV; uniform float _DetailMap2Type; uniform float _DetailMap2Blend; uniform float _DetailMap2Strength; 
uniform float _DetailMap3UV; uniform float _DetailMap3Type; uniform float _DetailMap3Blend; uniform float _DetailMap3Strength; 
uniform float _DetailMap4UV; uniform float _DetailMap4Type; uniform float _DetailMap4Blend; uniform float _DetailMap4Strength; 
#endif

// Fur options
#if defined(SCSS_FUR)
uniform sampler2D _FurMask;
UNITY_DECLARE_TEX2D_NOSAMPLER(_FurNoise); float4 _FurNoise_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_FurNormal);
uniform float _FurLength;
uniform float _FurMode;
uniform float _FurLayerCount;
uniform float _FurRandomization;
uniform float _FurThickness;
uniform float _FurGravity;
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

struct SCSS_LightParam
{
	half3 viewDir, halfDir, reflDir;
	half NdotL, NdotV, LdotH, NdotH;
	half NdotAmb;
};

// Allows saturate to be called on light params. 
// Does not affect directions. Those are already normalized.
// Only the required saturations will be left in code.
SCSS_LightParam saturate (SCSS_LightParam d)
{
	d.NdotL = saturate(d.NdotL);
	d.NdotV = saturate(d.NdotV);
	d.LdotH = saturate(d.LdotH);
	d.NdotH = saturate(d.NdotH);
	return d;
}

SCSS_RimLightInput initialiseRimParam()
{
	SCSS_RimLightInput rim = (SCSS_RimLightInput) 0;
	rim.width = _FresnelWidth;
	rim.power = _FresnelStrength;
	rim.tint = _FresnelTint.rgb;
	rim.alpha = _FresnelTint.a;

	rim.invWidth = _FresnelWidthInv;
	rim.invPower = _FresnelStrengthInv;
	rim.invTint = _FresnelTintInv.rgb;
	rim.invAlpha = _FresnelTintInv.a;
	return rim;
}

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

float4 EmissionTexCoords(SCSS_TexCoords tc)
{
	float4 texcoord = 0;
#if defined(_EMISSION) 
	texcoord.xy = tc.uv[_EmissionUVSec];
	texcoord.xy = TRANSFORM_TEX(texcoord, _EmissionMap);
	texcoord.xy = _PixelSampleMode? 
		sharpSample(_EmissionMap_TexelSize * _EmissionMap_ST.xyxy, texcoord.xy) : texcoord.xy;

	// Should we skip this if detail texture doesn't exist?
	float2 detailTexcoord = tc.uv[_DetailEmissionUVSec];
	detailTexcoord = TRANSFORM_TEX(detailTexcoord, _DetailEmissionMap);
	detailTexcoord = _PixelSampleMode? 
		sharpSample(_DetailEmissionMap_TexelSize * _DetailEmissionMap_ST.xyxy, detailTexcoord) : detailTexcoord;
	texcoord.zw = detailTexcoord;
#endif
	return texcoord;
}

float4 EmissionTexCoords2nd(SCSS_TexCoords tc)
{
	float4 texcoord = 0;
#if defined(_EMISSION_2ND) 
	texcoord.xy = tc.uv[_EmissionUVSec2nd];
	texcoord.xy = TRANSFORM_TEX(texcoord, _EmissionMap2nd);
	texcoord.xy = _PixelSampleMode? 
		sharpSample(_EmissionMap2nd_TexelSize * _EmissionMap2nd_ST.xyxy, texcoord.xy) : texcoord.xy;

	// Should we skip this if detail texture doesn't exist?
	float2 detailTexcoord = tc.uv[_DetailEmissionUVSec2nd];
	detailTexcoord = TRANSFORM_TEX(detailTexcoord, _DetailEmissionMap2nd);
	detailTexcoord = _PixelSampleMode? 
		sharpSample(_DetailEmissionMap2nd_TexelSize * _DetailEmissionMap2nd_ST.xyxy, detailTexcoord) : detailTexcoord;
	texcoord.zw = detailTexcoord;
#endif
	return texcoord;
}

float4 EmissiveAudioLinkTexCoords(SCSS_TexCoords tc)
{
	float4 texcoord;
#if defined(_AUDIOLINK) 
	float2 maskTexcoord = tc.uv[_AudiolinkMaskMapUVSec];
	float2 sweepTexcoord = tc.uv[_AudiolinkSweepMapUVSec];

	maskTexcoord.xy = TRANSFORM_TEX(maskTexcoord, _AudiolinkMaskMap);
	// Pixel sample mode not implemented yet.
	sweepTexcoord.xy = TRANSFORM_TEX(sweepTexcoord, _AudiolinkSweepMap);
	// Pixel sampling probably won't work with sweeps...

	texcoord = float4(maskTexcoord, sweepTexcoord); // Default we won't need
#else
	texcoord = float4(tc.uv[0], tc.uv[1]); // Default we won't need
#endif
    return texcoord;
}

half OutlineMask(float2 uv)
{
	#if defined(SCSS_OUTLINE)
		// Needs LOD, sampled in vertex function
		return tex2Dlod(_OutlineMask, float4(uv, 0, 0)).r;
	#else
		return 0;
	#endif
}

half FurMask(float2 uv)
{
	#if defined(SCSS_FUR)
		// Needs LOD, sampled in vertex function
    	return tex2Dlod(_FurMask, float4(uv, 0, 0)).r;
	#else
		return 0;
	#endif
}

half ColorMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_ColorMask, _MainTex, uv).g;
}

half RimMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_ColorMask, _MainTex, uv).b;
}

half4 MatcapMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_MatcapMask, _MainTex, uv);
}

half4 DetailMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_DetailAlbedoMask, _MainTex, uv);
}

half3 Thickness(float2 uv)
{
#if defined(_SUBSURFACE)
	return pow(
		UNITY_SAMPLE_TEX2D_SAMPLER (_ThicknessMap, _MainTex, uv), 
		_ThicknessMapPower);
#else
	return 1;
#endif
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

half3 Albedo(float2 uv)
{
	half3 albedo = UNITY_SAMPLE_TEX2D (_MainTex, uv).rgb;
    return albedo;
}

half3 Emission(float2 uv)
{
#if defined(_EMISSION) 
    return UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap, _MainTex, uv*_EmissionMap_ST.xy+_EmissionMap_ST.zw).rgb;
#else
	return 1.0f;
#endif
}

half4 EmissionDetail(float2 uv)
{
#if defined(_EMISSION)
	if (dot(_DetailEmissionMap_TexelSize.zw, 1.0) > 4.0)
	{
		uv += _EmissionDetailParams.xy * _Time.y;
		half4 ed = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailEmissionMap, _DetailEmissionMap, uv);
		if (_EmissionDetailParams.z != 0)
		{
			float s = dot((0.5 * sin(ed.rgb * _EmissionDetailParams.w + _Time.y * _EmissionDetailParams.z))+0.5, 1.0/3.0);
			ed.rgb = s;
		}
		return ed;
	}
#endif
	return 1.0f;
}

half3 Emission2nd(float2 uv)
{
#if defined(_EMISSION_2ND) 
    return UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap2nd, _MainTex, uv*_EmissionMap2nd_ST.xy+_EmissionMap2nd_ST.zw).rgb;
#else
	return 1.0f;
#endif
}

half4 EmissionDetail2nd(float2 uv)
{
#if defined(_EMISSION_2ND)
	if (any(_DetailEmissionMap2nd_TexelSize.zw > 4.0))
	{
		uv += _EmissionDetailParams2nd.xy * _Time.y;
		half4 ed = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailEmissionMap2nd, _DetailEmissionMap2nd, uv);
		if (_EmissionDetailParams2nd.z != 0)
		{
			float s = dot((0.5 * sin(ed.rgb * _EmissionDetailParams2nd.w + _Time.y * _EmissionDetailParams2nd.z))+0.5, 1.0/3.0);
			ed.rgb = s;
		}
		return ed;
	}
#endif
	return 1.0f;
}

half ClippingMask(float2 uv)
{
	uv = TRANSFORM_TEX(uv, _ClippingMask);
	// Workaround for shadow compiler error. 
	#if defined(SCSS_SHADOWS_INCLUDED)
	float alpha = UNITY_SAMPLE_TEX2D(_ClippingMask, uv).r;
	#else
	float alpha = UNITY_SAMPLE_TEX2D_SAMPLER(_ClippingMask, _MainTex, uv).r;
	#endif 
	return saturate(alpha + _Tweak_Transparency);
}

half Alpha(float2 uv, float2 uv0)
{
	half alpha = _Color.a;
	switch(_AlbedoAlphaMode)
	{
		case 0: alpha *= UNITY_SAMPLE_TEX2D(_MainTex, uv).a; break;
		case 2: alpha *= ClippingMask(uv0); break;
	}
	// Bugfix for Unity's bad BC7 texture encoding that makes opaque areas slightly transparent
	const float alphaFix = 1.0 / ((255.0 - 8.0)/255.0);
	alpha = saturate(alpha * alphaFix);
	return alpha;
}

half4 Iridescence(float NoV, float rampID)
{
#if defined(_SPECULAR)
	if (any(_SpecIridescenceRamp_TexelSize.zw > 6.0))
	{
	float rampIDUV = (1.0 - (floor(rampID * _SpecIridescenceRamp_TexelSize.w) + 0.5) * _SpecIridescenceRamp_TexelSize.y);
	float2 rampUV = float2(NoV, rampIDUV);
	// Colour multiplies specular colour, alpha attenuates albedo.
	return UNITY_SAMPLE_TEX2D_SAMPLER(_SpecIridescenceRamp, _MainTex, rampUV);
	}
#endif
	return 1.0;
}

void applyVanishing (inout float alpha) {
    const fixed3 baseWorldPos = unity_ObjectToWorld._m03_m13_m23;
    float closeDist = distance(_WorldSpaceCameraPos, baseWorldPos);
    float vanishing = saturate(lerpstep(_VanishingStart, _VanishingEnd, closeDist));
    alpha = lerp(alpha, alpha * vanishing, _UseVanishing);
}

#if defined(_BACKFACE)
half3 BackfaceAlbedo(float2 uv)
{
    half3 albedo = UNITY_SAMPLE_TEX2D (_MainTexBackface, uv).rgb;
    return albedo;
}
half BackfaceAlpha(float2 uv)
{
	half alpha = _ColorBackface.a;
	switch(_AlbedoAlphaMode)
	{
		case 0: alpha *= UNITY_SAMPLE_TEX2D(_MainTexBackface, uv).a; break;
		case 2: alpha *= ClippingMask(uv); break;
	}
	return alpha;
}
#endif // _BACKFACE

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

float3 applyMaskedHSVToAlbedo(float3 albedo, float mask, float shiftHue, float shiftSat, float shiftVal)
{
	// HSV tinting, masked by tint mask
	float3 warpedAlbedo = TransformHSV(albedo, shiftHue, shiftSat, shiftVal);
	return lerp(albedo, saturate(warpedAlbedo), mask);
}

half4 SpecularGloss(float2 uv)
{
    half4 sg;
#if defined(_SPECULAR)
    sg = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecGlossMap, _MainTex, uv);

    sg.a = _AlbedoAlphaMode == 1? UNITY_SAMPLE_TEX2D(_MainTex, uv).a : sg.a;

    sg.rgb *= _SpecColor * _SpecColor.a; // Use alpha as an overall multiplier
    sg.a *= _Smoothness; // _GlossMapScale is what Standard uses for this
#else
    sg = _SpecColor;
    sg.a = _AlbedoAlphaMode == 1? UNITY_SAMPLE_TEX2D(_MainTex, uv).a : sg.a;
#endif
    return sg;
}

half4 EmissiveAudioLink(float2 maskUV, float2 sweepUV)
{
	float4 col = 0;
#if defined(_AUDIOLINK) 
	// Load mask texture
	half4 mask = UNITY_SAMPLE_TEX2D_SAMPLER(_AudiolinkMaskMap, _AudiolinkMaskMap, maskUV);
	// Load weights texture
	half4 weights = UNITY_SAMPLE_TEX2D_SAMPLER(_AudiolinkSweepMap, _AudiolinkSweepMap, sweepUV);
	// Apply a small epsilon to the weights to avoid artifacts.
	const float epsilon = (1.0/255.0);
	weights = saturate(weights-epsilon);
	// sample the texture
	col.rgb += (_alBandR >= 1) ? audioLinkGetLayer(weights.r, _alTimeRangeR, _alBandR, _alModeR) * _alColorR : 0;
	col.rgb += (_alBandG >= 1) ? audioLinkGetLayer(weights.g, _alTimeRangeG, _alBandG, _alModeG) * _alColorG : 0;
	col.rgb += (_alBandB >= 1) ? audioLinkGetLayer(weights.b, _alTimeRangeB, _alBandB, _alModeB) * _alColorB : 0;
	col.rgb += (_alBandA >= 1) ? audioLinkGetLayer(weights.a, _alTimeRangeA, _alBandA, _alModeA) * _alColorA : 0;
	col.a = 1.0;
	col.rgb *= mask * _AudiolinkIntensity;
#endif
	return col;
}

float applyEmissionRim(float power, float NdotV)
{
	float absPower = abs(power);
	if (absPower > 0.0001)
	{
		// d.NdotV is not guaranteed to be positive, so clamp it here. 
		float rimMask = saturate(pow(max(abs(NdotV), float(FLT_EPS)), absPower));
		return power < 0.0 ? 1.0 - rimMask : rimMask;
	}
	return 1.0;
}

half3 NormalInTangentSpace(float2 uv)
{
	#if defined(UNITY_STANDARD_BRDF_INCLUDED)
		float3 normalTangent = UnpackScaleNormal(
			UNITY_SAMPLE_TEX2D_SAMPLER(_BumpMap, _MainTex, 
				uv), _BumpScale);
	    return normalTangent;
	#else
		return float3(1, 1, 0);
	#endif
}

#if !defined(SCSS_CROSSTONE)
SCSS_TonemapInput Tonemap(float2 uv, inout float occlusion)
{
	SCSS_TonemapInput t = (SCSS_TonemapInput)0;
	float4 _ShadowMask_var = UNITY_SAMPLE_TEX2D_SAMPLER(_ShadowMask, _MainTex, uv.xy);

	switch (_ShadowMaskType)
	{
		case 0: // Occlusion
			// RGB will boost shadow range. Raising _Shadow reduces its influence.
			// Alpha will boost light range. Raising _Shadow reduces its influence.
			t.col = saturate(_IndirectLightingBoost+1-_ShadowMask_var.a) * _ShadowMaskColor.rgb;
			t.bias = _ShadowMaskColor.a*_ShadowMask_var.r;
			break;
		case 1: // Tone
			t.col = saturate(_ShadowMask_var+_IndirectLightingBoost) * _ShadowMaskColor.rgb;
			t.bias = _ShadowMaskColor.a*_ShadowMask_var.a;
			break;
		case 2: // Auto-Tone
			float3 albedo = Albedo(uv.xyxy);
			t.col = saturate(AutoToneMapping(albedo)+_IndirectLightingBoost) * _ShadowMaskColor.rgb;
			t.bias = _ShadowMaskColor.a*_ShadowMask_var.r;
			break;
	}

	t.bias = (1 - _Shadow) * t.bias + _Shadow;
	occlusion = t.bias;
	return t;
}

// Sample ramp with the specified options.
// rampPosition: 0-1 position on the light ramp from light to dark
// softness: 0-1 position on the light ramp on the other axis
float3 sampleRampWithOptions(float rampPosition, half softness) 
{
    float2 rampUV = float2(rampPosition, softness);
    switch (_LightRampType)
    {
        case 3: // No sampling; smooth NdotL
            return saturate(rampPosition*2-1);
        case 2: // No texture, sharp sampling
            float shadeWidth = 0.0002 * (1+softness*100);
            const float shadeOffset = 0.5; 
            float lightContribution = simpleSharpen(rampPosition, shadeWidth, shadeOffset);
            return saturate(lightContribution);
        case 1: // Vertical
            rampUV = float2(softness, rampPosition);
            return tex2D(_Ramp, saturate(rampUV));
        default: // Horizontal
            return tex2D(_Ramp, saturate(rampUV));
    }
}
#endif

#if defined(SCSS_CROSSTONE)
// Tonemaps contain tone in RGB, occlusion in A.
// Midpoint/width is handled in the application function.
SCSS_TonemapInput Tonemap1st (float2 uv)
{
	float4 tonemap = UNITY_SAMPLE_TEX2D_SAMPLER(_1st_ShadeMap, _MainTex, uv.xy);
	tonemap.rgb = tonemap * _1st_ShadeColor;
	SCSS_TonemapInput t = (SCSS_TonemapInput)1;
	t.col = tonemap.rgb;
	t.bias = tonemap.a;
	t.offset = t.bias * _1st_ShadeColor_Step;
	t.width = _1st_ShadeColor_Feather;
	return t;
}
SCSS_TonemapInput Tonemap2nd (float2 uv)
{
	float4 tonemap = UNITY_SAMPLE_TEX2D_SAMPLER(_2nd_ShadeMap, _MainTex, uv.xy);
	tonemap.rgb *= _2nd_ShadeColor;
	SCSS_TonemapInput t = (SCSS_TonemapInput)1;
	t.col = tonemap.rgb;
	t.bias = tonemap.a;
	t.offset = t.bias * _2nd_ShadeColor_Step;
	t.width = _2nd_ShadeColor_Feather;
	return t;
}

float adjustShadeMap(float x, float y)
{
	// Might be changed later.
	return (x * (1+y));
}

float ShadingGradeMap (float2 uv)
{
	float tonemap = UNITY_SAMPLE_TEX2D_SAMPLER(_ShadingGradeMap, _MainTex, uv.xy).r;
	// Red to match UCTS
	return adjustShadeMap(tonemap, _Tweak_ShadingGradeMapLevel);
}
#endif

void applyVertexColour(float3 color, inout SCSS_Input c)
{
	// Only float3 input is supported, as vertex alpha isn't 
	switch (_VertexColorType)
	{
		// Color
		case 0: 
		c.albedo = c.albedo * color.rgb; 
		if (_CrosstoneToneSeparation) c.tone[0].col *= color.rgb; 
		if (_Crosstone2ndSeparation) c.tone[1].col *= color.rgb; 
		c.outlineCol.rgb = color * _outline_color;
		c.outlineCol.a = c.alpha * _outline_color.a;
		break;
		
		// Outline Color
		// color is color (passed from vertex)
		// Additional Data/Ignore
		// color is white (reset from vertex)
		default: 
		c.outlineCol.rgb = color * _outline_color;
		c.outlineCol.a = _outline_color.a;
		break;

	}
}

float3 applyOutline(float3 col, float3 outlineCol, float is_outline)
{    
	#if defined(SCSS_OUTLINE)
	switch (_OutlineMode)
	{
		// Tinted
		case 1: 
			outlineCol = outlineCol.rgb * col.rgb; 
			break;
		// Colored (replaces color)
		default: 
			outlineCol = outlineCol; 
			break;

	}
    return lerp(col, outlineCol, is_outline);
    #else
    return col;
	#endif
}

float applyOutlineAlpha(float alpha, float outlineAlpha, float is_outline)
{    
	#if defined(SCSS_OUTLINE)
	switch (_OutlineMode)
	{
		// Tinted
		case 1: 
			outlineAlpha = outlineAlpha * alpha; 
			break;
		// Colored (replaces color)
		default: 
			outlineAlpha = outlineAlpha; 
			break;

	}
    return lerp(alpha, outlineAlpha, is_outline);
    #else
    return alpha;
	#endif
}

void applyOutline(float is_outline, inout SCSS_Input c)
{
	c.albedo = applyOutline(c.albedo, c.outlineCol, is_outline);
    if (_CrosstoneToneSeparation) c.tone[0].col = applyOutline(c.tone[0].col, c.outlineCol, is_outline);
	if (_Crosstone2ndSeparation)  c.tone[1].col = applyOutline(c.tone[1].col, c.outlineCol, is_outline);
	c.alpha = applyOutlineAlpha(c.alpha, c.outlineCol.a, is_outline);
}


//-----------------------------------------------------------------------------
// These functions use data or functions not available in the shadow pass
//-----------------------------------------------------------------------------

#if defined(UNITY_STANDARD_BRDF_INCLUDED)

struct SCSS_Light
{
    half3 color;
    half3 dir;
    half  intensity; 
};

bool getLightClampActive()
{
	#if !UNITY_HDR_ON && SCSS_CLAMP_IN_NON_HDR
	return true;
	#endif
	#if SCSS_NO_CLAMPING
	return false;
	#endif
	return (_LightClampAnimated == 1.0);
}

SCSS_Light MainLight(float3 worldPos)
{
    SCSS_Light l;

    l.color = _LightColor0.rgb;
    l.dir = Unity_SafeNormalize(UnityWorldSpaceLightDir(worldPos)); 

    // Workaround for scenes with HDR off blowing out in VRchat.
    if (getLightClampActive())
        l.color = saturate(l.color);

	// Minimum light level setting.
	l.color += _LightAddAnimated;

    return l;
}

float getAmbientLight (float3 normal, float3 viewDir)
{
	float3 ambientLightDirection = Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);

	if (_IndirectShadingType == 2) // Flatten
	{
		ambientLightDirection = any(_LightColor0) 
		? normalize(_WorldSpaceLightPos0) 
		: ambientLightDirection;
	}

	if (_IndirectShadingType == 3) // UTS-like
	{
		ambientLightDirection = any(_LightColor0) 
		? normalize(_WorldSpaceLightPos0) 
		: viewDir;
	}

	float ambientLight = dot(normal, ambientLightDirection);
	ambientLight = ambientLight * 0.5 + 0.5;

	if (_IndirectShadingType == 0) // Dynamic
		ambientLight = getGreyscaleSH(normal);
	return ambientLight;
}

SCSS_LightParam initialiseLightParam (SCSS_Light l, SCSS_ShadingParam s)
{
	SCSS_LightParam d = (SCSS_LightParam) 0;
	d.halfDir = Unity_SafeNormalize (l.dir + s.view);
	d.reflDir = reflect(-s.view, s.normal); // Calculate reflection vector
	d.NdotL = (dot(l.dir, s.normal)); // Calculate NdotL
	d.NdotV = (dot(s.view,  s.normal)); // Calculate NdotV
	d.LdotH = (dot(l.dir, d.halfDir));
	d.NdotH = (dot(s.normal, d.halfDir)); // Saturate seems to cause artifacts
	d.NdotAmb = getAmbientLight(s.normal, s.view);
	return d;
}

void getDirectIndirectLighting(float3 normal, out float3 directLighting, out float3 indirectLighting)
{
	directLighting   = 0.0;
	indirectLighting = 0.0;

	#ifndef SHADER_TARGET_GLSL
	[call] // https://www.gamedev.net/forums/topic/682920-hlsl-switch-attributes/
	#endif
	switch (_LightingCalculationType)
	{
	case 0: // Unbiased
		directLighting   = GetSHMaxL1();
		indirectLighting = GetSHAverage(); 
	break;
	case 1: // Standard
		directLighting = 
		indirectLighting = BetterSH9(half4(normal, 1.0));
	break;
	case 2: // Cubed
		directLighting   = BetterSH9(half4(0.0,  1.0, 0.0, 1.0));
		indirectLighting = BetterSH9(half4(0.0, -1.0, 0.0, 1.0)); 
	break;
	case 3: // True Directional
		float4 ambientDir = float4(Unity_SafeNormalize(unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz), 1.0);
		directLighting   = BetterSH9(ambientDir);
		indirectLighting = BetterSH9(-ambientDir); 
	break;
	case 4: // Biased
		directLighting   = GetSHMaxL1();
		indirectLighting = BetterSH9(half4(0.0, 0.0, 0.0, 1.0)); 
	break;
	}

	directLighting   += FLT_EPS;
	indirectLighting += FLT_EPS;

    // Workaround for scenes with HDR off blowing out in VRchat.
    if (getLightClampActive())
    {
        directLighting = saturate(directLighting);
        indirectLighting = saturate(indirectLighting);
    }
}
#endif // if UNITY_STANDARD_BRDF_INCLUDED

// A neat gimmick to darken meshes that are right up against the camera, to fake
// the shadows from your camera/face being up against them.
float3 applyNearShading(float3 color, float3 worldPos, bool isFrontFace)
{
#if defined(UNITY_STANDARD_BRDF_INCLUDED)
	// Disable in mirrors.
    if (inMirror()) return color;
#endif
    float depth = distance(_WorldSpaceCameraPos, worldPos);
    // Transform clip pos depth into linear depth. Then, remove the near-clip plane. 

    depth = max(0, depth/_ProximityShadowDistance);
    depth = saturate(depth);
    depth = pow(depth, abs(_ProximityShadowDistancePower));

    if (_UseProximityShadow == 1)
    {
    	float4 shadowColor = isFrontFace ? _ProximityShadowFrontColor : _ProximityShadowBackColor;
    	shadowColor.rgb = lerp(color, shadowColor, shadowColor.a);
    	color = lerp( shadowColor, color, depth );
    }

    return color;
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
			blendStrength *=  detailMap.b;
            c.specColor = applyDetailBlendMode(blendMode, c.specColor, detailMap.r, blendStrength);
            c.smoothness = applyDetailBlendMode(blendMode, c.smoothness, detailMap.a, blendStrength);
            break; 
    }
}

float2 applyScaleOffset(float2 uv, float4 scaleOffset)
{
	// Potential future expansion? Right now, just makes code cleaner.
	return uv * scaleOffset.xy + scaleOffset.zw;
}

#endif // SCSS_INPUT_INCLUDED