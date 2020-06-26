#ifndef SCSS_CORE_INCLUDED

#define SCSS_CORE_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

// Perform full-quality light calculations on unimportant lights.
// Considering our target GPUs, this is a big visual improvement
// for a small performance penalty.
#define SCSS_UNIMPORTANT_LIGHTS_FRAGMENT 1

// When rendered by a non-HDR camera, clamp incoming lighting.
// This works around issues where scenes are set up incorrectly
// for non-HDR.
#define SCSS_CLAMP_IN_NON_HDR 1

// When screen-space shadows are used in the scene, performs a
// search to find the best sampling point for the shadow
// using the camera's depth buffer. This filters away many aliasing
// artifacts caused by limitations in the screen shadow technique
// used by directional lights.
#define SCSS_SCREEN_SHADOW_FILTER 1

#include "SCSS_UnityGI.cginc"
#include "SCSS_Utils.cginc"
#include "SCSS_Input.cginc"

// Shade4PointLights from UnityCG.cginc but only returns their attenuation.
float4 Shade4PointLightsAtten (
    float4 lightPosX, float4 lightPosY, float4 lightPosZ,
    float4 lightAttenSq,
    float3 pos, float3 normal)
{
    // to light vectors
    float4 toLightX = lightPosX - pos.x;
    float4 toLightY = lightPosY - pos.y;
    float4 toLightZ = lightPosZ - pos.z;
    // squared lengths
    float4 lengthSq = 0;
    lengthSq += toLightX * toLightX;
    lengthSq += toLightY * toLightY;
    lengthSq += toLightZ * toLightZ;
    // don't produce NaNs if some vertex position overlaps with the light
    lengthSq = max(lengthSq, 0.000001);

    // NdotL
    float4 ndotl = 0;
    ndotl += toLightX * normal.x;
    ndotl += toLightY * normal.y;
    ndotl += toLightZ * normal.z;
    // correct NdotL
    float4 corr = 0;//rsqrt(lengthSq);
    corr.x = fastRcpSqrtNR0(lengthSq.x);
    corr.y = fastRcpSqrtNR0(lengthSq.y);
    corr.z = fastRcpSqrtNR0(lengthSq.z);
    corr.w = fastRcpSqrtNR0(lengthSq.x);

    ndotl = corr * (ndotl * 0.5 + 0.5); // Match with Forward for light ramp sampling
    ndotl = max (float4(0,0,0,0), ndotl);
    // attenuation
    // Fixes popin. Thanks, d4rkplayer!
    float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
	float4 atten2 = saturate(1 - (lengthSq * lightAttenSq / 25));
	atten = min(atten, atten2 * atten2);

    float4 diff = ndotl * atten;
    #if defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
    return atten;
    #else
    return diff;
    #endif
}

// Based on Standard Shader's forwardbase vertex lighting calculations in VertexGIForward
// This revision does not pass the light values themselves, but only their attenuation.
inline half4 VertexLightContribution(float3 posWorld, half3 normalWorld)
{
	half4 vertexLight = 0;

	// Static lightmaps
	#ifdef LIGHTMAP_ON
		return 0;
	#elif UNITY_SHOULD_SAMPLE_SH
		#ifdef VERTEXLIGHT_ON
			// Approximated illumination from non-important point lights
			vertexLight = Shade4PointLightsAtten(
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_4LightAtten0, posWorld, normalWorld);
		#endif
	#endif

	return vertexLight;
}

#if defined(_SUBSURFACE)
//SSS method from GDC 2011 conference by Colin Barre-Bresebois & Marc Bouchard and modified by Xiexe
float3 getSubsurfaceScatteringLight (SCSS_Light l, float3 normalDirection, float3 viewDirection, 
    float attenuation, float3 thickness, float3 indirectLight = 0)
{
    float3 vSSLight = l.dir + normalDirection * _SSSDist; // Distortion
    float3 vdotSS = pow(saturate(dot(viewDirection, -vSSLight)), _SSSPow) 
        * _SSSIntensity; 
    
    return lerp(1, attenuation, float(any(_WorldSpaceLightPos0.xyz))) 
                * (vdotSS + _SSSAmbient) * abs(_ThicknessMapInvert-thickness)
                * (l.color + indirectLight) * _SSSCol;
                
}
#endif

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
		float shadeWidth = max(fwidth(rampPosition), 0.002 * (1+softness*10));

		const float shadeOffset = 0.5; 
		float lightContribution = smoothstep(shadeOffset-shadeWidth, shadeOffset+shadeWidth, frac(rampPosition)) + floor(rampPosition); 
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

