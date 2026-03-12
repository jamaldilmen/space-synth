#pragma once
#include <string>
#include <vector>
#include <chrono>
#include <mutex>

namespace space {

struct LogEntry {
    std::chrono::system_clock::time_point timestamp;
    std::string message;
};

class Logger {
public:
    static void log(const std::string& message);
    static void clear();
    static std::string getMarkdownReport();
    static void exportToDownloads();

private:
    static std::vector<LogEntry> entries;
    static std::mutex mutex;
};

} // namespace space
