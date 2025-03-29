#ifndef SCSS_LIGHTING_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_LIGHTING_INCLUDED

// Functions and structs used for the lighting calculation.

struct SCSS_LightParam
{
	half3 viewDir, halfDir, reflDir, ambDir;
	half NdotL, NdotV, LdotH, NdotH;
	half NdotAmb;
};

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

struct SCSS_CrosstoneData {
    SCSS_TonemapInput tone0;
    SCSS_TonemapInput tone1;
    float occlusion;
    float perceptualRoughness;
    float shadowBorderRange;
    float4 shadowBorderColor;
    float crosstone2ndSeparation;
    float crosstoneToneSeparation;
};

struct SCSS_LightrampData {
    SCSS_TonemapInput tone0;
    half softness; // Selects ramp to use from opposite axis. 
    float occlusion;
    float perceptualRoughness;
	float shadowLift;
};

SCSS_CrosstoneData initaliseCrosstoneParam(SCSS_Input c)
{
	SCSS_CrosstoneData data = (SCSS_CrosstoneData)0;
	#if defined(SCSS_CROSSTONE)
        data.tone0 = c.tone[0];
        data.tone1 = c.tone[1];
        data.occlusion = c.occlusion;
        data.perceptualRoughness = c.perceptualRoughness;
        data.shadowBorderRange = _ShadowBorderRange;
        data.shadowBorderColor = _ShadowBorderColor;
        data.crosstone2ndSeparation = _Crosstone2ndSeparation;
        data.crosstoneToneSeparation = _CrosstoneToneSeparation;
	#endif
	return data;
};

SCSS_LightrampData initaliseLightrampParam(SCSS_Input c)
{
	SCSS_LightrampData data = (SCSS_LightrampData)0;
	#if !defined(SCSS_CROSSTONE)
        data.tone0 = c.tone[0];
		data.softness = c.softness;
		data.occlusion = c.occlusion;
		data.perceptualRoughness = c.perceptualRoughness;
		data.shadowLift = _ShadowLift;
	#endif
	return data;
};

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

//-----------------------------------------------------------------------------
// These functions use data or functions not available in the shadow pass
//-----------------------------------------------------------------------------

#if defined(UNITY_STANDARD_BRDF_INCLUDED)

struct SCSS_Light
{
    half3 color;
    half3 dir;
    half  intensity; 
};

bool getLightClampActive()
{
	#if !UNITY_HDR_ON && SCSS_CLAMP_IN_NON_HDR
	return true;
	#endif
	#if SCSS_NO_CLAMPING
	return false;
	#endif
	return (_LightClampAnimated == 1.0);
}

SCSS_Light MainLight(float3 worldPos)
{
    SCSS_Light l;

    l.color = _LightColor0.rgb;
    l.dir = Unity_SafeNormalize(UnityWorldSpaceLightDir(worldPos)); 

    // Workaround for scenes with HDR off blowing out in VRchat.
    if (getLightClampActive())
        l.color = saturate(l.color);

	// Minimum light level setting.
	l.color += _LightAddAnimated;

    return l;
}

float3 GetSHDirectionL1()
{
    // For efficiency, we only get the direction from L1.
    // Because getting it from L2 would be too hard!
    return
        normalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) + FLT_EPS);
}

float3 SimpleSH9(float3 normal)
{
    return ShadeSH9(float4(normal, 1));
}

// Get the average (L0) SH contribution
// Biased due to a constant factor added for L2
half3 GetSHAverageFast()
{
    return float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
}


// Get the ambient (L0) SH contribution correctly
// Provided by Dj Lukis.LT - Unity's SH calculation adds a constant
// factor which produces a slight bias in the result.
half3 GetSHAverage ()
{
    return float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w)
     + float3(unity_SHBr.z, unity_SHBg.z, unity_SHBb.z) / 3.0;
}

// Get the maximum SH contribution
// synqark's Arktoon shader's shading method
// This method has some flaws: 
// - Getting the length of the L1 data is a bit wrong
//   because .w contains ambient contribution
// - Getting the length of L2 doesn't correspond with
//   intensity, because it doesn't store direct vectors
half3 GetSHLengthOld ()
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

// Returns the value from SH in the lighting direction with the 
// brightest intensity. 
half3 GetSHMaxL1()
{
    float4 maxDirection = float4(GetSHDirectionL1(), 1.0);
    return SHEvalLinearL0L1(maxDirection) + max(SHEvalLinearL2(maxDirection), 0);
}

float3 SHEvalLinearL2(float3 n)
{
    return SHEvalLinearL2(float4(n, 1.0));
}

float getGreyscaleSH(float3 normal)
{
    // Samples the SH in the weakest and strongest direction and uses the difference
    // to compress the SH result into 0-1 range.

    // However, for efficiency, we only get the direction from L1.
    float3 ambientLightDirection = GetSHDirectionL1();

    // If this causes issues, it might be worth getting the min() of those two.
    //float3 dd = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
    float3 dd = SimpleSH9(-ambientLightDirection);
    float3 ee = SimpleSH9(normal);
    float3 aa = SimpleSH9(ambientLightDirection);

    ee = saturate( (ee - dd) / (aa - dd));
    return abs(dot(ee, sRGB_Luminance));

    return dot(normal, ambientLightDirection);
}

