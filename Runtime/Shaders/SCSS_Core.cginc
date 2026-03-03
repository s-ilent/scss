#ifndef SCSS_CORE_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_CORE_INCLUDED

#if defined(SCSS_IS_URP)
    #include "SCSS_CompatURP.hlsl"
#else
    #include "SCSS_CompatBIRP.hlsl"
#endif

#include "SCSS_Config.cginc"
#include "SCSS_UnityGI.cginc"
#include "SCSS_Utils.cginc"
#include "SCSS_BRDF_Glint.cginc"
#include "SCSS_Attributes.cginc"
#include "SCSS_Input.cginc"
#include "SCSS_Lighting.cginc"

#if defined(_SUBSURFACE)
//SSS method from GDC 2011 conference by Colin Barre-Bresebois & Marc Bouchard and modified by Xiexe
half3 getSubsurfaceScatteringLight (CompatLight l, half3 normalDirection, half3 viewDirection,
    half attenuation, half3 thickness)
{
    half3 vSSLight = l.direction + normalDirection * _SSSDist; // Distortion
    half3 vdotSS = pow(saturate(dot(viewDirection, -vSSLight)), _SSSPow)
        * _SSSIntensity;
    thickness = abs(_ThicknessMapInvert-thickness);
    return attenuation * (vdotSS + _SSSAmbient) * thickness * l.color * _SSSCol;
}
#endif

