#ifndef SCSS_CORE_INCLUDED
#define SCSS_CORE_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

#include "SCSS_Config.cginc"
#include "SCSS_UnityGI.cginc"
#include "SCSS_Utils.cginc"
#include "SCSS_Input.cginc"
#include "SCSS_Attributes.cginc"

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

#if defined(SCSS_CROSSTONE)
float3 sampleCrossToneLighting(inout float remappedLight, SCSS_TonemapInput tone0, SCSS_TonemapInput tone1, float3 albedo)
{
	// A three-tiered tone system.
	// Input remappedLight is potentially affected by occlusion map.

	// Todo: clean this up, compatibility hacks
	half factorBorder = saturate(simpleSharpen(remappedLight, tone0.width + _ShadowBorderRange, tone0.offset));

	half factor0 = saturate(simpleSharpen(remappedLight, tone0.width, tone0.offset));
	half factor1 = saturate(simpleSharpen(remappedLight, tone1.width, tone1.offset));

	float3 final;

	// 2nd separation determines whether 1st and 2nd shading tones are combined.
	if (_Crosstone2ndSeparation == 0) 	tone1.col = tone1.col * tone0.col;
	// if (_Crosstone2ndSeparation == 1) 	tone1.col = tone1.col; // Just here for completeness
	
	// Either way, the result is interpolated against tone 0 by the 2nd factor.
	final = lerp(tone1.col, tone0.col, factor1);

	// Tone separation determines whether albedo and 1st shading tones are combined.
	if (_CrosstoneToneSeparation == 0) 	final = final*albedo;
	// if (_CrosstoneToneSeparation == 1) 	final = final; // Just here for completeness
	
	final = lerp(final, albedo, factorBorder*_ShadowBorderColor);

	final = lerp(final, albedo, factor0);

	remappedLight = factor0;
	
	return final;
}
#endif

#if !defined(SCSS_CROSSTONE)
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
#endif

float getRemappedLight(half perceptualRoughness, SCSS_LightParam d)
{
	float diffuseShadowing = DisneyDiffuse(abs(d.NdotV), abs(d.NdotL), d.LdotH, perceptualRoughness);
	float remappedLight = d.NdotL * LerpOneTo(diffuseShadowing, _DiffuseGeomShadowFactor);
	return remappedLight;
}

float applyAttenuation(half NdotL, half attenuation)
{
	#if defined(SCSS_CROSSTONE)
	// This depends on knowing when the first shadow transition point is to work well.
	// Ideally, though, it shouldn't depend on the parameters itself. 
	half shadeVal = _1st_ShadeColor_Step - _1st_ShadeColor_Feather * 0.5;
	shadeVal = shadeVal-0.01;
	NdotL = lerp(shadeVal*NdotL, NdotL, attenuation);
	#else
	NdotL = min(NdotL * attenuation, NdotL);
	#endif
	return NdotL;
}

half3 calcVertexLight(float4 vertexAttenuation, float occlusion, SCSS_TonemapInput tone[2], half softness)
{
	float3 vertexContribution = 0;
	#if defined(UNITY_PASS_FORWARDBASE)

		#if !defined(SCSS_CROSSTONE)
		vertexAttenuation = applyShadowLift(vertexAttenuation, occlusion);
    	for (int num = 0; num < 4; num++) {
    		vertexContribution += unity_LightColor[num] * 
    			(sampleRampWithOptions(vertexAttenuation[num], softness)+tone[0].col);
    	}
    	#endif

		#if defined(SCSS_CROSSTONE)
    	for (int num = 0; num < 4; num++) {
    		vertexContribution += unity_LightColor[num] * 
    			sampleCrossToneLighting(vertexAttenuation[num], tone[0], tone[1], 1.0);
    	}
    	#endif

	#endif
	return vertexContribution;
}

