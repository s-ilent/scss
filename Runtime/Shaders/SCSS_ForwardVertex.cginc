#ifndef SCSS_FORWARD_VERTEX_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_FORWARD_VERTEX_INCLUDED

// Only compile vertex functions for vert/geom shader, which should make compilation a bit faster.
#if (defined(SHADER_STAGE_VERTEX) || defined(SHADER_STAGE_GEOMETRY))

#include "SCSS_Attributes.cginc"

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
    ndotl = corr * (ndotl * 0.5 + 0.5); // Match with Forward for light ramp sampling
    ndotl = max (float4(0,0,0,0), ndotl);
    // attenuation
    // Fixes popin. Thanks, d4rkplayer!
    float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
	float4 atten2 = saturate(1 - (lengthSq * lightAttenSq / 25));
	atten = min(atten, atten2 * atten2);

    float4 diff = ndotl * atten;
    #if defined(SCSS_UNIMPORTANT_LIGHTS_FRAGMENT)
    return atten;
    #else
    return diff;
    #endif
}

// Based on Standard Shader's forwardbase vertex lighting calculations in VertexGIForward
// This revision does not pass the light values themselves, but only their attenuation.
half4 VertexLightContribution(float3 posWorld, half3 normalWorld)
{
	half4 vertexLight = 0;

	// Static lightmapped materials are not allowed to have vertex lights.
	#ifdef LIGHTMAP_ON
		return 0;
	#elif UNITY_SHOULD_SAMPLE_SH
		#ifdef VERTEXLIGHT_ON
			// Approximated illumination from non-important point lights
			vertexLight = Shade4PointLightsAtten(
				unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
				unity_4LightAtten0, posWorld, normalWorld);
		#endif
	#endif

	return vertexLight;
}

inline float4 ObjectToClipPosRelative(float3 pos)
{
	float4x4 matrixM = unity_ObjectToWorld;
	float4x4 matrixV = UNITY_MATRIX_V; // todo: verify
	matrixM._m03_m13_m23 -= _WorldSpaceCameraPos.xyz;
	matrixV._m03_m13_m23 = 0.0;

	float3 posWS = mul(matrixM, float4(pos, 1.0)).xyz;

#if defined(STEREO_CUBEMAP_RENDER_ON)
    float3 offset = ODSOffset(posWS, unity_HalfStereoSeparation.x);
#else
	float3 offset = 0;
#endif

	float3 posVS = mul(matrixV, float4(posWS+offset, 1.0)).xyz;

	float4 posCS = mul(UNITY_MATRIX_P, float4(posVS, 1.0));

	return posCS;
}

inline float4 WorldToClipPosRelative(float3 posWS)
{
	float4x4 matrixM = unity_ObjectToWorld;
	float4x4 matrixV = UNITY_MATRIX_V; // todo: verify
	matrixM._m03_m13_m23 -= _WorldSpaceCameraPos.xyz;
	matrixV._m03_m13_m23 = 0.0;

	posWS -= _WorldSpaceCameraPos.xyz;
	//float3 posWS = mul(matrixM, float4(pos, 1.0)).xyz;
	float3 posVS = mul(matrixV, float4(posWS, 1.0)).xyz;

	float4 posCS = mul(UNITY_MATRIX_P, float4(posVS, 1.0));

	return posCS;
}

