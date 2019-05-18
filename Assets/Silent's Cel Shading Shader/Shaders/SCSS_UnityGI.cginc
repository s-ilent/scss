// Altered UnityGI calculations for higher quality light probe sampling.
#ifndef SCSS_UNITYGI_INCLUDED
#define SCSS_UNITYGI_INCLUDED

/* http://www.geomerics.com/wp-content/uploads/2015/08/CEDEC_Geomerics_ReconstructingDiffuseLighting1.pdf */
float shEvaluateDiffuseL1Geomerics_local(float L0, float3 L1, float3 n)
{
	// average energy
	float R0 = L0;

	// avg direction of incoming light
	float3 R1 = 0.5f * L1;

	// directional brightness
	float lenR1 = length(R1);

	// linear angle between normal and direction 0-1
	//float q = 0.5f * (1.0f + dot(R1 / lenR1, n));
	//float q = dot(R1 / lenR1, n) * 0.5 + 0.5;
	float q = dot(normalize(R1), n) * 0.5 + 0.5;
	q = saturate(q); // Thanks to ScruffyRuffles for the bug identity.

	// power for q
	// lerps from 1 (linear) to 3 (cubic) based on directionality
	float p = 1.0f + 2.0f * lenR1 / R0;

	// dynamic range constant
	// should vary between 4 (highly directional) and 0 (ambient)
	float a = (1.0f - lenR1 / R0) / (1.0f + lenR1 / R0);

	return R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p));
}

inline UnityGI UnityGlobalIllumination_SCSS (UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
{
    UnityGI o_gi = UnityGI_Base(data, occlusion, normalWorld);
	#if defined(SAMPLE_SH_NONLINEAR) 
	    float3 L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
	    float3 nonLinearSH = float3(0,0,0); 
	    nonLinearSH.r = shEvaluateDiffuseL1Geomerics_local(L0.r, unity_SHAr.xyz, normalWorld);
	    nonLinearSH.g = shEvaluateDiffuseL1Geomerics_local(L0.g, unity_SHAg.xyz, normalWorld);
	    nonLinearSH.b = shEvaluateDiffuseL1Geomerics_local(L0.b, unity_SHAb.xyz, normalWorld);
	    nonLinearSH = max(nonLinearSH, 0);
	    o_gi.indirect.diffuse += nonLinearSH * occlusion;
    #endif
    o_gi.indirect.specular = UnityGI_IndirectSpecular(data, occlusion, glossIn);
    return o_gi;
}

UnityGI GetUnityGI(float3 lightColor, float3 lightDirection, float3 normalDirection,float3 viewDirection, 
float3 viewReflectDirection, float attenuation, float roughness, float3 worldPos){
    UnityLight light;
    light.color = lightColor;
    light.dir = lightDirection;
    light.ndotl = max(0.0h,dot( normalDirection, lightDirection));
    UnityGIInput d = (UnityGIInput) 0;
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
    UnityGI gi = UnityGlobalIllumination_SCSS(d, 1.0h, normalDirection, ugls_en_data );
    return gi;
}

half3 BetterSH9 (half4 normal) {
	float3 indirect;
	float3 L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
	indirect.r = shEvaluateDiffuseL1Geomerics_local(L0.r, unity_SHAr.xyz, normal);
	indirect.g = shEvaluateDiffuseL1Geomerics_local(L0.g, unity_SHAg.xyz, normal);
	indirect.b = shEvaluateDiffuseL1Geomerics_local(L0.b, unity_SHAb.xyz, normal);
	indirect = max(0, indirect);
	return indirect;

}
#endif // SCSS_UNITYGI_INCLUDED