half3 sampleCrossToneLighting(inout half remappedLight, SCSS_CrosstoneData data, half3 albedo) {
	// A three-tiered tone system.
	// Input remappedLight is potentially affected by occlusion map.
    half factorBorder = saturate(simpleSharpen(remappedLight, data.tone0.width + data.shadowBorderRange, data.tone0.offset));
    half factor0 = saturate(simpleSharpen(remappedLight, data.tone0.width, data.tone0.offset));
    half factor1 = saturate(simpleSharpen(remappedLight, data.tone1.width, data.tone1.offset));

    half3 final;

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

half applyShadowLift(half baseLight, half occlusion, half shadowLift)
{
    baseLight *= occlusion;
    baseLight = shadowLift + baseLight * (1 - shadowLift);
    return baseLight;
}

half applyShadowLift(half4 baseLight, half occlusion, half shadowLift)
{
    baseLight *= occlusion;
    baseLight = shadowLift + baseLight * (1 - shadowLift);
    return baseLight;
}

half getRemappedLight(half perceptualRoughness, SCSS_LightParam d)
{
	half diffuseShadowing = DisneyDiffuse(abs(d.NdotV), abs(d.NdotL), d.LdotH, perceptualRoughness);
	half remappedLight = d.NdotL * LerpOneTo(diffuseShadowing, _DiffuseGeomShadowFactor);
	return remappedLight;
}

half applyAttenuation(half NdotL, half attenuation) {
    NdotL = min(NdotL * attenuation, NdotL);
    return NdotL;
}

half applyAttenuationCrosstone(half NdotL, half attenuation, SCSS_TonemapInput t) {
	// This depends on knowing when the first shadow transition point is to work well.
	// Ideally, though, it shouldn't depend on the parameters itself.
    half shadeVal = t.offset - t.width * 0.5;
    shadeVal = shadeVal - 0.01;
    NdotL = lerp(shadeVal * NdotL, NdotL, attenuation);
    return NdotL;
}

// For baked lighting.
// remappedLight should be d.NdotAmb.
half3 calcDiffuseGI(half3 albedo, SCSS_LightrampData data, half3 indirectLighting, half3 directLighting, half remappedLight) {
    half ambientLight = remappedLight;
    half3 indirectAverage = 0.5 * (indirectLighting + directLighting);
    const half ambientLightSplitThreshold = 1.0;
    half ambientLightSplitFactor = saturate(dot(abs((directLighting - indirectLighting) / indirectAverage), ambientLightSplitThreshold * sRGB_Luminance));
    directLighting = lerp(indirectLighting, directLighting, _LightWrappingCompensationFactor);

    ambientLight = applyShadowLift(ambientLight, data.occlusion, data.shadowLift);
    half3 indirectContribution = sampleRampWithOptions(ambientLight, data.softness);
    indirectLighting = lerp(indirectLighting, directLighting, data.tone0.col);
    indirectAverage = lerp(indirectAverage, directLighting, data.tone0.col);

    return lerp(indirectAverage, lerp(indirectLighting, directLighting, indirectContribution), ambientLightSplitFactor) * albedo;
}

half3 calcDiffuseGI(half3 albedo, SCSS_CrosstoneData data, half3 indirectLighting, half3 directLighting, half remappedLight) {
    half ambientLight = remappedLight;
    half3 indirectAverage = 0.5 * (indirectLighting + directLighting);
    const half ambientLightSplitThreshold = 1.0;
    half ambientLightSplitFactor = saturate(dot(abs((directLighting - indirectLighting) / indirectAverage), ambientLightSplitThreshold * sRGB_Luminance));
    directLighting = lerp(indirectLighting, directLighting, _LightWrappingCompensationFactor);

    ambientLight *= data.occlusion;
    half3 indirectContribution = sampleCrossToneLighting(ambientLight, data, albedo);

    if (data.crosstoneToneSeparation == 0) {
        return lerp(indirectAverage, lerp(indirectLighting, directLighting, indirectContribution), ambientLightSplitFactor) * albedo;
    } else {
        return lerp(indirectAverage * albedo, directLighting * indirectContribution, ambientLightSplitFactor);
    }
}

// For directional lights where attenuation is shadow.
// remappedLight must be 0..1 range.
half3 calcDiffuseBase(half3 albedo, SCSS_LightrampData data, half attenuation, half3 lightColor, half remappedLight) {
    remappedLight = applyAttenuation(remappedLight, attenuation);
    remappedLight = applyShadowLift(remappedLight, data.tone0.bias * data.occlusion, data.shadowLift);
    half3 lightContribution = lerp(data.tone0.col, 1.0, sampleRampWithOptions(remappedLight, data.softness)) * albedo;
    lightContribution *= lightColor;
    lightContribution *= _LightWrappingCompensationFactor;
    return lightContribution;
}

half3 calcDiffuseBase(half3 albedo, SCSS_CrosstoneData data, half attenuation, half3 lightColor, half remappedLight) {
    remappedLight = applyAttenuationCrosstone(remappedLight, attenuation, data.tone0);
    remappedLight *= data.occlusion;
    half3 lightContribution = sampleCrossToneLighting(remappedLight, data, albedo);
    lightContribution *= lightColor;
    lightContribution *= _LightWrappingCompensationFactor;
    return lightContribution;
}

// For point/spot lights, where attenuation is shadow+attenuation.
// remappedLight must be 0..1 range.
half3 calcDiffuseAdd(half3 albedo, SCSS_LightrampData data, half3 lightColor, half remappedLight) {
    remappedLight = applyShadowLift(remappedLight, data.tone0.bias * data.occlusion, data.shadowLift);
    half3 lightContribution = sampleRampWithOptions(remappedLight, data.softness);

    half3 directLighting = lightColor;
    half3 indirectLighting = lightColor * data.tone0.col;

    lightContribution = lerp(indirectLighting, directLighting, lightContribution) * albedo;
    return lightContribution;
}

half3 calcDiffuseAdd(half3 albedo, SCSS_CrosstoneData data, half3 lightColor, half remappedLight) {
    half3 lightContribution = sampleCrossToneLighting(remappedLight, data, albedo);
    lightContribution *= lightColor;
    return lightContribution;
}

#if defined(_SPECULAR)
half3 getSpecularDominantDirection(const half3 n, const half3 r, half roughness) {
    return lerp(r, n, roughness * roughness);
}

half3 getIndirectSpecular(SCSS_Input c, SCSS_ShadingParam p, SCSS_LightParam d, half3 indirectColor)
{
    #if !defined(_METALLICGLOSSMAP)
        return 0.0;
    #endif

    bool isCloth = (_SpecularType == 2);

    // Lookup DFG (Distribution / Fresnel / Geometric) from LUT
    // This approximates the integral of the microfacet BRDF
    half3 dfg = PrefilteredDFG_LUT(d.NdotV, c.perceptualRoughness);
    half3 dfgEnergyCompensation = specularDFGEnergyCompensation(dfg, c.specColor, isCloth);
    half3 environmentSpecular = specularDFG(dfg, c.specColor, isCloth) * dfgEnergyCompensation;

    // Attenuate reflections coming from below the geometric horizon
    half horizon = min(1.0 + dot(d.reflDir, p.normal), 1.0);
    half horizonOcclusion = horizon * horizon;

    return environmentSpecular * indirectColor * horizonOcclusion * _GlossyReflections;
}

half3 getDirectSpecular(SCSS_Input c, SCSS_ShadingParam p, SCSS_LightParam d, CompatLight l, half attenuation)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
        return 0.0;
    #endif

    half specularTerm = 0;

    half roughness = PerceptualRoughnessToRoughness(c.perceptualRoughness);
    roughness = max(roughness, 0.002);

    // PBR Specular (GGX, Anisotropic, Cloth)
    #if defined(_METALLICGLOSSMAP)
        d = saturate(d);

        half V = 0;
        half D = 0;

        switch((int)_SpecularType)
        {
        case 1: // GGX
            V = V_SmithGGXCorrelated(roughness, d.NdotV, d.NdotL);
            D = D_GGX(roughness, d.NdotH, d.NxH);
            break;

        case 2: // Charlie (Cloth)
            V = V_Neubelt(d.NdotV, d.NdotL);
            D = D_Charlie(roughness, d.NdotH);
            break;

        case 3: // GGX Anisotropic
            half at = max(roughness * (1.0 + p.anisotropy), 0.002);
            half ab = max(roughness * (1.0 - p.anisotropy), 0.002);

            const half3 t = p.anisotropicT;
            const half3 b = p.anisotropicB;

            half ToH = dot(t, d.halfDir);
            half BoH = dot(b, d.halfDir);

            V = V_SmithGGXCorrelated(roughness, d.NdotV, d.NdotL);
            D = D_GGX_Anisotropic(at, ab, ToH, BoH, d.NdotH);
            break;
        }

        specularTerm = V * D * UNITY_PI; // Torrance-Sparrow
        specularTerm = max(0, specularTerm * d.NdotL);

        return specularTerm * l.color * attenuation * FresnelTerm(c.specColor, d.LdotH) * _SpecularHighlights;
    #endif // _METALLICGLOSSMAP

    // Stylized Specular (Cel, Strand)
    #if defined(_SPECGLOSSMAP)

        if (_SpecularType == 4) // Cel Standard
        {
            half spec = max(d.NdotH, 0);
            spec = pow(spec, c.smoothness * 40.0) * _CelSpecularSteps;
            spec = sharpenLighting(frac(spec), _CelSpecularSoftness) + floor(spec);
            spec = max(0.02, spec);
            specularTerm = spec * UNITY_PI * rcp(_CelSpecularSteps);
        }
        else if (_SpecularType == 5) // Cel Strand (Hair)
        {
            half3 strandBase = (_Anisotropy < 0) ? p.tangentToWorld[1] : p.tangentToWorld[2];
            half3 strandTangent = lerp(p.normal, strandBase, abs(_Anisotropy));

            half exponent = c.smoothness;
            half spec1 = StrandSpecular(strandTangent, d.halfDir, exponent * 80.0, 1.0);
            half spec2 = StrandSpecular(strandTangent, d.halfDir, exponent * 40.0, 0.5);

            spec1 = sharpenLighting(frac(spec1), _CelSpecularSoftness) + floor(spec1);
            spec2 = sharpenLighting(frac(spec2), _CelSpecularSoftness) + floor(spec2);

            specularTerm = spec1 + spec2;
        }

        return specularTerm * c.specColor * l.color * attenuation * _SpecularHighlights;
    #endif

    #if defined(_SPEC_GLINTY)
        d = saturate(d);

        half V = 0;
        half D = 0;

        half2x2 jacobian = half2x2(ddx(p.uv.xy), ddy(p.uv.xy));
        half2x2 uv_ellipsoid = get_uv_ellipsoid(jacobian);

        // H in tangent-space
        half3 tangentH = mul(d.halfDir, p.tangentToWorld);

        // 0.001 to 0.1
        half internal_glint_alpha = lerp(0.001, 0.1, _SpecularGlintSize * _SpecularGlintSize);

        // 0 maps to 10^3 (1,000) particles
        // 1 maps to 10^9 (1,000,000,000) particles
        half internal_density = pow(10.0, lerp(3.0, 9.0, _SpecularGlintDensity));

        const half filter_size = 0.8;

        V = V_SmithGGXCorrelated(roughness, d.NdotV, d.NdotL);
        D = EvaluateGlintyNDF(tangentH, roughness, internal_glint_alpha,
            p.uv.xy, uv_ellipsoid,
            internal_density, filter_size
        );

        specularTerm = V * D * UNITY_PI; // Torrance-Sparrow
        specularTerm = max(0, specularTerm * d.NdotL);

        return specularTerm * l.color * attenuation * FresnelTerm(c.specColor, d.LdotH) * _SpecularHighlights;
    #endif // _SPEC_GLINTY

    return 0.0;
}
#endif // _SPECULAR

