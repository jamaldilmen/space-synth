#include "ui/window.h"
#include "backends/imgui_impl_metal.h"
#include "backends/imgui_impl_osx.h"
#include "imgui.h"
#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#include <mach/mach_time.h>

// Forward declare
namespace space {
struct WindowImpl;
}

// ── Custom NSView with Metal layer ──────────────────────────────────────────

@interface SpaceSynthMetalView : NSView
@property(nonatomic, assign) space::Window::Impl *impl;
@end

@interface SpaceSynthWindowDelegate : NSObject <NSWindowDelegate>
@property(nonatomic, assign) space::Window::Impl *impl;
@end

namespace space {

struct Window::Impl {
  NSWindow *window = nil;
  SpaceSynthMetalView *metalView = nil;
  SpaceSynthWindowDelegate *delegate = nil;
  CAMetalLayer *layer = nil;
  id<MTLDevice> device = nil;

  KeyCallback keyCallback;
  MouseCallback mouseCallback;
  ScrollCallback scrollCallback;
  ResizeCallback resizeCallback;
  FrameCallback frameCallback;

  int width = 0;
  int height = 0;
  bool shouldClose = false;

  uint64_t lastFrameTime = 0;
  mach_timebase_info_data_t timebaseInfo;

  CVDisplayLinkRef displayLink = nullptr;
  dispatch_source_t frameSource = nullptr;
};

// CVDisplayLink callback — fires on display vsync
static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink,
                                    const CVTimeStamp *inNow,
                                    const CVTimeStamp *inOutputTime,
                                    CVOptionFlags flagsIn,
                                    CVOptionFlags *flagsOut, void *context) {
  auto *impl = static_cast<Window::Impl *>(context);
  // Signal the main thread to render
  if (impl->frameSource) {
    dispatch_source_merge_data(impl->frameSource, 1);
  }
  return kCVReturnSuccess;
}

} // namespace space

@implementation SpaceSynthWindowDelegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
  self.impl->shouldClose = true;
  if (self.impl->displayLink) {
    CVDisplayLinkStop(self.impl->displayLink);
  }
  [NSApp stop:nil];
  // Post a dummy event to unblock the run loop
  [NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined
                                      location:NSZeroPoint
                                 modifierFlags:0
                                     timestamp:0
                                  windowNumber:0
                                       context:nil
                                       subtype:0
                                         data1:0
                                         data2:0]
           atStart:YES];
  return YES;
}

- (void)windowDidResize:(NSNotification *)notification {
  NSRect frame = [self.impl->metalView bounds];
  CGFloat scale = [self.impl->window backingScaleFactor];
  int logicalW = (int)frame.size.width;
  int logicalH = (int)frame.size.height;
  int physicalW = (int)(frame.size.width * scale);
  int physicalH = (int)(frame.size.height * scale);

  self.impl->width = logicalW;
  self.impl->height = logicalH;
  self.impl->layer.contentsScale = scale;
  self.impl->layer.drawableSize = CGSizeMake(physicalW, physicalH);

  if (self.impl->resizeCallback) {
    self.impl->resizeCallback(physicalW, physicalH);
  }
}

@end

@implementation SpaceSynthMetalView

- (BOOL)wantsLayer {
  return YES;
}
- (BOOL)wantsUpdateLayer {
  return YES;
}

- (CALayer *)makeBackingLayer {
  CAMetalLayer *layer = [CAMetalLayer layer];
  return layer;
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)keyDown:(NSEvent *)event {
  if (ImGui::GetIO().WantCaptureKeyboard)
    return;

  printf("[KEY] down keyCode=%d\n", event.keyCode);
  if (!self.impl || !self.impl->keyCallback)
    return;
  space::KeyEvent ke;
  ke.keyCode = event.keyCode;
  ke.isDown = true;
  ke.isRepeat = event.isARepeat;
  ke.characters = event.characters ? [event.characters UTF8String] : "";
  self.impl->keyCallback(ke);
}

