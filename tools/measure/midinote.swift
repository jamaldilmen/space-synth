import CoreMIDI
import Foundation

// Two modes to the same IAC destination (real MIDI path):
//   midinote <destSub> hold <sec> <n1,n2,..> [vel]
//   midinote <destSub> pat  <cycles> <onSec> <offSec> <n1,n2,..> [vel]
// pat = retriggered staccato: (note-on, hold onSec, note-off, wait offSec) × cycles.

let a = CommandLine.arguments
func die(_ s: String) -> Never { FileHandle.standardError.write(s.data(using:.utf8)!); exit(2) }
guard a.count >= 4 else { die("usage: midinote <dest> hold|pat ...\n") }
let destSub = a[1]; let mode = a[2]

var client = MIDIClientRef(); MIDIClientCreate("midinote.client" as CFString, nil, nil, &client)
var outPort = MIDIPortRef(); MIDIOutputPortCreate(client, "midinote.out" as CFString, &outPort)
var dest: MIDIEndpointRef = 0; var destName = ""
for i in 0..<MIDIGetNumberOfDestinations() {
    let d = MIDIGetDestination(i); var cf: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(d, kMIDIPropertyDisplayName, &cf)
    let name = (cf?.takeRetainedValue() as String?) ?? ""
    if name.localizedCaseInsensitiveContains(destSub) { dest = d; destName = name; break }
}
guard dest != 0 else { die("no MIDI dest matching '\(destSub)'\n") }

func send(_ b: [UInt8]) {
    var pkt = MIDIPacketList(); let p = MIDIPacketListInit(&pkt)
    _ = MIDIPacketListAdd(&pkt, 1024, p, 0, b.count, b); MIDISend(outPort, dest, &pkt)
}
func on(_ ns: [UInt8], _ v: UInt8)  { for n in ns { send([0x90, n, v]) } }
func off(_ ns: [UInt8])             { for n in ns { send([0x80, n, 0]) } }

if mode == "hold" {
    let hold = Double(a[3]) ?? 5
    let notes = a[4].split(separator: ",").compactMap { UInt8($0) }
    let vel: UInt8 = a.count >= 6 ? (UInt8(a[5]) ?? 100) : 100
    print("→ \(destName)  hold \(hold)s  \(notes)")
    on(notes, vel); Thread.sleep(forTimeInterval: hold); off(notes)
} else if mode == "pat" {
    let cycles = Int(a[3]) ?? 30
    let onS = Double(a[4]) ?? 0.4, offS = Double(a[5]) ?? 0.2
    let notes = a[6].split(separator: ",").compactMap { UInt8($0) }
    let vel: UInt8 = a.count >= 8 ? (UInt8(a[7]) ?? 100) : 100
    print("→ \(destName)  pat \(cycles)×(on \(onS)s/off \(offS)s)  \(notes)")
    for _ in 0..<cycles {
        on(notes, vel);  Thread.sleep(forTimeInterval: onS)
        off(notes);      Thread.sleep(forTimeInterval: offS)
    }
} else if mode == "arp" {
    // Accelerating ascending arp: <passes> ascending sweeps of <notes>, the
    // per-step gap shrinking from startGap→endGap across passes (accelerando).
    // midinote <dest> arp <passes> <startGap> <endGap> <n1,n2,..> [vel]
    let passes = Int(a[3]) ?? 3
    let g0 = Double(a[4]) ?? 0.20, g1 = Double(a[5]) ?? 0.05
    let notes = a[6].split(separator: ",").compactMap { UInt8($0) }
    let vel: UInt8 = a.count >= 8 ? (UInt8(a[7]) ?? 100) : 100
    print("→ \(destName)  arp \(passes)× accel \(g0)→\(g1)s  \(notes)")
    for p in 0..<passes {
        let gap = passes > 1 ? g0 + (g1 - g0) * Double(p) / Double(passes - 1) : g0
        for n in notes {
            on([n], vel); Thread.sleep(forTimeInterval: gap * 0.6)
            off([n]);     Thread.sleep(forTimeInterval: gap * 0.4)
        }
    }
} else { die("mode must be hold|pat|arp\n") }
print("done")
