float4 frag(VertexOutput i) : COLOR
{
	float4 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
	i.normalDir = normalize(i.normalDir);
	float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
	float3 _BumpMap_var = UnpackNormal(tex2D(_BumpMap,TRANSFORM_TEX(i.uv0, _BumpMap)));
	float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform)); // Perturbed normals
	float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));
	
	float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
	UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);
	float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);

	float4 _ColorMask_var = tex2D(_ColorMask,TRANSFORM_TEX(i.uv0, _ColorMask));
	float4 baseColor = lerp((_MainTex_var.rgba*_Color.rgba),_MainTex_var.rgba,_ColorMask_var.r);
	baseColor *= float4(i.col.rgb, 1);

	float4 _ShadowMask_var = tex2D(_ShadowMask,TRANSFORM_TEX(i.uv0, _ShadowMask));

	#if COLORED_OUTLINE
	if(i.is_outline) {
		baseColor.rgb = i.col.rgb;
	}
	#endif

	#if defined(_ALPHATEST_ON)
	clip (baseColor.a - _Cutoff); 
	#endif

	// Lighting parameters
	float3 halfDir = Unity_SafeNormalize (lightDirection + viewDirection);
	float3 reflDir = reflect(viewDirection, normalDirection); // Calculate reflection vector
	float NdotL = saturate(dot(lightDirection, normalDirection)); // Calculate NdotL
	float NdotV = saturate(dot(viewDirection,  normalDirection)); // Calculate NdotV
	float LdotH = saturate(dot(lightDirection, halfDir));

	float lightContribution = dot(normalize(_WorldSpaceLightPos0.xyz - i.posWorld.xyz),normalDirection);

	#if 1
	float4 shadowMask = tex2D(_ShadowMask,TRANSFORM_TEX(i.uv0, _MainTex));
	#endif
	// Shadow mask handling
	#if 1
	// RGB will boost shadow range. Raising _Shadow reduces its influence.
	// Alpha will boost light range. Raising _Shadow reduces its influence.
	lightContribution = min(lightContribution, (lightContribution * shadowMask)+_Shadow);
	lightContribution = max(lightContribution, (lightContribution * (1+1-shadowMask.w)));
	lightContribution = saturate(lightContribution);
	#endif

	// Cel transition between light steps
	#if 1
	// Apply lightramp to lighting
	float3 directContribution = tex2D(_Ramp, saturate(
		#if _LIGHTRAMP_VERTICAL
		float2( 0.0, lightContribution)
		#else
		float2( lightContribution, 0.0)
		#endif
		) );
	#else
	float3 directContribution =  smoothstep(0.30, 0.36, frac(lightContribution))+floor(lightContribution);
	//float3 directContribution = floor(saturate(lightContribution) * 2.0); // Original
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

		// oneMinusRoughness + (1 - oneMinusReflectivity)
		float grazingTerm = saturate(1-roughness + (1-oneMinusReflectivity));

		#if defined(_METALLIC)
			specColor *= diffuseColor.rgb; // For metallic maps
		#endif
		#if defined(_ENERGY_CONSERVE)
			diffuseColor.xyz = diffuseColor.xyz * (oneMinusReflectivity); 
			// Unity's boost to diffuse power to accomodate rougher metals.
			diffuseColor.xyz += specColor.xyz * (1 - _Smoothness_var) * 0.5;
		#endif
	#endif

	// Physically based specular
	float3 specularContribution = 0;
	#if defined(USE_SPECULAR)
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
			half V = SmithJointGGXVisibilityTerm (NdotL, NdotV, roughness);
		    half D = D_GGX_Anisotropic(nh, halfDir, i.tangentDir, i.bitangentDir, at, ab);
	    #endif

	    half specularTerm = V*D * UNITY_PI; // Torrance-Sparrow model, Fresnel is applied later
	    specularTerm = max(0, specularTerm * NdotL);

		half surfaceReduction = 1.0 / (roughness*roughness + 1);

		UnityGI gi =  GetUnityGI(_LightColor0.rgb, lightDirection, 
		normalDirection, viewDirection, reflDir, attenuation, roughness, i.posWorld.xyz);

		specularContribution = 
		specularTerm * (gi.light.color) * FresnelTerm(specColor, LdotH) +
		surfaceReduction * (gi.indirect.specular.rgb) * FresnelLerp(specColor, grazingTerm, NdotV);
	#endif

	float3 finalColor = diffuseColor * 
		lerp(0, _LightColor0.rgb, directContribution) + specularContribution;

	finalColor *= attenuation;

	#if defined(_SUBSURFACE)
	float3 thicknessMap_var = pow(tex2D(_ThicknessMap, TRANSFORM_TEX(i.uv0, _MainTex)), _ThicknessMapPower);
	finalColor += diffuseColor * getSubsurfaceScatteringLight(_LightColor0, lightDirection, normalDirection, viewDirection,
		attenuation, thicknessMap_var, 0.0);
	#endif

	fixed4 finalRGBA = fixed4(finalColor,1) * i.col;
	UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	return finalRGBA;
}