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
    theta = 0.5f; // Elevation
    phi = 0.0f;   // Azimuth
    velRho = velTheta = velPhi = 0.0f;
  }

  void update(float dt) {
    // Velocity-based damping for inertia
    float friction = std::max(0.0f, 1.0f - dt * 6.0f);
    velPhi *= friction;
    velTheta *= friction;
    velRho *= friction;

    phi += velPhi;
    theta = std::max(0.01f, std::min(M_PI_F - 0.01f, theta + velTheta));
    rho = std::max(100.0f, std::min(2000.0f, rho + velRho));

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

  void buildViewMatrix(float *out) const {
    // LookAt(pos, [0,0,0], [0,1,0])
    float forward[3] = {-posX, -posY, -posZ};
    float len = std::sqrt(forward[0] * forward[0] + forward[1] * forward[1] +
                          forward[2] * forward[2]);
    forward[0] /= len;
    forward[1] /= len;
    forward[2] /= len;

    float up[3] = {0, 1, 0};
    float right[3] = {up[1] * forward[2] - up[2] * forward[1],
                      up[2] * forward[0] - up[0] * forward[2],
                      up[0] * forward[1] - up[1] * forward[0]};
    len = std::sqrt(right[0] * right[0] + right[1] * right[1] +
                    right[2] * right[2]);
    right[0] /= len;
    right[1] /= len;
    right[2] /= len;

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
};

} // namespace space
