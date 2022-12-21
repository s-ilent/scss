#ifndef SCSS_ATTRIBUTES_INCLUDED
#define SCSS_ATTRIBUTES_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"

struct VertexOutput
{
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO

	UNITY_POSITION(pos); // UnityCG macro specified name. Technically "positionCS"
	fixed4 color : COLOR0_centroid;
	float4 uvPack0 : TEXCOORD0;
	float4 uvPack1 : TEXCOORD1;
	float4 posWorld : TEXCOORD2;
    float4 tangentToWorldAndPackedData[3] : TEXCOORD3;    // [3x3:tangentToWorld | 1x3: normal]

	float4 vertex : VERTEX; // UnityCG macro specified name. Technically "positionOS"

	#if defined(VERTEXLIGHT_ON)
	half4 vertexLight : TEXCOORD6;
	#endif

	half4 extraData : EXTRA_DATA;

	// Pass-through the shadow coordinates if this pass has shadows.
	// Note the workaround for UNITY_SHADOW_COORDS issue. 
	#if defined(USING_SHADOWS_UNITY) && defined(UNITY_SHADOW_COORDS)
	UNITY_SHADOW_COORDS(8)
	#endif

	// Pass-through the fog coordinates if this pass has fog.
	#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
	UNITY_FOG_COORDS(9)
	#endif
};

struct VertexInputShadowCaster
{
    float4 vertex   : POSITION;
    float3 normal   : NORMAL;
    float2 uv0      : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

#ifdef SCSS_USE_SHADOW_OUTPUT_STRUCT
struct VertexOutputShadowCaster
{
    V2F_SHADOW_CASTER_NOPOS
    #if defined(SCSS_USE_SHADOW_UVS)
        float2 tex : TEXCOORD1;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
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