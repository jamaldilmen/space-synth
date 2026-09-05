#pragma once
#include <algorithm>
#include <cmath>
#include <cstdlib>

#ifndef M_PI_F
#define M_PI_F 3.14159265358979323846f
#endif

namespace space {

// ── SECOND-ORDER DAMPED SPRING — EXACT SOLUTION ─────────────────────────────
//
// Solves  a + 2ζω·v + ω²x = 0  ANALYTICALLY over the step, rather than
// integrating it. Ryan Juckett's closed form (the same math behind Unity's
// SmoothDamp and Game Programming Gems 4).
//
// 🚨 WHY THE EXACT FORM AND NOT A LERP: the old camera bled velocity with
// `friction = max(0, 1 - dt*6)`, which only APPROXIMATES e^(-6·dt) and diverges
// as dt grows. Measured fps on this project spans 18.7 to 120.2, so the camera
// FEEL changed with particle load — the opposite of an operator's hand. The
// closed form is exact for any dt, so frame-rate independence is free rather
// than a thing to tune. That is not a nicety here; it is the difference between
// a move that lands the same every take and one that does not.
struct SpringCoef {
  float posPos = 1.0f, posVel = 0.0f;
  float velPos = 0.0f, velVel = 1.0f;
};

// ω = angular frequency (rad/s), ζ = damping ratio.
// ζ = 1 critically damped (fastest arrival with NO overshoot)
// ζ < 1 under-damped (overshoots, then settles)
inline SpringCoef springCoefficients(float dt, float omega, float zeta) {
  const float eps = 1e-4f;
  SpringCoef c;
  if (omega < eps) return c; // ω→0: frozen, coefficients are the identity
  if (zeta < 0.0f) zeta = 0.0f;

  if (zeta > 1.0f + eps) {
    // Over-damped: two real roots, no oscillation, slower than critical.
    float za = -omega * zeta;
    float zb = omega * std::sqrt(zeta * zeta - 1.0f);
    float z1 = za - zb, z2 = za + zb;
    float e1 = std::exp(z1 * dt), e2 = std::exp(z2 * dt);
    float invTwoZb = 1.0f / (2.0f * zb);
    float e1t = e1 * invTwoZb, e2t = e2 * invTwoZb;
    float z1e1t = z1 * e1t, z2e2t = z2 * e2t;
    c.posPos = e1t * z2 - z2e2t + e2;
    c.posVel = -e1t + e2t;
    c.velPos = (z1e1t - z2e2t) * z2;
    c.velVel = -z1e1t + z2e2t;
  } else if (zeta < 1.0f - eps) {
    // Under-damped: overshoots by ~5% at ζ=0.7, which is what reads as a human
    // operator rather than a script.
    float omegaZeta = omega * zeta;
    float alpha = omega * std::sqrt(1.0f - zeta * zeta);
    float expTerm = std::exp(-omegaZeta * dt);
    float cosTerm = std::cos(alpha * dt);
    float sinTerm = std::sin(alpha * dt);
    float invAlpha = 1.0f / alpha;
    float expSin = expTerm * sinTerm;
    float expCos = expTerm * cosTerm;
    float expOmegaZetaSinOverAlpha = expTerm * omegaZeta * sinTerm * invAlpha;
    c.posPos = expCos + expOmegaZetaSinOverAlpha;
    c.posVel = expSin * invAlpha;
    c.velPos = -expSin * alpha - omegaZeta * expOmegaZetaSinOverAlpha;
    c.velVel = expCos - expOmegaZetaSinOverAlpha;
  } else {
    // Critically damped: arrives as fast as possible without ever overshooting.
    float expTerm = std::exp(-omega * dt);
    float timeExp = dt * expTerm;
    float timeExpFreq = timeExp * omega;
    c.posPos = timeExpFreq + expTerm;
    c.posVel = timeExp;
    c.velPos = -omega * timeExpFreq;
    c.velVel = -timeExpFreq + expTerm;
  }
  return c;
}

// Advance one axis toward `target`. pos/vel are updated in place.
inline void springStep(const SpringCoef &c, float &pos, float &vel,
                       float target) {
  float oldPos = pos - target;
  float oldVel = vel;
  pos = oldPos * c.posPos + oldVel * c.posVel + target;
  vel = oldPos * c.velPos + oldVel * c.velVel;
}

class Camera {
public:
  Camera() { reset(); }

