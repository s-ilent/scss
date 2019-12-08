v2g vert(appdata_full v) {
	v2g o = (v2g)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_OUTPUT(v2g, o);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv0 = v.texcoord;
	o.uv1 = v.texcoord1;
	o.normal = v.normal;
	o.tangent = v.tangent;
	o.normalDir = UnityObjectToWorldNormal(v.normal);
	o.tangentDir = UnityObjectToWorldDir(v.tangent.xyz);
    half sign = v.tangent.w * unity_WorldTransformParams.w;
	o.bitangentDir = cross(o.normalDir, o.tangentDir) * sign;
	float4 objPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
	o.posWorld = mul(unity_ObjectToWorld, v.vertex);
	o.vertex = v.vertex;

	// Extra data handling
	// X: Outline width | Y: Ramp softness
	if (_VertexColorType == 2) 
	{
		o.color = 1.0; // Reset
		o.extraData.xy = v.color.rg;
	} else {
		o.color = v.color;
		o.extraData.x = v.color.a;
		o.extraData.y = 0.0; 
	}

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

	UNITY_TRANSFER_FOG(o, o.pos);
#if VERTEXLIGHT_ON
	o.vertexLight = VertexLightContribution(o.posWorld, o.normalDir);
#else
	o.vertexLight = 0;
#endif
	return o;
}

[maxvertexcount(6)]
void geom(triangle v2g IN[3], inout TriangleStream<VertexOutput> tristream)
{
	VertexOutput o = (VertexOutput)0;
	for (int i = 2; i >= 0; i--)
	{
		// If the outline triangle is too small, don't emit it.
		if (IN[i].extraData.r <= 1.e-9)
		{
			continue;
		}

		o.uv0 = IN[i].uv0;
		o.uv1 = IN[i].uv1;
		o.posWorld = mul(unity_ObjectToWorld, IN[i].vertex);
		o.normalDir = UnityObjectToWorldNormal(IN[i].normal);
		o.tangentDir = IN[i].tangentDir;
		o.bitangentDir = IN[i].bitangentDir;
		o.is_outline = true;

		o.pos = UnityObjectToClipPos(IN[i].vertex + normalize(IN[i].normal) * IN[i].extraData.r);
		//o.pos.z *= sign(o.pos.z) * (2*any(_outline_width_var))-1; // 

		// Pass-through the shadow coordinates if this pass has shadows.
		#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE) || (defined (UNITY_LIGHT_PROBE_PROXY_VOLUME) && UNITY_VERSION<600)
		o._ShadowCoord = IN[i]._ShadowCoord;
		#endif

		// Pass-through the fog coordinates if this pass has fog.
		#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
		o.fogCoord = IN[i].fogCoord;
		#endif

		// Pass-through the vertex light information.
		o.vertexLight = IN[i].vertexLight;
		o.color = fixed4( _outline_color.r, _outline_color.g, _outline_color.b, 1)*IN[i].color;
		o.extraData = IN[i].extraData;

		UNITY_TRANSFER_INSTANCE_ID(IN[i], o);

		tristream.Append(o);
	}

	tristream.RestartStrip();

	for (int ii = 0; ii < 3; ii++)
	{
		o.pos = UnityObjectToClipPos(IN[ii].vertex);
		o.uv0 = IN[ii].uv0;
		o.uv1 = IN[ii].uv1;
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
		o.color = IN[ii].color;
		o.extraData = IN[ii].extraData;

		UNITY_TRANSFER_INSTANCE_ID(IN[i], o);

		tristream.Append(o);
	}

	tristream.RestartStrip();
}

VertexOutput vert_nogeom(appdata_full v) {
	VertexOutput o = (VertexOutput)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_OUTPUT(VertexOutput, o);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv0 = v.texcoord;
	o.uv1 = v.texcoord1;
	o.normalDir = UnityObjectToWorldNormal(v.normal);
	o.tangentDir = UnityObjectToWorldDir(v.tangent.xyz);
    half sign = v.tangent.w * unity_WorldTransformParams.w;
	o.bitangentDir = cross(o.normalDir, o.tangentDir) * sign;
	float4 objPos = mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
	o.posWorld = mul(unity_ObjectToWorld, v.vertex);
	o.is_outline = false;

	// Extra data handling
	// X: Outline width | Y: Ramp softness
	if (_VertexColorType == 2) 
	{
		o.color = 1.0; // Reset
		o.extraData.xy = v.color.rg;
	} else {
		o.color = v.color;
		o.extraData.x = v.color.a;
		o.extraData.y = 0.0; 
	}

	#if (UNITY_VERSION<600)
	TRANSFER_SHADOW(o);
	#else
	UNITY_TRANSFER_SHADOW(o, v.texcoord);
	#endif

	UNITY_TRANSFER_FOG(o, o.pos);
#if VERTEXLIGHT_ON
	o.vertexLight = VertexLightContribution(o.posWorld, o.normalDir);
#else
	o.vertexLight = 0;
#endif
	return o;
}

