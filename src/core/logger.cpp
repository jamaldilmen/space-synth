#include "core/logger.h"
#include <fstream>
#include <iomanip>
#include <sstream>
#include <iostream>
#include <pwd.h>
#include <unistd.h>

namespace space {

std::vector<LogEntry> Logger::entries;
std::mutex Logger::mutex;

void Logger::log(const std::string& message) {
    std::lock_guard<std::mutex> lock(mutex);
    entries.push_back({std::chrono::system_clock::now(), message});
    
    // Also print to console for current terminal debugging
    std::cout << "[DEBUG] " << message << std::endl;
}

void Logger::clear() {
    std::lock_guard<std::mutex> lock(mutex);
    entries.clear();
}

std::string Logger::getMarkdownReport() {
    std::lock_guard<std::mutex> lock(mutex);
    std::stringstream ss;
    ss << "# Space Synth v1.0 Debug Report\n\n";
    ss << "Generated at: " << std::chrono::system_clock::to_time_t(std::chrono::system_clock::now()) << "\n\n";
    
    ss << "| Timestamp | Message |\n";
    ss << "| :--- | :--- |\n";
    
    for (const auto& entry : entries) {
        auto t = std::chrono::system_clock::to_time_t(entry.timestamp);
        ss << "| " << std::put_time(std::localtime(&t), "%H:%M:%S") << " | " << entry.message << " |\n";
    }
    
    return ss.str();
}

void Logger::exportToDownloads() {
    std::string report = getMarkdownReport();
    
    const char* homeDir = getenv("HOME");
    if (!homeDir) {
        struct passwd* pw = getpwuid(getuid());
        homeDir = pw->pw_dir;
    }
    
    if (!homeDir) return;
    
    std::string path = std::string(homeDir) + "/Downloads/SpaceSynth_v1_Log.md";
    std::ofstream f(path);
    if (f.is_open()) {
        f << report;
        f.close();
        std::cout << "[LOGGER] Report exported to: " << path << std::endl;
    }
}

} // namespace space
