#ifndef SCSS_FORWARD_INCLUDED
// UNITY_SHADER_NO_UPGRADE
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

	#if defined(SCSS_SCREEN_SHADOW_FILTER) && defined(USING_SHADOWS_UNITY) && !defined(UNITY_PASS_SHADOWCASTER)
	correctedScreenShadowsForMSAA(i._ShadowCoord, atten);
	#endif

	#if defined(USING_SHADOWS_UNITY) && !defined(UNITY_PASS_SHADOWCASTER)
	float3 lightPos = UnityWorldSpaceLightDir(i.posWorld.xyz);
		#if defined(_CONTACTSHADOWS)
		// Only calculate contact shadows if we're not in shadow. 
		if (atten > 0)
		{
			atten *= 1.0 - screenSpaceContactShadow(lightPos, i.posWorld.xyz, i.pos.xy, _ContactShadowDistance);
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
    shading.isOutline = i.extraData.x;

    #if (defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON))
        shading.lightmapUV = lightmapUV;
    #endif
}

void prepareMaterial (inout SCSS_ShadingParam shading, const SCSS_Input material) {
    shading.normal = normalize(mul(shading.tangentToWorld, material.normalTangent));
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

inline SCSS_Input MaterialSetup(SCSS_TexCoords tc,
	float4 i_color, float4 i_extraData, float p_isOutline, uint facing)
{
	SCSS_Input material = (SCSS_Input)0;
	initMaterial(material);

	// Note: Outline colour is part of the material data, but is set by applyVertexColour. 
	
	// Todo: Revamp
	float2 mainUVs = TexCoords(tc);

	// Darken some effects on outlines. 
	// Note that MSAA means this isn't a strictly binary thing.
    half outlineDarken = 1-p_isOutline;

	material.alpha = Alpha(mainUVs, tc.uv[0]);

	#if defined(_BACKFACE)
		if (!facing) material.alpha = BackfaceAlpha(mainUVs);
	#endif

    material.normalTangent = NormalInTangentSpace(mainUVs);

    // Todo: Allow passing anisotropy direction
    material.anisotropyDirection = float3(1, 0, 0);

	material.albedo = Albedo(mainUVs);

	#if defined(_BACKFACE)
		if (!facing) material.albedo = BackfaceAlbedo(mainUVs);
	#endif

	#if !defined(SCSS_CROSSTONE)
		material.tone[0] = Tonemap(mainUVs, material.occlusion);
	#endif

	#if defined(SCSS_CROSSTONE)
		material.tone[0] = Tonemap1st(mainUVs);
		material.tone[1] = Tonemap2nd(mainUVs);
		material.occlusion = ShadingGradeMap(mainUVs);
	#endif

	applyVertexColour(i_color.rgb, material);

	// Todo: Refactor this 
	{
		float tintMask = ColorMask(mainUVs);

		if (_ToggleHueControls)
		{
			material.albedo = applyMaskedHSVToAlbedo(material.albedo, tintMask, _ShiftHue, _ShiftSaturation, _ShiftValue);
			material.tone[0].col = applyMaskedHSVToAlbedo(material.tone[0].col, tintMask, _ShiftHue, _ShiftSaturation, _ShiftValue);
			material.tone[1].col = applyMaskedHSVToAlbedo(material.tone[1].col, tintMask, _ShiftHue, _ShiftSaturation, _ShiftValue);
		}

		material.albedo *= LerpWhiteTo_local(_Color.rgb, tintMask);
		if (_CrosstoneToneSeparation) material.tone[0].col *= LerpWhiteTo_local(_Color.rgb, tintMask);
		if (_Crosstone2ndSeparation) material.tone[1].col *= LerpWhiteTo_local(_Color.rgb, tintMask);
	}

	#if defined(_DETAIL)
    {
        float4 _DetailMask_var = DetailMask(tc.uv[0]);
        applyDetail(material, _DetailMap1, getDetailUVs(tc.uv[_DetailMap1UV], _DetailMap1_ST), _DetailMap1Type, _DetailMap1Blend, _DetailMap1Strength * _DetailMask_var[0]);
        applyDetail(material, _DetailMap2, getDetailUVs(tc.uv[_DetailMap2UV], _DetailMap2_ST), _DetailMap2Type, _DetailMap2Blend, _DetailMap2Strength * _DetailMask_var[1]);
        applyDetail(material, _DetailMap3, getDetailUVs(tc.uv[_DetailMap3UV], _DetailMap3_ST), _DetailMap3Type, _DetailMap3Blend, _DetailMap3Strength * _DetailMask_var[2]);
        applyDetail(material, _DetailMap4, getDetailUVs(tc.uv[_DetailMap4UV], _DetailMap4_ST), _DetailMap4Type, _DetailMap4Blend, _DetailMap4Strength * _DetailMask_var[3]);
    }
	#endif

	// Masks albedo out behind emission.
	float emissionAlpha;

	float4 emissionTexcoords = EmissionTexCoords(tc);
	float3 emission = Emission(emissionTexcoords.xy);
	
	// Apply mask mode to emission
	emission = true? emission * material.albedo : emission;

	emission = addEmissiveDetail(emission, emissionTexcoords.zw, emissionAlpha);

	float4 audiolinkUV = EmissiveAudioLinkTexCoords(tc);
	emission = addEmissiveAudiolink(emission, audiolinkUV, emissionAlpha);

	emission *= outlineDarken;
	material.emission = float4(emission, 0);
	
	material.softness = i_extraData.g;

	applyOutline(p_isOutline, material);

    // Rim lighting parameters. 
	material.rim = initialiseRimParam();
	material.rim.alpha *= RimMask(mainUVs);
	material.rim.invAlpha *= RimMask(mainUVs);
	material.rim.tint *= outlineDarken;

	// Scattering parameters
	material.thickness = Thickness(mainUVs);

	// Specular variable setup

	// Disable PBR dielectric setup in cel specular mode.
	#if defined(_SPECGLOSSMAP)
		#undef unity_ColorSpaceDielectricSpec
		#define unity_ColorSpaceDielectricSpec half4(0, 0, 0, 1)
	#endif 

	//if (_SpecularType != 0 )
	#if defined(_SPECULAR)
	{
		half4 specGloss = SpecularGloss(mainUVs);

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
	}
	#endif

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

		float4 _MatcapMask_var = MatcapMask(tc.uv[0]);
		material.albedo = applyMatcap(_Matcap1, matcapUV, material.albedo, _Matcap1Tint, _Matcap1Blend, _Matcap1Strength * _MatcapMask_var.r);
		material.albedo = applyMatcap(_Matcap2, matcapUV, material.albedo, _Matcap2Tint, _Matcap2Blend, _Matcap2Strength * _MatcapMask_var.g);
		material.albedo = applyMatcap(_Matcap3, matcapUV, material.albedo, _Matcap3Tint, _Matcap3Blend, _Matcap3Strength * _MatcapMask_var.b);
		material.albedo = applyMatcap(_Matcap4, matcapUV, material.albedo, _Matcap4Tint, _Matcap4Blend, _Matcap4Strength * _MatcapMask_var.a);
	}

	material.emission.rgb += _CustomFresnelColor.xyz * (pow(rlPow4, rcp(_CustomFresnelColor.w+FLT_EPS)));
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
	MaterialSetup(mainUVs, i.color, i.extraData, p.isOutline, facing);

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
	finalColor += material.albedo * 0.00001;

	finalColor = applyNearShading(finalColor, i.posWorld.xyz, facing);

	#if 0 // TESTING
		float3 lightPos = UnityWorldSpaceLightDir(i.posWorld.xyz);
		finalColor = lerp(finalColor, inferno_quintic(screenSpaceContactShadow(lightPos, i.posWorld.xyz, i.pos.xy)), 0.999);
		// finalColor = lerp(float4(1, 0, 0, 1), finalColor, p.attenuation>0);
	#endif

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
	UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	return finalRGBA;
}

#endif // !UNITY_PASS_SHADOWCASTER
#endif // SCSS_FORWARD_INCLUDED