#ifndef SCSS_UTILS_INCLUDED
#define SCSS_UTILS_INCLUDED

#ifndef USING_DIRECTIONAL_LIGHT
    #if defined (DIRECTIONAL_COOKIE) || defined (DIRECTIONAL)
        #define USING_DIRECTIONAL_LIGHT
    #endif
#endif

#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE) || (defined (UNITY_LIGHT_PROBE_PROXY_VOLUME) && UNITY_VERSION<600)
    #define USING_SHADOWS_UNITY
#endif

sampler2D_float _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;

#define sRGB_Luminance float3(0.2126, 0.7152, 0.0722)

float interleaved_gradient(float2 uv : SV_POSITION) : SV_Target
{
	float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
	return frac(magic.z * frac(dot(uv, magic.xy)));
}

float Dither17(float2 Pos, float FrameIndexMod4)
{
    // 3 scalar float ALU (1 mul, 2 mad, 1 frac)
    return frac(dot(float3(Pos.xy, FrameIndexMod4), uint3(2, 7, 23) / 17.0f));
}

float max3 (float3 x) 
{
	return max(x.x, max(x.y, x.z));
}

// "R2" dithering

// Triangle Wave
float T(float z) {
    return z >= 0.5 ? 2.-2.*z : 2.*z;
}

// R dither mask
float intensity(float2 pixel) {
    const float a1 = 0.75487766624669276;
    const float a2 = 0.569840290998;
    return frac(a1 * float(pixel.x) + a2 * float(pixel.y));
}

float rDither(float gray, float2 pos) {
	#define steps 4
	// pos is screen pixel position in 0-res range
    // Calculated noised gray value
    float noised = (2./steps) * T(intensity(float2(pos.xy))) + gray - (1./steps); 
    // Clamp to the number of gray levels we want
    return floor(steps * noised) / (steps-1.);
    #undef steps
}

// "R2" dithering -- end

inline void applyAlphaClip(inout float alpha, float cutoff, float2 pos, bool sharpen)
{
    // Get the amount of MSAA samples present
    #if (SHADER_TARGET > 40)
    half samplecount = GetRenderTargetSampleCount();
    #else
    half samplecount = 1;
    #endif

    pos += _SinTime.x%4;
    #if defined(_ALPHATEST_ON)
    // Switch between dithered alpha and sharp-edge alpha.
        if (!sharpen) {
            alpha = (1+cutoff) * alpha - cutoff;
            float mask = (T(intensity(pos)));
            const float width = 1 / (samplecount*2-1);
            alpha = alpha - (mask * (1-(alpha)) * width);
        }
        else {
            alpha = ((alpha - cutoff) / max(fwidth(alpha), 0.0001) + 0.5);
        }
    // If 0, remove now.
    clip (alpha);
    #endif
}

inline float3 BlendNormalsPD(float3 n1, float3 n2) {
	return normalize(float3(n1.xy*n2.z + n2.xy*n1.z, n1.z*n2.z));
}

float2 invlerp(float2 A, float2 B, float2 T){
    return (T - A)/(B - A);
}

// Stylish lighting helpers

float smooth_floor(float x, float c) {
    float a = frac(x);
    float b = floor(x);
    return ((pow(a,c)-pow(1.-a,c))/2.)+b;
}

float smooth_ceil(float x, float c) {
    float a = frac(x);
    float b = ceil(x);
    return ((pow(a,c)-pow(1.-a,c))/2.)+b;
}

float lerpstep( float a, float b, float t)
{
    return saturate( ( t - a ) / ( b - a ) );
}

float smootherstep(float a, float b, float t) 
{
    t = saturate( ( t - a ) / ( b - a ) );
    return t * t * t * (t * (t * 6. - 15.) + 10.);
}

float sharpenLighting (float inLight, float softness)
{
    float2 lightStep = 0.5 + float2(-1, 1) * fwidth(inLight);
    lightStep = lerp(float2(0.0, 1.0), lightStep, 1-softness);
    inLight = smoothstep(lightStep.x, lightStep.y, inLight);
    return inLight;
}

