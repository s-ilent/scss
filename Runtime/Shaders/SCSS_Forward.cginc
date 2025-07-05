#ifndef SCSS_FORWARD_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_FORWARD_INCLUDED

#include "SCSS_Attributes.cginc" 
#include "SCSS_ForwardVertex.cginc"

void prepareMaterial (inout SCSS_ShadingParam shading, const SCSS_Input material) {
    shading.normal = normalize(mul(shading.tangentToWorld, material.normalTangent));
    shading.NoV = clampNoV(dot(shading.normal, shading.view));
    shading.reflected = reflect(-shading.view, shading.normal);
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

float3 applyMaskedHSVToAlbedo(float3 albedo, float mask, float shiftHue, float shiftSat, float shiftVal)
{
	// HSV tinting, masked by tint mask
	float3 warpedAlbedo = TransformHSV(albedo, shiftHue, shiftSat, shiftVal);
	return lerp(albedo, saturate(warpedAlbedo), mask);
}

void applySpecularGloss(inout SCSS_Input material, float2 uv, float oneMinusOutline)
{
    half4 specGloss;
#if defined(_SPECULAR)
    specGloss = UNITY_SAMPLE_TEX2D_SAMPLER(_SpecGlossMap, _MainTex, uv);

    specGloss.a = _AlbedoAlphaMode == 1? UNITY_SAMPLE_TEX2D(_MainTex, uv).a : specGloss.a;

    specGloss.rgb *= _SpecColor * _SpecColor.a; // Use alpha as an overall multiplier
    specGloss.a *= _Smoothness; // _GlossMapScale is what Standard uses for this
	
	material.specColor = specGloss.rgb;
	material.smoothness = specGloss.a;

	// This should be an option later.
	material.specOcclusion = saturate(material.occlusion);

	if (_UseMetallic == 1)
	{
		// In Metallic mode, ignore the other colour channels. 
		material.specColor = specGloss.r;
		// Treat as a packed map. 
		material.specOcclusion = specGloss.g;
	}

	// Because specular behaves poorly on backfaces, disable specular on outlines. 
	material.specColor  *= oneMinusOutline;
	material.smoothness *= oneMinusOutline;

	// Specular energy converservation. From EnergyConservationBetweenDiffuseAndSpecular in UnityStandardUtils.cginc
	material.oneMinusReflectivity = 1 - SpecularStrength_local(material.specColor); 

	if (_UseMetallic == 1)
	{
		// From DiffuseAndSpecularFromMetallic
		material.oneMinusReflectivity = OneMinusReflectivityFromMetallic_local(material.specColor);
		material.specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, material.albedo, material.specColor);
	}

	if (_UseEnergyConservation == 1)
	{
		material.albedo.xyz = material.albedo.xyz * (material.oneMinusReflectivity); 
		if (_CrosstoneToneSeparation) material.tone[0].col = material.tone[0].col * (material.oneMinusReflectivity); 
		if (_Crosstone2ndSeparation)  material.tone[1].col = material.tone[1].col * (material.oneMinusReflectivity); 
	}
	
#endif
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
SCSS_TonemapInput LightrampTonemap(float2 uv)
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
			float3 albedo = UNITY_SAMPLE_TEX2D(_MainTex, uv);
			t.col = saturate(AutoToneMapping(albedo)+_IndirectLightingBoost) * _ShadowMaskColor.rgb;
			t.bias = _ShadowMaskColor.a*_ShadowMask_var.r;
			break;
		case 3: // Median
			// Single channel texture (R) where 0.5 is neutral
			// TODO
			break;
	}

	t.bias = (1 - _Shadow) * t.bias + _Shadow;
	return t;
}
#endif

#if defined(SCSS_CROSSTONE)
// Tonemaps contain tone in RGB, occlusion in A.
// Midpoint/width is handled in the application function.
SCSS_TonemapInput CrosstoneTonemap1st (float2 uv)
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
SCSS_TonemapInput CrosstoneTonemap2nd (float2 uv)
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

float CrosstoneShadingGradeMap (float2 uv)
{
	float tonemap = UNITY_SAMPLE_TEX2D_SAMPLER(_ShadingGradeMap, _MainTex, uv.xy).r;
	// Red to match UCTS
	return adjustShadeMap(tonemap, _Tweak_ShadingGradeMapLevel);
}
#endif

