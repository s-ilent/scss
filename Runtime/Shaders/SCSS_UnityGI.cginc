#ifndef SCSS_UNITYGI_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_UNITYGI_INCLUDED

#ifndef FLT_EPS
#define FLT_EPS 1e-5
#endif

//------------------------------------------------------------------------------

// https://github.com/z3y/shaders/blob/d52e2831a82ffd7dba0a070edf6fad6b1a5d4ed3/Shaders/ShaderLibrary/EnvironmentBRDF.cginc
// Based on z3y's implementation of Filament's indirect specular distribution
Texture2D _DFG;
SamplerState sampler_DFG;

half3 PrefilteredDFG_LUT(half NoV, half perceptualRoughness)
{
    return _DFG.SampleLevel(sampler_DFG, float2(NoV, perceptualRoughness), 0);
}

half3 specularDFG(half3 dfg, half3 f0, bool isCloth = false)
{
    if (isCloth)
    {
        return f0 * dfg.zzz;
    }
    return lerp(dfg.xxx, dfg.yyy, f0);
}

half3 specularDFGEnergyCompensation(half3 dfg, half3 f0, bool isCloth = false)
{
    if (isCloth)
    {
        return 1.0;
    }
    return 1.0 + f0 * (1.0 / dfg.y - 1.0);
}

#endif // SCSS_UNITYGI_INCLUDED
