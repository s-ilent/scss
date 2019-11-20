#ifndef SCSS_CORE_INCLUDED
#define SCSS_CORE_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

#include "SCSS_Utils.cginc"
#include "SCSS_Input.cginc"
#include "SCSS_UnityGI.cginc"

#define SCSS_UNIMPORTANT_LIGHTS_FRAGMENT 1

struct SCSS_Light
{
    half3 color;
    half3 dir;
    half  intensity; 
};

SCSS_Light MainLight()
{
    SCSS_Light l;

    l.color = _LightColor0.rgb;
    l.intensity = _LightColor0.w;
    l.dir = Unity_SafeNormalize(_WorldSpaceLightPos0.xyz); 
    return l;
}

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
    float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
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

		const float shadeOffset = (UNITY_PI/10.0); 
		float lightContribution = smoothstep(shadeOffset-shadeWidth, shadeOffset+shadeWidth, frac(rampPosition)); 
		lightContribution += floor(rampPosition);
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

float3 sharpFresnelLight(SCSS_LightParam d) {
	float fresnelEffect = d.rlPow4.y;
	float2 fresStep = .5 + float2(-1, 1) * fwidth(d.rlPow4.y);
	// Sharper rim lighting for the anime look.
	fresnelEffect *= _FresnelWidth;
	float2 fresStep_var = lerp(float2(0.0, 1.0), fresStep, 1-_FresnelStrength);
	fresnelEffect = smoothstep(fresStep_var.x, fresStep_var.y, fresnelEffect);
	return fresnelEffect * _FresnelTint.rgb * _FresnelTint.a;
}

float3 applyBlendMode(int blendOp, half3 a, half3 b, half t)
{
	switch (blendOp) 
	{
		default:
		case 0: return a + b * t;
		case 1: return a * LerpWhiteTo(b, t);
		case 2: return a + b * a * t;
	}
}

float3 applyMatcap(sampler2D src, float3 dst, float3 normal, float3 light, float3 viewDir, int blendMode, float blendStrength)
{
	// Based on Masataka SUMI's implementation
	half3 worldUp = float3(0, 1, 0);
	half3 worldViewUp = normalize(worldUp - viewDir * dot(viewDir, worldUp));
	half3 worldViewRight = normalize(cross(viewDir, worldViewUp));
	half2 matcapUV = half2(dot(worldViewRight, normal), dot(worldViewUp, normal)) * 0.5 + 0.5;
	
	return applyBlendMode(blendMode, dst, tex2D(src, matcapUV), blendStrength);
}

//SSS method from GDC 2011 conference by Colin Barre-Bresebois & Marc Bouchard and modified by Xiexe
float3 getSubsurfaceScatteringLight (SCSS_Light l, float3 normalDirection, float3 viewDirection, 
	float attenuation, float3 thickness, float3 indirectLight)
{
	float3 vSSLight = l.dir + normalDirection * _SSSDist; // Distortion
	float3 vdotSS = pow(saturate(dot(viewDirection, -vSSLight)), _SSSPow) 
		* _SSSIntensity; 
	
	return lerp(1, attenuation, float(any(_WorldSpaceLightPos0.xyz))) 
				* (vdotSS + _SSSAmbient) * abs(_ThicknessMapInvert-thickness)
				* (l.color + indirectLight) * _SSSCol;
				
}

float applyShadowLift(float baseLight, float occlusion)
{
	baseLight *= (1 - _Shadow) * occlusion + _Shadow;
	baseLight = _ShadowLift + baseLight * (1-_ShadowLift);
	return baseLight;
}

float getRemappedLight(half perceptualRoughness, half attenuation, SCSS_LightParam d)
{
	float remappedLight = d.NdotL * attenuation
		* DisneyDiffuse(d.NdotV, d.NdotL, d.LdotH, perceptualRoughness);
	return remappedLight;
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

half3 calcDiffuseBase(float3 tonemap, float occlusion, half3 normal, half perceptualRoughness, half attenuation, 
	half smoothness, half softness, SCSS_LightParam d, SCSS_Light l)
{
	float remappedLight = getRemappedLight(perceptualRoughness, attenuation, d);
	remappedLight = remappedLight * 0.5 + 0.5;
	remappedLight = applyShadowLift(remappedLight, occlusion);

	float3 lightContribution = sampleRampWithOptions(remappedLight, softness);

	float3 directLighting = 0.0;
	float3 indirectLighting = 0.0;

	getDirectIndirectLighting(normal, /*out*/ directLighting, /*out*/ indirectLighting);
	
	if (_UseFresnel == 1) 
	{
		float sharpFresnel = sharpFresnelLight(d);
		lightContribution += lightContribution*sharpFresnel;
		directLighting += directLighting*sharpFresnel;
	}
	
	indirectLighting = lerp(indirectLighting, directLighting, tonemap);

	lightContribution = lerp(tonemap, 1.0, lightContribution);
	lightContribution *= l.color;
	
	float3 ambientLightDirection = Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);
	float ambientLight = dot(normal, ambientLightDirection);
	ambientLight = ambientLight * 0.5 + 0.5;
	ambientLight = applyShadowLift(ambientLight, occlusion);

	lightContribution += lerp(indirectLighting, directLighting, sampleRampWithOptions(ambientLight, softness));

	return lightContribution;	
}

