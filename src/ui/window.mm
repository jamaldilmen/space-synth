#include "ui/window.h"
#include "core/offline_clock.h"   // S3: SS_RENDER_FPS — unset ⇒ wall-clock dt untouched
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

// ── TWO-WINDOW MODE: the settings window's view ───────────────────────────
// Deliberately dumb. It owns a CAMetalLayer so ImGui can be drawn into it, and
// it accepts first responder so keyboard reaches ImGui. It does NOT forward to
// the app's key/mouse callbacks: camera control belongs to the OUTPUT window.
@interface SpaceSynthSettingsView : NSView
@end

@interface SpaceSynthSettingsDelegate : NSObject <NSWindowDelegate>
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

  // TWO-WINDOW MODE (2026-08-23) — nil unless createSettingsWindow() ran.
  NSWindow *settingsWindow = nil;
  SpaceSynthSettingsView *settingsView = nil;
  SpaceSynthSettingsDelegate *settingsDelegate = nil;
  CAMetalLayer *settingsLayer = nil;
  bool settingsVisible = false;

  KeyCallback keyCallback;
  MouseCallback mouseCallback;
  ScrollCallback scrollCallback;
  ResizeCallback resizeCallback;
  FrameCallback frameCallback;

  int width = 0;      // POINTS (ImGui lays out in these)
  int height = 0;
  int pinnedW = 0;    // S1: exact render pixels, 0 = follow the window
  int pinnedH = 0;
  int drawW = 0;      // PIXELS actually allocated for the drawable
  int drawH = 0;
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

@implementation SpaceSynthSettingsView
- (BOOL)wantsLayer { return YES; }
- (BOOL)wantsUpdateLayer { return YES; }
- (CALayer *)makeBackingLayer { return [CAMetalLayer layer]; }
- (BOOL)acceptsFirstResponder { return YES; }
@end

@implementation SpaceSynthSettingsDelegate
- (void)windowDidResize:(NSNotification *)notification {
  if (!self.impl || !self.impl->settingsLayer)
    return;
  NSRect b = [self.impl->settingsView bounds];
  CGFloat scale = [self.impl->settingsWindow backingScaleFactor];
  self.impl->settingsLayer.contentsScale = scale;
  // Free-floating: this window is NOT subject to the pinned render size. It is
  // a control surface, not a render target, so it may be any size he likes.
  self.impl->settingsLayer.drawableSize =
      CGSizeMake(b.size.width * scale, b.size.height * scale);
}
- (BOOL)windowShouldClose:(NSWindow *)sender {
  // Closing the settings window must NOT kill the show. Hide it, and hand the
  // UI back to the main window so he is never left with no controls at all.
  if (self.impl) {
    self.impl->settingsVisible = false;
    ImGui_ImplOSX_Shutdown();
    ImGui_ImplOSX_Init(self.impl->metalView);
  }
  [sender orderOut:nil];
  return NO;
}
@end

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

  // S1: a PINNED buffer is not a function of the window. Resizing, zooming or
  // entering fullscreen must not change the number of pixels we render, or a
  // recording changes resolution mid-take.
  if (self.impl->pinnedW > 0 && self.impl->pinnedH > 0) {
    physicalW = self.impl->pinnedW;
    physicalH = self.impl->pinnedH;
  }
  self.impl->drawW = physicalW;
  self.impl->drawH = physicalH;
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
  ke.shift = (event.modifierFlags & NSEventModifierFlagShift) != 0;
  ke.option = (event.modifierFlags & NSEventModifierFlagOption) != 0;
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
  ke.shift = (event.modifierFlags & NSEventModifierFlagShift) != 0;
  ke.option = (event.modifierFlags & NSEventModifierFlagOption) != 0;
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
  if (ImGui::GetIO().WantCaptureMouse)
    return;
  [self handleMouseEvent:event isDown:YES button:0];
}

- (void)rightMouseDown:(NSEvent *)event {
  if (ImGui::GetIO().WantCaptureMouse)
    return;
  [self handleMouseEvent:event isDown:YES button:1];
}

- (void)rightMouseUp:(NSEvent *)event {
  [self handleMouseEvent:event isDown:NO button:1];
}