  // ── FEEL CONSTANTS ────────────────────────────────────────────────────────
  // ω is derived from a SETTLE TIME, not tasted: a critically-damped system is
  // within 2% of its target at ω·t ≈ 5.83, so ω = 5.83 / T_settle. T_settle is
  // the one number here in a unit he can actually feel — "how long until the
  // camera has arrived."
  //
  // ⛔ NO BPM, NO BEAT, NO TEMPO TERM. An earlier draft sourced ω from the beat
  // (12.4 rad/s at 128 BPM). His ruling 2026-08-28: "we dont want a bpm sync
  // its not needed for now u got that wrong. its just about smoothness in
  // camer amotion." Only the SOURCE of ω changed; the math below is untouched.
  static constexpr float kSettleConst = 5.83f;  // ω·t for 2% settle, critical
  static constexpr float kSettleNormal = 0.50f; // s  → ω ≈ 11.7
  static constexpr float kSettleCine = 1.50f;   // s  → ω ≈  3.9
  // ζ: zoom never overshoots (an overshooting zoom reads as a mistake). Orbit
  // overshoots slightly in normal mode — that ~5% is the operator's hand.
  // In CINEMATIC mode both go critical: a cinema camera does not bounce.
  static constexpr float kZetaOrbit = 0.70f;
  static constexpr float kZetaZoom = 1.00f;

  static constexpr float kMinRho = 50.0f;
  // kMaxRho 2000 -> 5800 (2026-09-05, his "it was clearly not zoomed out"):
  // 2000 is ortho's far end (half-height rho*1.2 = 2400 world). Perspective at
  // 45 deg shows d*tan(22.5) = 0.414*d, so the SAME framing needs
  // d = 2400/0.414 = 5794. Derived from ortho's own law, not picked. The
  // rest cloud reaches ~7600 world units (maxR 61-76 sim x plate 100), so at
  // 2000 a POV camera is still INSIDE it. Ortho keeps its 1.2*rho law and
  // gains range it never uses.
  static constexpr float kMaxRho = 5800.0f;

  void reset() {
    // 400 puts the horizon at ~12% of half-screen at default zoom
    // (was 800 → 6%). User can still scroll out to 2000.
    // 400 → 800 (2026-07-20 01:07, "still an eye"): the cavity doubled
    // (R=3→6) but the default view stayed ±4.8, so the figure OVERFLOWED the
    // frame and read as a cropped eye. 800 spans ±9.6 — the whole R=6 figure
    // sits in frame at the same proportion the old R=3 figure had in ±4.8.
    rho = 800.0f;
    // 🔬 TEMP-DIAG SS_CAM_RHO (2026-07-16): launch at a chosen zoom so the
    // agent can self-verify zoomed render states (hole close-ups) by
    // screenshot without driving the user's mouse. No env = unchanged.
    if (const char *cr = getenv("SS_CAM_RHO")) {
      float v = (float)atof(cr);
      if (v >= kMinRho && v <= kMaxRho) rho = v;
    }
    theta = M_PI_F / 2.0f; // Elevation — face-on horizontal view
    phi = 0.0f;            // Azimuth
    velRho = velTheta = velPhi = 0.0f;
    // The camera starts AT its target, at rest. Anything else would make the
    // app open on a move nobody asked for.
    tgtRho = rho;
    tgtTheta = theta;
    tgtPhi = phi;
  }

  // ── CINEMATIC MODE ────────────────────────────────────────────────────────
  // His spec 2026-08-28, verbatim: "i press a key. ideally c and the cmaera
  // movement becomes smooth as a cienma camera . thats it."
  //
  // ONE scalar, and it reaches EVERY camera motion — orbit, tilt and zoom, in
  // every state. It is not a second code path and not a per-axis tuning set;
  // it changes the settle time and the damping of the ONE law below.
  //
  // ⛔ IT DOES NOT TOUCH TIME WARP OR THE BODY SPIN, deliberately. His ruling:
  // "at warp we spin the object not the camera u know so the question doesnt
  // make sens." Cinematic mode is about the speed of the CAMERA. The arrow-HOLD
  // spin and the shift+arrow time warp move the OBJECT and are a different
  // system — see docs/CAMERA_STEP2_DESIGN.md §2.
  void setCinematic(bool on) { cinematic = on; }
  bool isCinematic() const { return cinematic; }

