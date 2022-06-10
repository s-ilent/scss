#ifndef SCSS_FORWARD_VERTEX_INCLUDED
#define SCSS_FORWARD_VERTEX_INCLUDED

#include "SCSS_Attributes.cginc"

VertexOutput vert(appdata_full v) {
	VertexOutput o = (VertexOutput)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_OUTPUT(VertexOutput, o);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	o.pos = UnityObjectToClipPos(v.vertex);

	float4 uvPack0 = float4(v.texcoord.xy, v.texcoord1.xy);
	float4 uvPack1 = float4(v.texcoord2.xy, v.texcoord3.xy);
	uvPack0.xy = AnimateTexcoords(uvPack0.xy);
	o.uvPack0 = uvPack0;
	o.uvPack1 = uvPack1;

	float3 normalOS = v.normal;
	float3 normalDir = UnityObjectToWorldNormal(v.normal);
	float3 tangentDir = UnityObjectToWorldDir(v.tangent.xyz);
    half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
	float3 bitangentDir = cross(normalDir, tangentDir) * tangentSign;

	o.tangentToWorldAndPackedData[0].xyz = tangentDir;
	o.tangentToWorldAndPackedData[1].xyz = bitangentDir;
	o.tangentToWorldAndPackedData[2].xyz = normalDir;

	o.tangentToWorldAndPackedData[0].w = normalOS.x;
	o.tangentToWorldAndPackedData[1].w = normalOS.y;
	o.tangentToWorldAndPackedData[2].w = normalOS.z;

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
		case 2: // Additional data
		o.color = 1.0; // Reset
		o.extraData = v.color;
		break;

		case 3: // None
		o.color = 1.0; 
		o.extraData = float4(1.0, 0.0, 1.0, 1.0); 
		break;

		default:
		o.color = v.color;
		o.extraData = float4(0.0, 0.0, 1.0, 1.0); 
		o.extraData.x = v.color.a;
		break;
	}

	#if defined(SCSS_OUTLINE)
	#if defined(SCSS_USE_OUTLINE_TEXTURE)
	o.extraData.x *= OutlineMask(uvPack0.xy);
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
	o.vertexLight = VertexLightContribution(o.posWorld, o.normalDir);
#endif

	return o;
}

VertexOutput vert_nogeom(appdata_full v) {
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
        const float3 positionWS = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
        const half3 normalWS = v.tangentToWorldAndPackedData[2].xyz;

        v.posWorld = float4(positionWS + normalWS * outlineWidth, 1);
        v.pos = UnityWorldToClipPos(v.posWorld);
	} 
	if (false) 
	{
        const float3 positionWS = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)).xyz;
        const half aspect = getScreenAspectRatio();

        float4 positionCS = UnityObjectToClipPos(v.vertex.xyz);
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

				//o.pos = UnityObjectToClipPos(o.vertex + normalize(o.normal) * o.extraData.r);
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

#endif // SCSS_FORWARD_VERTEX_INCLUDED