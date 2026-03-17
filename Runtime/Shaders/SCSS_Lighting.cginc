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
    half3 L0;
    half3 L1r;
    half3 L1g;
    half3 L1b;
    // L2 could be added, but is not necessary for cel shading
};

struct SCSS_LightParam
{
	half3 viewDir, halfDir, reflDir, ambDir, NxH;
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
    half occlusion;
    half perceptualRoughness;
    half shadowBorderRange;
    half4 shadowBorderColor;
    half crosstone2ndSeparation;
    half crosstoneToneSeparation;
};

struct SCSS_LightrampData {
    SCSS_TonemapInput tone0;
    half softness; // Selects ramp to use from opposite axis.
    half occlusion;
    half perceptualRoughness;
	half shadowLift;
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


half3 SHEvalLinearL2(half3 n)
{
    return SHEvalLinearL2(half4(n, 1.0));
}

// Helper to convert CompatSHData to SCSS SHdata
SHdata ConvertCompatSH(CompatSHData compatSH)
{
    SHdata sh;
    // sh.L0  = half3(compatSH.SHAr.w, compatSH.SHAg.w, compatSH.SHAb.w);
    sh.L0  = half3(compatSH.SHAr.w, compatSH.SHAg.w, compatSH.SHAb.w) + half3(compatSH.SHBr.z, compatSH.SHBg.z, compatSH.SHBb.z) / 3.0;
    sh.L1r = compatSH.SHAr.xyz;
    sh.L1g = compatSH.SHAg.xyz;
    sh.L1b = compatSH.SHAb.xyz;
    return sh;
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

half SHEvalLinearL0L1_ZH3Hallucinate(half4 sh, half3 normal)
{
    half4 radiance = sh * L0L1IrradianceToRadiance;

    half3 zonalAxis = half3(radiance.w, radiance.y, radiance.z);
    half l1Length = length(zonalAxis);
    zonalAxis /= l1Length;

    half ratio = l1Length / radiance.x;
    half zonalL2Coeff = radiance.x * ratio * (0.08 + 0.6 * ratio); // Curve-fit.

    half fZ = dot(zonalAxis, normal);
    half zhNormal = sqrt(5.0f / (16.0f * UNITY_PI)) * (3.0f * fZ * fZ - 1.0f);

    half result = dot(sh, half4(1, half3(normal.y, normal.z, normal.x)));
    result += 0.25f * zhNormal * zonalL2Coeff;
    return result;
}


half3 SHEvalLinearL0L1_ZH3Hallucinate(half3 normal, half3 L0,
    half3 L1r, half3 L1g, half3 L1b)
{
    half3 shL0 = L0;
    half3 shL1_1 = half3(L1r.y, L1g.y, L1b.y);
    half3 shL1_2 = half3(L1r.z, L1g.z, L1b.z);
    half3 shL1_3 = half3(L1r.x, L1g.x, L1b.x);

    half3 result = 0.0;
    half4 a = half4(shL0.r, shL1_1.r, shL1_2.r, shL1_3.r);
    half4 b = half4(shL0.g, shL1_1.g, shL1_2.g, shL1_3.g);
    half4 c = half4(shL0.b, shL1_1.b, shL1_2.b, shL1_3.b);
    result.r = SHEvalLinearL0L1_ZH3Hallucinate(a, normal);
    result.g = SHEvalLinearL0L1_ZH3Hallucinate(b, normal);
    result.b = SHEvalLinearL0L1_ZH3Hallucinate(c, normal);
    return result;
}

/* http://www.geomerics.com/wp-content/uploads/2015/08/CEDEC_Geomerics_ReconstructingDiffuseLighting1.pdf */
// Optimised version by d4rkpl4y3r
half3 ShadeSH9_Geometrics(half3 n, SHdata sh)
{
    // average energy
    half3 R0 = sh.L0;

    // avg direction of incoming light
    //half3 R1 = 0.5f * L1;
    half3 R1r = sh.L1r;
    half3 R1g = sh.L1g;
    half3 R1b = sh.L1b;

    half3 rlenR1 = { dot(R1r,R1r), dot(R1g, R1g), dot(R1b, R1b) };
    rlenR1 = rsqrt(rlenR1);

    // directional brightness
    half3 lenR1 = rcp(rlenR1) * .5;

    // linear angle between normal and direction 0-1
    half3 q = { dot(R1r, n), dot(R1g, n), dot(R1b, n) };
    q = q * rlenR1 * .5 + .5;
    q = isnan(q) ? 1 : q;

    // power for q
    // lerps from 1 (linear) to 3 (cubic) based on directionality
    half3 p = 1.0f + 2.0f * (lenR1 / R0);

    // dynamic range constant
    // should vary between 4 (highly directional) and 0 (ambient)
    half3 a = (1.0f - (lenR1 / R0)) / (1.0f + (lenR1 / R0));

    return max(0, R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p)));
}