  void update(float dt) {
    if (dt <= 0.0f) return;

    float settle = cinematic ? kSettleCine : kSettleNormal;
    float omega = kSettleConst / settle;
    // A cinema camera does not bounce: cinematic forces critical damping.
    float zOrbit = cinematic ? 1.0f : kZetaOrbit;

    SpringCoef cOrbit = springCoefficients(dt, omega, zOrbit);
    SpringCoef cZoom = springCoefficients(dt, omega, kZetaZoom);

    // 🚨 EVERY MOTION GOES THROUGH THE SPRING. There is no path that writes a
    // position or a velocity directly any more — that inversion IS the fix.
    // Input moves the TARGET; the camera chases it. An impulse is instantaneous
    // acceleration, so the old camera was at peak speed on frame one and
    // everything decayed from maximum: ease-OUT only, ease-IN unobtainable at
    // any setting. The spring accelerates from rest, so a move now has a
    // beginning as well as an end.
    springStep(cOrbit, phi, velPhi, tgtPhi);
    springStep(cOrbit, theta, velTheta, tgtTheta);
    springStep(cZoom, rho, velRho, tgtRho);

    // Keep phi/theta numerically tame under infinite rotation WITHOUT ever
    // disturbing the error the spring is solving: wrap the actual, then shift
    // the target by the SAME multiple of 2π. (phi - tgtPhi) is unchanged, so
    // the camera cannot be made to take the long way round by a wrap.
    coWrap(phi, tgtPhi);
    coWrap(theta, tgtTheta);

    // Compute Cartesian position
    float sinTheta = std::sin(theta);
    float cosTheta = std::cos(theta);
    float sinPhi = std::sin(phi);
    float cosPhi = std::cos(phi);

    posX = rho * sinTheta * sinPhi;
    posY = rho * cosTheta;
    posZ = rho * sinTheta * cosPhi;
  }

  // Free-form rotation (mouse drag). Moves the TARGET, not the camera.
  // Gain is unchanged at 0.0015 rad/pt and that is now a DERIVED number rather
  // than a tuned one: a ~1920 pt drag across the window sweeps 1920 × 0.0015 ≈
  // 2.9 rad ≈ 165°, i.e. dragging the width of the screen turns the view about
  // half a revolution.
  void rotate(float dPhi, float dTheta) {
    tgtPhi += dPhi;
    tgtTheta += dTheta;
  }

  // Arrow-key TAP. Steps the target to the NEXT EIGHTH-TURN (45°) in the
  // direction pressed, EXACTLY — 8 taps for a full revolution, on BOTH axes.
  // His order 2026-08-28: "pls make it exactly double as many taps need yeah
  // so 8 taps for a full rotation on either axis not 4 ok". Was 90°/4 taps,
  // which he approved the feel of first ("i love the feel the snappiness") —
  // only the grid spacing changed, not the law.
  //
  // ⭐ This replaces `softLockToQuarter`, a magnetic detent that watched for the
  // velocity to fall below a threshold and then snapped the angle. That hack
  // existed only because input wrote velocity: you cannot land on an angle by
  // throwing velocity at it, so it had to be caught on the way down. With a
  // target the landing is exact by construction, in one tap, every time, and it
  // eases in and out on the way. ~25 lines of detent logic deleted.
  void rotateKey(int stepPhi, int stepTheta) {
    // The step grid. Shared by both branches below, so one constant covers
    // "either axis". The round-to-grid form lands exactly at any spacing; the
    // grid is simply twice as fine now. The default theta = π/2 (:131) is still
    // ON this grid, so nothing jumps at launch.
    const float Q = M_PI_F * 0.25f; // 45°
    if (stepPhi) tgtPhi = (std::round(tgtPhi / Q) + (float)stepPhi) * Q;
    if (stepTheta) tgtTheta = (std::round(tgtTheta / Q) + (float)stepTheta) * Q;
  }

