#ifndef SCSS_ATTRIBUTES_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_ATTRIBUTES_INCLUDED

#if defined(SCSS_IS_URP)
    #include "SCSS_CompatURP.hlsl"
#else
    #include "SCSS_CompatBIRP.hlsl"
#endif

struct appdata_full_local
{
    half4 vertex : POSITION;
    half4 tangent : TANGENT;
    half3 normal : NORMAL;
    half4 texcoord : TEXCOORD0;
    half4 texcoord1 : TEXCOORD1;
    half4 texcoord2 : TEXCOORD2;
    half4 texcoord3 : TEXCOORD3;
    half4 color : COLOR;
	// uint vid : SV_VertexID;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput
{
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO

	float4 pos : SV_POSITION; // UnityCG macro specified name. Technically "positionCS"
	centroid half4 color : COLOR0_centroid;
	half4 uvPack0 : TEXCOORD0;
	half4 uvPack1 : TEXCOORD1;
	float4 worldPos : TEXCOORD2;
    half4 tangentToWorldAndPackedData[3] : TEXCOORD3;    // [3x3:tangentToWorld | 1x3: outlineDir]

	half4 extraData : EXTRA_DATA;

	// Pass-through the shadow coordinates if this pass has shadows.
	// Note the workaround for UNITY_SHADOW_COORDS issue.
	#if defined(USING_SHADOWS_UNITY) && defined(UNITY_SHADOW_COORDS)
	UNITY_SHADOW_COORDS(8)
	#endif
};

struct VertexInputShadowCaster
{
    half4 vertex   : POSITION;
    half3 normal   : NORMAL;
    // Required for inventory
	half2 texcoord  : TEXCOORD0;
	#if defined(SCSS_USE_SHADOW_UVS)
		half2 texcoord1 : TEXCOORD1;
		half2 texcoord2 : TEXCOORD2;
		half2 texcoord3 : TEXCOORD3;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#ifdef SCSS_USE_SHADOW_OUTPUT_STRUCT
struct VertexOutputShadowCaster
{
    V2F_SHADOW_CASTER_NOPOS
    #if defined(SCSS_USE_SHADOW_UVS)
		half4 uvPack0 : TEXCOORD0;
		half4 uvPack1 : TEXCOORD1;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
#endif

#ifdef SCSS_USE_STEREO_SHADOW_OUTPUT_STRUCT
struct VertexOutputStereoShadowCaster
{
    UNITY_VERTEX_OUTPUT_STEREO
};
#endif


struct FragmentInput
{
	VertexOutput i;
	uint facing : SV_IsFrontFace;
};

struct FragmentOutput
{
	half4 color : SV_Target;
	uint coverage : SV_Coverage;
};

#endif // SCSS_ATTRIBUTES_INCLUDED
