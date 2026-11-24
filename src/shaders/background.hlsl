// background.hlsl - animated gradient + drifting fog + vignette
#include "dashboard.hlsli"

float4 PSBackground(VSOut i) : SV_Target
{
    float2 uv = i.uv;
    float2 p  = PixelAspect(uv, g_Resolution);

    // deep navy -> indigo vertical gradient with slow hue drift
    float t = g_Time * 0.05;
    float3 top = lerp(float3(0.030, 0.045, 0.090), float3(0.045, 0.030, 0.095), 0.5 + 0.5 * sin(t));
    float3 bot = float3(0.010, 0.014, 0.028);
    float3 col = lerp(bot, top, smoothstep(0.0, 1.0, uv.y));

    // two soft moving glows (cyan accent + warm ember)
    float2 g1 = float2(0.62 + 0.10 * sin(g_Time * 0.21), 0.72 + 0.08 * cos(g_Time * 0.17));
    float2 g2 = float2(0.30 + 0.12 * cos(g_Time * 0.13), 0.25 + 0.10 * sin(g_Time * 0.19));
    float d1 = length(PixelAspect(g1, g_Resolution) - p);
    float d2 = length(PixelAspect(g2, g_Resolution) - p);
    col += float3(0.05, 0.16, 0.28) * exp(-d1 * d1 * 6.0);
    col += float3(0.16, 0.06, 0.02) * exp(-d2 * d2 * 9.0);

    // drifting fog: two octaves of value noise scrolling opposite ways
    float2 q = p * 3.0;
    float fog = vnoise(q + float2( t * 0.6, -t * 0.3)) * 0.6
              + vnoise(q * 2.3 + float2(-t * 0.4, t * 0.5)) * 0.4;
    col += float3(0.04, 0.07, 0.10) * (fog - 0.5);

    // subtle scanline texture + film grain for the "speed" feel
    col *= 1.0 - 0.03 * step(0.5, frac(uv.y * g_Resolution.y * 0.5));
    col += (hash21(uv * g_Resolution + frac(g_Time) * 91.7) - 0.5) * 0.015;

    // vignette
    float vig = smoothstep(1.35, 0.35, length(p * float2(1.0, 1.1)));
    col *= 0.35 + 0.65 * vig;

    return float4(max(col, 0.0), 1.0);
}