// For baked lighting.
half3 calcDiffuseGI(float3 albedo, SCSS_TonemapInput tone[2], float occlusion, half softness,
	float3 indirectLighting, float3 directLighting, SCSS_LightParam d)
{
	float ambientLight = d.NdotAmb;

	/*
	Ambient lighting splitting: 
	Strong shading looks good, but weak shading looks bad. 
	This system removes shading if it's too weak.
	*/
	
	float3 indirectAverage = 0.5 * (indirectLighting + directLighting);

	// Make this a UI value later.
	const half ambientLightSplitThreshold = 1.0;
	half ambientLightSplitFactor = 
	saturate(
		dot(abs((directLighting-indirectLighting)/indirectAverage), 
		ambientLightSplitThreshold * sRGB_Luminance));

	directLighting	= lerp(indirectLighting, directLighting, _LightWrappingCompensationFactor);

	#if !defined(SCSS_CROSSTONE)
	ambientLight = applyShadowLift(ambientLight, occlusion);
	float3 indirectContribution = sampleRampWithOptions(ambientLight, softness);
	indirectLighting = lerp(indirectLighting, directLighting, tone[0].col);
	indirectAverage = lerp(indirectAverage, directLighting, tone[0].col);
	#endif

	#if defined(SCSS_CROSSTONE)
	ambientLight *= occlusion;
	float3 indirectContribution = sampleCrossToneLighting(ambientLight, tone[0], tone[1], albedo);
	#endif

	float3 lightContribution;

	#if defined(SCSS_CROSSTONE)
	if (_CrosstoneToneSeparation == 0) lightContribution = 
	lerp(indirectAverage,
	lerp(indirectLighting, directLighting, indirectContribution),
	ambientLightSplitFactor) * albedo;

	if (_CrosstoneToneSeparation == 1) lightContribution = 
	lerp(indirectAverage * albedo,
	directLighting*indirectContribution,
	ambientLightSplitFactor);
	#endif

	#if !defined(SCSS_CROSSTONE)
	lightContribution = 
	lerp(indirectAverage,
	lerp(indirectLighting, directLighting, indirectContribution),
	ambientLightSplitFactor) * albedo;
	#endif

	return lightContribution;
}

// For directional lights where attenuation is shadow.
half3 calcDiffuseBase(float3 albedo, SCSS_TonemapInput tone[2], float occlusion, half perceptualRoughness, 
	half attenuation, half softness, SCSS_LightParam d, SCSS_Light l)
{
	float remappedLight = getRemappedLight(perceptualRoughness, d);
	remappedLight = remappedLight * 0.5 + 0.5;

	remappedLight = applyAttenuation(remappedLight, attenuation);

	#if !defined(SCSS_CROSSTONE)
	remappedLight = applyShadowLift(remappedLight, occlusion);
	float3 lightContribution = lerp(tone[0].col, 1.0, sampleRampWithOptions(remappedLight, softness)) * albedo;
	#endif

	#if defined(SCSS_CROSSTONE)
	remappedLight *= occlusion;
	float3 lightContribution = sampleCrossToneLighting(remappedLight, tone[0], tone[1], albedo);
	#endif

	lightContribution *= l.color;

	lightContribution *= _LightWrappingCompensationFactor;

	return lightContribution;	
}

// For point/spot lights where attenuation is shadow+attenuation.
half3 calcDiffuseAdd(float3 albedo, SCSS_TonemapInput tone[2], float occlusion, half perceptualRoughness, 
	half softness, SCSS_LightParam d, SCSS_Light l)
{
	float remappedLight = getRemappedLight(perceptualRoughness, d);
	remappedLight = remappedLight * 0.5 + 0.5;

	#if !defined(SCSS_CROSSTONE)
	remappedLight = applyShadowLift(remappedLight, occlusion);
	float3 lightContribution = sampleRampWithOptions(remappedLight, softness);

	float3 directLighting = l.color;
	float3 indirectLighting = l.color * tone[0].col;

	lightContribution = lerp(indirectLighting, directLighting, lightContribution) * albedo;
	#endif

	#if defined(SCSS_CROSSTONE)
	float3 lightContribution = sampleCrossToneLighting(remappedLight, tone[0], tone[1], albedo);
	lightContribution *= l.color;
	#endif

	return lightContribution;
}

#if defined(_SPECULAR)
void getSpecularVD(float roughness, SCSS_LightParam d, SCSS_Light l, SCSS_ShadingParam p,
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

	    float3 direction = float3(1, 0, 0);

	    float3 anisotropicT = normalize(mul(p.tangentToWorld, direction));
    	float3 anisotropicB = normalize(cross(p.geometricNormal, anisotropicT));

		V = SmithJointGGXVisibilityTerm (d.NdotL, d.NdotV, roughness);
	    D = D_GGX_Anisotropic(d.NdotH, d.halfDir, anisotropicT, anisotropicB, at, ab);
	    break;
	}
	return;
}