- (void)rightMouseDragged:(NSEvent *)event {
  if (ImGui::GetIO().WantCaptureMouse)
    return;
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

    // S1: when the buffer is pinned, the window exists only to LOOK at it.
    // Fit it inside the visible screen area preserving the pinned aspect, so
    // macOS never clamps it into a different shape. The drawable stays exact.
    if (impl_->pinnedW > 0 && impl_->pinnedH > 0) {
      CGFloat sc = [[NSScreen mainScreen] backingScaleFactor];
      if (sc < 1.0) sc = 1.0;
      double wantW = impl_->pinnedW / sc;      // points needed to show 1:1
      double wantH = impl_->pinnedH / sc;
      NSRect vis = [[NSScreen mainScreen] visibleFrame];
      double maxW = vis.size.width * 0.92, maxH = vis.size.height * 0.92;
      double k = 1.0;
      if (wantW > maxW) k = maxW / wantW;
      if (wantH * k > maxH) k = maxH / wantH;
      width  = (int)(wantW * k);
      height = (int)(wantH * k);
      printf("[S1] render buffer PINNED %dx%d px (%.4f:1); preview window "
             "%dx%d pt (%.0f%% scale)\n",
             impl_->pinnedW, impl_->pinnedH,
             (double)impl_->pinnedW / (double)impl_->pinnedH,
             width, height, k * 100.0);
    }
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
    // ── EDR / HDR output ────────────────────────────────────────────────
    // RGBA16Float drawable + extended-sRGB colorspace: values in [0,1] map
    // exactly like SDR sRGB (existing look preserved), and values ABOVE 1.0
    // extend into the display's HDR headroom. wantsEDR opts the layer into the
    // brighter-than-white range so glow/highlights actually use the panel's
    // peak brightness. On an SDR display headroom is 1.0 and this is a no-op.
    layer.pixelFormat = MTLPixelFormatRGBA16Float;
    layer.wantsExtendedDynamicRangeContent = YES;
    CGColorSpaceRef edrSpace =
        CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB);
    layer.colorspace = edrSpace;
    CGColorSpaceRelease(edrSpace);
    layer.framebufferOnly = NO; // drawable is blit-copied for the trail buffer
    // ── LETTERBOX, NEVER STRETCH (2026-08-23) ────────────────────────────────
    // CALayer's default contentsGravity is kCAGravityResize, which scales the
    // drawable to the layer's box on EACH AXIS INDEPENDENTLY. With a pinned
    // drawable that is not the window's shape, that is a non-uniform scale:
    // pinned 3840x1536 (2.5:1) shown fullscreen on a 3024x1964 (1.539:1) screen
    // scaled x by 0.788 and y by 1.279 — a 1.62x vertical stretch, and every
    // circular orbit rendered as a vertical egg. His screenshot, 12:14.
    // ResizeAspect preserves the ratio and letterboxes instead, so a pinned
    // 2.5:1 render previews as a true 2.5:1 image with bars. The RENDER is
    // unaffected either way — this is purely how the finished drawable is
    // fitted into the window.
    layer.contentsGravity = kCAGravityResizeAspect;
    layer.contentsScale = scale;
    if (impl_->pinnedW > 0 && impl_->pinnedH > 0) {
      layer.drawableSize = CGSizeMake(impl_->pinnedW, impl_->pinnedH);
      impl_->drawW = impl_->pinnedW;
      impl_->drawH = impl_->pinnedH;
    } else {
      layer.drawableSize = CGSizeMake(width * scale, height * scale);
      impl_->drawW = (int)(width * scale);
      impl_->drawH = (int)(height * scale);
    }
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
    NSString *fontPath = [[NSBundle mainBundle] pathForResource:@"Roboto-Medium" ofType:@"ttf" inDirectory:@"fonts"];
    if (!fontPath) {
      // Fallback for build directory
      NSString *execPath = [[[NSProcessInfo processInfo] arguments][0] stringByDeletingLastPathComponent];
      fontPath = [execPath stringByAppendingPathComponent:@"../third_party/imgui/misc/fonts/Roboto-Medium.ttf"];
    }

    // `scale` is the BACKING scale and is only about crispness: render the
    // glyphs at device resolution, then divide back down so they occupy the
    // right number of POINTS. uiScale is a separate axis — how big the UI
    // should be to the eye — and comes from physical DPI, not from backing.
    const float uiScale = getUIScale();
    float baseFontSize = 20.0f; // chosen at ~110 ppi
    float fontSize = baseFontSize * uiScale * scale;
    if ([[NSFileManager defaultManager] fileExistsAtPath:fontPath]) {
      io.Fonts->AddFontFromFileTTF([fontPath UTF8String], fontSize);
    }

    io.FontGlobalScale = 1.0f / scale;

    [impl_->window setContentView:impl_->metalView];
    // ── SS_SCREEN: put the window on a chosen display BEFORE it is shown ──
    // (2026-08-27, his order "relaunch on screen 2 in 4k".) The app sized
    // itself from [NSScreen mainScreen] and toggleFullScreen: takes whatever
    // screen the window is already on, so with no way to move it there was no
    // route to a second display at all.
    //
    // SS_SCREEN is an INDEX into [NSScreen screens] (0-based). Out-of-range or
    // unset leaves the existing behaviour untouched, so this is inert unless
    // asked for. The window frame is already in GLOBAL coordinates, so simply
    // re-origining it inside the target screen's frame is enough — the
    // fullscreen toggle below then lands on that screen.
    //
    // ⚠️ SEPARATE CONCERN from the physics change in particles.metal. This
    // file, this commit, independently verifiable: launch with SS_SCREEN=1 and
    // read the [SCREEN] line it prints.
    if (const char *ss = getenv("SS_SCREEN")) {
      NSArray<NSScreen *> *screens = [NSScreen screens];
      int idx = atoi(ss);
      if (idx >= 0 && idx < (int)screens.count) {
        NSScreen *target = screens[(NSUInteger)idx];
        NSRect sf = [target frame];
        NSRect wf = [impl_->window frame];
        // Centre it on the target screen; fullscreen replaces this anyway, but
        // a sane windowed position matters if SS_FULLSCREEN is not set.
        NSPoint o = NSMakePoint(sf.origin.x + (sf.size.width  - wf.size.width)  * 0.5,
                                sf.origin.y + (sf.size.height - wf.size.height) * 0.5);
        [impl_->window setFrameOrigin:o];
        printf("[SCREEN] index %d of %lu -> %.0fx%.0f @ %ld Hz origin(%.0f,%.0f) "
               "backing=%.1f EDRmax=%.2f\n",
               idx, (unsigned long)screens.count, sf.size.width, sf.size.height,
               (long)[target maximumFramesPerSecond], sf.origin.x, sf.origin.y,
               [target backingScaleFactor],
               [target maximumExtendedDynamicRangeColorComponentValue]);
      } else {
        printf("[SCREEN] SS_SCREEN=%s out of range (%lu screens) — ignored\n",
               ss, (unsigned long)screens.count);
      }
    }
    [impl_->window makeKeyAndOrderFront:nil];
    [impl_->window makeFirstResponder:impl_->metalView];
    [NSApp activateIgnoringOtherApps:YES];

    // ── FULLSCREEN AT LAUNCH ─────────────────────────────────────────────────
    // His standing order, 2026-08-10 17:12:00: "WHENEVER U LAUNCH THE APP LAUNCH
    // IT IN FULL SCREEN. IT LOOKS DIFFERENT IN WINDOW V FULL SCREEN."
    //
    // He is right that it looks different, and the reason is not subtle: star
    // size is written to out.pointSize, which is Metal's [[point_size]] — a size
    // in DEVICE PIXELS. Nothing in render.metal normalises it to the drawable.
    // So a star is the same number of pixels at any window size, and the drawable
    // is what changes: fullscreen on a Retina panel is several times the pixel
    // count of a window, so each star covers a SMALLER FRACTION of the screen —
    // finer points, denser-looking field. Windowed, the same stars are fatter
    // relative to the frame. The physics is identical; only the size unit is
    // resolution-dependent. (Same reason [KPROBE-SCALE] meanPx ~1.0 means very
    // different things at two window sizes.)
    //
    // Toggled AFTER makeKeyAndOrderFront — AppKit ignores toggleFullScreen: on a
    // window that has not been shown. Requires NSWindowStyleMaskResizable, which
    // is already set above.
    //
    // Env-gated so a plain double-click still opens windowed; the test harness
    // sets SS_FULLSCREEN=1. Launch with:
    //   open -n SpaceSynth.app --env SS_FULLSCREEN=1
    if (getenv("SS_FULLSCREEN")) {
      [impl_->window toggleFullScreen:nil];
    }

    impl_->width = width;
    impl_->height = height;
  }

  return true;
}