float3 sampleCrossToneLighting(float x, SCSS_TonemapInput tone0, SCSS_TonemapInput tone1)
{
	// A three-tiered tone system.
	// Input x is potentially affected by occlusion map.
	half offset0 = _1st_ShadeColor_Step * tone0.bias; 
	half width0  = _1st_ShadeColor_Feather;
	half factor0 = saturate(simpleSharpen(x, width0, offset0));

	half offset1 = _2nd_ShadeColor_Step * tone1.bias; 
	half width1  = _2nd_ShadeColor_Feather;
	half factor1 = saturate(simpleSharpen(x, width1, offset1));

	float3 final;
	final = lerp(tone1.col, tone0.col, factor1);
	final = lerp(final, 1.0, factor0);
	return final;

	// v0 + t * (v1 - v0);
}

float applyShadowLift(float baseLight, float occlusion)
{
	baseLight *= occlusion;
	baseLight = _ShadowLift + baseLight * (1-_ShadowLift);
	return baseLight;
}

float applyShadowLift(float4 baseLight, float occlusion)
{
	baseLight *= occlusion;
	baseLight = _ShadowLift + baseLight * (1-_ShadowLift);
	return baseLight;
}

float getRemappedLight(half perceptualRoughness, SCSS_LightParam d)
{
	float diffuseShadowing = DisneyDiffuse(abs(d.NdotV), abs(d.NdotL), d.LdotH, perceptualRoughness);
	float remappedLight = d.NdotL * LerpOneTo(diffuseShadowing, _DiffuseGeomShadowFactor);
	return remappedLight;
}

float applyAttenuation(half NdotL, half attenuation)
{
	#if defined(SCSS_CROSSTONE)
	//attenuation = round(attenuation);
	half shadeVal = _1st_ShadeColor_Step - _1st_ShadeColor_Feather * 0.5;
	shadeVal = shadeVal-0.01;
	//NdotL = min(lerp(shadeVal, NdotL, attenuation), NdotL);
	NdotL = lerp(shadeVal*NdotL, NdotL, attenuation);
	#else
	NdotL = min(NdotL * attenuation, NdotL);
	//NdotL = lerp(0.5, NdotL, attenuation);
	#endif
	return NdotL;
}

half3 calcVertexLight(float4 vertexAttenuation, float occlusion, float3 tonemap, half softness)
{
	float3 vertexContribution = 0;
	#if defined(UNITY_PASS_FORWARDBASE)
		// Vertex lighting based on Shade4PointLights
		float4 vertexAttenuationFalloff = saturate(vertexAttenuation * 10);
		vertexAttenuation = applyShadowLift(vertexAttenuation, occlusion);

	    vertexContribution += unity_LightColor[0] * (sampleRampWithOptions(vertexAttenuation.x, softness)+tonemap) * vertexAttenuationFalloff.x;
	    vertexContribution += unity_LightColor[1] * (sampleRampWithOptions(vertexAttenuation.y, softness)+tonemap) * vertexAttenuationFalloff.y;
	    vertexContribution += unity_LightColor[2] * (sampleRampWithOptions(vertexAttenuation.z, softness)+tonemap) * vertexAttenuationFalloff.z;
	    vertexContribution += unity_LightColor[3] * (sampleRampWithOptions(vertexAttenuation.w, softness)+tonemap) * vertexAttenuationFalloff.w;
	#endif
	return vertexContribution;
}

void getDirectIndirectLighting(float3 normal, inout float3 directLighting, inout float3 indirectLighting)
{
	switch (_LightingCalculationType)
	{
	case 0: // Arktoon
		directLighting   = GetSHLength();
		indirectLighting = BetterSH9(half4(0.0, 0.0, 0.0, 1.0)); 
	break;
	case 1: // Standard
		directLighting = 
		indirectLighting = BetterSH9(half4(normal, 1.0))
						 + SHEvalLinearL2(half4(normal, 1.0));
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
	}

}

