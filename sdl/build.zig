const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_dep = b.dependency("sdl3", .{});
    const sdl_path = sdl_dep.path("");
    const sdl_include_path = sdl_path.path(b, "include");

    const is_shared_library = target.result.abi.isAndroid(); // NOTE(jae): 2024-09-22: Android uses shared library as SDL2 loads it as part of SDLActivity.java
    const lib = if (!is_shared_library) b.addStaticLibrary(.{
        .name = "SDL3",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }) else b.addSharedLibrary(.{
        .name = "SDL3",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    lib.addCSourceFiles(.{
        .root = sdl_path,
        .files = &generic_src_files,
        .flags = &.{"-DSDL_VIDEO_DRIVER_VULKAN=1, -fvisibility=default"},
    });
    // lib.linkLibC();
    lib.root_module.addCMacro("DSDL_VIDEO_DRIVER_VULKAN", "1");
    lib.root_module.addCMacro("SDL_USE_BUILTIN_OPENGL_DEFINITIONS", "1");
    // lib.root_module.addCMacro(name: []const u8, value: []const u8)

    lib.root_module.addCSourceFiles(.{
        .root = sdl_path,
        .files = &android_src_files,
    });
    // NOTE(jae): 2024-09-22
    // Build settings taken from: SDL2-2.32.2/src/hidapi/android/jni/Android.mk
    // SDLActivity.java by default expects to be able to load this library
    lib.root_module.addCSourceFiles(.{
        .root = sdl_path,
        .files = &[_][]const u8{
            "src/hidapi/android/hid.cpp",
        },
        .flags = &.{"-std=c++11"},
    });
    lib.linkLibCpp();

    // This is needed for "src/render/opengles/SDL_render_gles.c" to compile
    lib.root_module.addCMacro("GL_GLEXT_PROTOTYPES", "1");

    // Add Java files to dependency
    const java_dir = sdl_dep.path("android-project/app/src/main/java/org/libsdl/app");
    const java_files: []const []const u8 = &.{
        "HIDDevice.java",
        "HIDDeviceBLESteamController.java",
        "HIDDeviceManager.java",
        "HIDDeviceUSB.java",
        "SDL.java",
        "SDLActivity.java",
        "SDLAudioManager.java",
        "SDLControllerManager.java",
        "SDLDummyEdit.java",
        "SDLInputConnection.java",
        "SDLSurface.java",
    };
    const java_write_files = b.addNamedWriteFiles("sdljava");
    for (java_files) |java_file_basename| {
        _ = java_write_files.addCopyFile(java_dir.path(b, java_file_basename), java_file_basename);
    }

    // https://github.com/libsdl-org/SDL/blob/release-2.30.6/Android.mk#L82C62-L82C69
    lib.linkSystemLibrary("dl");
    lib.linkSystemLibrary("GLESv1_CM");
    lib.linkSystemLibrary("GLESv2");
    lib.linkSystemLibrary("OpenSLES");
    lib.linkSystemLibrary("log");
    lib.linkSystemLibrary("android");

    // SDLActivity.java's getMainFunction defines the entrypoint as "SDL_main"
    // So your main / root file will need something like this for Android
    //
    // fn android_sdl_main() callconv(.C) void {
    //    _ = std.start.callMain();
    // }
    // comptime {
    //    if (builtin.abi.isAndroid()) @export(&android_sdl_main, .{ .name = "SDL_main", .linkage = .strong });
    // }

    // NOTE(jae): 2024-07-07
    // This must come *after* addConfigHeader logic above for per-OS so that the include for SDL_config.h takes precedence
    lib.addIncludePath(sdl_include_path);
    lib.addIncludePath(sdl_dep.path("src"));
    lib.addIncludePath(sdl_dep.path("include/build_config"));
    // NOTE(jae): 2024-04-07
    // Not installing header as we include/export it from the module
    // lib.installHeadersDirectory("include", "SDL");
    b.installArtifact(lib);

    var sdl_c_module = b.addTranslateC(.{
        .target = target,
        .optimize = .ReleaseFast,
        .root_source_file = b.path("src/sdl.h"),
    });
    // if (sdl_config_header) |config_header| {
    //     sdl_c_module.addConfigHeader(config_header);
    // }
    sdl_c_module.addIncludePath(sdl_include_path);

    _ = b.addModule("sdl", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = sdl_c_module.getOutput(),
    });
}

