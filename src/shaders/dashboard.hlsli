// dashboard.hlsli - shared code for the DX11 dashboard (MSAA 8x, deferred-ish UI)
// Compiled with fxc.exe to /Fh headers. Keep C-preprocessor-friendly: no `#pragma once`.

cbuffer SceneCB : register(b0)
{
    float2 g_Resolution;   // pixels
    float  g_Time;         // seconds
       float g_Pad;
    float4 g_Tint;         // accent color
};

struct VSOut
{
    float4 pos : SV_Position;
    float2 uv  : TEXCOORD0;
};

VSOut VSFullscreen(uint id : SV_VertexID)
{
    VSOut o;
    // deterministic triangle trick: one big triangle, zero vertex buffers
    float2 uv = float2((id << 1) & 2, id & 2);
    o.pos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    o.uv = uv;
    return o;
}

float2 PixelAspect(float2 uv, float2 res)
{
    return (uv - 0.5) * float2(res.x / res.y, 1.0);
}

float sdRoundBox(float2 p, float2 b, float r)
{
    float2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float aaMask(float d, float w)
{
    return saturate(0.5 - d / max(w, 1e-6));
}

// hash-based value noise (cheap, tileable enough for background fog)
float hash21(float2 p)
{
    p = frac(p * float2(123.4327, 345.6789));
    p += dot(p, p + 34.56789);
    return frac(p.x * p.y);
}

float vnoise(float2 p)
{
    float2 i = floor(p), f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(hash21(i), hash21(i + float2(1, 0)), f.x),
                lerp(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), f.x), f.y);
}

// smooth pseudo-random in [0,1] keyed by integer n
float nrand(float n) { return frac(sin(n * 12.9898) * 43758.5453); }
