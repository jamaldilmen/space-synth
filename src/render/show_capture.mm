// S8 show capture — see show_capture.h for the contract and the measurements.
#include "show_capture.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

namespace space {

struct ShowCapture::Slice {
  int x0 = 0, w = 0;
  std::string path;
  AVAssetWriter *writer = nil;
  AVAssetWriterInput *input = nil;
  AVAssetWriterInputPixelBufferAdaptor *adaptor = nil;
  // This frame's buffer, alive from encodeBlits() to appendFrame().
  CVPixelBufferRef pb = NULL;
  CVMetalTextureRef cvTex = NULL;
};

ShowCapture::ShowCapture() {}
ShowCapture::~ShowCapture() {
  if (active_) finish();
  for (Slice *s : slices_) delete s;
  if (cache_) CFRelease((CVMetalTextureCacheRef)cache_);
}

bool ShowCapture::open(int renderW, int renderH, int fps, void *mtlDevice) {
  const char *base = getenv("SS_CAPTURE");
  if (!base || !*base) return false;
  if (fps != 30 && fps != 60) {
    fprintf(stderr, "[CAPTURE] SS_CAPTURE refused: the offline clock is OFF (SS_RENDER_FPS unset). "
                    "A frame is not a unit of time without it — nothing is written.\n");
    return false;
  }
  if (renderW <= 0 || renderH <= 0 || !mtlDevice) {
    fprintf(stderr, "[CAPTURE] SS_CAPTURE refused: no render target (%dx%d).\n", renderW, renderH);
    return false;
  }
  // Slices: explicit x-widths, or one slice of the full width.
  std::vector<int> widths;
  if (const char *sl = getenv("SS_CAPTURE_SLICES")) {
    std::string s(sl);
    size_t p = 0;
    while (p <= s.size()) {
      size_t q = s.find(',', p);
      if (q == std::string::npos) q = s.size();
      int v = atoi(s.substr(p, q - p).c_str());
      if (v <= 0) { fprintf(stderr, "[CAPTURE] SS_CAPTURE_SLICES=%s refused: '%s' is not a width.\n", sl, s.substr(p, q - p).c_str()); return false; }
      widths.push_back(v);
      p = q + 1;
    }
    int sum = 0;
    for (int v : widths) sum += v;
    if (sum != renderW) {
      fprintf(stderr, "[CAPTURE] SS_CAPTURE_SLICES=%s refused: the widths sum to %d, the render is %d wide. "
                      "Nothing is written.\n", sl, sum, renderW);
      return false;
    }
  } else {
    widths.push_back(renderW);
  }
  if (const char *mf = getenv("SS_CAPTURE_FRAMES")) {
    long n = atol(mf);
    if (n <= 0) { fprintf(stderr, "[CAPTURE] SS_CAPTURE_FRAMES=%s refused (need > 0).\n", mf); return false; }
    maxFrames_ = (uint32_t)n;
  }

  id<MTLDevice> dev = (__bridge id<MTLDevice>)mtlDevice;
  CVMetalTextureCacheRef cache = NULL;
  if (CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, dev, NULL, &cache) != kCVReturnSuccess || !cache) {
    fprintf(stderr, "[CAPTURE] CVMetalTextureCacheCreate failed.\n");
    return false;
  }
  cache_ = cache;
  base_ = base;
  fps_ = fps; w_ = renderW; h_ = renderH;

  static const char *kLCR[3] = {"_L", "_C", "_R"};
  int x = 0;
  for (size_t i = 0; i < widths.size(); i++) {
    Slice *s = new Slice();
    s->x0 = x; s->w = widths[i]; x += widths[i];
    if (widths.size() == 1) s->path = base_ + ".mov";
    else if (widths.size() == 3) s->path = base_ + kLCR[i] + ".mov";
    else s->path = base_ + "_" + std::to_string(i) + ".mov";
    unlink(s->path.c_str());
    NSError *err = nil;
    s->writer = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:@(s->path.c_str())]
                                          fileType:AVFileTypeQuickTimeMovie error:&err];
    if (!s->writer) {
      fprintf(stderr, "[CAPTURE] cannot create %s: %s\n", s->path.c_str(), err.localizedDescription.UTF8String);
      delete s; return false;
    }
    NSDictionary *vs = @{
      AVVideoCodecKey: AVVideoCodecTypeAppleProRes422HQ,
      AVVideoWidthKey: @(s->w), AVVideoHeightKey: @(h_),
      AVVideoColorPropertiesKey: @{ AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2 } };
    if (![s->writer canApplyOutputSettings:vs forMediaType:AVMediaTypeVideo]) {
      fprintf(stderr, "[CAPTURE] ProRes 422 HQ %dx%d refused by AVAssetWriter.\n", s->w, h_);
      delete s; return false;
    }
    s->input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:vs];
    s->input.expectsMediaDataInRealTime = NO;
    NSDictionary *pa = @{ (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_64RGBAHalf),
                          (id)kCVPixelBufferWidthKey: @(s->w), (id)kCVPixelBufferHeightKey: @(h_),
                          (id)kCVPixelBufferMetalCompatibilityKey: @YES,
                          (id)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    s->adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:s->input
                                                                                   sourcePixelBufferAttributes:pa];
    if (![s->writer canAddInput:s->input]) { fprintf(stderr, "[CAPTURE] canAddInput failed for %s\n", s->path.c_str()); delete s; return false; }
    [s->writer addInput:s->input];
    if (![s->writer startWriting]) {
      fprintf(stderr, "[CAPTURE] startWriting failed for %s: %s\n", s->path.c_str(),
              s->writer.error.localizedDescription.UTF8String);
      delete s; return false;
    }
    [s->writer startSessionAtSourceTime:kCMTimeZero];
    if (!s->adaptor.pixelBufferPool) {
      fprintf(stderr, "[CAPTURE] the adaptor gave no pixel-buffer pool for %s (64RGBAHalf %dx%d not accepted?)\n",
              s->path.c_str(), s->w, h_);
      delete s; return false;
    }
    slices_.push_back(s);
  }
  active_ = true;
  printf("[CAPTURE] ARMED: %zu slice(s) of a %dx%d render at %d fps, ProRes 422 HQ 709, 64RGBAHalf in:\n",
         slices_.size(), w_, h_, fps_);
  for (Slice *s : slices_) printf("[CAPTURE]   x %d-%d (%d wide) -> %s\n", s->x0, s->x0 + s->w - 1, s->w, s->path.c_str());
  if (maxFrames_) printf("[CAPTURE]   stops after %u frames (SS_CAPTURE_FRAMES)\n", maxFrames_);
  else            printf("[CAPTURE]   runs until quit (SS_CAPTURE_FRAMES unset)\n");
  fflush(stdout);
  return true;
}