float remapCubic(float x)
{
    return x = x * x * x * (x * (6 * x - 15) + 10);
}

// By default, use smootherstep because it has the best visual appearance.
// But some functions might work better with lerpstep.
float simpleSharpen (float x, float width, float mid, const float smoothnessMode = 2)
{
    float2 dx = float2(ddx(x), ddy(x));
    float rf = (dot(dx, dx)*2);
    width = max(width, rf);

    [flatten]
    switch (smoothnessMode)
    {
        case 0: x = lerpstep(mid-width, mid, x); break;
        case 1: x = smoothstep(mid-width, mid, x); break;
        case 2: x = smootherstep(mid-width, mid, x); break;
    }

    return x;
}

// Returns pixel sharpened to nearest pixel boundary. 
// texelSize is Unity _Texture_TexelSize; zw is w/h, xy is 1/wh
float2 sharpSample( float4 texelSize , float2 p )
{
	p = p*texelSize.zw;
    float2 c = max(0.0001, fwidth(p));
    p = floor(p) + saturate(frac(p) / c);
	p = (p - 0.5)*texelSize.xy;
	return p;
}

bool inMirror()
{
	return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
}

// Only needed in Unity versions before Unity 2017.4.28 or so.
// However, 2017.4.15 is a higher UNITY_VERSION.
bool backfaceInMirror()
{
	#if ( (UNITY_VERSION <= 201711) || (UNITY_VERSION == 201755) )
	return inMirror();
	#else
	return false;
	#endif
}

#if defined(UNITY_STANDARD_BRDF_INCLUDED)

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

    // Workaround for scenes with HDR off blowing out in VRchat.
    #if !UNITY_HDR_ON && SCSS_CLAMP_IN_NON_HDR
        l.color = saturate(l.color);
    #endif

    return l;
}

SCSS_Light MainLight(float3 worldPos)
{
    SCSS_Light l = MainLight();
    l.dir = Unity_SafeNormalize(UnityWorldSpaceLightDir(worldPos)); 
    return l;
}

//-----------------------------------------------------------------------------
// Helper functions for roughness
//-----------------------------------------------------------------------------

float RoughnessToPerceptualRoughness(float roughness)
{
    return sqrt(roughness);
}

float RoughnessToPerceptualSmoothness(float roughness)
{
    return 1.0 - sqrt(roughness);
}

float PerceptualSmoothnessToRoughness(float perceptualSmoothness)
{
    return (1.0 - perceptualSmoothness) * (1.0 - perceptualSmoothness);
}

float PerceptualSmoothnessToPerceptualRoughness(float perceptualSmoothness)
{
    return (1.0 - perceptualSmoothness);
}

float PerceptualRoughnessToPerceptualSmoothness(float perceptualRoughness)
{
    return (1.0 - perceptualRoughness);
}

// Return modified perceptualSmoothness based on provided variance (get from GeometricNormalVariance + TextureNormalVariance)
float NormalFiltering(float perceptualSmoothness, float variance, float threshold)
{
    float roughness = PerceptualSmoothnessToRoughness(perceptualSmoothness);
    // Ref: Geometry into Shading - http://graphics.pixar.com/library/BumpRoughness/paper.pdf - equation (3)
    float squaredRoughness = saturate(roughness * roughness + min(2.0 * variance, threshold * threshold)); // threshold can be really low, square the value for easier control

    return RoughnessToPerceptualSmoothness(sqrt(squaredRoughness));
}

// Reference: Error Reduction and Simplification for Shading Anti-Aliasing
// Specular antialiasing for geometry-induced normal (and NDF) variations: Tokuyoshi / Kaplanyan et al.'s method.
// This is the deferred approximation, which works reasonably well so we keep it for forward too for now.
// screenSpaceVariance should be at most 0.5^2 = 0.25, as that corresponds to considering
// a gaussian pixel reconstruction kernel with a standard deviation of 0.5 of a pixel, thus 2 sigma covering the whole pixel.
float GeometricNormalVariance(float3 geometricNormalWS, float screenSpaceVariance)
{
    float3 deltaU = ddx(geometricNormalWS);
    float3 deltaV = ddy(geometricNormalWS);

    return screenSpaceVariance * (dot(deltaU, deltaU) + dot(deltaV, deltaV));
}

