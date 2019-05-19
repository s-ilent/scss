#ifndef SCSS_INPUT_INCLUDED
#define SCSS_INPUT_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

UNITY_DECLARE_TEX2D(_MainTex); uniform half4 _MainTex_ST; uniform half4 _MainTex_TexelSize;
UNITY_DECLARE_TEX2D_NOSAMPLER(_DetailAlbedoMap); uniform half4 _DetailAlbedoMap_ST; uniform half4 _DetailAlbedoMap_TexelSize;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ColorMask); uniform half4 _ColorMask_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_BumpMap); uniform half4 _BumpMap_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_DetailNormalMap); uniform half4 _DetailNormalMap_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap); uniform half4 _EmissionMap_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_SpecGlossMap); uniform half4 _SpecGlossMap_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ShadowMask); uniform half4 _ShadowMask_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_MatcapMask); uniform half4 _MatcapMask_ST; 
UNITY_DECLARE_TEX2D_NOSAMPLER(_SpecularDetailMask); uniform half4 _SpecularDetailMask_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ThicknessMap); uniform half4 _ThicknessMap_ST;

uniform sampler2D _Ramp; uniform half4 _Ramp_ST;
uniform sampler2D _AdditiveMatcap; uniform half4 _AdditiveMatcap_ST; 
uniform sampler2D _MultiplyMatcap; uniform half4 _MultiplyMatcap_ST; 

uniform float4 _Color;
uniform float _Cutoff;
uniform float _AlphaSharp;
uniform float _UVSec;

uniform float _DetailNormalMapScale;

uniform float _LightRampType;

uniform float4 _EmissionColor;

uniform float _UseMetallic;
uniform float _SpecularType;
uniform float _Smoothness;
uniform float _Anisotropy;
uniform float _UseEnergyConservation;

uniform float _Shadow;
uniform float4 _ShadowMaskColor;
uniform float _ShadowMaskType;
uniform float _ShadowLift;
uniform float _IndirectLightingBoost;

uniform float _UseFresnel;
uniform float _FresnelWidth;
uniform float _FresnelStrength;
uniform float4 _FresnelTint;

uniform float4 _CustomFresnelColor;

uniform float _outline_width;
uniform float4 _outline_color;

uniform float _LightingCalculationType;

uniform float _UseMatcap;
uniform float _AdditiveMatcapStrength;
uniform float _MultiplyMatcapStrength;

uniform float _SpecularDetailStrength;

uniform float _UseSubsurfaceScattering;
uniform float _ThicknessMapPower;
uniform float _ThicknessMapInvert;
uniform float3 _SSSCol;
uniform float _SSSIntensity;
uniform float _SSSPow;
uniform float _SSSDist;
uniform float _SSSAmbient;

uniform float4 _LightSkew;
uniform float _PixelSampleMode;

//-------------------------------------------------------------------------------------
// Input functions

struct v2g
{
	UNITY_POSITION(vertex);
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float4 posWorld : TEXCOORD2;
	float3 normalDir : TEXCOORD3;
	float3 tangentDir : TEXCOORD4;
	float3 bitangentDir : TEXCOORD5;
	float4 pos : CLIP_POS;
	half4 vertexLight : TEXCOORD6;
	fixed4 color : COLOR;
	UNITY_SHADOW_COORDS(7)
	UNITY_FOG_COORDS(8)
};

struct VertexOutput
{
	UNITY_POSITION(pos);
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float4 posWorld : TEXCOORD2;
	float3 normalDir : TEXCOORD3;
	float3 tangentDir : TEXCOORD4;
	float3 bitangentDir : TEXCOORD5;
	half4 vertexLight : TEXCOORD6;
	float4 color : COLOR;
	bool is_outline : IS_OUTLINE;
	UNITY_SHADOW_COORDS(7)
	UNITY_FOG_COORDS(8)
};

struct SCSS_Input 
{
	half3 albedo, specColor;
	float3 normal;
	float oneMinusReflectivity, smoothness;
	half alpha;
	half3 tonemap;
	half occlusion;
};

struct SCSS_LightParam
{
	half3 halfDir, reflDir;
	half2 rlPow4;
	half NdotL, NdotV, LdotH, NdotH;
};

float4 TexCoords(VertexOutput v)
{
    float4 texcoord;
	texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex);// Always source from uv0
	texcoord.xy = _PixelSampleMode? 
		sharpSample(_MainTex_TexelSize.zw * _MainTex_ST.xy, texcoord.xy) : texcoord.xy;

	texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
	texcoord.zw = _PixelSampleMode? 
		sharpSample(_DetailAlbedoMap_TexelSize.zw * _DetailAlbedoMap_ST.xy, texcoord.zw) : texcoord.zw;
    return texcoord;
}

half ColorMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_ColorMask, _MainTex, uv).g;
}

half DetailMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_ColorMask, _MainTex, uv).a;
}

half4 MatcapMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_MatcapMask, _MainTex, uv);
}

half3 Thickness(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_ThicknessMap, _MainTex, uv);
}

half3 Albedo(float4 texcoords)
{
    half3 albedo = UNITY_SAMPLE_TEX2D (_MainTex, texcoords.xy).rgb * LerpWhiteTo(_Color.rgb, ColorMask(texcoords.xy));
#if _DETAIL
    half mask = DetailMask(texcoords.xy);
    half3 detailAlbedo = UNITY_SAMPLE_TEX2D_SAMPLER (_DetailAlbedoMap, _MainTex, texcoords.zw).rgb;
    #if _DETAIL_MULX2
        albedo *= LerpWhiteTo (detailAlbedo * unity_ColorSpaceDouble.rgb, mask);
    #elif _DETAIL_MUL
        albedo *= LerpWhiteTo (detailAlbedo, mask);
    #elif _DETAIL_ADD
        albedo += detailAlbedo * mask;
    #elif _DETAIL_LERP
        albedo = lerp (albedo, detailAlbedo, mask);
    #endif
#endif
    return albedo;
}

half Alpha(float2 uv)
{
#if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
    return _Color.a;
#else
    return UNITY_SAMPLE_TEX2D(_MainTex, uv).a * _Color.a;
#endif
}


half4 SpecularGloss(float4 texcoords)
{
    half4 sg;
#if 1 //def _SPECGLOSSMAP
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        sg.rgb = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecGlossMap, _MainTex, texcoords.xy).rgb;
        sg.a = UNITY_SAMPLE_TEX2D(_MainTex, texcoords.xy).a;
    #else
        sg = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecGlossMap, _MainTex, texcoords.xy);
    #endif
    sg.a *= _Smoothness; // _GlossMapScale is what Standard uses for this
#else
    sg.rgb = _SpecColor.rgb;
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        sg.a = UNITY_SAMPLE_TEX2D(_MainTex, texcoords.xy).a * _Smoothness; // _GlossMapScale is what Standard uses for this
    #else
        sg.a = _Smoothness; // _Glossiness is what Standard uses for this
    #endif
#endif

#if defined(_SPECULAR_DETAIL)
	float4 sdm = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecularDetailMask,_MainTex,TRANSFORM_TEX(texcoords.zw, _SpecularDetailMask));
	sg *= saturate(sdm + 1-_SpecularDetailStrength);
#endif

    return sg;
}

half3 Emission(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap, _MainTex, uv).rgb * _EmissionColor.rgb;
}

half3 NormalInTangentSpace(float2 texcoords, half mask)
{
	float3 normalTangent = UnpackScaleNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_BumpMap, _MainTex, TRANSFORM_TEX(texcoords.xy, _MainTex)), 1.0);
#if _DETAIL 
    half3 detailNormalTangent = UnpackScaleNormal(UNITY_SAMPLE_TEX2D_SAMPLER (_DetailNormalMap, _MainTex, TRANSFORM_TEX(texcoords.xy, _DetailNormalMap)), _DetailNormalMapScale);
    #if _DETAIL_LERP
        normalTangent = lerp(
            normalTangent,
            detailNormalTangent,
            mask);
    #else
        normalTangent = lerp(
            normalTangent,
            BlendNormalsPD(normalTangent, detailNormalTangent),
            mask);
    #endif
#endif

    return normalTangent;
}

half3 Tonemap(float2 uv, inout float occlusion)
{
	float4 _ShadowMask_var = UNITY_SAMPLE_TEX2D_SAMPLER(_ShadowMask, _MainTex, uv.xy);

	if (_ShadowMaskType == 0) 
	{
		// RGB will boost shadow range. Raising _Shadow reduces its influence.
		// Alpha will boost light range. Raising _Shadow reduces its influence.
		_ShadowMask_var = float4(_ShadowMaskColor.rgb*(1-_ShadowMask_var.w), 
			_ShadowMaskColor.a*_ShadowMask_var.r);
	}
	if (_ShadowMaskType == 1) 
	{
		_ShadowMask_var = _ShadowMask_var * _ShadowMaskColor;
	}
	occlusion = _ShadowMask_var.a;
	return saturate(_ShadowMask_var.rgb + _IndirectLightingBoost);
}

#endif // SCSS_INPUT_INCLUDED