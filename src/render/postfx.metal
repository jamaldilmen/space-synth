#include <metal_stdlib>
using namespace metal;

// ── Post-processing: HDR tonemap, bloom, chromatic aberration, trails ───────

struct PostFXUniforms {
    float2 resolution;
    float bloomIntensity;   // 0-1
    float trailDecay;       // 0-1 (0 = no trails)
    float chromaticAmount;  // 0-0.02 typical
    float time;             // seconds (animated glitch)
    float glitchAmount;     // 0-1 cyberpunk RGB block displacement
    float scanlineAmount;   // 0-1 CRT scanlines
    float neonGrade;        // 0-1 cyberpunk color grade
    float vignette;         // 0-1 edge darkening
    float audioLevel;       // 0-1 total amplitude (beat-reactive)
    // ── Resolume-style VJ effects ──
    float mirrorMode;       // 0 off, 1 H, 2 V, 3 quad
    float kaleidoSegments;  // 0 off, else segment count (2-16)
    float tileCount;        // <=1 off, else NxN repeat
    float twirl;            // swirl amount (-1..1)
    float hueShift;         // 0-1 hue rotation
    float strobe;           // 0-1 strobe depth
    float invert;           // 0-1 colour invert mix
    float posterize;        // 0 off, else colour levels (2-16)
    float edrHeadroom;      // display EDR headroom (1.0 = SDR), drives HDR glow
    float pixelStretch;     // 0-1 "5D look" radial pixel-stretch (driven by spin)
    float exposure;         // global HDR exposure multiplier (1.0 = neutral)
    float debugBypass;      // >0.5 = raw scene + plain Reinhard, whole chain skipped (whiteout bisect)
    // Scalars MUST stay a multiple of 4 so the float4x4s below keep their
    // 16-byte alignment on both sides. Was 24 (=96 B); now 28 (=112 B).
    float gradeAmount;      // 0-1 blend of the display grade LUT (0 = exact bypass)
    float gradePad0;
    float gradePad1;
    float gradePad2;
    float4x4 inverseViewProj;
    float4x4 prevViewProj;
};

// ── HSV helpers (Sam Hocevar / IQ) for hue-shift VJ effect ──────────────────
static float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    float4 p = mix(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = mix(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
static float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, saturate(p - K.xxx), c.y);
}

// ── Hash / noise helpers for glitch ─────────────────────────────────────────
static float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}
static float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

struct PostVertexOut {
    float4 position [[position]];
    float2 uv;
};