half3 calcDiffuseAdd(float3 tonemap, float occlusion, half perceptualRoughness, 
	half smoothness, half softness, SCSS_LightParam d, SCSS_Light l)
{
	float remappedLight = getRemappedLight(perceptualRoughness, 1.0, d);
	remappedLight = remappedLight * 0.5 + 0.5;
	remappedLight = applyShadowLift(remappedLight, occlusion);

	float3 lightContribution = sampleRampWithOptions(remappedLight, softness);

	float3 directLighting = l.color;
	float3 indirectLighting = l.color * tonemap;

	if (_UseFresnel == 1) 
	{
		float sharpFresnel = sharpFresnelLight(d);
		directLighting += directLighting*sharpFresnel;
	}

	lightContribution = lerp(indirectLighting, directLighting, lightContribution);
	return lightContribution;
}

half3 calcVertexLight(float4 vertexAttenuation, float occlusion, float3 tonemap, half softness)
{
	float3 vertexContribution = 0;
	#if defined(UNITY_PASS_FORWARDBASE)
		// Vertex lighting based on Shade4PointLights
		vertexAttenuation *= (1 - _Shadow) * occlusion + _Shadow;
		float4 vertexAttenuationFalloff = saturate(vertexAttenuation * 10);

	    vertexContribution += unity_LightColor[0] * (sampleRampWithOptions(vertexAttenuation.x, softness)+tonemap) * vertexAttenuationFalloff.x;
	    vertexContribution += unity_LightColor[1] * (sampleRampWithOptions(vertexAttenuation.y, softness)+tonemap) * vertexAttenuationFalloff.y;
	    vertexContribution += unity_LightColor[2] * (sampleRampWithOptions(vertexAttenuation.z, softness)+tonemap) * vertexAttenuationFalloff.z;
	    vertexContribution += unity_LightColor[3] * (sampleRampWithOptions(vertexAttenuation.w, softness)+tonemap) * vertexAttenuationFalloff.w;
	#endif
	return vertexContribution;
}

void getSpecularVD(float roughness, float3 normal, float3 viewDir, SCSS_LightParam d, SCSS_Light l, VertexOutput i,
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

	case 4: // Strand
		V = SmithJointGGXVisibilityTerm (d.NdotL, d.NdotV, roughness);
		// Temporary
		//i.tangentDir = ShiftTangent(i.tangentDir, normal, roughness);
	    // exponent, strength
		D = StrandSpecular(i.tangentDir, 
			viewDir, l.dir, d.halfDir, 
			_Anisotropy*100, 1.0 );
		D += StrandSpecular(i.tangentDir, 
			viewDir, l.dir, d.halfDir, 
			_Anisotropy*10, 0.05 );
	    break;
	}
	return;
}

half3 calcSpecularBase(float3 specColor, float smoothness, float3 normal, float oneMinusReflectivity, float perceptualRoughness,
	float3 viewDir, float attenuation, SCSS_LightParam d, SCSS_Light l, VertexOutput i)
{
	UnityGI gi = (UnityGI)0;
	
	half V = 0; half D = 0; 
	float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	//float roughness = (perceptualRoughness);

	// "GGX with roughness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughness remapping."
	// This also fixes issues with the other specular types.
	roughness = max(roughness, 0.002);

	getSpecularVD(roughness, normal, viewDir, d, l, i, /*out*/ V, /*out*/ D);

	half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
	specularTerm = max(0, specularTerm * d.NdotL);

	#if defined(_SPECULARHIGHLIGHTS_OFF)
    	specularTerm = 0.0;
	#endif

	half surfaceReduction = 1.0 / (roughness*roughness + 1);

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

	gi =  GetUnityGI(l.color.rgb, l.dir, 
	normal, viewDir, d.reflDir, attenuation, perceptualRoughness, i.posWorld.xyz);

	float grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));

	return
	specularTerm * (gi.light.color) * FresnelTerm(specColor, d.LdotH) +
	surfaceReduction * (gi.indirect.specular.rgb) * FresnelLerp(specColor, grazingTerm, d.NdotV);
	
}

half3 calcSpecularAdd(float3 specColor, float smoothness, float3 normal, float oneMinusReflectivity, float perceptualRoughness,
	float3 viewDir, SCSS_LightParam d, SCSS_Light l, VertexOutput i)
{
	#if defined(_SPECULARHIGHLIGHTS_OFF)
		return 0.0;
	#endif
	
	half V = 0; half D = 0; 
	float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

	// "GGX with roughness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughness remapping."
	// This also fixes issues with the other specular types.
	roughness = max(roughness, 0.002);

	getSpecularVD(roughness, normal, viewDir, d, l, i, /*out*/ V, /*out*/ D);

	half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
	specularTerm = max(0, specularTerm * d.NdotL);

    // To provide true Lambert lighting, we need to be able to kill specular completely.
    specularTerm *= any(specColor) ? 1.0 : 0.0;

	return
	specularTerm * l.color * FresnelTerm(specColor, d.LdotH);
	
}