half3 SCSS_ShadeBase(const SCSS_Input c, const SCSS_ShadingParam p, CompatLight l, SCSS_LightParam d)
{
	half3 finalColor;
	bool hasMainLight = length(l.color) > 0;

    half remappedLight = getRemappedLight(c.perceptualRoughness, d);
	remappedLight = remappedLight * 0.5 + 0.5;
	half giLight = d.NdotAmb;

	if (_SDFMode)
	{
		remappedLight = getSDFLightingMasked(l.direction, c.sdf, c.sdfSmoothness, remappedLight, c.sdfMask);
		giLight = getSDFLightingMasked(d.ambDir, c.sdf, c.sdfSmoothness, giLight, c.sdfMask);
	}

	half3 directLighting, indirectLighting, indirectDominantDir;

	getDirectIndirectLighting(p.normal, p.position, d.sh,
		/*out*/ directLighting, /*out*/ indirectLighting, /*out*/ indirectDominantDir);

	// Prepare Lightramp/Crosstone parameters to pass on
	#if defined(SCSS_CROSSTONE)
    SCSS_CrosstoneData shadingData = initaliseCrosstoneParam(c);
	#else
    SCSS_LightrampData shadingData = initaliseLightrampParam(c);
	#endif

	// Todo: Should we handle attenuation from shadows and lights seperately?
    half totalShadow = l.shadowAttenuation * l.attenuation;

    finalColor  = calcDiffuseGI(c.albedo, shadingData, indirectLighting, directLighting, giLight);
    finalColor += calcDiffuseBase(c.albedo, shadingData, totalShadow, l.color, remappedLight);

    half directionality = max(0.001, length(indirectDominantDir));
    half3 indirectKeyLight = directLighting;

	// Prepare fake light params for subsurface scattering.
	CompatLight iL = l;
	iL.color = indirectKeyLight;
	iL.direction = Unity_SafeNormalize(indirectDominantDir);
	SCSS_LightParam iD = recalculateLightParamLight(iL, p, d);

	// Prepare fake light params for spec/fresnel which simulate specular.
	CompatLight fL = iL;
	SCSS_LightParam fD = iD;

	if (hasMainLight)
	{
    	fL.color = l.color + indirectKeyLight;
    	fL.direction = Unity_SafeNormalize(l.direction + indirectDominantDir * directionality);
    	fD = recalculateLightParamLight(fL, p, d);
	}

	if (p.isOutline <= 0)
	{
		#if defined(_SUBSURFACE)
		half3 sssContrib = 0;
		#if defined(USING_DIRECTIONAL_LIGHT)
		sssContrib += getSubsurfaceScatteringLight(l, p.normal, p.view, totalShadow, c.thickness);
		#endif
		sssContrib += getSubsurfaceScatteringLight(iL, p.normal, p.view, 1.0, c.thickness);
		finalColor += sssContrib * c.albedo;
		#endif

		#if defined(_SPECULAR)
        half3 reflDir = d.reflDir;
        half roughness = PerceptualRoughnessToRoughness(c.perceptualRoughness);
        roughness = max(roughness, 0.002);

        if ((int)_SpecularType == 3)
        {
            half3  anisoDir   = p.anisotropy >= 0.0 ? p.anisotropicB : p.anisotropicT;
            half3  anisoTan   = cross(anisoDir, p.view);
            half3  anisoNrm   = cross(anisoTan, anisoDir);
            half   bendFactor = abs(p.anisotropy) * saturate(5.0 * c.perceptualRoughness);
            half3  bentNormal = normalize(lerp(p.normal, anisoNrm, bendFactor));

            reflDir = reflect(-p.view, bentNormal);
        }
        reflDir = getSpecularDominantDirection(p.normal, reflDir, roughness);

		half3 indirectSpecular = CGetIndirectSpecular(reflDir, p.position, p.normalizedViewportCoord, c.perceptualRoughness, c.occlusion);
		half3 directSpec   = getDirectSpecular(c, p, fD, fL, 1.0);
        half3 indirectSpec = getIndirectSpecular(c, p, d, indirectSpecular);
        finalColor += directSpec + indirectSpec;
        #endif
    };


    return finalColor;
}

