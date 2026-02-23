#ifndef GLINTY_NDF_INCLUDED
#define GLINTY_NDF_INCLUDED

// "Evaluating and Sampling Glinty NDFs in Constant Time"
// Based on Kemppinen et al. 2025
static const float GLINT_PI = 3.14159265358979;
static const half HALF_PI = 3.14159265h;

// --- Internal Utilities ---

half2 lambert_map(float3 v) {
    return (half2)(v.xy / sqrt(1.0 + v.z));
}

// Maps GGX NDF to a 2D disk
float3 ndf_to_disk_ggx(float3 v, float alpha) {
    float3 hemi = float3(v.xy / alpha, v.z);
    float denom = dot(hemi, hemi);
    half2 v_disk = lambert_map(normalize(hemi)) * 0.5h + 0.5h;
    float jacobian_determinant = 1.0 / (alpha * alpha * denom * denom);
    return float3(v_disk, jacobian_determinant);
}

// 2x2 Inverse
float2x2 inverse2x2(float2x2 m) {
    float det = m._m00 * m._m11 - m._m01 * m._m10;
    return float2x2(m._m11, -m._m01, -m._m10, m._m00) / det;
}

float2x2 inv_quadratic(float2x2 M) {
    float D = determinant(M);
    float2 col0 = float2(M._m00, M._m10) / D;
    float2 col1 = float2(M._m01, M._m11) / D;

    float A = dot(col0, col0);
    float B = -dot(col0, col1);
    float C = dot(col1, col1);
    return float2x2(C, B, B, A);
}

// Converts UV Jacobian into an anisotropy-aware ellipsoid matrix
float2x2 get_uv_ellipsoid(float2x2 uv_J) {
    float2x2 Q = inv_quadratic(transpose(uv_J));
    float tr = 0.5 * (Q._m00 + Q._m11);
    float D = sqrt(max(0.0, tr * tr - determinant(Q)));
    float l1 = tr - D;
    float l2 = tr + D;

    float2 v1 = float2(l1 - Q._m11, Q._m10);
    float2 v2 = float2(Q._m01, l2 - Q._m00);
    float2 n = 1.0 / sqrt(float2(l1, l2));

    float2 col0 = normalize(v1) * n.x;
    float2 col1 = normalize(v2) * n.y;
    // Constructing column-major equivalent for the math later
    return float2x2(col0.x, col1.x, col0.y, col1.y);
}

float query_lod(float2x2 uv_J, float filter_size) {
    float s0 = length(float2(uv_J._m00, uv_J._m10));
    float s1 = length(float2(uv_J._m01, uv_J._m11));
    return log2(max(s0, s1) * filter_size) + pow(2.0, filter_size);
}

uint2 shuffle_hash(uint2 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> 16u);
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> 16u);
    return v;
}

half2 rand2d(float2 x, float2 y, float l, uint i) {
    uint2 ux = asuint(x), uy = asuint(y);
    uint ul = asuint(l);
    uint2 seed = (ux >> 16u | ux << 16u) ^ uy ^ ul ^ (i * 0x124u);
    // Cast to half2 since random output is strictly [0, 1]
    return (half2)(float2(shuffle_hash(seed)) * pow(0.5, 32.0));
}

half rand1d(float2 x, float2 y, float l, uint i) {
    return rand2d(x, y, l, i).x;
}

half fast_erf(half x) {
    half e = exp(-x * x);
    half sign_x = sign(x);
    // Constants pre-calculated to half precision
    half scale = sqrt((1.0h - e) / HALF_PI);
    half poly = 0.886226h + 0.155h * e - 0.042625h * e * e; // (sqrt(pi)/2), (31/200), (341/8000)
    return sign_x * 2.0h * scale * poly;
}

half gaussian_cdf(float x, float mu, float sigma) {
    float z = (x - mu) / (sigma * 1.41421356);
    return 0.5h + 0.5h * fast_erf((half)z);
}

half integrate_interval(float x, float size, float mu, float stdev, float lower_limit, float upper_limit) {
    return gaussian_cdf(min(x + size, upper_limit), mu, stdev) - gaussian_cdf(max(x - size, lower_limit), mu, stdev);
}

half integrate_box(float2 x, float2 size, float2 mu, float2x2 sigma, float2 lower_limit, float2 upper_limit) {
    return integrate_interval(x.x, size.x, mu.x, sqrt(sigma._m00), lower_limit.x, upper_limit.x) *
           integrate_interval(x.y, size.y, mu.y, sqrt(sigma._m11), lower_limit.y, upper_limit.y);
}

half glint_compensation(float2 x_a, float2x2 sigma_a, float res_a) {
    half containing = integrate_box(0.5f.xx, 0.5f.xx, x_a, sigma_a, 0.0f.xx, 1.0f.xx);
    half explicitly_evaluated = integrate_box(round(x_a * res_a) / res_a, (1.0 / res_a).xx, x_a, sigma_a, 0.0f.xx, 1.0f.xx);
    return containing - explicitly_evaluated;
}

float eval_normal(float2x2 cov, float2 x) {
    float2x2 inv_cov = inverse2x2(cov);
    return exp(-0.5 * dot(x, mul(inv_cov, x))) / (sqrt(determinant(cov)) * 2.0 * GLINT_PI);
}

