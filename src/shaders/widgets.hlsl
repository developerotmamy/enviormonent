// widgets.hlsl - gauges, sparkline, bars, clock ring. All analytic SDFs:
// zero geometry, zero textures, thousands of shapes at trivial GPU cost.
#include "dashboard.hlsli"

#define MAX_BARS 16

cbuffer WidgetCB : register(b2)
{
    // gauge (speedometer): center uv, radius uv-x, value 0..1
    float4 g_Gauge;      // xy center, z radius (aspect units), w value
    float4 g_Clock;      // xy center, z radius, w seconds/60
    float4 g_RingPos;    // xy center, z radius, w load 0..1
    float4 g_BarsMeta;   // xy origin uv (bottom-left), z bar width uv, w gap uv
    int    g_BarCount;
    float  g_BarH[MAX_BARS]; // normalized heights
    float  g_Pad2[3];
    float2 g_SparkTL;    // top-left uv of sparkline box
    float2 g_SparkBR;    // bottom-right uv
    int    g_SparkN;     // sample count (<= 96)
    int    g_Pad3;
    float  g_SparkData[96];
};

float angOf(float2 d) { return atan2(d.y, d.x); }

// ---- speedometer arc with ticks + glowing needle -----------------------------
float4 DrawGauge(float2 uv, float2 res)
{
    float2 pc = (g_Gauge.xy - 0.5) * float2(res.x / res.y, 1.0);
    float2 p  = (uv - 0.5) * float2(res.x / res.y, 1.0);
    float2 d = p - pc;
    float r = g_Gauge.z;
    float val = saturate(g_Gauge.w);
    float px = 1.0 / res.y;

    float a = angOf(d);                 // -pi..pi
    float rr = length(d);

    // sweep from 135deg down-left, clockwise 270deg
    const float A0 = 2.35619;           // 135 deg
    float t = A0 - a;                   // clockwise param
    t = fmod(t + 6.28318, 6.28318);     // 0..2pi
    float span = 4.71239;               // 270 deg
    if (t > span) return float4(0,0,0,0);
    float u = t / span;                 // 0..1 along the arc

    // track ring
    float band = exp(-pow((rr - r) / (px * 3.0), 2.0));
    float4 col = float4(0.10, 0.16, 0.26, 1.0) * band * step(u, 1.0);

    // progress arc: cyan -> magenta heat ramp
    float3 hot = lerp(float3(0.10, 0.85, 1.0), float3(1.0, 0.25, 0.55), smoothstep(0.55, 1.0, u));
    float prog = band * step(u, val) * step(0.0, u);
    col.rgb += hot * prog * 1.6;
    col.a    = max(col.a, prog);

    // ticks every 1/10 of span
    float angPx = px / max(rr, 1e-5);            // angular width of one pixel at this radius
    for (int k = 0; k <= 10; ++k)
    {
        float tu = k / 10.0;
        if (fabs(u - tu) < angPx * 1.6)
        {
            float tk = step(r * 0.78, rr) * step(rr, r * 1.02);
            col.rgb += float3(0.6, 0.8, 1.0) * tk * (tu <= val ? 1.4 : 0.35);
            col.a = max(col.a, tk * 0.9);
        }
    }

    // needle: distance to segment from hub to rim
    float na = A0 - val * span;
    float2 dir = float2(cos(na), sin(na));
    float2 q = d;                       // point rel center
    float proj = clamp(dot(q, dir) / r, 0.0, 1.0);
    float dist = length(q - dir * proj * r * 0.92);
    float needle = exp(-pow(dist / (px * 1.6), 2.0)) * step(proj, 0.98);
    col.rgb += float3(1.0, 0.9, 0.55) * needle * 2.0;
    col.a = max(col.a, needle);

    // hub dot
    float hub = exp(-pow(rr / (px * 3.5), 2.0));
    col.rgb += float3(0.9, 0.95, 1.0) * hub;
    col.a = max(col.a, hub);

    return col;
}

// ---- donut ring (CPU load) -----------------------------------------------------
float4 DrawRing(float2 uv, float2 res)
{
    float2 pc = (g_RingPos.xy - 0.5) * float2(res.x / res.y, 1.0);
    float2 p  = (uv - 0.5) * float2(res.x / res.y, 1.0);
    float2 d = p - pc;
    float r = g_RingPos.z;
    float load = saturate(g_RingPos.w);
    float px = 1.0 / res.y;

    float rr = length(d);
    float a = fmod(angOf(d) - 1.5708 + 6.28318, 6.28318);
    float u = a / 6.28318;

    float band = exp(-pow((rr - r) / (px * 4.0), 2.0));
    float on = step(u, load);
    float3 c = lerp(float3(0.15, 0.9, 0.6), float3(1.0, 0.35, 0.2), smoothstep(0.6, 0.95, load));
    float4 col = float4(c * 1.5 * band * on, band * on);
    float off = band * (1.0 - on) * 0.5;
    col.rgb += float3(0.12, 0.18, 0.3) * off;
    col.a = max(col.a, off);
    return col;
}