- (void)keyUp:(NSEvent *)event {
  if (ImGui::GetIO().WantCaptureKeyboard)
    return;

  if (!self.impl || !self.impl->keyCallback)
    return;
  space::KeyEvent ke;
  ke.keyCode = event.keyCode;
  ke.isDown = false;
  ke.isRepeat = false;
  ke.characters = event.characters ? [event.characters UTF8String] : "";
  self.impl->keyCallback(ke);
}

- (void)mouseDown:(NSEvent *)event {
  if (ImGui::GetIO().WantCaptureMouse)
    return;
  [self handleMouseEvent:event isDown:YES button:0];
}

- (void)mouseUp:(NSEvent *)event {
  [self handleMouseEvent:event isDown:NO button:0];
}

- (void)mouseDragged:(NSEvent *)event {
  [self handleMouseEvent:event isDown:YES button:0];
}

- (void)rightMouseDown:(NSEvent *)event {
  [self handleMouseEvent:event isDown:YES button:1];
}

- (void)rightMouseUp:(NSEvent *)event {
  [self handleMouseEvent:event isDown:NO button:1];
}

- (void)rightMouseDragged:(NSEvent *)event {
  [self handleMouseEvent:event isDown:YES button:1];
}

- (void)scrollWheel:(NSEvent *)event {
  if (ImGui::GetIO().WantCaptureMouse)
    return;

  if (!self.impl || !self.impl->scrollCallback)
    return;
  self.impl->scrollCallback(event.scrollingDeltaX, event.scrollingDeltaY);
}

- (void)handleMouseEvent:(NSEvent *)event
                  isDown:(BOOL)isDown
                  button:(int)button {
  if (!self.impl || !self.impl->mouseCallback)
    return;

  NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
  NSRect bounds = [self bounds];

  space::MouseEvent me;
  me.x = location.x / bounds.size.width;
  me.y = 1.0f - (location.y / bounds.size.height);
  me.dx = event.deltaX;
  me.dy = event.deltaY;
  me.isDown = isDown;
  me.button = button;
  self.impl->mouseCallback(me);
}

@end

namespace space {

Window::Window() : impl_(new Impl()) {
  mach_timebase_info(&impl_->timebaseInfo);
}

Window::~Window() {
  if (impl_->displayLink) {
    CVDisplayLinkStop(impl_->displayLink);
    CVDisplayLinkRelease(impl_->displayLink);
  }
  if (impl_->frameSource) {
    dispatch_source_cancel(impl_->frameSource);
  }
  delete impl_;
}

bool Window::create(int width, int height, const std::string &title) {
  @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    NSMenu *menubar = [[NSMenu alloc] init];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"Quit"
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
    [appMenuItem setSubmenu:appMenu];
    [NSApp setMainMenu:menubar];

    NSRect frame = NSMakeRect(100, 100, width, height);
    NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                       NSWindowStyleMaskResizable |
                       NSWindowStyleMaskMiniaturizable;

    impl_->window = [[NSWindow alloc] initWithContentRect:frame
                                                styleMask:style
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];

    [impl_->window setTitle:[NSString stringWithUTF8String:title.c_str()]];
    [impl_->window setMinSize:NSMakeSize(640, 480)];

    impl_->delegate = [[SpaceSynthWindowDelegate alloc] init];
    impl_->delegate.impl = impl_;
    [impl_->window setDelegate:impl_->delegate];

    impl_->device = MTLCreateSystemDefaultDevice();
    if (!impl_->device)
      return false;

    // Create custom NSView with CAMetalLayer (layer-hosting)
    impl_->metalView = [[SpaceSynthMetalView alloc] initWithFrame:frame];
    impl_->metalView.impl = impl_;

    CGFloat scale = [impl_->window backingScaleFactor];
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = impl_->device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = YES;
    layer.contentsScale = scale;
    layer.drawableSize = CGSizeMake(width * scale, height * scale);
    layer.maximumDrawableCount = 3;
    layer.displaySyncEnabled = YES;

    [impl_->metalView setLayer:layer];
    [impl_->metalView setWantsLayer:YES];
    impl_->layer = layer;

    // ── ImGui Initialization ──────────────────────────────────────────
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsDark();

    ImGui_ImplOSX_Init(impl_->metalView);
    ImGui_ImplMetal_Init(impl_->device);

    // Load Roboto Font
    ImGuiIO &io = ImGui::GetIO();
    NSString *fontPath = [[NSString
        stringWithUTF8String:space::Window::getExecutablePath().c_str()]
        stringByDeletingLastPathComponent];
    fontPath =
        [fontPath stringByAppendingPathComponent:
                      @"../third_party/imgui/misc/fonts/Roboto-Medium.ttf"];

    float fontSize = 16.0f * scale;
    if ([[NSFileManager defaultManager] fileExistsAtPath:fontPath]) {
      io.Fonts->AddFontFromFileTTF([fontPath UTF8String], fontSize);
    }

    io.FontGlobalScale = 1.0f / scale; // Since we loaded at physical size

    [impl_->window setContentView:impl_->metalView];
    [impl_->window makeKeyAndOrderFront:nil];
    [impl_->window makeFirstResponder:impl_->metalView];
    [NSApp activateIgnoringOtherApps:YES];

    impl_->width = width;
    impl_->height = height;
  }

