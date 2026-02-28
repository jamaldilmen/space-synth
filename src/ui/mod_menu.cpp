#include "ui/mod_menu.h"

// ImGui includes — will be available once submodule is added
// #include "imgui.h"
// #include "imgui_impl_metal.h"
// #include "imgui_impl_osx.h"

namespace space {

struct ModMenu::Impl {
    bool initialized = false;
};

ModMenu::ModMenu() : impl_(new Impl()) {}
ModMenu::~ModMenu() { shutdown(); delete impl_; }

bool ModMenu::init(void* device, void* view) {
    // TODO: Initialize ImGui context and Metal backend
    // ImGui::CreateContext();
    // ImGui_ImplMetal_Init(device);
    // ImGui_ImplOSX_Init(view);
    impl_->initialized = true;
    return true;
}

void ModMenu::beginFrame() {
    if (!impl_->initialized) return;
    // ImGui_ImplMetal_NewFrame();
    // ImGui_ImplOSX_NewFrame(view);
    // ImGui::NewFrame();
}

bool ModMenu::draw(Params& params) {
    if (!impl_->initialized || !visible_) return false;
    bool changed = false;

    // TODO: ImGui panels
    // ImGui::Begin("SPACE Synth");
    //
    // if (ImGui::CollapsingHeader("Particles")) {
    //     changed |= ImGui::SliderInt("Count", &params.particleCount, 1000, 2000000);
    //     changed |= ImGui::SliderFloat("Size", &params.particleSize, 0.1f, 5.0f);
    //     changed |= ImGui::SliderFloat("Friction", &params.friction, 0.01f, 0.5f);
    //     changed |= ImGui::SliderFloat("Speed Cap", &params.speedCap, 0.1f, 5.0f);
    // }
    //
    // if (ImGui::CollapsingHeader("Envelope")) {
    //     changed |= ImGui::SliderFloat("Attack", &params.envelope.attack, 0.001f, 0.5f);
    //     changed |= ImGui::SliderFloat("Decay", &params.envelope.decay, 0.001f, 1.0f);
    //     changed |= ImGui::SliderFloat("Sustain", &params.envelope.sustain, 0.0f, 1.0f);
    //     changed |= ImGui::SliderFloat("Release", &params.envelope.release, 0.01f, 2.0f);
    // }
    //
    // if (ImGui::CollapsingHeader("Post-FX")) {
    //     changed |= ImGui::SliderFloat("Bloom", &params.render.bloomIntensity, 0.0f, 1.0f);
    //     changed |= ImGui::SliderFloat("Trails", &params.render.trailDecay, 0.0f, 0.95f);
    //     changed |= ImGui::SliderFloat("Chromatic", &params.render.chromaticAberration, 0.0f, 0.02f);
    // }
    //
    // ImGui::End();

    return changed;
}

void ModMenu::render(void* encoder) {
    if (!impl_->initialized) return;
    // ImGui::Render();
    // ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, encoder);
}

void ModMenu::processKeyEvent(int keyCode, bool isDown) {
    // Tab key (keyCode 48) toggles visibility
    if (keyCode == 48 && isDown) {
        visible_ = !visible_;
    }
}

void ModMenu::shutdown() {
    if (!impl_->initialized) return;
    // ImGui_ImplMetal_Shutdown();
    // ImGui_ImplOSX_Shutdown();
    // ImGui::DestroyContext();
    impl_->initialized = false;
}

} // namespace space