half3 calcSpecularBase(float3 specColor, float smoothness, float3 normal, float oneMinusReflectivity, float perceptualRoughness,
	float attenuation, float occlusion, SCSS_LightParam d, SCSS_Light l, SCSS_ShadingParam p)
{
	UnityGI gi = (UnityGI)0;
	
	half V = 0; half D = 0; 
	float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

	// "GGX with roughness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughness remapping."
	// This also fixes issues with the other specular types.
	roughness = max(roughness, 0.002);

	d = saturate(d);

	getSpecularVD(roughness, d, l, p, /*out*/ V, /*out*/ D);

	half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
	specularTerm = max(0, specularTerm * d.NdotL);

	#if defined(_SPECULARHIGHLIGHTS_OFF)
    	specularTerm = 0.0;
	#endif

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

	gi =  GetUnityGI(l.color.rgb, l.dir, normal, 
		p.view, d.reflDir, attenuation, occlusion, perceptualRoughness, p.position.xyz);

	bool isCloth = (_SpecularType==2);
    float3 dfg = PrefilteredDFG_LUT(d.NdotV, perceptualRoughness);
    float horizon = min(1.0 + dot(d.reflDir, normal), 1.0);
    float3 dfgEnergyCompensation = specularDFGEnergyCompensation(dfg, specColor, isCloth);
	float3 environmentSpecular = specularDFG(dfg, specColor, isCloth) * dfgEnergyCompensation;

	return
	specularTerm * (gi.light.color) * FresnelTerm(specColor, d.LdotH) +
	environmentSpecular * gi.indirect.specular.rgb * horizon * horizon; 
}

half3 calcSpecularBase(SCSS_Input c, float attenuation,
	SCSS_LightParam d, SCSS_Light l, SCSS_ShadingParam p)
{
	return calcSpecularBase(c.specColor, c.smoothness, p.normal, c.oneMinusReflectivity, c.perceptualRoughness, 
		attenuation, c.specOcclusion, d, l, p);
}

half3 calcSpecularAdd(float3 specColor, float smoothness, float3 normal, float oneMinusReflectivity, float perceptualRoughness,
	SCSS_LightParam d, SCSS_Light l, SCSS_ShadingParam p)
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

	getSpecularVD(roughness, d, l, p, /*out*/ V, /*out*/ D);

	half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
	specularTerm = max(0, specularTerm * d.NdotL);

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

	return
	specularTerm * l.color * FresnelTerm(specColor, d.LdotH);
	
}

half3 calcSpecularAdd(SCSS_Input c,	SCSS_LightParam d, SCSS_Light l, SCSS_ShadingParam p)
{
	return calcSpecularAdd(c.specColor, c.smoothness, p.normal, c.oneMinusReflectivity, c.perceptualRoughness, d, l, p);
}

half3 calcSpecularCel(float3 specColor, float smoothness, float3 normal, float oneMinusReflectivity, float perceptualRoughness,
	float attenuation, SCSS_LightParam d, SCSS_Light l, SCSS_ShadingParam p)
{
	if (_SpecularType == 4) {
		// 
		float spec = max(d.NdotH, 0);
		spec = pow(spec, (smoothness)*40) * _CelSpecularSteps;
		spec = sharpenLighting(frac(spec), _CelSpecularSoftness)+floor(spec);
    	spec = max(0.02,spec);
    	spec *= UNITY_PI * rcp(_CelSpecularSteps);

    	float3 envLight = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, normal, UNITY_SPECCUBE_LOD_STEPS);
		return (spec * specColor *  l.color) + (spec * specColor * envLight);
	}
	if (_SpecularType == 5) {
		// It might be better if these are passed in parameters in future
		float anisotropy = _Anisotropy;
		float softness = _CelSpecularSoftness;


	    float3 direction = float3(1, 0, 0);

	    float3 anisotropicT = normalize(mul(p.tangentToWorld, direction));
    	float3 anisotropicB = normalize(cross(p.tangentToWorld[0], anisotropicT));

		float3 strandTangent = (anisotropy < 0)
		? p.tangentToWorld[1]
		: p.tangentToWorld[2];
		anisotropy = abs(anisotropy);
		strandTangent = lerp(normal, strandTangent, anisotropy);
		float exponent = smoothness;
		float spec  = StrandSpecular(strandTangent, d.halfDir, 
			exponent*80, 1.0 );
		float spec2 = StrandSpecular(strandTangent, d.halfDir, 
			exponent*40, 0.5 );
		spec  = sharpenLighting(frac(spec), softness)+floor(spec);
		spec2 = sharpenLighting(frac(spec2), softness)+floor(spec2);
		spec += spec2;
		
    	float3 envLight = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, normal, UNITY_SPECCUBE_LOD_STEPS);
		return (spec * specColor *  l.color);// + (spec * specColor * envLight);
	}
	return 0;
}

