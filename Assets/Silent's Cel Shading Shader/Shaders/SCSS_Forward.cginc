VertexOutput vert(appdata_full v) {
	VertexOutput o = (VertexOutput)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_OUTPUT(VertexOutput, o);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv0 = AnimateTexcoords(v.texcoord);
	o.uv1 = v.texcoord1;
	o.normal = v.normal;
	o.normalDir = UnityObjectToWorldNormal(v.normal);
	o.tangentDir = UnityObjectToWorldDir(v.tangent.xyz);
    half sign = v.tangent.w * unity_WorldTransformParams.w;
	o.bitangentDir = cross(o.normalDir, o.tangentDir) * sign;
	float4 objPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
	o.posWorld = mul(unity_ObjectToWorld, v.vertex);
	o.vertex = v.vertex;

	// Extra data handling
	// X: Outline width | Y: Ramp softness
	// Z: Outline Z offset | 
	if (_VertexColorType == 2) 
	{
		o.color = 1.0; // Reset
		o.extraData = v.color;
	} else {
		o.color = v.color;
		o.extraData = float4(0.0, 0.0, 1.0, 1.0); 
		o.extraData.x = v.color.a;
	}

	#if defined(SCSS_USE_OUTLINE_TEXTURE)
	o.extraData.x *= OutlineMask(v.texcoord.xy);
	#endif

	o.extraData.x *= _outline_width * .01; // Apply outline width and convert to cm
	
	// Scale outlines relative to the distance from the camera. Outlines close up look ugly in VR because
	// they can have holes, being shells. This is also why it is clamped to not make them bigger.
	// That looks good at a distance, but not perfect. 
	o.extraData.x *= min(distance(o.posWorld,_WorldSpaceCameraPos)*4, 1); 

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
	
	o.extraData.x = false;
	return o;
}

[maxvertexcount(6)]
void geom(triangle VertexOutput IN[3], inout TriangleStream<VertexOutput> tristream)
{
    #if defined(UNITY_REVERSED_Z)
        const float far_clip_value_raw = 0.0;
    #else
        const float far_clip_value_raw = 1.0;
    #endif

	// Generate base vertex
	[unroll]
	for (int ii = 0; ii < 3; ii++)
	{
		VertexOutput o = IN[ii];
		o.extraData.x = false;

		tristream.Append(o);
	}

	tristream.RestartStrip();

	// Generate outline vertex
	// If the outline triangle is too small, don't emit it.
	if ((IN[0].extraData.r + IN[1].extraData.r + IN[2].extraData.r) >= 1.e-9)
	{
		[unroll]
		for (int i = 2; i >= 0; i--)
		{
			VertexOutput o = IN[i];
			o.pos = UnityObjectToClipPos(o.vertex + normalize(o.normal) * o.extraData.r);

			// Possible future parameter depending on what people need
			float zPushLimit = lerp(far_clip_value_raw, o.pos.z, 0.9);
			o.pos.z = lerp(zPushLimit, o.pos.z, o.extraData.z);

			o.extraData.x = true;

			tristream.Append(o);
		}

		tristream.RestartStrip();
	}
}