  return true;
}

void *Window::metalLayer() const { return (__bridge void *)impl_->layer; }
void *Window::metalDevice() const { return (__bridge void *)impl_->device; }
int Window::width() const { return impl_->width; }
int Window::height() const { return impl_->height; }

std::string Window::getExecutablePath() {
  NSString *path = [[NSProcessInfo processInfo] arguments][0];
  return [path UTF8String];
}

void Window::setKeyCallback(KeyCallback cb) { impl_->keyCallback = cb; }
void Window::setMouseCallback(MouseCallback cb) { impl_->mouseCallback = cb; }
void Window::setScrollCallback(ScrollCallback cb) {
  impl_->scrollCallback = cb;
}
void Window::setResizeCallback(ResizeCallback cb) {
  impl_->resizeCallback = cb;
}
void Window::setFrameCallback(FrameCallback cb) { impl_->frameCallback = cb; }

void Window::run() {
  impl_->lastFrameTime = mach_absolute_time();

  // Create a dispatch source that fires on the main queue when CVDisplayLink
  // signals
  impl_->frameSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0,
                                              0, dispatch_get_main_queue());

  dispatch_source_set_event_handler(impl_->frameSource, ^{
    if (impl_->shouldClose || !impl_->frameCallback)
      return;

    uint64_t now = mach_absolute_time();
    uint64_t elapsed = now - impl_->lastFrameTime;
    impl_->lastFrameTime = now;

    double nanos =
        (double)elapsed * impl_->timebaseInfo.numer / impl_->timebaseInfo.denom;
    float dt = (float)(nanos / 1.0e9);
    if (dt > 0.033f)
      dt = 0.033f;

    ImGui_ImplMetal_NewFrame(nil);
    ImGui_ImplOSX_NewFrame(impl_->metalView);
    ImGui::NewFrame();

    impl_->frameCallback(dt);
  });
  dispatch_resume(impl_->frameSource);

  // Set up CVDisplayLink
  CVDisplayLinkCreateWithActiveCGDisplays(&impl_->displayLink);
  CVDisplayLinkSetOutputCallback(impl_->displayLink, displayLinkCallback,
                                 impl_);

  // Use the display the window is on
  NSNumber *screenNum =
      [impl_->window.screen deviceDescription][@"NSScreenNumber"];
  CGDirectDisplayID displayID =
      screenNum ? [screenNum unsignedIntValue] : CGMainDisplayID();
  CVDisplayLinkSetCurrentCGDisplay(impl_->displayLink, displayID);

  CVDisplayLinkStart(impl_->displayLink);

  // Run the app event loop — dispatch_source events fire on the main queue
  [NSApp finishLaunching];
  [NSApp run];

  // Cleanup
  if (impl_->displayLink) {
    CVDisplayLinkStop(impl_->displayLink);
  }
}

void Window::close() { impl_->shouldClose = true; }

} // namespace space