void *Window::metalLayer() const { return (__bridge void *)impl_->layer; }
void *Window::metalDevice() const { return (__bridge void *)impl_->device; }
int Window::width() const { return impl_->width; }
int Window::height() const { return impl_->height; }
bool Window::canAllocateDrawable(int pixelW, int pixelH) {
  if (pixelW <= 0 || pixelH <= 0) return false;
  // Metal's own descriptor validation ABORTS (it does not return nil) above
  // the device ceiling — MEASURED 2026-09-03 18:24:10 on the M5 Max:
  // "MTLTextureDescriptor has width (200000) greater than the maximum allowed
  // size of 32768." So the ceiling is checked here, before any descriptor
  // exists. 32768 is that message's number for this GPU family, not a guess.
  const int kMetalMaxDim = 32768;
  if (pixelW > kMetalMaxDim || pixelH > kMetalMaxDim) return false;
  @autoreleasepool {
    id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
    if (!dev) return false;
    // The drawable's own format (see the layer setup below) so the probe asks
    // the exact question the render will.
    MTLTextureDescriptor *td = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                     width:(NSUInteger)pixelW
                                    height:(NSUInteger)pixelH
                                 mipmapped:NO];
    td.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    td.storageMode = MTLStorageModePrivate;
    id<MTLTexture> t = nil;
    @try { t = [dev newTextureWithDescriptor:td]; } @catch (NSException *e) { t = nil; }
    if (!t) return false;
    // MEASURED 2026-09-03 18:22:51 (crash) + probe: every offscreen texture
    // allocates at 19,644 wide, but the CAMetalLayer that PRESENTS refuses a
    // drawable above 16,384 — nextDrawable returns nil and drawableSize reads
    // 0x0 — and the final blit then copies from a nil drawable (SIGSEGV in
    // renderWithCamera). Until the capture stage renders the final frame into
    // an offscreen target, the pinned size must also be presentable, so the
    // layer is asked directly rather than a number typed here.
    CAMetalLayer *probe = [CAMetalLayer layer];
    probe.device = dev;
    probe.pixelFormat = MTLPixelFormatRGBA16Float;
    probe.drawableSize = CGSizeMake(pixelW, pixelH);
    id<CAMetalDrawable> dr = [probe nextDrawable];
    if (!dr) {
      fprintf(stderr, "[S1] the display layer cannot present a %dx%d drawable (nextDrawable nil, layer reports "
                      "%.0fx%.0f). Offscreen textures allocate at this size; the on-screen drawable does not. "
                      "A wall-size render needs the offscreen capture target (S8).\n",
              pixelW, pixelH, probe.drawableSize.width, probe.drawableSize.height);
      return false;
    }
    return true;
  }
}