float getAmbientLight (float3 ambientLightDirection, float3 normal, float3 viewDir)
{
	if (_IndirectShadingType == 2) // Flatten
	{
		ambientLightDirection = any(_LightColor0) 
		? normalize(_WorldSpaceLightPos0) 
		: ambientLightDirection;
	}

	if (_IndirectShadingType == 3) // UTS-like
	{
		ambientLightDirection = any(_LightColor0) 
		? normalize(_WorldSpaceLightPos0) 
		: viewDir;
	}

	float ambientLight = dot(normal, ambientLightDirection);
	ambientLight = ambientLight * 0.5 + 0.5;

	if (_IndirectShadingType == 0) // Dynamic
		ambientLight = getGreyscaleSH(normal);
	return ambientLight;
}

SCSS_LightParam initialiseLightParam (SCSS_Light l, SCSS_ShadingParam s)
{
	SCSS_LightParam d = (SCSS_LightParam) 0;
	d.halfDir = Unity_SafeNormalize (l.dir + s.view);
	d.reflDir = reflect(-s.view, s.normal); // Calculate reflection vector
	d.NdotL = (dot(l.dir, s.normal)); // Calculate NdotL
	d.NdotV = (dot(s.view,  s.normal)); // Calculate NdotV
	d.LdotH = (dot(l.dir, d.halfDir));
	d.NdotH = (dot(s.normal, d.halfDir)); // Saturate seems to cause artifacts
    d.ambDir = Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz) * _LightSkew.xyz);
	d.NdotAmb = getAmbientLight(d.ambDir, s.normal, s.view);
	return d;
}

void getDirectIndirectLighting(float3 normal, out float3 directLighting, out float3 indirectLighting)
{
	directLighting   = 0.0;
	indirectLighting = 0.0;

	#ifdef SCSS_HLSL_COMPAT
	[call] // https://www.gamedev.net/forums/topic/682920-hlsl-switch-attributes/
	#endif
	switch (_LightingCalculationType)
	{
	case 0: // Unbiased
		directLighting   = GetSHMaxL1();
		indirectLighting = GetSHAverage(); 
	break;
	case 1: // Standard
		directLighting = 
		indirectLighting = BetterSH9(half4(normal, 1.0));
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
	case 4: // Biased
		directLighting   = GetSHMaxL1();
		indirectLighting = BetterSH9(half4(0.0, 0.0, 0.0, 1.0)); 
	break;
	}

	directLighting   += FLT_EPS;
	indirectLighting += FLT_EPS;

    // Workaround for scenes with HDR off blowing out in VRchat.
    if (getLightClampActive())
    {
        directLighting = saturate(directLighting);
        indirectLighting = saturate(indirectLighting);
    }
}
#endif // if UNITY_STANDARD_BRDF_INCLUDED

// Sample ramp with the specified options.
// rampPosition: 0-1 position on the light ramp from light to dark
// softness: 0-1 position on the light ramp on the other axis
float3 sampleRampWithOptions(float rampPosition, half softness) 
{
	#if defined(SCSS_CROSSTONE)
	// Shouldn't be used in Crosstone.
	return float3(1.0, 0.0, 1.0);
	#else
    float2 rampUV = float2(rampPosition, softness);
    switch (_LightRampType)
    {
        case 3: // No sampling; smooth NdotL
            return saturate(rampPosition*2-1);
        case 2: // No texture, sharp sampling
            float shadeWidth = 0.0002 * (1+softness*100);
            const float shadeOffset = 0.5; 
            float lightContribution = simpleSharpen(rampPosition, shadeWidth, shadeOffset);
            return saturate(lightContribution);
        case 1: // Vertical
            rampUV = float2(softness, rampPosition);
            return tex2D(_Ramp, saturate(rampUV));
        default: // Horizontal
            return tex2D(_Ramp, saturate(rampUV));
    }
	#endif
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


// Based on lilxyzw's implementation
float getSDFLighting(float3 lightDir, float2 sdfLR, float shadowFlatBlur) {
    // Compute the right face direction in world space
    float3 rightFaceDirection = mul((float3x3)unity_ObjectToWorld, float3(-1.0, 0.0, 0.0));
    float lightDotRightFace = dot(lightDir.xz, rightFaceDirection.xz);

    // Flip SDF based on the light direction
    float shadingSDF = lightDotRightFace < 0 ? sdfLR[1] : sdfLR[0];
    float hardShadow = saturate(max(sdfLR.x, sdfLR.y)*10);

    // Compute the forward face direction in world space
    float3 forwardFaceDirection = mul((float3x3)unity_ObjectToWorld, float3(0.0, 0.0, 1.0)).xyz;
    forwardFaceDirection.y *= shadowFlatBlur;
    forwardFaceDirection = dot(forwardFaceDirection, forwardFaceDirection) == 0 ? 0 : normalize(forwardFaceDirection);

    // Adjust light direction for shadow flat blur
    float3 lightDirection = lightDir;
    lightDirection.y *= shadowFlatBlur;
    lightDirection = dot(lightDirection, lightDirection) == 0 ? 0 : normalize(lightDirection);

    // Compute the shading based on light and face directions
    float lightFaceDot = dot(lightDirection, forwardFaceDirection);
    //float finalSDF = saturate(lightFaceDot * hardShadow + shadingSDF * 1 );
    float finalSDF = saturate(lightFaceDot * 0.5 + shadingSDF * 0.5 + 0.25);

    return finalSDF;
}


#endif // SCSS_LIGHTING_INCLUDED