// Return modified perceptualSmoothness
float GeometricNormalFiltering(float perceptualSmoothness, float3 geometricNormalWS, float screenSpaceVariance, float threshold)
{
    float variance = GeometricNormalVariance(geometricNormalWS, screenSpaceVariance);
    return NormalFiltering(perceptualSmoothness, variance, threshold);
}

// bgolus's method for "fixing" screen space directional shadows and anti-aliasing
// https://forum.unity.com/threads/fixing-screen-space-directional-shadows-and-anti-aliasing.379902/
// Searches the depth buffer for the depth closest to the current fragment to sample the shadow from.
// This reduces the visible aliasing. 

void correctedScreenShadowsForMSAA(float4 _ShadowCoord, inout float shadow)
{
    #ifdef SHADOWS_SCREEN

    float2 screenUV = _ShadowCoord.xy / _ShadowCoord.w;
    shadow = tex2D(_ShadowMapTexture, screenUV).r;

    float fragDepth = _ShadowCoord.z / _ShadowCoord.w;
    float depth_raw = tex2D(_CameraDepthTexture, screenUV).r;

    float depthDiff = abs(fragDepth - depth_raw);
    float diffTest = 1.0 / 100000.0;

    if (depthDiff > diffTest)
    {
        float2 texelSize = _CameraDepthTexture_TexelSize.xy;
        float4 offsetDepths = 0;

        float2 uvOffsets[5] = {
            float2(1.0, 0.0) * texelSize,
            float2(-1.0, 0.0) * texelSize,
            float2(0.0, 1.0) * texelSize,
            float2(0.0, -1.0) * texelSize,
            float2(0.0, 0.0)
        };

        offsetDepths.x = tex2D(_CameraDepthTexture, screenUV + uvOffsets[0]).r;
        offsetDepths.y = tex2D(_CameraDepthTexture, screenUV + uvOffsets[1]).r;
        offsetDepths.z = tex2D(_CameraDepthTexture, screenUV + uvOffsets[2]).r;
        offsetDepths.w = tex2D(_CameraDepthTexture, screenUV + uvOffsets[3]).r;

        float4 offsetDiffs = abs(fragDepth - offsetDepths);

        float diffs[4] = {offsetDiffs.x, offsetDiffs.y, offsetDiffs.z, offsetDiffs.w};

        int lowest = 4;
        float tempDiff = depthDiff;
        for (int i=0; i<4; i++)
        {
            if(diffs[i] < tempDiff)
            {
                tempDiff = diffs[i];
                lowest = i;
            }
        }

        shadow = tex2D(_ShadowMapTexture, screenUV + uvOffsets[lowest]).r;
    }
    #endif //SHADOWS_SCREEN
}

// RCP SQRT
// Source: https://github.com/michaldrobot/ShaderFastLibs/blob/master/ShaderFastMathLib.h

#define IEEE_INT_RCP_SQRT_CONST_NR0         0x5f3759df
#define IEEE_INT_RCP_SQRT_CONST_NR1         0x5F375A86 
#define IEEE_INT_RCP_SQRT_CONST_NR2         0x5F375A86  

// Approximate guess using integer float arithmetics based on IEEE floating point standard
float rcpSqrtIEEEIntApproximation(float inX, const int inRcpSqrtConst)
{
	int x = asint(inX);
	x = inRcpSqrtConst - (x >> 1);
	return asfloat(x);
}

float rcpSqrtNewtonRaphson(float inXHalf, float inRcpX)
{
	return inRcpX * (-inXHalf * (inRcpX * inRcpX) + 1.5f);
}

