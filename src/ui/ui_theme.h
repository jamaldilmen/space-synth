#pragma once
#include "imgui.h"

namespace space {
namespace UITheme {

inline void ApplyPremiumTheme() {
  auto &style = ImGui::GetStyle();
  auto &colors = style.Colors;

  // ── Spacing & Rounding ──────────────────────────────────────────
  style.WindowPadding = ImVec2(16, 16);
  style.FramePadding = ImVec2(10, 8);
  style.ItemSpacing = ImVec2(12, 10);
  style.ItemInnerSpacing = ImVec2(8, 6);
  style.WindowRounding = 14.0f;
  style.FrameRounding = 5.0f;
  style.PopupRounding = 5.0f;
  style.ScrollbarRounding = 12.0f;
  style.GrabRounding = 5.0f;
  style.TabRounding = 5.0f;
  style.WindowTitleAlign = ImVec2(0.0f, 0.5f); // Left align title
  style.WindowBorderSize = 1.0f;
  style.FrameBorderSize = 0.0f;

  // ── Ultra-Premium Design Colors ───────────────────────────────
  // Darker, more sophisticated translucent backgrounds
  colors[ImGuiCol_WindowBg] =
      ImVec4(0.03f, 0.03f, 0.05f, 0.65f); // Deep frosted glass
  colors[ImGuiCol_ChildBg] = ImVec4(0.00f, 0.00f, 0.00f, 0.00f);
  colors[ImGuiCol_PopupBg] = ImVec4(0.05f, 0.05f, 0.07f, 0.95f);

  // Borders & Separators
  colors[ImGuiCol_Border] = ImVec4(1.00f, 1.00f, 1.00f, 0.12f);
  colors[ImGuiCol_Separator] = ImVec4(1.00f, 1.00f, 1.00f, 0.10f);

  // Interaction (Sliders, Buttons)
  colors[ImGuiCol_FrameBg] = ImVec4(1.00f, 1.00f, 1.00f, 0.04f);
  colors[ImGuiCol_FrameBgHovered] = ImVec4(1.00f, 1.00f, 1.00f, 0.08f);
  colors[ImGuiCol_FrameBgActive] = ImVec4(1.00f, 1.00f, 1.00f, 0.12f);

  // Headers (Collapsing Header style)
  colors[ImGuiCol_Header] = ImVec4(1.00f, 1.00f, 1.00f, 0.03f);
  colors[ImGuiCol_HeaderHovered] = ImVec4(1.00f, 1.00f, 1.00f, 0.10f);
  colors[ImGuiCol_HeaderActive] = ImVec4(1.00f, 1.00f, 1.00f, 0.15f);

  // Accents (Electric Indigo)
  ImVec4 accentColor = ImVec4(0.40f, 0.50f, 1.00f, 1.00f);
  colors[ImGuiCol_SliderGrab] = ImVec4(0.40f, 0.50f, 1.00f, 0.85f);
  colors[ImGuiCol_SliderGrabActive] = ImVec4(0.50f, 0.60f, 1.00f, 1.00f);
  colors[ImGuiCol_Button] = ImVec4(1.00f, 1.00f, 1.00f, 0.06f);
  colors[ImGuiCol_ButtonHovered] = ImVec4(1.00f, 1.00f, 1.00f, 0.15f);
  colors[ImGuiCol_ButtonActive] = accentColor;

  // Title & Text
  colors[ImGuiCol_TitleBg] =
      ImVec4(0.00f, 0.00f, 0.00f, 0.00f); // Hidden title bg
  colors[ImGuiCol_TitleBgActive] = ImVec4(0.00f, 0.00f, 0.00f, 0.00f);
  colors[ImGuiCol_Text] = ImVec4(1.00f, 1.00f, 1.00f, 0.95f);
  colors[ImGuiCol_TextDisabled] = ImVec4(1.00f, 1.00f, 1.00f, 0.35f);
}

} // namespace UITheme
} // namespace space
