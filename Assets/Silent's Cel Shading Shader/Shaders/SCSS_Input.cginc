#ifndef SCSS_INPUT_INCLUDED
#define SCSS_INPUT_INCLUDED

//---------------------------------------

// Keyword squeezing. 
#if (_DETAIL_MULX2 || _DETAIL_MUL || _DETAIL_ADD || _DETAIL_LERP)
    #define _DETAIL 1
#endif

#if (_METALLICGLOSSMAP || _SPECGLOSSMAP)
	#define _SPECULAR 1
#endif

#if (_SUNDISK_NONE)
	#define _SUBSURFACE 1
#endif

//---------------------------------------

UNITY_DECLARE_TEX2D(_MainTex); uniform half4 _MainTex_ST; uniform half4 _MainTex_TexelSize;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ColorMask); uniform half4 _ColorMask_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_ClippingMask); uniform half4 _ClippingMask_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_BumpMap); uniform half4 _BumpMap_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_EmissionMap); uniform half4 _EmissionMap_ST;

#if defined(_DETAIL)
UNITY_DECLARE_TEX2D(_DetailAlbedoMap); uniform half4 _DetailAlbedoMap_ST; uniform half4 _DetailAlbedoMap_TexelSize;
UNITY_DECLARE_TEX2D_NOSAMPLER(_DetailNormalMap); uniform half4 _DetailNormalMap_ST;
UNITY_DECLARE_TEX2D_NOSAMPLER(_SpecularDetailMask); uniform half4 _SpecularDetailMask_ST;
uniform float _DetailAlbedoMapScale;
uniform float _DetailNormalMapScale;
uniform float _SpecularDetailStrength;
#endif

#if defined(_EMISSION)
UNITY_DECLARE_TEX2D_NOSAMPLER(_DetailEmissionMap); uniform half4 _DetailEmissionMap_ST;
uniform float4 _EmissionDetailParams;
#endif

#if defined(_SPECULAR)
//uniform float4 _SpecColor; // Defined elsewhere
UNITY_DECLARE_TEX2D_NOSAMPLER(_SpecGlossMap); uniform half4 _SpecGlossMap_ST;
uniform float _UseMetallic;
uniform float _SpecularType;
uniform float _Smoothness;
uniform float _UseEnergyConservation;
uniform float _Anisotropy;
uniform float _CelSpecularSoftness;
uniform float _CelSpecularSteps;
#else
#define _SpecularType 0
#define _UseEnergyConservation 0
uniform float _Anisotropy; // Can not be removed yet.
#endif

#if defined(SCSS_CROSSTONE)
UNITY_DECLARE_TEX2D_NOSAMPLER(_1st_ShadeMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_2nd_ShadeMap);
UNITY_DECLARE_TEX2D_NOSAMPLER(_ShadingGradeMap);
#endif

uniform float _Shadow;
uniform float _ShadowLift;

#if !defined(SCSS_CROSSTONE)
UNITY_DECLARE_TEX2D_NOSAMPLER(_ShadowMask); uniform half4 _ShadowMask_ST;
uniform sampler2D _Ramp; uniform half4 _Ramp_ST;
uniform float _LightRampType;
uniform float4 _ShadowMaskColor;
uniform float _ShadowMaskType;
uniform float _IndirectLightingBoost;
#endif

uniform float4 _Color;
uniform float _BumpScale;
uniform float _Cutoff;
uniform float _AlphaSharp;
uniform float _UVSec;
uniform float _AlbedoAlphaMode;

uniform float4 _EmissionColor;
// For later use
uniform float _EmissionScrollX;
uniform float _EmissionScrollY;
uniform float _EmissionPhaseSpeed;
uniform float _EmissionPhaseWidth;

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

uniform float _outline_width;
uniform float4 _outline_color;
uniform float _OutlineMode;

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

// CrossTone
uniform float4 _1st_ShadeColor;
uniform float4 _2nd_ShadeColor;
uniform float _1st_ShadeColor_Step;
uniform float _1st_ShadeColor_Feather;
uniform float _2nd_ShadeColor_Step;
uniform float _2nd_ShadeColor_Feather;

uniform float _Tweak_ShadingGradeMapLevel;

uniform float _DiffuseGeomShadowFactor;
uniform float _LightWrappingCompensationFactor;

uniform float _IndirectShadingType;
uniform float _CrosstoneToneSeparation;
uniform float _Crosstone2ndSeparation;

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

//-------------------------------------------------------------------------------------
// Input functions

struct VertexOutput
{
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO

	UNITY_POSITION(pos);
	float3 normal : NORMAL;
	fixed4 color : COLOR0_centroid;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float4 posWorld : TEXCOORD2;
	float3 normalDir : TEXCOORD3;
	float3 tangentDir : TEXCOORD4;
	float3 bitangentDir : TEXCOORD5;
	float4 vertex : VERTEX;

