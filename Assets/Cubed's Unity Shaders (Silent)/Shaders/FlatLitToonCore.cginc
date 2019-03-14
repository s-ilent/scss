// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

#ifndef FLAT_LIT_TOON_CORE_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"

uniform sampler2D _MainTex; uniform float4 _MainTex_ST; uniform float4 _MainTex_TexelSize;
uniform sampler2D _ColorMask; uniform float4 _ColorMask_ST;
uniform sampler2D _BumpMap; uniform float4 _BumpMap_ST;
uniform sampler2D _DetailNormalMap; uniform float4 _DetailNormalMap_ST;
uniform sampler2D _EmissionMap; uniform float4 _EmissionMap_ST;
uniform sampler2D _SpecularMap; uniform float4 _SpecularMap_ST;
uniform sampler2D _Ramp; uniform float4 _Ramp_ST;
uniform sampler2D _ShadowMask; uniform float4 _ShadowMask_ST;

uniform float4 _Color;
uniform float _DetailNormalMapScale;
uniform float _Shadow;
uniform float _ShadowLift;
uniform float _IndirectLightingBoost;
uniform float _Cutoff;
uniform float _AlphaSharp;
uniform float _Smoothness;
uniform float _Anisotropy;
uniform float _FresnelWidth;
uniform float _FresnelStrength;
uniform float4 _FresnelTint;
uniform float4 _EmissionColor;
uniform float4 _CustomFresnelColor;
uniform float _outline_width;
uniform float4 _outline_color;

uniform float _UseFresnel;
uniform float _UseEnergyConservation;
uniform float _LightRampType;
uniform float _UseMetallic;
uniform float _ShadowMaskType;
uniform float _SpecularType;
uniform float _LightingCalculationType;

uniform float _UseMatcap;
uniform sampler2D _AdditiveMatcap; uniform float4 _AdditiveMatcap_ST; 
uniform float _AdditiveMatcapStrength;
uniform sampler2D _MultiplyMatcap; uniform float4 _MultiplyMatcap_ST; 
uniform float _MultiplyMatcapStrength;
uniform sampler2D _MatcapMask; uniform float4 _MatcapMask_ST; 

uniform sampler2D _SpecularDetailMask; uniform float4 _SpecularDetailMask_ST;
uniform float _SpecularDetailStrength;

uniform float _UseSubsurfaceScattering;
uniform sampler2D _ThicknessMap; uniform float4 _ThicknessMap_ST;
uniform float _ThicknessMapPower;
uniform float _ThicknessMapInvert;
uniform float3 _SSSCol;
uniform float _SSSIntensity;
uniform float _SSSPow;
uniform float _SSSDist;
uniform float _SSSAmbient;

uniform float4 _LightSkew;
uniform float _PixelSampleMode;

static const float3 grayscale_vector = 1.0/3.0; 
// When operating in non-perceptual space, treat greyscale as an equal distribution.
// Previously float3(0, 0.3823529, 0.01845836);

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
	float4 pos : CLIP_POS;
	UNITY_SHADOW_COORDS(6)
	UNITY_FOG_COORDS(7)

	//Since ifdef won't work in geom we must always pass this
	half4 vertexLight : TEXCOORD8;
};

// Shade4PointLights from UnityCG.cginc but only returns their attenuation.
float4 Shade4PointLightsAtten (
    float4 lightPosX, float4 lightPosY, float4 lightPosZ,
    float4 lightAttenSq,
    float3 pos, float3 normal)
{
    // to light vectors
    float4 toLightX = lightPosX - pos.x;
    float4 toLightY = lightPosY - pos.y;
    float4 toLightZ = lightPosZ - pos.z;
    // squared lengths
    float4 lengthSq = 0;
    lengthSq += toLightX * toLightX;
    lengthSq += toLightY * toLightY;
    lengthSq += toLightZ * toLightZ;
    // don't produce NaNs if some vertex position overlaps with the light
    lengthSq = max(lengthSq, 0.000001);

    // NdotL
    float4 ndotl = 0;
    ndotl += toLightX * normal.x;
    ndotl += toLightY * normal.y;
    ndotl += toLightZ * normal.z;
    // correct NdotL
    float4 corr = rsqrt(lengthSq);
    ndotl = max (float4(0,0,0,0), ndotl * corr);
    // attenuation
    float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
    float4 diff = ndotl * atten;
    return diff;
}