VertexOutput vert(appdata_full_local v) {
	VertexOutput o = (VertexOutput)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_OUTPUT(VertexOutput, o);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	#if (SCSS_CAMERA_RELATIVE_VERTEX)
	o.pos = ObjectToClipPosRelative(v.vertex);
	#else
	o.pos = UnityObjectToClipPos(v.vertex);
	#endif

	SCSS_AnimData anim = initialiseAnimParam();

	float4 uvPack0 = float4(v.texcoord.xy, v.texcoord1.xy);
	float4 uvPack1 = float4(v.texcoord2.xy, v.texcoord3.xy);
	uvPack0.xy = AnimateTexcoords(uvPack0.xy, anim);
	o.uvPack0 = uvPack0;
	o.uvPack1 = uvPack1;

	// Calculate the transformed texture coordinates so that the
	// outline mask matches with the scale/offset of the main texture.
	SCSS_TexCoords postTexcoords = initialiseTexCoords(uvPack0, uvPack1);

	// Object-space normal from vertex
	float3 normalOS = v.normal;

	float3 normalDir = UnityObjectToWorldNormal(v.normal);
	float3 tangentDir = UnityObjectToWorldDir(v.tangent.xyz);
    half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
	float3 bitangentDir = cross(normalDir, tangentDir) * tangentSign;

	o.tangentToWorldAndPackedData[0].xyz = tangentDir;
	o.tangentToWorldAndPackedData[1].xyz = bitangentDir;
	o.tangentToWorldAndPackedData[2].xyz = normalDir;

	// Previously this was the object-space normal, which was only used for outline direction;
	// so it makes sense to use it as outline direction directly.

	float3 outlineDir = (_VertexColorType == 4) ? (2.0 * v.color.xyz - 1.0) : normalOS;

	o.tangentToWorldAndPackedData[0].w = outlineDir.x;
	o.tangentToWorldAndPackedData[1].w = outlineDir.y;
	o.tangentToWorldAndPackedData[2].w = outlineDir.z;

	float4 objPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
	o.posWorld = mul(unity_ObjectToWorld, v.vertex);
	o.vertex = v.vertex;

	// This is mainly needed when Blender mangles vertex colour values.
	// If you notice major differences in vertex colour behaviour to expectations, try this.
	if (false) v.color.rgb = GammaToLinearSpace(v.color.rgb);

	// Extra data handling
	// X: Outline width | Y: Ramp softness
	// Z: Outline Z offset | 
	switch (_VertexColorType) 
	{
		case 1: // Outline colour
		o.color = v.color;
		o.extraData = float4(v.color.a, 0.0, 1.0, 1.0); 
		break;

		case 2: // Additional data
		o.color = 1.0; // Reset
		o.extraData = v.color;
		break;

		case 3: // Ignore
		o.color = 1.0; 
		o.extraData = float4(1.0, 0.0, 1.0, 1.0); 
		break;

		case 4: // Outline direction + width
		o.color = 1.0; // Handled above
		o.extraData = float4(1.0, 0.0, 1.0, 1.0); 
		o.extraData.x = v.color.a;
		break;

		// 0, Colour
		default:
		o.color = v.color;
		o.extraData = float4(0.0, 0.0, 1.0, 1.0); 
		o.extraData.x = v.color.a;
		break;
	}

	// Invert ramp softness based on popular request
	o.extraData.y = 1-o.extraData.y;

	#if defined(SCSS_OUTLINE)
	#if defined(SCSS_USE_OUTLINE_TEXTURE)
	o.extraData.x *= OutlineMask(postTexcoords.uv[0]);
	#endif

	o.extraData.x *= _outline_width * .01; // Apply outline width and convert to cm
	o.extraData.z *= (1 - _OutlineZPush * 0.1); // Apply outline push parameter.
	
	// Scale outlines relative to the distance from the camera. Outlines close up look ugly in VR because
	// they can have holes, being shells. This is also why it is clamped to not make them bigger.
	// That looks good at a distance, but not perfect. 
	o.extraData.x *= min(distance(o.posWorld,_WorldSpaceCameraPos)*4, 1); 
	#else
	// Remove outline data when no outline present.
	o.extraData.xz = 0.0;
	#endif

    // Simple inventory handling.
    float inventoryMask = getInventoryMask(v.texcoord);

	// Apply the inventory mask.
    // Set the output variables based on the mask to completely remove it.
    // - Set the clip-space position to one that won't be rendered
    // - Set the vertex alpha to zero
    // - Disable outlines
    if (_UseInventory)
    {
		o.pos.z =     inventoryMask ? o.pos.z : 1e+9;
		o.posWorld =  inventoryMask ? o.posWorld : 0;
		o.vertex =    inventoryMask ? o.vertex : 1e+9;
		o.color.a =   inventoryMask ? o.color.a : -1;
		o.extraData.xz = inventoryMask ? o.extraData.xz : 0;
    }

#if (UNITY_VERSION<600)
	TRANSFER_SHADOW(o);
#else
	UNITY_TRANSFER_SHADOW(o, v.texcoord);
#endif

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
	UNITY_TRANSFER_FOG(o, o.pos);
#endif

#if defined(VERTEXLIGHT_ON)
	o.vertexLight = VertexLightContribution(o.posWorld, normalDir);
#endif

	return o;
}

VertexOutput vert_nogeom(appdata_full_local v) {
	VertexOutput o = (VertexOutput)0;

	o = vert(v);

	o.pos = ApplyNearVertexSquishing(o.pos);
	
	o.extraData.x = false;
	return o;
}