const generic_src_files = [_][]const u8{
    "src/SDL.c",
    "src/SDL_assert.c",
    "src/SDL_error.c",
    "src/SDL_guid.c",
    "src/SDL_hashtable.c",
    "src/SDL_hints.c",
    "src/SDL_list.c",
    "src/SDL_log.c",
    "src/SDL_properties.c",
    "src/SDL_utils.c",
    // "src/SDL_internal.c",
    "src/atomic/SDL_atomic.c",
    "src/atomic/SDL_spinlock.c",
    "src/audio/SDL_audio.c",
    "src/audio/SDL_audiocvt.c",
    "src/audio/SDL_audiodev.c",
    "src/audio/SDL_audioqueue.c",
    "src/audio/SDL_audioresample.c",
    "src/audio/SDL_audiotypecvt.c",
    "src/audio/SDL_mixer.c",
    "src/audio/SDL_wave.c",
    "src/camera/SDL_camera.c",
    "src/core/SDL_core_unsupported.c",
    "src/cpuinfo/SDL_cpuinfo.c",
    "src/dynapi/SDL_dynapi.c",
    "src/events/SDL_categories.c",
    "src/events/SDL_clipboardevents.c",
    "src/events/SDL_displayevents.c",
    "src/events/SDL_dropevents.c",
    "src/events/SDL_events.c",
    "src/events/SDL_eventwatch.c",
    "src/events/SDL_keyboard.c",
    "src/events/SDL_keymap.c",
    "src/events/SDL_keysym_to_keycode.c",
    "src/events/SDL_keysym_to_scancode.c",
    "src/events/SDL_mouse.c",
    "src/events/SDL_pen.c",
    "src/events/SDL_quit.c",
    "src/events/SDL_scancode_tables.c",
    "src/events/SDL_touch.c",
    "src/events/SDL_windowevents.c",
    "src/events/imKStoUCS.c",
    "src/filesystem/SDL_filesystem.c",
    "src/gpu/SDL_gpu.c",
    "src/haptic/SDL_haptic.c",
    "src/hidapi/SDL_hidapi.c",
    "src/io/SDL_asyncio.c",
    "src/io/SDL_iostream.c",
    "src/io/generic/SDL_asyncio_generic.c",

    "src/joystick/SDL_gamepad.c",
    "src/joystick/SDL_joystick.c",
    "src/joystick/SDL_steam_virtual_gamepad.c",
    "src/joystick/controller_type.c",
    "src/joystick/hidapi/SDL_hidapijoystick.c",
    "src/joystick/hidapi/SDL_hidapi_combined.c",
    "src/joystick/hidapi/SDL_hidapi_gamecube.c",
    "src/joystick/hidapi/SDL_hidapi_luna.c",
    "src/joystick/hidapi/SDL_hidapi_ps3.c",
    "src/joystick/hidapi/SDL_hidapi_ps4.c",
    "src/joystick/hidapi/SDL_hidapi_ps5.c",
    "src/joystick/hidapi/SDL_hidapi_rumble.c",
    "src/joystick/hidapi/SDL_hidapi_shield.c",
    "src/joystick/hidapi/SDL_hidapi_stadia.c",
    "src/joystick/hidapi/SDL_hidapi_steam.c",
    "src/joystick/hidapi/SDL_hidapi_steam_hori.c",
    "src/joystick/hidapi/SDL_hidapi_steamdeck.c",
    "src/joystick/hidapi/SDL_hidapi_switch.c",
    "src/joystick/hidapi/SDL_hidapi_wii.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360.c",
    "src/joystick/hidapi/SDL_hidapi_xbox360w.c",
    "src/joystick/hidapi/SDL_hidapi_xboxone.c",

    "src/locale/SDL_locale.c",
    "src/main/SDL_main_callbacks.c",
    "src/main/SDL_runapp.c",
    "src/misc/SDL_url.c",
    "src/power/SDL_power.c",
    "src/render/SDL_d3dmath.c",
    "src/render/SDL_render.c",
    "src/render/SDL_render_unsupported.c",
    "src/render/SDL_yuv_sw.c",
    "src/render/gpu/SDL_pipeline_gpu.c",
    "src/render/gpu/SDL_render_gpu.c",
    "src/render/gpu/SDL_shaders_gpu.c",
    "src/render/opengl/SDL_render_gl.c",
    "src/render/opengl/SDL_shaders_gl.c",
    "src/render/software/SDL_blendfillrect.c",
    "src/render/software/SDL_blendline.c",
    "src/render/software/SDL_blendpoint.c",
    "src/render/software/SDL_drawline.c",
    "src/render/software/SDL_drawpoint.c",
    "src/render/software/SDL_render_sw.c",
    "src/render/software/SDL_rotate.c",
    "src/render/software/SDL_triangle.c",
    "src/render/vitagxm/SDL_render_vita_gxm.c",
    "src/render/vitagxm/SDL_render_vita_gxm_memory.c",
    "src/render/vitagxm/SDL_render_vita_gxm_tools.c",
    "src/sensor/SDL_sensor.c",
    "src/stdlib/SDL_crc16.c",
    "src/stdlib/SDL_crc32.c",
    "src/stdlib/SDL_getenv.c",
    "src/stdlib/SDL_iconv.c",
    "src/stdlib/SDL_malloc.c",
    "src/stdlib/SDL_memcpy.c",
    "src/stdlib/SDL_memmove.c",
    "src/stdlib/SDL_memset.c",
    "src/stdlib/SDL_mslibc.c",
    "src/stdlib/SDL_murmur3.c",
    "src/stdlib/SDL_qsort.c",
    "src/stdlib/SDL_random.c",
    "src/stdlib/SDL_stdlib.c",
    "src/stdlib/SDL_string.c",
    "src/stdlib/SDL_strtokr.c",
    "src/storage/SDL_storage.c",
    "src/thread/SDL_thread.c",
    // "src/thread/generic/SDL_sysrwlock.c",

    "src/time/SDL_time.c",
    "src/timer/SDL_timer.c",
    "src/video/SDL_RLEaccel.c",
    "src/video/SDL_blit.c",
    "src/video/SDL_blit_0.c",
    "src/video/SDL_blit_1.c",
    "src/video/SDL_blit_A.c",
    "src/video/SDL_blit_N.c",
    "src/video/SDL_blit_auto.c",
    "src/video/SDL_blit_copy.c",
    "src/video/SDL_blit_slow.c",
    "src/video/SDL_bmp.c",
    "src/video/SDL_clipboard.c",
    "src/video/SDL_egl.c",
    "src/video/SDL_fillrect.c",
    "src/video/SDL_pixels.c",
    "src/video/SDL_rect.c",
    "src/video/SDL_stb.c",
    "src/video/SDL_stretch.c",
    "src/video/SDL_surface.c",
    "src/video/SDL_video.c",
    "src/video/SDL_video_unsupported.c",
    "src/video/SDL_vulkan_utils.c",
    "src/video/SDL_yuv.c",
    "src/video/yuv2rgb/yuv_rgb_lsx.c",
    "src/video/yuv2rgb/yuv_rgb_sse.c",
    "src/video/yuv2rgb/yuv_rgb_std.c",
    "src/dialog/SDL_dialog.c",
    "src/dialog/SDL_dialog_utils.c",
    "src/process/SDL_process.c",
    "src/tray/SDL_tray_utils.c",
};