void applyVertexColour(float4 color, inout SCSS_Input c)
{
	// Outline width/etc is passed through extraData, and alpha is passed through alpha.
	// But if we're in custom data mode, the outline alpha will be in the vertex red channel instead.
	float vertexAlpha = _VertexColorAType == 5 ? color.a : 1.0;
	float outlineAlpha = _VertexColorAType == 6 ? color.a : 1.0;
	switch (_VertexColorType)
	{
		// Color
		case 0: 
		c.albedo = c.albedo * color; 
		if (_CrosstoneToneSeparation) c.tone[0].col *= color.rgb; 
		if (_Crosstone2ndSeparation) c.tone[1].col *= color.rgb; 
		c.outlineCol.rgb = color * _outline_color;
		c.outlineCol.a = _outline_color.a * outlineAlpha;
		c.alpha = c.alpha * vertexAlpha;
		break;

		// Custom Data
		case 2:
		c.outlineCol.rgb = _outline_color;
		c.outlineCol.a = _outline_color.a * color.r;
		c.alpha = c.alpha * color.a;
		break;
		
		// Outline Color
		// color is color (passed from vertex)
		// Additional Data/Ignore/Outline Width
		// color is white (reset from vertex)
		default: 
		c.outlineCol.rgb = color * _outline_color;
		c.outlineCol.a = _outline_color.a * outlineAlpha;
		c.alpha = c.alpha * vertexAlpha;
		break;

	}
}

float3 applyOutlineColor(float3 col, float3 outlineCol, float is_outline)
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

void applyOutline(inout SCSS_Input c, float is_outline)
{
	c.albedo = applyOutlineColor(c.albedo, c.outlineCol, is_outline);
    if (_CrosstoneToneSeparation) c.tone[0].col = applyOutlineColor(c.tone[0].col, c.outlineCol, is_outline);
	if (_Crosstone2ndSeparation)  c.tone[1].col = applyOutlineColor(c.tone[1].col, c.outlineCol, is_outline);
	c.alpha = applyOutlineAlpha(c.alpha, c.outlineCol.a, is_outline);
}

void applyFur(inout SCSS_Input material, SCSS_TexCoords tc, float furDepth)
{
	#if defined(SCSS_FUR)
	float furNoise = UNITY_SAMPLE_TEX2D_SAMPLER(_FurNoise, _MainTex, applyScaleOffset(tc.uv[0], _FurNoise_ST));
	if (furDepth > 0)
	{
		float furFalloff = pow((1.0 - furDepth), abs(_FurThickness));
		material.alpha = material.alpha * furNoise;
		// Alpha sharpen is used for the cutoff, but we can use it here too.
		applyAlphaSharpen(material.alpha, 1.0 - furFalloff);
	}

	float furAO = depthBlend(furDepth, furNoise);
	material.albedo *= gtaoMultiBounce(furAO, material.albedo);
	if (_CrosstoneToneSeparation) material.tone[0].col *= gtaoMultiBounce(furAO, material.tone[0].col);
	if (_Crosstone2ndSeparation) material.tone[1].col *= gtaoMultiBounce(furAO, material.tone[1].col);

	#endif
}

void applyMaskedDetail (inout SCSS_Input material, SCSS_TexCoords tc)
{
	#if defined(_DETAIL)
    {
        float4 _DetailMask_var = UNITY_SAMPLE_TEX2D_SAMPLER (_DetailAlbedoMask, _MainTex, tc.uv[0]);
        if (any(_DetailMap1_TexelSize > 4.0)) applyDetail(material, _DetailMap1, applyScaleOffset(tc.uv[_DetailMap1UV], _DetailMap1_ST), 
			_DetailMap1Type, _DetailMap1Blend, _DetailMap1Strength * _DetailMask_var[0]);
        if (any(_DetailMap2_TexelSize > 4.0)) applyDetail(material, _DetailMap2, applyScaleOffset(tc.uv[_DetailMap2UV], _DetailMap2_ST), 
			_DetailMap2Type, _DetailMap2Blend, _DetailMap2Strength * _DetailMask_var[1]);
        if (any(_DetailMap3_TexelSize > 4.0)) applyDetail(material, _DetailMap3, applyScaleOffset(tc.uv[_DetailMap3UV], _DetailMap3_ST), 
			_DetailMap3Type, _DetailMap3Blend, _DetailMap3Strength * _DetailMask_var[2]);
        if (any(_DetailMap4_TexelSize > 4.0)) applyDetail(material, _DetailMap4, applyScaleOffset(tc.uv[_DetailMap4UV], _DetailMap4_ST), 
			_DetailMap4Type, _DetailMap4Blend, _DetailMap4Strength * _DetailMask_var[3]);
    }
	#endif
}