half3 SCSS_ShadeLight(const SCSS_Input c, const SCSS_ShadingParam p, const CompatLight l)
{
	half3 finalColor;

	SCSS_LightParam d = initialiseLightParam(l, p);
    half remappedLight = getRemappedLight(c.perceptualRoughness, d);
	remappedLight = remappedLight * 0.5 + 0.5;

	if (_SDFMode)
	{
		remappedLight = getSDFLightingMasked(l.direction, c.sdf, c.sdfSmoothness, remappedLight, c.sdfMask);
	}

	// Prepare Lightramp/Crosstone parameters to pass on
	#if defined(SCSS_CROSSTONE)
    SCSS_CrosstoneData shadingData = initaliseCrosstoneParam(c);
	#else
    SCSS_LightrampData shadingData = initaliseLightrampParam(c);
	#endif

    finalColor = calcDiffuseAdd(c.albedo, shadingData, l.color, remappedLight);

    half totalAtten = l.attenuation * l.shadowAttenuation;
    finalColor *= totalAtten;

	if (p.isOutline <= 0)
	{
		#if defined(_SUBSURFACE)
		finalColor += c.albedo * getSubsurfaceScatteringLight(l, p.normal, p.view,
			totalAtten, c.thickness);
		#endif

		#if (defined(_SPECULAR))
        half3 directSpec   = getDirectSpecular(c, p, d, l, totalAtten);
        finalColor += directSpec;
        #endif
	};

	return finalColor;
}