// https://github.com/libsdl-org/SDL/blob/release-2.30.6/Android.mk#L17
const android_src_files = [_][]const u8{
    "src/core/android/SDL_android.c",

    "src/audio/openslES/SDL_openslES.c",
    "src/audio/aaudio/SDL_aaudio.c",

    "src/gpu/vulkan/SDL_gpu_vulkan.c",

    "src/render/opengles2/SDL_render_gles2.c",
    "src/render/opengles2/SDL_shaders_gles2.c",
    "src/render/vulkan/SDL_render_vulkan.c",
    "src/render/vulkan/SDL_shaders_vulkan.c",

    "src/haptic/android/SDL_syshaptic.c",
    "src/joystick/android/SDL_sysjoystick.c",
    "src/joystick/virtual/SDL_virtualjoystick.c",

    "src/storage/generic/SDL_genericstorage.c",

    "src/locale/android/SDL_syslocale.c",
    "src/misc/android/SDL_sysurl.c",
    "src/power/android/SDL_syspower.c",
    "src/filesystem/android/SDL_sysfilesystem.c",
    "src/filesystem/posix/SDL_sysfsops.c",
    "src/camera/android/SDL_camera_android.c",
    "src/sensor/android/SDL_androidsensor.c",

    "src/process/posix/SDL_posixprocess.c",
    "src/process/dummy/SDL_dummyprocess.c",

    "src/dialog/android/SDL_androiddialog.c",
    // "src/dialog/unix/SDL_sysdialog.c",

    "src/time/unix/SDL_systime.c",

    "src/timer/unix/SDL_systimer.c",
    "src/loadso/dlopen/SDL_sysloadso.c",

    "src/thread/pthread/SDL_syscond.c",
    "src/thread/pthread/SDL_sysmutex.c",
    "src/thread/pthread/SDL_syssem.c",
    "src/thread/pthread/SDL_systhread.c",
    "src/thread/pthread/SDL_systls.c",
    "src/thread/pthread/SDL_sysrwlock.c",

    "src/tray/unix/SDL_tray.c",

    "src/video/android/SDL_androidclipboard.c",
    "src/video/android/SDL_androidevents.c",
    "src/video/android/SDL_androidgl.c",
    "src/video/android/SDL_androidkeyboard.c",
    "src/video/android/SDL_androidmessagebox.c",
    "src/video/android/SDL_androidmouse.c",
    "src/video/android/SDL_androidtouch.c",
    "src/video/android/SDL_androidvideo.c",
    "src/video/android/SDL_androidpen.c",
    "src/video/android/SDL_androidvulkan.c",
    "src/video/android/SDL_androidwindow.c",
};

