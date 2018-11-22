Shader "CubedParadox/Flat Lit Toon (Silent)"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_ColorMask("ColorMask", 2D) = "black" {}
		_Shadow("Shadow Mask Power", Range(0, 1)) = 0.5
		_ShadowLift("Shadow Offset", Range(0, 1)) = 0.0
		_IndirectLightingBoost("Indirect Lighting Boost", Range(0, 1)) = 0.0
		_ShadowMask("ShadowMask", 2D) = "white" {}
		_Ramp ("Lighting Ramp", 2D) = "white" {}
		_outline_width("outline_width", Float) = 0.2
		_outline_color("outline_color", Color) = (0.5,0.5,0.5,1)
		_outline_tint("outline_tint", Range(0, 1)) = 0.5
		_EmissionMap("Emission Map", 2D) = "white" {}
		[HDR]_EmissionColor("Emission Color", Color) = (0,0,0,1)
		[HDR]_CustomFresnelColor("Emissive Fresnel Color", Color) = (0,0,0,1)
		_SpecularMap ("Specular Map", 2D) = "black" {}
		_SpecularDetailMask ("Specular Detail Mask", 2D) = "white" {}
		_SpecularDetailStrength ("Specular Detail Strength", Range(0, 1)) = 1.0
		[Toggle(_ENERGY_CONSERVE)] _UseEnergyConservation ("Energy Conservation", Float) = 0.0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5
		_Anisotropy("Anisotropy", Range(-1,1)) = 0.8
		[Toggle]_UseFresnel ("Use Fresnel", Float) = 0.0
		_FresnelWidth ("Fresnel Strength", Range(0, 20)) = .5
		_FresnelStrength ("Fresnel Softness", Range(0.1, 0.9999)) = 0.5
		[HDR]_FresnelTint("Fresnel Tint", Color) = (1,1,1,1)
		_BumpMap("BumpMap", 2D) = "bump" {}
		_Cutoff("Alpha cutoff", Range(0,1)) = 0.5
		[HideInInspector] _OutlineMode("__outline_mode", Float) = 0.0
		[Toggle(_MATCAP)] _UseMatcap ("Use Matcap", Float) = 0.0
		_AdditiveMatcap("AdditiveMatcapTex", 2D) = "black" {}
		_AdditiveMatcapStrength("Additive Matcap Strength", Range(0, 2)) = 1.0
		_MultiplyMatcap("MultiplyMatcapTex", 2D) = "white" {}
		_MultiplyMatcapStrength("Multiply Matcap Strength", Range(0, 2)) = 1.0
		_MatcapMask("Matcap Mask", 2D) = "white" {}
		[Toggle(_LIGHTRAMP_VERTICAL)] _UseVerticalLightramp ("Use Vertical Lightramp", Float) = 0.0
		[Toggle(_METALLIC)] _UseMetallic ("Use Metallic", Float) = 0.0
		[Enum(SpecularType)] _SpecularType ("Specular Type", Float) = 0.0
		[Toggle(_SPECULAR_DETAIL)] _UseSpecularDetailMask ("Use Specular Detail Mask", Float) = 0.0
		[Enum(LightingCalculationType)] _LightingCalculationType ("Lighting Calculation Type", Float) = 0.0
		[Toggle(_SUBSURFACE)] _UseSubsurfaceScattering ("Use Subsurface Scattering", Float) = 0.0
		_ThicknessMap("Thickness Map", 2D) = "black" {}
		[Toggle]_ThicknessMapInvert("Invert Thickness", Float) = 0.0
		_ThicknessMapPower ("Thickness Map Power", Range(0.01, 10)) = 1
		_SSSCol ("Scattering Color", Color) = (1,1,1,1)
		_SSSIntensity ("Scattering Intensity", Range(0, 10)) = 1
		_SSSPow ("Scattering Power", Range(0.01, 10)) = 1
		_SSSDist ("Scattering Distance", Range(0, 10)) = 1


        // Advanced options.
        [Enum(RenderingMode)] _Mode("Rendering Mode", Float) = 0                                     // "Opaque"
        [Enum(CustomRenderingMode)] _CustomMode("Mode", Float) = 0                                   // "Opaque"
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source Blend", Float) = 1                 // "One"
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination Blend", Float) = 0            // "Zero"
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp("Blend Operation", Float) = 0                 // "Add"
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("Depth Test", Float) = 4                // "LessEqual"
        [Enum(DepthWrite)] _ZWrite("Depth Write", Float) = 1                                         // "On"
        [Enum(UnityEngine.Rendering.ColorWriteMask)] _ColorWriteMask("Color Write Mask", Float) = 15 // "All"
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 2                     // "Back"
        _RenderQueueOverride("Render Queue Override", Range(-1.0, 5000)) = -1
	}

	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
		}

		Pass
		{

			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

            Blend[_SrcBlend][_DstBlend]
            BlendOp[_BlendOp]
            ZTest[_ZTest]
            ZWrite[_ZWrite]
            Cull[_CullMode]
            ColorMask[_ColorWriteMask]

			CGPROGRAM
			#include "FlatLitToonCore.cginc"

			#pragma shader_feature NO_OUTLINE TINTED_OUTLINE COLORED_OUTLINE
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature _ENERGY_CONSERVE
			#pragma shader_feature _METALLIC
			#pragma shader_feature _SPECULAR_DETAIL
			#pragma shader_feature _ _SPECULAR_GGX _SPECULAR_CHARLIE _SPECULAR_GGX_ANISO
			#pragma shader_feature _MATCAP
			#pragma shader_feature _LIGHTRAMP_VERTICAL
			#pragma shader_feature _LIGHTINGTYPE_CUBED _LIGHTINGTYPE_ARKTOON _LIGHTINGTYPE_STANDARD
			#pragma shader_feature _SUBSURFACE
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

			#if defined(_SPECULAR_GGX) | defined(_SPECULAR_CHARLIE) | defined(_SPECULAR_GGX_ANISO)
			#define USE_SPECULAR true
			#endif

			#include "FlatLitToonForward.cginc"

			ENDCG
		}


		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			Blend [_SrcBlend] One

			CGPROGRAM
			#pragma shader_feature NO_OUTLINE TINTED_OUTLINE COLORED_OUTLINE
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature _ENERGY_CONSERVE
			#pragma shader_feature _METALLIC
			#pragma shader_feature _SPECULAR_DETAIL
			#pragma shader_feature _ _SPECULAR_GGX _SPECULAR_CHARLIE _SPECULAR_GGX_ANISO
			#pragma shader_feature _SUBSURFACE
			#include "FlatLitToonCore.cginc"
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog

			#if defined(_SPECULAR_GGX) | defined(_SPECULAR_CHARLIE) | defined(_SPECULAR_GGX_ANISO)
			#define USE_SPECULAR true
			#endif

			#include "FlatLitToonForwardDelta.cginc"

			ENDCG
		}

		Pass
		{
			Name "SHADOW_CASTER"
			Tags{ "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual

			CGPROGRAM
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#include "FlatLitToonShadows.cginc"
			
			#pragma multi_compile_shadowcaster

			#pragma vertex vertShadowCaster
			#pragma fragment fragShadowCaster
			ENDCG
		}
	}
	FallBack "Diffuse"
	CustomEditor "FlatLitToonS.Unity.Inspector"
}