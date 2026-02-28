#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#include "ui/window.h"

// ── Custom NSWindow delegate ────────────────────────────────────────────────

@interface SpaceSynthWindowDelegate : NSObject <NSWindowDelegate>
@property (nonatomic, assign) space::Window::Impl* impl;
@end

// ── Custom MTKView subclass for key events ──────────────────────────────────

@interface SpaceSynthView : MTKView
@property (nonatomic, assign) space::Window::Impl* impl;
@end

namespace space {

struct Window::Impl {
    NSWindow* window = nil;
    SpaceSynthView* metalView = nil;
    SpaceSynthWindowDelegate* delegate = nil;
    CAMetalLayer* layer = nil;

    KeyCallback keyCallback;
    ResizeCallback resizeCallback;

    int width = 0;
    int height = 0;
    bool shouldClose = false;
};

} // namespace space

@implementation SpaceSynthWindowDelegate

- (BOOL)windowShouldClose:(NSWindow*)sender {
    self.impl->shouldClose = true;
    [NSApp stop:nil];
    return YES;
}

- (void)windowDidResize:(NSNotification*)notification {
    NSRect frame = [self.impl->metalView bounds];
    float scale = self.impl->window.backingScaleFactor;
    int w = (int)(frame.size.width * scale);
    int h = (int)(frame.size.height * scale);
    self.impl->width = w;
    self.impl->height = h;
    if (self.impl->resizeCallback) {
        self.impl->resizeCallback(w, h);
    }
}

@end

@implementation SpaceSynthView

- (BOOL)acceptsFirstResponder { return YES; }

- (void)keyDown:(NSEvent*)event {
    if (!self.impl->keyCallback) return;
    space::KeyEvent ke;
    ke.keyCode = event.keyCode;
    ke.isDown = true;
    ke.isRepeat = event.isARepeat;
    ke.characters = event.characters ? [event.characters UTF8String] : "";
    self.impl->keyCallback(ke);
}

- (void)keyUp:(NSEvent*)event {
    if (!self.impl->keyCallback) return;
    space::KeyEvent ke;
    ke.keyCode = event.keyCode;
    ke.isDown = false;
    ke.isRepeat = false;
    ke.characters = event.characters ? [event.characters UTF8String] : "";
    self.impl->keyCallback(ke);
}

@end

namespace space {

Window::Window() : impl_(new Impl()) {}

Window::~Window() {
    delete impl_;
}

bool Window::create(int width, int height, const std::string& title) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        NSRect frame = NSMakeRect(100, 100, width, height);
        NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                           NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable;

        impl_->window = [[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:style
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];

        [impl_->window setTitle:[NSString stringWithUTF8String:title.c_str()]];
        [impl_->window setMinSize:NSMakeSize(640, 480)];

        // Create delegate
        impl_->delegate = [[SpaceSynthWindowDelegate alloc] init];
        impl_->delegate.impl = impl_;
        [impl_->window setDelegate:impl_->delegate];

        // Create Metal view
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) return false;

        impl_->metalView = [[SpaceSynthView alloc] initWithFrame:frame device:device];
        impl_->metalView.impl = impl_;
        impl_->metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        impl_->metalView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        impl_->metalView.preferredFramesPerSecond = 120;
        impl_->metalView.enableSetNeedsDisplay = NO;
        impl_->metalView.paused = YES;  // We drive rendering ourselves

        impl_->layer = (CAMetalLayer*)impl_->metalView.layer;

        [impl_->window setContentView:impl_->metalView];
        [impl_->window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];

        float scale = impl_->window.backingScaleFactor;
        impl_->width = (int)(width * scale);
        impl_->height = (int)(height * scale);
    }

    return true;
}

void* Window::metalLayer() const {
    return (__bridge void*)impl_->layer;
}

int Window::width() const { return impl_->width; }
int Window::height() const { return impl_->height; }

void Window::setKeyCallback(KeyCallback cb) { impl_->keyCallback = cb; }
void Window::setResizeCallback(ResizeCallback cb) { impl_->resizeCallback = cb; }

void Window::run() {
    // Main run loop — process events, then yield for rendering
    while (!impl_->shouldClose) {
        @autoreleasepool {
            NSEvent* event;
            while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                              untilDate:nil
                                                 inMode:NSDefaultRunLoopMode
                                                dequeue:YES])) {
                [NSApp sendEvent:event];
            }
        }
        // TODO: Call into renderer here, driven by CVDisplayLink or manual timer
    }
}

void Window::close() {
    impl_->shouldClose = true;
}

} // namespace space
