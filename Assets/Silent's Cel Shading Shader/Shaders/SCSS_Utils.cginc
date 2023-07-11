#ifndef SCSS_UTILS_INCLUDED
#define SCSS_UTILS_INCLUDED

#ifndef USING_DIRECTIONAL_LIGHT
    #if defined (DIRECTIONAL_COOKIE) || defined (DIRECTIONAL)
        #define USING_DIRECTIONAL_LIGHT
    #endif
#endif

#if defined (SHADOWS_SHADOWMASK) || defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE) || (defined (UNITY_LIGHT_PROBE_PROXY_VOLUME) && UNITY_VERSION<600)
    #define USING_SHADOWS_UNITY
#endif

#if defined (_ALPHATEST_ON) || defined (_ALPHABLEND_ON) || defined (_ALPHAPREMULTIPLY_ON)
    #define USING_TRANSPARENCY
#endif

#if defined (_ALPHABLEND_ON) || defined (_ALPHAPREMULTIPLY_ON)
    #define USING_ALPHA_BLENDING
#endif

#if defined (SCSS_COVERAGE_OUTPUT) && defined (_ALPHATEST_ON) && !defined(SHADER_API_GLES3)
    #define USING_COVERAGE_OUTPUT
#endif

#ifndef UNITY_POSITION
    #define UNITY_POSITION(pos) float4 pos : SV_POSITION
#endif

sampler2D_float _CameraDepthTexture;
float4 _CameraDepthTexture_TexelSize;

#define sRGB_Luminance float3(0.2126, 0.7152, 0.0722)

// Epsilon value for floating point numbers that we can't allow to reach 0
#define FLT_EPS 1e-5

bool inMirror()
{
    return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
}

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
float getR2(float2 pixel) {
    const float phi2 = pow((9. + sqrt(69.)) / 18., 1./3.) + pow((9. - sqrt(69.)) / 18., 1./3.); 
    const float C1 = 1. - 1. / phi2;
    const float C2 = 1. - 1. / (phi2 * phi2);
    return frac(C1 * float(pixel.x) + C2 * float(pixel.y));
}

float2 getR2_2(float2 pixel) {
    const float phi2 = pow((9. + sqrt(69.)) / 18., 1./3.) + pow((9. - sqrt(69.)) / 18., 1./3.); 
    const float C1 = 1. - 1. / phi2;
    const float C2 = 1. - 1. / (phi2 * phi2);
    return float2(frac(C1 * float(pixel.x)), frac(C2 * float(pixel.y)));
}

float4 getR2_RGBA(float2 pixel) {
    float h1 = getR2(pixel);
    float h2 = getR2(pixel+53);
    float h3 = getR2(pixel+49);
    float h4 = getR2(pixel+77);
    return float4(h1, h2, h3, h4);
}

float r2Dither(float gray, float2 pos, float steps) {
	// pos is screen pixel position in 0-res range
    // Calculated noised gray value
    float noised = (2./steps) * T(getR2(float2(pos.xy))) + gray - (1./steps); 
    // Clamp to the number of gray levels we want
    return floor(steps * noised) / (steps-1.);
}

// "R2" dithering -- end

// Bicubic weights
float4 cubic_weights(float v)
{
    float4 n = float4(1.0, 2.0, 3.0, 4.0) - v;
    float4 s = n * n * n;
    float4 o;
    o.x = s.x;
    o.y = s.y - 4.0 * s.x;
    o.z = s.z - 4.0 * s.y + 6.0 * s.x;
    o.w = 6.0 - o.x - o.y - o.z;
    return o;
}

#define ALPHA_SHOULD_DITHER_CLIP (defined(_ALPHATEST_ON) || defined(UNITY_PASS_SHADOWCASTER))

inline void applyAlphaSharpen(inout float alpha, float cutoff)
{
    // Use an epsilon above the normal float epsilon. 
    alpha = ((alpha - cutoff) / max(fwidth(alpha), 1e-3) + 0.5);
}

inline void applyAlphaCutoff(inout float alpha, float cutoff)
{
    //alpha = (alpha - (cutoff-FLT_EPS)) / (1.0 - cutoff);
    float epsilon = max(abs(fwidth(alpha)), 1e-3);
    //alpha = smoothstep(cutoff - epsilon, cutoff + epsilon, alpha);
    float t = smoothstep(0.0, cutoff, alpha);
    alpha = lerp(0.0, alpha, t);
}

