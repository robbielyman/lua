const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const build_shared = b.option(bool, "shared", "build a shared library") orelse false;
    const use_xwin = b.option(bool, "use_xwin", "use xwin to install MSVC SDK") orelse blk: {
        break :blk target.result.abi == .msvc and !target.query.isNative();
    };
    const sdk_version = b.option([]const u8, "sdk_version", "which version of the MSVC to install") orelse "10.0.20348";

    const xwin = b.dependency("zig-build-msvc-sdk", .{
        .target = target,
        .optimize = optimize,
        .sdk_version = sdk_version,
    });
    const msvc_write_files = xwin.namedWriteFiles("msvc_libc");
    const msvc_libc_txt = msvc_write_files.getDirectory().path(b, "libc.txt");

    const upstream = b.dependency("lua54", .{});

    const static = b.addStaticLibrary(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 5, .minor = 4, .patch = 7 },
    });
    if (use_xwin) {
        static.libc_file = msvc_libc_txt;
        static.step.dependOn(&msvc_write_files.step);
    }
    const shared = if (build_shared) b.addSharedLibrary(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 5, .minor = 4, .patch = 7 },
    }) else null;
    if (shared) |s| {
        if (use_xwin) s.libc_file = msvc_libc_txt;
        s.step.dependOn(&msvc_write_files.step);
    }
    const exe = b.addExecutable(.{
        .name = "lua",
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 5, .minor = 4, .patch = 7 },
        .link_libc = true,
    });
    if (use_xwin) {
        exe.libc_file = msvc_libc_txt;
        exe.step.dependOn(&msvc_write_files.step);
    }
    // statically link on windows to avoid https://github.com/ziglang/zig/issues/15107 in 0.13.0
    exe.linkLibrary(if (build_shared and target.result.os.tag != .windows) shared.? else static);

    const lua_c = b.addExecutable(.{
        .name = "luac",
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 5, .minor = 4, .patch = 7 },
        .link_libc = true,
    });
    if (use_xwin) {
        lua_c.libc_file = msvc_libc_txt;
        lua_c.step.dependOn(&msvc_write_files.step);
    }

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
        if (use_xwin) lib.libc_file = msvc_libc_txt;
        lib.step.dependOn(&msvc_write_files.step);
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