// --- Public Interface ---

/**
 * Main Glinty NDF Function
 * @param h             Local space half-vector
 * @param alpha         Macro-roughness (standard GGX roughness)
 * @param glint_alpha   Micro-roughness (the size/sharpness of individual glints, e.g., 0.01)
 * @param uv            Surface UV coordinates
 * @param uv_J          Jacobian of the UVs (use get_uv_ellipsoid(float2x2(ddx(uv), ddy(uv))))
 * @param glint_density Scaling factor for glint particles (e.g., 1000 to 1000000)
 * @param filter_size   Standard pixel filter size (e.g., 0.7 to 1.2)
 */
float EvaluateGlintyNDF(float3 h, float alpha, float glint_alpha, float2 uv, float2x2 uv_J, float glint_density, float filter_size) {
    float res = sqrt(glint_density);
    float2 x_s = uv;
    float3 x_a_and_d = ndf_to_disk_ggx(h, alpha);
    float2 x_a = x_a_and_d.xy;
    float d = x_a_and_d.z;

    float lambda = query_lod(res * uv_J, filter_size);
    float D_filter = 0.0;

    for(float m = 0.0; m < 2.0; m += 1.0) {
        float l = floor(lambda) + m;
        half w_lambda = (half)(1.0 - abs(lambda - l));

        float res_s = res * exp2(-l);
        float res_a = exp2(l);

        float2x2 uv_J2 = filter_size * uv_J;
        float2x2 sigma_s = mul(uv_J2, transpose(uv_J2));

        float det_J2 = determinant(uv_J2);
        float det_sigma_s = det_J2 * det_J2;
        float2x2 inv_sigma_s = float2x2(sigma_s._m11, -sigma_s._m01, -sigma_s._m10, sigma_s._m00) / det_sigma_s;

        float norm_s = 1.0 / (abs(det_J2) * 2.0 * GLINT_PI * glint_density);

        float var_a = d * glint_alpha * glint_alpha;
        float norm_a = 1.0 / (var_a * 2.0 * GLINT_PI);
        float stdev_a = sqrt(var_a);

        float2 base_i_a = clamp(round(x_a * res_a), 1.0, res_a - 1.0);

        for(int j_a = 0; j_a < 4; ++j_a) {
            half2 offset_a = (half2)(float2(j_a & 1, j_a >> 1) - 0.5);
            float2 i_a = base_i_a + offset_a;

            float2 base_i_s = round(x_s * res_s);

            for(int j_s = 0; j_s < 4; ++j_s) {
                half2 offset_s = (half2)(float2(j_s & 1, j_s >> 1) - 0.5);
                float2 i_s = base_i_s + offset_s;

                float2 g_s = (i_s + rand2d(i_s, i_a, l, 1u) - 0.5) / res_s;
                float2 g_a = (i_a + rand2d(i_s, i_a, l, 2u) - 0.5) / res_a;

                half r = rand1d(i_s, i_a, l, 4u);
                half roulette = smoothstep(max(0.0h, r - 0.1h), min(1.0h, r + 0.1h), w_lambda);

                float2 delta_a = x_a - g_a;
                float eval_a = exp(-0.5 * dot(delta_a, delta_a) / var_a) * norm_a;

                float2 delta_s = x_s - g_s;
                float eval_s = exp(-0.5 * dot(delta_s, mul(inv_sigma_s, delta_s))) * norm_s;

                D_filter += roulette * eval_a * eval_s;
            }
        }
        D_filter += w_lambda * glint_compensation(x_a, stdev_a, res_a);
    }

    return D_filter * d / GLINT_PI;
}

/*** Sample implementation...

// 1. Setup Inputs
float3 V = normalize(_WorldSpaceCameraPos - input.worldPos);
float3 L = normalize(_MainLightPosition.xyz);
float3 H = normalize(V + L);
float3 N = normalize(input.normal);

// Transform H to local tangent space
float3 tangentH = WorldToTangent(H, input.tangent, input.bitangent, N);

// 2. Prepare Derivatives for Anisotropic Filtering
float2x2 Jacobian = float2x2(ddx(input.uv), ddy(input.uv));
float2x2 uv_ellipsoid = get_uv_ellipsoid(Jacobian);

// 3. Evaluate NDF
// alpha: standard roughness (0.1 - 0.8)
// glint_alpha: micro-roughness (0.005 - 0.05)
// glint_density: how many particles (10^4 to 10^9)
float D = EvaluateGlintyNDF(
    tangentH,
    _Roughness,
    _GlintMicroRoughness,
    input.uv,
    uv_ellipsoid,
    _GlintDensity,
    0.8 // Filter size
);

// 4. Standard BRDF integration
// Use D instead of the standard GGX D term in: (D * F * G) / (4 * NoV * NoL)
float NoL = saturate(dot(N, L));
float NoV = saturate(dot(N, V));
float3 spec = (D * F * G) / max(1e-4, 4.0 * NoV * NoL);
return float4(spec * NoL * _LightColor.rgb, 1.0);

***/

#endif
