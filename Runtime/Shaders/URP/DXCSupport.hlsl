/* MIT License
Copyright (c) 2026 Error.mdl

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

/// INSTRUCTIONS -------------------------------------------------------------

// Include this file with '#include_with_pragmas' after the urp Core.hlsl to
// activate DXC for vulkan and non-multiview metal. You may optionally define
// USE_DXC_D3D12_AND_BREAK_D3D11 before this include to use DXC for D3D12,
// but it will prevent the shader from compiling for D3D11.

// Note that there is an unfixable bug with DXC and instancing on Android.
// Instance count must be fixed or severe graphical corruption will occur.

// After including this file, add the following to fix the instance count:

/*
#if defined(NEEDS_FORCE_MAX_INSTANCE_COUNT)
#pragma instancing_options maxcount:128 forcemaxcount:128
#endif
*/

/// Optionally, switch back to the FXC compiler:

/*
#if defined(INSTANCING_FLEXIBLE_ARRAY_SIZE_INCOMPATIBLE)
#pragma never_use_dxc vulkan
#endif
*/

/// END INSTRUCTIONS ---------------------------------------------------------

#ifndef BASIS_DXC_SUPPORT
#define BASIS_DXC_SUPPORT


#pragma use_dxc vulkan

// Can't bypass lack of shader model 6.5 to use SV_ViewID like with vulkan, and I can't test metal
#if !defined(STEREO_MULTIVIEW_ON)
#pragma use_dxc metal
#endif

// unity uses 'd3d11' as the identifier for both D3D11 and D3D12, but DXC can't compile for D3D12 resulting in the shader disappearing without error
// if you don't care about d3d11, define USE_DXC_D3D12_AND_BREAK_D3D11
#if defined(USE_DXC_D3D12_AND_BREAK_D3D11)
#pragma use_dxc d3d11
#endif

#if !defined(UNITY_INSTANCING_INCLUDED)
        #error DXCSupport.hlsl must be included after UnityInstancing.hlsl (included in Core.hlsl)
#endif

// Hack to make multiview stereo work with DXC and vulkan. The default FXC->hlslCC->GLSL
// chain replaces references to a cbuffer constant with the multiview stereo
// eye index glsl builtin. DXC can express the eye index with SV_ViewID, but
// it's only available in shader model 6.5 which unity doesn't let us use.
// However, DXC does let us inject raw SPIR-V...
#if defined(STEREO_MULTIVIEW_ON) && defined(UNITY_COMPILER_DXC) && defined(unity_StereoEyeIndex)

    // in the vertex, unity_StereoEyeIndex is defined to the magic constant buffer value gl_viewID that hlslcc swaps for the gl_viewID_OVR builtin
    #undef unity_StereoEyeIndex

    // make it a static global like in SPSI
    static uint unity_StereoEyeIndex;

    // redefine UNITY_SETUP_INSTANCE_ID to copy the eye index from the vertex to unity_StereoEyeIndex like with SPSI
    #undef UNITY_SETUP_INSTANCE_ID
    #define UNITY_SETUP_INSTANCE_ID(input) unity_StereoEyeIndex = input.stereoTargetEyeIndexAsBlendIdx0 ; DEFAULT_UNITY_SETUP_INSTANCE_ID(input)

    // Redefine the POSITION semantic basically guaranteed to be present in every vertex struct to the functionally equivalent POSITION0,
    // with the addition of the SPIR-V view index following it
    #define POSITION POSITION0; [[vk::ext_decorate(/*Builtin*/11, /*ViewIndex*/4440)]] uint stereoTargetEyeIndexAsBlendIdx0 : VIEWIDX

#endif

// WARNING: DXC does not work with non-fixed size instancing buffers on Android!
// Always use #pragma instancing_options forcemaxcount:count on android, or
// add #pragma never_use_dxc vulkan after this include if on mobile.
//
// If the batch count isn't forced, unity defines all instancing cbuffers to
// contain fixed 2 length arrays since shaders don't support variable length arrays.
// For some reason, binding a constant buffer containing a larger array to the slot
// and using out-of-bounds indices greater than 2 just works on PC hardware.
// On mobile this does not work, and unity uses HLSLcc to replace the instancing
// array lengths with a vulkan specialization constant. This is a vulkan-specific
// feature that directX has no equivalent to, and while DXC does have a way to
// define them, it does not allow using them for array lengths.

#if defined(SHADER_API_MOBILE) && defined(SHADER_API_VULKAN) && defined(UNITY_INSTANCING_ENABLED) && defined(UNITY_INSTANCING_SUPPORT_FLEXIBLE_ARRAY_SIZE)
    #define INSTANCING_FLEXIBLE_ARRAY_SIZE_INCOMPATIBLE 1
#endif // SHADER_API_MOBILE && SHADER_API_VULKAN && UNITY_INSTANCING_ENABLED && UNITY_INSTANCING_SUPPORT_FLEXIBLE_ARRAY_SIZE

#if defined(UNITY_COMPILER_DXC) && defined(INSTANCING_FLEXIBLE_ARRAY_SIZE_INCOMPATIBLE)
    #if !defined(UNITY_FORCE_MAX_INSTANCE_COUNT)
        #error Cannot use the DXC compiler for mobile shaders with GPU instancing and variable instancing count. Add pragma never_use_dxc after this include or use pragma instancing_options forcemaxcount:count
    #endif
    #define NEEDS_FORCE_MAX_INSTANCE_COUNT 1
#endif // UNITY_COMPILER_DXC && INSTANCING_FLEXIBLE_ARRAY_SIZE_INCOMPATIBLE


#endif // BASIS_DXC_SUPPORT