void Window::pinDrawableSize(int pixelW, int pixelH) {
  impl_->pinnedW = pixelW;
  impl_->pinnedH = pixelH;
}
int Window::drawableWidth() const {
  return impl_->drawW > 0 ? impl_->drawW : impl_->width;
}
int Window::drawableHeight() const {
  return impl_->drawH > 0 ? impl_->drawH : impl_->height;
}

float Window::getUIScale() const {
  // Explicit override always wins.
  if (const char *e = getenv("SS_UI_SCALE")) {
    float v = (float)atof(e);
    if (v >= 0.5f && v <= 4.0f)
      return v;
    fprintf(stderr, "[UI] SS_UI_SCALE=%s out of range 0.5..4.0, ignored\n", e);
  }
  CGDirectDisplayID d = CGMainDisplayID();
  CGSize mm = CGDisplayScreenSize(d); // physical, in millimetres
  size_t px = CGDisplayPixelsWide(d);
  if (mm.width <= 1.0 || px == 0)
    return 1.0f; // projectors and some externals report no physical size
  // ⚠️ CGDisplayPixelsWide returns the CURRENT MODE's width in POINTS, not the
  // panel's physical pixels. So this quantity is POINTS per inch, and it is
  // only equal to the panel's physical density in a 1x mode. That is exactly
  // what we want: ImGui multiplies by the backing scale afterwards, so
  // pointsPerInch * backing == physical density in EVERY mode, and the UI
  // keeps one physical size. Measured on his panel 2026-08-23 14:47:
  //   1x  3024x1964 -> 255.0 ppi -> 2.32x, backing 1.0 -> 2.32x total
  //   2x  1512x982  -> 127.5 ppi -> 1.16x, backing 2.0 -> 2.32x total
  // Physical panel density is 255 ppi (3024 px / 11.859 in). Do not "fix" the
  // 127.5 case; it is the same answer expressed in the other mode.
  const double pointsPerInch = (double)px / (mm.width / 25.4);
  // 110 ppi is the density the 20 px base font was chosen for.
  double s = pointsPerInch / 110.0;
  if (s < 1.0) s = 1.0;
  if (s > 3.0) s = 3.0;
  printf("[UI] display %.1f points/inch (x backing = physical) -> UI scale "
         "%.2fx (SS_UI_SCALE overrides)\n",
         pointsPerInch, s);
  return (float)s;
}

