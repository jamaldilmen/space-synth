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
    rho = 800.0f;
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
    // Engages only when the user has let go (small velocity) AND we're
    // within SOFT_LOCK_RAD of a quarter-turn. Acts like a magnetic
    // detent: pulls the angle the rest of the way to the snap target
    // and zeroes the residual velocity.
    constexpr float SOFT_LOCK_RAD = 0.12f;    // ≈ 6.9°
    constexpr float SOFT_LOCK_VEL = 0.003f;   // ~1°/frame at 60fps
    softLockToQuarter(phi, velPhi, SOFT_LOCK_RAD, SOFT_LOCK_VEL);
    softLockToQuarter(theta, velTheta, SOFT_LOCK_RAD, SOFT_LOCK_VEL);

    // Compute Cartesian position
    float sinTheta = std::sin(theta);
    float cosTheta = std::cos(theta);
    float sinPhi = std::sin(phi);
    float cosPhi = std::cos(phi);

    posX = rho * sinTheta * sinPhi;
    posY = rho * cosTheta;
    posZ = rho * sinTheta * cosPhi;
  }

  void rotate(float dPhi, float dTheta) {
    velPhi += dPhi;
    velTheta += dTheta;
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

    // Pole-safe reference up: when forward is nearly parallel to world up,
    // cross(up, forward) goes to zero and the basis collapses. Fall back to
    // world Z as the reference. Lets the camera pass straight through the
    // poles (theta = 0, ±π) instead of flipping or NaNing out.
    float refUp[3] = {0.0f, 1.0f, 0.0f};
    if (std::abs(forward[1]) > 0.9995f) {
      refUp[0] = 0.0f;
      refUp[1] = 0.0f;
      refUp[2] = 1.0f;
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

private:
  float rho, theta, phi;
  float velRho, velTheta, velPhi;
  float posX, posY, posZ;

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