// For baked lighting.
half3 calcDiffuseGI(SCSS_TonemapInput tone[2], float occlusion, half3 normal, half perceptualRoughness, half softness)
{
	float3 ambientLightDirection = Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);

	float ambientLight = dot(normal, ambientLightDirection);
	ambientLight = ambientLight * 0.5 + 0.5;

	if (1)	ambientLight = getGreyscaleSH(normal);

	float3 directLighting = 0.0;
	float3 indirectLighting = 0.0;

	getDirectIndirectLighting(normal, /*out*/ directLighting, /*out*/ indirectLighting);
	
	float3 indirectAverage = 0.5 * (indirectLighting + directLighting);

	#if !defined(SCSS_CROSSTONE)
	ambientLight = applyShadowLift(ambientLight, occlusion);
	float3 indirectContribution = sampleRampWithOptions(ambientLight, softness);
	indirectLighting = lerp(indirectLighting, directLighting, tone[0].col);
	indirectAverage = lerp(indirectAverage, directLighting, tone[0].col);
	#endif

	#if defined(SCSS_CROSSTONE)
	ambientLight *= occlusion;
	float3 indirectContribution = sampleCrossToneLighting(ambientLight, tone[0], tone[1]);
	indirectLighting = lerp(indirectLighting, directLighting, tone[0].col);
	indirectAverage = lerp(indirectAverage, directLighting, tone[0].col);
	#endif

	// Make this a UI value later.
	half ambientLightSplitThreshold = 1.0/3.0;

	float3 lightContribution = 
	lerp(indirectAverage,
	lerp(indirectLighting, directLighting, indirectContribution),
	saturate(dot(abs((directLighting-indirectLighting)/indirectAverage), 
		ambientLightSplitThreshold)));

	return lightContribution;
}

// For directional lights where attenuation is shadow.
half3 calcDiffuseBase(SCSS_TonemapInput tone[2], float occlusion, half3 normal, half perceptualRoughness, 
	half attenuation, half softness, SCSS_LightParam d, SCSS_Light l)
{
	float remappedLight = getRemappedLight(perceptualRoughness, d);
	remappedLight = remappedLight * 0.5 + 0.5;

	remappedLight = applyAttenuation(remappedLight, attenuation);

	#if !defined(SCSS_CROSSTONE)
	remappedLight = applyShadowLift(remappedLight, occlusion);
	float3 lightContribution = lerp(tone[0].col, 1.0, sampleRampWithOptions(remappedLight, softness));;
	#endif

	#if defined(SCSS_CROSSTONE)
	remappedLight *= occlusion;
	float3 lightContribution = sampleCrossToneLighting(remappedLight, tone[0], tone[1]);
	#endif

	lightContribution *= l.color;

	return lightContribution;	
}

// For point/spot lights where attenuation is shadow+attenuation.
half3 calcDiffuseAdd(SCSS_TonemapInput tone[2], float occlusion, half perceptualRoughness, 
	half softness, SCSS_LightParam d, SCSS_Light l)
{
	float remappedLight = getRemappedLight(perceptualRoughness, d);
	remappedLight = remappedLight * 0.5 + 0.5;

	#if !defined(SCSS_CROSSTONE)
	remappedLight = applyShadowLift(remappedLight, occlusion);
	float3 lightContribution = sampleRampWithOptions(remappedLight, softness);

	float3 directLighting = l.color;
	float3 indirectLighting = l.color * tone[0].col;

	lightContribution = lerp(indirectLighting, directLighting, lightContribution);
	#endif

	#if defined(SCSS_CROSSTONE)
	float3 lightContribution = sampleCrossToneLighting(remappedLight, tone[0], tone[1]);
	lightContribution *= l.color;
	#endif

	return lightContribution;
}

