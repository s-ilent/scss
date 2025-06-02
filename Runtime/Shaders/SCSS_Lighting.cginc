#ifndef SCSS_LIGHTING_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_LIGHTING_INCLUDED

#include "SCSS_Input.cginc"
#include "SCSS_LightVolumes.cginc"

//------------------------------------------------------------------------------
// Image based lighting configuration
//------------------------------------------------------------------------------

// Spherical harmonics sampling algorithm
// Unity's default; basic SH sampling
#define SPHERICAL_HARMONICS_DEFAULT         0
// Geometrics' deringing lightprobe sampling
#define SPHERICAL_HARMONICS_GEOMETRICS      1
// Activision's Quadratic Zonal Harmonics
#define SPHERICAL_HARMONICS_ZH3             2

#define SPHERICAL_HARMONICS SPHERICAL_HARMONICS_GEOMETRICS

// Functions and structs used for the lighting calculation.

struct SHdata
{
    float3 L0;
    float3 L1r;
    float3 L1g;
    float3 L1b;
    // L2 could be added, but is not necessary for cel shading
};

struct SCSS_LightParam
{
	half3 viewDir, halfDir, reflDir, ambDir;
	half NdotL, NdotV, LdotH, NdotH;
	half NdotAmb;
    SHdata sh;
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


float3 SHEvalLinearL2(float3 n)
{
    return SHEvalLinearL2(float4(n, 1.0));
}

/*
// Paper: ZH3: Quadratic Zonal Harmonics, i3D 2024. https://torust.me/ZH3.pdf
// Code based on paper and demo https://www.shadertoy.com/view/Xfj3RK
// https://gist.github.com/pema99/f735ca33d1299abe0e143ee94fc61e73
*/

// L1 radiance = L1 irradiance * PI / Y_1 / AHat_1
// PI / (sqrt(3 / PI) / 2) / ((2 * PI) / 3) = sqrt(3 * PI)
const static float L0IrradianceToRadiance = 2 * sqrt(UNITY_PI);

// L0 radiance = L0 irradiance * PI / Y_0 / AHat_0
// PI / (sqrt(1 / PI) / 2) / PI = 2 * sqrt(PI)
const static float L1IrradianceToRadiance = sqrt(3 * UNITY_PI);

const static float4 L0L1IrradianceToRadiance = float4(L0IrradianceToRadiance, L1IrradianceToRadiance, L1IrradianceToRadiance, L1IrradianceToRadiance);

float SHEvalLinearL0L1_ZH3Hallucinate(float4 sh, float3 normal)
{
    float4 radiance = sh * L0L1IrradianceToRadiance;

    float3 zonalAxis = float3(radiance.w, radiance.y, radiance.z);
    float l1Length = length(zonalAxis);
    zonalAxis /= l1Length;

    float ratio = l1Length / radiance.x;
    float zonalL2Coeff = radiance.x * ratio * (0.08 + 0.6 * ratio); // Curve-fit.

    float fZ = dot(zonalAxis, normal);
    float zhNormal = sqrt(5.0f / (16.0f * UNITY_PI)) * (3.0f * fZ * fZ - 1.0f);

    float result = dot(sh, float4(1, float3(normal.y, normal.z, normal.x)));
    result += 0.25f * zhNormal * zonalL2Coeff;
    return result;
}


float3 SHEvalLinearL0L1_ZH3Hallucinate(float3 normal, float3 L0, 
    float3 L1r, float3 L1g, float3 L1b)
{
    float3 shL0 = L0;
    float3 shL1_1 = float3(L1r.y, L1g.y, L1b.y);
    float3 shL1_2 = float3(L1r.z, L1g.z, L1b.z);
    float3 shL1_3 = float3(L1r.x, L1g.x, L1b.x);

    float3 result = 0.0;
    float4 a = float4(shL0.r, shL1_1.r, shL1_2.r, shL1_3.r);
    float4 b = float4(shL0.g, shL1_1.g, shL1_2.g, shL1_3.g);
    float4 c = float4(shL0.b, shL1_1.b, shL1_2.b, shL1_3.b);
    result.r = SHEvalLinearL0L1_ZH3Hallucinate(a, normal);
    result.g = SHEvalLinearL0L1_ZH3Hallucinate(b, normal);
    result.b = SHEvalLinearL0L1_ZH3Hallucinate(c, normal);
    return result;
}

/* http://www.geomerics.com/wp-content/uploads/2015/08/CEDEC_Geomerics_ReconstructingDiffuseLighting1.pdf */
// Optimised version by d4rkpl4y3r
float3 ShadeSH9_Geometrics(float3 n, SHdata sh)
{
    // average energy
    float3 R0 = sh.L0;

    // avg direction of incoming light
    //float3 R1 = 0.5f * L1;
    float3 R1r = sh.L1r;
    float3 R1g = sh.L1g;
    float3 R1b = sh.L1b;

    float3 rlenR1 = { dot(R1r,R1r), dot(R1g, R1g), dot(R1b, R1b) };
    rlenR1 = rsqrt(rlenR1);

    // directional brightness
    float3 lenR1 = rcp(rlenR1) * .5;

    // linear angle between normal and direction 0-1
    float3 q = { dot(R1r, n), dot(R1g, n), dot(R1b, n) };
    q = q * rlenR1 * .5 + .5;
    q = isnan(q) ? 1 : q;

    // power for q
    // lerps from 1 (linear) to 3 (cubic) based on directionality
    float3 p = 1.0f + 2.0f * (lenR1 / R0);

    // dynamic range constant
    // should vary between 4 (highly directional) and 0 (ambient)
    float3 a = (1.0f - (lenR1 / R0)) / (1.0f + (lenR1 / R0));

    return max(0, R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p)));
}

