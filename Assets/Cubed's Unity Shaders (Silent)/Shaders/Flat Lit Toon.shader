Shader "CubedParadox/Flat Lit Toon (Silent)"
{
	Properties
	{
		_MainTex("MainTex", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)
		_ColorMask("ColorMask", 2D) = "black" {}
		_Shadow("Shadow Mask Power", Range(0, 1)) = 0.5
		_ShadowLift("Shadow Offset", Range(0, 1)) = 0.0
		_IndirectLightingBoost("Indirect Lighting Boost", Range(0, 1)) = 0.0
		_ShadowMask("ShadowMask", 2D) = "white" {}
		_LightingRamp ("Lighting Ramp", 2D) = "white" {}
		_outline_width("outline_width", Float) = 0.2
		_outline_color("outline_color", Color) = (0.5,0.5,0.5,1)
		_outline_tint("outline_tint", Range(0, 1)) = 0.5
		_EmissionMap("Emission Map", 2D) = "white" {}
		[HDR]_EmissionColor("Emission Color", Color) = (0,0,0,1)
		[HDR]_CustomFresnelColor("Emissive Fresnel Color", Color) = (0,0,0,1)
		_SpecularMap ("Specular Map", 2D) = "black" {}
		[Toggle(_ENERGY_CONSERVE)] _UseEnergyConservation ("Energy Conservation", Float) = 0.0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5
		_SpecularMult ("Specular Multiplier", Range(0, 20)) = 1
		[Toggle(_FRESNEL)] _UseFresnel ("Use Fresnel", Float) = 0.0
		_FresnelWidth ("Fresnel Strength", Range(0, 20)) = .5
		_FresnelStrength ("Fresnel Softness", Range(0.1, 0.9999)) = 0.5
		_BumpMap("BumpMap", 2D) = "bump" {}
		_Cutoff("Alpha cutoff", Range(0,1)) = 0.5
		[HideInInspector] _OutlineMode("__outline_mode", Float) = 0.0
		[Toggle(_MATCAP)] _UseMatcap ("Use Matcap", Float) = 0.0
		_AdditiveMatcap("AdditiveMatcapTex", 2D) = "black" {}
		_AdditiveMatcapStrength("Additive Matcap Strength", Range(0, 2)) = 1.0
		_MultiplyMatcap("MultiplyMatcapTex", 2D) = "white" {}
		_MultiplyMatcapStrength("Multiply Matcap Strength", Range(0, 2)) = 1.0
		[Toggle(_LIGHTRAMP_VERTICAL)] _UseVerticalLightramp ("Use Vertical Lightramp", Float) = 0.0

        // Advanced options.
        [Enum(RenderingMode)] _Mode("Rendering Mode", Float) = 0                                     // "Opaque"
        [Enum(CustomRenderingMode)] _CustomMode("Mode", Float) = 0                                   // "Opaque"
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("Source Blend", Float) = 1                 // "One"
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("Destination Blend", Float) = 0            // "Zero"
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp("Blend Operation", Float) = 0                 // "Add"
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("Depth Test", Float) = 4                // "LessEqual"
        [Enum(DepthWrite)] _ZWrite("Depth Write", Float) = 1                                         // "On"
        [Enum(UnityEngine.Rendering.ColorWriteMask)] _ColorWriteMask("Color Write Mask", Float) = 15 // "All"
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 2                     // "Back"
        _RenderQueueOverride("Render Queue Override", Range(-1.0, 5000)) = -1
	}

	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
		}

		Pass
		{

			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }

            Blend[_SrcBlend][_DstBlend]
            BlendOp[_BlendOp]
            ZTest[_ZTest]
            ZWrite[_ZWrite]
            Cull[_CullMode]
            ColorMask[_ColorWriteMask]

			CGPROGRAM
			#include "FlatLitToonCore.cginc"

			#pragma shader_feature NO_OUTLINE TINTED_OUTLINE COLORED_OUTLINE
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#pragma shader_feature _ENERGY_CONSERVE
			#pragma shader_feature _FRESNEL
			#pragma shader_feature _MATCAP
			#pragma shader_feature _LIGHTRAMP_VERTICAL
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#pragma multi_compile_fwdbase
			#pragma multi_compile_fog

			float4 frag(VertexOutput i) : COLOR
			{
				float4 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
				i.normalDir = normalize(i.normalDir);
				float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
				float3 _BumpMap_var = UnpackNormal(tex2D(_BumpMap,TRANSFORM_TEX(i.uv0, _BumpMap)));
				float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform)); // Perturbed normals
				float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));

				float4 _EmissionMap_var = tex2D(_EmissionMap,TRANSFORM_TEX(i.uv0, _EmissionMap));
				float3 emissive = (_EmissionMap_var.rgb*_EmissionColor.rgb);
				float4 _ColorMask_var = tex2D(_ColorMask,TRANSFORM_TEX(i.uv0, _ColorMask));
				float4 baseColor = lerp((_MainTex_var.rgba*_Color.rgba),_MainTex_var.rgba,_ColorMask_var.r);
				baseColor *= float4(i.col.rgb, 1); // Could vertex alpha be used, ever? Let's hope not.

				float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz + 0.0000001); // Offset to avoid error in lightless worlds.
				float3 lightColor = _LightColor0.rgb; 
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
				mask = (1-_Cutoff) * (mask + _Cutoff);
				clip (baseColor.a - mask);
				#endif

				// Lighting parameters
    			float3 halfDir = Unity_SafeNormalize (lightDirection + viewDirection);
				float3 reflDir = reflect(viewDirection, normalDirection); // Calculate reflection vector
				float NdotL = saturate(dot(lightDirection, normalDirection)); // Calculate NdotL
				float NdotV = saturate(dot(viewDirection,  normalDirection)); // Calculate NdotV
    			float LdotH = saturate(dot(lightDirection, halfDir));

				float2 rlPow4 = Pow4(float2(dot(reflDir, lightDirection), 1 - NdotV));  // "use R.L instead of N.H to save couple of instructions"

				// Specular, Unity style (hopefully actually faster) 
				// Todo: Only if specular is present? The main processing is done below, though.
				float3 specularContribution = 0.0;
				float fresnelEffect = 0.0;
				float4 _SpecularMap_var = tex2D(_SpecularMap,TRANSFORM_TEX(i.uv0, _SpecularMap));
				// Todo: Add smoothness in diffuse alpha support
				float3 specColor = _SpecularMap_var.rgb;
				float _Smoothness_var = _Smoothness * _SpecularMap_var.w;
				// Perceptual roughness transformation...
				// I forgot if this was necessary. Oops! I guess we're doing it ourselves, so yes.
				_Smoothness_var = _Smoothness_var * _Smoothness_var;
				
				// Specular energy converservation. From EnergyConservationBetweenDiffuseAndSpecular in UnityStandardUtils.cginc
				half oneMinusReflectivity = 1 - max3(specColor);

				float grazingTerm = saturate(_Smoothness_var + (1-oneMinusReflectivity));
				specularContribution = UnitySpecularSimplified(specColor, _Smoothness_var, rlPow4, NdotL);
				//specularContribution *= _SpecularMult; // Depreciated

				#if 1 //defined(_FRESNEL) || true
					float fresnelEdge = fwidth(rlPow4.y);
					float2 fresStep = .5 + float2(-1, 1) * fresnelEdge;
				#endif

				#if defined(_FRESNEL)
					fresnelEffect = rlPow4.y;
					// Sharper rim lighting for the anime look.
					fresnelEffect *= _FresnelWidth;
					float2 fresStep_var = lerp(float2(0.0, 1.0), fresStep, 1-_FresnelStrength);
					fresnelEffect = smoothstep(fresStep_var.x, fresStep_var.y, fresnelEffect);
				#endif

				// Customisable fresnel for a user-defined glow
				emissive += _CustomFresnelColor.xyz * (pow(rlPow4.y, rcp(_CustomFresnelColor.w+0.0001)));

				float3 lightmap = float4(1.0,1.0,1.0,1.0);
				#ifdef LIGHTMAP_ON
				lightmap = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv1 * unity_LightmapST.xy + unity_LightmapST.zw));
				#endif

				// Reproduce Standard shader's method...
				float roughness = 1 - _Smoothness_var;
				roughness *= 1.7 - 0.7 * roughness;

				#if 0
				// Cubed's original
				float3 reflectionMap = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, normalize((_WorldSpaceCameraPos - objPos.rgb)), 7), unity_SpecCube0_HDR) * 0.02;
				#endif
				#if 0
				// Compromise between Cubed's original normalised reflection sampling and accurate reflection
				float3 reflWarped = lerp(normalize((_WorldSpaceCameraPos - objPos.xyz)), reflDir, 
					saturate(2*_Smoothness_var));
				float3 reflectionMap = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflWarped, 
					roughness*UNITY_SPECCUBE_LOD_STEPS), unity_SpecCube0_HDR);
				#else
				// Just do it properly!
				float3 reflectionMap = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 
					roughness*UNITY_SPECCUBE_LOD_STEPS), unity_SpecCube0_HDR);
				#endif

				float3 diffuseColor = baseColor.xyz;
				#if defined(_ENERGY_CONSERVE)
				// Note: I'm pretty sure this specular system isn't doing what I think
				// it's doing. 
				specColor *= diffuseColor.rgb; // For metallic maps
				diffuseColor.xyz = diffuseColor.xyz * 
					//(half3(1,1,1) - specColor); // By colour
					oneMinusReflectivity; // Monochrome
				// Unity's boost to diffuse power to accomodate rougher metals.
				diffuseColor.xyz += specColor.xyz * (1 - _Smoothness_var) * 0.5;
				#endif

				float3 directReflectance = 0.16 * _Smoothness_var * oneMinusReflectivity + baseColor * (1-oneMinusReflectivity);

				float grayscalelightcolor 	 = dot(_LightColor0.rgb, grayscale_vector);
				float bottomIndirectLighting = grayscaleSH9(float3(0.0, -1.0, 0.0));
				float topIndirectLighting 	 = grayscaleSH9(float3(0.0, 1.0, 0.0));

				float grayscaleDirectLighting = NdotL * grayscalelightcolor * attenuation + grayscaleSH9(normalDirection);

				float lightDifference = topIndirectLighting + grayscalelightcolor - bottomIndirectLighting;
				float remappedLight   = (grayscaleDirectLighting - bottomIndirectLighting) / lightDifference;

				float3 indirectLighting = ((ShadeSH9_mod(half4(0.0, -1.0, 0.0, 1.0)))); 
				float3 directLighting   = ((ShadeSH9_mod(half4(0.0,  1.0, 0.0, 1.0)) + _LightColor0.rgb)) ;
				directLighting += i.vertexLight;
				indirectLighting += i.vertexLight;

				#if defined(_FRESNEL)
				// Not used, see below.
				//fresnelEffect = fresnelEffect * indirectLighting + directLighting * fresnelEffect * diffuseColor;
				#endif

				// Todo: Only if shadow mask is selected?
				#if 1
				float4 shadowMask = tex2D(_ShadowMask,TRANSFORM_TEX(i.uv0, _ShadowMask));
				#endif
				#if 1
				// Shadow mask handling
				// RGB will boost shadow range. Raising _Shadow reduces its influence.
				// Alpha will boost light range. Raising _Shadow increases its influence.
				remappedLight = min(remappedLight, (remappedLight * shadowMask)+_Shadow);
				remappedLight = max(remappedLight, (remappedLight * (1+_Shadow-shadowMask.w)));
				#endif

				// Shadow appearance setting
				remappedLight = saturate(_ShadowLift + remappedLight * (1-_ShadowLift));

				// Remove light influence from outlines. 
				//remappedLight = i.is_outline? 0 : remappedLight;

				float3 lightContribution = 1;
				#if 1
					// Apply lightramp to lighting
					lightContribution = tex2D(_LightingRamp, saturate(
						#if _LIGHTRAMP_VERTICAL
						float2( 0.0, remappedLight)
						#else
						float2( remappedLight, 0.0)
						#endif
						) );
				#else
					// Lighting without lightramp
					#if 1
						// This produces more instructions, but also an antialiased edge. 
						float shadeWidth = max(fwidth(remappedLight), 0.01);

						// Create two variables storing values similar to 0.49 and 0.51 that the fractional part
						// of the lighting is squeezed into. Then add the non-fractional part to the result.
						// Using fwidth (which should be cheap), we can come up with a gradient
						// about the size of 2 pixels in screen space at minimum.
						// Note: This might be slower than just sampling a light ramp. 

						float2 shadeOffset = 0.50 + float2(-shadeWidth, shadeWidth); 
						lightContribution = smoothstep(shadeOffset.x, shadeOffset.y, frac(remappedLight)); 
						lightContribution += floor(remappedLight);
					#else
						// Cubed's original
						//lightContribution = saturate((1.0 - _Shadow) + floor(saturate(remappedLight) * 2.0)); 
						lightContribution = saturate(floor(saturate(remappedLight) * 2.0)); 
					#endif
				#endif

				// Apply indirect lighting shift.
				lightContribution = lightContribution*(1-_IndirectLightingBoost)+_IndirectLightingBoost;
				// Give indirect specular a sharp edge.
				//float specTerm = smoothstep(fresStep.x-0.25, fresStep.y+0.25, rlPow4.y);

				#if defined(_MATCAP)
					// Based on Masataka SUMI's implementation
				    half3 worldUp = float3(0, 1, 0);
				    half3 worldViewUp = normalize(worldUp - viewDirection * dot(viewDirection, worldUp));
				    half3 worldViewRight = normalize(cross(viewDirection, worldViewUp));
				    half2 matcapUV = half2(dot(worldViewRight, normalDirection), dot(worldViewUp, normalDirection)) * 0.5 + 0.5;
				
					float3 AdditiveMatcap = tex2D(_AdditiveMatcap, matcapUV);
					float3 MultiplyMatcap = tex2D(_MultiplyMatcap, matcapUV);
					diffuseColor.xyz = lerp(diffuseColor.xyz, diffuseColor.xyz*MultiplyMatcap, _MultiplyMatcapStrength);
					diffuseColor.xyz += grayscaleDirectLighting*AdditiveMatcap*_AdditiveMatcapStrength;
				#endif

				/*
				 This section is messy. I've tried to make it roughly fit Unity's
				 PBR rendering, but PBR is complex and hard to grasp with the
				 available information...
				*/
				// "horizon occlusion with falloff, should be computed for direct specular too"
				float horizon = min(1.0 + dot(reflDir, normalDirection), 1.0);
				//specularContribution *= horizon * horizon;

				specularContribution *= reflectionMap;
				// Adjust the colour of reflections depending on how metal an object is. 
				// Metallic objects have tinted reflections, while nonmetals don't. 
				//reflectionMap = lerp(reflectionMap*specColor, reflectionMap, oneMinusReflectivity);
				reflectionMap = lerp(reflectionMap*baseColor, reflectionMap, oneMinusReflectivity);
				//reflectionMap *= directReflectance;

				float3 indirectContribution = 
				//(diffuseColor*oneMinusReflectivity // Breaks specular maps used for explicit highlights.
				(diffuseColor
					+ specularContribution) * indirectLighting;

				// Unity-style indirect lighting
				// Disabled for outlines, because they're always edges. 
				indirectContribution +=
					//lerp(specColor, grazingTerm, specTerm)
					lerp(specColor, grazingTerm, rlPow4.y)					
					* (1-lightContribution) * indirectLighting * reflectionMap * horizon;
				
				float3 directContribution = (diffuseColor + specularContribution)
					* lightContribution * directLighting;

				half surfaceReduction = 1.0 / (_Smoothness_var*_Smoothness_var + 1);
				float3 tertiaryContribution = surfaceReduction * reflectionMap * FresnelLerpFast(specColor, grazingTerm, NdotV);
				//tertiaryContribution *= horizon * horizon;

				float3 finalColor = directContribution + (emissive + indirectContribution + tertiaryContribution) * !i.is_outline;

				finalColor *= 1+fresnelEffect;

				//finalColor = float3(i.matcap.x, i.matcap.y, 0.5);

				fixed4 finalRGBA = fixed4(finalColor * lightmap, baseColor.a);
				UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
				return finalRGBA;
			}
			ENDCG
		}


		Pass
		{
			Name "FORWARD_DELTA"
			Tags { "LightMode" = "ForwardAdd" }
			Blend [_SrcBlend] One

			CGPROGRAM
			#pragma shader_feature NO_OUTLINE TINTED_OUTLINE COLORED_OUTLINE
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#include "FlatLitToonCore.cginc"
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag

			#pragma multi_compile_fwdadd_fullshadows
			#pragma multi_compile_fog

			float4 frag(VertexOutput i) : COLOR
			{
				float4 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
				i.normalDir = normalize(i.normalDir);
				float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
				float3 _BumpMap_var = UnpackNormal(tex2D(_BumpMap,TRANSFORM_TEX(i.uv0, _BumpMap)));
				float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform)); // Perturbed normals
				float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));
				
				float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);
				float3 lightColor = _LightColor0.rgb;
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
			ENDCG
		}

		Pass
		{
			Name "SHADOW_CASTER"
			Tags{ "LightMode" = "ShadowCaster" }

			ZWrite On ZTest LEqual

			CGPROGRAM
			#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
			#include "FlatLitToonShadows.cginc"
			
			#pragma multi_compile_shadowcaster

			#pragma vertex vertShadowCaster
			#pragma fragment fragShadowCaster
			ENDCG
		}
	}
	FallBack "Diffuse"
	CustomEditor "FlatLitToon.Unity.Inspector"
}