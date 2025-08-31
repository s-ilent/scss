#ifndef SCSS_CORE_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_CORE_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

#include "SCSS_Config.cginc"
#include "SCSS_UnityGI.cginc"
#include "SCSS_Utils.cginc"
#include "SCSS_Attributes.cginc"
#include "SCSS_Input.cginc"
#include "SCSS_Lighting.cginc"

#if defined(_SUBSURFACE)
//SSS method from GDC 2011 conference by Colin Barre-Bresebois & Marc Bouchard and modified by Xiexe
float3 getSubsurfaceScatteringLight (SCSS_Light l, float3 normalDirection, float3 viewDirection, 
    float attenuation, float3 thickness)
{
    float3 vSSLight = l.dir + normalDirection * _SSSDist; // Distortion
    float3 vdotSS = pow(saturate(dot(viewDirection, -vSSLight)), _SSSPow) 
        * _SSSIntensity; 
    
    return lerp(1, attenuation, float(any(_WorldSpaceLightPos0.xyz))) 
                * (vdotSS + _SSSAmbient) * abs(_ThicknessMapInvert-thickness)
                * (l.color) * _SSSCol;
                
}
#endif

float3 sampleCrossToneLighting(inout float remappedLight, SCSS_CrosstoneData data, float3 albedo) {
	// A three-tiered tone system.
	// Input remappedLight is potentially affected by occlusion map.
    half factorBorder = saturate(simpleSharpen(remappedLight, data.tone0.width + data.shadowBorderRange, data.tone0.offset));
    half factor0 = saturate(simpleSharpen(remappedLight, data.tone0.width, data.tone0.offset));
    half factor1 = saturate(simpleSharpen(remappedLight, data.tone1.width, data.tone1.offset));

    float3 final;

	// 2nd separation determines whether 1st and 2nd shading tones are combined.
    if (data.crosstone2ndSeparation == 0) data.tone1.col = data.tone1.col * data.tone0.col;

	// Either way, the result is interpolated against tone 0 by the 2nd factor.
    final = lerp(data.tone1.col, data.tone0.col, factor1);

	// Tone separation determines whether albedo and 1st shading tones are combined.
    if (data.crosstoneToneSeparation == 0) final = final * albedo;

    final = lerp(final, albedo, factorBorder * data.shadowBorderColor);
    final = lerp(final, albedo, factor0);

    remappedLight = factor0;
    
    return final;
}

float applyShadowLift(float baseLight, float occlusion, float shadowLift) 
{
    baseLight *= occlusion;
    baseLight = shadowLift + baseLight * (1 - shadowLift);
    return baseLight;
}

float applyShadowLift(float4 baseLight, float occlusion, float shadowLift) 
{
    baseLight *= occlusion;
    baseLight = shadowLift + baseLight * (1 - shadowLift);
    return baseLight;
}

float getRemappedLight(half perceptualRoughness, SCSS_LightParam d)
{
	float diffuseShadowing = DisneyDiffuse(abs(d.NdotV), abs(d.NdotL), d.LdotH, perceptualRoughness);
	float remappedLight = d.NdotL * LerpOneTo(diffuseShadowing, _DiffuseGeomShadowFactor);
	return remappedLight;
}

float applyAttenuation(half NdotL, half attenuation) {
    NdotL = min(NdotL * attenuation, NdotL);
    return NdotL;
}

float applyAttenuationCrosstone(half NdotL, half attenuation, SCSS_TonemapInput t) {
	// This depends on knowing when the first shadow transition point is to work well.
	// Ideally, though, it shouldn't depend on the parameters itself. 
    half shadeVal = t.offset - t.width * 0.5;
    shadeVal = shadeVal - 0.01;
    NdotL = lerp(shadeVal * NdotL, NdotL, attenuation);
    return NdotL;
}

half3 calcVertexLight(float4 vertexAttenuation, SCSS_LightrampData data) {
    float3 vertexContribution = 0;
    vertexAttenuation = applyShadowLift(vertexAttenuation, data.occlusion, data.shadowLift);
    for (int num = 0; num < 4; num++) {
        vertexContribution += unity_LightColor[num] * (sampleRampWithOptions(vertexAttenuation[num], data.softness) + data.tone0.col);
    }
    return vertexContribution;
}

half3 calcVertexLight(float4 vertexAttenuation, SCSS_CrosstoneData data) {
    float3 vertexContribution = 0;
    for (int num = 0; num < 4; num++) {
        vertexContribution += unity_LightColor[num] * sampleCrossToneLighting(vertexAttenuation[num], data, 1.0);
    }
    return vertexContribution;
}

