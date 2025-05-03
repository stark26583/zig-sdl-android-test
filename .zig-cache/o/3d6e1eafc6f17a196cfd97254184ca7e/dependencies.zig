pub const packages = struct {
    pub const @"android-0.1.0-7iz7QoSaAQCGbFl_CMg5mPgHq4_vogPxzxlhWpr5rM88" = struct {
        pub const build_root = "/home/stark/.cache/zig/p/android-0.1.0-7iz7QoSaAQCGbFl_CMg5mPgHq4_vogPxzxlhWpr5rM88";
        pub const build_zig = @import("android-0.1.0-7iz7QoSaAQCGbFl_CMg5mPgHq4_vogPxzxlhWpr5rM88");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
    pub const sdl = struct {
        pub const build_root = "/home/stark/Windows/Users/User/Desktop/Programming/zig/sdl-android-test/sdl";
        pub const build_zig = @import("sdl");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
            .{ "sdl3", "sdl/SDL-release-3.2.10" },
        };
    };
    pub const @"sdl/SDL-release-3.2.10" = struct {
        pub const build_root = "/home/stark/Windows/Users/User/Desktop/Programming/zig/sdl-android-test/sdl/SDL-release-3.2.10";
        pub const deps: []const struct { []const u8, []const u8 } = &.{};
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "sdl", "sdl" },
    .{ "android", "android-0.1.0-7iz7QoSaAQCGbFl_CMg5mPgHq4_vogPxzxlhWpr5rM88" },
};