// const windows_src_files = [_][]const u8{
//     "src/core/windows/SDL_hid.c",
//     "src/core/windows/SDL_immdevice.c",
//     "src/core/windows/SDL_windows.c",
//     "src/core/windows/SDL_xinput.c",
//     "src/filesystem/windows/SDL_sysfilesystem.c",
//     "src/haptic/windows/SDL_dinputhaptic.c",
//     "src/haptic/windows/SDL_windowshaptic.c",
//     "src/haptic/windows/SDL_xinputhaptic.c",
//     "src/hidapi/windows/hid.c",
//     "src/joystick/windows/SDL_dinputjoystick.c",
//     "src/joystick/windows/SDL_rawinputjoystick.c",
//     // This can be enabled when Zig updates to the next mingw-w64 release,
//     // which will make the headers gain `windows.gaming.input.h`.
//     // Also revert the patch 2c79fd8fd04f1e5045cbe5978943b0aea7593110.
//     "src/joystick/windows/SDL_windows_gaming_input.c", // note: previously didnt work
//     "src/joystick/windows/SDL_windowsjoystick.c",
//     "src/joystick/windows/SDL_xinputjoystick.c",
//
//     "src/loadso/windows/SDL_sysloadso.c",
//     "src/locale/windows/SDL_syslocale.c",
//     "src/main/windows/SDL_windows_main.c",
//     "src/misc/windows/SDL_sysurl.c",
//     "src/power/windows/SDL_syspower.c",
//     "src/sensor/windows/SDL_windowssensor.c",
//     "src/timer/windows/SDL_systimer.c",
//     "src/video/windows/SDL_windowsclipboard.c",
//     "src/video/windows/SDL_windowsevents.c",
//     "src/video/windows/SDL_windowsframebuffer.c",
//     "src/video/windows/SDL_windowskeyboard.c",
//     "src/video/windows/SDL_windowsmessagebox.c",
//     "src/video/windows/SDL_windowsmodes.c",
//     "src/video/windows/SDL_windowsmouse.c",
//     "src/video/windows/SDL_windowsopengl.c",
//     "src/video/windows/SDL_windowsopengles.c",
//     "src/video/windows/SDL_windowsshape.c",
//     "src/video/windows/SDL_windowsvideo.c",
//     "src/video/windows/SDL_windowsvulkan.c",
//     "src/video/windows/SDL_windowswindow.c",
//
//     "src/thread/windows/SDL_syscond_cv.c",
//     "src/thread/windows/SDL_sysmutex.c",
//     "src/thread/windows/SDL_syssem.c",
//     "src/thread/windows/SDL_systhread.c",
//     "src/thread/windows/SDL_systls.c",
//     "src/thread/generic/SDL_syscond.c",
//
//     "src/render/direct3d/SDL_render_d3d.c",
//     "src/render/direct3d/SDL_shaders_d3d.c",
//     "src/render/direct3d11/SDL_render_d3d11.c",
//     "src/render/direct3d11/SDL_shaders_d3d11.c",
//     "src/render/direct3d12/SDL_render_d3d12.c",
//     "src/render/direct3d12/SDL_shaders_d3d12.c",
//
//     "src/audio/directsound/SDL_directsound.c",
//     "src/audio/wasapi/SDL_wasapi.c",
//     "src/audio/wasapi/SDL_wasapi_win32.c",
//     "src/audio/winmm/SDL_winmm.c",
//     "src/audio/disk/SDL_diskaudio.c",
//
//     "src/render/opengl/SDL_render_gl.c",
//     "src/render/opengl/SDL_shaders_gl.c",
//     "src/render/opengles/SDL_render_gles.c",
//     "src/render/opengles2/SDL_render_gles2.c",
//     "src/render/opengles2/SDL_shaders_gles2.c",
// };

// const linux_src_files = [_][]const u8{
//     "src/core/linux/SDL_dbus.c",
//     "src/core/linux/SDL_evdev.c",
//     "src/core/linux/SDL_evdev_capabilities.c",
//     "src/core/linux/SDL_evdev_kbd.c",
//     "src/core/linux/SDL_fcitx.c",
//     "src/core/linux/SDL_ibus.c",
//     "src/core/linux/SDL_ime.c",
//     "src/core/linux/SDL_sandbox.c",
//     "src/core/linux/SDL_threadprio.c",
//     "src/core/linux/SDL_udev.c",
//
//     // "src/haptic/linux/SDL_syshaptic.c",
//     "src/haptic/dummy/SDL_syshaptic.c",
//
//     "src/hidapi/linux/hid.c",
//
//     "src/locale/unix/SDL_syslocale.c",
//
//     // "src/filesystem/unix/SDL_sysfilesystem.c",
//     "src/filesystem/dummy/SDL_sysfilesystem.c",
//
//     "src/misc/dummy/SDL_sysurl.c",
//
//     "src/joystick/linux/SDL_sysjoystick.c",
//     "src/joystick/dummy/SDL_sysjoystick.c", // required with default SDL_config.h
//
//     "src/power/linux/SDL_syspower.c",
//
//     "src/timer/unix/SDL_systimer.c",
//     "src/core/unix/SDL_poll.c",
//
//     "src/sensor/dummy/SDL_dummysensor.c",
//
//     "src/loadso/dlopen/SDL_sysloadso.c",
//
//     "src/thread/pthread/SDL_syscond.c",
//     "src/thread/pthread/SDL_sysmutex.c",
//     "src/thread/pthread/SDL_syssem.c",
//     "src/thread/pthread/SDL_systhread.c",
//     "src/thread/pthread/SDL_systls.c",
//
//     "src/video/wayland/SDL_waylandclipboard.c",
//     "src/video/wayland/SDL_waylanddatamanager.c",
//     "src/video/wayland/SDL_waylanddyn.c",
//     "src/video/wayland/SDL_waylandevents.c",
//     "src/video/wayland/SDL_waylandkeyboard.c",
//     "src/video/wayland/SDL_waylandmessagebox.c",
//     "src/video/wayland/SDL_waylandmouse.c",
//     "src/video/wayland/SDL_waylandopengles.c",
//     "src/video/wayland/SDL_waylandtouch.c",
//     "src/video/wayland/SDL_waylandvideo.c",
//     "src/video/wayland/SDL_waylandvulkan.c",
//     "src/video/wayland/SDL_waylandwindow.c",
//
//     "src/video/x11/SDL_x11clipboard.c",
//     "src/video/x11/SDL_x11dyn.c",
//     "src/video/x11/SDL_x11events.c",
//     "src/video/x11/SDL_x11framebuffer.c",
//     "src/video/x11/SDL_x11keyboard.c",
//     "src/video/x11/SDL_x11messagebox.c",
//     "src/video/x11/SDL_x11modes.c",
//     "src/video/x11/SDL_x11mouse.c",
//     "src/video/x11/SDL_x11opengl.c",
//     "src/video/x11/SDL_x11opengles.c",
//     "src/video/x11/SDL_x11shape.c",
//     "src/video/x11/SDL_x11touch.c",
//     "src/video/x11/SDL_x11video.c",
//     "src/video/x11/SDL_x11vulkan.c",
//     "src/video/x11/SDL_x11window.c",
//     "src/video/x11/SDL_x11xfixes.c",
//     "src/video/x11/SDL_x11xinput2.c",
//     "src/video/x11/edid-parse.c",
//
//     "src/audio/alsa/SDL_alsa_audio.c",
//     "src/audio/jack/SDL_jackaudio.c",
//     "src/audio/pulseaudio/SDL_pulseaudio.c",
// };

