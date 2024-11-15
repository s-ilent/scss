#ifndef SCSS_ATTRIBUTES_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_ATTRIBUTES_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"

// Testing using a lower precision format for the vertex data. 
// This could increase performance in situations where there is a lot of GPU load,`
// at the cost of some GPU load.

#if 1
#define v_half  min16float
#define v_half2 min16float2
#define v_half3 min16float3
#define v_half4 min16float4
#else
#define v_half  half 
#define v_half2 half2
#define v_half3 half3
#define v_half4 half4
#endif

struct appdata_full_local
{
    v_half4 vertex : POSITION;
    v_half4 tangent : TANGENT;
    v_half3 normal : NORMAL;
    v_half4 texcoord : TEXCOORD0;
    v_half4 texcoord1 : TEXCOORD1;
    v_half4 texcoord2 : TEXCOORD2;
    v_half4 texcoord3 : TEXCOORD3;
    v_half4 color : COLOR;
	uint vid : SV_VertexID;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput
{
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO

	v_half4 pos : SV_POSITION; // UnityCG macro specified name. Technically "positionCS"
	v_half4 color : COLOR0_centroid;
	v_half4 uvPack0 : TEXCOORD0;
	v_half4 uvPack1 : TEXCOORD1;
	float4 worldPos : TEXCOORD2;
    v_half4 tangentToWorldAndPackedData[3] : TEXCOORD3;    // [3x3:tangentToWorld | 1x3: outlineDir]

	#if defined(VERTEXLIGHT_ON)
	v_half4 vertexLight : TEXCOORD6;
	#endif

	v_half4 extraData : EXTRA_DATA;

	// Pass-through the shadow coordinates if this pass has shadows.
	// Note the workaround for UNITY_SHADOW_COORDS issue. 
	#if defined(USING_SHADOWS_UNITY) && defined(UNITY_SHADOW_COORDS)
	UNITY_SHADOW_COORDS(8)
	#endif
};

struct VertexInputShadowCaster
{
    v_half4 vertex   : POSITION;
    v_half3 normal   : NORMAL;
    // Required for inventory
	v_half2 texcoord  : TEXCOORD0;
	#if defined(SCSS_USE_SHADOW_UVS)
		v_half2 texcoord1 : TEXCOORD1;
		v_half2 texcoord2 : TEXCOORD2;
		v_half2 texcoord3 : TEXCOORD3;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#ifdef SCSS_USE_SHADOW_OUTPUT_STRUCT
struct VertexOutputShadowCaster
{
    V2F_SHADOW_CASTER_NOPOS
    #if defined(SCSS_USE_SHADOW_UVS)
		v_half4 uvPack0 : TEXCOORD0;
		v_half4 uvPack1 : TEXCOORD1;
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
	float4 color : SV_Target;
	uint coverage : SV_Coverage;
};

#endif // SCSS_ATTRIBUTES_INCLUDED