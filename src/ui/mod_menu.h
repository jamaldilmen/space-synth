#pragma once
#include "core/envelope.h"
#include "render/renderer.h"
#include <string>

namespace space {

// ImGui mod menu — exposes all tweakable parameters
class ModMenu {
public:
  ModMenu();
  ~ModMenu();

  // Initialize ImGui with Metal backend
  // device = id<MTLDevice>, renderPassDesc = MTLRenderPassDescriptor
  bool init(void *device, void *view);

  // Begin a new ImGui frame (call before draw)
  void beginFrame();

  // Draw the mod menu (call between beginFrame and endFrame)
  // Returns true if any parameter changed
  struct Params {
    // Particles
    int particleCount = 1000000;
    float particleSize = 0.8f;
    float mass = 1.0f;
    float friction = 0.06f;
    float jitterScale = 6.0f;
    float speedCap = 1.2f;

    // Envelope
    EnvelopeParams envelope;

    // Rendering
    RenderConfig render;

    // Audio
    bool voiceMode = false; // false = synth, true = mic
    int audioDeviceIndex = 0;

    // Mode mapping
    bool keyboardMode = false;
    int modeDepth = 1;

    // Preset
    std::string presetName = "Default";
  };

  bool draw(Params &params);

  // Render ImGui draw data with Metal
  // encoder = id<MTLRenderCommandEncoder>
  void render(void *encoder);

  // Handle input events
  void processKeyEvent(int keyCode, bool isDown);

  void shutdown();

private:
  struct Impl;
  Impl *impl_;
  bool visible_ = true;
};

} // namespace space