half3 calcSpecularCel(SCSS_Input c, float perceptualRoughness, float attenuation, SCSS_LightParam d, SCSS_Light l, SCSS_ShadingParam p)
{
	return calcSpecularCel(c.specColor, c.smoothness, p.normal, c.oneMinusReflectivity, perceptualRoughness, attenuation, d, l, p);
}

#endif // _SPECULAR

float3 SCSS_ShadeBase(const SCSS_Input c, const SCSS_ShadingParam p)
{	
	float3 finalColor;

	SCSS_Light l = MainLight(p.position.xyz);
	SCSS_LightParam d = initialiseLightParam(l, p);

	float3 directLighting, indirectLighting;

	getDirectIndirectLighting(p.normal, /*out*/ directLighting, /*out*/ indirectLighting);

	finalColor  = calcDiffuseGI(c.albedo, c.tone, c.occlusion, c.softness, indirectLighting, directLighting, d);
	finalColor += calcDiffuseBase(c.albedo, c.tone, c.occlusion,
		c.perceptualRoughness, p.attenuation, c.softness, d, l);

	// Prepare fake light params for subsurface scattering.
	SCSS_Light iL = l;
	SCSS_LightParam iD = d;
	iL.color = GetSHMaxL1();
	iL.dir = Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);
	iD = initialiseLightParam(iL, p);

	// Prepare fake light params for spec/fresnel which simulate specular.
	SCSS_Light fL = l;
	SCSS_LightParam fD = d;
	fL.color = p.attenuation * fL.color + GetSHMaxL1();
	fL.dir = Unity_SafeNormalize(fL.dir + (unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);
	fD = initialiseLightParam(fL, p);

	if (p.isOutline <= 0)
	{
		#if defined(_SUBSURFACE)
			#if defined(USING_DIRECTIONAL_LIGHT)
			finalColor += getSubsurfaceScatteringLight(l, p.normal, p.view,
				p.attenuation, c.thickness) * c.albedo;
			#endif
		finalColor += getSubsurfaceScatteringLight(iL, p.normal, p.view,
			1, c.thickness) * c.albedo;
		#endif

		#if defined(_METALLICGLOSSMAP)
	    finalColor += calcSpecularBase(c, p.attenuation, d, l, p);
	    #endif

	    #if defined(_SPECGLOSSMAP)
    	finalColor += calcSpecularCel(c, c.perceptualRoughness, p.attenuation, fD, fL, p);
   		#endif
    };

    return finalColor;
}

float3 SCSS_ShadeLight(const SCSS_Input c, const SCSS_ShadingParam p, const SCSS_Light l)
{
	float3 finalColor;

	SCSS_LightParam d = initialiseLightParam(l, p);

    finalColor = calcDiffuseAdd(c.albedo, c.tone, c.occlusion, c.perceptualRoughness, c.softness, d, l);

	if (p.isOutline <= 0)
	{
		#if defined(_SUBSURFACE) 
		finalColor += c.albedo * getSubsurfaceScatteringLight(l, p.normal, p.view,
			p.attenuation, c.thickness, c.tone[0].col);
		#endif

		#if defined(_METALLICGLOSSMAP)
    	finalColor += calcSpecularAdd(c, d, l, p);
    	#endif

		#if defined(_SPECGLOSSMAP)
		finalColor += calcSpecularCel(c, c.perceptualRoughness, p.attenuation, d, l, p);
		#endif
	};
	return finalColor;
}

float3 SCSS_ShadeLight(const SCSS_Input c, const SCSS_ShadingParam p)
{
	SCSS_Light l = MainLight(p.position.xyz);
	return SCSS_ShadeLight(c, p, l);
}

