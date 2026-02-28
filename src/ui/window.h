#pragma once
#include <functional>
#include <string>

namespace space {

// Key event callback
struct KeyEvent {
    int keyCode;
    bool isDown;
    bool isRepeat;
    std::string characters;
};

using KeyCallback = std::function<void(const KeyEvent&)>;
using ResizeCallback = std::function<void(int width, int height)>;

// macOS window with Metal layer
class Window {
public:
    Window();
    ~Window();

    // Create and show window
    bool create(int width, int height, const std::string& title);

    // Get the CAMetalLayer (as void* for C++ compatibility)
    void* metalLayer() const;

    // Window size
    int width() const;
    int height() const;

    // Event callbacks
    void setKeyCallback(KeyCallback cb);
    void setResizeCallback(ResizeCallback cb);

    // Run the application event loop (blocks until window closes)
    void run();

    // Request close
    void close();

private:
    struct Impl;
    Impl* impl_;
};

} // namespace space