// For baked lighting.
// remappedLight should be d.NdotAmb. 
half3 calcDiffuseGI(float3 albedo, SCSS_LightrampData data, float3 indirectLighting, float3 directLighting, float remappedLight) {
    float ambientLight = remappedLight;
    float3 indirectAverage = 0.5 * (indirectLighting + directLighting);
    const half ambientLightSplitThreshold = 1.0;
    half ambientLightSplitFactor = saturate(dot(abs((directLighting - indirectLighting) / indirectAverage), ambientLightSplitThreshold * sRGB_Luminance));
    directLighting = lerp(indirectLighting, directLighting, _LightWrappingCompensationFactor);

    ambientLight = applyShadowLift(ambientLight, data.occlusion, data.shadowLift);
    float3 indirectContribution = sampleRampWithOptions(ambientLight, data.softness);
    indirectLighting = lerp(indirectLighting, directLighting, data.tone0.col);
    indirectAverage = lerp(indirectAverage, directLighting, data.tone0.col);

    return lerp(indirectAverage, lerp(indirectLighting, directLighting, indirectContribution), ambientLightSplitFactor) * albedo;
}

half3 calcDiffuseGI(float3 albedo, SCSS_CrosstoneData data, float3 indirectLighting, float3 directLighting, float remappedLight) {
    float ambientLight = remappedLight;
    float3 indirectAverage = 0.5 * (indirectLighting + directLighting);
    const half ambientLightSplitThreshold = 1.0;
    half ambientLightSplitFactor = saturate(dot(abs((directLighting - indirectLighting) / indirectAverage), ambientLightSplitThreshold * sRGB_Luminance));
    directLighting = lerp(indirectLighting, directLighting, _LightWrappingCompensationFactor);

    ambientLight *= data.occlusion;
    float3 indirectContribution = sampleCrossToneLighting(ambientLight, data, albedo);

    if (data.crosstoneToneSeparation == 0) {
        return lerp(indirectAverage, lerp(indirectLighting, directLighting, indirectContribution), ambientLightSplitFactor) * albedo;
    } else {
        return lerp(indirectAverage * albedo, directLighting * indirectContribution, ambientLightSplitFactor);
    }
}

// For directional lights where attenuation is shadow.
// remappedLight must be 0..1 range.
half3 calcDiffuseBase(float3 albedo, SCSS_LightrampData data, half attenuation, float3 lightColor, float remappedLight) {
    remappedLight = applyAttenuation(remappedLight, attenuation);
    remappedLight = applyShadowLift(remappedLight, data.tone0.bias * data.occlusion, data.shadowLift);
    float3 lightContribution = lerp(data.tone0.col, 1.0, sampleRampWithOptions(remappedLight, data.softness)) * albedo;
    lightContribution *= lightColor;
    lightContribution *= _LightWrappingCompensationFactor;
    return lightContribution;
}

half3 calcDiffuseBase(float3 albedo, SCSS_CrosstoneData data, half attenuation, float3 lightColor, float remappedLight) {
    remappedLight = applyAttenuationCrosstone(remappedLight, attenuation, data.tone0);
    remappedLight *= data.occlusion;
    float3 lightContribution = sampleCrossToneLighting(remappedLight, data, albedo);
    lightContribution *= lightColor;
    lightContribution *= _LightWrappingCompensationFactor;
    return lightContribution;
}

// For point/spot lights, where attenuation is shadow+attenuation.
// remappedLight must be 0..1 range.
half3 calcDiffuseAdd(float3 albedo, SCSS_LightrampData data, float3 lightColor, float remappedLight) {
    remappedLight = applyShadowLift(remappedLight, data.tone0.bias * data.occlusion, data.shadowLift);
    float3 lightContribution = sampleRampWithOptions(remappedLight, data.softness);

    float3 directLighting = lightColor;
    float3 indirectLighting = lightColor * data.tone0.col;

    lightContribution = lerp(indirectLighting, directLighting, lightContribution) * albedo;
    return lightContribution;
}

half3 calcDiffuseAdd(float3 albedo, SCSS_CrosstoneData data, float3 lightColor, float remappedLight) {
    float3 lightContribution = sampleCrossToneLighting(remappedLight, data, albedo);
    lightContribution *= lightColor;
    return lightContribution;
}