	#if defined(VERTEXLIGHT_ON)
	half4 vertexLight : TEXCOORD6;
	#endif

	half4 extraData : EXTRA_DATA;

	// Pass-through the shadow coordinates if this pass has shadows.
	#if defined(USING_SHADOWS_UNITY)
	UNITY_SHADOW_COORDS(8)
	#endif

	// Pass-through the fog coordinates if this pass has fog.
	#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
	UNITY_FOG_COORDS(9)
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
};

struct SCSS_Input 
{
	half3 albedo;
	half alpha;
	float3 normal;

	half occlusion;

	half3 specColor;
	float oneMinusReflectivity, smoothness, perceptualRoughness;
	half softness;
	half3 emission;

	half3 thickness;

	SCSS_RimLightInput rim;
	SCSS_TonemapInput tone[2];
};

struct SCSS_LightParam
{
	half3 viewDir, halfDir, reflDir;
	half2 rlPow4;
	half NdotL, NdotV, LdotH, NdotH;
	half NdotAmb;
};

#if defined(UNITY_STANDARD_BRDF_INCLUDED)
float getAmbientLight (float3 normal)
{
	float3 ambientLightDirection = Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);

	if (_IndirectShadingType == 2) // Flatten
	{
		ambientLightDirection = any(_LightColor0) 
		? normalize(_WorldSpaceLightPos0) 
		: ambientLightDirection;
	}

	float ambientLight = dot(normal, ambientLightDirection);
	ambientLight = ambientLight * 0.5 + 0.5;

	if (_IndirectShadingType == 0) // Dynamic
		ambientLight = getGreyscaleSH(normal);
	return ambientLight;
}

SCSS_LightParam initialiseLightParam (SCSS_Light l, float3 normal, float3 posWorld)
{
	SCSS_LightParam d = (SCSS_LightParam) 0;
	d.viewDir = normalize(_WorldSpaceCameraPos.xyz - posWorld.xyz);
	d.halfDir = Unity_SafeNormalize (l.dir + d.viewDir);
	d.reflDir = reflect(-d.viewDir, normal); // Calculate reflection vector
	d.NdotL = (dot(l.dir, normal)); // Calculate NdotL
	d.NdotV = (dot(d.viewDir,  normal)); // Calculate NdotV
	d.LdotH = (dot(l.dir, d.halfDir));
	d.NdotH = (dot(normal, d.halfDir)); // Saturate seems to cause artifacts
	d.rlPow4 = Pow4(float2(dot(d.reflDir, l.dir), 1 - d.NdotV));  
	d.NdotAmb = getAmbientLight(normal);
	return d;
}
#endif

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

float2 AnimateTexcoords(float2 texcoord)
{
	float2 spriteUV = texcoord;
	if (_UseAnimation)
	{
		_FrameNumber += frac(_Time[0] * _AnimationSpeed) * _TotalFrames;

		float frame = clamp(_FrameNumber, 0, _TotalFrames);

		float2 offPerFrame = float2((1 / (float)_Columns), (1 / (float)_Rows));

		float2 spriteSize = texcoord * offPerFrame;

		float2 currentSprite = 
				float2(frame * offPerFrame.x,  1 - offPerFrame.y);
		
		float rowIndex;
		float mod = modf(frame / (float)_Columns, rowIndex);
		currentSprite.y -= rowIndex * offPerFrame.y;
		currentSprite.x -= rowIndex * _Columns * offPerFrame.x;
		
		spriteUV = (spriteSize + currentSprite); 
	}
	return spriteUV;

}

float4 TexCoords(VertexOutput v)
{
    float4 texcoord;
	texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex);// Always source from uv0
	texcoord.xy = _PixelSampleMode? 
		sharpSample(_MainTex_TexelSize * _MainTex_ST.xyxy, texcoord.xy) : texcoord.xy;

#if _DETAIL 
	texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap);
	texcoord.zw = _PixelSampleMode? 
		sharpSample(_DetailAlbedoMap_TexelSize * _DetailAlbedoMap_ST.xyxy, texcoord.zw) : texcoord.zw;
#else
	texcoord.zw = texcoord.xy;
#endif
    return texcoord;
}

#define UNITY_SAMPLE_TEX2D_SAMPLER_LOD(tex,samplertex,coord,lod) tex.Sample (sampler##samplertex,coord,lod)
#define UNITY_SAMPLE_TEX2D_LOD(tex,coord,lod) tex.Sample (sampler##tex,coord,lod)

half OutlineMask(float2 uv)
{
	// Needs LOD, sampled in vertex function
    return tex2Dlod(_OutlineMask, float4(uv, 0, 0)).r;
}

half ColorMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_ColorMask, _MainTex, uv).g;
}

half RimMask(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER (_ColorMask, _MainTex, uv).b;
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
#if defined(_SUBSURFACE)
	return pow(
		UNITY_SAMPLE_TEX2D_SAMPLER (_ThicknessMap, _MainTex, uv), 
		_ThicknessMapPower);
#else
	return 1;
#endif
}

half3 Albedo(float4 texcoords)
{
    half3 albedo = UNITY_SAMPLE_TEX2D (_MainTex, texcoords.xy).rgb;
    return albedo;
}

SCSS_Input applyDetail(SCSS_Input c, float4 texcoords)
{
	c.albedo *= LerpWhiteTo(_Color.rgb, ColorMask(texcoords.xy));
	c.tone[0].col *= LerpWhiteTo(_Color.rgb, ColorMask(texcoords.xy));
	c.tone[1].col *= LerpWhiteTo(_Color.rgb, ColorMask(texcoords.xy));

#if _DETAIL
    half mask = DetailMask(texcoords.xy);
    half4 detailAlbedo = UNITY_SAMPLE_TEX2D_SAMPLER (_DetailAlbedoMap, _DetailAlbedoMap, texcoords.zw);
    mask *= detailAlbedo.a;
    mask *= _DetailAlbedoMapScale;
    #if _DETAIL_MULX2
        c.albedo *= LerpWhiteTo (detailAlbedo.rgb * unity_ColorSpaceDouble.rgb, mask);
        c.tone[0].col *= LerpWhiteTo (detailAlbedo.rgb * unity_ColorSpaceDouble.rgb, mask);
		c.tone[1].col *= LerpWhiteTo (detailAlbedo.rgb * unity_ColorSpaceDouble.rgb, mask);
    #endif
        // Not implemented: _DETAIL_MUL, _DETAIL_ADD, _DETAIL_LERP
#endif
    return c;
}

half Alpha(float2 uv)
{
	half alpha = _Color.a;
	switch(_AlbedoAlphaMode)
	{
		case 0: alpha *= UNITY_SAMPLE_TEX2D(_MainTex, uv).a; break;
		case 2: alpha *= UNITY_SAMPLE_TEX2D_SAMPLER(_ClippingMask, _MainTex, uv); break;
	}
	return alpha;
}


half4 SpecularGloss(float4 texcoords, half mask)
{
    half4 sg;
#if _SPECULAR
    sg = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecGlossMap, _MainTex, texcoords.xy);

    sg.a = _AlbedoAlphaMode == 1? UNITY_SAMPLE_TEX2D(_MainTex, texcoords.xy).a : sg.a;

    sg.rgb *= _SpecColor;
    sg.a *= _Smoothness; // _GlossMapScale is what Standard uses for this
#else
    sg = _SpecColor;
    sg.a = _AlbedoAlphaMode == 1? UNITY_SAMPLE_TEX2D(_MainTex, texcoords.xy).a : sg.a;
#endif

#if _DETAIL 
		float4 sdm = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecularDetailMask,_DetailAlbedoMap,texcoords.zw);
		sg *= saturate(sdm + 1-(_SpecularDetailStrength*mask));		
#endif

    return sg;
}

half3 Emission(float2 uv)
{
    return UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap, _MainTex, uv).rgb;
}

half4 EmissionDetail(float2 uv)
{
#if _EMISSION 
	uv += _EmissionDetailParams.xy * _Time.y;
	half4 ed = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailEmissionMap, _MainTex, uv);
	if (_EmissionDetailParams.z != 0)
	{
		float s = (sin(ed.r * _EmissionDetailParams.w + _Time.y * _EmissionDetailParams.z))+1;
		ed.rgb = s;
	}
	return ed;
#else
	return 1;
#endif
}

