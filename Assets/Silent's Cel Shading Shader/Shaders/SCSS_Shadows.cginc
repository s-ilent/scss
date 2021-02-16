#ifndef SHADOWS_INCLUDED
#define SHADOWS_INCLUDED

#include "UnityCG.cginc"
#include "UnityShaderVariables.cginc"
#include "SCSS_Utils.cginc"
#include "SCSS_Input.cginc"

#pragma multi_compile_shadowcaster
#pragma fragmentoption ARB_precision_hint_fastest

// Do dithering for alpha blended shadows on SM3+/desktop;
// on lesser systems do simple alpha-tested shadows
#if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
    #if !((SHADER_TARGET < 30) || defined (SHADER_API_MOBILE) || defined(SHADER_API_D3D11_9X) || defined (SHADER_API_PSP2) || defined (SHADER_API_PSM))
        #define UNITY_STANDARD_USE_DITHER_MASK 1
    #endif
#endif

// Need to output UVs in shadow caster, since we need to sample texture and do clip/dithering based on it
#if defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
    #define UNITY_STANDARD_USE_SHADOW_UVS 1
#endif

//uniform float4      _Color;
//uniform float       _Cutoff;
//uniform sampler2D   _MainTex;
//uniform sampler2D   _ClippingMask;
//uniform float4      _MainTex_ST;
#ifdef UNITY_STANDARD_USE_DITHER_MASK
    uniform sampler3D   _DitherMaskLOD;
#endif

//uniform float       _AlbedoAlphaMode;
//uniform float       _VanishingStart;
//uniform float       _VanishingEnd;
//uniform float       _UseVanishing;
//uniform float       _AlphaSharp;
//uniform float       _Tweak_Transparency;

struct VertexInput
{
    float4 vertex   : POSITION;
    float3 normal   : NORMAL;
    float2 uv0      : TEXCOORD0;
};


// Don't make the structure if it's empty (it's an error to have empty structs on some platforms...)
#if !defined(V2F_SHADOW_CASTER_NOPOS_IS_EMPTY) || defined(UNITY_STANDARD_USE_SHADOW_UVS)
struct VertexOutputShadowCaster
{
    V2F_SHADOW_CASTER_NOPOS
        // Need to output UVs in shadow caster, since we need to sample texture and do clip/dithering based on it
    #if defined(UNITY_STANDARD_USE_SHADOW_UVS)
        float2 tex : TEXCOORD1;
    #endif
};

float4 TexCoordsShadowCaster(VertexOutputShadowCaster v)
{
    float4 texcoord;
    texcoord.xy = TRANSFORM_TEX(v.tex, _MainTex);// Always source from uv0
    texcoord.xy = _PixelSampleMode? 
        sharpSample(_MainTex_TexelSize * _MainTex_ST.xyxy, texcoord.xy) : texcoord.xy;

    return texcoord;
}
#endif

// We have to do these dances of outputting SV_POSITION separately from the vertex shader,
// and inputting VPOS in the pixel shader, since they both map to "POSITION" semantic on
// some platforms, and then things don't go well.

void vertShadowCaster(VertexInput v,
    #if !defined(V2F_SHADOW_CASTER_NOPOS_IS_EMPTY) || defined(UNITY_STANDARD_USE_SHADOW_UVS)
        out VertexOutputShadowCaster o,
    #endif
    out float4 opos : SV_POSITION)
{
    TRANSFER_SHADOW_CASTER_NOPOS(o, opos)
    //TRANSFER_SHADOW_CASTER_NOPOS_LEGACY (o, opos)

    #if defined(UNITY_STANDARD_USE_SHADOW_UVS)
        o.tex = AnimateTexcoords(v.uv0);;
    #endif
}

half4 fragShadowCaster(
    #if !defined(V2F_SHADOW_CASTER_NOPOS_IS_EMPTY) || defined(UNITY_STANDARD_USE_SHADOW_UVS)
        VertexOutputShadowCaster i
        #if !defined(UNITY_STANDARD_USE_DITHER_MASK)
            , UNITY_VPOS_TYPE vpos : VPOS
        #endif
    #endif
    
    #ifdef UNITY_STANDARD_USE_DITHER_MASK
        , UNITY_VPOS_TYPE vpos : VPOS
    #endif
    
) : SV_Target
{
    #if defined(UNITY_STANDARD_USE_SHADOW_UVS)
        float4 texcoords = TexCoordsShadowCaster(i);
        fixed3 albedo = Albedo(texcoords);
        half alpha = Alpha(texcoords);

        #if defined(ALPHAFUNCTION)
        alphaFunction(alpha);
        #endif

        applyVanishing(alpha);
    #endif

    #if defined(UNITY_STANDARD_USE_SHADOW_UVS) || defined(UNITY_STANDARD_USE_DITHER_MASK)
        applyAlphaClip(alpha, _Cutoff, vpos.xy, _AlphaSharp);
    #endif

    SHADOW_CASTER_FRAGMENT(i)
}

#endif