// const darwin_src_files = [_][]const u8{
//     "src/haptic/darwin/SDL_syshaptic.c",
//     "src/joystick/darwin/SDL_iokitjoystick.c",
//     "src/power/macosx/SDL_syspower.c",
//     "src/timer/unix/SDL_systimer.c",
//     "src/loadso/dlopen/SDL_sysloadso.c",
//     "src/audio/disk/SDL_diskaudio.c",
//     "src/render/opengl/SDL_render_gl.c",
//     "src/render/opengl/SDL_shaders_gl.c",
//     "src/render/opengles/SDL_render_gles.c",
//     "src/render/opengles2/SDL_render_gles2.c",
//     "src/render/opengles2/SDL_shaders_gles2.c",
//     "src/sensor/dummy/SDL_dummysensor.c",
//
//     "src/thread/pthread/SDL_syscond.c",
//     "src/thread/pthread/SDL_sysmutex.c",
//     "src/thread/pthread/SDL_syssem.c",
//     "src/thread/pthread/SDL_systhread.c",
//     "src/thread/pthread/SDL_systls.c",
// };

// const objective_c_src_files = [_][]const u8{
//     "src/audio/coreaudio/SDL_coreaudio.m",
//     "src/file/cocoa/SDL_rwopsbundlesupport.m",
//     "src/filesystem/cocoa/SDL_sysfilesystem.m",
//     "src/joystick/iphoneos/SDL_mfijoystick.m",
//     //"src/hidapi/testgui/mac_support_cocoa.m",
//     // This appears to be for SDL3 only.
//     //"src/joystick/apple/SDL_mfijoystick.m",
//     "src/locale/macosx/SDL_syslocale.m",
//     "src/misc/macosx/SDL_sysurl.m",
//     "src/power/uikit/SDL_syspower.m",
//     "src/render/metal/SDL_render_metal.m",
//     "src/sensor/coremotion/SDL_coremotionsensor.m",
//     "src/video/cocoa/SDL_cocoaclipboard.m",
//     "src/video/cocoa/SDL_cocoaevents.m",
//     "src/video/cocoa/SDL_cocoakeyboard.m",
//     "src/video/cocoa/SDL_cocoamessagebox.m",
//     "src/video/cocoa/SDL_cocoametalview.m",
//     "src/video/cocoa/SDL_cocoamodes.m",
//     "src/video/cocoa/SDL_cocoamouse.m",
//     "src/video/cocoa/SDL_cocoaopengl.m",
//     "src/video/cocoa/SDL_cocoaopengles.m",
//     "src/video/cocoa/SDL_cocoashape.m",
//     "src/video/cocoa/SDL_cocoavideo.m",
//     "src/video/cocoa/SDL_cocoavulkan.m",
//     "src/video/cocoa/SDL_cocoawindow.m",
//     "src/video/uikit/SDL_uikitappdelegate.m",
//     "src/video/uikit/SDL_uikitclipboard.m",
//     "src/video/uikit/SDL_uikitevents.m",
//     "src/video/uikit/SDL_uikitmessagebox.m",
//     "src/video/uikit/SDL_uikitmetalview.m",
//     "src/video/uikit/SDL_uikitmodes.m",
//     "src/video/uikit/SDL_uikitopengles.m",
//     "src/video/uikit/SDL_uikitopenglview.m",
//     "src/video/uikit/SDL_uikitvideo.m",
//     "src/video/uikit/SDL_uikitview.m",
//     "src/video/uikit/SDL_uikitviewcontroller.m",
//     "src/video/uikit/SDL_uikitvulkan.m",
//     "src/video/uikit/SDL_uikitwindow.m",
// };