SHdata SampleProbes(float3 worldPos, half3 normal)
{
    SHdata sh;
    CompatSHData compatSH = CGetSHData(worldPos, normal);
    sh = ConvertCompatSH(compatSH);

    #if defined(SCSS_USE_VRC_LIGHT_VOLUMES)
    LightVolumeSH(worldPos, sh.L0, sh.L1r, sh.L1g, sh.L1b);
    #endif

    return sh;
}

half3 SampleIrradiance(half3 normal, SHdata sh, out half3 dominantDir)
{
    half3 nL1x; half3 nL1y; half3 nL1z;
    nL1x = half3(sh.L1r[0], sh.L1g[0], sh.L1b[0]);
    nL1y = half3(sh.L1r[1], sh.L1g[1], sh.L1b[1]);
    nL1z = half3(sh.L1r[2], sh.L1g[2], sh.L1b[2]);
    dominantDir = half3(luminance(nL1x), luminance(nL1y), luminance(nL1z));

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

half3 SampleIrradianceSimple(half3 normal, SHdata sh)
{
    half3 irradiance = 0.0;
    irradiance.r = dot(sh.L1r, normal.xyz) + sh.L0.r;
    irradiance.g = dot(sh.L1g, normal.xyz) + sh.L0.g;
    irradiance.b = dot(sh.L1b, normal.xyz) + sh.L0.b;
    return irradiance;
}

half3 GetSHDirectionL1(SHdata sh)
{
    return normalize((sh.L1r.xyz + sh.L1g.xyz + sh.L1b.xyz) + FLT_EPS);
}

// Returns the value from SH in the lighting direction with the
// brightest intensity.
half3 GetSHMaxL1(SHdata sh)
{
    half4 maxDirection = half4(GetSHDirectionL1(sh), 1.0);
    return SampleIrradianceSimple(maxDirection, sh);
}

half getGreyscaleSH(half3 normal, SHdata sh)
{
    // Samples the SH in the weakest and strongest direction and uses the difference
    // to compress the SH result into 0-1 range.

    // However, for efficiency, we only get the direction from L1.
    half3 ambientLightDirection = GetSHDirectionL1(sh);

    // If this causes issues, it might be worth getting the min() of those two.
    half3 dd = SampleIrradianceSimple(-ambientLightDirection, sh);
    half3 ee = SampleIrradianceSimple(normal, sh);
    half3 aa = SampleIrradianceSimple(ambientLightDirection, sh);

    ee = saturate( (ee - dd) / (aa - dd));
    return abs(dot(ee, sRGB_Luminance));

    return dot(normal, ambientLightDirection);
}


half getGreyscaleSH_Simplified(half3 normal, half3 ambientLightDirection, SHdata sh)
{

    half3 M = half3(
        dot(sh.L1r, ambientLightDirection),
        dot(sh.L1g, ambientLightDirection),
        dot(sh.L1b, ambientLightDirection)
    );

    half3 DEN = 2.0f * M + FLT_EPS;

    half3 X = half3(
        dot(sh.L1r, normal),
        dot(sh.L1g, normal),
        dot(sh.L1b, normal)
    );

    half3 ee_remapped = saturate((X + M) / DEN);

    return dot(ee_remapped, sRGB_Luminance);
}

//-----------------------------------------------------------------------------
// These functions use data or functions not available in the shadow pass
//-----------------------------------------------------------------------------

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

half getAmbientLight (half3 ambientLightDirection, half3 normal, half3 viewDir, SHdata sh, CompatLight mainLight)
{
	if (_IndirectShadingType == 2) // Flatten
	{
		ambientLightDirection = any(mainLight.color)
		? normalize(mainLight.direction)
		: ambientLightDirection;
	}

	if (_IndirectShadingType == 3) // UTS-like
	{
		ambientLightDirection = any(mainLight.color)
		? normalize(mainLight.direction)
		: viewDir;
	}

	half ambientLight = dot(normal, ambientLightDirection);
	ambientLight = ambientLight * 0.5 + 0.5;

    // Todo: Maybe this should be restructured like the other SH functions?
	if (_IndirectShadingType == 0) // Dynamic
		ambientLight = getGreyscaleSH_Simplified(normal, ambientLightDirection, sh);
	return ambientLight;
}

// Helper function for derived lights
SCSS_LightParam recalculateLightParamLight (CompatLight l, SCSS_ShadingParam s, SCSS_LightParam d)
{
	d.halfDir = Unity_SafeNormalize (l.direction + s.view);
	d.NdotL = (dot(l.direction, s.normal)); // Calculate NdotL
	d.LdotH = (dot(l.direction, d.halfDir));
	d.NdotH = (dot(s.normal, d.halfDir)); // Saturate seems to cause artifacts
	d.NxH   = cross(s.normal, d.halfDir);
    return d;
}

SCSS_LightParam initialiseLightParam (CompatLight l, SCSS_ShadingParam s)
{
	SCSS_LightParam d = (SCSS_LightParam) 0;
	d.halfDir = Unity_SafeNormalize (l.direction + s.view);
	d.reflDir = reflect(-s.view, s.normal); // Calculate reflection vector
	d.NdotL = (dot(l.direction, s.normal)); // Calculate NdotL
	d.NdotV = (dot(s.view,  s.normal)); // Calculate NdotV
	d.LdotH = (dot(l.direction, d.halfDir));
	d.NdotH = (dot(s.normal, d.halfDir)); // Saturate seems to cause artifacts
	d.NxH   = cross(s.normal, d.halfDir);
    // No SH data.
	return d;
}

SCSS_LightParam initialiseLightParam(CompatLight l, SCSS_ShadingParam s, SHdata sh)
{
	SCSS_LightParam d = (SCSS_LightParam) 0;
	d.halfDir = Unity_SafeNormalize (l.direction + s.view);
	d.reflDir = reflect(-s.view, s.normal); // Calculate reflection vector
	d.NdotL = (dot(l.direction, s.normal)); // Calculate NdotL
	d.NdotV = (dot(s.view,  s.normal)); // Calculate NdotV
	d.LdotH = (dot(l.direction, d.halfDir));
	d.NdotH = (dot(s.normal, d.halfDir)); // Saturate seems to cause artifacts
	d.NxH   = cross(s.normal, d.halfDir);

    d.sh = sh;
    d.ambDir = GetSHDirectionL1(d.sh);
	d.NdotAmb = getAmbientLight(d.ambDir, s.normal, s.view, d.sh, l);
	return d;
}

void getDirectIndirectLighting(half3 normal, half3 worldPos, SHdata sh,
    out half3 directLighting, out half3 indirectLighting, out half3 dominantDirection)
{
	directLighting    = 0.0;
	indirectLighting  = 0.0;
    dominantDirection = 0.0;

    half3 baseIrradiance = SampleIrradiance(normal, sh, dominantDirection);

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
		half4 ambientDir = half4(Unity_SafeNormalize(sh.L1r.xyz + sh.L1g.xyz + sh.L1b.xyz), 1.0);
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

// Sample ramp with the specified options.
// rampPosition: 0-1 position on the light ramp from light to dark
// softness: 0-1 position on the light ramp on the other axis
half3 sampleRampWithOptions(half rampPosition, half softness)
{
	#if defined(SCSS_CROSSTONE)
	// Shouldn't be used in Crosstone.
	return half3(1.0, 0.0, 1.0);
	#else
    half2 rampUV = half2(rampPosition, softness);
    switch (_LightRampType)
    {
        case 3: // No sampling; smooth NdotL
            return saturate(rampPosition*2-1);
        case 2: // No texture, sharp sampling
            half shadeWidth = 0.0002 * (1+softness*100);
            const half shadeOffset = 0.5;
            half lightContribution = simpleSharpen(rampPosition, shadeWidth, shadeOffset);
            return saturate(lightContribution);
        case 1: // Vertical
            rampUV = half2(softness, rampPosition);
            return _Ramp.Sample(_RampLinearClampSampler, saturate(rampUV));
        default: // Horizontal
            return _Ramp.Sample(_RampLinearClampSampler, saturate(rampUV));
    }
	#endif
}

// This is based on a typical calculation for tonemapping
// scenes to screens, but in this case we want to flatten
// and shift the image colours.
// Lavender's the most aesthetic colour for this.
half3 AutoToneMapping(half3 color)
{
    const half A = 0.7;
    const half3 B = half3(.74, 0.6, .74);
    const half C = 0;
    const half D = 1.59;
    const half E = 0.451;
    color = max((0.0), color - (0.004));
    color = (color * (A * color + B)) / (color * (C * color + D) + E);
    return color;
}

// Maps an index 0-5 to the primary cardinal axes
half3 GetCardinal(uint i)
{
    // Cycle through 0 to 5 to prevent out-of-bounds
    uint index = i % 6;

    // Define the 6 cardinal directions
    static const half3 directions[6] = {
        half3( 1,  0,  0), // 0: +X (Right)
        half3(-1,  0,  0), // 1: -X (Left)
        half3( 0,  1,  0), // 2: +Y (Up)
        half3( 0, -1,  0), // 3: -Y (Down)
        half3( 0,  0,  1), // 4: +Z (Forward)
        half3( 0,  0, -1)  // 5: -Z (Back)
    };

    return directions[index];
}

// Based on lilxyzw's implementation
half getSDFLighting(half3 lightDir, half2 sdfLR, half shadowFlatBlur) {
    // Compute the right face direction in world space
    half3 rightFaceDirection = mul((half3x3)GetObjectToWorldMatrix(), GetCardinal(_SDFRightVector));
    half lightDotRightFace = dot(lightDir.xz, rightFaceDirection.xz);

    // Flip SDF based on the light direction
    half shadingSDF = lightDotRightFace < 0 ? sdfLR[1] : sdfLR[0];
    half hardShadow = saturate(max(sdfLR.x, sdfLR.y)*10);

    // Compute the forward face direction in world space
    half3 forwardFaceDirection = mul((half3x3)GetObjectToWorldMatrix(), GetCardinal(_SDFFrontVector)).xyz;
    forwardFaceDirection.y *= shadowFlatBlur;
    forwardFaceDirection = dot(forwardFaceDirection, forwardFaceDirection) == 0 ? 0 : normalize(forwardFaceDirection);

    // Adjust light direction for shadow flat blur
    half3 lightDirection = lightDir;
    lightDirection.y *= shadowFlatBlur;
    lightDirection = dot(lightDirection, lightDirection) == 0 ? 0 : normalize(lightDirection);

    // Compute the shading based on light and face directions
    half lightFaceDot = dot(lightDirection, forwardFaceDirection);
    //half finalSDF = saturate(lightFaceDot * hardShadow + shadingSDF * 1 );
    half finalSDF = saturate(lightFaceDot * 0.5 + shadingSDF * 0.5 + 0.25);

    return finalSDF;
}

half getSDFLightingMasked(half3 lightDir, half2 sdfLR, half shadowFlatBlur, half baseLight, half lightMask)
{
    half sdfLight = getSDFLighting(lightDir, sdfLR, shadowFlatBlur);
    return lerp(sdfLight, baseLight, lightMask);
}

#endif // SCSS_LIGHTING_INCLUDED