void applyMatcaps(inout float3 albedo, float3 normal, float3 viewDir, float3 bitangentDir, float2 matcapMaskUVs)
{
	if (_UseMatcap >= 1) 
	{
		half2 matcapUV;
		if (_UseMatcap == 1) matcapUV = getMatcapUVsOriented(normal, viewDir, float3(0, 1, 0));
		if (_UseMatcap == 2) matcapUV = getMatcapUVsOriented(normal, viewDir, bitangentDir);

		float4 _MatcapMask_var = UNITY_SAMPLE_TEX2D_SAMPLER (_MatcapMask, _MainTex, matcapMaskUVs);
		albedo = applyMatcap(_Matcap1, matcapUV, albedo, _Matcap1Tint, _Matcap1Blend, _Matcap1Strength * _MatcapMask_var.r);
		albedo = applyMatcap(_Matcap2, matcapUV, albedo, _Matcap2Tint, _Matcap2Blend, _Matcap2Strength * _MatcapMask_var.g);
		albedo = applyMatcap(_Matcap3, matcapUV, albedo, _Matcap3Tint, _Matcap3Blend, _Matcap3Strength * _MatcapMask_var.b);
		albedo = applyMatcap(_Matcap4, matcapUV, albedo, _Matcap4Tint, _Matcap4Blend, _Matcap4Strength * _MatcapMask_var.a);
	}	
}

void applyEmission(inout SCSS_Input material, SCSS_TexCoords tc, float outlineDarken, float ndotv)
{
    half3 emission = 1.0;
    half4 emissionDetail = 1.0;

#if defined(_EMISSION)
    float2 texcoord = tc.uv[_EmissionUVSec];
    texcoord = TRANSFORM_TEX(texcoord, _EmissionMap);
    texcoord = _PixelSampleMode ? sharpSample(_EmissionMap_TexelSize * _EmissionMap_ST.xyxy, texcoord) : texcoord;

    float2 detailTexcoord = tc.uv[_DetailEmissionUVSec];
    detailTexcoord = TRANSFORM_TEX(detailTexcoord, _DetailEmissionMap);
	detailTexcoord += _EmissionDetailParams.xy * _Time.y;
    detailTexcoord = _PixelSampleMode ? sharpSample(_DetailEmissionMap_TexelSize * _DetailEmissionMap_ST.xyxy, detailTexcoord) : detailTexcoord;

    emission = UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap, _MainTex, texcoord).rgb;
    emission = _EmissionMode ? emission * material.albedo : emission;

    if (any(_DetailEmissionMap_TexelSize.zw > 4.0))
    {
        emissionDetail = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailEmissionMap, _DetailEmissionMap, detailTexcoord);
        if (_EmissionDetailParams.z != 0.0)
        {
            float s = dot((0.5 * sin(emissionDetail.rgb * _EmissionDetailParams.w + _Time.y * _EmissionDetailParams.z)) + 0.5, 1.0 / 3.0);
            emissionDetail.rgb = s;
        }
    }
#endif

    emission = emissionDetail.rgb * emission * _EmissionColor.rgb;
    emission *= outlineDarken * simpleRimHelper(_EmissionRimPower, ndotv);
    material.emission += half4(emission, 0.0);
}