float Window::getContentScale() const {
  if (impl_->window)
    return [impl_->window backingScaleFactor];
  return 1.0f;
}

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

bool Window::createSettingsWindow(int width, int height,
                                  const std::string &title) {
  @autoreleasepool {
    if (impl_->settingsWindow)
      return true; // already up
    if (!impl_->device)
      return false;

    NSRect frame = NSMakeRect(0, 0, width, height);
    NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                       NSWindowStyleMaskResizable |
                       NSWindowStyleMaskMiniaturizable;
    impl_->settingsWindow =
        [[NSWindow alloc] initWithContentRect:frame
                                    styleMask:style
                                      backing:NSBackingStoreBuffered
                                        defer:NO];
    if (!impl_->settingsWindow)
      return false;

    [impl_->settingsWindow
        setTitle:[NSString stringWithUTF8String:title.c_str()]];
    // A control surface should never be the thing that goes fullscreen onto the
    // wall by accident.
    [impl_->settingsWindow
        setCollectionBehavior:NSWindowCollectionBehaviorFullScreenAuxiliary];

    impl_->settingsView =
        [[SpaceSynthSettingsView alloc] initWithFrame:frame];

    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = impl_->device;
    // ⭐ IDENTICAL to the main window's layer, on purpose (2026-08-23).
    // The first attempt used BGRA8Unorm with the default colorspace and he
    // said it "looked like shit" — correctly. The theme's colours are authored
    // for the main window's RGBA16Float + extended-sRGB layer, where [0,1]
    // maps exactly like sRGB. Writing those same values into a plain UNORM
    // target skips that mapping, so every colour lands at the wrong gamma.
    // Same format + same colorspace = the panels look exactly as they do in
    // the synth window, which is what he asked for.
    layer.pixelFormat = MTLPixelFormatRGBA16Float;
    layer.wantsExtendedDynamicRangeContent = YES;
    CGColorSpaceRef uiSpace =
        CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB);
    layer.colorspace = uiSpace;
    CGColorSpaceRelease(uiSpace);
    layer.framebufferOnly = YES;
    CGFloat scale = [impl_->settingsWindow backingScaleFactor];
    layer.contentsScale = scale;
    layer.drawableSize = CGSizeMake(width * scale, height * scale);

    [impl_->settingsView setLayer:layer];
    [impl_->settingsView setWantsLayer:YES];
    impl_->settingsLayer = layer;

    impl_->settingsDelegate = [[SpaceSynthSettingsDelegate alloc] init];
    impl_->settingsDelegate.impl = impl_;
    [impl_->settingsWindow setDelegate:impl_->settingsDelegate];
    [impl_->settingsWindow setContentView:impl_->settingsView];

    // ⭐ RE-POINT IMGUI'S INPUT AT THE SETTINGS VIEW. Without this the panels
    // draw in the new window but only respond to clicks in the old one.
    ImGui_ImplOSX_Shutdown();
    ImGui_ImplOSX_Init(impl_->settingsView);

    // Put it beside the output window rather than on top of it.
    [impl_->settingsWindow cascadeTopLeftFromPoint:NSMakePoint(40, 40)];
    [impl_->settingsWindow makeKeyAndOrderFront:nil];
    [impl_->settingsWindow makeFirstResponder:impl_->settingsView];
    impl_->settingsVisible = true;
    return true;
  }
}

