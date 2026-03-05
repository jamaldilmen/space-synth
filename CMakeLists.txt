cmake_minimum_required(VERSION 3.24)
project(SpaceSynth LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)

# macOS deployment target
set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS version")

# ── Sources ──────────────────────────────────────────────────────────────────

set(SOURCES
    src/main.cpp
    src/core/bessel.cpp
    src/core/lut.cpp
    src/core/modes.cpp
    src/core/midi_input.mm
    src/core/particles.cpp
    src/core/envelope.cpp
    src/core/preset_manager.cpp
    src/audio/audio_engine.mm
    src/audio/fft.cpp
    src/audio/synth.cpp
    src/audio/chorus.cpp
    src/render/renderer.mm
    src/ui/mod_menu.cpp
    src/ui/window.mm
)

set(HEADERS
    src/core/bessel.h
    src/core/lut.h
    src/core/modes.h
    src/core/particles.h
    src/core/envelope.h
    src/core/preset_manager.h
    src/audio/audio_engine.h
    src/audio/fft.h
    src/audio/synth.h
    src/audio/chorus.h
    src/render/renderer.h
    src/ui/mod_menu.h
    src/ui/window.h
)

# ── Metal Shaders ────────────────────────────────────────────────────────────

set(METAL_SOURCES
    src/render/particles.metal
    src/render/render.metal
    src/render/blackhole.metal
    src/render/postfx.metal
    src/render/spatial_hash.metal
)

# Compile .metal → .air → .metallib
set(METAL_AIR_FILES)
foreach(METAL_SRC ${METAL_SOURCES})
    get_filename_component(METAL_NAME ${METAL_SRC} NAME_WE)
    set(AIR_FILE ${CMAKE_BINARY_DIR}/${METAL_NAME}.air)
    add_custom_command(
        OUTPUT ${AIR_FILE}
        COMMAND xcrun -sdk macosx metal
            -c ${CMAKE_SOURCE_DIR}/${METAL_SRC}
            -o ${AIR_FILE}
            -std=metal3.0
        DEPENDS ${CMAKE_SOURCE_DIR}/${METAL_SRC}
        COMMENT "Compiling ${METAL_SRC} → ${METAL_NAME}.air"
    )
    list(APPEND METAL_AIR_FILES ${AIR_FILE})
endforeach()

set(METALLIB_FILE ${CMAKE_BINARY_DIR}/default.metallib)
add_custom_command(
    OUTPUT ${METALLIB_FILE}
    COMMAND xcrun -sdk macosx metallib ${METAL_AIR_FILES} -o ${METALLIB_FILE}
    DEPENDS ${METAL_AIR_FILES}
    COMMENT "Linking Metal shaders → default.metallib"
)
add_custom_target(MetalShaders DEPENDS ${METALLIB_FILE})

# ── ImGui ────────────────────────────────────────────────────────────────────

set(IMGUI_DIR ${CMAKE_SOURCE_DIR}/third_party/imgui)
set(IMGUI_SOURCES
    ${IMGUI_DIR}/imgui.cpp
    ${IMGUI_DIR}/imgui_demo.cpp
    ${IMGUI_DIR}/imgui_draw.cpp
    ${IMGUI_DIR}/imgui_tables.cpp
    ${IMGUI_DIR}/imgui_widgets.cpp
    ${IMGUI_DIR}/backends/imgui_impl_metal.mm
    ${IMGUI_DIR}/backends/imgui_impl_osx.mm
)

# ── Executable ───────────────────────────────────────────────────────────────

add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS} ${IMGUI_SOURCES})
add_dependencies(${PROJECT_NAME} MetalShaders)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${IMGUI_DIR}
    ${IMGUI_DIR}/backends
)

# ── Frameworks ───────────────────────────────────────────────────────────────

find_library(METAL_FRAMEWORK Metal REQUIRED)
find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
find_library(COCOA_FRAMEWORK Cocoa REQUIRED)
find_library(QUARTZCORE_FRAMEWORK QuartzCore REQUIRED)
find_library(COREAUDIO_FRAMEWORK CoreAudio REQUIRED)
find_library(AUDIOTOOLBOX_FRAMEWORK AudioToolbox REQUIRED)
find_library(AUDIOUNIT_FRAMEWORK AudioUnit REQUIRED)
find_library(ACCELERATE_FRAMEWORK Accelerate REQUIRED)
find_library(COREMIDI_FRAMEWORK CoreMIDI REQUIRED)
find_library(AVFOUNDATION_FRAMEWORK AVFoundation REQUIRED)
find_library(VIDEOTOOLBOX_FRAMEWORK VideoToolbox REQUIRED)
find_library(GAMECONTROLLER_FRAMEWORK GameController REQUIRED)
find_library(COREVIDEO_FRAMEWORK CoreVideo REQUIRED)

target_link_libraries(${PROJECT_NAME} PRIVATE
    ${METAL_FRAMEWORK}
    ${METALKIT_FRAMEWORK}
    ${COCOA_FRAMEWORK}
    ${QUARTZCORE_FRAMEWORK}
    ${COREAUDIO_FRAMEWORK}
    ${AUDIOTOOLBOX_FRAMEWORK}
    ${AUDIOUNIT_FRAMEWORK}
    ${ACCELERATE_FRAMEWORK}
    ${COREMIDI_FRAMEWORK}
    ${AVFOUNDATION_FRAMEWORK}
    ${VIDEOTOOLBOX_FRAMEWORK}
    ${GAMECONTROLLER_FRAMEWORK}
    ${COREVIDEO_FRAMEWORK}
)

# ── Syphon (optional, enable when framework is available) ────────────────────

if(EXISTS "${CMAKE_SOURCE_DIR}/third_party/syphon/Syphon.framework")
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "${CMAKE_SOURCE_DIR}/third_party/syphon/Syphon.framework"
    )
    target_compile_definitions(${PROJECT_NAME} PRIVATE HAS_SYPHON=1)
endif()

# ── Copy metallib to build dir ──────────────────────────────────────────────

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${METALLIB_FILE}
        $<TARGET_FILE_DIR:${PROJECT_NAME}>/default.metallib
    COMMENT "Copying default.metallib to output directory"
)

# ── Compile options ─────────────────────────────────────────────────────────

target_compile_options(${PROJECT_NAME} PRIVATE
    -Wall -Wextra -Wno-unused-parameter
    -ffast-math
)
