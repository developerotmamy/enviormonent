// panels.hlsl - glassmorphism card layer: rounded translucent panels,
// hairline borders, top sheen. One pass draws every panel from a uniform-array
// of rects (CPU side packs up to 24 visible cards).
#include "dashboard.hlsli"

#define MAX_PANELS 24

cbuffer PanelCB : register(b1)
{
    float4 g_Panels[MAX_PANELS]; // xy = center uv, zw = halfsize uv
    int    g_PanelCount;
    int    g_HoverPanel;
    int2   g_Pad;
};

float4 PSPanels(VSOut i) : SV_Target
{
    float2 uv = i.uv;
    float2 res = g_Resolution;
    float px = 1.0 / res.y; // one pixel in NDC-ish aspect units below

    float4 acc = float4(0, 0, 0, 0);

    for (int n = 0; n < g_PanelCount && n < MAX_PANELS; ++n)
    {
        float4 pn = g_Panels[n];
        // work in aspect-corrected space so corner radius is circular
        float2 c = pn.xy;
        float2 hs = pn.zw * float2(res.x / res.y, 1.0);
        float2 p = (uv - 0.5) * float2(res.x / res.y, 1.0);
        float2 pc = (c - 0.5) * float2(res.x / res.y, 1.0);
        float2 d = p - pc;

        float radius = min(min(hs.x, hs.y) * 0.16, 0.02);
        float sd = sdRoundBox(d, hs, radius);
        float w = px * 1.4;

        float inside = aaMask(sd, w);
        if (inside <= 0.0) continue;

        bool hovered = (n == g_HoverPanel);
        float glow = hovered ? 1.0 : 0.0;

        // frosted glass fill
        float3 fill = lerp(float3(0.070, 0.095, 0.150), float3(0.10, 0.14, 0.22), glow);
        // vertical sheen: brighter at top edge
        float sheen = smoothstep(-hs.y, hs.y, d.y) * 0.10;
        fill += sheen;

        // hairline border ring
        float border = saturate(1.0 - abs(sd) / (w * 1.8));
        border *= step(-w * 1.2, sd);
        float3 bcol = lerp(float3(0.25, 0.55, 0.85), g_Tint.rgb, 0.35 + 0.5 * glow);

        // outer soft shadow under the card
        float shadow = aaMask(sd - 0.006, w * 3.0) * 0.35;

        float4 over;
        over.rgb = lerp(fill, bcol, border * 0.9);
        over.a = inside * (0.62 + 0.12 * glow) + border * 0.35 + shadow * inside;
        // painter's order with real alpha blending: later cards composite over earlier
        acc.rgb = lerp(acc.rgb, over.rgb, over.a);
        acc.a = saturate(acc.a + over.a * (1.0 - acc.a));
    }
    return acc;
}
