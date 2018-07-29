// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

#ifndef FLAT_LIT_TOON_CORE_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
uniform sampler2D _ColorMask; uniform float4 _ColorMask_ST;
uniform sampler2D _ShadowMask; uniform float4 _ShadowMask_ST;
uniform sampler2D _LightingRamp; uniform float4 _LightingRamp_ST;
uniform sampler2D _EmissionMap; uniform float4 _EmissionMap_ST;
uniform sampler2D _SpecularMap; uniform float4 _SpecularMap_ST;
uniform sampler2D _BumpMap; uniform float4 _BumpMap_ST;

uniform float4 _Color;
uniform float _Shadow;
uniform float _ShadowLift;
uniform float _IndirectLightingBoost;
uniform float _Cutoff;
//uniform float _Fresnel;
uniform float _Smoothness;
uniform float _SpecularMult;
uniform float _FresnelWidth;
uniform float _FresnelStrength;
uniform float4 _EmissionColor;
uniform float4 _CustomFresnelColor;
uniform float _outline_width;
uniform float4 _outline_color;
uniform sampler2D _AdditiveMatcap; uniform sampler2D _AdditiveMatcap_ST; 
uniform sampler2D _MultiplyMatcap; uniform sampler2D _MultiplyMatcap_ST; 

static const float3 grayscale_vector = float3(0, 0.3823529, 0.01845836);

struct v2g
{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float4 posWorld : TEXCOORD2;
	float3 normalDir : TEXCOORD3;
	float3 tangentDir : TEXCOORD4;
	float3 bitangentDir : TEXCOORD5;
	float2 matcap : TEXCOORD9;
	float4 pos : CLIP_POS;
	SHADOW_COORDS(6)
	UNITY_FOG_COORDS(7)

	//Since ifdef won't work in geom we must always pass this
	half3 vertexLight : TEXCOORD8;
};

// HelloKitty's vertex lighting implementation. See:
// https://github.com/cubedparadox/Cubeds-Unity-Shaders/pull/40
//Based on Standard Shader's forwardbase vertex lighting calculations in VertexGIForward
inline half3 VertexLightContribution(float3 posWorld, half3 normalWorld)
{
	half3 vertexLight = 0;

	// Static lightmaps
	#ifdef LIGHTMAP_ON
		return 0;
	#elif UNITY_SHOULD_SAMPLE_SH
		#ifdef VERTEXLIGHT_ON
			// Approximated illumination from non-important point lights
			vertexLight = Shade4PointLights(
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
				unity_4LightAtten0, posWorld, normalWorld);
		#endif
		// (Shouldn't SH already be handled in the main shader?)
		// Re-enabled pending evidence of this breaking something. 
		vertexLight = ShadeSHPerVertex(normalWorld, vertexLight);
	#endif

	// Threshold to preserve toon shading image as much as possible. 
	// Which isn't much, because vertexes are interpolated.
	//vertexLight = max(floor(vertexLight+.5), ceil(frac(vertexLight))*.5);

	return vertexLight;
}

v2g vert(appdata_full v) {
	v2g o;
	o.uv0 = v.texcoord;
	o.uv1 = v.texcoord1;
	o.normal = v.normal;
	o.tangent = v.tangent;
	o.normalDir = normalize(UnityObjectToWorldNormal(v.normal));
	o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
	o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
	float4 objPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
	o.posWorld = mul(unity_ObjectToWorld, v.vertex);
	float3 lightColor = _LightColor0.rgb;
	o.vertex = v.vertex;
	o.pos = UnityObjectToClipPos(v.vertex);
	TRANSFER_SHADOW(o);
	UNITY_TRANSFER_FOG(o, o.pos);
#if VERTEXLIGHT_ON
	//o.vertexLight = VertexLightContribution(o.posWorld, o.normal);
	// As suggested by netri.
	// https://github.com/cubedparadox/Cubeds-Unity-Shaders/pull/40
	o.vertexLight = VertexLightContribution(o.posWorld, UnityObjectToWorldNormal(normalize(v.vertex)));
#else
	o.vertexLight = 0;
#endif

#if defined(_MATCAP)
	float3 worldNorm = normalize(unity_WorldToObject[0].xyz * v.normal.x + unity_WorldToObject[1].xyz * v.normal.y + unity_WorldToObject[2].xyz * v.normal.z);
	worldNorm = mul((float3x3)unity_ObjectToWorld, worldNorm);
	o.matcap.xy =  worldNorm * 0.5 + 0.5f;
#else
	o.matcap.xy = 0;
#endif
	return o;
}

struct VertexOutput
{
	float4 pos : SV_POSITION;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float4 posWorld : TEXCOORD2;
	float3 normalDir : TEXCOORD3;
	float3 tangentDir : TEXCOORD4;
	float3 bitangentDir : TEXCOORD5;
	float2 matcap : TEXCOORD9;
	float4 col : COLOR;
	bool is_outline : IS_OUTLINE;
	SHADOW_COORDS(6)
	UNITY_FOG_COORDS(7)