// const ios_src_files = [_][]const u8{
//     "src/hidapi/ios/hid.m",
//     "src/misc/ios/SDL_sysurl.m",
//     "src/joystick/iphoneos/SDL_mfijoystick.m",
// };
//
// const emscripten_src_files = [_][]const u8{
//     "src/audio/emscripten/SDL_emscriptenaudio.c",
//     "src/filesystem/emscripten/SDL_sysfilesystem.c",
//     "src/joystick/emscripten/SDL_sysjoystick.c",
//     "src/locale/emscripten/SDL_syslocale.c",
//     "src/misc/emscripten/SDL_sysurl.c",
//     "src/power/emscripten/SDL_syspower.c",
//     "src/video/emscripten/SDL_emscriptenevents.c",
//     "src/video/emscripten/SDL_emscriptenframebuffer.c",
//     "src/video/emscripten/SDL_emscriptenmouse.c",
//     "src/video/emscripten/SDL_emscriptenopengles.c",
//     "src/video/emscripten/SDL_emscriptenvideo.c",
//
//     "src/timer/unix/SDL_systimer.c",
//     "src/loadso/dlopen/SDL_sysloadso.c",
//     "src/audio/disk/SDL_diskaudio.c",
//     "src/render/opengles2/SDL_render_gles2.c",
//     "src/render/opengles2/SDL_shaders_gles2.c",
//     "src/sensor/dummy/SDL_dummysensor.c",
//
//     "src/thread/pthread/SDL_syscond.c",
//     "src/thread/pthread/SDL_sysmutex.c",
//     "src/thread/pthread/SDL_syssem.c",
//     "src/thread/pthread/SDL_systhread.c",
//     "src/thread/pthread/SDL_systls.c",
// };