// Based on Standard Shader's forwardbase vertex lighting calculations in VertexGIForward
// This revision does not pass the light values themselves, but only their attenuation.
inline half4 VertexLightContribution(float3 posWorld, half3 normalWorld)
{
	half4 vertexLight = 0;

	// Static lightmaps
	#ifdef LIGHTMAP_ON
		return 0;
	#elif UNITY_SHOULD_SAMPLE_SH
		#ifdef VERTEXLIGHT_ON
			// Approximated illumination from non-important point lights
			vertexLight = Shade4PointLightsAtten(
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_4LightAtten0, posWorld, normalWorld);
		#endif
		// (Shouldn't SH already be handled in the main shader?)
		//vertexLight = ShadeSHPerVertex(normalWorld, vertexLight);
	#endif

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

	#if (UNITY_VERSION<600)
	TRANSFER_SHADOW(o);
	#else
	UNITY_TRANSFER_SHADOW(o, v.texcoord1);
	#endif

	UNITY_TRANSFER_FOG(o, o.pos);
#if VERTEXLIGHT_ON
	o.vertexLight = VertexLightContribution(o.posWorld, o.normalDir);
	// As suggested by netri.
	// https://github.com/cubedparadox/Cubeds-Unity-Shaders/pull/40
	//o.vertexLight = VertexLightContribution(o.posWorld, UnityObjectToWorldNormal(normalize(v.vertex)));
#else
	o.vertexLight = 0;
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
	float4 col : COLOR;
	bool is_outline : IS_OUTLINE;
	UNITY_SHADOW_COORDS(6)
	UNITY_FOG_COORDS(7)

	//Since ifdef won't work in frag we must always pass this
	half4 vertexLight : TEXCOORD8;
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
		float _outline_width_var = _outline_width * .01; // Convert to cm
		// Scale outlines relative to the distance from the camera. Outlines close up look ugly in VR because
		// they can have holes, being shells. This is also why it is clamped to not make them bigger.
		// That looks good at a distance, but not perfect. 
		_outline_width_var *= min(distance(o.posWorld,_WorldSpaceCameraPos)*4, 1); 

		o.pos = UnityObjectToClipPos(IN[i].vertex + normalize(IN[i].normal) * _outline_width_var);
		//o.pos = UnityObjectToClipPos(IN[i].vertex + normalize(IN[i].normal) * (_outline_width * .01));

		// Pass-through the shadow coordinates if this pass has shadows.
		#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE) || (defined (UNITY_LIGHT_PROBE_PROXY_VOLUME) && UNITY_VERSION<600) || defined(DIRECTIONAL_COOKIE)
		o._ShadowCoord = IN[i]._ShadowCoord;
		#endif

		// Pass-through the fog coordinates if this pass has fog.
		#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
		o.fogCoord = IN[i].fogCoord;
		#endif

		// Pass-through the vertex light information.
		o.vertexLight = IN[i].vertexLight;

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
		#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE) || (defined (UNITY_LIGHT_PROBE_PROXY_VOLUME) && UNITY_VERSION<600)
		o._ShadowCoord = IN[ii]._ShadowCoord;
		#endif

		// Pass-through the fog coordinates if this pass has fog.
		#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
		o.fogCoord = IN[ii].fogCoord;
		#endif

		// Pass-through the vertex light information.
		o.vertexLight = IN[ii].vertexLight;

		tristream.Append(o);
	}

	tristream.RestartStrip();
}

 
// Hack suggested by ACIIL to reduce overbrightening
// Reducing the intensity of the incoming indirect light by two
// In testing this, I noticed the intensity of directly lit objects 
// isn't the same as with standard shader comparing by eye.
// Disabled for review.
inline float3 ShadeSH9_mod(half4 normalDirection)
{
	return ShadeSH9(normalDirection);
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
		// specular = tex2D(_Ramp, saturate(float2( specular, 0.0)) );
	return specular * specColor; // Return specular colour multiplied by specular  
	//return specular * specColor * nDotL; // Return specular colour multiplied by specular  
}

