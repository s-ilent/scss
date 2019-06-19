#ifndef SCSS_CORE_INCLUDED
#define SCSS_CORE_INCLUDED

#include "SCSS_Utils.cginc"
#include "SCSS_Input.cginc"
#include "SCSS_UnityGI.cginc"

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
    corr.x = fastRcpSqrtNR1(lengthSq.x);
    corr.y = fastRcpSqrtNR1(lengthSq.y);
    corr.z = fastRcpSqrtNR1(lengthSq.z);
    corr.w = fastRcpSqrtNR1(lengthSq.x);

    ndotl = corr * ndotl * 0.5 + 0.5; // Match with Forward for light ramp sampling
    ndotl = max (float4(0,0,0,0), ndotl);
    // attenuation
    float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
    float4 diff = ndotl * atten;
    return diff;
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

// BRDF based on implementation in Filament.
// https://github.com/google/filament

float D_Ashikhmin(float linearRoughness, float NoH) {
    // Ashikhmin 2007, "Distribution-based BRDFs"
	float a2 = linearRoughness * linearRoughness;
	float cos2h = NoH * NoH;
	float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
	float sin4h = sin2h * sin2h;
	float cot2 = -cos2h / (a2 * sin2h);
	return 1.0 / (UNITY_PI * (4.0 * a2 + 1.0) * sin4h) * (4.0 * exp(cot2) + sin4h);
}

float D_Charlie(float linearRoughness, float NoH) {
    // Estevez and Kulla 2017, "Production Friendly Microfacet Sheen BRDF"
    float invAlpha  = 1.0 / linearRoughness;
    float cos2h = NoH * NoH;
    float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
    return (2.0 + invAlpha) * pow(sin2h, invAlpha * 0.5) / (2.0 * UNITY_PI);
}

float V_Neubelt(float NoV, float NoL) {
    // Neubelt and Pettineo 2013, "Crafting a Next-gen Material Pipeline for The Order: 1886"
    return saturate(1.0 / (4.0 * (NoL + NoV - NoL * NoV)));
}

float D_GGX_Anisotropic(float NoH, const float3 h,
        const float3 t, const float3 b, float at, float ab) {
    float ToH = dot(t, h);
    float BoH = dot(b, h);
    float a2 = at * ab;
    float3 v = float3(ab * ToH, at * BoH, a2 * NoH);
    float v2 = dot(v, v);
    float w2 = a2 / v2;
    return a2 * w2 * w2 * UNITY_INV_PI;
}

float V_SmithGGXCorrelated_Anisotropic(float at, float ab, float ToV, float BoV,
        float ToL, float BoL, float NoV, float NoL) {
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    float lambdaV = NoL * length(float3(at * ToV, ab * BoV, NoV));
    float lambdaL = NoV * length(float3(at * ToL, ab * BoL, NoL));
    float v = 0.5 / (lambdaV + lambdaL + 1e-7f);
    return v;
}

// From "From mobile to high-end PC: Achieving high quality anime style rendering on Unity"
float3 ShiftTangent (float3 T, float3 N, float shift) 
{
	float3 shiftedT = T + shift * N;
	return normalize(shiftedT);
}

float StrandSpecular(float3 T, float3 V, float3 L, float3 H, float exponent, float strength)
{
	//float3 H = normalize(L+V);
	float dotTH = dot(T, H);
	float sinTH = sqrt(1.0-dotTH*dotTH);
	float dirAtten = smoothstep(-1.0, 0.0, dotTH);
	return dirAtten * pow(sinTH, exponent) * strength;
}

// Get the maximum SH contribution
// synqark's Arktoon shader's shading method
half3 GetSHLength ()
{
    half3 x, x1;
    x.r = length(unity_SHAr);
    x.g = length(unity_SHAg);
    x.b = length(unity_SHAb);
    x1.r = length(unity_SHBr);
    x1.g = length(unity_SHBg);
    x1.b = length(unity_SHBb);
    return x + x1;
}