float3 SCSS_ApplyLighting(SCSS_Input c, SCSS_LightParam d, VertexOutput i, float3 viewDir, SCSS_Light l,
	float2 texcoords)
{
	UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);

	// Perceptual roughness transformation. Without this, roughness handling is wrong.
	float perceptualRoughness = SmoothnessToPerceptualRoughness(c.smoothness);

	// Apply matcap before specular effect.
	if (_UseMatcap == 1) 
	{
		float3 matcapLight = l.color;
		#if defined(UNITY_PASS_FORWARDBASE)
		matcapLight += BetterSH9(half4(0.0,  0.0, 0.0, 1.0));
		#endif
		float4 _MatcapMask_var = MatcapMask(texcoords.xy);
		c.albedo = applyMatcap(_Matcap1, c.albedo, c.normal, matcapLight, viewDir, _Matcap1Blend, _Matcap1Strength * _MatcapMask_var.r);
		c.albedo = applyMatcap(_Matcap2, c.albedo, c.normal, matcapLight, viewDir, _Matcap2Blend, _Matcap2Strength * _MatcapMask_var.g);
		c.albedo = applyMatcap(_Matcap3, c.albedo, c.normal, matcapLight, viewDir, _Matcap3Blend, _Matcap3Strength * _MatcapMask_var.b);
		c.albedo = applyMatcap(_Matcap4, c.albedo, c.normal, matcapLight, viewDir, _Matcap4Blend, _Matcap4Strength * _MatcapMask_var.a);
	}

	float3 finalColor; 

	if (_UseFresnel == 3 && i.is_outline == 0)
	{
		d.NdotL = saturate(max(d.NdotL, sharpFresnelLight(d)));
	}

	#if defined(UNITY_PASS_FORWARDBASE)
	finalColor = calcDiffuseBase(c.tonemap, c.occlusion, c.normal, 
		perceptualRoughness, attenuation, c.smoothness, c.softness, d, l);
	#endif

	#if defined(UNITY_PASS_FORWARDADD)
	finalColor = calcDiffuseAdd(c.tonemap, c.occlusion, 
		perceptualRoughness, c.smoothness, c.softness, d, l);
	#endif

	// Proper cheap vertex lights. 
	#if defined(VERTEXLIGHT_ON) && !defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
	finalColor += calcVertexLight(i.vertexLight, c.occlusion, c.tonemap, c.softness);
	#endif

	if (_UseFresnel == 2 && i.is_outline == 0)
	{
		finalColor *= 1+sharpFresnelLight(d);
	}

	finalColor *= c.albedo;

	//if (_SpecularType != 0 && i.is_outline == 0)
	#if defined(_METALLICGLOSSMAP)
	if (i.is_outline == 0)
	{
    	finalColor += calcSpecularBase(c.specColor, c.smoothness, c.normal, c.oneMinusReflectivity, perceptualRoughness, 
    		viewDir, attenuation, d, l, i);
    };
    #endif

    // Apply full lighting to unimportant lights. This is cheaper than you might expect.
	#if defined(UNITY_PASS_FORWARDBASE) && defined(VERTEXLIGHT_ON) && defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
    for (int num = 0; num < 4; num++) {
    	l.color = unity_LightColor[num].rgb;
    	l.dir = normalize(float3(unity_4LightPosX0[num], unity_4LightPosY0[num], unity_4LightPosZ0[num]) - i.posWorld.xyz);

    	d.NdotL = saturate(dot(l.dir, c.normal)); // Calculate NdotL
		d.halfDir = Unity_SafeNormalize (l.dir + viewDir);
		d.LdotH = saturate(dot(l.dir, d.halfDir));
		d.NdotH = saturate(dot(c.normal, d.halfDir));

    	finalColor += calcDiffuseAdd(c.tonemap, c.occlusion, perceptualRoughness, c.smoothness, c.softness, d, l) * c.albedo * i.vertexLight[num];

		//if (_SpecularType != 0 && i.is_outline == 0)
		#if defined(_METALLICGLOSSMAP)
		if (i.is_outline == 0)
		{
    	finalColor += calcSpecularAdd(c.specColor, c.smoothness, c.normal, c.oneMinusReflectivity, perceptualRoughness, 
    	viewDir, d, l, i) * i.vertexLight[num];
    	}
    	#endif
    };
	#endif

	#if defined(UNITY_PASS_FORWARDADD)
		finalColor *= attenuation;
	#endif

	if (_UseSubsurfaceScattering == 1 && i.is_outline == 0)
	{
	float3 thicknessMap_var = pow(Thickness(texcoords.xy), _ThicknessMapPower);
	finalColor += c.albedo * getSubsurfaceScatteringLight(l, c.normal, viewDir,
		attenuation, thicknessMap_var, c.tonemap);
	};
	return finalColor;
}

#endif // SCSS_CORE_INCLUDED