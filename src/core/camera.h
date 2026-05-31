#pragma once
#include <algorithm>
#include <cmath>

#ifndef M_PI_F
#define M_PI_F 3.14159265358979323846f
#endif

namespace space {

class Camera {
public:
  Camera() { reset(); }

  void reset() {
    // 400 puts the horizon at ~12% of half-screen at default zoom
    // (was 800 → 6%). User can still scroll out to 2000.
    rho = 400.0f;
    theta = M_PI_F / 2.0f; // Elevation — face-on horizontal view
    phi = 0.0f;            // Azimuth
    velRho = velTheta = velPhi = 0.0f;
  }

  void update(float dt) {
    // Velocity-based damping for inertia
    float friction = std::max(0.0f, 1.0f - dt * 6.0f);
    velPhi *= friction;
    velTheta *= friction;
    velRho *= friction;

    phi += velPhi;
    theta += velTheta;
    rho = std::max(50.0f, std::min(2000.0f, rho + velRho));

    // Wrap to [-π, π] so the values stay numerically tame even with
    // infinite rotation. Display layer can convert to degrees / quadrant.
    phi = wrapPi(phi);
    theta = wrapPi(theta);

    // Soft-lock at N·π/2 (0°, 90°, 180°, 270°) for screenshot framing.
    // ONLY engages when the last input was an arrow key. Mouse drag stays
    // free-form so the user can frame off-axis shots without the camera
    // pulling itself onto an axis.
    if (snapNextSettle) {
      constexpr float SOFT_LOCK_RAD = 0.12f;    // ≈ 6.9°
      constexpr float SOFT_LOCK_VEL = 0.003f;   // ~1°/frame at 60fps
      softLockToQuarter(phi, velPhi, SOFT_LOCK_RAD, SOFT_LOCK_VEL);
      softLockToQuarter(theta, velTheta, SOFT_LOCK_RAD, SOFT_LOCK_VEL);
      // Once both axes have settled (velocity near zero), arm cleared so
      // a subsequent mouse drag isn't snapped at the end.
      if (std::abs(velPhi) < 1e-4f && std::abs(velTheta) < 1e-4f) {
        snapNextSettle = false;
      }
    }

    // Compute Cartesian position
    float sinTheta = std::sin(theta);
    float cosTheta = std::cos(theta);
    float sinPhi = std::sin(phi);
    float cosPhi = std::cos(phi);

    posX = rho * sinTheta * sinPhi;
    posY = rho * cosTheta;
    posZ = rho * sinTheta * cosPhi;
  }

  // Free-form rotation (mouse drag). Does NOT enable 90° snap.
  void rotate(float dPhi, float dTheta) {
    velPhi += dPhi;
    velTheta += dTheta;
    snapNextSettle = false;
  }

  // Arrow-key rotation. Same impulse as rotate(), but ALSO arms the
  // 90° soft-lock so the next time the camera settles it snaps onto a
  // quarter-turn for clean screenshots.
  void rotateKey(float dPhi, float dTheta) {
    velPhi += dPhi;
    velTheta += dTheta;
    snapNextSettle = true;
  }

  void zoom(float dRho) { velRho -= dRho; }

  // Snap directly to a target angle (skips inertia). Used by quick-snap
  // shortcuts like number-key presets if we ever wire them.
  void setAngles(float newPhi, float newTheta) {
    phi = wrapPi(newPhi);
    theta = wrapPi(newTheta);
    velPhi = velTheta = 0.0f;
  }

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
    float refUp[3] = {-cosT * sinP, sinT, -cosT * cosP};
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

private:
  float rho, theta, phi;
  float velRho, velTheta, velPhi;
  float posX, posY, posZ;
  bool snapNextSettle = false; // Armed by arrow keys, cleared by mouse rotate

  // Wrap an angle to (-π, π].
  static float wrapPi(float a) {
    const float TWO_PI = 2.0f * M_PI_F;
    a = std::fmod(a + M_PI_F, TWO_PI);
    if (a < 0.0f)
      a += TWO_PI;
    return a - M_PI_F;
  }

  // Magnetic detent toward the nearest multiple of π/2. Acts when the
  // user has stopped driving (|vel| < velThresh). Pulls strongly within
  // tolRad of the snap target so screenshots land exactly on 0°/90°/etc.
  static void softLockToQuarter(float &angle, float &vel, float tolRad,
                                float velThresh) {
    if (std::abs(vel) > velThresh)
      return;
    const float QUARTER = M_PI_F * 0.5f;
    float k = std::round(angle / QUARTER);
    float target = k * QUARTER;
    float diff = target - angle;
    if (std::abs(diff) < tolRad) {
      angle = target;
      vel = 0.0f;
    }
  }
};

} // namespace space