float interleaved_gradient(float2 uv : SV_POSITION) : SV_Target
{
	float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
	return frac(magic.z * frac(dot(uv, magic.xy)));
}

float Dither17(float2 Pos, float FrameIndexMod4)
{
    // 3 scalar float ALU (1 mul, 2 mad, 1 frac)
    return frac(dot(float3(Pos.xy, FrameIndexMod4), uint3(2, 7, 23) / 17.0f));
}

float max3 (float3 x) 
{
	return max(x.x, max(x.y, x.z));
}

// BRDF based on implementation in Filament.
// https://github.com/google/filament

float D_Ashikhmin(float linearRoughness, float NoH) {
    // Ashikhmin 2007, "Distribution-based BRDFs"
	float a2 = linearRoughness * linearRoughness;
	float cos2h = NoH * NoH;
	float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
	float sin4h = sin2h * sin2h;
	float cot2 = -cos2h / (a2 * sin2h);
	return 1.0 / (UNITY_PI * (4.0 * a2 + 1.0) * sin4h) * (4.0 * exp(cot2) + sin4h);
}

float D_Charlie(float linearRoughness, float NoH) {
    // Estevez and Kulla 2017, "Production Friendly Microfacet Sheen BRDF"
    float invAlpha  = 1.0 / linearRoughness;
    float cos2h = NoH * NoH;
    float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
    return (2.0 + invAlpha) * pow(sin2h, invAlpha * 0.5) / (2.0 * UNITY_PI);
}

float V_Neubelt(float NoV, float NoL) {
    // Neubelt and Pettineo 2013, "Crafting a Next-gen Material Pipeline for The Order: 1886"
    return saturate(1.0 / (4.0 * (NoL + NoV - NoL * NoV)));
}

float D_GGX_Anisotropic(float NoH, const float3 h,
        const float3 t, const float3 b, float at, float ab) {
    float ToH = dot(t, h);
    float BoH = dot(b, h);
    float a2 = at * ab;
    float3 v = float3(ab * ToH, at * BoH, a2 * NoH);
    float v2 = dot(v, v);
    float w2 = a2 / v2;
    return a2 * w2 * w2 * UNITY_INV_PI;
}

float V_SmithGGXCorrelated_Anisotropic(float at, float ab, float ToV, float BoV,
        float ToL, float BoL, float NoV, float NoL) {
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    float lambdaV = NoL * length(float3(at * ToV, ab * BoV, NoV));
    float lambdaL = NoV * length(float3(at * ToL, ab * BoL, NoL));
    float v = 0.5 / (lambdaV + lambdaL + 1e-7f);
    return v;
}

