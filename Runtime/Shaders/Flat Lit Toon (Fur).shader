Shader "Silent's Cel Shading/Lightramp (Fur)"
{
	Properties
	{
		[Header(Main)]
		_MainTex("Main Texture", 2D) = "white" {}
		_Color("Tint", Color) = (1,1,1,1)
		_Cutoff("Alpha Cutoff", Range(0,1)) = 0.5
		[Enum(TransparencyMode)]_AlphaSharp("Transparency Mode", Float) = 0.0
		//[Space]
		[Toggle(_BACKFACE)]_UseBackfaceTexture("Enable Backface Texture", Float ) = 0.0
		_ColorBackface("Backface Tint", Color) = (1,1,1,1)
		_MainTexBackface("Backface Main Texture", 2D) = "white" {}
		//[Space]
		_ColorMask("Color Mask Map", 2D) = "white" {}
		_ClippingMask ("Alpha Transparency Map", 2D) = "white" {}
        _Tweak_Transparency ("Transparency Adjustment", Range(-1, 1)) = 0
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpScale("Normal Map Scale", Float) = 1.0
		[Enum(VertexColorType)]_VertexColorType ("Vertex Colour Type", Float) = 2.0
		[Enum(VertexColorChannelType)]_VertexColorRType ("Vertex Red Type", Float) = 1.0
		[Enum(VertexColorChannelType)]_VertexColorGType ("Vertex Green Type", Float) = 4.0
		[Enum(VertexColorChannelType)]_VertexColorBType ("Vertex Blue Type", Float) = 3.0
		[Enum(VertexColorChannelType)]_VertexColorAType ("Vertex Alpha Type", Float) = 1.0
		//[Space]
		[Enum(TintApplyMode)]_ToggleHueControls("Show HSV Controls", Float) = 0.0
		_ShiftHue ("Hue Shift", Range(-180, 180)) = 0.0
		_ShiftSaturation ("Saturation Shift", Range(0, 6)) = 1.0
		_ShiftValue ("Value Shift", Range(0, 6)) = 1.0
		//[Space]
		//[Space]
		[Enum(LightRampType)]_LightRampType ("Light Ramp Type", Float) = 0.0
		_Ramp ("Lighting Ramp", 2D) = "white" {}
		//[Space]
		[Enum(ShadowMaskType)] _ShadowMaskType ("Shadow Mask Type", Float) = 0.0
		_ShadowMask("Shadow Mask", 2D) = "white" {} 
		_ShadowMaskColor("Shadow Mask Color", Color) = (1,1,1,1)
		_Shadow("Shadow Mask Power", Range(0, 1)) = 0.5
		_ShadowLift("Shadow Offset", Range(-1, 1)) = 0.0
		_IndirectLightingBoost("Indirect Lighting Boost", Range(0, 1)) = 0.0
		//[Space]
		_SDFMode("SDF Mode", Float) = 0
		_SDFSmoothness("SDF Smoothness", Range(0, 1)) = 0.01
		//[Space]
		[Enum(OutlineMode)] _OutlineMode("Outline Mode", Float) = 1.0
		_OutlineMask("Outline Map", 2D) = "white" {}
		_OutlineZPush("Outline Z Push", Float) = 0.0
		[Enum(OutlineCalculationMode)]_OutlineCalculationMode("Outline Calculation Mode", Float) = 0
		_outline_width("Outline Width", Float) = 0.1
		_OutlineNearDistance ("Outline Nearest Distance", Float) = 0.25
		_OutlineFarDistance ("Outline Farthest Distance", Float) = 10
		_outline_color("Outline Colour", Color) = (0.5,0.5,0.5,1)
		//[Space]
        _FurMode("Fur Mode", Float) = 0.0
        [IntRange]_FurLayerCount("Layer Count", Range(1, 32)) = 8
        _FurMask("Fur Mask", 2D) = "white" {}
		_FurNoise("Fur Shape Texture", 2D) = "white" {}
		_FurLength("Length", Float) = 1.0
		_FurRandomization("Randomization", Float) = 0.0
		[Gamma]_FurThickness("Thickness", Range(0.01, 2)) = 1.0
		_FurGravity("Gravity", Range(-0.99, 0.99)) = 1.0
		//[Space]
		[Enum(AmbientFresnelType)]_UseFresnel ("Use Rim Light", Float) = 0.0
		[HDR]_FresnelTint("Rim Light Tint", Color) = (1,1,1,1)
		_FresnelWidth ("Rim Light Strength", Range(0, 20)) = .5
		_FresnelStrength ("Rim Light Softness", Range(0.01, 0.9999)) = 0.5
		[ToggleUI]_UseFresnelLightMask("Mask Rim Light by Light Direction", Float) = 0.0
		_FresnelLightMask("Light Direction Mask Power", Range(1, 10)) = 1.0
		[HDR]_FresnelTintInv("Inverse Rim Light Tint", Color) = (1,1,1,1)
		_FresnelWidthInv ("Inverse Rim Light Strength", Range(0, 20)) = .5
		_FresnelStrengthInv ("Inverse Rim Light Softness", Range(0.01, 0.9999)) = 0.5
		//[Space]
		[Enum(SpecularType)] _SpecularType ("Specular Type", Float) = 0.0
        _SpecColor("Specular", Color) = (1,1,1)
		_SpecGlossMap ("Specular Map", 2D) = "white" {}
		[ToggleUI]_UseMetallic ("Use as Metallic", Float) = 0.0
		[ToggleUI]_UseEnergyConservation ("Energy Conservation", Float) = 0.0
		_Smoothness ("Smoothness", Range(0, 1)) = 1
		_CelSpecularSoftness ("Softness", Range(1, 0)) = 0.02
		_CelSpecularSteps("Steps", Range(1, 4)) = 1
		_Anisotropy("Anisotropy", Range(-1,1)) = 0.8
		_SpecIridescenceRamp ("Iridescence Ramp", 2D) = "white" {}
		//[Space]
		[Enum(MatcapType)]_UseMatcap ("Matcap Type", Float) = 0.0
		_MatcapMask("Matcap Mask", 2D) = "white" {}
		//[Space]
		_Matcap1("Matcap 1", 2D) = "black" {}
		_Matcap1Strength("Matcap 1 Strength", Range(0, 2)) = 1.0
		[Enum(MatcapBlendModes)]_Matcap1Blend("Matcap 1 Blend Mode", Float) = 0.0
		_Matcap1Tint("Matcap 1 Tint", Color) = (1, 1, 1, 1)
		//[Space]
		_Matcap2("Matcap 2", 2D) = "black" {}
		_Matcap2Strength("Matcap 2 Strength", Range(0, 2)) = 1.0
		[Enum(MatcapBlendModes)]_Matcap2Blend("Matcap 2 Blend Mode", Float) = 0.0
		_Matcap2Tint("Matcap 2 Tint", Color) = (1, 1, 1, 1)
		//[Space]
		_Matcap3("Matcap 3", 2D) = "black" {}
		_Matcap3Strength("Matcap 3 Strength", Range(0, 2)) = 1.0
		[Enum(MatcapBlendModes)]_Matcap3Blend("Matcap 3 Blend Mode", Float) = 0.0
		_Matcap3Tint("Matcap 3 Tint", Color) = (1, 1, 1, 1)
		//[Space]
		_Matcap4("Matcap 4", 2D) = "black" {}
		_Matcap4Strength("Matcap 4 Strength", Range(0, 2)) = 1.0
		[Enum(MatcapBlendModes)]_Matcap4Blend("Matcap 4 Blend Mode", Float) = 0.0
		_Matcap4Tint("Matcap 4 Tint", Color) = (1, 1, 1, 1)

		//[Space]
		//[Toggle(_EMISSION)]
		_EmissionMap("Emission Map", 2D) = "white" {}
		[Enum(Additive, 0, Mask, 1)]_EmissionMode("Emission Mode", Float) = 0.0
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]_EmissionUVSec("Emission UV Source", Float) = 0
		[HDR]_EmissionColor("Emission Color", Color) = (0,0,0,1)
		//[Space]
		_DetailEmissionMap("Detail Emission Map", 2D) = "white" {}
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]_DetailEmissionUVSec("Detail Emission UV Source", Float) = 0
		[Enum(DetailEmissionMode)]_EmissionDetailType("Emission Detail Type", Float) = 0
		[HDR]_EmissionDetailParams("Emission Detail Params", Vector) = (0,0,0,0)
		
		//[Space]
		//[Toggle(_EMISSION_2ND)]
		_EmissionMap2nd("2nd Emission Map", 2D) = "white" {}
		[Enum(Additive, 0, Mask, 1)]_EmissionMode2nd("2nd Emission Mode", Float) = 0.0
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]_EmissionUVSec2nd("2nd Emission UV Source", Float) = 0
		[HDR]_EmissionColor2nd("2nd Emission Color", Color) = (0,0,0,1)
		//[Space]
		_DetailEmissionMap2nd("2nd Detail Emission Map", 2D) = "white" {}
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]_DetailEmissionUVSec2nd("2nd Detail Emission UV Source", Float) = 0
		[HDR]_EmissionDetailParams2nd("2nd Emission Detail Params", Vector) = (0,0,0,0)
		//[Space]
		_EmissionRimPower2nd("2nd Emission Rim Power", Float) = 0.0
		
		//[Space]
		[ToggleUI]_UseEmissiveLightSense ("Use Light-sensing Emission", Float) = 0.0
		_EmissiveLightSenseStart("Light Threshold Start", Range(0, 1)) = 1.0
		_EmissiveLightSenseEnd("Light Threshold End", Range(0, 1)) = 0.0
		_EmissionRimPower("Emission Rim Power", Float) = 0.0

		//[Space]
		[Toggle(_DETAIL_MULX2)]_UseDetailMaps("Enable Detail Maps", Float) = 0.0
		_DetailAlbedoMask ("Detail Mask", 2D) = "white" {}

        _DetailMap1 ("Detail Map 1", 2D) = "grey" {}
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]
        _DetailMap1UV ("Detail Map 1 UV", Float) = 0.0
		[Enum(DetailMapType)]
        _DetailMap1Type ("Detail Map 1 Type", Float) = 0.0
		[Enum(DetailBlendMode)]
        _DetailMap1Blend ("Detail Map 1 Blend Mode", Float) = 0.0
        _DetailMap1Strength ("Detail Map 1 Power", Range(0, 1)) = 1.0

        _DetailMap2 ("Detail Map 2", 2D) = "grey" {}
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]
        _DetailMap2UV ("Detail Map 2 UV", Float) = 0.0
		[Enum(DetailMapType)]
        _DetailMap2Type ("Detail Map 2 Type", Float) = 0.0
		[Enum(DetailBlendMode)]
        _DetailMap2Blend ("Detail Map 2 Blend Mode", Float) = 0.0
        _DetailMap2Strength ("Detail Map 2 Power", Range(0, 1)) = 1.0

        _DetailMap3 ("Detail Map 3", 2D) = "grey" {}
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]
        _DetailMap3UV ("Detail Map 3 UV", Float) = 0.0
		[Enum(DetailMapType)]
        _DetailMap3Type ("Detail Map 3 Type", Float) = 0.0
		[Enum(DetailBlendMode)]
        _DetailMap3Blend ("Detail Map 3 Blend Mode", Float) = 0.0
        _DetailMap3Strength ("Detail Map 3 Power", Range(0, 1)) = 1.0

        _DetailMap4 ("Detail Map 4", 2D) = "grey" {}
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]
        _DetailMap4UV ("Detail Map 4 UV", Float) = 0.0
		[Enum(DetailMapType)]
        _DetailMap4Type ("Detail Map 4 Type", Float) = 0.0
		[Enum(DetailBlendMode)]
        _DetailMap4Blend ("Detail Map 4 Blend Mode", Float) = 0.0 
        _DetailMap4Strength ("Detail Map 4 Power", Range(0, 1)) = 1.0 

		[Toggle(_AUDIOLINK)]_UseEmissiveAudiolink("Enable Audiolink Emission", Float ) = 0.0
		_AudiolinkIntensity("Audiolink Emission Intensity", Float) = 1.0
		_AudiolinkMaskMap ("Audiolink Mask Map", 2D) = "white" {}
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]_AudiolinkMaskMapUVSec("Audiolink Mask UV Source", Float) = 0
		_AudiolinkSweepMap ("Audiolink Sweep Map", 2D) = "gray" {}
        [Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]_AudiolinkSweepMapUVSec("Audiolink Sweep UV Source", Float) = 0
		[ToggleUI]_UseAudiolinkLightSense ("Use Light-sensing Audiolink", Float) = 0.0
		_AudiolinkLightSenseStart("Light Threshold Start", Range(0, 1)) = 1.0
		_AudiolinkLightSenseEnd("Light Threshold End", Range(0, 1)) = 0.0
		//[Space]
        _alColorR("Red Channel Tint", Color)   = (1, 0.333, 0, 0)
        _alColorG("Green Channel Tint", Color) = (0, 1, 0.333, 0)
        _alColorB("Blue Channel Tint", Color)  = (0.33, 0, 1, 0)
        _alColorA("Alpha Channel Tint", Color) = (0.333, 0.333, 0.333, 0)
        [IntRange]_alBandR("Red Channel Band", Range(0, 4)) = 1
        [IntRange]_alBandG("Green Channel Band", Range(0, 4)) = 2
        [IntRange]_alBandB("Blue Channel Band", Range(0, 4)) = 3
        [IntRange]_alBandA("Alpha Channel Band", Range(0, 4)) = 0
        [Enum(Pulse, 0, VU, 1)]_alModeR("AudioLink Mode", Float) = 0
        [Enum(Pulse, 0, VU, 1)]_alModeG("AudioLink Mode", Float) = 0
        [Enum(Pulse, 0, VU, 1)]_alModeB("AudioLink Mode", Float) = 0
        [Enum(Pulse, 0, VU, 1)]_alModeA("AudioLink Mode", Float) = 0
        [Gamma]_alTimeRangeR("Audio Link Time Range", Range(0, 1)) = 1.0
        [Gamma]_alTimeRangeG("Audio Link Time Range", Range(0, 1)) = 1.0
        [Gamma]_alTimeRangeB("Audio Link Time Range", Range(0, 1)) = 1.0
        [Gamma]_alTimeRangeA("Audio Link Time Range", Range(0, 1)) = 1.0
        [Enum(Disable, 0, Enable, 1, Force on, 2)]_alUseFallback("Enable fallback", Float) = 1
        _alFallbackBPM("Fallback BPM", Float) = 160
		[Enum(UV0,0,UV1,1)]_UVSec ("UV Set Secondary", Float) = 0
		//[Space]
		[Toggle(_SUNDISK_NONE)]_UseSubsurfaceScattering ("Use Subsurface Scattering", Float) = 0.0
		_ThicknessMap("Thickness Map", 2D) = "black" {}
		[ToggleUI]_ThicknessMapInvert("Invert Thickness", Float) = 0.0
		_ThicknessMapPower ("Thickness Map Power", Range(0.01, 10)) = 1
		_SSSCol ("Scattering Color", Color) = (1,1,1,1)
		_SSSIntensity ("Scattering Intensity", Range(0, 10)) = 1
		_SSSPow ("Scattering Power", Range(0.01, 10)) = 1
		_SSSDist ("Scattering Distance", Range(0, 10)) = 1
		_SSSAmbient ("Scattering Ambient", Range(0, 1)) = 0
		//[Space]
		[Toggle(_CONTACTSHADOWS)]_UseContactShadows ("Use Contact Shadows", Float) = 0
		_ContactShadowDistance("Max Distance", Range(0.01, 0.2)) = 0.1
		[IntRange]_ContactShadowSteps("Steps", Range(2, 32)) = 8
		//[Space]
		[ToggleUI]_UseAnimation ("Use Animation", Float) = 0.0
		_AnimationSpeed ("_AnimationSpeed", Float) = 10
		_TotalFrames ("_TotalFrames", Int) = 4
		_FrameNumber ("_FrameNumber", Int) = 0
		_Columns ("_Columns", Int) = 2
		_Rows ("_Rows", Int) = 2
		//[Space]
		[ToggleUI]_UseVanishing ("Use Vanishing", Float) = 0.0
		_VanishingStart("Vanishing Start", Float) = 0.0
		_VanishingEnd("Vanishing End", Float) = 0.0
		//[Space]
		[ToggleUI]_UseProximityShadow ("Use Proximity Shadow", Float) = 0.0
		_ProximityShadowDistance("Shadow Start Distance", Float) = 0.1
		_ProximityShadowDistancePower("Shadow Start Distance Power", Float) = 1.5
		_ProximityShadowFrontColor("Shadow Color (front)", Color) = (0,0,0,1)
		_ProximityShadowBackColor("Shadow Color (back)", Color) = (0,0,0,1)
		//[Space]
		[ToggleUI]_UseInventory("Use Inventory", Float) = 0.0
		_InventoryStride("Inventory Stride", Int) = 1
		[Enum(UV0, 0, UV1, 1, UV2, 2, UV3, 3)]_InventoryUVSec("Inventory UV Source", Float) = 0
		[ToggleUI]_InventoryItem01Animated("Toggle Item 1", Float) = 1.0
		[ToggleUI]_InventoryItem02Animated("Toggle Item 2", Float) = 1.0
		[ToggleUI]_InventoryItem03Animated("Toggle Item 3", Float) = 1.0
		[ToggleUI]_InventoryItem04Animated("Toggle Item 4", Float) = 1.0
		[ToggleUI]_InventoryItem05Animated("Toggle Item 5", Float) = 1.0
		[ToggleUI]_InventoryItem06Animated("Toggle Item 6", Float) = 1.0
		[ToggleUI]_InventoryItem07Animated("Toggle Item 7", Float) = 1.0
		[ToggleUI]_InventoryItem08Animated("Toggle Item 8", Float) = 1.0
		[ToggleUI]_InventoryItem09Animated("Toggle Item 9", Float) = 1.0
		[ToggleUI]_InventoryItem10Animated("Toggle Item 10", Float) = 1.0
		[ToggleUI]_InventoryItem11Animated("Toggle Item 11", Float) = 1.0
		[ToggleUI]_InventoryItem12Animated("Toggle Item 12", Float) = 1.0
		[ToggleUI]_InventoryItem13Animated("Toggle Item 13", Float) = 1.0
		[ToggleUI]_InventoryItem14Animated("Toggle Item 14", Float) = 1.0
		[ToggleUI]_InventoryItem15Animated("Toggle Item 15", Float) = 1.0
		[ToggleUI]_InventoryItem16Animated("Toggle Item 16", Float) = 1.0
		//[Space]
		_LightMultiplyAnimated("Modulate outgoing light", Range(0, 1)) = 1.0
		[ToggleUI]_LightClampAnimated("Reduce outgoing light", Range(0, 1)) = 0.0
		_LightAddAnimated("Boost outgoing light", Range(0, 1)) = 0.0
		//[Space]
		[ToggleUI]_AlbedoAlphaMode("Albedo Alpha Mode", Float) = 0.0
		[ToggleUI]_PixelSampleMode("Sharp Sampling Mode", Float) = 0.0
		//[Space]
		[Enum(LightingCalculationType)] _LightingCalculationType ("Lighting Calculation Type", Float) = 0.0
		[Enum(IndirectShadingType)] _IndirectShadingType ("Indirect Shading Type", Float) = 0.0
		_LightSkew ("Light Skew", Vector) = (1, 0.1, 1, 0)
        _DiffuseGeomShadowFactor ("Diffuse Geometric Shadowing Factor", Range(0, 1)) = 1
        _LightWrappingCompensationFactor("Light Wrapping Compensation Factor", Range(0.5, 1)) = 0.8
		//[Space]
		[ToggleOff(_SPECULARHIGHLIGHTS_OFF)]_SpecularHighlights ("Specular Highlights", Float) = 1.0
		[ToggleOff(_GLOSSYREFLECTIONS_OFF)]_GlossyReflections ("Glossy Reflections", Float) = 1.0
		//[Space]
        // Advanced options.
		//[Header(System Render Flags)]
        [Enum(RenderingMode)] _Mode("Rendering Mode", Float) = 0                                     // "Opaque"
        [Enum(CustomRenderingMode)] _CustomMode("Mode", Float) = 0                                   // "Opaque"
        [Enum(DepthWrite)] _AtoCMode("Alpha to Mask", Float) = 0                                     // "Off"
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source Blend", Float) = 1                 // "One"
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination Blend", Float) = 0            // "Zero"
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp("Blend Operation", Float) = 0                 // "Add"
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("Depth Test", Float) = 4                // "LessEqual"
        [Enum(DepthWrite)] _ZWrite("Depth Write", Float) = 1                                         // "On"
        [Enum(UnityEngine.Rendering.ColorWriteMask)] _ColorWriteMask("Color Write Mask", Float) = 15 // "All"
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 2                     // "Back"
        _RenderQueueOverride("Render Queue Override", Range(-1.0, 5000)) = -1
		//[Space]
        // Stencil options.
		//[Header(System Stencil Flags)]
	    [IntRange] _Stencil ("Stencil ID [0;255]", Range(0,255)) = 0
	    _ReadMask ("ReadMask [0;255]", Int) = 255
	    _WriteMask ("WriteMask [0;255]", Int) = 255
	    [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comparison", Int) = 0
	    [Enum(UnityEngine.Rendering.StencilOp)] _StencilOp ("Stencil Operation", Int) = 0
	    [Enum(UnityEngine.Rendering.StencilOp)] _StencilFail ("Stencil Fail", Int) = 0
	    [Enum(UnityEngine.Rendering.StencilOp)] _StencilZFail ("Stencil ZFail", Int) = 0
	    [HideInInspector]__Baked ("Is this material referencing a baked shader?", Float) = 0
		[NonModifiableTextureData][HideInInspector]_DFG("Specular Distribution", 2D) = "green" {}
	}

	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
		}

        Blend[_SrcBlend][_DstBlend], One One
        BlendOp[_BlendOp], Max
        ZTest[_ZTest]
        ZWrite[_ZWrite]
        Cull[_CullMode]
        ColorMask[_ColorWriteMask]
		// AlphaToMask [_AtoCMode]

        Stencil
        {
            Ref [_Stencil]
            ReadMask [_ReadMask]
            WriteMask [_WriteMask]
            Comp [_StencilComp]
            Pass [_StencilOp]
            Fail [_StencilFail]
            ZFail [_StencilZFail]
        }

        CGINCLUDE
		#pragma target 5.0
		#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
        #pragma multi_compile_instancing
        #pragma skip_variants DYNAMICLIGHTMAP_ON LIGHTMAP_ON LIGHTMAP_SHADOW_MIXING DIRLIGHTMAP_COMBINED SHADOWS_SHADOWMASK
		
		#define SCSS_FUR
		#define SCSS_COVERAGE_OUTPUT
        ENDCG

		Pass
		{

			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

			CGPROGRAM

			#ifndef UNITY_PASS_FORWARDBASE
			#define UNITY_PASS_FORWARDBASE
			#endif

			#pragma require geometry

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog
			#pragma multi_compile _ UNITY_HDR_ON
			#pragma multi_compile _ VERTEXLIGHT_ON

			// Needs to be global for Unity reasons
			#pragma shader_feature _ _EMISSION
			#pragma shader_feature_local _ _EMISSION_2ND

			#pragma shader_feature_local _ _DETAIL_MULX2
			#pragma shader_feature_local _ _METALLICGLOSSMAP _SPECGLOSSMAP
			#pragma shader_feature_local _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local _ _SPECULARHIGHLIGHTS_OFF
			#pragma shader_feature_local _ _GLOSSYREFLECTIONS_OFF		
			#pragma shader_feature_local _ _SUNDISK_NONE		
			#pragma shader_feature_local _ _BACKFACE
			#pragma shader_feature_local _ _AUDIOLINK
			#pragma shader_feature_local _ _CONTACTSHADOWS
			
			#include "SCSS_Core.cginc"

			#pragma vertex vert
			#pragma geometry geom_fur
			#pragma fragment frag

			#include "SCSS_Forward.cginc"

			ENDCG
		}


		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			Blend [_SrcBlend] One, Zero One

			CGPROGRAM

			#ifndef UNITY_PASS_FORWARDADD
			#define UNITY_PASS_FORWARDADD
			#endif 

			#pragma require geometry

			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog
			#pragma multi_compile _ UNITY_HDR_ON
			
			#pragma shader_feature_local _ _DETAIL_MULX2
			#pragma shader_feature_local _ _METALLICGLOSSMAP _SPECGLOSSMAP
			#pragma shader_feature_local _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
			#pragma shader_feature_local _ _SPECULARHIGHLIGHTS_OFF
			#pragma shader_feature_local _ _GLOSSYREFLECTIONS_OFF
			#pragma shader_feature_local _ _SUNDISK_NONE			
			#pragma shader_feature_local _ _BACKFACE
			#pragma shader_feature_local _ _CONTACTSHADOWS

			#include "SCSS_Core.cginc"

			#pragma vertex vert
			#pragma geometry geom_fur
			#pragma fragment frag

			#include "SCSS_Forward.cginc"

			ENDCG
		}

		Pass
		{
			Name "SHADOW_CASTER"
			Tags{ "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual
            Cull[_CullMode]

			AlphaToMask Off

			CGPROGRAM

			#ifndef UNITY_PASS_SHADOWCASTER
			#define UNITY_PASS_SHADOWCASTER
			#endif 
			
			#pragma multi_compile_shadowcaster
			
			#pragma shader_feature_local _ _METALLICGLOSSMAP _SPECGLOSSMAP
			
			#include "SCSS_Shadows.cginc"

			#pragma vertex vertShadowCaster
			#pragma fragment fragShadowCaster
			ENDCG
		}
	}
	FallBack "Silent's Cel Shading/Lightramp"
	CustomEditor "SilentCelShading.Unity.Inspector"
}