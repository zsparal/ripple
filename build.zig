const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The list of static build steps.
    // NOTE: The following additional build steps will be generated:
    //   1. One run step for each configured executable
    const steps = .{
        .check = b.step("check", "Checks if the shared library and all clients compile"),
        .@"test" = b.step("test", "Run unit tests"),
    };

    // Setting up modules, libraries and executables
    const modules = .{
        .ripple = addNamedModule(b, "ripple", .{
            .root = b.path("lib/ripple.zig"),
            .target = target,
            .mode = optimize,
        }),
    };

    const libs = .{
        .ripple = addCheckedStaticLibrary(b, "ripple", .{
            .root = &modules.ripple,
            .imports = &.{},
        }),
    };

    const executables = .{
        .broker = addCheckedExecutable(b, "broker", .{
            .root = b.path("src/broker.zig"),
            .imports = &.{modules.ripple},
            .target = target,
            .mode = optimize,
        }),
    };

    // Check step for ZLS and CI
    inline for (.{ libs.ripple, executables.broker }) |artifact| {
        steps.check.dependOn(&artifact.check.step);
    }

    // Add unit tests
    inline for (.{ libs.ripple, executables.broker }) |artifact| {
        const run_test = b.addRunArtifact(artifact.@"test");
        steps.@"test".dependOn(&run_test.step);
    }
}

const NamedModule = struct {
    name: []const u8,
    module: *std.Build.Module,
};

const CheckedArtifact = struct {
    artifact: *std.Build.Step.Compile,
    @"test": *std.Build.Step.Compile,
    check: *std.Build.Step.Compile,
};

fn addNamedModule(b: *std.Build, comptime name: []const u8, options: struct {
    root: std.Build.LazyPath,
    target: std.Build.ResolvedTarget,
    mode: std.builtin.OptimizeMode,
}) NamedModule {
    const module = b.addModule(name, .{
        .root_source_file = options.root,
        .target = options.target,
        .optimize = options.mode,
    });

    return .{ .name = name, .module = module };
}

fn addCheckedStaticLibrary(b: *std.Build, comptime name: []const u8, options: struct {
    root: *const NamedModule,
    imports: []const NamedModule,
}) CheckedArtifact {
    const libs = CheckedArtifact{
        .artifact = b.addLibrary(.{
            .linkage = .static,
            .name = name,
            .root_module = options.root.module,
        }),
        // Duplicate the step for check and step. This way we can set up the run artifact for
        // the real test only, making sure the "check" step can run with `-fno-emit-bin`. This
        // speeds up editor experience quite a bit by skipping LLVM codegen.
        // NOTE: We use `addTest` for the check stage as well so we can use `refAllDeclsRecursive`
        //       for a simplified setup
        .check = b.addTest(.{
            .name = name,
            .root_module = options.root.module,
        }),
        .@"test" = b.addTest(.{
            .name = name,
            .root_module = options.root.module,
        }),
    };

    inline for (.{ libs.artifact, libs.check }) |lib| {
        for (options.imports) |import| {
            lib.root_module.addImport(import.name, import.module);
        }
    }

    b.installArtifact(libs.artifact);

    return libs;
}

fn addCheckedExecutable(b: *std.Build, comptime name: []const u8, options: struct {
    root: std.Build.LazyPath,
    imports: []const NamedModule,
    target: std.Build.ResolvedTarget,
    mode: std.builtin.OptimizeMode,
}) CheckedArtifact {
    const exe_name = "ripple-" ++ name;
    const root_module = b.createModule(.{
        .root_source_file = options.root,
        .target = options.target,
        .optimize = options.mode,
    });

    const executables = CheckedArtifact{
        .artifact = b.addExecutable(.{
            .name = exe_name,
            .root_module = root_module,
        }),
        .check = b.addTest(.{
            .name = exe_name,
            .root_module = root_module,
        }),
        .@"test" = b.addTest(.{
            .name = exe_name,
            .root_module = root_module,
        }),
    };

    inline for (.{ executables.artifact, executables.check }) |exe| {
        for (options.imports) |import| {
            exe.root_module.addImport(import.name, import.module);
        }
    }

    b.installArtifact(executables.artifact);

    // Set up a different run step for each executable
    const run_artifact = b.addRunArtifact(executables.artifact);
    run_artifact.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_artifact.addArgs(args);
    }

    const run_step = b.step("run:" ++ name, "Runs the executable of the Ripple " ++ name);
    run_step.dependOn(&run_artifact.step);

    return executables;
}
