#pragma once
#include <functional>
#include <string>

namespace space {

struct KeyEvent {
  int keyCode;
  bool isDown;
  bool isRepeat;
  bool shift = false;
  bool option = false;   // Option/Alt modifier (third-axis roll, 2026-07-19)
  std::string characters;
};

struct MouseEvent {
  float x, y;   // Normalized [0, 1]
  float dx, dy; // Delta in pixels
  int button;   // 0=left, 1=right
  bool isDown;
};

using KeyCallback = std::function<void(const KeyEvent &)>;
using MouseCallback = std::function<void(const MouseEvent &)>;
using ScrollCallback = std::function<void(float dx, float dy)>;
using ResizeCallback = std::function<void(int width, int height)>;
using FrameCallback = std::function<void(float dt)>;

class Window {
public:
  Window();
  ~Window();

  bool create(int width, int height, const std::string &title);

  void *metalLayer() const;
  void *metalDevice() const;

  // ── TWO-WINDOW MODE (2026-08-23, his order) ───────────────────────────────
  // "i cant have the settings in the same window im sending out."
  // Creates a SECOND, freely resizable window that owns the whole ImGui UI.
  // The main window then renders nothing but the visuals — it is the thing you
  // send out. ImGui's input is re-pointed at the settings view, so the main
  // window's mouse/keys go to the CAMERA instead of being eaten by the panels.
  // Returns false if it could not be created; the app then stays single-window.
  bool createSettingsWindow(int width, int height, const std::string &title);
  bool hasSettingsWindow() const;
  bool settingsWindowVisible() const;
  // Toggle two-window mode. Builds the window on first use. Returns true if the
  // controls are now in their own window, false if they went back to the main
  // one. Bound to I in main.cpp.
  bool toggleSettingsWindow();
  void *settingsMetalLayer() const; // CAMetalLayer*, nil when single-window

  int width() const;
  int height() const;
  float getContentScale() const;

  // ── UI SCALE (2026-08-23) ─────────────────────────────────────────────────
  // NOT the backing scale. backingScaleFactor is 1.0 in every 1x display mode,
  // so it says the same thing at 110 ppi and at 255 ppi — which is why running
  // the panel at its native 3024x1964 made the whole UI microscopic. This is
  // derived from the display's POINTS per inch instead (physical density in a
  // 1x mode, half of it at 2x — and ImGui multiplies the backing scale back in
  // afterwards), so the controls keep a constant physical size in every mode.
  // His panel measures 255 ppi physical: 3024 px across 301.21 mm.
  // Override with SS_UI_SCALE=<float> (0.5 .. 4.0).
  float getUIScale() const;

  // ── S1 (2026-08-21): PIN THE RENDER BUFFER TO EXACT PIXELS ───────────────
  // Call BEFORE create(). The whole pipeline, the Syphon feed and any
  // recording are sized from the drawable, so the drawable must be exactly
  // the output resolution — NOT whatever the screen happens to allow.
  // MEASURED failure without this: SS_WIDTH=2560 SS_HEIGHT=1024 produced a
  // 3600x2048 drawable (1.758:1, not 2.5:1) because macOS clamped the window
  // to the 1800x1130-point screen and the height picked up the x2 backing
  // scale. A recording made that way is the wrong shape permanently.
  // When pinned, the WINDOW is only a scaled preview; the buffer is exact.
  // 0,0 = follow the window, the historical behaviour.
  void pinDrawableSize(int pixelW, int pixelH);

  // Drawable size in PIXELS. width()/height() stay in POINTS because ImGui
  // lays out in points (main.cpp:857, :934) — two different quantities, and
  // the projection aspect must come from THESE.
  int drawableWidth() const;
  int drawableHeight() const;

  void setKeyCallback(KeyCallback cb);
  void setMouseCallback(MouseCallback cb);
  void setScrollCallback(ScrollCallback cb);
  void setResizeCallback(ResizeCallback cb);
  void setFrameCallback(FrameCallback cb);

  void run();
  void close();

  static std::string getExecutablePath();

  struct Impl;
  Impl *impl_;
};

} // namespace space
