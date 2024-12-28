const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const build_shared = b.option(bool, "shared", "build a shared library") orelse false;

    const upstream = b.dependency("lua54", .{});

    const static = b.addStaticLibrary(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 5, .minor = 4, .patch = 7 },
    });
    const shared = if (build_shared) b.addSharedLibrary(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 5, .minor = 4, .patch = 7 },
    }) else null;
    const exe = b.addExecutable(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 5, .minor = 4, .patch = 7 },
        .link_libc = true,
    });
    exe.linkLibrary(if (build_shared) shared.? else static);

    const lua_c = b.addExecutable(.{
        .name = "luac",
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 5, .minor = 4, .patch = 7 },
        .link_libc = true,
    });

    b.installArtifact(exe);
    b.installArtifact(lua_c);

    const flags: []const []const u8 = flags: {
        const flags: [1][]const u8 = .{
            switch (target.result.os.tag) {
                .linux => "-DLUA_USE_LINUX",
                .macos => "-DLUA_USE_MACOSX",
                .windows => "-DLUA_USE_WINDOWS",
                else => "-DLUA_USE_POSIX",
            },
        };
        break :flags if (optimize == .Debug) &(flags ++ .{"-DLUA_USE_APICHECK"}) else &flags;
    };
    exe.addCSourceFile(.{ .file = upstream.path("src/lua.c"), .flags = flags });
    lua_c.addCSourceFile(.{ .file = upstream.path("src/luac.c"), .flags = flags });
    lua_c.addCSourceFiles(.{
        .root = .{ .dependency = .{ .dependency = upstream, .sub_path = "" } },
        .files = lua_source_files,
        .flags = flags,
    });

    const libs: []const *std.Build.Step.Compile = if (build_shared) &.{ static, shared.? } else &.{static};
    for (libs) |lib| {
        lib.addIncludePath(upstream.path("src"));
        lib.addCSourceFiles(.{
            .root = .{ .dependency = .{ .dependency = upstream, .sub_path = "" } },
            .files = lua_source_files,
            .flags = flags,
        });
        lib.linkLibC();
        lib.installHeader(upstream.path("src/lua.h"), "lua.h");
        lib.installHeader(upstream.path("src/lualib.h"), "lualib.h");
        lib.installHeader(upstream.path("src/lauxlib.h"), "lauxlib.h");
        lib.installHeader(upstream.path("src/luaconf.h"), "luaconf.h");
        b.installArtifact(lib);
    }
}

const lua_source_files: []const []const u8 = &.{
    "src/lapi.c",
    "src/lcode.c",
    "src/ldebug.c",
    "src/ldo.c",
    "src/ldump.c",
    "src/lfunc.c",
    "src/lgc.c",
    "src/llex.c",
    "src/lmem.c",
    "src/lobject.c",
    "src/lopcodes.c",
    "src/lparser.c",
    "src/lstate.c",
    "src/lstring.c",
    "src/ltable.c",
    "src/ltm.c",
    "src/lundump.c",
    "src/lvm.c",
    "src/lzio.c",
    "src/lauxlib.c",
    "src/lbaselib.c",
    "src/ldblib.c",
    "src/liolib.c",
    "src/lmathlib.c",
    "src/loslib.c",
    "src/ltablib.c",
    "src/lstrlib.c",
    "src/loadlib.c",
    "src/linit.c",
    "src/lctype.c",
    "src/lcorolib.c",
    "src/lutf8lib.c",
};
