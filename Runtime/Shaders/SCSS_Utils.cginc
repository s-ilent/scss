#ifndef SCSS_UTILS_INCLUDED
// UNITY_SHADER_NO_UPGRADE
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

float luminance(const float3 linearCol) {
    return dot(linearCol, sRGB_Luminance);
}

// Epsilon value for floating point numbers that we can't allow to reach 0
#define FLT_EPS 1e-5

bool inMirror()
{
    return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
}

float3 inferno_quintic(float x)
{
    x = saturate(x);
    float4 x1 = float4(1.0, x, x * x, x * x * x); // 1 x x2 x3
    float4 x2 = x1 * x1.w * x; // x4 x5 x6 x7
    return float3(
        dot(x1.xyzw, float4(-0.027780558, +1.228188385, +0.278906882, +3.892783760)) + dot(x2.xy, float2(-8.490712758, +4.069046086)),
        dot(x1.xyzw, float4(+0.014065206, +0.015360518, +1.605395918, -4.821108251)) + dot(x2.xy, float2(+8.389314011, -4.193858954)),
        dot(x1.xyzw, float4(-0.019628385, +3.122510347, -5.893222355, +2.798380308)) + dot(x2.xy, float2(-3.608884658, +4.324996022)));
}

float interleaved_gradient(float2 uv)
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

float hashR2_2D( float2 fragCoord ) {
    return frac( 1.0e4 * sin( 17.0*fragCoord.x + 0.1*fragCoord.y ) *
    ( 0.1 + abs( sin( 13.0*fragCoord.y + fragCoord.x )))
    );
}

float hashR2_3D( float3 fragCoord ) {
    return hashR2_2D( float2( hashR2_2D( fragCoord.xy ), fragCoord.z ) );
}

