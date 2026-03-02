const std = @import("std");
const Step = std.Build.Step;

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "digibib.app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            // .root_source_file = b.path("src/main_enc.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .arm,
                .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_a7 },
                .os_tag = .linux,
                .abi = .gnueabi,
                .glibc_version = .{ .major = 2, .minor = 25, .patch = 0 }, // std.Io.Threaded.init_single_threaded
            }),
            .optimize = b.standardOptimizeOption(.{}),
        }),
    });

    exe.root_module.addIncludePath(b.path("sdk/include"));
    exe.root_module.addIncludePath(b.path("sdk/include/freetype2"));
    exe.root_module.addIncludePath(b.path("sdk/local/include"));
    exe.root_module.addLibraryPath(b.path("sdk/local/lib"));
    exe.root_module.linkSystemLibrary("hwconfig", .{});
    exe.root_module.linkSystemLibrary("inkview", .{});
    exe.root_module.link_libc = true;

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
        const send_tar = SendTar.create(b, dest_ip, 10003);
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

const SendTar = struct {
    pub const base_id: Step.Id = .custom;

    step: Step,
    dest_ip: []const u8,
    dest_port: u16,

    pub fn create(owner: *std.Build, dest_ip: []const u8, dest_port: u16) *SendTar {
        const send_tar = owner.allocator.create(SendTar) catch @panic("OOM");

        send_tar.* = .{
            .step = Step.init(.{
                .id = base_id,
                .name = owner.fmt("send tarball to {s}:{d}", .{ dest_ip, dest_port }),
                .owner = owner,
                .makeFn = make,
            }),
            .dest_ip = owner.dupe(dest_ip),
            .dest_port = dest_port,
        };

        return send_tar;
    }

    fn make(step: *Step, options: Step.MakeOptions) !void {
        _ = options; // No progress to report.
        const b = step.owner;
        const send_tar: *SendTar = @fieldParentPtr("step", step);

        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        var tcp_stream = try std.Io.net.IpAddress.connect(try std.Io.net.IpAddress.parse(send_tar.dest_ip, send_tar.dest_port), io, .{ .mode = .stream });
        defer tcp_stream.close(io);
        var tcp_buffer: [1024]u8 = undefined;
        var tcp_writer = tcp_stream.writer(io, &tcp_buffer);

        var gzip_buffer: [std.compress.flate.max_window_len]u8 = undefined;
        var gzip_compress: std.compress.flate.Compress = try .init(&tcp_writer.interface, &gzip_buffer, .gzip, .default);
        const gzip_writer = &gzip_compress.writer;

        var tar_writer: std.tar.Writer = .{ .underlying_writer = gzip_writer };

        var install_dir = try std.Io.Dir.openDirAbsolute(io, b.getInstallPath(.prefix, ""), .{ .iterate = true });
        defer install_dir.close(io);

        var install_walker = try install_dir.walk(b.allocator);
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
    }
};