// Sample ramp with the specified options.
// rampPosition: 0-1 position on the light ramp from light to dark
// softness: 0-1 position on the light ramp on the other axis
float3 sampleRampWithOptions(float rampPosition, half softness) 
{
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

struct MatcapOutput 
{
	half3 add;
	half3 multiply;
};

MatcapOutput getMatcapEffect(float3 normal, SCSS_Light l, float3 viewDir, float2 texcoords)
{
	MatcapOutput matcaps = (MatcapOutput) 0;
	// Based on Masataka SUMI's implementation
	half3 worldUp = float3(0, 1, 0);
	half3 worldViewUp = normalize(worldUp - viewDir * dot(viewDir, worldUp));
	half3 worldViewRight = normalize(cross(viewDir, worldViewUp));
	half2 matcapUV = half2(dot(worldViewRight, normal), dot(worldViewUp, normal)) * 0.5 + 0.5;
	
	float3 AdditiveMatcap = tex2D(_AdditiveMatcap, matcapUV);
	float3 MultiplyMatcap = tex2D(_MultiplyMatcap, matcapUV);
	float4 _MatcapMask_var = MatcapMask(texcoords.xy);
	matcaps.add = 
		#if defined(UNITY_PASS_FORWARDBASE)
		(BetterSH9(half4(0.0,  0.0, 0.0, 1.0))+l.color)
		#endif
		#if defined(UNITY_PASS_FORWARDADD)
		(l.color)
		#endif
		*AdditiveMatcap*_AdditiveMatcapStrength*_MatcapMask_var.g;
	matcaps.multiply = LerpWhiteTo(MultiplyMatcap, _MultiplyMatcapStrength * _MatcapMask_var.w);
	return matcaps;
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

half3 calcDiffuse(float3 tonemap, float occlusion, half3 normal, half perceptualRoughness, half attenuation, 
	half smoothness, half softness, SCSS_LightParam d, SCSS_Light l)
{
#if defined(UNITY_PASS_FORWARDADD)
	attenuation = 1; // Attenuation is applied later for ForwardAdd.
#endif

	float remappedLight = d.NdotL * attenuation
		* DisneyDiffuse(d.NdotV, d.NdotL, d.LdotH, perceptualRoughness);
	remappedLight = remappedLight * 0.5 + 0.5;

	remappedLight *= (1 - _Shadow) * occlusion + _Shadow;
	remappedLight = _ShadowLift + remappedLight * (1-_ShadowLift);

	float3 lightContribution = sampleRampWithOptions(remappedLight, softness);

	float3 directLighting = 0.0;
	float3 indirectLighting = 0.0;

#if defined(UNITY_PASS_FORWARDADD)
	directLighting = 
	indirectLighting = l.color;

	if (_UseFresnel == 1) 
	{
		float sharpFresnel = sharpFresnelLight(d);
		directLighting += directLighting*sharpFresnel;
	}

	indirectLighting *= tonemap;

	lightContribution = lerp(indirectLighting, directLighting, lightContribution);
#endif

#if defined(UNITY_PASS_FORWARDBASE)
	if (_LightingCalculationType == 0) // Arktoon
	{
		directLighting   = GetSHLength();
		indirectLighting = BetterSH9(half4(0.0, 0.0, 0.0, 1.0)); 
	}
	if (_LightingCalculationType == 1) // Standard
	{
		directLighting = 
		indirectLighting = BetterSH9(half4(normal, 1.0))
						 + SHEvalLinearL2(half4(normal, 1.0));
	} 
	if (_LightingCalculationType == 2) // Cubed
	{
		directLighting   = BetterSH9(half4(0.0,  1.0, 0.0, 1.0));
		indirectLighting = BetterSH9(half4(0.0, -1.0, 0.0, 1.0)); 
	}
	if (_LightingCalculationType == 3) // True Directional
	{
		float4 ambientDir = float4(Unity_SafeNormalize(unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz), 1.0);
		directLighting   = BetterSH9(ambientDir);
		indirectLighting = BetterSH9(-ambientDir); 
	}
	
	if (_UseFresnel == 1) 
	{
		float sharpFresnel = sharpFresnelLight(d);
		lightContribution += lightContribution*sharpFresnel;
		directLighting += directLighting*sharpFresnel;
	}

	lightContribution *= l.color;

	indirectLighting *= 1+tonemap;

	float ambientProbeIntensity = (unity_SHAr.w + unity_SHAg.w + unity_SHAb.w);

	lightContribution += (1 - lightContribution) * tonemap
	 * saturate((ambientProbeIntensity)/(l.intensity+1));

	float3 ambientLightDirection = Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);
	float ambientLight = dot(normal, ambientLightDirection);
	ambientLight = ambientLight * 0.5 + 0.5;
	lightContribution += lerp(indirectLighting, directLighting, sampleRampWithOptions(ambientLight, softness));
#endif

	return lightContribution;	
}

half3 calcVertexLight(float4 vertexAttenuation, float occlusion, float3 tonemap, half softness)
{
	float3 vertexContribution = 0;
	#if defined(UNITY_PASS_FORWARDBASE)
		// Vertex lighting based on Shade4PointLights
		vertexAttenuation *= (1 - _Shadow) * occlusion + _Shadow;

	    vertexContribution += unity_LightColor[0] * (sampleRampWithOptions(vertexAttenuation.x, softness)+tonemap) * vertexAttenuation.x;
	    vertexContribution += unity_LightColor[1] * (sampleRampWithOptions(vertexAttenuation.y, softness)+tonemap) * vertexAttenuation.y;
	    vertexContribution += unity_LightColor[2] * (sampleRampWithOptions(vertexAttenuation.z, softness)+tonemap) * vertexAttenuation.z;
	    vertexContribution += unity_LightColor[3] * (sampleRampWithOptions(vertexAttenuation.w, softness)+tonemap) * vertexAttenuation.w;
	#endif
	return vertexContribution;
}

half3 calcSpecular(float3 specColor, float smoothness, float3 normal, float oneMinusReflectivity, float perceptualRoughness,
	float3 viewDir, float attenuation, SCSS_LightParam d, SCSS_Light l, VertexOutput i)
{

	UnityGI gi = (UnityGI)0;
	
	half V = 0; half D = 0; float3 shiftedTangent = 0;
	float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
	//float roughness = (perceptualRoughness);

	// "GGX with roughness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughness remapping."
	// This also fixes issues with the other specular types.
	roughness = max(roughness, 0.002);

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
	    float at = max(roughness * (1.0 + anisotropy), 0.001);
	    float ab = max(roughness * (1.0 - anisotropy), 0.001);

		#if 0
	    float TdotL = dot(i.tangentDir, l.dir);
	    float BdotL = dot(i.bitangentDir, l.dir);
	    float TdotV = dot(i.tangentDir, viewDir);
	    float BdotV = dot(i.bitangentDir, l.dir);

	    // Accurate but probably expensive
		float V = V_SmithGGXCorrelated_Anisotropic (at, ab, TdotV, BdotV, TdotL, BdotL, d.NdotV, d.NdotL);
		#else
		V = SmithJointGGXVisibilityTerm (d.NdotL, d.NdotV, roughness);
		#endif
		// Temporary
		shiftedTangent = ShiftTangent(i.tangentDir, normal, roughness);
	    D = D_GGX_Anisotropic(d.NdotH, d.halfDir, shiftedTangent, i.bitangentDir, at, ab);
	    break;

	case 4: // Strand
		V = SmithJointGGXVisibilityTerm (d.NdotL, d.NdotV, roughness);
		// Temporary
		shiftedTangent = ShiftTangent(i.tangentDir, normal, roughness);
	    // exponent, strength
		D = StrandSpecular(shiftedTangent, 
			viewDir, l.dir, d.halfDir, 
			_Anisotropy*100, 1.0 );
		D += StrandSpecular(shiftedTangent, 
			viewDir, l.dir, d.halfDir, 
			_Anisotropy*10, 0.05 );
	    break;
	}

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

float3 SCSS_ApplyLighting(SCSS_Input c, SCSS_LightParam d, VertexOutput i, float3 viewDir, SCSS_Light l,
	float2 texcoords)
{
	UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);

	// Perceptual roughness transformation...
	float perceptualRoughness = SmoothnessToPerceptualRoughness(c.smoothness);

	// Matcap handling
	if (_UseMatcap == 1) 
	{
		MatcapOutput matcaps = getMatcapEffect(c.normal, l, viewDir, texcoords.xy);
		c.albedo *= matcaps.multiply;
		c.albedo += matcaps.add;
	}

	float3 finalColor = calcDiffuse(c.tonemap, c.occlusion, c.normal, 
		perceptualRoughness, attenuation, c.smoothness, c.softness, d, l);

	#if defined(VERTEXLIGHT_ON)
	finalColor += calcVertexLight(i.vertexLight, c.occlusion, c.tonemap, c.softness);
	#endif
		
	if (_UseFresnel == 2 && i.is_outline == 0)
	{
		finalColor *= 1+sharpFresnelLight(d);
	}

	finalColor *= c.albedo;

	if (_SpecularType != 0 && i.is_outline == 0)
	{
    	finalColor += calcSpecular(c.specColor, c.smoothness, c.normal, c.oneMinusReflectivity, perceptualRoughness, 
    		viewDir, attenuation, d, l, i);

    // Apply specular lighting to vertex lights. This is cheaper than you might expect.
	#if defined(UNITY_PASS_FORWARDBASE) && defined(VERTEXLIGHT_ON)
    	for (int num = 0; num < 4; num++) {
    		l.color = unity_LightColor[num].rgb;
    		l.dir = normalize(float3(unity_4LightPosX0[num], unity_4LightPosY0[num], unity_4LightPosZ0[num]) - i.posWorld.xyz);
    		d.NdotL = i.vertexLight[num];
			d.halfDir = Unity_SafeNormalize (l.dir + viewDir);
			d.LdotH = saturate(dot(l.dir, d.halfDir));
			d.NdotH = saturate(dot(c.normal, d.halfDir));

    		finalColor += calcSpecular(c.specColor, c.smoothness, c.normal, c.oneMinusReflectivity, perceptualRoughness, 
    		viewDir, i.vertexLight[num], d, l, i);
    	};
	#endif
    };

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