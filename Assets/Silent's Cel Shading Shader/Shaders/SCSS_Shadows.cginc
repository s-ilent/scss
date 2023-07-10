#ifndef SCSS_SHADOWS_INCLUDED
#define SCSS_SHADOWS_INCLUDED

#pragma multi_compile_shadowcaster
#pragma fragmentoption ARB_precision_hint_fastest

#include "UnityCG.cginc"
#include "UnityShaderVariables.cginc"

// In Standard, this is gated behind UNITY_USE_DITHER_MASK_FOR_ALPHABLENDED_SHADOWS but it's
// better for us to avoid relying on unrelated project settings. 
#if (defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON))
    #define SCSS_USE_DITHER_MASK 1
#endif

// Need to output UVs in shadow caster, since we need to sample texture and do clip/dithering based on it
#if defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
    #define SCSS_USE_SHADOW_UVS 1
#endif

// Has a non-empty shadow caster output struct (it's an error to have empty structs on some platforms...)
#if !defined(V2F_SHADOW_CASTER_NOPOS_IS_EMPTY) || defined(SCSS_USE_SHADOW_UVS)
    #define SCSS_USE_SHADOW_OUTPUT_STRUCT 1
#endif

#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(STEREO_INSTANCING_ON)
    #define SCSS_USE_STEREO_SHADOW_OUTPUT_STRUCT 1
#endif

// This is defined somewhere deep in Standard/UnityCG. 
float4 _SpecColor;

#include "SCSS_Config.cginc"
#include "SCSS_Utils.cginc"
#include "SCSS_Input.cginc"
#include "SCSS_Attributes.cginc"
#include "SCSS_Forward.cginc"
#include "SCSS_ForwardVertex.cginc"

// We have to do these dances of outputting SV_POSITION separately from the vertex shader,
// and inputting VPOS in the pixel shader, since they both map to "POSITION" semantic on
// some platforms, and then things don't go well.

void vertShadowCaster (VertexInputShadowCaster v
    , out float4 opos : SV_POSITION
    #ifdef SCSS_USE_SHADOW_OUTPUT_STRUCT
    , out VertexOutputShadowCaster o
    #endif
    #ifdef SCSS_USE_STEREO_SHADOW_OUTPUT_STRUCT
    , out VertexOutputStereoShadowCaster os
    #endif
)
{
    UNITY_SETUP_INSTANCE_ID(v);

    // Object-space vertex modifications go here.
    #ifdef SCSS_USE_SHADOW_OUTPUT_STRUCT
        UNITY_TRANSFER_INSTANCE_ID(v, o);
    #endif
    
    #ifdef SCSS_USE_STEREO_SHADOW_OUTPUT_STRUCT
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(os);
    #endif

    TRANSFER_SHADOW_CASTER_NOPOS(o,opos)
    //TRANSFER_SHADOW_CASTER_NOPOS_LEGACY (o, opos)

    // Standard would apply texcoords here, but we need to apply them in fragment
    // due to pixel sampling mode options.


    // Simple inventory.
    float inventoryMask = getInventoryMask(v.texcoord.xy);

    // Apply the inventory mask.
    // Set the output variables based on the mask to completely remove it.
    // - Set the clip-space position to one that won't be rendered
    // - Set the vertex alpha to zero
    // - Disable outlines
    if (_UseInventory)
    {
        opos.z =     inventoryMask ? opos.z : 1e+9;
        //o.vertex =    inventoryMask ? o.vertex : 1e+9;
    }
    
    opos = ApplyNearVertexSquishing(opos);

    #if defined(SCSS_USE_SHADOW_UVS)
        float4 uvPack0 = float4(v.texcoord.xy, v.texcoord1.xy);
        float4 uvPack1 = float4(v.texcoord2.xy, v.texcoord3.xy);
        uvPack0.xy = AnimateTexcoords(uvPack0.xy);
        o.uvPack0 = uvPack0;
        o.uvPack1 = uvPack1;
    #endif
}

half4 fragShadowCaster (
    UNITY_POSITION(vpos)
#ifdef SCSS_USE_SHADOW_OUTPUT_STRUCT
    , VertexOutputShadowCaster i
#endif
) : SV_Target
{
    // No need to set up if i does not exist
    #if (defined(UNITY_STEREO_INSTANCING_ENABLED) && defined(SCSS_USE_SHADOW_OUTPUT_STRUCT))
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i)
    #endif

    // Setup Material, but dummy out unused elements.
    float4 uvPack0 = 0;
    float4 uvPack1 = 0;
    #if defined(SCSS_USE_SHADOW_UVS)
    uvPack0 = i.uvPack0;
    uvPack1 = i.uvPack1;
    #endif
    SCSS_Input material = 
    MaterialSetup(uvPack0, uvPack1, /* color */ 1.0, /* extraData */ 1.0, /* isOutline */ 0.0, /* facing */ true);

    #if defined(ALPHAFUNCTION)
    alphaFunction(material.alpha);
    #endif

    applyVanishing(material.alpha);

    // When premultiplied mode is set, this will multiply the diffuse by the alpha component,
    // allowing to handle transparency in physically correct way - only diffuse component gets affected by alpha
    float finalAlpha = material.alpha;
    PreMultiplyAlpha_local (material.albedo, material.alpha, material.oneMinusReflectivity, /*out*/ finalAlpha);

    applyAlphaClip(finalAlpha, _Cutoff, vpos.xy, _AlphaSharp, true);

    SHADOW_CASTER_FRAGMENT(i) 
}

#endif