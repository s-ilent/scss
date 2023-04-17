#ifndef SCSS_FORWARD_INCLUDED
#define SCSS_FORWARD_INCLUDED

#include "SCSS_Attributes.cginc"
#include "SCSS_ForwardVertex.cginc"

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
    shading.position = i.posWorld;
    shading.view = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);

    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
    float2 lightmapUV = i.uvPack0.zw * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif

    UNITY_LIGHT_ATTENUATION(atten, i, shading.position)

	#if defined(SCSS_SCREEN_SHADOW_FILTER) && defined(USING_SHADOWS_UNITY)
	correctedScreenShadowsForMSAA(i._ShadowCoord, atten);
	#endif

    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
    GetBakedAttenuation(atten, lightmapUV, shading.position);
    #endif

	#if defined(VERTEXLIGHT_ON)
	shading.vertexLight = i.vertexLight;
	#endif

    shading.attenuation = atten;
    shading.isOutline = i.extraData.x;

    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
        shading.lightmapUV = lightmapUV;
    #else
        shading.lightmapUV = 0;
    #endif
}

void prepareMaterial (inout SCSS_ShadingParam shading, const SCSS_Input material) {
    shading.normal = normalize(mul(shading.tangentToWorld, material.normalTangent));
    // shading.normal = shading.geometricNormal;
    shading.NoV = clampNoV(dot(shading.normal, shading.view));
    shading.reflected = reflect(-shading.view, shading.normal);
}

float3 addEmissiveDetail(float3 emission, float2 emissionDetailUV, out float alpha)
{
	float4 emissionDetail = EmissionDetail(emissionDetailUV);

	alpha = emissionDetail.w;
	emission = emissionDetail.rgb * emission * _EmissionColor.rgb;

	return emission;
}