// ACES filmic tonemapping (approximation by Krzysztof Narkowicz)
static float3 acesTonemap(float3 x) {
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

vertex PostVertexOut postfx_vertex(uint vertexId [[vertex_id]]) {
    PostVertexOut out;
    float2 pos;
    pos.x = (vertexId == 1) ? 3.0 : -1.0;
    pos.y = (vertexId == 2) ? 3.0 : -1.0;
    out.position = float4(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5;
    out.uv.y = 1.0 - out.uv.y;  // Flip Y for Metal
    return out;
}

fragment float4 postfx_fragment(
    PostVertexOut in [[stage_in]],
    texture2d<float> currentFrame [[texture(0)]],
    texture2d<float> previousFrame [[texture(1)]],
    texture2d<float> bloomTex [[texture(2)]],
    texture2d<float> sceneAvgTex [[texture(3)]], // mipped HDR scene → top mip = frame average (auto-exposure)
    texture3d<float> gradeLut [[texture(4)]],    // display grade LUT (grade_lut.h bake), 33^3 RGBA16F
    constant PostFXUniforms& u [[buffer(0)]])
{
    constexpr sampler s(mag_filter::linear, min_filter::linear);

    // WHITEOUT BISECT (2026-07-23, F8): raw HDR scene + plain Reinhard,
    // nothing else — no bloom, trails, auto-exposure, bleach, grade, VJ.
    // Whiteout still present here → scene pass / particle data.
    // Gone here → this composite chain.
    // debugBypass is a MODE (layout-safe reuse of the one scalar):
    // 0 = normal · 1 = B-key full bypass · 2 = N-key bleach-off isolation.
    if (u.debugBypass > 0.5 && u.debugBypass < 1.5) {
        float3 c = currentFrame.sample(s, in.uv).rgb;
        return float4(c / (1.0 + c), 1.0);
    }

    float2 uv = in.uv;

    // ── VJ geometric effects (Resolume-style), applied to sample UV ──────
    // Mirror: fold one half onto the other.
    if (u.mirrorMode > 0.5) {
        int m = int(u.mirrorMode + 0.5);
        if (m == 1 || m == 3) uv.x = (uv.x < 0.5) ? uv.x : 1.0 - uv.x; // H
        if (m == 2 || m == 3) uv.y = (uv.y < 0.5) ? uv.y : 1.0 - uv.y; // V
    }
    // Tile: NxN repeat.
    if (u.tileCount > 1.0) {
        uv = fract(uv * u.tileCount);
    }
    // Kaleidoscope: fold the angle into N wedges around centre.
    if (u.kaleidoSegments > 1.5) {
        float2 c = uv - 0.5;
        float r = length(c);
        float ang = atan2(c.y, c.x);
        float seg = 6.28318531 / u.kaleidoSegments;
        ang = abs(fract(ang / seg) * seg - seg * 0.5);
        c = float2(cos(ang), sin(ang)) * r;
        uv = c + 0.5;
    }
    // Twirl: rotate around centre, stronger toward the middle.
    if (abs(u.twirl) > 0.001) {
        float2 c = uv - 0.5;
        float r = length(c);
        float ang = u.twirl * (0.5 - r) * 6.0;
        float sa = sin(ang), ca = cos(ang);
        c = float2(c.x * ca - c.y * sa, c.x * sa + c.y * ca);
        uv = c + 0.5;
    }

    // ── Cyberpunk glitch: horizontal RGB block displacement ──────────────
    // The screen is split into horizontal bands; some bands jump sideways on
    // a time+audio clock → the classic datamosh tear. Beat-reactive: louder
    // audio widens both how many bands glitch and how far they jump.
    float glitch = u.glitchAmount * (1.0 + u.audioLevel * 2.0);
    float2 guv = uv;
    if (glitch > 0.001) {
        float t    = floor(u.time * 14.0);       // discrete glitch "frames"
        float band = floor(uv.y * 28.0);         // 28 horizontal bands
        float trig = hash21(float2(band, t));
        if (trig > 1.0 - 0.45 * glitch) {        // only the "hot" bands jump
            float dir = (hash11(band + t) > 0.5) ? 1.0 : -1.0;
            float mag = (0.02 + 0.12 * glitch) * hash11(band * 1.7 + t);
            guv.x += dir * mag;
        }
        guv.x += (hash21(float2(t, band * 3.1)) - 0.5) * 0.01 * glitch;
    }

    // ── Chromatic aberration + glitch RGB split ──────────────────────────
    float2 d = uv - 0.5;
    float dist = length(d);
    float2 offset = d * dist * u.chromaticAmount;  // base radial CA
    offset.x += glitch * 0.012;                     // glitch horizontal tear

    float r = currentFrame.sample(s, guv + offset).r;
    float g = currentFrame.sample(s, guv).g;
    float b = currentFrame.sample(s, guv - offset).b;
    float4 color = float4(r, g, b, 1.0);

    // ── TANGENTIAL PIXEL STRETCH — the "5D look", BOUNDED ────────────────────
    // Smear the BRIGHTEST pixels ALONG CONCENTRIC CIRCLES (not radially out), so
    // every sample stays on its own radius → bounded to the BH/SN, never globby.
    // The spinning bright side fuses into fine concentric trails. Both arc
    // directions, threshold-gated (dark background untouched), cumulative max
    // with falloff. Driven by u.pixelStretch (spin). Real knobs: THRESHOLD,
    // ARC span (radians), FALLOFF.
    if (u.pixelStretch > 0.001) {
        const int   STRETCH_SAMPLES   = 16;     // per side
        const float STRETCH_THRESHOLD = 0.45;   // luminance gate (HDR scene)
        const float STRETCH_FALLOFF   = 0.93;   // decay per step
        float arcSpan = 2.4 * u.pixelStretch;   // radians of arc each side (fuses)
        float aspectR = u.resolution.x / u.resolution.y;
        float2 c2 = uv - 0.5; c2.x *= aspectR;
        float radius = length(c2);
        if (radius > 1e-4) {
            float baseA = atan2(c2.y, c2.x);
            float3 streak = color.rgb;
            for (int i = 1; i <= STRETCH_SAMPLES; i++) {
                float da = arcSpan * float(i) / float(STRETCH_SAMPLES);
                float w  = pow(STRETCH_FALLOFF, float(i));
                // + arc and − arc: rotate the sample point around centre (stays
                // on the same radius → bounded).
                float2 sp = float2(cos(baseA + da), sin(baseA + da)) * radius; sp.x /= aspectR;
                float2 sm = float2(cos(baseA - da), sin(baseA - da)) * radius; sm.x /= aspectR;
                float3 cp = currentFrame.sample(s, 0.5 + sp).rgb;
                float3 cm = currentFrame.sample(s, 0.5 + sm).rgb;
                if (dot(cp, float3(0.299, 0.587, 0.114)) > STRETCH_THRESHOLD) streak = max(streak, cp * w);
                if (dot(cm, float3(0.299, 0.587, 0.114)) > STRETCH_THRESHOLD) streak = max(streak, cm * w);
            }
            color.rgb = mix(color.rgb, streak, u.pixelStretch);
        }
    }

    // ── ACES Tonemapping (HDR scene → SDR base) ─────────────────────────
    // Tonemap the scene to a clean SDR [0,1] base FIRST, then add the glow on
    // top scaled by the display's EDR headroom so highlights punch ABOVE white
    // into HDR range (paper-white = 1.0, peaks up to edrHeadroom×). On an SDR
    // display headroom = 1.0, so this degrades gracefully to a normal add.
    // Tonemap into the display's HDR range, not flat SDR. Dividing by the EDR
    // headroom before ACES and multiplying after maps bright cores into [1,
    // headroom]× (genuine HDR above paper-white) WITH the ACES shoulder keeping
    // definition — instead of everything hot clipping to featureless white.
    // On SDR (headroom=1) this is identical to plain ACES.
    // ── SCENE-REFERRED GLOW (Checkpoint A4, 2026-07-08) ────────────────────
    // The glow is scene light: composite it BEFORE exposure/tonemap/bleach so
    // it stops down, tonemaps and BLEACHES like everything else. It used to be
    // added AFTER the bleach (scaled ×headroom) — the blurred un-bleached
    // orange core got repainted on top every frame: the immortal yellow blob.
    if (u.bloomIntensity > 0.0) {
        float3 glow = bloomTex.sample(s, in.uv).rgb;
        color.rgb += glow * (u.bloomIntensity * (1.5 + u.audioLevel));
    }

    // ── GLOBAL EXPOSURE (2026-07-07, Jamal: core blob unchanged by Grain) ──
    // The fragment shader's alpha is grainAlpha + a luminance boost that
    // DOMINATED for stars ≥1 M☉ — so the Grain slider never actually stopped
    // the sensor down. This is the real iris: scales the WHOLE HDR scene
    // before the tonemap, no per-sprite term can bypass it. 1.0 = neutral.
    color.rgb *= max(u.exposure, 0.0f);

    // ── AUTO-EXPOSURE, STOP-DOWN ONLY (2026-07-16) — expose for the ring.
    // The queued matter at the hole stacks 30–100× over display peak; the
    // sensor bleach then (correctly) burns it to featureless white paste
    // (Jamal: "still this blob thing", "hdr peaks limit in the highs"). A
    // real camera pointed at the EHT crescent stops down and the ring shows
    // FIRE. Iris = key/avgLum from the scene's own average (top mip of the
    // freshly rendered HDR frame), clamped to ≤1 so it can only darken an
    // overexposed frame — the wide starfield (avgLum ≪ key) stays EXACTLY
    // as tuned. Applied before the tonemap like the manual iris above.
    {
        constexpr sampler avgS(mag_filter::linear, min_filter::linear,
                               mip_filter::linear);
        uint topMip = sceneAvgTex.get_num_mip_levels() - 1u;
        float3 avgC = sceneAvgTex.sample(avgS, float2(0.5f, 0.5f),
                                         level(float(topMip))).rgb;
        float avgLum = dot(avgC, float3(0.2126f, 0.7152f, 0.0722f));
        const float kExpKey = 0.35f;   // wide field avg ≪ this → no change
        // FLOOR 0.05 -> 0.01 (2026-07-26 16:5x). MEASURED: the iris was JAMMED
        // against this floor for the whole late rest state, so the frame could
        // not be stopped down to the key and the sensor bleach below (correctly)
        // burned the result to featureless white — Jamal: "too whiteish, too blue
        // sparkly". The numbers, from [LUMPROBE] (which reads the SAME top mip of
        // offscreenTexture this samples, renderer.mm:3443):
        //   early rest  avgRGB=(4.68 3.36 4.47) -> avgLum 3.72 -> needs 0.094  OK
        //   late  rest  avgRGB=(17.2 13.1 16.5) -> avgLum 14.2 -> needs 0.0246 JAMMED
        // i.e. the old floor ran out of travel at avgLum > kExpKey/0.05 = 7.0,
        // and the rest state measured twice that. 0.01 = up to 100x stop-down,
        // which covers the observed 14.2 with real margin.
        // Play/Chladni states are UNTOUCHED by construction: their avgLum is
        // 0.03..0.5, far below the key, so autoExp stays pinned at 1.0.
        // ⚠ This gives the iris its travel back; it does NOT stop the underlying
        // light runaway (~1% of particles carry ~98% of the emitted light via
        // starLum = min(M^3.5*2.5, 1000), and merging keeps growing that tail),
        // and it does NOT address the fps decay, which is fill cost upstream of
        // the tonemap. Both are separate, still open.
        float autoExp = clamp(kExpKey / max(avgLum, 1e-5f), 0.01f, 1.0f);
        color.rgb *= autoExp;
    }

    float hdrPeak = max(1.0f, u.edrHeadroom);
    // HUE-PRESERVING tonemap. Per-channel ACES desaturates every highlight to
    // white — so dense particle clusters blew out to flat white instead of
    // reading as hot PLASMA. Instead: tonemap the LUMINANCE into the HDR range,
    // then rescale RGB by the same factor so the blackbody colour survives at
    // high brightness. A small per-channel ACES blend at the very top tames
    // single-channel clipping without killing the hue.
    // MAX-CHANNEL hue-preserving tonemap. The old luminance-normalised version
    // scaled RGB until the brightest channel exceeded 1.0 and CLIPPED — which
    // desaturated every bright colour back to white (the "ugly white" disk &
    // chords). A saturated orange can't also be max-luminance. Instead tonemap
    // the MAX channel into range and scale the others by the SAME factor: the
    // brightest channel lands at ≤hdrPeak (never clips), the hue ratio is exact.
    // A genuinely white-hot (high-T blackbody) colour is already ~(1,1,1) so it
    // still reads white — but an orange disk now stays orange at full brightness.
    float maxc = max(max(color.r, color.g), color.b);
    maxc = max(maxc, 1e-4f);
    // LUPTON ASINH STRETCH (2026-07-19, Jamal: "gaseous aesthetic not just
    // glowing yellow / from afar it's just blurry"). ACES has a hard shoulder:
    // once sprites stack a few times past peak, whole regions hit the ceiling
    // TOGETHER and every internal gradation dies — the flat blur. The asinh
    // curve (Lupton 2004, the survey-imagery standard — see
    // reference_stellar_render_sources) is log-tailed: brightness keeps
    // differentiating across ~ASINH_RANGE decades of overlap, so dense cores
    // read as graded gas. Same max-channel application → hue ratio exact.
    // ASINH_Q = softness knee; ASINH_RANGE = how many × peak still gain
    // visible brightness (only the very densest point reaches display peak).
    const float ASINH_Q = 8.0f;
    const float ASINH_RANGE = 32.0f;
    float xN = maxc / hdrPeak;
    float tonedMax = hdrPeak * asinh(ASINH_Q * xN) / asinh(ASINH_Q * ASINH_RANGE);
    color.rgb = color.rgb * (tonedMax / maxc);
    // SENSOR BLEACH (2026-07-07, Jamal: "still the ugly ass yellow"). Pure
    // hue-preservation pins a 50×-overexposed cluster core at max-saturation
    // yellow forever — but a real sensor BLEACHES saturated highlights to
    // white (Hubble cluster cores burn white; colour survives only in the
    // fringe where the exposure drops). Bleach ∝ log2 overexposure: hue fully
    // intact below 2× display peak (every isolated star), white by ~32×
    // (the stacked core). This is the middle between the old per-channel
    // ACES (EVERYTHING bleached → "ugly white") and the pure max-channel
    // preserve (NOTHING bleaches → the yellow fog).
    float over = maxc / hdrPeak;
    // BLEACH RE-KEYED (2026-07-19 22:4x, Jamal: "only white or orange / from
    // afar it still over-whites / a supernova has so much more variety"): the
    // old 2×→32× window whitened everything moderately dense — and the
    // emission ramp's green/cyan midband LIVES in moderately-dense matter, so
    // the palette's middle was systematically buried under white; only cold
    // sparse fringes kept hue (the orange+white look). asinh now grades the
    // stack, so the bleach only needs the truly nuclear cores: hue intact
    // below 8× peak, full white at ~256×.
    float bleach = smoothstep(3.0f, 8.0f, log2(max(over, 1.0f)));
    // N-key isolation (2026-07-23): mode 2 disables the bleach so the
    // traveling cream "yellow zone" can be attributed on screen.
    if (abs(u.debugBypass - 2.0f) > 0.25f)
        color.rgb = mix(color.rgb, float3(tonedMax), bleach);

    // (HDR glow composite moved ABOVE the tonemap — scene-referred, Checkpoint
    // A4. It must never be added post-bleach again: that repaints the
    // un-bleached core on top and resurrects the yellow blob.)

    // ── DISPLAY GRADE LUT (2026-08-03) ───────────────────────────────────
    // The creative grade stage this chain never had. It composites AFTER the
    // display transform (the asinh tonemap + sensor bleach above) and BEFORE
    // neonGrade and the VJ effects, because those are performance layers that
    // belong on top of a graded base — the same order a real pipeline uses.
    //
    // The LUT contents are baked by src/render/grade_lut.h, which carries the
    // derivation of every number in it. Exact bypass at 0.
    if (u.gradeAmount > 0.001) {
        constexpr sampler ls(mag_filter::linear, min_filter::linear,
                             address::clamp_to_edge);
        // A .cube grade is DEFINED on display-referred [0,1]. Anything above
        // paper-white is EDR headroom the LUT has no opinion about, so it is
        // split off, passed through untouched, and added back — the grade can
        // never eat the HDR cores.
        float3 over = max(color.rgb - 1.0, 0.0);
        float3 base = saturate(color.rgb);
        // HALF-TEXEL INSET. The N^3 grid's nodes are texel CENTRES, so the
        // sample coordinate is (c·(N-1) + 0.5)/N. Omitting this samples the
        // endpoints half a texel outside the grid and shifts the entire grade —
        // it is the classic LUT bug, not an optional refinement.
        const float N = 33.0;   // must match space::grade::kGradeLutN
        float3 luv = (base * (N - 1.0) + 0.5) / N;
        float3 graded = gradeLut.sample(ls, luv).rgb + over;
        color.rgb = mix(color.rgb, graded, u.gradeAmount);
    }

    // ── Neon cyberpunk color grade ───────────────────────────────────────
    // Remaps tonal range to a synth palette: shadows → deep indigo, mids →
    // magenta, highlights → cyan. Keeps per-pixel brightness so it grades
    // colour without crushing the image.
    if (u.neonGrade > 0.0) {
        float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
        float3 shadow = float3(0.04, 0.01, 0.16);
        float3 mid    = float3(0.90, 0.12, 0.70);
        float3 high   = float3(0.10, 0.95, 1.00);
        float3 graded = mix(shadow, mid, smoothstep(0.0, 0.5, luma));
        graded = mix(graded, high, smoothstep(0.5, 1.0, luma));
        graded *= (luma + 0.06);
        color.rgb = mix(color.rgb, graded, u.neonGrade);
    }

    // ── VJ colour effects ────────────────────────────────────────────────
    if (u.hueShift > 0.001) {
        float3 hsv = rgb2hsv(saturate(color.rgb));
        hsv.x = fract(hsv.x + u.hueShift);
        color.rgb = hsv2rgb(hsv);
    }
    if (u.posterize > 1.5) {
        color.rgb = floor(color.rgb * u.posterize) / u.posterize;
    }
    if (u.invert > 0.001) {
        color.rgb = mix(color.rgb, 1.0 - color.rgb, u.invert);
    }

    // ── Analytical Motion Blur (Ray-Bundle proxy) ───────────────────────
    // To simulate the streak of a ray-bundle over the camera exposure time,
    // we calculate the exact screen-space velocity of this pixel by un-projecting
    // it to world space, then re-projecting it with the previous frame's matrix.

    // We assume the Black Hole and accretion disk particles are far away,
    // so we approximate their depth as far-plane (z=0.99) for the optical flow proxy.
    float4 ndcPos = float4(uv.x * 2.0 - 1.0, (1.0 - uv.y) * 2.0 - 1.0, 0.99, 1.0);

    // 1. Un-project to World Space
    float4 worldPos = u.inverseViewProj * ndcPos;
    worldPos /= worldPos.w;

    // 2. Re-project with previous frame's View-Projection
    float4 prevClipPos = u.prevViewProj * worldPos;
    prevClipPos /= prevClipPos.w;

    // 3. Calculate screen-space velocity vector
    float2 prevUV = prevClipPos.xy * 0.5 + 0.5;
    prevUV.y = 1.0 - prevUV.y;

    float2 velocity = uv - prevUV;

    // 4. Streak only the very brightest core pixels (reduced from 8 to 4 samples, HDR-gated)
    float velLen = length(velocity);
    // DISABLED: this camera motion-blur averaged the HDR glow with tonemapped
    // (SDR, dimmer) samples and /4, so moving the camera DIMMED the glow — the
    // "FX bug out / glow turns off when I move the camera" bug. FX stay stable now.
    if (false && velLen > 0.002) {
        // Only blur pixels that are actually bright (HDR luminance gate)
        float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
        if (luma > 0.3) {
            int blurSamples = 4; // Reduced from 8 for sharper disk
            float blurStrength = min(velLen * 0.5, 1.0); // Scale blur with velocity, cap at 1x
            float4 blurColor = color;

            for (int i = 1; i < blurSamples; i++) {
                float2 sampleUV = uv - velocity * blurStrength * (float(i) / float(blurSamples - 1));
                float4 sColor = currentFrame.sample(s, sampleUV);
                float3 mappedS = acesTonemap(sColor.rgb);
                blurColor.rgb += mappedS;
            }
            color.rgb = blurColor.rgb / float(blurSamples);
        }
    }

    // ── VRAM Trail Decay (persistence) ──────────────────────────────────
    if (u.trailDecay > 0.0) {
        float4 prev = previousFrame.sample(s, uv);
        color = max(color, prev * u.trailDecay);
    }

    // ── Scanlines (CRT / techno) — applied last so it doesn't feed back ──
    if (u.scanlineAmount > 0.0) {
        float line = 0.5 + 0.5 * sin(in.uv.y * u.resolution.y * 3.14159265);
        color.rgb *= 1.0 - u.scanlineAmount * 0.6 * (1.0 - line);
    }

    // ── Vignette (cinematic framing) ─────────────────────────────────────
    if (u.vignette > 0.0) {
        float vig = smoothstep(0.85, 0.25, length(in.uv - 0.5));
        color.rgb *= mix(1.0, vig, u.vignette);
    }

    // ── Strobe (VJ) — beat-reactive flash, applied last ──────────────────
    if (u.strobe > 0.001) {
        // ~8 Hz base, sped up by audio. Square flash between dark and full.
        float rate = 6.0 + u.audioLevel * 10.0;
        float flash = step(0.5, fract(u.time * rate));
        color.rgb *= mix(1.0, flash, u.strobe);
    }

    // ── Output dither — break 8-bit banding (Resolume-style) ─────────────
    // Triangular-PDF dither at ±1 LSB. Two hashes of the pixel position give
    // a TPDF that's perceptually cleaner than a single uniform dither. Costs
    // nothing and removes the gradient banding of an 8-bit SDR drawable.
    float2 dpx = in.position.xy;
    float dn1 = fract(sin(dot(dpx, float2(12.9898, 78.233))) * 43758.5453);
    float dn2 = fract(sin(dot(dpx, float2(39.3468, 11.135))) * 24634.6345);
    color.rgb += (dn1 + dn2 - 1.0) / 255.0;

    // ── SYPHON ALPHA OUT ────────────────────────────────────────────────────
    // Everything that isn't black becomes opaque; pure black → transparent. The
    // RGB is already premultiplied (glow on a black background = 0,0,0), so the
    // feed keys cleanly as a layer in Resolume/Arena. The on-screen CAMetalLayer
    // is opaque, so writing alpha here does NOT affect the app window — only the
    // published Syphon texture carries the coverage. (Opaque-black toggle next.)
    float outA = clamp(dot(color.rgb, float3(0.299f, 0.587f, 0.114f)), 0.0f, 1.0f);
    return float4(color.rgb, outA);
}

// ── Separable Gaussian blur (ping-pong multi-pass building block) ───────────
// One axis per invocation; the renderer runs it H then V into ping-pong HDR
// targets. 9-tap Gaussian. This is the reusable foundation for real blur,
// future bloom, DOF and feedback effects — not a per-pixel uber-shader trick.
struct BlurUniforms {
    float2 direction;  // texel step (1/resolution) along one axis
    float radius;      // spread multiplier
    float pad;
};

fragment float4 blur_fragment(
    PostVertexOut in [[stage_in]],
    texture2d<float> src [[texture(0)]],
    constant BlurUniforms& u [[buffer(0)]])
{
    constexpr sampler s(mag_filter::linear, min_filter::linear,
                        address::clamp_to_edge);
    const float w[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};
    float2 stepv = u.direction * u.radius;
    float3 col = src.sample(s, in.uv).rgb * w[0];
    for (int i = 1; i < 5; i++) {
        col += src.sample(s, in.uv + stepv * float(i)).rgb * w[i];
        col += src.sample(s, in.uv - stepv * float(i)).rgb * w[i];
    }
    return float4(col, 1.0);
}

// ── HDR bright-pass (bloom extraction) ──────────────────────────────────────
// First stage of the modern glow split: keep only the energy ABOVE a soft HDR
// knee, then feed that into the ping-pong Gaussian (cheap wide blur) before the
// final composite adds it back. Soft-knee (not a hard step) so the glow ramps
// in smoothly instead of popping at the threshold. The 1/(1+luma) firefly
// weight tames single ultra-bright texels that would otherwise flicker as the
// blur smears them — same trick as Jimenez/CoD bloom.
struct BrightUniforms {
    float threshold; // HDR knee (≈1.0 = only values past SDR white glow)
    float softKnee;  // width of the smooth ramp below threshold
    float pad0;
    float pad1;
};

fragment float4 bright_fragment(
    PostVertexOut in [[stage_in]],
    texture2d<float> src [[texture(0)]],
    constant BrightUniforms& u [[buffer(0)]])
{
    constexpr sampler s(mag_filter::linear, min_filter::linear,
                        address::clamp_to_edge);
    float3 c = src.sample(s, in.uv).rgb;
    float luma = dot(c, float3(0.2126, 0.7152, 0.0722));

    // Soft-knee curve around the threshold (Jimenez): smooth ramp in [t-k, t+k]
    float knee = max(u.softKnee, 0.0001);
    float soft = clamp(luma - u.threshold + knee, 0.0, 2.0 * knee);
    soft = (soft * soft) / (4.0 * knee + 0.0001);
    float contrib = max(soft, luma - u.threshold) / max(luma, 0.0001);

    float3 bright = c * contrib;
    // Firefly clamp: down-weight tiny ultra-bright spikes so the blur is stable
    bright *= 1.0 / (1.0 + luma);
    return float4(bright, 1.0);
}

// ── Bloom mip pyramid: downsample + upsample ────────────────────────────────
// Replaces the old single-scale chain (one half-res buffer, 3 iterations of the
// 9-tap Gaussian at radius 2.5). Three passes of a small Gaussian at ONE
// resolution can only produce ONE characteristic glow radius — a modest halo
// hugging each bright thing. That is what reads as cheap.
//
// A pyramid is scale-INVARIANT: the bright-pass result is halved repeatedly,
// then progressively upsampled and accumulated, so a single bright star throws
// a tight core glow AND a soft wash across a large fraction of the screen at
// the same time. Reference: Jimenez, "Next Generation Post Processing in Call
// of Duty: Advanced Warfare" (SIGGRAPH 2014) — the same source as the soft-knee
// bright-pass above, which is why the two compose correctly.

struct BloomDownUniforms {
    float2 srcTexel;  // 1 / source resolution — the sample offsets are in
                      // SOURCE texels, so the kernel is identical at every level
    float2 pad;
};

// 13-tap partial-box downsample. A naive 2x2 box (or bilinear) aliases: at each
// halving it drops the odd samples, so a bright point flickers between levels
// as the camera moves. This kernel samples five overlapping 2x2 boxes — the
// centre box weighted 0.5, the four corner boxes 0.125 each (sum = 1.0, energy
// preserving) — which is stable because every source texel contributes to every
// destination texel it touches.
fragment float4 bloom_down_fragment(
    PostVertexOut in [[stage_in]],
    texture2d<float> src [[texture(0)]],
    constant BloomDownUniforms& u [[buffer(0)]])
{
    constexpr sampler s(mag_filter::linear, min_filter::linear,
                        address::clamp_to_edge);
    float2 t = u.srcTexel;
    float2 uv = in.uv;

    // Sample layout (o = centre), offsets in source texels:
    //   a . b . c        (-2,-2) ( 0,-2) ( 2,-2)
    //   . d . e .        (-1,-1) ( 1,-1)
    //   f . o . h        (-2, 0) ( 0, 0) ( 2, 0)
    //   . i . j .        (-1, 1) ( 1, 1)
    //   k . l . m        (-2, 2) ( 0, 2) ( 2, 2)
    float3 a = src.sample(s, uv + float2(-2.0, -2.0) * t).rgb;
    float3 b = src.sample(s, uv + float2( 0.0, -2.0) * t).rgb;
    float3 c = src.sample(s, uv + float2( 2.0, -2.0) * t).rgb;
    float3 d = src.sample(s, uv + float2(-1.0, -1.0) * t).rgb;
    float3 e = src.sample(s, uv + float2( 1.0, -1.0) * t).rgb;
    float3 f = src.sample(s, uv + float2(-2.0,  0.0) * t).rgb;
    float3 o = src.sample(s, uv).rgb;
    float3 h = src.sample(s, uv + float2( 2.0,  0.0) * t).rgb;
    float3 i = src.sample(s, uv + float2(-1.0,  1.0) * t).rgb;
    float3 j = src.sample(s, uv + float2( 1.0,  1.0) * t).rgb;
    float3 k = src.sample(s, uv + float2(-2.0,  2.0) * t).rgb;
    float3 l = src.sample(s, uv + float2( 0.0,  2.0) * t).rgb;
    float3 m = src.sample(s, uv + float2( 2.0,  2.0) * t).rgb;

    float3 col = (d + e + i + j) * (0.500 * 0.25);   // centre box
    col       += (a + b + o + f) * (0.125 * 0.25);   // top-left box
    col       += (b + c + h + o) * (0.125 * 0.25);   // top-right box
    col       += (f + o + l + k) * (0.125 * 0.25);   // bottom-left box
    col       += (o + h + m + l) * (0.125 * 0.25);   // bottom-right box
    return float4(col, 1.0);
}

struct BloomUpUniforms {
    float2 filterRadius; // UV offset for the tent's outer ring
    float2 pad;
};

// 3x3 tent upsample. Bilinear alone would reintroduce the blocky structure of
// the small level; the tent (weights 1,2,1 / 2,4,2 / 1,2,1, sum 16) reconstructs
// a smooth field. The result is blended ADDITIVELY onto the level above, so the
// finished glow is the sum of every scale — that sum is the whole point.
//
// filterRadius is set by the renderer to exactly ONE SOURCE TEXEL, which is half
// a destination texel: the tent then spans the destination neighbourhood the
// source texel actually covers, so successive levels tile without gaps or
// double-counting. It is not a tuned number; it is the level ratio.
fragment float4 bloom_up_fragment(
    PostVertexOut in [[stage_in]],
    texture2d<float> src [[texture(0)]],
    constant BloomUpUniforms& u [[buffer(0)]])
{
    constexpr sampler s(mag_filter::linear, min_filter::linear,
                        address::clamp_to_edge);
    float x = u.filterRadius.x;
    float y = u.filterRadius.y;
    float2 uv = in.uv;

    float3 a = src.sample(s, uv + float2(-x,  y)).rgb;
    float3 b = src.sample(s, uv + float2(0.0, y)).rgb;
    float3 c = src.sample(s, uv + float2( x,  y)).rgb;
    float3 d = src.sample(s, uv + float2(-x, 0.0)).rgb;
    float3 e = src.sample(s, uv).rgb;
    float3 f = src.sample(s, uv + float2( x, 0.0)).rgb;
    float3 g = src.sample(s, uv + float2(-x, -y)).rgb;
    float3 h = src.sample(s, uv + float2(0.0,-y)).rgb;
    float3 i = src.sample(s, uv + float2( x, -y)).rgb;

    float3 col = e * 4.0;
    col += (b + d + f + h) * 2.0;
    col += (a + c + g + i);
    col *= (1.0 / 16.0);
    return float4(col, 1.0);
}
