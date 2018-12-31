// For pass "FORWARD"
float4 frag(VertexOutput i) : COLOR
{
	float4 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
	i.normalDir = normalize(i.normalDir);
	float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);

	// Colour and detail mask. Green is colour tint, while alpha is normal detail mask.
	float4 _ColorMask_var = tex2D(_ColorMask,TRANSFORM_TEX(i.uv0, _MainTex));
	float3 _BumpMap_var = NormalInTangentSpace(i.uv0, _ColorMask_var.a);

	float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform)); // Perturbed normals

	float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));

	float4 _EmissionMap_var = tex2D(_EmissionMap,TRANSFORM_TEX(i.uv0, _MainTex));
	float3 emissive = (_EmissionMap_var.rgb*_EmissionColor.rgb);
	float4 baseColor = lerp(_MainTex_var.rgba,(_MainTex_var.rgba*_Color.rgba),_ColorMask_var.g);
	baseColor *= float4(i.col.rgb, 1); // Could vertex alpha be used, ever? Let's hope not.

	float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz + 0.0000001); // Offset to avoid error in lightless worlds.
	UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);
	float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);

	#if COLORED_OUTLINE
	if(i.is_outline) 
	{
		baseColor.rgb = i.col.rgb; 
	}
	#endif

	// Todo: Some characters can use dithered transparency,
	// like Miku's sleeves, while others get broken by it. 
	#if defined(_ALPHATEST_ON)
		float mask = saturate(interleaved_gradient(i.pos.xy)); 
		//float mask = (float((9*int(i.pos.x)+5*int(i.pos.y))%11) + 0.5) / 11.0;
		//mask = (1-_Cutoff) * (mask + _Cutoff);
		//mask = saturate(_Cutoff + _Cutoff*mask);
		//clip (baseColor.a - mask);
		baseColor.a = saturate(baseColor.a + baseColor.a * mask); 
		clip (baseColor.a - _Cutoff);
	#endif

	// Lighting parameters
	float3 halfDir = Unity_SafeNormalize (lightDirection + viewDirection);
	float3 reflDir = reflect(-viewDirection, normalDirection); // Calculate reflection vector
	float NdotL = saturate(dot(lightDirection, normalDirection)); // Calculate NdotL
	float NdotV = saturate(dot(viewDirection,  normalDirection)); // Calculate NdotV
	float LdotH = saturate(dot(lightDirection, halfDir));

	float2 rlPow4 = Pow4(float2(dot(reflDir, lightDirection), 1 - NdotV));  // "use R.L instead of N.H to save couple of instructions"

	// Ambient fresnel	
	float3 fresnelEffect = 0.0;

	if (_UseFresnel == 1)
	{
	fresnelEffect = rlPow4.y;
	float2 fresStep = .5 + float2(-1, 1) * fwidth(rlPow4.y);
	// Sharper rim lighting for the anime look.
	fresnelEffect *= _FresnelWidth;
	float2 fresStep_var = lerp(float2(0.0, 1.0), fresStep, 1-_FresnelStrength);
	fresnelEffect = smoothstep(fresStep_var.x, fresStep_var.y, fresnelEffect);
	fresnelEffect *= _FresnelTint.rgb * _FresnelTint.a;
	}

	// Customisable fresnel for a user-defined glow
	emissive += _CustomFresnelColor.xyz * (pow(rlPow4.y, rcp(_CustomFresnelColor.w+0.0001)));

	float3 lightmap = float4(1.0,1.0,1.0,1.0);
	#ifdef LIGHTMAP_ON
		lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1 * unity_LightmapST.xy + unity_LightmapST.zw));
	#endif

	// Seperate energy conserved and original value for later.
	float3 diffuseColor = baseColor.xyz;

	#if defined(USE_SPECULAR)
		// Specular, high quality (but with probably decent performance)
		float4 _SpecularMap_var = tex2D(_SpecularMap,TRANSFORM_TEX(i.uv0, _MainTex));

		#if defined(_SPECULAR_DETAIL)
		float4 _SpecularDetailMask_var = tex2D(_SpecularDetailMask,TRANSFORM_TEX(i.uv0, _SpecularDetailMask));
		_SpecularMap_var *= saturate(_SpecularDetailMask_var + 1-_SpecularDetailStrength);
		#endif

		// Todo: Add smoothness in diffuse alpha support
		float3 specColor = _SpecularMap_var.rgb;
		float _Smoothness_var = _Smoothness * _SpecularMap_var.w;

		// Because specular behaves poorly on backfaces, disable specular on outlines. 
		if(i.is_outline) 
		{
			specColor = 0;
			_Smoothness_var = 0;
		}

		// Perceptual roughness transformation...
		float roughness = SmoothnessToRoughness(_Smoothness_var);

		// Specular energy converservation. From EnergyConservationBetweenDiffuseAndSpecular in UnityStandardUtils.cginc
		half oneMinusReflectivity = 1 - max3(specColor);

		if (_UseMetallic == 1)
		{
			// From DiffuseAndSpecularFromMetallic
			oneMinusReflectivity = OneMinusReflectivityFromMetallic(specColor);
			specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, diffuseColor, specColor);
		}

		// oneMinusRoughness + (1 - oneMinusReflectivity)
		float grazingTerm = saturate(1-roughness + (1-oneMinusReflectivity));

		if (_UseEnergyConservation == 1)
		{
			diffuseColor.xyz = diffuseColor.xyz * (oneMinusReflectivity); 
			// Unity's boost to diffuse power to accomodate rougher metals.
			// Note: It looks like 2017 doesn't do this anymore... 
			// But it looks nice, so I've left it in.
			diffuseColor.xyz += specColor.xyz * (1 - _Smoothness_var) * 0.5;
		}
	#endif

	// Derive the direction of incoming light from either the direction or the ambient probes.
    #if defined(DIRECTIONAL)
    	lightDirection = lightDirection; // Do nothing.
    #else
    	// Get the dominant light direction from light probes
	    lightDirection = normalize(unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz);
	    #if !defined(POINT) && !defined(SPOT) 
	    if(length(unity_SHAr.xyz*unity_SHAr.w + unity_SHAg.xyz*unity_SHAg.w + unity_SHAb.xyz*unity_SHAb.w) == 0)
	    {
	        lightDirection = normalize(float4(1, 1, 1, 0));
	    }
	    #endif
    #endif
    #if !defined(DIRECTIONAL) && !defined(POINT) && !defined(SPOT)
    	attenuation = 1;
	#endif
	float remappedLight = (dot(normalDirection, lightDirection) * 0.5 + 0.5) * attenuation;
	
	// Shadow mask handling
	float4 shadowMask = tex2D(_ShadowMask,TRANSFORM_TEX(i.uv0, _MainTex));
	
	if (_ShadowMaskType == 0) 
	{
	// RGB will boost shadow range. Raising _Shadow reduces its influence.
	// Alpha will boost light range. Raising _Shadow reduces its influence.
	remappedLight = min(remappedLight, (remappedLight * shadowMask)+_Shadow);
	remappedLight = max(remappedLight, (remappedLight * (1+1-shadowMask.w)));
	}
	if (_ShadowMaskType == 1) 
	{
	// RGB will boost shadow range. Raising _Shadow reduces its influence.
	// Alpha will boost light range. Raising _Shadow reduces its influence.
	remappedLight = min(remappedLight, (remappedLight * shadowMask.w)+_Shadow);
	//remappedLight = max(remappedLight, (remappedLight * (1+1-shadowMask.w)));
	}
	remappedLight = saturate(remappedLight);

	// Shadow appearance setting
	remappedLight = saturate(_ShadowLift + remappedLight * (1-_ShadowLift));

	// Remove light influence from outlines. 
	//remappedLight = i.is_outline? 0 : remappedLight;

	float3 lightContribution = 1;
	#if 1
		// Apply lightramp to lighting
		lightContribution = sampleRampWithOptions(remappedLight);
	#else
		// Lighting without lightramp
		#if 1
			// This produces more instructions, but also an antialiased edge. 
			float shadeWidth = max(fwidth(remappedLight), 0.01);

			// Create two variables storing values similar to 0.49 and 0.51 that the fractional part
			// of the lighting is squeezed into. Then add the non-fractional part to the result.
			// Using fwidth (which should be cheap), we can come up with a gradient
			// about the size of 2 pixels in screen space at minimum.
			// Note: This might be slower than just sampling a light ramp,
			// but popular thought states math > textures for modern GPUs.

			float2 shadeOffset = 0.50 + float2(-shadeWidth, shadeWidth); 
			lightContribution = smoothstep(shadeOffset.x, shadeOffset.y, frac(remappedLight)); 
			lightContribution += floor(remappedLight);
		#else
			// Cubed's original
			//lightContribution = saturate((1.0 - _Shadow) + floor(saturate(remappedLight) * 2.0)); 
			lightContribution = saturate(floor(saturate(remappedLight) * 2.0)); 
		#endif
	#endif

	if (_ShadowMaskType == 1) 
	{
		// Implementation A
		// Not used because it requires lots of tweaking.
		//diffuseColor = lerp(diffuseColor * shadowMask.rgb, diffuseColor, lightContribution);
		lightContribution += (1 - lightContribution) * shadowMask;
	}

	// Apply indirect lighting shift.
	lightContribution = lightContribution*(1-_IndirectLightingBoost)+_IndirectLightingBoost;

	if (_UseMatcap == 1) 
	{
		// Based on Masataka SUMI's implementation
	    half3 worldUp = float3(0, 1, 0);
	    half3 worldViewUp = normalize(worldUp - viewDirection * dot(viewDirection, worldUp));
	    half3 worldViewRight = normalize(cross(viewDirection, worldViewUp));
	    half2 matcapUV = half2(dot(worldViewRight, normalDirection), dot(worldViewUp, normalDirection)) * 0.5 + 0.5;
	
		float3 AdditiveMatcap = tex2D(_AdditiveMatcap, matcapUV);
		float3 MultiplyMatcap = tex2D(_MultiplyMatcap, matcapUV);
		float4 _MatcapMask_var = tex2D(_MatcapMask,TRANSFORM_TEX(i.uv0, _MainTex));
		diffuseColor.xyz = lerp(diffuseColor.xyz, diffuseColor.xyz*MultiplyMatcap, _MultiplyMatcapStrength * _MatcapMask_var.w);
		diffuseColor.xyz += (ShadeSH9_mod(half4(0.0,  0.0, 0.0, 1.0))+_LightColor0)*AdditiveMatcap*_AdditiveMatcapStrength*_MatcapMask_var.g;
	}
	//float horizon = min(1.0 + dot(reflDir, normalDirection), 1.0);

	#if defined(_LIGHTINGTYPE_CUBED)
		float3 directLighting   = ((ShadeSH9_mod(half4(0.0,  1.0, 0.0, 1.0)) + _LightColor0.rgb)) ;
		float3 indirectLighting = ((ShadeSH9_mod(half4(0.0, -1.0, 0.0, 1.0)))); 
	#endif
	#if defined(_LIGHTINGTYPE_ARKTOON)
		float3 directLighting   = ((GetSHLength() + _LightColor0.rgb)) ;
		float3 indirectLighting = ((ShadeSH9_mod(half4(0.0, 0.0, 0.0, 1.0)))); 
	#endif

	// Vertex lighting based on Shade4PointLights
	float4 vertexAttenuation = i.vertexLight;
	vertexAttenuation = min(vertexAttenuation, (vertexAttenuation * shadowMask)+_Shadow);
	vertexAttenuation = max(vertexAttenuation, (vertexAttenuation * (1+1-shadowMask.w)));
	vertexAttenuation = saturate(vertexAttenuation);

	// Cheaper, but less aethetically correct.
	//vertexAttenuation = smoothstep(UNITY_PI/10-0.025,UNITY_PI/10+0.025, 
	//	 frac(vertexAttenuation))+floor(vertexAttenuation);

	float3 vertexContribution = 0;
    vertexContribution += unity_LightColor[0] * sampleRampWithOptions(vertexAttenuation.x) * vertexAttenuation.x;
    vertexContribution += unity_LightColor[1] * sampleRampWithOptions(vertexAttenuation.y) * vertexAttenuation.y;
    vertexContribution += unity_LightColor[2] * sampleRampWithOptions(vertexAttenuation.z) * vertexAttenuation.z;
    vertexContribution += unity_LightColor[3] * sampleRampWithOptions(vertexAttenuation.w) * vertexAttenuation.w;

	// Physically based specular
	#if defined(USE_SPECULAR) || defined(_LIGHTINGTYPE_STANDARD)
		half nh = saturate(dot(normalDirection, halfDir));
		#if defined(_SPECULAR_GGX)
			half V = SmithJointGGXVisibilityTerm (NdotL, NdotV, roughness);
		    half D = GGXTerm (nh, roughness);
	    #endif
		#if defined(_SPECULAR_CHARLIE)
			half V = V_Neubelt (NdotV, NdotL);
		    half D = D_Charlie (roughness, nh);
	    #endif
	    #if defined(_SPECULAR_GGX_ANISO)
		    float anisotropy = _Anisotropy;
		    float at = max(roughness * (1.0 + anisotropy), 0.001);
		    float ab = max(roughness * (1.0 - anisotropy), 0.001);

		    float TdotL = dot(i.tangentDir, lightDirection);
		    float BdotL = dot(i.bitangentDir, lightDirection);
		    float TdotV = dot(i.tangentDir, viewDirection);
		    float BdotV = dot(i.bitangentDir, lightDirection);

		    // Accurate but probably expensive
			//float V = V_SmithGGXCorrelated_Anisotropic (at, ab, TdotV, BdotV, TdotL, BdotL, NdotV, NdotL);
			half V = SmithJointGGXVisibilityTerm (NdotL, NdotV, roughness);
		    half D = D_GGX_Anisotropic(nh, halfDir, i.tangentDir, i.bitangentDir, at, ab);
	    #endif

	    #if defined(_LIGHTINGTYPE_STANDARD) & !defined(USE_SPECULAR)
	    // Awkward
	    	half V = 0; half D = 0; half roughness = 0; half specColor = 0; half grazingTerm = 0;
	    #endif

	    half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
	    specularTerm = max(0, specularTerm * NdotL);

	    // We could match the falloff of specular to the light ramp, but it causes artifacts.
	    //specularTerm = max(0, specularTerm * (lightContribution * 2 - 1));

		half surfaceReduction = 1.0 / (roughness*roughness + 1);

		UnityGI gi =  GetUnityGI(_LightColor0.rgb, lightDirection, 
		normalDirection, viewDirection, reflDir, attenuation, roughness, i.posWorld.xyz);

		//lightContribution = DisneyDiffuse(NdotV, NdotL, LdotH, roughness) * NdotL;

		#if defined(_LIGHTINGTYPE_STANDARD)
			float3 indirectLighting = gi.indirect.diffuse.rgb;
			float3 directContribution = diffuseColor * (gi.indirect.diffuse.rgb + _LightColor0.rgb * lightContribution);
		#else
			float3 directContribution = diffuseColor * 
			lerp(indirectLighting, directLighting, lightContribution);
		#endif

		directContribution += vertexContribution*diffuseColor;
	
		directContribution *= 1+fresnelEffect;

		float3 finalColor = emissive + directContribution +
		specularTerm * (gi.light.color + vertexContribution) * FresnelTerm(specColor, LdotH) +
		surfaceReduction * (gi.indirect.specular.rgb + vertexContribution) * FresnelLerp(specColor, grazingTerm, NdotV);
	#else
		float3 directContribution = diffuseColor * 
		lerp(indirectLighting, directLighting, lightContribution);

		directContribution += vertexContribution*diffuseColor;
		
		directContribution *= 1+fresnelEffect;

		float3 finalColor = directContribution + emissive;
	#endif

	if (_UseSubsurfaceScattering == 1)
	{
	float3 thicknessMap_var = pow(tex2D(_ThicknessMap, TRANSFORM_TEX(i.uv0, _MainTex)), _ThicknessMapPower);
	finalColor += diffuseColor * getSubsurfaceScatteringLight(_LightColor0, lightDirection, normalDirection, viewDirection,
		attenuation, thicknessMap_var, indirectLighting);
	}

	fixed4 finalRGBA = fixed4(finalColor * lightmap, baseColor.a);
	UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	return finalRGBA;
}