void applyEmission2nd(inout SCSS_Input material, SCSS_TexCoords tc, float outlineDarken, float ndotv)
{
    half3 emission = 1.0;
    half4 emissionDetail = 1.0;

#if defined(_EMISSION_2ND)
    float2 texcoord = tc.uv[_EmissionUVSec2nd];
    texcoord = TRANSFORM_TEX(texcoord, _EmissionMap2nd);
    texcoord = _PixelSampleMode ? sharpSample(_EmissionMap2nd_TexelSize * _EmissionMap2nd_ST.xyxy, texcoord) : texcoord;

    float2 detailTexcoord = tc.uv[_DetailEmissionUVSec2nd];
    detailTexcoord = TRANSFORM_TEX(detailTexcoord, _DetailEmissionMap2nd);
	detailTexcoord += _EmissionDetailParams2nd.xy * _Time.y;
    detailTexcoord = _PixelSampleMode ? sharpSample(_DetailEmissionMap2nd_TexelSize * _DetailEmissionMap2nd_ST.xyxy, detailTexcoord) : detailTexcoord;

    emission = UNITY_SAMPLE_TEX2D_SAMPLER(_EmissionMap2nd, _MainTex, texcoord).rgb;
    emission = _EmissionMode2nd ? emission * material.albedo : emission;

    if (any(_DetailEmissionMap2nd_TexelSize.zw > 4.0))
    {
        emissionDetail = UNITY_SAMPLE_TEX2D_SAMPLER(_DetailEmissionMap2nd, _DetailEmissionMap2nd, detailTexcoord);
        if (_EmissionDetailParams2nd.z != 0.0)
        {
            float s = dot((0.5 * sin(emissionDetail.rgb * _EmissionDetailParams2nd.w + _Time.y * _EmissionDetailParams2nd.z)) + 0.5, 1.0 / 3.0);
            emissionDetail.rgb = s;
        }
    }
#endif

    emission = emissionDetail.rgb * emission * _EmissionColor2nd.rgb;
    emission *= outlineDarken * simpleRimHelper(_EmissionRimPower2nd, ndotv);
    material.emission += half4(emission, 0.0);
}

void applyEmissiveAudioLink(inout SCSS_Input material, SCSS_TexCoords tc)
{
#if defined(_AUDIOLINK)
    float2 maskTexcoord = tc.uv[_AudiolinkMaskMapUVSec];
    maskTexcoord = TRANSFORM_TEX(maskTexcoord, _AudiolinkMaskMap);

    float2 sweepTexcoord = tc.uv[_AudiolinkSweepMapUVSec];
    sweepTexcoord = TRANSFORM_TEX(sweepTexcoord, _AudiolinkSweepMap);

    // Load mask texture
    half4 mask = UNITY_SAMPLE_TEX2D_SAMPLER(_AudiolinkMaskMap, _MainTex, maskTexcoord);
    // Load weights texture
    half4 weights = UNITY_SAMPLE_TEX2D_SAMPLER(_AudiolinkSweepMap, _MainTex, sweepTexcoord);

	// Apply a small epsilon to the weights to avoid artifacts.
    const float epsilon = (1.0 / 255.0);
    weights = saturate(weights - epsilon);

    half3 audioLinkColor = 0;
    audioLinkColor += (_alBandR >= 1) ? audioLinkGetLayer(weights.r, _alTimeRangeR, _alBandR, _alModeR) * _alColorR : 0;
    audioLinkColor += (_alBandG >= 1) ? audioLinkGetLayer(weights.g, _alTimeRangeG, _alBandG, _alModeG) * _alColorG : 0;
    audioLinkColor += (_alBandB >= 1) ? audioLinkGetLayer(weights.b, _alTimeRangeB, _alBandB, _alModeB) * _alColorB : 0;
    audioLinkColor += (_alBandA >= 1) ? audioLinkGetLayer(weights.a, _alTimeRangeA, _alBandA, _alModeA) * _alColorA : 0;

    material.emission += half4(audioLinkColor * mask * _AudiolinkIntensity, 0.0);  // Accumulate audiolink emission
#endif
}