#if defined(_SPECULAR)
void getSpecularVD(float roughness, SCSS_LightParam d, SCSS_Light l, SCSS_ShadingParam p,
	out half V, out half D)
{
	V = 0; D = 0;

	#ifdef SCSS_HLSL_COMPAT
	[call] 
	// Call should improve performance by avoiding the execution of unused code paths.
	// https://www.gamedev.net/forums/topic/682920-hlsl-switch-attributes/
	#endif
	switch(_SpecularType)
	{
	case 1: // GGX
		V = SmithJointGGXVisibilityTerm (d.NdotL, d.NdotV, roughness);
	    D = D_GGX (roughness, d.NdotH);
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

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

	gi = GetUnityGI(l.color.rgb, l.dir, normal, 
		p.view, d.reflDir, attenuation, occlusion, perceptualRoughness, p.position.xyz);

	bool isCloth = (_SpecularType==2);
    float3 dfg = PrefilteredDFG_LUT(d.NdotV, perceptualRoughness);
    float horizon = min(1.0 + dot(d.reflDir, normal), 1.0);
    float3 dfgEnergyCompensation = specularDFGEnergyCompensation(dfg, specColor, isCloth);
	float3 environmentSpecular = specularDFG(dfg, specColor, isCloth) * dfgEnergyCompensation;

	specularTerm *= _SpecularHighlights;
	environmentSpecular *= _GlossyReflections;

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
	
	specularTerm *= _SpecularHighlights;

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

		return (spec * specColor *  l.color);
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
		
		return (spec * specColor * l.color);
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

    float remappedLight = getRemappedLight(c.perceptualRoughness, d);
	remappedLight = remappedLight * 0.5 + 0.5;
	float giLight = d.NdotAmb;

	if (_SDFMode)
	{
		remappedLight = getSDFLighting(l.dir, c.sdf, c.sdfSmoothness);
		giLight = getSDFLighting(d.ambDir, c.sdf, c.sdfSmoothness);
	}

	float3 directLighting, indirectLighting, indirectDominantDir;

	getDirectIndirectLighting(p.normal, p.position, d.sh, 
		/*out*/ directLighting, /*out*/ indirectLighting, /*out*/ indirectDominantDir);

	// Prepare Lightramp/Crosstone parameters to pass on
	#if defined(SCSS_CROSSTONE)
    SCSS_CrosstoneData shadingData = initaliseCrosstoneParam(c);
	#else
    SCSS_LightrampData shadingData = initaliseLightrampParam(c);
	#endif

    finalColor  = calcDiffuseGI(c.albedo, shadingData, indirectLighting, directLighting, giLight);
    finalColor += calcDiffuseBase(c.albedo, shadingData, p.attenuation, l.color, remappedLight);
	
    half directionality = max(0.001, length(indirectDominantDir));
    float3 indirectKeyLight = directLighting * directionality;

	// Prepare fake light params for subsurface scattering.
	SCSS_Light iL = l;
	iL.color = indirectKeyLight;
	iL.dir = Unity_SafeNormalize(indirectDominantDir);
	SCSS_LightParam iD = recalculateLightParamLight(iL, p, d);

	// Prepare fake light params for spec/fresnel which simulate specular.
	SCSS_Light fL = l;
	fL.color = p.attenuation * fL.color + indirectKeyLight;
	fL.dir = Unity_SafeNormalize(fL.dir + indirectDominantDir);
	SCSS_LightParam fD = recalculateLightParamLight(fL, p, d);

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
	    finalColor += calcSpecularBase(c, p.attenuation, fD, fL, p);
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
    float remappedLight = getRemappedLight(c.perceptualRoughness, d);
	remappedLight = remappedLight * 0.5 + 0.5;

	if (_SDFMode)
	{
		remappedLight = getSDFLighting(l.dir, c.sdf, c.sdfSmoothness);
	}
	
	// Prepare Lightramp/Crosstone parameters to pass on
	#if defined(SCSS_CROSSTONE)
    SCSS_CrosstoneData shadingData = initaliseCrosstoneParam(c);
	#else
    SCSS_LightrampData shadingData = initaliseLightrampParam(c);
	#endif

    finalColor = calcDiffuseAdd(c.albedo, shadingData, l.color, remappedLight);

	if (p.isOutline <= 0)
	{
		#if defined(_SUBSURFACE) 
		finalColor += c.albedo * getSubsurfaceScatteringLight(l, p.normal, p.view,
			p.attenuation, c.thickness);
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
	effectLighting += d.sh.L0;
	#endif

	// Generic lighting for effects with shadow applied.
	float3 effectLightShadow = l.color * max((1+d.NdotL)*p.attenuation, 0);
	#if defined(UNITY_PASS_FORWARDBASE)
	effectLightShadow += d.sh.L0;
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

	// Apply the light scaling if the light clamp is active. When the light clamp is active,
	// the final colour is divided by the light intensity
   	if (getLightClampActive()) finalColor = finalColor / max(max3(effectLighting), 1);

	finalColor *= _LightMultiplyAnimated;

	#if defined(UNITY_PASS_FORWARDBASE)
	float glowModifier = smoothstep(_EmissiveLightSenseStart, _EmissiveLightSenseEnd, dot(effectLightShadow, sRGB_Luminance));
	if (_UseEmissiveLightSense) c.emission *= glowModifier;
	#endif

	#if defined(UNITY_PASS_FORWARDBASE)
	//finalColor = lerp(finalColor, c.emission, c.emission.a);
	finalColor += c.emission;
	#endif

	return finalColor;
}

#endif // SCSS_CORE_INCLUDED