SHdata SampleProbes(float3 worldPos)
{
    SHdata sh = (SHdata)0;

    #if defined(SCSS_USE_VRC_LIGHT_VOLUMES)
    LightVolumeSH(worldPos, sh.L0, sh.L1r, sh.L1g, sh.L1b);
    #else
    sh.L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) + float3(unity_SHBr.z, unity_SHBg.z, unity_SHBb.z) / 3.0;
    sh.L1r = unity_SHAr.xyz; 
    sh.L1g = unity_SHAg.xyz; 
    sh.L1b = unity_SHAb.xyz;
    #endif

    return sh;
}

float3 SampleIrradiance(float3 normal, SHdata sh, out float3 dominantDir)
{
    float3 nL1x; float3 nL1y; float3 nL1z;
    nL1x = float3(sh.L1r[0], sh.L1g[0], sh.L1b[0]);
    nL1y = float3(sh.L1r[1], sh.L1g[1], sh.L1b[1]);
    nL1z = float3(sh.L1r[2], sh.L1g[2], sh.L1b[2]);
    dominantDir = float3(luminance(nL1x), luminance(nL1y), luminance(nL1z));

    // Compute irradiance using the SH components
    half3 irradiance = 0.0;

    #if (SPHERICAL_HARMONICS == SPHERICAL_HARMONICS_DEFAULT)
        irradiance.r = dot(sh.L1r, normal.xyz) + sh.L0.r;
        irradiance.g = dot(sh.L1g, normal.xyz) + sh.L0.g;
        irradiance.b = dot(sh.L1b, normal.xyz) + sh.L0.b;
    #endif

    #if (SPHERICAL_HARMONICS == SPHERICAL_HARMONICS_GEOMETRICS)
        irradiance   = ShadeSH9_Geometrics(normal.xyz, sh);
    #endif

    #if (SPHERICAL_HARMONICS == SPHERICAL_HARMONICS_ZH3)
        irradiance   = SHEvalLinearL0L1_ZH3Hallucinate(normal.xyz, sh.L0, sh.L1r, sh.L1g, sh.L1b );
    #endif

    return irradiance;
}

float3 SampleIrradianceSimple(float3 normal, SHdata sh)
{
    half3 irradiance = 0.0;
    irradiance.r = dot(sh.L1r, normal.xyz) + sh.L0.r;
    irradiance.g = dot(sh.L1g, normal.xyz) + sh.L0.g;
    irradiance.b = dot(sh.L1b, normal.xyz) + sh.L0.b;
    return irradiance;
}

float3 GetSHDirectionL1(SHdata sh)
{
    return normalize((sh.L1r.xyz + sh.L1g.xyz + sh.L1b.xyz) + FLT_EPS);
}

// Returns the value from SH in the lighting direction with the 
// brightest intensity. 
float3 GetSHMaxL1(SHdata sh)
{
    float4 maxDirection = float4(GetSHDirectionL1(sh), 1.0);
    return SampleIrradianceSimple(maxDirection, sh);
}