half3 NormalInTangentSpace(float4 texcoords, half mask)
{
	float3 normalTangent = UnpackScaleNormal(UNITY_SAMPLE_TEX2D_SAMPLER(_BumpMap, _MainTex, TRANSFORM_TEX(texcoords.xy, _MainTex)), _BumpScale);
#if _DETAIL 
    half3 detailNormalTangent = UnpackScaleNormal(UNITY_SAMPLE_TEX2D_SAMPLER (_DetailNormalMap, _MainTex, texcoords.zw), _DetailNormalMapScale);
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

// This is based on a typical calculation for tonemapping
// scenes to screens, but in this case we want to flatten
// and shift the image colours.
// Lavender's the most aesthetic colour for this.
float3 AutoToneMapping(float3 color)
{
  	const float A = 0.7;
  	const float3 B = float3(.74, 0.6, .74); 
  	const float C = 0;
  	const float D = 1.59;
  	const float E = 0.451;
	color = max((0.0), color - (0.004));
	color = (color * (A * color + B)) / (color * (C * color + D) + E);
	return color;
}

#if !defined(SCSS_CROSSTONE)
SCSS_TonemapInput Tonemap(float2 uv, inout float occlusion)
{
	SCSS_TonemapInput t = (SCSS_TonemapInput)0;
	float4 _ShadowMask_var = UNITY_SAMPLE_TEX2D_SAMPLER(_ShadowMask, _MainTex, uv.xy);

	// Occlusion
	if (_ShadowMaskType == 0) 
	{
		// RGB will boost shadow range. Raising _Shadow reduces its influence.
		// Alpha will boost light range. Raising _Shadow reduces its influence.
		t.col = saturate(_IndirectLightingBoost+1-_ShadowMask_var.a) * _ShadowMaskColor.rgb;
		t.bias = _ShadowMaskColor.a*_ShadowMask_var.r;
	}
	// Tone
	if (_ShadowMaskType == 1) 
	{
		t.col = saturate(_ShadowMask_var+_IndirectLightingBoost) * _ShadowMaskColor.rgb;
		t.bias = _ShadowMaskColor.a*_ShadowMask_var.a;
	}
	// Auto-Tone
	if (_ShadowMaskType == 2) 
	{
		float3 albedo = Albedo(uv.xyxy);
		t.col = saturate(AutoToneMapping(albedo)+_IndirectLightingBoost) * _ShadowMaskColor.rgb;
		t.bias = _ShadowMaskColor.a*_ShadowMask_var.r;
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
	if (_LightRampType == 3) // No sampling
	{
		return saturate(rampPosition*2-1);
	}
	if (_LightRampType == 2) // None
	{
		float shadeWidth = 0.0002 * (1+softness*100);

		const float shadeOffset = 0.5; 
		float lightContribution = simpleSharpen(rampPosition, shadeWidth, shadeOffset);
		return saturate(lightContribution);
	}
	if (_LightRampType == 1) // Vertical
	{
		float2 rampUV = float2(softness, rampPosition);
		return tex2D(_Ramp, saturate(rampUV));
	}
	else // Horizontal
	{
		float2 rampUV = float2(rampPosition, softness);
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
	return t;
}
SCSS_TonemapInput Tonemap2nd (float2 uv)
{
	float4 tonemap = UNITY_SAMPLE_TEX2D_SAMPLER(_2nd_ShadeMap, _MainTex, uv.xy);
	tonemap.rgb *= _2nd_ShadeColor;
	SCSS_TonemapInput t = (SCSS_TonemapInput)1;
	t.col = tonemap.rgb;
	t.bias = tonemap.a;
	return t;
}

float adjustShadeMap(float x, float y)
{
	// Might be changed later.
	return (x * (1+y));

}

float ShadingGradeMap (float2 uv)
{
	float4 tonemap = UNITY_SAMPLE_TEX2D_SAMPLER(_ShadingGradeMap, _MainTex, uv.xy);
	// Red to match UCTS
	return adjustShadeMap(tonemap.r, _Tweak_ShadingGradeMapLevel);
}
#endif

float innerOutline (VertexOutput i)
{
	// The compiler should merge this with the later calls.
	// Use the vertex normals for this to avoid artifacts.
	SCSS_LightParam d = initialiseLightParam((SCSS_Light)0, i.normalDir, i.posWorld.xyz);
	float baseRim = d.NdotV;
	baseRim = simpleSharpen(baseRim, 0, _InteriorOutlineWidth * OutlineMask(i.uv0.xy));
	return baseRim;
}

float3 applyOutline(float3 col, float is_outline)
{    
	col = lerp(col, col * _outline_color.rgb, is_outline);
    if (_OutlineMode == 2) 
    {
        col = lerp(col, _outline_color.rgb, is_outline);
    }
    return col;
}

SCSS_Input applyOutline(SCSS_Input c, float is_outline)
{

	c.albedo = applyOutline(c.albedo, is_outline);
    if (_CrosstoneToneSeparation) c.tone[0].col = applyOutline(c.tone[0].col, is_outline);
	if (_Crosstone2ndSeparation)  c.tone[1].col = applyOutline(c.tone[1].col, is_outline);

    return c;
}

void applyVanishing (inout float alpha) {
    const fixed3 baseWorldPos = unity_ObjectToWorld._m03_m13_m23;
    float closeDist = distance(_WorldSpaceCameraPos, baseWorldPos);
    float vanishing = saturate(lerpstep(_VanishingStart, _VanishingEnd, closeDist));
    alpha = lerp(alpha, alpha * vanishing, _UseVanishing);
}

#endif // SCSS_INPUT_INCLUDED