float3 addEmissiveAudiolink(float3 emission, float4 audiolinkUV, inout float alpha)
{
	emission += EmissiveAudioLink(audiolinkUV.xy, audiolinkUV.zw);
	return emission;
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
	if (p.isOutline && !facing) discard;
	
	// Darken some effects on outlines. 
	// Note that MSAA means this isn't a strictly binary thing.
    half outlineDarken = 1-p.isOutline;

	float4 texcoords = TexCoords(i.uvPack0, i.uvPack1);
	float4 detailNStexcoords = DetailNormalSpecularTexCoords(i.uvPack0, i.uvPack1);

	// Ideally, we should pass all input to lighting functions through the 
	// material parameter struct. But there are some things that are
	// optional. Review this at a later date...

	SCSS_Input material = (SCSS_Input) 0;
	initMaterial(material);

	material.alpha = Alpha(texcoords.xy, i.uvPack0.xy);

	#if defined(_BACKFACE)
	if (!facing) material.alpha = BackfaceAlpha(texcoords.xy);
	#endif

    #if defined(ALPHAFUNCTION)
    alphaFunction(material.alpha);
	#endif

	applyVanishing(material.alpha);
	
	applyAlphaClip(material.alpha, _Cutoff, i.pos.xy, _AlphaSharp);

	half detailMask = DetailMask(texcoords.xy);

	float4 normalTexcoords = float4(texcoords.xy, detailNStexcoords.xy);
    half3 normalTangent = NormalInTangentSpace(normalTexcoords, detailMask);
    material.normalTangent = normalTangent;

    // Todo: Allow passing anisotropy direction
    material.anisotropyDirection = float3(1, 0, 0);

	material.albedo = Albedo(texcoords);

	#if defined(_BACKFACE)
	if (!facing) material.albedo = BackfaceAlbedo(texcoords);
	#endif

	#if !defined(SCSS_CROSSTONE)
	material.tone[0] = Tonemap(texcoords.xy, material.occlusion);
	#endif

	#if defined(SCSS_CROSSTONE)
	material.tone[0] = Tonemap1st(texcoords.xy);
	material.tone[1] = Tonemap2nd(texcoords.xy);
	material.occlusion = ShadingGradeMap(texcoords.xy);
	#endif

	applyDetail(texcoords, material);
	
	#if defined(_BACKFACE)
	if (!facing) applyBackfaceDetail(texcoords, material);
	#endif

	applyVertexColour(i.color, p.isOutline, material);

	// Masks albedo out behind emission.
	float emissionAlpha;

	float4 emissionTexcoords = EmissionTexCoords(i.uvPack0, i.uvPack1);
	float3 emission = Emission(emissionTexcoords.xy);
	emission = addEmissiveDetail(emission, emissionTexcoords.zw, emissionAlpha);

	float4 audiolinkUV = EmissiveAudioLinkTexCoords(i.uvPack0, i.uvPack1);
	emission = addEmissiveAudiolink(emission, audiolinkUV, emissionAlpha);

	emission *= outlineDarken;
	material.emission = float4(emission, 0);
	
	material.softness = i.extraData.g;

	applyOutline(p.isOutline, material);

    // Rim lighting parameters. 
	material.rim = initialiseRimParam();
	material.rim.alpha *= RimMask(texcoords.xy);
	material.rim.invAlpha *= RimMask(texcoords.xy);
	material.rim.tint *= outlineDarken;

	// Scattering parameters
	material.thickness = Thickness(texcoords.xy);

	// Specular variable setup

	// Disable PBR dielectric setup in cel specular mode.
	#if defined(_SPECGLOSSMAP)
	#undef unity_ColorSpaceDielectricSpec
	#define unity_ColorSpaceDielectricSpec half4(0, 0, 0, 1)
	#endif 

	//if (_SpecularType != 0 )
	#if defined(_SPECULAR)
	{
		half4 specGloss = SpecularGloss(texcoords.xy, detailNStexcoords.zw, detailMask);

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
		material.specColor  *= outlineDarken;
		material.smoothness *= outlineDarken;

		// Specular energy converservation. From EnergyConservationBetweenDiffuseAndSpecular in UnityStandardUtils.cginc
		material.oneMinusReflectivity = 1 - SpecularStrength(material.specColor); 

		if (_UseMetallic == 1)
		{
			// From DiffuseAndSpecularFromMetallic
			material.oneMinusReflectivity = OneMinusReflectivityFromMetallic(material.specColor);
			material.specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, material.albedo, material.specColor);
		}

		if (_UseEnergyConservation == 1)
		{
			material.albedo.xyz = material.albedo.xyz * (material.oneMinusReflectivity); 
			if (_CrosstoneToneSeparation) material.tone[0].col = material.tone[0].col * (material.oneMinusReflectivity); 
			if (_Crosstone2ndSeparation)  material.tone[1].col = material.tone[1].col * (material.oneMinusReflectivity); 
		}
	}
	#endif

	#if !defined(USING_TRANSPARENCY)
		material.alpha = 1.0;
	#endif

    // When premultiplied mode is set, this will multiply the diffuse by the alpha component,
    // allowing to handle transparency in physically correct way - only diffuse component gets affected by alpha
    half outputAlpha;
    material.albedo = PreMultiplyAlpha_local (material.albedo, material.alpha, material.oneMinusReflectivity, /*out*/ outputAlpha);

    prepareMaterial(p, material);

    // Local light parameters. These are a bit redundant, but maybe there's a way to clean them out.

	SCSS_Light l = MainLight(p.position.xyz);
	SCSS_LightParam d = initialiseLightParam(l, p);
	// Todo
	float3 bitangentDir = p.tangentToWorld[1].xyz;
	float rlPow4 = Pow4(1 - p.NoV);

	// This is changed from how it works normally. This should be reevaluated based on user feedback. 
	if (_UseFresnel)
	{
		float NdotH = d.NdotH;
		float fresnelLightMaskBase = LerpOneTo(NdotH, _UseFresnelLightMask);
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
		//if (applyToFinal) finalRimLight = rimFinal * outlineDarken;
		if (applyToFinal) material.albedo += rimFinal * outlineDarken;

	}
	
	// Apply matcap before specular effect.
	if (_UseMatcap >= 1 && p.isOutline <= 0) 
	{
		half2 matcapUV;
		if (_UseMatcap == 1) matcapUV = getMatcapUVsOriented(p.normal, p.view, float3(0, 1, 0));
		if (_UseMatcap == 2) matcapUV = getMatcapUVsOriented(p.normal, p.view, bitangentDir.xyz);

		float4 _MatcapMask_var = MatcapMask(texcoords);
		material.albedo = applyMatcap(_Matcap1, matcapUV, material.albedo, _Matcap1Tint, _Matcap1Blend, _Matcap1Strength * _MatcapMask_var.r);
		material.albedo = applyMatcap(_Matcap2, matcapUV, material.albedo, _Matcap2Tint, _Matcap2Blend, _Matcap2Strength * _MatcapMask_var.g);
		material.albedo = applyMatcap(_Matcap3, matcapUV, material.albedo, _Matcap3Tint, _Matcap3Blend, _Matcap3Strength * _MatcapMask_var.b);
		material.albedo = applyMatcap(_Matcap4, matcapUV, material.albedo, _Matcap4Tint, _Matcap4Blend, _Matcap4Strength * _MatcapMask_var.a);
	}

	material.emission.rgb += _CustomFresnelColor.xyz * (pow(rlPow4, rcp(_CustomFresnelColor.w+FLT_EPS)));

	// Lighting handling
	float3 finalColor = SCSS_ApplyLighting(material, p);
	finalColor += material.albedo * 0.00001;

	finalColor = applyNearShading(finalColor, i.posWorld.xyz, facing);

    #if defined(USING_COVERAGE_OUTPUT)
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
	UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	return finalRGBA;
}

#endif // SCSS_FORWARD_INCLUDED