#pragma once
#include <map>
#include <string>
#include <vector>

namespace space {

struct Preset {
  std::string name = "Untitled";

  // Physics
  float particleSize = 4.0f;
  float jitterScale = 1.0f;
  float damping = 0.95f;
  float retraction = 1.0f;
  float waveDepth = 20.0f;
  float speedCap = 1.2f;

  // Real Maxwell/String Physics parameters (Phase 5)
  float eField = 0.05f;
  float bField = 0.05f;
  float gravity = 0.005f;
  float stringStiffness = 0.01f;
  float restLength = 0.01f;
  int particleCount = 800000;
  float supernova = 0.0f;

  // Render (Future-proofing for Post-FX)
  float bloomIntensity = 0.0f;
  float trailDecay = 0.0f;
  float chromaticAberration = 0.0f;

  bool load(const std::string &path);
  bool save(const std::string &path) const;
};

class PresetManager {
public:
  static std::vector<std::string> scanPresets(const std::string &directory);
  static bool loadPreset(const std::string &path, Preset &outPreset);
  static bool savePreset(const std::string &path, const Preset &preset);
};

} // namespace space