// ---- clock ring ----------------------------------------------------------------
float4 DrawClock(float2 uv, float2 res)
{
    float2 pc = (g_Clock.xy - 0.5) * float2(res.x / res.y, 1.0);
    float2 p  = (uv - 0.5) * float2(res.x / res.y, 1.0);
    float2 d = p - pc;
    float r = g_Clock.z;
    float sec = g_Clock.w; // 0..60 fractional
    float px = 1.0 / res.y;
    float rr = length(d);

    float ring = exp(-pow((rr - r) / (px * 1.6), 2.0));
    float4 col = float4(float3(0.2, 0.35, 0.6) * ring, ring * 0.8);

    // sweeping head glow
    float a = fmod(angOf(d) - 1.5708 + 6.28318, 6.28318);
    float su = sec / 60.0 * 6.28318;
    float da = fabs(fmod(a - su + 9.42477, 6.28318) - 3.14159);
    float head = exp(-pow(da * r / (px * 6.0), 2.0)) * ring;
    col.rgb += float3(0.3, 1.0, 0.9) * head * 2.0;
    col.a = max(col.a, head);

    // hour ticks
    float angPx = px / max(rr, 1e-5);
    for (int k = 0; k < 12; ++k)
    {
        float ta = k / 12.0 * 6.28318;
        float pa = fabs(fmod(a - ta + 9.42477, 6.28318) - 3.14159);
        float tick = step(pa, angPx * 1.5) * step(r * 0.86, rr) * step(rr, r);
        col.rgb += float3(0.7, 0.85, 1.0) * tick * (k % 3 == 0 ? 1.6 : 0.6);
        col.a = max(col.a, tick * 0.9);
    }
    return col;
}

// ---- sparkline -----------------------------------------------------------------
float4 DrawSpark(float2 uv, float2 res)
{
    float2 tl = g_SparkTL, br = g_SparkBR;   // uv box; y measured from BOTTOM (OpenGL-style)
    if (any(uv < min(tl, br) - 0.002) || any(uv > max(tl, br) + 0.002))
        return float4(0, 0, 0, 0);

    float px = 1.0 / res.y;
    float2 box = br - tl;
    float2 local = (uv - tl) / box;          // 0..1 in box, y grows UPWARD
    int n = g_SparkN;
    if (n < 2) return float4(0,0,0,0);

    // interpolate polyline height
    float x = saturate(local.x) * (n - 1);
    int i0 = min(int(floor(x)), n - 2);
    float f = x - i0;
    float y0 = g_SparkData[i0], y1 = g_SparkData[i0 + 1];
    float yy = lerp(y0, y1, f);

    // area fill under curve (yy is height from box bottom; local.y grows upward)
    float fill = step(local.y, yy);
    float4 col = float4(0.1, 0.8, 1.0, 0.0);
    col.rgb *= fill * (0.10 + 0.35 * (local.y / max(yy, 1e-4)));
    col.a = fill * 0.30;

    // stroke
    float dist = fabs(local.y - yy) * abs(box.y) * res.y; // pixels
    float stroke = exp(-pow(dist / 1.6, 2.0));
    col.rgb += float3(0.35, 0.95, 1.0) * stroke * 1.8;
    col.a = max(col.a, stroke);

    // leading dot pulse at last sample
    float dx = fabs(local.x - 1.0) * abs(box.x) * res.x;
    float dy = fabs(local.y - g_SparkData[n - 1]) * abs(box.y) * res.y;
    float dot = exp(-(dx * dx + dy * dy) / (px * px * 30.0));
    col.rgb += float3(1.0, 0.9, 0.4) * dot * 2.0;
    col.a = max(col.a, dot);
    return col;
}

// ---- equalizer bars --------------------------------------------------------------
float4 DrawBars(float2 uv, float2 res)
{
    // g_BarsMeta: x = left edge uv, y = bottom edge uv (uv.y grows up),
    //             z = pitch uv (bar+gap), w = bar width uv
    float2 org = g_BarsMeta.xy;
    float pitch = g_BarsMeta.z, bw = g_BarsMeta.w;
    if (uv.x < org.x || uv.x > org.x + pitch * g_BarCount) return float4(0,0,0,0);
    if (uv.y > org.y + 0.30 || uv.y < org.y - 0.005) return float4(0,0,0,0);

    float slot = (uv.x - org.x) / pitch;
    int i = int(floor(slot));
    if (i < 0 || i >= g_BarCount) return float4(0,0,0,0);
    float fx = slot - i;                       // 0..1 inside slot
    if (fx > bw / pitch) return float4(0,0,0,0);

    float h = max(g_BarH[i], 0.03) * 0.26;     // bar height in uv units (y grows up)
    float bot = org.y - h;                     // bottom edge of the bar

    // rounded box in aspect-corrected space, spanning [bot, org.y]
    float2 c = float2(org.x + i * pitch + bw * 0.5, (org.y + bot) * 0.5);
    float2 d = (uv - c) * float2(res.x / res.y, 1.0);
    float2 hs = float2(bw * 0.5 * (res.x / res.y), h * 0.5);
    float sd = sdRoundBox(d, hs, min(hs.x * 0.6, 0.006));
    float px = 1.0 / res.y;
    float m = aaMask(sd, px * 1.3);
    if (m <= 0) return float4(0,0,0,0);

    float grad = saturate((org.y - uv.y) / max(h, 1e-4));
    float3 c2 = lerp(float3(0.15, 0.5, 1.0), float3(0.9, 0.2, 0.9), grad);
    return float4(c2 * (0.7 + 0.8 * grad), m * 0.95);
}

float4 PSWidgets(VSOut i) : SV_Target
{
    float2 uv = i.uv, res = g_Resolution;
    float4 acc = float4(0, 0, 0, 0);

    float4 c;
    c = DrawGauge(uv, res); acc = c;
    c = DrawRing(uv, res);  if (c.a > acc.a) acc = c;
    c = DrawClock(uv, res); if (c.a > acc.a) acc = c;
    c = DrawSpark(uv, res); if (c.a > acc.a) acc = c;
    c = DrawBars(uv, res);  if (c.a > acc.a) acc = c;
    return acc;
}
