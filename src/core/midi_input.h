#pragma once
#include <functional>

namespace space {

// Callback type: (midiNote, velocity, isNoteOn)
using MidiCallback =
    std::function<void(int note, float velocity, bool isNoteOn)>;

class MidiInput {
public:
  MidiInput();
  ~MidiInput();

  // Start listening to all MIDI sources
  bool start(MidiCallback callback);
  void stop();

  // Get connected device count
  int deviceCount() const;

  // Get name of connected device at index
  const char *deviceName(int index) const;

  bool isRunning() const { return running_; }

  struct Impl; // Public for .mm access

private:
  Impl *impl_ = nullptr;
  bool running_ = false;
};

} // namespace space