#if defined(_SPECULAR)
void getSpecularVD(float roughness, float3 normal, SCSS_LightParam d, SCSS_Light l, VertexOutput i,
	out half V, out half D)
{
	V = 0; D = 0;

	#ifndef SHADER_TARGET_GLSL
	[call]
	#endif
	switch(_SpecularType)
	{
	case 1: // GGX
		V = SmithJointGGXVisibilityTerm (d.NdotL, d.NdotV, roughness);
	    D = GGXTerm (d.NdotH, roughness);
	    break;

	case 2: // Charlie (cloth)
		V = V_Neubelt (d.NdotV, d.NdotL);
	    D = D_Charlie (roughness, d.NdotH);
	    break;

	case 3: // GGX anisotropic
	    float anisotropy = _Anisotropy;
	    float at = max(roughness * (1.0 + anisotropy), 0.002);
	    float ab = max(roughness * (1.0 - anisotropy), 0.002);

		#if 0
	    float TdotL = dot(i.tangentDir, l.dir);
	    float BdotL = dot(i.bitangentDir, l.dir);
	    float TdotV = dot(i.tangentDir, viewDir);
	    float BdotV = dot(i.bitangentDir, l.dir);

	    // Accurate but probably expensive
		V = V_SmithGGXCorrelated_Anisotropic (at, ab, TdotV, BdotV, TdotL, BdotL, d.NdotV, d.NdotL);
		#else
		V = SmithJointGGXVisibilityTerm (d.NdotL, d.NdotV, roughness);
		#endif
		// Temporary
	    D = D_GGX_Anisotropic(d.NdotH, d.halfDir, i.tangentDir, i.bitangentDir, at, ab);
	    break;
	}
	return;
}

half3 calcSpecularBase(float3 specColor, float smoothness, float3 normal, float oneMinusReflectivity, float perceptualRoughness,
	float attenuation, float occlusion, SCSS_LightParam d, SCSS_Light l, VertexOutput i)
{
	UnityGI gi = (UnityGI)0;
	
	half V = 0; half D = 0; 
	float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

	// "GGX with roughness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughness remapping."
	// This also fixes issues with the other specular types.
	roughness = max(roughness, 0.002);

	d = saturate(d);

	getSpecularVD(roughness, normal, d, l, i, /*out*/ V, /*out*/ D);

	half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
	specularTerm = max(0, specularTerm * d.NdotL);

	#if defined(_SPECULARHIGHLIGHTS_OFF)
    	specularTerm = 0.0;
	#endif

	half surfaceReduction = 1.0 / (roughness*roughness + 1);

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

	gi =  GetUnityGI(l.color.rgb, l.dir, normal, 
		d.viewDir, d.reflDir, attenuation, occlusion, perceptualRoughness, i.posWorld.xyz);

	float grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));

	return
	specularTerm * (gi.light.color) * FresnelTerm(specColor, d.LdotH) +
	surfaceReduction * (gi.indirect.specular.rgb) * FresnelLerp(specColor, grazingTerm, d.NdotV);
	
}

half3 calcSpecularBase(SCSS_Input c, float perceptualRoughness, float attenuation,
	SCSS_LightParam d, SCSS_Light l, VertexOutput i)
{
	return calcSpecularBase(c.specColor, c.smoothness, c.normal, c.oneMinusReflectivity, 
		perceptualRoughness, attenuation, c.occlusion, d, l, i);
}

half3 calcSpecularAdd(float3 specColor, float smoothness, float3 normal, float oneMinusReflectivity, float perceptualRoughness,
	SCSS_LightParam d, SCSS_Light l, VertexOutput i)
{
	#if defined(_SPECULARHIGHLIGHTS_OFF)
		return 0.0;
	#endif
	
	half V = 0; half D = 0; 
	float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

	// "GGX with roughness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughness remapping."
	// This also fixes issues with the other specular types.
	roughness = max(roughness, 0.002);

	d = saturate(d);

	getSpecularVD(roughness, normal, d, l, i, /*out*/ V, /*out*/ D);

	half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
	specularTerm = max(0, specularTerm * d.NdotL);

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

	return
	specularTerm * l.color * FresnelTerm(specColor, d.LdotH);
	
}