	//Since ifdef won't work in frag we must always pass this
	half3 vertexLight : TEXCOORD8;
};

[maxvertexcount(6)]
void geom(triangle v2g IN[3], inout TriangleStream<VertexOutput> tristream)
{
	VertexOutput o;
	#if !NO_OUTLINE
	for (int i = 2; i >= 0; i--)
	{
		o.pos = UnityObjectToClipPos(IN[i].vertex + normalize(IN[i].normal) * (_outline_width * .01));
		o.uv0 = IN[i].uv0;
		o.uv1 = IN[i].uv1;
		o.col = fixed4( _outline_color.r, _outline_color.g, _outline_color.b, 1);
		o.posWorld = mul(unity_ObjectToWorld, IN[i].vertex);
		o.normalDir = UnityObjectToWorldNormal(IN[i].normal);
		o.tangentDir = IN[i].tangentDir;
		o.bitangentDir = IN[i].bitangentDir;
		o.is_outline = true;
		float _outline_width_var = _outline_width * .01;
		//_outline_width_var *= smoothstep(0.5, 1, distance(o.posWorld,_WorldSpaceCameraPos));
		o.pos = UnityObjectToClipPos(IN[i].vertex + normalize(IN[i].normal) * _outline_width_var);
		//o.pos = UnityObjectToClipPos(IN[i].vertex + normalize(IN[i].normal) * (_outline_width * .01));

		// Pass-through the shadow coordinates if this pass has shadows.
		#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE)
		o._ShadowCoord = IN[i]._ShadowCoord;
		#endif

		// Pass-through the fog coordinates if this pass has shadows.
		#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
		o.fogCoord = IN[i].fogCoord;
		#endif

		// Pass-through the vertex light information.
		o.vertexLight = IN[i].vertexLight;

		o.matcap = IN[i].matcap;

		tristream.Append(o);
	}

	tristream.RestartStrip();
	#endif

	for (int ii = 0; ii < 3; ii++)
	{
		o.pos = UnityObjectToClipPos(IN[ii].vertex);
		o.uv0 = IN[ii].uv0;
		o.uv1 = IN[ii].uv1;
		o.col = fixed4(1., 1., 1., 0.);
		o.posWorld = mul(unity_ObjectToWorld, IN[ii].vertex);
		o.normalDir = UnityObjectToWorldNormal(IN[ii].normal);
		o.tangentDir = IN[ii].tangentDir;
		o.bitangentDir = IN[ii].bitangentDir;
		o.posWorld = mul(unity_ObjectToWorld, IN[ii].vertex); 
		o.is_outline = false;

		// Pass-through the shadow coordinates if this pass has shadows.
		#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE)
		o._ShadowCoord = IN[ii]._ShadowCoord;
		#endif

		// Pass-through the fog coordinates if this pass has shadows.
		#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
		o.fogCoord = IN[ii].fogCoord;
		#endif

		// Pass-through the vertex light information.
		o.vertexLight = IN[ii].vertexLight;

		o.matcap = IN[ii].matcap;

		tristream.Append(o);
	}

	tristream.RestartStrip();
}

 
// Hack suggested by ACIIL to reduce overbrightening
// Reducing the intensity of the incoming indirect light by two
// In testing this, I noticed the intensity of directly lit objects 
// isn't the same as with standard shader comparing by eye.
// Removed for review.
float3 ShadeSH9_mod(half4 normalDirection)
{
	return ShadeSH9(normalDirection);//*.5;
}

float grayscaleSH9(float3 normalDirection)
{
	return dot(ShadeSH9_mod(half4(normalDirection, 1.0)), grayscale_vector);
}

float3 UnitySpecularSimplified(float3 specColor, float smoothness, float2 rlPow4, float3 nDotL )
{
	float LUT_RANGE = 16.0; // must match range in NHxRoughness() function in GeneratedTextures.cpp
	// Lookup texture to save instructions
	float specular = tex2D(unity_NHxRoughness, float2(rlPow4.x, SmoothnessToPerceptualRoughness(smoothness))).UNITY_ATTEN_CHANNEL * LUT_RANGE; 
		// Todo: IFDEF SpecularByLightramp?
		// But it causes issues where, for example, a lightramp with a wide middle section will cause extra
		// brightness in areas where specularity is weak, but present. 
		// specular = tex2D(_LightingRamp, saturate(float2( specular, 0.0)) );
	return specular * specColor; // Return specular colour multiplied by specular  
	//return specular * specColor * nDotL; // Return specular colour multiplied by specular  
}

float interleaved_gradient(float2 uv : SV_POSITION) : SV_Target
{
	float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
	return frac(magic.z * frac(dot(uv, magic.xy)));
}

float max3 (float3 x) 
{
	return max(x.x, max(x.y, x.z));
}

#endif