  void zoom(float dRho) {
    tgtRho = std::max(kMinRho, std::min(kMaxRho, tgtRho - dRho));
  }

  // ABSOLUTE set (2026-09-04, his CC ride order via BRAIN): zoom()/rotate()
  // are deltas, unsuited to a fader that must land on the SAME position every
  // time it repeats a value — a ride re-sweeping CC=64 needs the same rho
  // back, not "nudge from wherever we ended up". Still writes the TARGET only,
  // so the spring in update() is untouched.
  void setZoomAbs(float rhoAbs) {
    tgtRho = std::max(kMinRho, std::min(kMaxRho, rhoAbs));
  }
  void setTiltAbs(float thetaAbs) { tgtTheta = thetaAbs; }
  // Azimuth absolute set (2026-09-04, take 3 "spin" order): at theta=0 phi
  // has NO visible effect (sinTheta=0 kills it) -- this is the fixed pose
  // that picks ORBIT (phi=90 deg, stays edge-on through a theta sweep) vs
  // TUMBLE (phi=0, goes face-on at the quarter point). Same target-only
  // write as setTiltAbs/setZoomAbs; the spring in update() is untouched.
  void setPhiAbs(float phiAbs) { tgtPhi = phiAbs; }
  // See `orbitUpFix` above. Only the orbit ride sets this; every other use
  // of the camera keeps the original theta-derived up (unchanged, still the
  // right choice when theta is an elevation, not an orbit angle).
  void setOrbitUpFix(bool on) { orbitUpFix = on; }

  float getRho() const { return rho; }
  float getPhi() const { return phi; }
  float getTheta() const { return theta; }

  void buildViewMatrix(float *out) const {
    // LookAt(pos, [0,0,0], [0,1,0])
    float forward[3] = {-posX, -posY, -posZ};
    float len = std::sqrt(forward[0] * forward[0] + forward[1] * forward[1] +
                          forward[2] * forward[2]);
    forward[0] /= len;
    forward[1] /= len;
    forward[2] /= len;

    // Orbit-derived up: -d(pos)/d(theta) normalized. Always perpendicular
    // to forward by construction, always well-defined (no degenerate
    // cross product at poles), and continuously varies as theta sweeps
    // through ±π/2 ± π — no basis flip, no "skip + bounce" artifact.
    //   At theta = π/2 (equator) this equals (0, 1, 0) = world up.
    //   At theta = 0 or ±π (poles) it lies in the X-Z plane, perpendicular
    //   to the now-vertical forward vector.
    float sinT = std::sin(theta);
    float cosT = std::cos(theta);
    float sinP = std::sin(phi);
    float cosP = std::cos(phi);
    // ORBIT MODE ONLY: pin refUp to the disk normal (0,0,-1) instead of the
    // theta-derived vector -- see `orbitUpFix` above for why. Verified
    // numerically: this keeps screenUp constant at (0,0,-1) (matching take
    // 2's own framing) for every theta, while screenRight rotates smoothly
    // in the disk plane -- a true orbit, no roll.
    float refUp[3];
    if (orbitUpFix) {
      refUp[0] = 0.0f;
      refUp[1] = 0.0f;
      refUp[2] = -1.0f;
    } else {
      refUp[0] = -cosT * sinP;
      refUp[1] = sinT;
      refUp[2] = -cosT * cosP;
    }
    float right[3] = {refUp[1] * forward[2] - refUp[2] * forward[1],
                      refUp[2] * forward[0] - refUp[0] * forward[2],
                      refUp[0] * forward[1] - refUp[1] * forward[0]};
    len = std::sqrt(right[0] * right[0] + right[1] * right[1] +
                    right[2] * right[2]);
    right[0] /= len;
    right[1] /= len;
    right[2] /= len;
    float up[3];

    up[0] = forward[1] * right[2] - forward[2] * right[1];
    up[1] = forward[2] * right[0] - forward[0] * right[2];
    up[2] = forward[0] * right[1] - forward[1] * right[0];

    // Column-major
    out[0] = right[0];
    out[4] = right[1];
    out[8] = right[2];
    out[12] = -(right[0] * posX + right[1] * posY + right[2] * posZ);
    out[1] = up[0];
    out[5] = up[1];
    out[9] = up[2];
    out[13] = -(up[0] * posX + up[1] * posY + up[2] * posZ);
    out[2] = -forward[0];
    out[6] = -forward[1];
    out[10] = -forward[2];
    out[14] = (forward[0] * posX + forward[1] * posY + forward[2] * posZ);
    out[3] = 0;
    out[7] = 0;
    out[11] = 0;
    out[15] = 1;
  }

