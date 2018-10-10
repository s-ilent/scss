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

	float lightContribution = dot(normalize(_WorldSpaceLightPos0.xyz - i.posWorld.xyz),normalDirection);
	// Shadow masks should affect light by causing the shadowed regions to accept less light
	lightContribution = min(lightContribution, (lightContribution*_ShadowMask_var)+0.6); 
	lightContribution*=attenuation;

	//float3 directContribution = floor(saturate(lightContribution) * 2.0); // Original
	lightContribution = max(lightContribution, 0.0);
	// Smooth transition between light steps
	float3 directContribution =  smoothstep(0.30, 0.36, frac(lightContribution))+floor(lightContribution);

	//float3 directContribution =(lightContribution);

	float3 finalColor = baseColor * 
		lerp(0, _LightColor0.rgb, (directContribution + ((1-_Shadow) * attenuation)));

	fixed4 finalRGBA = fixed4(finalColor,1) * i.col;
	UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
	return finalRGBA;
}