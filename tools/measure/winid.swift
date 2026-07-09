import CoreGraphics
import Foundation

// Prints the CGWindowID of the on-screen window whose owner name contains the
// given substring (default "SpaceSynth"). Use with: screencapture -l<id> out.png
let sub = CommandLine.arguments.count >= 2 ? CommandLine.arguments[1] : "SpaceSynth"
guard let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}
for w in infos {
    let owner = (w[kCGWindowOwnerName as String] as? String) ?? ""
    let layer = (w[kCGWindowLayer as String] as? Int) ?? -1
    if owner.localizedCaseInsensitiveContains(sub) && layer == 0 {
        if let num = w[kCGWindowNumber as String] as? Int {
            print(num); exit(0)
        }
    }
}
exit(2)