half3 calcSpecularAdd(SCSS_Input c, float perceptualRoughness,
	SCSS_LightParam d, SCSS_Light l, VertexOutput i)
{
	return calcSpecularAdd(c.specColor, c.smoothness, c.normal, c.oneMinusReflectivity, perceptualRoughness, d, l, i);
}

half3 calcSpecularCel(float3 specColor, float smoothness, float3 normal, float oneMinusReflectivity, float perceptualRoughness,
	float attenuation, SCSS_LightParam d, SCSS_Light l, VertexOutput i)
{
	if (_SpecularType == 4) {
		float spec = max(d.NdotH, 0);
		spec = pow(spec, (smoothness)*40) * UNITY_PI;
		spec = sharpenLighting(frac(spec), _CelSpecularSoftness)+floor(spec);
    	spec = max(0.02,spec);

    	float3 envLight = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, normal, UNITY_SPECCUBE_LOD_STEPS);
		return (spec * specColor *  l.color) + (spec * specColor * envLight);
	}
	if (_SpecularType == 5) {
		_Anisotropy = abs(_Anisotropy);
		float spec = StrandSpecular(i.tangentDir, 
			d.viewDir, l.dir, d.halfDir, 
			_Anisotropy*100, 1.0 );
		spec += StrandSpecular(i.tangentDir, 
			d.viewDir, l.dir, d.halfDir, 
			_Anisotropy*10, 0.05 );
		spec = sharpenLighting(frac(spec), 0.02)+floor(spec);
		return max(0, spec * specColor *  l.color * smoothness) + 
			UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, normal, UNITY_SPECCUBE_LOD_STEPS) * specColor;
	}
	return 0;
}

half3 calcSpecularCel(SCSS_Input c, float perceptualRoughness, float attenuation, SCSS_LightParam d, SCSS_Light l, VertexOutput i)
{
	return calcSpecularCel(c.specColor, c.smoothness, c.normal, c.oneMinusReflectivity, perceptualRoughness, attenuation, d, l, i);
}
#endif

float3 SCSS_ShadeBase(SCSS_Input c, VertexOutput i, SCSS_Light l, float attenuation)
{	
	float3 finalColor;

	SCSS_LightParam d = initialiseLightParam(l, c.normal, i.posWorld.xyz);

	finalColor  = calcDiffuseGI(c.tone, c.occlusion, c.normal, c.perceptualRoughness, c.softness);
	finalColor += calcDiffuseBase(c.tone, c.occlusion, c.normal, c.perceptualRoughness, attenuation, c.softness, d, l);

	// Prepare fake light params for subsurface scattering.
	SCSS_Light iL = l;
	SCSS_LightParam iD = d;
	iL.color = GetSHLength();
	iL.dir = Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);
	iD = initialiseLightParam(iL, c.normal, i.posWorld.xyz);

	#if defined(_SUBSURFACE)
	if (i.is_outline == 0)
	{
		finalColor += getSubsurfaceScatteringLight(l, c.normal, d.viewDir,
			attenuation, c.thickness);
		finalColor += getSubsurfaceScatteringLight(iL, c.normal, iD.viewDir,
			1, c.thickness);
	}
	#endif

	finalColor *= c.albedo; 

	// Prepare fake light params for spec/fresnel which simulate specular.
	SCSS_Light fL = l;
	SCSS_LightParam fD = d;
	fL.color = attenuation * fL.color + GetSHLength();
	fL.dir = Unity_SafeNormalize(fL.dir + (unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);
	fD = initialiseLightParam(fL, c.normal, i.posWorld.xyz);
	
	if (i.is_outline == 0)
	{

		#if defined(_METALLICGLOSSMAP)
	    finalColor += calcSpecularBase(c, c.perceptualRoughness, attenuation, d, l, i);
	    #endif

	    #if defined(_SPECGLOSSMAP)
    	finalColor += calcSpecularCel(c, c.perceptualRoughness, attenuation, fD, fL, i);
   		#endif
    };

    return finalColor;
}