bool Window::hasSettingsWindow() const {
  return impl_->settingsWindow != nil;
}

bool Window::settingsWindowVisible() const { return impl_->settingsVisible; }

bool Window::toggleSettingsWindow() {
  @autoreleasepool {
    if (!impl_->settingsWindow) {
      // First press builds it. Nothing is allocated until he asks for it.
      if (!createSettingsWindow(560, 900, "SPACE Synth — Controls"))
        return false;
      return impl_->settingsVisible;
    }
    if (impl_->settingsVisible) {
      impl_->settingsVisible = false;
      ImGui_ImplOSX_Shutdown();
      ImGui_ImplOSX_Init(impl_->metalView); // controls return to the main window
      [impl_->settingsWindow orderOut:nil];
    } else {
      impl_->settingsVisible = true;
      ImGui_ImplOSX_Shutdown();
      ImGui_ImplOSX_Init(impl_->settingsView);
      [impl_->settingsWindow makeKeyAndOrderFront:nil];
      [impl_->settingsWindow makeFirstResponder:impl_->settingsView];
    }
    return impl_->settingsVisible;
  }
}

void *Window::settingsMetalLayer() const {
  return (__bridge void *)impl_->settingsLayer;
}

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
    // S3 OFFLINE: this dt drives the sequencer, camera rides and the VJ
    // crossfade in main.cpp. Offline they must advance in the same frame time
    // as physics (1/fps), not in wall time. Unset ⇒ the wall dt above.
    if (space::OfflineClock::get().enabled) dt = (float)space::OfflineClock::get().frameDt;
    // ⏱️ 2026-08-30 — WAS clamped to 0.033 s, i.e. THE WALL CLOCK LIED BELOW
    // 30 fps. This delta is the real-time anchor for everything that is
    // legitimately real-time: the sequencer (main.cpp:638 `seqTime += dt`), the
    // VJ band release/crossfade rates, the camera spin integration and
    // camera.update(dt), and the smoothedAmp time constants. He runs 32-52 fps,
    // so at the low end every one of those ran up to 24% slow — his RHYTHM
    // included, which is fatal in an instrument and invisible in a wallpaper.
    // A bound is still wanted for genuine stalls (window drag, display wake),
    // but 0.033 is not a stall guard, it is a 30 fps ceiling. 0.25 s is the same
    // bound the physics accumulator uses, so both clocks now agree on what
    // counts as a stall.
    if (dt > 0.25f)
      dt = 0.25f;

    ImGui_ImplMetal_NewFrame(nil);
    // DisplaySize comes from whichever view actually hosts the UI.
    ImGui_ImplOSX_NewFrame(impl_->settingsVisible
                               ? (NSView *)impl_->settingsView
                               : (NSView *)impl_->metalView);
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

// S8: an unattended render must be able to END. Before 2026-09-03 this only
// raised the flag (frame callbacks stop; the NSApp loop kept running) and had
// no callers. Now it does what the close button does (windowShouldClose:).
void Window::close() {
  impl_->shouldClose = true;
  if (impl_->displayLink) CVDisplayLinkStop(impl_->displayLink);
  [NSApp stop:nil];
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
}

} // namespace space
