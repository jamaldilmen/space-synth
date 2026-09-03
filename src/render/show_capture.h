#pragma once
// ── SHOW CAPTURE (S8 of the show renderer, 2026-09-03) ─────────────────────
// His delivery: ONE image, 19,644 x 1680, cropped into three walls —
// L 7152 / C 5340 / R 7152 — as ProRes 422 HQ, at exactly the offline clock's
// fps. The presenting CAMetalLayer refuses any drawable above 16,384 wide
// (MEASURED 2026-09-03 18:22, the "it crashed lol" SIGSEGV), so the final
// frame is rendered into an OFFSCREEN target of the pinned size and THIS reads
// it: one Metal blit per slice into a CVPixelBuffer (64RGBAHalf, IOSurface,
// Metal-compatible — the SAME RGBA16Float the render targets are, no
// conversion) → AVAssetWriterInputPixelBufferAdaptor → ProRes 422 HQ, 709.
// MEASURED (scratchpad probe, before this file existed): the adaptor accepts
// that pixel format at 7152x1680 and 5340x1680, and the decoded frames carry
// the exact colours written.
//
// Timing: presentation time = frameIndex / fps — a FRAME is the unit, never the
// wall clock (offline clock required; refused loudly without it). Back-pressure:
// the append WAITS for the writer (usleep loop), so a slow disk slows the render
// and never drops a frame. One frame per output tick, by construction.
//
// SS_CAPTURE=<base path>            files: <base>_L.mov/_C.mov/_R.mov (3 slices),
//                                   <base>.mov (1 slice), <base>_<i>.mov otherwise
// SS_CAPTURE_SLICES=7152,5340,7152  x-widths, must sum to the render width;
//                                   unset = one file of the full width
// SS_CAPTURE_FRAMES=<n>             stop (finish + quit) after n frames; unset = until quit
#include <cstdint>
#include <string>
#include <vector>

namespace space {

class ShowCapture {
public:
  ShowCapture();
  ~ShowCapture();

  // Reads SS_CAPTURE / SS_CAPTURE_SLICES / SS_CAPTURE_FRAMES, opens one writer
  // per slice. `fps` = the offline clock's fps (0 = clock off => refused).
  // `mtlDevice` is the renderer's id<MTLDevice> (void* like the rest of src/).
  // Returns true iff capture is armed.
  bool open(int renderW, int renderH, int fps, void *mtlDevice);

  bool active() const { return active_; }
  uint32_t framesWritten() const { return frames_; }
  // SS_CAPTURE_FRAMES reached (0 = never).
  bool done() const { return active_ && maxFrames_ > 0 && frames_ >= maxFrames_; }

  // Render thread, inside the frame's command buffer, AFTER the capture target
  // holds this frame: one blit per slice from `srcTexture` (id<MTLTexture>,
  // renderW x renderH, RGBA16Float) into this frame's pixel buffers.
  void encodeBlits(void *mtlCommandBuffer, void *srcTexture);
  // After that command buffer COMPLETED: append the slices at pts frame/fps.
  // Returns false (and prints) on a writer error; capture then disarms.
  bool appendFrame();

  // Finish every writer (blocks until the files are closed) and print them.
  void finish();

private:
  struct Slice;
  std::vector<Slice *> slices_;
  void *cache_ = nullptr;        // CVMetalTextureCacheRef
  bool active_ = false;
  bool pending_ = false;         // encodeBlits() done, appendFrame() not yet
  bool finished_ = false;        // finish() ran (main calls it twice: on the frame limit and after run())
  int fps_ = 0;
  int w_ = 0, h_ = 0;
  uint32_t frames_ = 0;
  uint32_t maxFrames_ = 0;
  std::string base_;
};

} // namespace space