// Based on code from MToon
inline VertexOutput CalculateOutlineVertexClipPosition(VertexOutput v)
{
	const float outlineWidth = v.extraData.r;
	if (true)
	{
		#if (SCSS_CAMERA_RELATIVE_VERTEX)
		const half3 positionOS = v.vertex.xyz;
        const half3 normalOS = float3(v.tangentToWorldAndPackedData[0].w, v.tangentToWorldAndPackedData[1].w, v.tangentToWorldAndPackedData[2].w);
        float4x4 matrixIM = unity_WorldToObject;
		matrixIM._m03_m13_m23 += _WorldSpaceCameraPos.xyz;

		// Calculate a world-space vertex offset we can apply in object space
        half3 offsetOS = mul( mul(transpose((float3x3)matrixIM), (float3x3)matrixIM), outlineWidth.xxx);

        half3 localPosition = positionOS + normalOS * offsetOS;

        v.pos = ObjectToClipPosRelative(localPosition);
        #else
        const float3 positionWS = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
        const half3 normalWS = v.tangentToWorldAndPackedData[2].xyz;

        v.posWorld = float4(positionWS + normalWS * outlineWidth, 1);
        v.pos = UnityWorldToClipPos(v.posWorld);
        #endif
	} 
	if (false) 
	{
        const float3 positionWS = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
        const half aspect = getScreenAspectRatio();

		#if (SCSS_CAMERA_RELATIVE_VERTEX)
        float4 positionCS = ObjectToClipPosRelative(v.vertex.xyz);
        #else
        float4 positionCS = UnityObjectToClipPos(v.vertex.xyz);
        #endif
        const half3 normalOS = float3(v.tangentToWorldAndPackedData[0].w, v.tangentToWorldAndPackedData[1].w, v.tangentToWorldAndPackedData[2].w);
        const half3 normalVS = getObjectToViewNormal(normalOS);
        const half3 normalCS = TransformViewToProjection(normalVS.xyz);
        half2 normalProjectedCS = normalize(normalCS.xy);
        normalProjectedCS *= positionCS.w;
        normalProjectedCS.x *= aspect;
        positionCS.xy += outlineWidth * normalProjectedCS.xy * saturate(1 - abs(normalVS.z)); // ignore offset when normal toward camera

        v.posWorld = float4(positionWS, 1);
        v.pos = positionCS;
	}
	return v;
}

float4 ApplyOutlineZBias (float4 clipPos, float bias ) {
    #if defined(UNITY_REVERSED_Z)
        const float far_clip_value_raw = 0.0;
    #else
        const float far_clip_value_raw = 1.0;
    #endif

	float zPushLimit = lerp(far_clip_value_raw, clipPos.z, 0.9);
	clipPos.z = lerp(zPushLimit, clipPos.z, bias);

	return clipPos;
}

[maxvertexcount(6)]
void geom(triangle VertexOutput IN[3], inout TriangleStream<VertexOutput> tristream)
{
	if ((IN[0].color.a + IN[1].color.a + IN[2].color.a) >= 0)
	{
		#if !defined(USING_ALPHA_BLENDING)
		// Generate base vertex
		[unroll]
		for (int ii = 0; ii < 3; ii++)
		{
			VertexOutput o = IN[ii];
			o.extraData.x = false;

			o.pos = ApplyNearVertexSquishing(o.pos);

			tristream.Append(o);
		}

		tristream.RestartStrip();
		#endif

		// Generate outline vertex
		// If the outline triangle is too small, don't emit it.
		if ((IN[0].extraData.r + IN[1].extraData.r + IN[2].extraData.r) >= 1.e-9)
		{
			[unroll]
			for (int i = 2; i >= 0; i--)
			{
				VertexOutput o = IN[i];

				// Single-pass instancing compatibility
	    		UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(o); 
			    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o = CalculateOutlineVertexClipPosition(o);

				o.pos = ApplyOutlineZBias(o.pos, o.extraData.z);

				o.pos = ApplyNearVertexSquishing(o.pos);

				o.extraData.x = true;

				tristream.Append(o);
			}

			tristream.RestartStrip();
		}
			
		#if defined(USING_ALPHA_BLENDING)
		// Generate base vertex
		[unroll]
		for (int ii = 0; ii < 3; ii++)
		{
			VertexOutput o = IN[ii];
			o.extraData.x = false;

			o.pos = ApplyNearVertexSquishing(o.pos);

			tristream.Append(o);
		}

		tristream.RestartStrip();
		#endif
	}
}

#endif // SHADER_STAGE_VERTEX
#endif // SCSS_FORWARD_VERTEX_INCLUDED