inline void applyAlphaClip(inout float alpha, float cutoff, float2 pos, bool sharpen, bool forceDither)
{
    // If this material isn't transparent, do nothing.
    #if !defined(USING_TRANSPARENCY)
        alpha = 1.0;
        return;
    #endif

    #if defined(USING_ALPHA_BLENDING)
    static bool isBlending = true;
    #else
    static bool isBlending = false;
    #endif

    // Get the amount of MSAA samples present
    #if (SHADER_TARGET > 40)
    half samplecount = GetRenderTargetSampleCount();
    #else
    half samplecount = 1; 
    #endif

    float modAlpha = alpha;

    // Apply dithered alpha. 
    if (sharpen) 
    {
        applyAlphaSharpen(modAlpha, cutoff);
    } 
    else
    {
        applyAlphaCutoff(modAlpha, cutoff);

        // The width of the dither changes how obvious it is,
        // so it might be useful as a user-adjustable value.
        // However, the visible width of the dither changes
        // based on the brightness of the scene/material..

        if (!isBlending || forceDither)
        {
            // Previously, this was passed through the T function to remap it
            // into a triangular distribution, but in practise this seems to 
            // produce worse results. 
            pos += _SinTime.x%4;
            float mask = (getR2(pos));
            modAlpha = modAlpha + mask / samplecount;
            modAlpha = floor(modAlpha * samplecount) / samplecount;
        }
    }

    // If 0, remove now.
    clip (modAlpha > FLT_EPS? modAlpha : -1);

    alpha = saturate(modAlpha); 
}

inline half3 PreMultiplyAlpha_local (half3 diffColor, half alpha, half oneMinusReflectivity, out half outModifiedAlpha)
{
    #if defined(_ALPHAPREMULTIPLY_ON)
        // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)

        // Transparency 'removes' from Diffuse component
        diffColor *= alpha;

        // Reflectivity 'removes' from the rest of components, including Transparency
        // outAlpha = 1-(1-alpha)*(1-reflectivity) = 1-(oneMinusReflectivity - alpha*oneMinusReflectivity) =
        //          = 1-oneMinusReflectivity + alpha*oneMinusReflectivity
        outModifiedAlpha = 1-oneMinusReflectivity + alpha*oneMinusReflectivity;
    #else
        outModifiedAlpha = alpha;
    #endif
    return diffColor;
}

half LerpOneTo_local(half b, half t)
{
    half oneMinusT = 1 - t;
    return oneMinusT + b * t;
}

half3 LerpWhiteTo_local(half3 b, half t)
{
    half oneMinusT = 1 - t;
    return half3(oneMinusT, oneMinusT, oneMinusT) + b * t;
}

half SpecularStrength_local(half3 specular)
{
    #if (SHADER_TARGET < 30)
        // SM2.0: instruction count limitation
        // SM2.0: simplified SpecularStrength
        return specular.r; // Red channel - because most metals are either monocrhome or with redish/yellowish tint
    #else
        return max (max (specular.r, specular.g), specular.b);
    #endif
}

inline half OneMinusReflectivityFromMetallic_local(half metallic)
{
    // We'll need oneMinusReflectivity, so
    //   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
    // store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
    //   1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) =
    //                  = alpha - metallic * alpha
    half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
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
    // Impossible if this is in the vert/geom shader, so just do nothing.
    #if defined(SHADER_STAGE_FRAGMENT)
    p = p*texelSize.zw;
    float2 c = max(0.0, abs(fwidth(p)));
    p = p + c;
    p = floor(p) + saturate(frac(p) / c);
    p = (p - 0.5)*texelSize.xy;
    #endif
	return p;
}

// Colour transform helper functions
// Source: https://beesbuzz.biz/code/16-hsv-color-transforms