half3 SCSS_ApplyLighting(SCSS_Input c, SCSS_ShadingParam p)
{
	#if defined(_METALLICGLOSSMAP)
	// Perceptual roughness transformation. Without this, roughness handling is wrong.
	half perceptualRoughness = SmoothnessToPerceptualRoughness(c.smoothness);
	perceptualRoughness = IsotropicNDFFiltering(p.geometricNormal.xyz, perceptualRoughness);
	c.perceptualRoughness = perceptualRoughness;
	#else
	// Disable DisneyDiffuse for cel specular.
	#endif

	// Todo: Add in the other parameters needed by URP.
    // - shadowCoord: 0 tells CompatURP to calculate it from World Position.
    // - shadowMask: 1.0 assumes no baked shadow mask for now (ShadowMask support would require reading lightmap UVs here).
	CompatLight l = CGetMainLight(p.position.xyz, p.normalizedViewportCoord,
	    /* shadowCoord */ 0, /* shadowMask */ 1.0,
		c.occlusion, p.attenuation);

    CompatSHData compatSH = CGetSHData(p.position, p.normal);
    SHdata sh = ConvertCompatSH(compatSH);

    #if defined(SCSS_USE_VRC_LIGHT_VOLUMES)
    LightVolumeSH(p.position, sh.L0, sh.L1r, sh.L1g, sh.L1b);
    #endif

	SCSS_LightParam d = initialiseLightParam(l, p, sh);

	// Generic lighting for effects.
	half3 effectLighting = FLT_EPS + l.color;
	half3 effectLightShadow = l.color * max((1+d.NdotL)*l.shadowAttenuation, 0);

	#if defined(UNITY_PASS_FORWARDBASE) || defined(SCSS_IS_URP)
	effectLighting += d.sh.L0;
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
	    half maxEffectLight = max3(effectLighting);
	    // The effect lighting is remapped to be within the 0-1.25 range when clamped.
	    half modLight = min(maxEffectLight, 1.25);
	    // Scale the values by the highest value.
	    // Needs a bit more testing, but should look nice.
	    effectLighting = (effectLighting/maxEffectLight)*modLight;
	}

    // Apply minimum brightness
    l.color += _LightAddAnimated;

	half3 finalColor = 0;

    #if defined(UNITY_PASS_FORWARDBASE) || defined(SCSS_IS_URP)
        // Base pass includes GI and Emissive
        finalColor = SCSS_ShadeBase(c, p, l, d);
    #else
        // Add pass is direct light only
        finalColor = SCSS_ShadeLight(c, p, l);
    #endif

    // Iterate additional Lights (URP: all others, BIRP: vertex Lights)
    CompatLightIterator iter = CInitLightLoop(p.normalizedViewportCoord, p.position);
    CompatLight addLight;
    while(CGetNextLight(iter, p.position, /*shadowMask*/ 1.0, c.occlusion, addLight))
    {
        if (getLightClampActive()) addLight.color = saturate(addLight.color);

        finalColor += SCSS_ShadeLight(c, p, addLight);
    }

	#if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
		lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, p.lightmapUV));
		finalColor *= lightmap;
	#endif

	// Apply the light scaling if the light clamp is active. When the light clamp is active,
	// the final colour is divided by the main light intensity.
	// Todo: Test in URP and see if it still makes sense.
   	if (getLightClampActive()) finalColor = finalColor / max(max3(effectLighting), 1);

	finalColor *= _LightMultiplyAnimated;

	#if defined(UNITY_PASS_FORWARDBASE) || defined(SCSS_IS_URP)
	    half glowModifier = smoothstep(_EmissiveLightSenseStart, _EmissiveLightSenseEnd, dot(effectLightShadow, sRGB_Luminance));
		if (_UseEmissiveLightSense) c.emission *= glowModifier;
	#endif

	#if defined(UNITY_PASS_FORWARDBASE) || defined(SCSS_IS_URP)
	    // finalColor = lerp(finalColor, c.emission, c.emission.a);
	    finalColor += c.emission;
	#endif

	return finalColor;
}

#endif // SCSS_CORE_INCLUDED