void ShowCapture::encodeBlits(void *mtlCommandBuffer, void *srcTexture) {
  if (!active_ || pending_) return;
  id<MTLCommandBuffer> cb = (__bridge id<MTLCommandBuffer>)mtlCommandBuffer;
  id<MTLTexture> src = (__bridge id<MTLTexture>)srcTexture;
  if ((int)src.width != w_ || (int)src.height != h_) {
    fprintf(stderr, "[CAPTURE] 🚨 source is %lux%lu, capture armed for %dx%d — DISARMED.\n",
            (unsigned long)src.width, (unsigned long)src.height, w_, h_);
    active_ = false;
    return;
  }
  id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
  for (Slice *s : slices_) {
    CVReturn r = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, s->adaptor.pixelBufferPool, &s->pb);
    if (r != kCVReturnSuccess || !s->pb) { fprintf(stderr, "[CAPTURE] pool create failed (%d) — DISARMED.\n", (int)r); active_ = false; break; }
    r = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, (CVMetalTextureCacheRef)cache_, s->pb, NULL,
                                                  MTLPixelFormatRGBA16Float, (size_t)s->w, (size_t)h_, 0, &s->cvTex);
    if (r != kCVReturnSuccess || !s->cvTex) { fprintf(stderr, "[CAPTURE] CVMetalTexture failed (%d) — DISARMED.\n", (int)r); active_ = false; break; }
    id<MTLTexture> dst = CVMetalTextureGetTexture(s->cvTex);
    [blit copyFromTexture:src sourceSlice:0 sourceLevel:0
             sourceOrigin:MTLOriginMake((NSUInteger)s->x0, 0, 0)
               sourceSize:MTLSizeMake((NSUInteger)s->w, (NSUInteger)h_, 1)
                toTexture:dst destinationSlice:0 destinationLevel:0
        destinationOrigin:MTLOriginMake(0, 0, 0)];
  }
  [blit endEncoding];
  pending_ = active_;
  if (!active_) {
    for (Slice *s : slices_) {
      if (s->cvTex) { CFRelease(s->cvTex); s->cvTex = NULL; }
      if (s->pb) { CVPixelBufferRelease(s->pb); s->pb = NULL; }
    }
  }
}

bool ShowCapture::appendFrame() {
  if (!active_ || !pending_) return false;
  pending_ = false;
  bool ok = true;
  const CMTime pts = CMTimeMake((int64_t)frames_, fps_);
  for (Slice *s : slices_) {
    int spins = 0;
    while (ok && !s->input.isReadyForMoreMediaData) { usleep(1000); if (++spins > 30000) { ok = false; fprintf(stderr, "[CAPTURE] writer %s not ready for 30 s\n", s->path.c_str()); } }
    if (ok && ![s->adaptor appendPixelBuffer:s->pb withPresentationTime:pts]) {
      ok = false;
      fprintf(stderr, "[CAPTURE] 🚨 append FAILED at frame %u for %s: %s — DISARMED.\n", frames_, s->path.c_str(),
              s->writer.error ? s->writer.error.localizedDescription.UTF8String : "(no error object)");
    }
    if (s->cvTex) { CFRelease(s->cvTex); s->cvTex = NULL; }
    if (s->pb) { CVPixelBufferRelease(s->pb); s->pb = NULL; }
  }
  if (!ok) { active_ = false; return false; }
  frames_++;
  if (frames_ == 1 || frames_ % 30 == 0 || (maxFrames_ && frames_ == maxFrames_))
    { printf("[CAPTURE] frame %u written (pts %u/%d s)\n", frames_ - 1, frames_ - 1, fps_); fflush(stdout); }
  return true;
}

void ShowCapture::finish() {
  if (slices_.empty() || finished_) return;
  finished_ = true;
  const bool wasActive = active_;
  active_ = false; pending_ = false;
  for (Slice *s : slices_) {
    if (s->cvTex) { CFRelease(s->cvTex); s->cvTex = NULL; }
    if (s->pb) { CVPixelBufferRelease(s->pb); s->pb = NULL; }
    if (!s->writer || s->writer.status != AVAssetWriterStatusWriting) continue;
    [s->input markAsFinished];
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [s->writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(sem); }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
  }
  printf("[CAPTURE] FINISHED%s: %u frame(s) at %d fps = %.3f s\n", wasActive ? "" : " (after a writer error)",
         frames_, fps_, fps_ ? (double)frames_ / fps_ : 0.0);
  for (Slice *s : slices_)
    printf("[CAPTURE]   %s  status %ld%s%s\n", s->path.c_str(), (long)s->writer.status,
           s->writer.error ? "  error: " : "", s->writer.error ? s->writer.error.localizedDescription.UTF8String : "");
  fflush(stdout);
}

} // namespace space