// const unknown_src_files = [_][]const u8{
//     "src/thread/generic/SDL_syscond.c",
//     "src/thread/generic/SDL_sysmutex.c",
//     "src/thread/generic/SDL_syssem.c",
//     "src/thread/generic/SDL_systhread.c",
//     "src/thread/generic/SDL_systls.c",
//
//     "src/audio/arts/SDL_artsaudio.c",
//     "src/audio/dsp/SDL_dspaudio.c",
//     // "src/audio/emscripten/SDL_emscriptenaudio.c",
//     "src/audio/esd/SDL_esdaudio.c",
//     "src/audio/fusionsound/SDL_fsaudio.c",
//     "src/audio/n3ds/SDL_n3dsaudio.c",
//     "src/audio/nacl/SDL_naclaudio.c",
//     "src/audio/nas/SDL_nasaudio.c",
//     "src/audio/netbsd/SDL_netbsdaudio.c",
//     "src/audio/openslES/SDL_openslES.c",
//     "src/audio/os2/SDL_os2audio.c",
//     "src/audio/paudio/SDL_paudio.c",
//     "src/audio/pipewire/SDL_pipewire.c",
//     "src/audio/ps2/SDL_ps2audio.c",
//     "src/audio/psp/SDL_pspaudio.c",
//     "src/audio/qsa/SDL_qsa_audio.c",
//     "src/audio/sndio/SDL_sndioaudio.c",
//     "src/audio/sun/SDL_sunaudio.c",
//     "src/audio/vita/SDL_vitaaudio.c",
//
//     "src/core/android/SDL_android.c",
//     "src/core/freebsd/SDL_evdev_kbd_freebsd.c",
//     "src/core/openbsd/SDL_wscons_kbd.c",
//     "src/core/openbsd/SDL_wscons_mouse.c",
//     "src/core/os2/SDL_os2.c",
//     "src/core/os2/geniconv/geniconv.c",
//     "src/core/os2/geniconv/os2cp.c",
//     "src/core/os2/geniconv/os2iconv.c",
//     "src/core/os2/geniconv/sys2utf8.c",
//     "src/core/os2/geniconv/test.c",
//     "src/core/unix/SDL_poll.c",
//
//     "src/file/n3ds/SDL_rwopsromfs.c",
//
//     "src/filesystem/android/SDL_sysfilesystem.c",
//     // "src/filesystem/emscripten/SDL_sysfilesystem.c",
//     "src/filesystem/n3ds/SDL_sysfilesystem.c",
//     "src/filesystem/nacl/SDL_sysfilesystem.c",
//     "src/filesystem/os2/SDL_sysfilesystem.c",
//     "src/filesystem/ps2/SDL_sysfilesystem.c",
//     "src/filesystem/psp/SDL_sysfilesystem.c",
//     "src/filesystem/riscos/SDL_sysfilesystem.c",
//     "src/filesystem/unix/SDL_sysfilesystem.c",
//     "src/filesystem/vita/SDL_sysfilesystem.c",
//
//     "src/haptic/android/SDL_syshaptic.c",
//     "src/haptic/dummy/SDL_syshaptic.c",
//
//     "src/hidapi/libusb/hid.c",
//     "src/hidapi/mac/hid.c",
//
//     "src/joystick/android/SDL_sysjoystick.c",
//     "src/joystick/bsd/SDL_bsdjoystick.c",
//     "src/joystick/dummy/SDL_sysjoystick.c",
//     // "src/joystick/emscripten/SDL_sysjoystick.c",
//     "src/joystick/n3ds/SDL_sysjoystick.c",
//     "src/joystick/os2/SDL_os2joystick.c",
//     "src/joystick/ps2/SDL_sysjoystick.c",
//     "src/joystick/psp/SDL_sysjoystick.c",
//     "src/joystick/steam/SDL_steamcontroller.c",
//     "src/joystick/vita/SDL_sysjoystick.c",
//
//     "src/loadso/dummy/SDL_sysloadso.c",
//     "src/loadso/os2/SDL_sysloadso.c",
//
//     "src/locale/android/SDL_syslocale.c",
//     "src/locale/dummy/SDL_syslocale.c",
//     // "src/locale/emscripten/SDL_syslocale.c",
//     "src/locale/n3ds/SDL_syslocale.c",
//     "src/locale/unix/SDL_syslocale.c",
//     "src/locale/vita/SDL_syslocale.c",
//     "src/locale/winrt/SDL_syslocale.c",
//
//     "src/main/android/SDL_android_main.c",
//     "src/main/dummy/SDL_dummy_main.c",
//     "src/main/gdk/SDL_gdk_main.c",
//     "src/main/n3ds/SDL_n3ds_main.c",
//     "src/main/nacl/SDL_nacl_main.c",
//     "src/main/ps2/SDL_ps2_main.c",
//     "src/main/psp/SDL_psp_main.c",
//     "src/main/uikit/SDL_uikit_main.c",
//
//     "src/misc/android/SDL_sysurl.c",
//     "src/misc/dummy/SDL_sysurl.c",
//     // "src/misc/emscripten/SDL_sysurl.c",
//     "src/misc/riscos/SDL_sysurl.c",
//     "src/misc/unix/SDL_sysurl.c",
//     "src/misc/vita/SDL_sysurl.c",
//
//     "src/power/android/SDL_syspower.c",
//     // "src/power/emscripten/SDL_syspower.c",
//     "src/power/haiku/SDL_syspower.c",
//     "src/power/n3ds/SDL_syspower.c",
//     "src/power/psp/SDL_syspower.c",
//     "src/power/vita/SDL_syspower.c",
//
//     "src/sensor/android/SDL_androidsensor.c",
//     "src/sensor/n3ds/SDL_n3dssensor.c",
//     "src/sensor/vita/SDL_vitasensor.c",
//
//     "src/test/SDL_test_assert.c",
//     "src/test/SDL_test_common.c",
//     "src/test/SDL_test_compare.c",
//     "src/test/SDL_test_crc32.c",
//     "src/test/SDL_test_font.c",
//     "src/test/SDL_test_fuzzer.c",
//     "src/test/SDL_test_harness.c",
//     "src/test/SDL_test_imageBlit.c",
//     "src/test/SDL_test_imageBlitBlend.c",
//     "src/test/SDL_test_imageFace.c",
//     "src/test/SDL_test_imagePrimitives.c",
//     "src/test/SDL_test_imagePrimitivesBlend.c",
//     "src/test/SDL_test_log.c",
//     "src/test/SDL_test_md5.c",
//     "src/test/SDL_test_memory.c",
//     "src/test/SDL_test_random.c",
//
//     "src/thread/n3ds/SDL_syscond.c",
//     "src/thread/n3ds/SDL_sysmutex.c",
//     "src/thread/n3ds/SDL_syssem.c",
//     "src/thread/n3ds/SDL_systhread.c",
//     "src/thread/os2/SDL_sysmutex.c",
//     "src/thread/os2/SDL_syssem.c",
//     "src/thread/os2/SDL_systhread.c",
//     "src/thread/os2/SDL_systls.c",
//     "src/thread/ps2/SDL_syssem.c",
//     "src/thread/ps2/SDL_systhread.c",
//     "src/thread/psp/SDL_syscond.c",
//     "src/thread/psp/SDL_sysmutex.c",
//     "src/thread/psp/SDL_syssem.c",
//     "src/thread/psp/SDL_systhread.c",
//     "src/thread/vita/SDL_syscond.c",
//     "src/thread/vita/SDL_sysmutex.c",
//     "src/thread/vita/SDL_syssem.c",
//     "src/thread/vita/SDL_systhread.c",
//
//     "src/timer/dummy/SDL_systimer.c",
//     "src/timer/haiku/SDL_systimer.c",
//     "src/timer/n3ds/SDL_systimer.c",
//     "src/timer/os2/SDL_systimer.c",
//     "src/timer/ps2/SDL_systimer.c",
//     "src/timer/psp/SDL_systimer.c",
//     "src/timer/vita/SDL_systimer.c",
//
//     "src/video/android/SDL_androidclipboard.c",
//     "src/video/android/SDL_androidevents.c",
//     "src/video/android/SDL_androidgl.c",
//     "src/video/android/SDL_androidkeyboard.c",
//     "src/video/android/SDL_androidmessagebox.c",
//     "src/video/android/SDL_androidmouse.c",
//     "src/video/android/SDL_androidtouch.c",
//     "src/video/android/SDL_androidvideo.c",
//     "src/video/android/SDL_androidvulkan.c",
//     "src/video/android/SDL_androidwindow.c",
//     "src/video/directfb/SDL_DirectFB_WM.c",
//     "src/video/directfb/SDL_DirectFB_dyn.c",
//     "src/video/directfb/SDL_DirectFB_events.c",
//     "src/video/directfb/SDL_DirectFB_modes.c",
//     "src/video/directfb/SDL_DirectFB_mouse.c",
//     "src/video/directfb/SDL_DirectFB_opengl.c",
//     "src/video/directfb/SDL_DirectFB_render.c",
//     "src/video/directfb/SDL_DirectFB_shape.c",
//     "src/video/directfb/SDL_DirectFB_video.c",
//     "src/video/directfb/SDL_DirectFB_vulkan.c",
//     "src/video/directfb/SDL_DirectFB_window.c",
//     // "src/video/emscripten/SDL_emscriptenevents.c",
//     // "src/video/emscripten/SDL_emscriptenframebuffer.c",
//     // "src/video/emscripten/SDL_emscriptenmouse.c",
//     // "src/video/emscripten/SDL_emscriptenopengles.c",
//     // "src/video/emscripten/SDL_emscriptenvideo.c",
//     "src/video/kmsdrm/SDL_kmsdrmdyn.c",
//     "src/video/kmsdrm/SDL_kmsdrmevents.c",
//     "src/video/kmsdrm/SDL_kmsdrmmouse.c",
//     "src/video/kmsdrm/SDL_kmsdrmopengles.c",
//     "src/video/kmsdrm/SDL_kmsdrmvideo.c",
//     "src/video/kmsdrm/SDL_kmsdrmvulkan.c",
//     "src/video/n3ds/SDL_n3dsevents.c",
//     "src/video/n3ds/SDL_n3dsframebuffer.c",
//     "src/video/n3ds/SDL_n3dsswkb.c",
//     "src/video/n3ds/SDL_n3dstouch.c",
//     "src/video/n3ds/SDL_n3dsvideo.c",
//     "src/video/nacl/SDL_naclevents.c",
//     "src/video/nacl/SDL_naclglue.c",
//     "src/video/nacl/SDL_naclopengles.c",
//     "src/video/nacl/SDL_naclvideo.c",
//     "src/video/nacl/SDL_naclwindow.c",
//     "src/video/offscreen/SDL_offscreenevents.c",
//     "src/video/offscreen/SDL_offscreenframebuffer.c",
//     "src/video/offscreen/SDL_offscreenopengles.c",
//     "src/video/offscreen/SDL_offscreenvideo.c",
//     "src/video/offscreen/SDL_offscreenwindow.c",
//     "src/video/os2/SDL_os2dive.c",
//     "src/video/os2/SDL_os2messagebox.c",
//     "src/video/os2/SDL_os2mouse.c",
//     "src/video/os2/SDL_os2util.c",
//     "src/video/os2/SDL_os2video.c",
//     "src/video/os2/SDL_os2vman.c",
//     "src/video/pandora/SDL_pandora.c",
//     "src/video/pandora/SDL_pandora_events.c",
//     "src/video/ps2/SDL_ps2video.c",
//     "src/video/psp/SDL_pspevents.c",
//     "src/video/psp/SDL_pspgl.c",
//     "src/video/psp/SDL_pspmouse.c",
//     "src/video/psp/SDL_pspvideo.c",
//     "src/video/qnx/gl.c",
//     "src/video/qnx/keyboard.c",
//     "src/video/qnx/video.c",
//     "src/video/raspberry/SDL_rpievents.c",
//     "src/video/raspberry/SDL_rpimouse.c",
//     "src/video/raspberry/SDL_rpiopengles.c",
//     "src/video/raspberry/SDL_rpivideo.c",
//     "src/video/riscos/SDL_riscosevents.c",
//     "src/video/riscos/SDL_riscosframebuffer.c",
//     "src/video/riscos/SDL_riscosmessagebox.c",
//     "src/video/riscos/SDL_riscosmodes.c",
//     "src/video/riscos/SDL_riscosmouse.c",
//     "src/video/riscos/SDL_riscosvideo.c",
//     "src/video/riscos/SDL_riscoswindow.c",
//     "src/video/vita/SDL_vitaframebuffer.c",
//     "src/video/vita/SDL_vitagl_pvr.c",
//     "src/video/vita/SDL_vitagles.c",
//     "src/video/vita/SDL_vitagles_pvr.c",
//     "src/video/vita/SDL_vitakeyboard.c",
//     "src/video/vita/SDL_vitamessagebox.c",
//     "src/video/vita/SDL_vitamouse.c",
//     "src/video/vita/SDL_vitatouch.c",
//     "src/video/vita/SDL_vitavideo.c",
//     "src/video/vivante/SDL_vivanteopengles.c",
//     "src/video/vivante/SDL_vivanteplatform.c",
//     "src/video/vivante/SDL_vivantevideo.c",
//     "src/video/vivante/SDL_vivantevulkan.c",
//
//     "src/render/opengl/SDL_render_gl.c",
//     "src/render/opengl/SDL_shaders_gl.c",
//     "src/render/opengles/SDL_render_gles.c",
//     "src/render/opengles2/SDL_render_gles2.c",
//     "src/render/opengles2/SDL_shaders_gles2.c",
//     "src/render/ps2/SDL_render_ps2.c",
//     "src/render/psp/SDL_render_psp.c",
//     "src/render/vitagxm/SDL_render_vita_gxm.c",
//     "src/render/vitagxm/SDL_render_vita_gxm_memory.c",
//     "src/render/vitagxm/SDL_render_vita_gxm_tools.c",
// };
