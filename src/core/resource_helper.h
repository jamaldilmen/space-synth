#pragma once
#include <string>
#include <CoreFoundation/CoreFoundation.h>

namespace space {

class ResourceHelper {
public:
    static std::string getResourcePath(const std::string& relativePath) {
        CFBundleRef mainBundle = CFBundleGetMainBundle();
        if (!mainBundle) return relativePath; // Fallback to current dir

        CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
        if (!resourcesURL) return relativePath;

        char path[PATH_MAX];
        if (!CFURLGetFileSystemRepresentation(resourcesURL, true, (UInt8*)path, PATH_MAX)) {
            CFRelease(resourcesURL);
            return relativePath;
        }
        CFRelease(resourcesURL);

        std::string fullPath = std::string(path) + "/" + relativePath;
        return fullPath;
    }

    static std::string getExecutablePath() {
        CFBundleRef mainBundle = CFBundleGetMainBundle();
        if (!mainBundle) return ".";

        CFURLRef bundleURL = CFBundleCopyBundleURL(mainBundle);
        if (!bundleURL) return ".";

        char path[PATH_MAX];
        CFURLGetFileSystemRepresentation(bundleURL, true, (UInt8*)path, PATH_MAX);
        CFRelease(bundleURL);
        return std::string(path);
    }
};

} // namespace space