UnityGI GetUnityGI(float3 lightColor, float3 lightDirection, float3 normalDirection,float3 viewDirection, 
float3 viewReflectDirection, float attenuation, float roughness, float3 worldPos){
    UnityLight light;
    light.color = lightColor;
    light.dir = lightDirection;
    light.ndotl = max(0.0h,dot( normalDirection, lightDirection));
    UnityGIInput d;
    d.light = light;
    d.worldPos = worldPos;
    d.worldViewDir = viewDirection;
    d.atten = attenuation;
    d.ambient = 0.0h;
    d.boxMax[0] = unity_SpecCube0_BoxMax;
    d.boxMin[0] = unity_SpecCube0_BoxMin;
    d.probePosition[0] = unity_SpecCube0_ProbePosition;
    d.probeHDR[0] = unity_SpecCube0_HDR;
    d.boxMax[1] = unity_SpecCube1_BoxMax;
    d.boxMin[1] = unity_SpecCube1_BoxMin;
    d.probePosition[1] = unity_SpecCube1_ProbePosition;
    d.probeHDR[1] = unity_SpecCube1_HDR;
    Unity_GlossyEnvironmentData ugls_en_data;
    ugls_en_data.roughness = roughness;
    ugls_en_data.reflUVW = viewReflectDirection;
    UnityGI gi = UnityGlobalIllumination(d, 1.0h, normalDirection, ugls_en_data );
    return gi;
}

// Get the maximum SH contribution
// synqark's Arktoon shader's shading method
half3 GetSHLength ()
{
    half3 x, x1;
    x.r = length(unity_SHAr);
    x.g = length(unity_SHAg);
    x.b = length(unity_SHAb);
    x1.r = length(unity_SHBr);
    x1.g = length(unity_SHBg);
    x1.b = length(unity_SHBb);
    return x + x1;
}

//SSS method from GDC 2011 conference by Colin Barre-Bresebois & Marc Bouchard and modified by Xiexe
float3 getSubsurfaceScatteringLight (float3 lightColor, float3 lightDirection, float3 normalDirection, float3 viewDirection, 
	float attenuation, float3 thickness, float3 indirectLight)
{
	float3 vSSLight = lightDirection + normalDirection * _SSSDist; // Distortion
	float3 vdotSS = pow(saturate(dot(viewDirection, -vSSLight)), _SSSPow) 
		* _SSSIntensity; 
	
	return lerp(1, attenuation, float(any(_WorldSpaceLightPos0.xyz))) 
				* (vdotSS + _SSSAmbient) * abs(_ThicknessMapInvert-thickness)
				* (lightColor + indirectLight) * _SSSCol;
				
}

float3 sampleRampWithOptions(float rampPosition) 
{
	if (_LightRampType == 2) // None
	{
		float shadeWidth = max(fwidth(rampPosition), 0.00);

		const float shadeOffset = (UNITY_PI/10.0); 
		float lightContribution = smoothstep(shadeOffset-shadeWidth, shadeOffset+shadeWidth, frac(rampPosition)); 
		lightContribution += floor(rampPosition);
		return lightContribution;
	}
	else {
		float2 rampUV = float2(rampPosition*(1-_LightRampType), rampPosition*_LightRampType);
		return tex2D(_Ramp, saturate(rampUV));

	}
}

inline float3 BlendNormalsPD(float3 n1, float3 n2) {
	return normalize(float3(n1.xy*n2.z + n2.xy*n1.z, n1.z*n2.z));
}

// Based on NormalInTangentSpace from UnityStandardInput
inline float3 NormalInTangentSpace(float2 texcoords, half mask)
{
	float3 normalTangent = UnpackNormal(tex2D(_BumpMap,TRANSFORM_TEX(texcoords.xy, _MainTex)));
#if _DETAIL 
    half3 detailNormalTangent = UnpackScaleNormal(tex2D (_DetailNormalMap, TRANSFORM_TEX(texcoords.xy, _DetailNormalMap)), _DetailNormalMapScale);
    #if _DETAIL_LERP
        normalTangent = lerp(
            normalTangent,
            detailNormalTangent,
            mask);
    #else
        normalTangent = lerp(
            normalTangent,
            BlendNormalsPD(normalTangent, detailNormalTangent),
            mask);
    #endif
#endif

    return normalTangent;
}

float2 sharpSample( float2 texResolution , float2 p )
{
	p = p*texResolution;
	float2 i = floor(p);
	p = i + smoothstep(0, max(0.0001, fwidth(p)), frac(p));
	p = (p - 0.5)/texResolution;
	return p;
}

#endif