float3 r3_modified(float idx, float3 seed)
{
    return frac(seed + float(idx) * float3(0.180827486604, 0.328956393296, 0.450299522098));
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
float2 sharpSample( float4 texelSize , float2 coord )
{    
    #if defined(SHADER_STAGE_FRAGMENT)
    // Vertex shader errors out on fwidth
    float2 boxSize = clamp(fwidth(coord) * texelSize.zw, 1e-5, 1);
    coord = coord * texelSize.zw - 0.5 * boxSize;
    float2 txOffset = smoothstep(1 - boxSize, 1, frac(coord));
    return(floor(coord) + 0.5 + txOffset) * texelSize.xy; 
    #endif
    return coord;
}

float simpleRimHelper(float power, float NdotV)
{
	float absPower = abs(power);
	if (absPower > 0.0001)
	{
		// d.NdotV is not guaranteed to be positive, so clamp it here. 
		float rimMask = saturate(pow(max(abs(NdotV), float(FLT_EPS)), absPower));
		return power < 0.0 ? 1.0 - rimMask : rimMask;
	}
	return 1.0;
}

// where x is depth and y is the modulator
float depthBlend(float x, float y)
{
	return (x+y) - (x*y);
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

float3 gtaoMultiBounce(float visibility, const float3 albedo) {
    // Jimenez et al. 2016, "Practical Realtime Strategies for Accurate Indirect Occlusion"
    float3 a =  2.0404 * albedo - 0.3324;
    float3 b = -4.7951 * albedo + 0.6417;
    float3 c =  2.7552 * albedo + 0.6903;

    return max((visibility), ((visibility * a + b) * visibility + c) * visibility);
}

inline float4 ApplyNearVertexSquishing(float4 posCS)
{
    #if SCSS_NEAR_SQUISH
    if (unity_OrthoParams.w == 1.0) return posCS;
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

float4 SampleTexture2DBiplanar( sampler2D sam, float3 p, float3 n, float k )
{
    // grab coord derivatives for texturing
    float3 dpdx = ddx(p);
    float3 dpdy = ddy(p);
    n = abs(n);

    // determine major axis (in x; yz are following axis)
    int3 ma =  (n.x>n.y && n.x>n.z) ? int3(0,1,2) :
               (n.y>n.z)            ? int3(1,2,0) :
                                      int3(2,0,1) ;
    // determine minor axis (in x; yz are following axis)
    int3 mi =  (n.x<n.y && n.x<n.z) ? int3(0,1,2) :
               (n.y<n.z)            ? int3(1,2,0) :
                                      int3(2,0,1) ;
    // determine median axis (in x;  yz are following axis)
    int3 me = clamp(3 - mi - ma, 0, 2); 
    
    // project+fetch
    float4 x = tex2Dgrad( sam, float2(   p[ma.y],   p[ma.z]), 
                               float2(dpdx[ma.y],dpdx[ma.z]), 
                               float2(dpdy[ma.y],dpdy[ma.z]) );
    float4 y = tex2Dgrad( sam, float2(   p[me.y],   p[me.z]), 
                               float2(dpdx[me.y],dpdx[me.z]),
                               float2(dpdy[me.y],dpdy[me.z]) );
    
    // blend factors
    float2 w = float2(n[ma.x],n[me.x]);
    // make local support
    w = clamp( (w-0.5773)/(1.0-0.5773), 0.0, 1.0 );
    // shape transition
    w = pow( w, k/8.0 );
    // blend and return
    return (x*w.x + y*w.y) / (w.x + w.y);
}


void applyUnityFog(inout float4 col, float depth)
{
    float fogFactor = 1.0;
    
    if (unity_FogParams.x != 0.0f) // Is Exp2 fog active?
    {
        float exponent_val = unity_FogParams.x * depth;
        fogFactor = exp2(-exponent_val * exponent_val);
    }
    else if (unity_FogParams.y != 0.0f) // Is Exp fog active?
    {
        float exponent = unity_FogParams.y * depth;
        fogFactor = exp2(-exponent);
    }
    else if (unity_FogParams.z != unity_FogParams.w)
    {
        fogFactor = depth * unity_FogParams.z + unity_FogParams.w;
    }
    
    fixed3 appliedFogColor = unity_FogColor.rgb;

    #if defined(UNITY_PASS_FORWARDADD) 
        appliedFogColor = fixed3(0,0,0);
    #endif

    col.rgb = lerp(appliedFogColor, col.rgb, saturate(fogFactor));
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
// Helper functions for matcaps
//-----------------------------------------------------------------------------

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
        case 1: return a * LerpWhiteTo_local(b, t);
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

SamplerState sampler_MatcapTrilinearClampSampler;
float3 applyMatcap(Texture2D src, half2 matcapUV, float3 dst, float4 tint, int blendMode, float blendStrength)
{
	// Skip if intensity is zero. 
	if (blendStrength < 1.0/255.0) return dst;

    half4 matcap = src.Sample(sampler_MatcapTrilinearClampSampler, matcapUV);
    return applyBlendMode(blendMode, dst, applyMatcapTint(matcap, tint), blendStrength * matcap.a);
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

float screenSpaceContactShadow(float3 lightDirection, float3 shadingPosition, 
    float2 screenPosition, float kDistanceMax = 0.1, uint kStepCount = 8) {
    ScreenSpaceRay rayData;
    initScreenSpaceRay(rayData, shadingPosition, lightDirection, kDistanceMax);

    // step size
    float dt = 1.0 / float(kStepCount);

    // tolerance
    float tolerance = abs(rayData.ssViewRayEnd.z - rayData.ssRayStart.z) * dt;

    // dither the ray with noise
    float dither = interleaved_gradient(screenPosition) - 0.5;
    float4 dither4 = getR2_RGBA(screenPosition) - 0.5;

    // normalized position on the ray (0 to 1)
    float t = dt * dither + dt;

    // cast a ray in the direction of the light
    float occlusion = 0.0;
    float softOcclusion = 0.0;
	float firstHit = kStepCount;

    float3 ray;
    uint di = 0; // dither index
    for (uint i = 0 ; i < kStepCount ; ++i, t += dt) {
        ray = rayData.uvRayStart + rayData.uvRay * t;
        float2 sampleUV = uvToRenderTargetUV(ray.xy);
        sampleUV = TransformStereoScreenSpaceTex(sampleUV, 1.0);
        float z = tex2Dlod(_CameraDepthTexture, float4(sampleUV, 0.0, 0.0)).r;
        float dz = z - ray.z;
        if (abs(tolerance - dz) < tolerance) {
			firstHit = min(firstHit, float(i));
            occlusion += 1.0;
			softOcclusion += saturate(kDistanceMax - dz);

            // try again with different dither offset
            // t = (dt * i - dt) + dt * dither4[di&3];

            di++;
        }
    }

	// soft occlusion, includes distance falloff
	occlusion = saturate(softOcclusion * (1.0 - (firstHit / kStepCount)));
    
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


float D_GGX(float roughness, float NoH) {
    float oneMinusNoHSquared = 1.0f - NoH * NoH;
    float a = NoH * roughness;
    float a2 = a * a;
    float k_denominator = oneMinusNoHSquared + a2;
    float k = roughness / k_denominator;
    float d = k * k * (1.0f / UNITY_PI);
    return d;
}

float D_GGX_Anisotropic(float NoH, const float3 h,
        const float3 t, const float3 b, float at, float ab) {
    float ToH = dot(t, h);
    float BoH = dot(b, h);
    float a2 = at * ab;
    float3 v = float3(ab * ToH, at * BoH, a2 * NoH);
    float v2 = dot(v, v);
    float w2 = a2 / max(v2, FLT_EPS);
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

#endif // if UNITY_STANDARD_BRDF_INCLUDED

#endif // SCSS_UTILS_INCLUDED