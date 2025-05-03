const std = @import("std");
const builtin = @import("builtin");
const android = @import("android");
const sdl = @import("sdl");
const FpsManager = @import("FpsManager.zig");

const log = std.log;
const assert = std.debug.assert;

const allocator_global = std.heap.c_allocator;

/// custom standard options for Android
pub const std_options: std.Options = if (builtin.abi.isAndroid())
    .{
        .logFn = android.logFn,
    }
else
    .{};

/// custom panic handler for Android
pub const panic = if (builtin.abi.isAndroid())
    android.panic
else
    std.debug.FullPanic(std.debug.defaultPanic);

comptime {
    if (builtin.abi.isAndroid()) {
        @export(&SDL_main, .{ .name = "SDL_main", .linkage = .strong });
    }
}

/// This needs to be exported for Android builds
fn SDL_main() callconv(.C) void {
    if (comptime builtin.abi.isAndroid()) {
        _ = std.start.callMain();
    } else {
        @compileError("SDL_main should not be called outside of Android builds");
    }
}

pub fn main() !void {
    log.debug("started sdl3-zig-demo ........................ hurray", .{});

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        log.info("Unable to initialize SDL: {s}", .{sdl.SDL_GetError()});
        return error.SDLInitializationFailed;
    }
    defer sdl.SDL_Quit();

    const screen = sdl.SDL_CreateWindow("My Game Window", 400, 140, sdl.SDL_WINDOW_FULLSCREEN) orelse {
        log.info("Unable to create window: {s}", .{sdl.SDL_GetError()});
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyWindow(screen);

    const num_render_drivers = sdl.SDL_GetNumRenderDrivers();
    for (0..@intCast(num_render_drivers)) |i| {
        const driver_name = sdl.SDL_GetRenderDriver(@intCast(i));
        log.debug("render driver {d}: {s}", .{ i, driver_name });
    }

    const renderer = sdl.SDL_CreateRenderer(screen, null) orelse {
        log.info("Unable to create renderer: {s}", .{sdl.SDL_GetError()});
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    var fps_manager = FpsManager.init(.none);

    var quit = false;
    while (!quit) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        fps_manager.tick();

        _ = sdl.SDL_SetRenderDrawColor(renderer, 45, 45, 45, 255);
        _ = sdl.SDL_RenderClear(renderer);

        _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
        _ = sdl.SDL_SetRenderScale(renderer, 5, 6);

        _ = sdl.SDL_RenderDebugText(renderer, 50, 50, "SucessFully Created SDL3 Android App");
        _ = sdl.SDL_RenderDebugText(renderer, 50, 70, sdl.SDL_GetRendererName(renderer));
        _ = sdl.SDL_SetRenderScale(renderer, 1, 1);

        try drawFPS(renderer, fps_manager);

        _ = sdl.SDL_RenderPresent(renderer);
    }
}

fn drawFPS(renderer: *sdl.SDL_Renderer, limiter: FpsManager) !void {
    const fps_text = try std.fmt.allocPrintZ(allocator_global, "FPS: {d:.2} Delta: {d:.6}", .{ limiter.getFps(), limiter.getDelta() });
    defer allocator_global.free(fps_text);

    // std.debug.print("FPS: {d}\n", .{AppState.fps});

    //Draw Code
    if (limiter.getFps() >= 59.5) {
        _ = sdl.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 180);
    } else {
        _ = sdl.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 180);
    }

    _ = sdl.SDL_SetRenderScale(renderer, 4, 4);
    assert(sdl.SDL_RenderDebugText(renderer, 12, 12, fps_text));
    _ = sdl.SDL_SetRenderScale(renderer, 1, 1);
}