float4 frag(VertexOutput i, uint facing : SV_IsFrontFace) : SV_Target
{
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
	if (i.is_outline && !facing) discard;

	float4 texcoords = TexCoords(i);

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

	// Vertex colour application. 
	c.albedo = _VertexColorType? c.albedo : c.albedo * i.color.rgb;
	c.softness = i.extraData.g;

	if(i.is_outline && _OutlineMode == 2) 
	{
		c.albedo = i.color.rgb; 
	}
	if (i.is_outline) 
	{
		c.albedo *= i.color.rgb;
	}

	c.alpha = Alpha(texcoords.xy);

	#if defined(_ALPHATEST_ON)
	// Switch between dithered alpha and sharp-edge alpha.
		if (_AlphaSharp  == 0) {
			float mask = (T(intensity(i.pos.xy + _SinTime.x%4)));
			c.alpha *= c.alpha;
			c.alpha = saturate(c.alpha + c.alpha * mask); 
			clip (c.alpha);
		}
		if (_AlphaSharp  == 1) {
			c.alpha = ((c.alpha - _Cutoff) / max(fwidth(c.alpha), 0.0001) + 0.5);
			clip (c.alpha);
		}
	#endif

	#if !(defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON))
		c.alpha = 1.0;
	#endif

	// Lighting parameters
	SCSS_Light l = MainLight();
	#if defined(UNITY_PASS_FORWARDADD)
	l.dir = normalize(_WorldSpaceLightPos0.xyz - i.posWorld.xyz);
	#endif
	float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);

	SCSS_LightParam d = (SCSS_LightParam) 0;
	d.halfDir = Unity_SafeNormalize (l.dir + viewDir);
	d.reflDir = reflect(-viewDir, c.normal); // Calculate reflection vector
	d.NdotL = saturate(dot(l.dir, c.normal)); // Calculate NdotL
	d.NdotV = saturate(dot(viewDir,  c.normal)); // Calculate NdotV
	d.LdotH = saturate(dot(l.dir, d.halfDir));
	d.NdotH = (dot(c.normal, d.halfDir)); // Saturate seems to cause artifacts
	d.rlPow4 = Pow4(float2(dot(d.reflDir, l.dir), 1 - d.NdotV));  

	c.tonemap = Tonemap(texcoords.xy, c.occlusion);

	// Specular variable setup
	//if (_SpecularType != 0 )
	#if (defined(_METALLICGLOSSMAP) || defined(_SPECGLOSSMAP))
	{
		half4 specGloss = SpecularGloss(texcoords, detailMask);

		c.specColor = specGloss.rgb;
		c.smoothness = specGloss.a;

		// Because specular behaves poorly on backfaces, disable specular on outlines. 
		if(i.is_outline) 
		{
			c.specColor = 0;
			c.smoothness = 0;
		}

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
			c.tonemap = c.tonemap * (c.oneMinusReflectivity); 
		}

		// Geometric Specular AA from HDRP
	    c.smoothness = GeometricNormalFiltering(c.smoothness, i.normalDir.xyz, 0.25, 0.5);

	    i.tangentDir = ShiftTangent(normalize(i.tangentDir), c.normal, c.smoothness);
	    i.bitangentDir = normalize(i.bitangentDir);
	}
	#endif

	// Lighting handling
	float3 finalColor = SCSS_ApplyLighting(c, d, i, viewDir, l, texcoords);

	#if defined(UNITY_PASS_FORWARDBASE)
	float3 emissionMask = Emission(texcoords.xy);
	float4 emissionDetail = EmissionDetail(texcoords.zw);
	//finalColor *= saturate(emissionDetail.w + (1-emissionMask.rgb));
	finalColor = max(0, finalColor - saturate((1-emissionDetail.w)- (1-emissionMask.rgb)));
	finalColor += emissionDetail.rgb * emissionMask * _EmissionColor.rgb;
	// Emissive rim. To restore masking behaviour, multiply by emissionMask.
	finalColor += _CustomFresnelColor.xyz * (pow(d.rlPow4.y, rcp(_CustomFresnelColor.w+0.0001)));
	#endif

	float3 lightmap = float4(1.0,1.0,1.0,1.0);
	#if defined(LIGHTMAP_ON)
		lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1 * unity_LightmapST.xy + unity_LightmapST.zw));
	#endif

	fixed4 finalRGBA = fixed4(finalColor * lightmap, c.alpha);
	UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	return finalRGBA;
}