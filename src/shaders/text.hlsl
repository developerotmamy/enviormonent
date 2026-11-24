// text.hlsl - procedural 5x7 bitmap font. No textures, no atlases: glyph bitmaps
// and strings live in one small constant buffer as packed ints. Crisp at any DPI.
#include "dashboard.hlsli"

#define FONT_INTS   (95 * 7)      // ascii 32..126, 7 rows each
#define STRING_INTS 1024          // dynamic string pool (4 bytes per int)
#define STR_BASE    FONT_INTS
#define MAX_RUNS    48

cbuffer TextCB : register(b3)
{
    int    g_Pack[FONT_INTS + STRING_INTS]; // glyph rows then string pool
    float4 g_Run[MAX_RUNS];   // xy = top-left uv, z = glyph pixel height, w = byte offset into pool
    int4   g_RunMeta[MAX_RUNS]; // x = char count, y = color id
    int    g_RunCount;
    int    g_PadT[3];
};

// colors: 0 title white, 1 label dim, 2 value cyan, 3 warn amber, 4 good green
float3 RunColor(int id)
{
    if (id == 1) return float3(0.55, 0.65, 0.8);
    if (id == 2) return float3(0.35, 0.95, 1.0);
    if (id == 3) return float3(1.0, 0.75, 0.3);
    if (id == 4) return float3(0.45, 1.0, 0.6);
    return float3(0.95, 0.97, 1.0);
}

int GlyphRow(int code, int row)
{
    if (code < 32 || code >= 127) return 0;
    return g_Pack[(code - 32) * 7 + row];
}

int StringByte(int idx)
{
    if (idx < 0 || idx >= STRING_INTS * 4) return 32;
    int word = g_Pack[STR_BASE + (idx >> 2)];
    return (word >> ((idx & 3) * 8)) & 0xFF;
}

float4 PSText(VSOut i) : SV_Target
{
    float2 uv = i.uv;
    float2 res = g_Resolution;
    float aspect = res.x / res.y;

    for (int r = 0; r < g_RunCount && r < MAX_RUNS; ++r)
    {
        float4 run = g_Run[r];
        int len = g_RunMeta[r].x;
        if (len <= 0) continue;

        float cellH = run.z / res.y;                 // glyph height in uv-y (y grows DOWN)
        float cellW = cellH * 0.75 / aspect;         // advance incl. spacing
        float2 st = run.xy;                          // top-left corner uv

        if (uv.x > st.x + cellW * len || uv.x < st.x) continue;
        if (uv.y < st.y - cellH || uv.y > st.y) continue;

        float2 rel = uv - float2(st.x, st.y - cellH); // origin at box BOTTOM-LEFT
        int ci = int(floor(rel.x / cellW));
        if (ci < 0 || ci >= len) continue;
        float2 cell = float2(rel.x / cellW - ci, rel.y / cellH);

        int code = StringByte(int(run.w) + ci);
        if (code == 32) continue;

        int gx = min(int(cell.x * 5.0), 4);          // 5 px wide
        int gy = min(int(cell.y * 7.0), 6);          // 7 px tall
        int rowbits = GlyphRow(code, gy);
        if (((rowbits >> (4 - gx)) & 1) == 0) continue;

        return float4(RunColor(g_RunMeta[r].y), 0.95);
    }
    return float4(0, 0, 0, 0);
}
