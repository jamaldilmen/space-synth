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

using KeyCallback = std::function<void(const KeyEvent &)>;
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
  void setResizeCallback(ResizeCallback cb);
  void setFrameCallback(FrameCallback cb);

  void run();
  void close();

  struct Impl;
  Impl *impl_;
};

} // namespace space
