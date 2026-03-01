#include "core/preset_manager.h"
#include <dirent.h>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <unistd.h>
#include <vector>

namespace space {

// Simple, dependency-free JSON parser
static std::string findValue(const std::string &json, const std::string &key) {
  size_t keyPos = json.find("\"" + key + "\"");
  if (keyPos == std::string::npos)
    return "";

  size_t colonPos = json.find(":", keyPos);
  if (colonPos == std::string::npos)
    return "";

  size_t startPos = json.find_first_not_of(" \t\n\r", colonPos + 1);
  if (startPos == std::string::npos)
    return "";

  size_t endPos;
  if (json[startPos] == '\"') {
    startPos++;
    endPos = json.find('\"', startPos);
  } else {
    endPos = json.find_first_of(" \t\n\r,}", startPos);
  }

  if (endPos == std::string::npos)
    return "";
  return json.substr(startPos, endPos - startPos);
}

bool Preset::load(const std::string &path) {
  std::ifstream f(path);
  if (!f.is_open())
    return false;

  std::stringstream buffer;
  buffer << f.rdbuf();
  std::string json = buffer.str();

  std::string val;
  val = findValue(json, "name");
  if (!val.empty())
    name = val;

  // Physics
  if (!(val = findValue(json, "size")).empty())
    particleSize = std::stof(val);
  if (!(val = findValue(json, "jitterScale")).empty())
    jitterScale = std::stof(val);
  if (!(val = findValue(json, "friction")).empty())
    damping = 1.0f - std::stof(val);
  if (!(val = findValue(json, "speedCap")).empty())
    speedCap = std::stof(val);

  return true;
}

bool Preset::save(const std::string &path) const {
  std::ofstream f(path);
  if (!f.is_open())
    return false;

  f << "{\n";
  f << "  \"name\": \"" << name << "\",\n";
  f << "  \"particles\": {\n";
  f << "    \"size\": " << particleSize << ",\n";
  f << "    \"jitterScale\": " << jitterScale << ",\n";
  f << "    \"friction\": " << (1.0f - damping) << ",\n";
  f << "    \"speedCap\": " << speedCap << "\n";
  f << "  },\n";
  f << "  \"render\": {\n";
  f << "    \"bloomIntensity\": " << bloomIntensity << ",\n";
  f << "    \"trailDecay\": " << trailDecay << ",\n";
  f << "    \"chromaticAberration\": " << chromaticAberration << "\n";
  f << "  }\n";
  f << "}\n";

  return true;
}

std::vector<std::string>
PresetManager::scanPresets(const std::string &directory) {
  std::vector<std::string> presets;
  DIR *dir = opendir(directory.c_str());
  if (!dir)
    return presets;

  struct dirent *ent;
  while ((ent = readdir(dir)) != nullptr) {
    std::string name = ent->d_name;
    if (name.length() > 5 && name.substr(name.length() - 5) == ".json") {
      presets.push_back(name);
    }
  }
  closedir(dir);
  return presets;
}

bool PresetManager::loadPreset(const std::string &path, Preset &outPreset) {
  return outPreset.load(path);
}

bool PresetManager::savePreset(const std::string &path, const Preset &preset) {
  return preset.save(path);
}

} // namespace space
