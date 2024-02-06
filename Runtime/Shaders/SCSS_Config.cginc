#ifndef SCSS_CONFIG_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_CONFIG_INCLUDED

// Perform full-quality light calculations on unimportant lights.
// Considering our target GPUs, this is a big visual improvement
// for a small performance penalty.
#define SCSS_UNIMPORTANT_LIGHTS_FRAGMENT 1

// When rendered by a non-HDR camera, clamp incoming lighting.
// This works around issues where scenes are set up incorrectly
// for non-HDR.
#define SCSS_CLAMP_IN_NON_HDR 1

// When screen-space shadows are used in the scene, performs a
// search to find the best sampling point for the shadow
// using the camera's depth buffer. This filters away many aliasing
// artifacts caused by limitations in the screen shadow technique
// used by directional lights.
#define SCSS_SCREEN_SHADOW_FILTER 1

// As objects become further and further from the origin point
// (0, 0, 0) in world space, they become affected by the 
// limitations of precision in floating point numbers.
// For shaders, this manifests as polygons wobbling and warping
// as they are further away from the origin point.
// This setting enables a system that calculates the final placement
// of polygons on screen seperately from their world-space
// position, partly alleviating this issue. However, it interferes
// with some of Unity's systems that expect the result of the
// object to world transformation to be identical between shaders. 
//#define SCSS_CAMERA_RELATIVE_VERTEX 1

// When objects reach the nearest extent of the camera's frustrum,
// they can intersect it and clip through. In VR, this can be a 
// problem as frustrum extents which are suitable for most circumstances
// will fall apart when close to an object - or, more commonly, another
// person. This setting enables a tweak to squish objects before they can
// intersect with the frustrum, giving them the appearance of a
// closer clipping plane on the camera.
#define SCSS_NEAR_SQUISH 1

// Safety net for things that can't be used in Standard's codepaths on weaker hardware
// Following implementation in Unity 2020's built-in pipeline

#if defined(SHADER_TARGET_SURFACE_ANALYSIS)
    // For surface shader code analysis pass, disable some features that don't affect inputs/outputs
    #undef UNITY_SPECCUBE_BOX_PROJECTION
    #undef UNITY_SPECCUBE_BLENDING
    #undef UNITY_USE_DITHER_MASK_FOR_ALPHABLENDED_SHADOWS
#elif SHADER_TARGET < 30
    #undef UNITY_SPECCUBE_BOX_PROJECTION
    #undef UNITY_SPECCUBE_BLENDING
    #undef UNITY_ENABLE_DETAIL_NORMALMAP
    #ifdef _PARALLAXMAP
        #undef _PARALLAXMAP
    #endif
#endif
#if (SHADER_TARGET < 30) || defined(SHADER_API_GLES)
    #undef UNITY_USE_DITHER_MASK_FOR_ALPHABLENDED_SHADOWS
#endif

#ifndef UNITY_SAMPLE_FULL_SH_PER_PIXEL
    // Lightmap UVs and ambient color from SHL2 are shared in the vertex to pixel interpolators. Do full SH evaluation in the pixel shader when static lightmap and LIGHTPROBE_SH is enabled.
    #define UNITY_SAMPLE_FULL_SH_PER_PIXEL (LIGHTMAP_ON && LIGHTPROBE_SH)

    // Shaders might fail to compile due to shader instruction count limit. Leave only baked lightmaps on SM20 hardware.
    #if UNITY_SAMPLE_FULL_SH_PER_PIXEL && (SHADER_TARGET < 25)
        #undef UNITY_SAMPLE_FULL_SH_PER_PIXEL
        #undef LIGHTPROBE_SH
    #endif
#endif

#endif // SCSS_CONFIG_INCLUDED