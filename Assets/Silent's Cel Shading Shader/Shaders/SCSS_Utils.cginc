#ifndef SCSS_UTILS_INCLUDED
#define SCSS_UTILS_INCLUDED

float interleaved_gradient(float2 uv : SV_POSITION) : SV_Target
{
	float3 magic = float3(0.06711056, 0.00583715, 52.9829189);
	return frac(magic.z * frac(dot(uv, magic.xy)));
}

float Dither17(float2 Pos, float FrameIndexMod4)
{
    // 3 scalar float ALU (1 mul, 2 mad, 1 frac)
    return frac(dot(float3(Pos.xy, FrameIndexMod4), uint3(2, 7, 23) / 17.0f));
}

float max3 (float3 x) 
{
	return max(x.x, max(x.y, x.z));
}

// "R2" dithering

// Triangle Wave
float T(float z) {
    return z >= 0.5 ? 2.-2.*z : 2.*z;
}

// R dither mask
float intensity(float2 pixel) {
    const float a1 = 0.75487766624669276;
    const float a2 = 0.569840290998;
    return frac(a1 * float(pixel.x) + a2 * float(pixel.y));
}

float rDither(float gray, float2 pos) {
	#define steps 8
	// pos is screen pixel position in 0-res range
    // Calculated noised gray value
    float noised = (2./steps) * T(intensity(float2(pos.xy))) + gray - (1./steps);
    // Clamp to the number of gray levels we want
    return floor(steps * noised) / (steps-1.);
    #undef steps
}

// "R2" dithering -- end

inline float3 BlendNormalsPD(float3 n1, float3 n2) {
	return normalize(float3(n1.xy*n2.z + n2.xy*n1.z, n1.z*n2.z));
}

float2 sharpSample( float2 texResolution , float2 p )
{
	p = p*texResolution;
	float2 i = floor(p);
	p = i + smoothstep(0, max(0.0001, fwidth(p)), frac(p));
	p = (p - 0.5)/texResolution;
	return p;
}

bool inMirror()
{
	return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
}

#endif // SCSS_UTILS_INCLUDED