float3 SCSS_ApplyLighting(SCSS_Input c, SCSS_ShadingParam p)
{
	float outlineLevel = 1-p.isOutline;

	// Lighting parameters
	SCSS_Light l = MainLight(p.position.xyz);
	SCSS_LightParam d = initialiseLightParam(l, p);


	#if defined(_METALLICGLOSSMAP)
	// Perceptual roughness transformation. Without this, roughness handling is wrong.
	float perceptualRoughness = SmoothnessToPerceptualRoughness(c.smoothness);
	perceptualRoughness = IsotropicNDFFiltering(p.geometricNormal.xyz, perceptualRoughness);
	c.perceptualRoughness = perceptualRoughness;
	#else
	// Disable DisneyDiffuse for cel specular.
	#endif

	// Generic lighting for effects.
	float3 effectLighting = FLT_EPS + l.color;
	#if defined(UNITY_PASS_FORWARDBASE)
	effectLighting += GetSHAverage();
	#endif

	// Generic lighting for effects with shadow applied.
	float3 effectLightShadow = l.color * max((1+d.NdotL)*p.attenuation, 0);
	#if defined(UNITY_PASS_FORWARDBASE)
	effectLightShadow += GetSHAverage();
	#endif

    // Workaround for scenes with HDR off blowing out in VRchat.
    if (getLightClampActive())
    {
	    // Colour-preserving clamp.
	    // This light value is used later to flatten the overall output intensity. 
	    // Get the maximum input value from the lighting.
	    // Note: Not luminance, because the final output is still tinted by the output colour.
	    // So bright blue light is OK because blue is still dark. 
	    float maxEffectLight = max3(effectLighting);
	    // The effect lighting is remapped to be within the 0-1.25 range when clamped.
	    float modLight = min(maxEffectLight, 1.25);
	    // Scale the values by the highest value. 
	    // Needs a bit more testing, but should look nice. 
	    effectLighting = (effectLighting/maxEffectLight)*modLight;
	}

	float3 finalColor = 0; 

	#if defined(UNITY_PASS_FORWARDBASE)
	finalColor = SCSS_ShadeBase(c, p);
	#endif

	#if defined(UNITY_PASS_FORWARDADD)
	finalColor = SCSS_ShadeLight(c, p);
	#endif

	// Proper cheap vertex lights. 
	#if defined(VERTEXLIGHT_ON) && !defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
	finalColor += c.albedo * calcVertexLight(p.vertexLight, c.occlusion, c.tone, c.softness);
	#endif

    // Apply full lighting to unimportant lights. This is cheaper than you might expect.
	#if defined(UNITY_PASS_FORWARDBASE) && defined(VERTEXLIGHT_ON) && defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
    for (int num = 0; num < 4; num++) {
    	UNITY_BRANCH if ((unity_LightColor[num].r + unity_LightColor[num].g + unity_LightColor[num].b + p.vertexLight[num]) != 0.0)
    	{
    	l.color = unity_LightColor[num].rgb;
    	l.dir = normalize(float3(unity_4LightPosX0[num], unity_4LightPosY0[num], unity_4LightPosZ0[num]) - p.position.xyz);

    	if (getLightClampActive()) l.color = saturate(l.color);

		float3 addColor = SCSS_ShadeLight(c, p, l) *  p.vertexLight[num];

    	if (getLightClampActive()) addColor = saturate(addColor);
    	
		finalColor += addColor;
    	}
    };
	#endif

	#if defined(UNITY_PASS_FORWARDADD)
		finalColor *= p.attenuation;
	#endif

	#if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
		lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, p.lightmapUV));
		finalColor *= lightmap;
	#endif

	//finalColor *= _LightWrappingCompensationFactor;

	// Apply the light scaling if the light clamp is active. When the light clamp is active,
	// the final colour is divided by the light intensity
   	if (getLightClampActive()) finalColor = finalColor / max(max3(effectLighting), 1);

	finalColor *= _LightMultiplyAnimated;

	#if defined(UNITY_PASS_FORWARDBASE) && defined(_EMISSION)
	float glowModifier = smoothstep(_EmissiveLightSenseStart, _EmissiveLightSenseEnd, dot(effectLightShadow, sRGB_Luminance));
	if (_UseEmissiveLightSense) c.emission *= glowModifier;
	#endif
	//finalColor = lerp(finalColor, c.emission, c.emission.a);
	finalColor += c.emission;

	return finalColor;
}

#endif // SCSS_CORE_INCLUDED