float4 frag(VertexOutput i, uint facing : SV_IsFrontFace) : SV_Target
{
	float isOutline = i.extraData.x;
	if (isOutline && !facing) discard;

    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

	// Backface correction. If a polygon is facing away from the camera, it's lit incorrectly.
	// This will light it as though it is facing the camera (which it visually is), unless
	// it's part of an outline, in which case it's invalid and deleted. 
	//facing = backfaceInMirror()? !facing : facing; // Only needed for older Unity versions.
	if (!facing) 
	{
		i.normalDir *= -1;
		i.tangentDir *= -1;
		i.bitangentDir *= -1;
	}

	if (_UseInteriorOutline)
	{
	    isOutline = max(isOutline, 1-innerOutline(i));
	}
	
    float outlineDarken = 1-isOutline;

	float4 texcoords = TexCoords(i);

	// Ideally, we should pass all input to lighting functions through the 
	// material parameter struct. But there are some things that are
	// optional. Review this at a later date...
	i.uv0 = texcoords; 

	SCSS_Input c = (SCSS_Input) 0;

	half detailMask = DetailMask(texcoords.xy);

    half3 normalTangent = NormalInTangentSpace(texcoords, detailMask);

    // Thanks, Xiexe!
    half3 tspace0 = half3(i.tangentDir.x, i.bitangentDir.x, i.normalDir.x);
    half3 tspace1 = half3(i.tangentDir.y, i.bitangentDir.y, i.normalDir.y);
    half3 tspace2 = half3(i.tangentDir.z, i.bitangentDir.z, i.normalDir.z);

    half3 calcedNormal;
    calcedNormal.x = dot(tspace0, normalTangent);
    calcedNormal.y = dot(tspace1, normalTangent);
    calcedNormal.z = dot(tspace2, normalTangent);
    
    calcedNormal = normalize(calcedNormal);
    half3 bumpedTangent = (cross(i.bitangentDir, calcedNormal));
    half3 bumpedBitangent = (cross(calcedNormal, bumpedTangent));

    // For our purposes, we'd like to keep the original normal in i, but warp the bi/tangents.
    c.normal = calcedNormal;
    i.tangentDir = bumpedTangent;
    i.bitangentDir = bumpedBitangent;

	c.albedo = Albedo(texcoords);

	c.emission = Emission(texcoords.xy);

	// Vertex colour application. 
	[flatten]
	switch (_VertexColorType)
	{
		case 2: 
		case 0: c.albedo = c.albedo * i.color.rgb; break;
		case 1: c.albedo = lerp(c.albedo, i.color.rgb, isOutline); break;
	}
	
	c.softness = i.extraData.g;

	c.alpha = Alpha(texcoords.xy);

	c.alpha *= UNITY_SAMPLE_TEX2D_SAMPLER (_ColorMask, _MainTex, texcoords.xy).r;

    #if defined(ALPHAFUNCTION)
    alphaFunction(c.alpha);
	#endif

	applyVanishing(c.alpha);
	
	applyAlphaClip(c.alpha, _Cutoff, i.pos.xy, _AlphaSharp);

	#if !defined(SCSS_CROSSTONE)
	c.tone[0] = Tonemap(texcoords.xy, c.occlusion);
	#endif

	#if defined(SCSS_CROSSTONE)
	c.tone[0] = Tonemap1st(texcoords.xy);
	c.tone[1] = Tonemap2nd(texcoords.xy);
	c.occlusion = ShadingGradeMap(texcoords.xy);
	#endif

	c = applyDetail(c, texcoords);

	c = applyOutline(c, isOutline);

    // Rim lighting parameters. 
	c.rim = initialiseRimParam();
	c.rim.power *= RimMask(texcoords.xy);
	c.rim.tint *= outlineDarken;

	// Scattering parameters
	c.thickness = Thickness(texcoords.xy);

	// Specular variable setup

	// Disable PBR dielectric setup in cel specular mode.
	#if defined(_SPECGLOSSMAP)
	#undef unity_ColorSpaceDielectricSpec
	#define unity_ColorSpaceDielectricSpec half4(0, 0, 0, 1)
	#endif 

	//if (_SpecularType != 0 )
	#if defined(_SPECULAR)
	{
		half4 specGloss = SpecularGloss(texcoords, detailMask);

		c.specColor = specGloss.rgb;
		c.smoothness = specGloss.a;

		if (_UseMetallic == 1)
		{
			// In Metallic mode, ignore the other colour channels. 
			c.specColor = c.specColor.r;
		}

		// Because specular behaves poorly on backfaces, disable specular on outlines. 
		c.specColor  *= outlineDarken;
		c.smoothness *= outlineDarken;

		// Specular energy converservation. From EnergyConservationBetweenDiffuseAndSpecular in UnityStandardUtils.cginc
		c.oneMinusReflectivity = 1 - SpecularStrength(c.specColor); 

		if (_UseMetallic == 1)
		{
			// From DiffuseAndSpecularFromMetallic
			c.oneMinusReflectivity = OneMinusReflectivityFromMetallic(c.specColor);
			c.specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, c.albedo, c.specColor);
		}

		if (_UseEnergyConservation == 1)
		{
			c.albedo.xyz = c.albedo.xyz * (c.oneMinusReflectivity); 
			if (_CrosstoneToneSeparation) c.tone[0].col = c.tone[0].col * (c.oneMinusReflectivity); 
			if (_Crosstone2ndSeparation)  c.tone[1].col = c.tone[1].col * (c.oneMinusReflectivity); 
		}

	    i.tangentDir = ShiftTangent(normalize(i.tangentDir), c.normal, c.smoothness);
	    i.bitangentDir = normalize(i.bitangentDir);
	}
	#endif

	#if !(defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON))
		c.alpha = 1.0;
	#endif

    // When premultiplied mode is set, this will multiply the diffuse by the alpha component,
    // allowing to handle transparency in physically correct way - only diffuse component gets affected by alpha
    half outputAlpha;
    c.albedo = PreMultiplyAlpha (c.albedo, c.alpha, c.oneMinusReflectivity, /*out*/ outputAlpha);

	// Lighting handling
	float3 finalColor = SCSS_ApplyLighting(c, i, texcoords);

	float3 lightmap = float4(1.0,1.0,1.0,1.0);
	#if defined(LIGHTMAP_ON)
		lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1 * unity_LightmapST.xy + unity_LightmapST.zw));
	#endif

	fixed4 finalRGBA = fixed4(finalColor * lightmap, outputAlpha);
	UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	return finalRGBA;
}