void applyRimLight(inout SCSS_Input material, float NdotH, float rlPow4, float outlineDarken)
{
	if (_UseFresnel)
	{
		float fresnelLightMaskBase = LerpOneTo_local(NdotH, _UseFresnelLightMask);
		float fresnelLightMask = 
			saturate(pow(saturate( fresnelLightMaskBase), _FresnelLightMask));
		float fresnelLightMaskInv = 
			saturate(pow(saturate(-fresnelLightMaskBase), _FresnelLightMask));

		// Refactored to use more ifs because the compiler is smarter than me.
		float rimBase = sharpenLighting(rlPow4 * material.rim.width * fresnelLightMask, material.rim.power) * material.rim.alpha;
		float3 rimCol = rimBase * material.rim.tint;

		float rimInv = sharpenLighting(rlPow4 * material.rim.invWidth * fresnelLightMaskInv,
			material.rim.invPower) * _FresnelLightMask * material.rim.invAlpha;
		float3 rimInvCol = rimInv * material.rim.invTint;

		float3 rimFinal = rimCol + rimInvCol;

		float applyToAlbedo = (_UseFresnel == 1) + (_UseFresnel == 4);
		float applyToFinal = (_UseFresnel == 2);
		float applyToLightBias = (_UseFresnel == 3) + (_UseFresnel == 4);
		// Lit
		if (applyToAlbedo) material.albedo += material.albedo * rimFinal * outlineDarken;
		// AmbientAlt
		if (applyToLightBias) material.occlusion += saturate(rimBase) * outlineDarken;
		// Ambient
		// If applied to the final output, it can only be applied later.
		if (applyToFinal) material.albedo += rimFinal * outlineDarken;
	}
}

void applyHatching(inout SCSS_Input material, float3 viewDir, float3 worldPos)
{	
	#if defined(_HATCHING)
	float4 baseWorldPos = mul(unity_ObjectToWorld,float4( 0,0,0,1 ));

	float3 hatchingOffset = (_HatchingMovementFPS > 0) 
		? r3_modified(floor(_Time.y * _HatchingMovementFPS), baseWorldPos)
		: 0;
	
	float3 hatchingPos = _HatchingScale * viewDir * floor( distance( baseWorldPos , float4( _WorldSpaceCameraPos , 0.0 ) ) );

	float4 hatchingTex = SampleTexture2DBiplanar(_HatchingTex, hatchingOffset+hatchingPos, viewDir, 16.0);

	material.occlusion = material.occlusion * LerpWhiteTo_local(hatchingTex.g, _HatchingShadingMul) + (hatchingTex.g * _HatchingShadingAdd);
	material.rim.width *= 1 + (hatchingTex.g * _HatchingRimAdd * 10);
	material.albedo *= LerpWhiteTo_local(hatchingTex.g, _HatchingAlbedoMul);
	#endif
}

#include "SCSS_Lighting.cginc"

