const std = @import("std");
const Step = std.Build.Step;

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .arm,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_a7 },
        .os_tag = .linux,
        .abi = .gnueabi,
        .glibc_version = .{ .major = 2, .minor = 25, .patch = 0 }, // std.Io.Threaded.init_single_threaded
    });
    const optimize = b.standardOptimizeOption(.{});

    const inkview_header = b.addWriteFiles().add("sdk/local/include/all.h",
        \\#include <inkview.h>
        \\#include <selection_list.h>
    );
    const inkview_translate = b.addTranslateC(.{
        .root_source_file = inkview_header,
        .target = target,
        .optimize = optimize,
    });
    inkview_translate.addIncludePath(b.path("sdk/include"));
    inkview_translate.addIncludePath(b.path("sdk/local/include"));

    const inkview_module = inkview_translate.createModule();
    inkview_module.addLibraryPath(b.path("sdk/local/lib_b288"));
    inkview_module.linkSystemLibrary("inkview", .{});

    const exe = b.addExecutable(.{
        .name = "digibib.app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            // .root_source_file = b.path("src/main_enc.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "inkview", .module = inkview_module },
            },
        }),
    });

    const applications_dir: std.Build.InstallDir = .{ .custom = "applications" };

    const install_artifact = b.addInstallArtifact(exe, .{
        .dest_dir = .{
            .override = applications_dir,
        },
    });

    const dest_ip = b.option([]const u8, "dest_ip", "device ip") orelse "";
    if (std.mem.eql(u8, "", dest_ip)) {
        b.getInstallStep().dependOn(&install_artifact.step);
    } else {
        const tar_exe = b.addExecutable(.{
            .name = "tar",
            .root_module = b.createModule(.{
                .root_source_file = b.path("build.zig"),
                .target = b.graph.host,
            }),
        });

        const send_tar = b.addRunArtifact(tar_exe);
        send_tar.setName("send tarball to device");
        send_tar.addFileArg(b.path("zig-out"));
        send_tar.addArg(dest_ip);
        send_tar.step.dependOn(&install_artifact.step);
        b.getInstallStep().dependOn(&send_tar.step);
    }

    /////////////////////////////////////////////////////////////////////////////////
    // https://github.com/FalsePattern/ZigBrains/issues/82#issuecomment-2758853680 //
    //                                  Build steps: test                          //
    //                            Debug Build steps: test                          //
    // Debug output executable created by the build: zig-out/tests/test (absolute) //
    /////////////////////////////////////////////////////////////////////////////////

    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/enc/vlado.zig"),
            .target = b.graph.host,
        }),
    });

    test_exe.root_module.link_libc = true;

    const test_install_artifact = b.addInstallArtifact(test_exe, .{
        .dest_dir = .{
            .override = .{ .custom = "tests" },
        },
    });

    const test_run_artifact = b.addRunArtifact(test_exe);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_install_artifact.step);
    test_step.dependOn(&test_run_artifact.step);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 3) {
        fatal("wrong number of arguments {d}", .{args.len});
    }

    const install_path = args[1];
    const dest_ip = args[2];
    const dest_port: u16 = 10003;

    const ip_address = try std.Io.net.IpAddress.parse(dest_ip, dest_port);
    var tcp_stream = try std.Io.net.IpAddress.connect(&ip_address, io, .{ .mode = .stream });
    defer tcp_stream.close(io);
    var tcp_buffer: [1024]u8 = undefined;
    var tcp_writer = tcp_stream.writer(io, &tcp_buffer);

    var gzip_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var gzip_compress: std.compress.flate.Compress = try .init(&tcp_writer.interface, &gzip_buffer, .gzip, .default);
    const gzip_writer = &gzip_compress.writer;

    var tar_writer: std.tar.Writer = .{ .underlying_writer = gzip_writer };

    var install_dir = try std.Io.Dir.openDirAbsolute(io, install_path, .{ .iterate = true });
    defer install_dir.close(io);

    var install_walker = try install_dir.walk(arena);
    defer install_walker.deinit();

    while (try install_walker.next(io)) |install_entry| {
        switch (install_entry.kind) {
            .file => {
                const file = try install_entry.dir.openFile(io, install_entry.basename, .{ .mode = .read_only });
                defer file.close(io);
                var file_buffer: [1024]u8 = undefined;
                var file_reader = file.reader(io, &file_buffer);

                try tar_writer.writeFile(install_entry.path, &file_reader, 0);
            },
            else => {},
        }
    }

    try tar_writer.finishPedantically();
    try gzip_writer.flush();
    try tcp_writer.interface.flush();

    return std.process.cleanExit(io);
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