  float getX() const { return posX; }
  float getY() const { return posY; }
  float getZ() const { return posZ; }

  // World-space UNIT FORWARD (eye → look-at target).
  //
  // F5 (2026-08-10). render.metal used to compute its view axis inline as
  // `normalize(-cam.cameraPos.xyz)`, which is not a view axis but "the
  // direction from the camera to the ORIGIN" — correct only while
  // buildViewMatrix() hardcodes the same assumption. The shader is TOLD the
  // forward vector instead of re-deriving it from that assumption.
  //
  // ⚠️ Its two ORIGINAL consumers (the lens front/behind test and the `behindBH`
  // occlusion) died with the lens and the geodesic march on 2026-08-27. The two
  // that survive are FIELD consumers, not BH optics: render.metal ~:1221 (ortho
  // depth for the PSF size falloff) and ~:2388 (per-cell dust absorption
  // direction). So this stays load-bearing, and the moment a ride points the
  // camera somewhere other than the origin both become correct for free.
  void getForward(float *out) const {
    float fx = -posX, fy = -posY, fz = -posZ;
    float len = std::sqrt(fx * fx + fy * fy + fz * fz);
    if (len < 1e-12f) {
      // Degenerate only if the camera sits exactly on the target. rho is
      // clamped to >= kMinRho, so this is unreachable today; it exists so a
      // future free-fly/POV camera cannot produce a NaN axis.
      out[0] = 0.0f;
      out[1] = 0.0f;
      out[2] = -1.0f;
      return;
    }
    out[0] = fx / len;
    out[1] = fy / len;
    out[2] = fz / len;
  }

private:
  float rho, theta, phi;          // ACTUAL — what the renderer reads
  float tgtRho, tgtTheta, tgtPhi; // TARGET — what input writes
  float velRho, velTheta, velPhi; // internal to the spring; nothing else writes
  float posX, posY, posZ;
  bool cinematic = false;
  // ORBIT UP-VECTOR FIX (2026-09-04, take 3 verdict "the rotation seems
  // wrong ... not what i wanted"): the theta-derived refUp below is correct
  // when theta is an ELEVATION -- it exists to avoid a basis flip at the
  // poles. Take 3 made theta the ORBIT angle instead, so the basis rotated
  // WITH the orbit: disk sat 90deg rotated on screen (right became the disk
  // normal instead of up) and screenUp swept a full 360deg in the disk
  // plane across the take -- the picture rolled, reading as the OBJECT
  // spinning rather than the camera flying around it. Pinning refUp to the
  // disk normal (0,0,-1) for orbit mode only keeps the horizon level: right
  // rotates in-plane as it should, up stays constant, matching take 2's
  // framing exactly (verified: take 2's own screenUp was (0,0,-1)).
  bool orbitUpFix = false;

  // Wrap an angle to (-π, π].
  static float wrapPi(float a) {
    const float TWO_PI = 2.0f * M_PI_F;
    a = std::fmod(a + M_PI_F, TWO_PI);
    if (a < 0.0f)
      a += TWO_PI;
    return a - M_PI_F;
  }

  // Wrap `actual` into (-π, π] and shift `target` by the SAME amount, so the
  // error between them survives the wrap exactly.
  static void coWrap(float &actual, float &target) {
    float wrapped = wrapPi(actual);
    float shift = wrapped - actual; // an exact multiple of 2π
    actual = wrapped;
    target += shift;
  }
};

} // namespace space