inline SCSS_Input MaterialSetup(SCSS_TexCoords tc,
	float4 i_color, float4 i_extraData, float p_isOutline, float p_furDepth, uint facing)
{
	SCSS_Input material = (SCSS_Input)0;
	initMaterial(material);

	// Note: Outline colour is part of the material data, but is set by applyVertexColour. 
	
	float2 mainUVs = TexCoords(tc);

	// Fade some effects on outlines. 
	// Note that MSAA means this isn't a strictly binary thing.
    half outlineDarken = 1-p_isOutline;

	// Setup albedo 
	float4 mainTex = UNITY_SAMPLE_TEX2D (_MainTex, mainUVs);
	#if defined(_BACKFACE)
		if (!facing) mainTex = UNITY_SAMPLE_TEX2D_SAMPLER (_MainTexBackface, _MainTex, mainUVs);
	#endif
	material.albedo = mainTex.rgb;

	#if defined(_BACKFACE)
	float4 tintColorAlpha = facing? _Color : _ColorBackface;
	#else
	float4 tintColorAlpha = _Color;
	#endif

	// Setup alpha
	material.alpha = tintColorAlpha.a;
	switch(_AlbedoAlphaMode)
	{
		case 0: material.alpha *= mainTex.a; break;
		case 2: material.alpha *= ClippingMask(tc.uv[0]); break;
	}
	
	// Workaround for Unity's bad BC7 texture encoding that makes opaque areas slightly transparent
	const float alphaFix = 1.0 / ((255.0 - 8.0)/255.0);
	material.alpha = saturate(material.alpha * alphaFix);

	// Setup misc. masks
	float4 colorMaskTex = UNITY_SAMPLE_TEX2D_SAMPLER (_ColorMask, _MainTex, mainUVs);
	float tintMask = colorMaskTex.g;
	float rimMask = colorMaskTex.b;

	// Setup normal map
    material.normalTangent = NormalInTangentSpace(mainUVs);

    // Todo: Allow passing anisotropy direction
    material.anisotropyDirection = float3(1, 0, 0);

	#if !defined(SCSS_CROSSTONE)
		material.tone[0] = LightrampTonemap(mainUVs);
	#endif

	#if defined(SCSS_CROSSTONE)
		material.tone[0] = CrosstoneTonemap1st(mainUVs);
		material.tone[1] = CrosstoneTonemap2nd(mainUVs);
		material.occlusion = CrosstoneShadingGradeMap(mainUVs);
	#endif

	switch (_SDFMode)
	{
		#if defined(SCSS_CROSSTONE)
		#define SDF_SOURCE _ShadingGradeMap
		#else
		#define SDF_SOURCE _ShadowMask
		#endif
		case 1:
		float sdfL = UNITY_SAMPLE_TEX2D_SAMPLER(SDF_SOURCE, _MainTex, mainUVs).r;
		float sdfR = UNITY_SAMPLE_TEX2D_SAMPLER(SDF_SOURCE, _MainTex, mainUVs * float2(-1, 1)).r;
		material.sdf = float2(sdfL, sdfR);
		material.occlusion = 1.0;
		material.sdfSmoothness = _SDFSmoothness;
		break;

		case 2:
		material.sdf = UNITY_SAMPLE_TEX2D_SAMPLER(SDF_SOURCE, _MainTex, mainUVs);
		material.occlusion = 1.0;
		material.sdfSmoothness = _SDFSmoothness;
		break;
		#undef SDF_SOURCE
	}

	// Apply vertex colour to albedo and tones if selected
	applyVertexColour(i_color, material);

	// Todo: Refactor this 
	if (_ToggleHueControls)
	{
		material.albedo = applyMaskedHSVToAlbedo(material.albedo, tintMask, _ShiftHue, _ShiftSaturation, _ShiftValue);
		material.tone[0].col = applyMaskedHSVToAlbedo(material.tone[0].col, tintMask, _ShiftHue, _ShiftSaturation, _ShiftValue);
		material.tone[1].col = applyMaskedHSVToAlbedo(material.tone[1].col, tintMask, _ShiftHue, _ShiftSaturation, _ShiftValue);
	}

	material.albedo *= LerpWhiteTo_local(tintColorAlpha, tintMask);
	if (_CrosstoneToneSeparation) material.tone[0].col *= LerpWhiteTo_local(tintColorAlpha, tintMask);
	if (_Crosstone2ndSeparation) material.tone[1].col *= LerpWhiteTo_local(tintColorAlpha, tintMask);
	
	// Scattering parameters
	material.thickness = Thickness(mainUVs);
	
	material.softness *= i_extraData.g;
	material.occlusion *= i_extraData.a;

	applyOutline(material, p_isOutline);

	applyFur(material, tc, p_furDepth);

    // Rim lighting parameters. 
	material.rim = initialiseRimParam();
	material.rim.alpha *= rimMask;
	material.rim.invAlpha *= rimMask;
	material.rim.tint *= outlineDarken;

	applySpecularGloss(material, tc.uv[0], outlineDarken);

	applyMaskedDetail(material, tc);

	return material;
}