float3 TransformHSV(float3 col, float h, float s, float v)
{
    float vsu,vsw;
    sincos(h*UNITY_PI/180, vsw, vsu);
    vsu *= v*s;
    vsw *= v*s;
    float3 ret;
    ret.r = (.299*v + .701*vsu + .168*vsw)*col.r
        +   (.587*v - .587*vsu + .330*vsw)*col.g
        +   (.114*v - .114*vsu - .497*vsw)*col.b;
    ret.g = (.299*v - .299*vsu - .328*vsw)*col.r
        +   (.587*v + .413*vsu + .035*vsw)*col.g
        +   (.114*v - .114*vsu + .292*vsw)*col.b;
    ret.b = (.299*v - .300*vsu + 1.25*vsw)*col.r
        +   (.587*v - .588*vsu - 1.05*vsw)*col.g
        +   (.114*v + .886*vsu - .203*vsw)*col.b;
    return ret;
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

inline float4 ApplyNearVertexSquishing(float4 posCS)
{
    #if SCSS_NEAR_SQUISH
    // Compress meshes when they're close to the camera.
    // https://qiita.com/lilxyzw/items/3684d8f252ab1894773a#
    #if defined(UNITY_REVERSED_Z)
    // DirectX
        if(posCS.w < _ProjectionParams.y * 1.01 && posCS.w > 0) posCS.z = posCS.z * 0.0001 + posCS.w * 0.999;
    #else
    // OpenGL
        if(posCS.w < _ProjectionParams.y * 1.01 && posCS.w > 0) posCS.z = posCS.z * 0.0001 - posCS.w * 0.999;
    #endif
    #endif

    return posCS;
}

// MToon's implementation
inline half3 getObjectToViewNormal(const half3 normalOS)
{
    return normalize(mul((half3x3)UNITY_MATRIX_IT_MV, normalOS));
}

// Source: https://qiita.com/Santarh/items/428d2e0f33852e6f37b5
static float getScreenAspectRatio()
{
    // Take the position of the top-right vertice of the near plane in projection space,
    // and convert it back to view space.

    // Upper right corner, so (x, y) = (1, 1)
    // Since we want the near plane, z is dependant on API (0: DirectX, -1: OpenGL)
    // And w is the near clip plane itself. 
    float4 projectionSpaceUpperRight = float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y);

    // Apply the inverse projection matrix...
    float4 viewSpaceUpperRight = mul(unity_CameraInvProjection, projectionSpaceUpperRight);

    // ...and the aspect ratio is width / height. 
    return viewSpaceUpperRight.x / viewSpaceUpperRight.y;
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

#define MIN_N_DOT_V 1e-4

float clampNoV(float NoV) {
    // Neubelt and Pettineo 2013, "Crafting a Next-gen Material Pipeline for The Order: 1886"
    return max(NoV, MIN_N_DOT_V);
}

//-----------------------------------------------------------------------------
// These functions rely on data or functions not available in the shadow pass
//-----------------------------------------------------------------------------

#if defined(UNITY_STANDARD_BRDF_INCLUDED)

float IsotropicNDFFiltering(float3 normal, float roughness2) {
    // Tokuyoshi and Kaplanyan 2021, "Stable Geometric Specular Antialiasing with
    // Projected-Space NDF Filtering"
    float SIGMA2 = 0.15915494;
    float KAPPA = 0.18;
    float3 dndu = ddx(normal);
    float3 dndv = ddy(normal);
    float kernelRoughness2 = 2.0 * SIGMA2 * (dot(dndu, dndu) + dot(dndv, dndv));
    float clampedKernelRoughness2 = min(kernelRoughness2, KAPPA);
    float filteredRoughness2 = saturate(roughness2 + clampedKernelRoughness2);
    return filteredRoughness2;
}

// bgolus's method for "fixing" screen space directional shadows and anti-aliasing
// https://forum.unity.com/threads/fixing-screen-space-directional-shadows-and-anti-aliasing.379902/
// Searches the depth buffer for the depth closest to the current fragment to sample the shadow from.
// This reduces the visible aliasing. 

void correctedScreenShadowsForMSAA(float4 _ShadowCoord, inout float shadow)
{
    #ifdef SHADOWS_SCREEN
    #ifdef SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED

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
    #endif //SHADOWMAPSAMPLER_AND_TEXELSIZE_DEFINED
    #endif //SHADOWS_SCREEN
}

//------------------------------------------------------------------------------
// Screen-space Contact Shadows
// Based on Filament - https://github.com/google/filament
//------------------------------------------------------------------------------

struct ScreenSpaceRay {
    float3 ssRayStart;
    float3 ssRayEnd;
    float3 ssViewRayEnd;
    float3 uvRayStart;
    float3 uvRay;
};

float2 uvToRenderTargetUV(float2 uv) {
    #if UNITY_UV_STARTS_AT_TOP
    return float2(uv.x, 1.0 - uv.y);
    #else
    return uv;
    #endif

}

void initScreenSpaceRay(out ScreenSpaceRay ray, float3 wsRayStart, float3 wsRayDirection, float wsRayLength) {
    float4x4 worldToClip = UNITY_MATRIX_VP;
    float4x4 viewToClip = UNITY_MATRIX_P;

    // ray end in world space
    float3 wsRayEnd = wsRayStart + wsRayDirection * wsRayLength;

    // ray start/end in clip space (z is inverted: [1,0])
    float4 csRayStart = mul(worldToClip, float4(wsRayStart, 1.0));
    float4 csRayEnd = mul(worldToClip, float4(wsRayEnd, 1.0));
    float4 csViewRayEnd = csRayStart + mul(viewToClip, float4(0.0, 0.0, wsRayLength, 0.0));

    // ray start/end in screen space (z is inverted: [1,0])
    ray.ssRayStart = csRayStart.xyz * (1.0 / csRayStart.w);
    ray.ssRayEnd = csRayEnd.xyz * (1.0 / csRayEnd.w);
    ray.ssViewRayEnd = csViewRayEnd.xyz * (1.0 / csViewRayEnd.w);

    // convert all to uv (texture) space (z is inverted: [1,0])
    float3 uvRayEnd = float3(ray.ssRayEnd.xy * 0.5 + 0.5, ray.ssRayEnd.z);
    ray.uvRayStart = float3(ray.ssRayStart.xy * 0.5 + 0.5, ray.ssRayStart.z);
    ray.uvRay = uvRayEnd - ray.uvRayStart;
}

float screenSpaceContactShadow(float3 lightDirection, float3 shading_position, 
    float2 input_position) {
    // cast a ray in the direction of the light
    float occlusion = 0.0;

    // These could be user adjustable, but let's keep to the minimum that works well for now.
    int kStepCount = 16;
    float kDistanceMax = 0.05;

    ScreenSpaceRay rayData;
    initScreenSpaceRay(rayData, shading_position, lightDirection, kDistanceMax);

    // step
    float dt = 1.0 / float(kStepCount);

    // tolerance
    float tolerance = abs(rayData.ssViewRayEnd.z - rayData.ssRayStart.z) * dt;

    // dither the ray with interleaved gradient noise
    float dither = getR2(input_position) - 0.5;

    float4 dither4 = getR2_RGBA(input_position + 12) - 0.5;
    uint di = 0;

    // normalized position on the ray (0 to 1)
    float t = dt * dither + dt;

    float3 ray;
    for (int i = 0 ; i < kStepCount ; i++, t += dt) {
        ray = rayData.uvRayStart + rayData.uvRay * t;
        float2 sampleUV = uvToRenderTargetUV(ray.xy);
        sampleUV = TransformStereoScreenSpaceTex(sampleUV, 1.0);
        float z = tex2Dlod(_CameraDepthTexture, float4(sampleUV, 0.0, 0.0)).r;
        float dz = z - ray.z;
        if (abs(tolerance - dz) < tolerance) {
            occlusion += 1.0;
            // try again with different dither offset
            t = (dt * i - dt) + dt * dither4[di];
            di++;
            if (di>4) break;
        }
    }

    // normalize by number of samples taken
    occlusion = occlusion/(di+1);

    // we fade out the contribution of contact shadows towards the edge of the screen
    // because we don't have depth data there
    float2 fade = max(12.0 * abs(ray.xy - 0.5) - 5.0, 0.0);
    occlusion *= saturate(1.0 - dot(fade, fade));
    return occlusion;
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

float3 applyMatcapTint(half4 matcap, half4 tint)
{
    // An adjustment to make matcap colour settings more useful.
    // Tint alpha controls whether matcaps are multiplied or "screen" blended.
    return lerp(1 - ((1 - matcap.rgb) * (1 - tint.rgb)),
                matcap.rgb * tint.rgb,
                tint.a);
}

float3 applyMatcap(sampler2D src, half2 matcapUV, float3 dst, float4 tint, int blendMode, float blendStrength)
{
    half4 matcap = tex2D(src, matcapUV);
    return applyBlendMode(blendMode, dst, applyMatcapTint(matcap, tint), blendStrength * matcap.a);
}

#endif // if UNITY_STANDARD_BRDF_INCLUDED

#endif // SCSS_UTILS_INCLUDED