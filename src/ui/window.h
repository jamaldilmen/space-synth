#pragma once
#include <functional>
#include <string>

namespace space {

struct KeyEvent {
  int keyCode;
  bool isDown;
  bool isRepeat;
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

  int width() const;
  int height() const;

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