float3 SCSS_ShadeLight(SCSS_Input c, VertexOutput i, SCSS_Light l, half attenuation)
{
	float3 finalColor;

	SCSS_LightParam d = initialiseLightParam(l, c.normal, i.posWorld.xyz);

    finalColor = calcDiffuseAdd(c.tone, c.occlusion, c.perceptualRoughness, c.softness, d, l) * c.albedo;

	if (i.is_outline == 0)
	{
		#if defined(_SUBSURFACE) 
		finalColor += c.albedo * getSubsurfaceScatteringLight(l, c.normal, d.viewDir,
			attenuation, c.thickness, c.tone[0].col);
		#endif

		#if defined(_METALLICGLOSSMAP)
    	finalColor += calcSpecularAdd(c, c.perceptualRoughness, d, l, i);
    	#endif

		#if defined(_SPECGLOSSMAP)
		finalColor += calcSpecularCel(c, c.perceptualRoughness, attenuation, d, l, i);
		#endif
	};
	return finalColor;
}


float3 SCSS_ApplyLighting(SCSS_Input c, VertexOutput i, float4 texcoords)
{
	UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);

	#if defined(SCSS_SCREEN_SHADOW_FILTER)
	correctedScreenShadowsForMSAA(i._ShadowCoord, attenuation);
	#endif

	// Lighting parameters
	SCSS_Light l = MainLight(i.posWorld.xyz);
	#if defined(UNITY_PASS_FORWARDADD) && !defined(USING_DIRECTIONAL_LIGHT)
	l.dir = normalize(_WorldSpaceLightPos0.xyz - i.posWorld.xyz);
	#endif 

	SCSS_LightParam d = initialiseLightParam(l, c.normal, i.posWorld.xyz);

	#if defined(_METALLICGLOSSMAP)
	// Geometric Specular AA from HDRP
	c.smoothness = GeometricNormalFiltering(c.smoothness, i.normalDir.xyz, 0.25, 0.5);
	#endif

	#if defined(_METALLICGLOSSMAP)
	// Perceptual roughness transformation. Without this, roughness handling is wrong.
	c.perceptualRoughness = SmoothnessToPerceptualRoughness(c.smoothness);
	#else
	// Disable DisneyDiffuse for cel specular.
	#endif

	// Generic lighting for matcaps/rimlighting. 
	// Currently matcaps are applied to albedo, so they don't need lighting. 
	float3 effectLighting = l.color;
	#if defined(UNITY_PASS_FORWARDBASE)
	//effectLighting *= attenuation;
	effectLighting += BetterSH9(half4(0.0,  0.0, 0.0, 1.0));
	#endif

	// Apply matcap before specular effect.
	if (_UseMatcap >= 1 && i.is_outline == 0) 
	{
		half2 matcapUV;
		if (_UseMatcap == 1) matcapUV = getMatcapUVsOriented(c.normal, d.viewDir, float3(0, 1, 0));
		if (_UseMatcap == 2) matcapUV = getMatcapUVsOriented(c.normal, d.viewDir, i.bitangentDir.xyz);

		float4 _MatcapMask_var = MatcapMask(i.uv0.xy);
		c.albedo = applyMatcap(_Matcap1, matcapUV, c.albedo, 1.0, _Matcap1Blend, _Matcap1Strength * _MatcapMask_var.r);
		c.albedo = applyMatcap(_Matcap2, matcapUV, c.albedo, 1.0, _Matcap2Blend, _Matcap2Strength * _MatcapMask_var.g);
		c.albedo = applyMatcap(_Matcap3, matcapUV, c.albedo, 1.0, _Matcap3Blend, _Matcap3Strength * _MatcapMask_var.b);
		c.albedo = applyMatcap(_Matcap4, matcapUV, c.albedo, 1.0, _Matcap4Blend, _Matcap4Strength * _MatcapMask_var.a);
	}

	float3 finalColor = 0; 

	float fresnelLightMaskBase = LerpOneTo((d.NdotH), _UseFresnelLightMask);
	float fresnelLightMask = 
		saturate(pow(saturate( fresnelLightMaskBase), _FresnelLightMask));
	float fresnelLightMaskInv = 
		saturate(pow(saturate(-fresnelLightMaskBase), _FresnelLightMask));
	
	if (_UseFresnel == 1 && i.is_outline == 0) 
	{
		float3 sharpFresnel = sharpenLighting(d.rlPow4.y * c.rim.width * fresnelLightMask, 
			c.rim.power) * c.rim.tint * c.rim.alpha;
		sharpFresnel += sharpenLighting(d.rlPow4.y * c.rim.invWidth * fresnelLightMaskInv,
			c.rim.invPower) * c.rim.invTint * c.rim.invAlpha * _FresnelLightMask;
		c.albedo += c.albedo * sharpFresnel;
	}

	if (_UseFresnel == 3 && i.is_outline == 0)
	{
		float sharpFresnel = sharpenLighting(d.rlPow4.y*c.rim.width, c.rim.power)
		 * c.rim.alpha;
		c.occlusion += saturate(sharpFresnel);
	}

	if (_UseFresnel == 4 && i.is_outline == 0)
	{
		float3 sharpFresnel = sharpenLighting(d.rlPow4.y * c.rim.width * fresnelLightMask, 
			c.rim.power);
		c.occlusion += saturate(sharpFresnel);
		sharpFresnel *= c.rim.tint * c.rim.alpha;
		sharpFresnel += sharpenLighting(d.rlPow4.y * c.rim.invWidth * fresnelLightMaskInv,
			c.rim.invPower) * c.rim.invTint * c.rim.invAlpha * _FresnelLightMask;
		c.albedo += c.albedo * sharpFresnel;
	}

	#if defined(UNITY_PASS_FORWARDBASE)
	finalColor = SCSS_ShadeBase(c, i, l, attenuation);
	#endif

	#if defined(UNITY_PASS_FORWARDADD)
	finalColor = SCSS_ShadeLight(c, i, l, attenuation);
	#endif

	// Proper cheap vertex lights. 
	#if defined(VERTEXLIGHT_ON) && !defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
	finalColor += c.albedo * calcVertexLight(i.vertexLight, c.occlusion, c.tone[0].col, c.softness);
	#endif

	if (_UseFresnel == 2 && i.is_outline == 0)
	{
		float3 sharpFresnel = sharpenLighting(d.rlPow4.y * c.rim.width * fresnelLightMask, 
			c.rim.power) * c.rim.tint * c.rim.alpha;
		sharpFresnel += sharpenLighting(d.rlPow4.y * c.rim.invWidth * fresnelLightMaskInv,
			c.rim.invPower) * c.rim.invTint * c.rim.invAlpha * _FresnelLightMask;
		finalColor += effectLighting*sharpFresnel;
	}

	//float3 wrappedDiffuse = LightColour * saturate((dot(N, L) + w) / ((1 + w) * (1 + w)));

    // Workaround for scenes with HDR off blowing out in VRchat.
    #if !UNITY_HDR_ON && SCSS_CLAMP_IN_NON_HDR
        l.color = saturate(l.color);
    #endif


    // Apply full lighting to unimportant lights. This is cheaper than you might expect.
	#if defined(UNITY_PASS_FORWARDBASE) && defined(VERTEXLIGHT_ON) && defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
    for (int num = 0; num < 4; num++) {
    	l.color = unity_LightColor[num].rgb;
    	l.dir = normalize(float3(unity_4LightPosX0[num], unity_4LightPosY0[num], unity_4LightPosZ0[num]) - i.posWorld.xyz);

		finalColor += SCSS_ShadeLight(c, i, l, 1) *  i.vertexLight[num];
    };
	#endif

	#if defined(UNITY_PASS_FORWARDADD)
		finalColor *= attenuation;
	#endif

	finalColor *= _LightWrappingCompensationFactor;

	#if defined(UNITY_PASS_FORWARDBASE)
	float4 emissionDetail = EmissionDetail(texcoords.zw);

	finalColor = max(0, finalColor - saturate((1-emissionDetail.w)- (1-c.emission)));
	finalColor += emissionDetail.rgb * c.emission * _EmissionColor.rgb;

	// Emissive c.rim. To restore masking behaviour, multiply by emissionMask.
	finalColor += _CustomFresnelColor.xyz * (pow(d.rlPow4.y, rcp(_CustomFresnelColor.w+0.0001)));
	#endif

	return finalColor;
}

#endif // SCSS_CORE_INCLUDED