float getGreyscaleSH(float3 normal, SHdata sh)
{
    // Samples the SH in the weakest and strongest direction and uses the difference
    // to compress the SH result into 0-1 range.

    // However, for efficiency, we only get the direction from L1.
    float3 ambientLightDirection = GetSHDirectionL1(sh);

    // If this causes issues, it might be worth getting the min() of those two.
    float3 dd = SampleIrradianceSimple(-ambientLightDirection, sh);
    float3 ee = SampleIrradianceSimple(normal, sh);
    float3 aa = SampleIrradianceSimple(ambientLightDirection, sh);

    ee = saturate( (ee - dd) / (aa - dd));
    return abs(dot(ee, sRGB_Luminance));

    return dot(normal, ambientLightDirection);
}


float getGreyscaleSH_Simplified(float3 normal, float3 ambientLightDirection, SHdata sh)
{

    float3 M = float3(
        dot(sh.L1r, ambientLightDirection),
        dot(sh.L1g, ambientLightDirection),
        dot(sh.L1b, ambientLightDirection)
    );

    float3 DEN = 2.0f * M + FLT_EPS;

    float3 X = float3(
        dot(sh.L1r, normal),
        dot(sh.L1g, normal),
        dot(sh.L1b, normal)
    );

    float3 ee_remapped = saturate((X + M) / DEN);

    return dot(ee_remapped, sRGB_Luminance);
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

float getAmbientLight (float3 ambientLightDirection, float3 normal, float3 viewDir, SHdata sh)
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

    // Todo: Maybe this should be restructured like the other SH functions?
	if (_IndirectShadingType == 0) // Dynamic
		ambientLight = getGreyscaleSH_Simplified(normal, ambientLightDirection, sh);
	return ambientLight;
}

// Helper function for derived lights
SCSS_LightParam recalculateLightParamLight (SCSS_Light l, SCSS_ShadingParam s, SCSS_LightParam d)
{
	d.halfDir = Unity_SafeNormalize (l.dir + s.view);
	d.NdotL = (dot(l.dir, s.normal)); // Calculate NdotL
	d.LdotH = (dot(l.dir, d.halfDir));
	d.NdotH = (dot(s.normal, d.halfDir)); // Saturate seems to cause artifacts
    return d;
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

    // Todo: Apply _LightSkew if light probes are used
    d.sh = SampleProbes(s.position);
    d.ambDir = GetSHDirectionL1(d.sh);
	d.NdotAmb = getAmbientLight(d.ambDir, s.normal, s.view, d.sh);
	return d;
}

void getDirectIndirectLighting(float3 normal, float3 worldPos, SHdata sh,
    out float3 directLighting, out float3 indirectLighting, out float3 dominantDirection)
{
	directLighting    = 0.0;
	indirectLighting  = 0.0;
    dominantDirection = 0.0;

    float3 baseIrradiance = SampleIrradiance(normal, sh, dominantDirection);

	#ifdef SCSS_HLSL_COMPAT
	[call] // https://www.gamedev.net/forums/topic/682920-hlsl-switch-attributes/
	#endif
	switch (_LightingCalculationType)
	{
	case 0: // Unbiased
		directLighting   = GetSHMaxL1(sh);
		indirectLighting = sh.L0; 
	break;
	case 1: // Standard
		directLighting = 
		indirectLighting = baseIrradiance;
	break;
	case 2: // Cubed
		directLighting   = SampleIrradianceSimple(half4(0.0,  1.0, 0.0, 1.0), sh);
		indirectLighting = SampleIrradianceSimple(half4(0.0, -1.0, 0.0, 1.0), sh);
	break;
	case 3: // True Directional
		float4 ambientDir = float4(Unity_SafeNormalize(sh.L1r.xyz + sh.L1g.xyz + sh.L1b.xyz), 1.0);
		directLighting   = SampleIrradianceSimple( ambientDir, sh);
		indirectLighting = SampleIrradianceSimple(-ambientDir, sh); 
	break;
	case 4: // Biased
		directLighting   = GetSHMaxL1(sh); 
		indirectLighting = SampleIrradiance(half4(0.0, 0.0, 0.0, 1.0), sh, dominantDirection); 
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