#if !defined(UNITY_PASS_SHADOWCASTER)
inline void MaterialSetupPostParams(inout SCSS_Input material, SCSS_ShadingParam p, SCSS_TexCoords tc)
{    
	// Local light parameters. These are a bit redundant, but maybe there's a way to clean them out.

	// Darken some effects on outlines. 
	// Note that MSAA means this isn't a strictly binary thing.
    half outlineDarken = 1-p.isOutline;

	SCSS_Light l = MainLight(p.position.xyz);
	SCSS_LightParam d = initialiseLightParam(l, p);

	// Todo: Clean this up
	float rlPow4 = Pow4(1 - p.NoV);
	float3 bitangentDir = p.tangentToWorld[1].xyz;

	applyEmission(material, tc, outlineDarken, d.NdotV);
	applyEmission2nd(material, tc, outlineDarken, d.NdotV);
	applyEmissiveAudioLink(material, tc);

	#if defined(_SPECULAR)
	{
		float4 specIrid = Iridescence(p.NoV, 0);
		material.specColor *= specIrid;
		// This looks ugly, but it's useful
		material.albedo *= lerp(specIrid.a, 1.0, material.oneMinusReflectivity);
		material.oneMinusReflectivity = OneMinusReflectivityFromMetallic_local(material.specColor);
	};
	#endif // _SPECULAR

	applyHatching(material, p.view, p.position);

	applyRimLight(material, d.NdotH, rlPow4, outlineDarken);
	
	// Apply matcap before specular effect.
	applyMatcaps(material.albedo, p.normal, p.view, bitangentDir, tc.uv[0]);
}

float4 frag(VertexOutput i, uint facing : SV_IsFrontFace
    #if defined(USING_COVERAGE_OUTPUT)
	, out uint cov : SV_Coverage
	#endif
	) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

	SCSS_ShadingParam p = (SCSS_ShadingParam) 0;
	computeShadingParams(p, i, facing);

	// Note that discard applies even to pixels that are opaque, but it's safe
	// to perform here because any pixel with a front-facing outline has something behind it. 
	if (p.isOutline && !facing) discard;

	// Ideally, we should pass all input to lighting functions through the 
	// material parameter struct. But there are some things that are
	// optional. Review this at a later date...

	// There are also some things that need to be handled after calculation
	// of the normal parameters and etc: fresnel and matcaps. 

	// Texcoords are calculated in too many places because of the slow but incomplete
	// shift from "everything using the same as main texture" to individual selection
	// for UV channel, and then scale/offset. 
	SCSS_TexCoords mainUVs = initialiseTexCoords(i.uvPack0, i.uvPack1);

	SCSS_Input material = 
	MaterialSetup(mainUVs, i.color, i.extraData, p.isOutline, p.furDepth, facing);

	#if !defined(USING_TRANSPARENCY)
		material.alpha = 1.0;
	#else
	    #if defined(ALPHAFUNCTION)
	    alphaFunction(material.alpha);
		#endif

		applyVanishing(material.alpha);
		
		applyAlphaClip(material.alpha, _Cutoff, i.pos.xy, _AlphaSharp, false);
	#endif

    // When premultiplied mode is set, this will multiply the diffuse by the alpha component,
    // allowing to handle transparency in physically correct way - only diffuse component gets affected by alpha
    half outputAlpha;
    material.albedo = PreMultiplyAlpha_local (material.albedo, material.alpha, material.oneMinusReflectivity, 
		/*out*/ outputAlpha);

    prepareMaterial(p, material);

    MaterialSetupPostParams(material, p, mainUVs);

	// Lighting handling
	float3 finalColor = SCSS_ApplyLighting(material, p);

	// Workaround a compiler issue when albedo is not needed but its sampler is.
	finalColor += material.albedo * FLT_EPS;

	float4 nearShading = getNearShading(i.worldPos.xyz, facing);
	finalColor.rgb = lerp(finalColor, nearShading.rgb, nearShading.a);

    #if defined(USING_COVERAGE_OUTPUT)
		cov = 1.0;
		// Get the amount of MSAA samples enabled
		uint samplecount = GetRenderTargetSampleCount();

		// center out the steps
		outputAlpha = saturate(outputAlpha) * samplecount + 0.5;

		// Shift and subtract to get the needed amount of positive bits
		cov = (1u << (uint)(outputAlpha)) - 1u;

		// Output 1 as alpha, otherwise result would be a^2
		outputAlpha = 1;
	#endif

	fixed4 finalRGBA = fixed4(finalColor, outputAlpha);

	#if defined(SCSS_USE_UNITY_FOG)
	applyUnityFog(finalRGBA, UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w));
	#endif

	return finalRGBA;
}

#endif // !UNITY_PASS_SHADOWCASTER
#endif // SCSS_FORWARD_INCLUDED