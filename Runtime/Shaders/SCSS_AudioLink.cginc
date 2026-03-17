#ifndef SCSS_AUDIOLINK_INCLUDED
// UNITY_SHADER_NO_UPGRADE
#define SCSS_AUDIOLINK_INCLUDED
// Reference the documentation at
// https://github.com/llealloo/vrc-udon-audio-link
// for more info.

#ifdef SHADER_TARGET_SURFACE_ANALYSIS
#define AUDIOLINK_COMPILE_COMPATIBILITY
#endif

#ifdef AUDIOLINK_COMPILE_COMPATIBILITY
uniform sampler2D  _AudioTexture;
#else
uniform Texture2D<float4> _AudioTexture;
uniform SamplerState sampler_AudioGraph_Linear_Clamp;
#endif

// Todo: Move _alFallbackBPM, _alUseFallback to parameters.

half al_lerpstep( half a, half b, half t)
{
    return saturate( ( t - a ) / ( b - a ) );
}

float2 audioLinkModifyTexcoord(float4 texelSize , float2 p)
{
    p = p*texelSize.zw;
    // Instead of a hard clamp, sharpen to a pixel width for glancing angles
    float2 c = max(0.0, abs(fwidth(p)));
    c.x = 1;
    p = p + abs(c);
    p = floor(p) + saturate(frac(p) / c);
    p = (p - 0.5)*texelSize.xy;
    return p;
}

half audioLinkRenderBar(half grad, half pulse)
{
    half2 deriv = abs(fwidth(grad));
    half step = deriv*0.5;
    return al_lerpstep(pulse, pulse + step, grad);
}

half al_expImpulse( half x, half k )
{
    const half h = k*x;
    return h*exp(1.0-h);
}
half al_parabola( half x, half k )
{
    return pow( 4.0*x*(1.0-x), k );
}

// Samples the AudioLink texture.
half sampleAudioTexture(half band, half delay, half range)
{
    // Initialisation.
    float2 audioLinkRes = 0;
    _AudioTexture.GetDimensions(audioLinkRes.x, audioLinkRes.y);

    if (audioLinkRes.x >= 128.0 && _alUseFallback != 2)
    {
        float2 params = float2(delay, band / 4.0);
        // We only want the bottom 4 bands.
        // When reading the texture, we want the bands to be thickly seperated.
        float2 alUV = params*float2(range,0.0625);
        alUV = audioLinkModifyTexcoord(float4(1.0/audioLinkRes, audioLinkRes), alUV);
        // sample the texture
        #ifdef AUDIOLINK_COMPILE_COMPATIBILITY
        return tex2Dlod(_AudioTexture, float4(alUV, 0, 0));
        #else
        return _AudioTexture.SampleLevel(sampler_AudioGraph_Linear_Clamp, alUV, 0);
        #endif
    } else {
        if (_alUseFallback != 0)
        {
            if (_alFallbackBPM == 0)
            {
                return 1;
            }
        // If not available, fake one.
        float beat = _alFallbackBPM / 60;
        float rowTiming = (4-band)/4.0;
        delay *= range;
        beat = (delay-_Time.y)*rowTiming*beat;
        beat = frac(-beat);
        beat = al_expImpulse(beat, 8.0);
        half s; half c;
        sincos(beat, s, c);
        half final = saturate(s+(0.5+c));
        //
        return final*beat;
        }
    }

    return 0;
}

half audioLinkGetLayer(half weight, const half range, const half band, const half mode)
{
    if (mode == 0) return weight * pow(sampleAudioTexture(band-1, 1-weight, range ), 2.0) * 2.0;
    if (mode == 1) return audioLinkRenderBar(weight, 1-sampleAudioTexture(band-1, 1-weight, range ));
    return 0;
}

#endif //SCSS_AUDIOLINK_INCLUDED