//
// Using 0 Newton Raphson iterations
// Relative error : ~3.4% over full
// Precise format : ~small float
// 2 ALU
//
float fastRcpSqrtNR0(float inX)
{
	float  xRcpSqrt = rcpSqrtIEEEIntApproximation(inX, IEEE_INT_RCP_SQRT_CONST_NR0);
	return xRcpSqrt;
}

//
// Using 1 Newton Raphson iterations
// Relative error : ~0.2% over full
// Precise format : ~half float
// 6 ALU
//
float fastRcpSqrtNR1(float inX)
{
	float  xhalf = 0.5f * inX;
	float  xRcpSqrt = rcpSqrtIEEEIntApproximation(inX, IEEE_INT_RCP_SQRT_CONST_NR1);
	xRcpSqrt = rcpSqrtNewtonRaphson(xhalf, xRcpSqrt);
	return xRcpSqrt;
}

//
// Using 2 Newton Raphson iterations
// Relative error : ~4.6e-004%  over full
// Precise format : ~full float
// 9 ALU
//
float fastRcpSqrtNR2(float inX)
{
	float  xhalf = 0.5f * inX;
	float  xRcpSqrt = rcpSqrtIEEEIntApproximation(inX, IEEE_INT_RCP_SQRT_CONST_NR2);
	xRcpSqrt = rcpSqrtNewtonRaphson(xhalf, xRcpSqrt);
	xRcpSqrt = rcpSqrtNewtonRaphson(xhalf, xRcpSqrt);
	return xRcpSqrt;
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
    w2 = max(0.001, w2);
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

float StrandSpecular(float3 T, float3 H, float exponent, float strength)
{
	//float3 H = normalize(L+V);
	float dotTH = dot(T, H);
	float sinTH = sqrt(1.0-dotTH*dotTH);
	float dirAtten = smoothstep(-1.0, 0.0, dotTH);
	return dirAtten * pow(sinTH, exponent) * strength;
}

float3 SimpleSH9(float3 normal)
{
    return ShadeSH9(float4(normal, 1));
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

// Get the average (L0) SH contribution
half3 GetSHAverage ()
{
    return float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
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
    float3 ambientLightDirection = 
        Unity_SafeNormalize((unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz));

    // If this causes issues, it might be worth getting the min() of those two.
    //float3 dd = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
    float3 dd = SimpleSH9(-ambientLightDirection);
    float3 ee = SimpleSH9(normal);
    float3 aa = GetSHLength(); // SHa and SHb

    ee = saturate( (ee - dd) / (aa - dd));
    return abs(dot(ee, sRGB_Luminance));

    return dot(normal, ambientLightDirection);
}

half2 getMatcapUVs(float3 normal, float3 viewDir)
{
    // Based on Masataka SUMI's implementation
    half3 worldUp = float3(0, 1, 0);
    half3 worldViewUp = normalize(worldUp - viewDir * dot(viewDir, worldUp));
    half3 worldViewRight = normalize(cross(viewDir, worldViewUp));
    return half2(dot(worldViewRight, normal), dot(worldViewUp, normal)) * 0.5 + 0.5;
}

half2 getMatcapUVsOriented(float3 normal, float3 viewDir, float3 upDir)
{
    // Based on Masataka SUMI's implementation
    half3 worldViewUp = normalize(upDir - viewDir * dot(viewDir, upDir));
    half3 worldViewRight = normalize(cross(viewDir, worldViewUp));
    return half2(dot(worldViewRight, normal), dot(worldViewUp, normal)) * 0.5 + 0.5;
}

// Used for matcaps
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

float3 applyMatcap(sampler2D src, half2 matcapUV, float3 dst, float3 tint, int blendMode, float blendStrength)
{
    return applyBlendMode(blendMode, dst, tex2D(src, matcapUV) * tint, blendStrength);
}

#endif // if UNITY_STANDARD_BRDF_INCLUDED

#endif // SCSS_UTILS_INCLUDED