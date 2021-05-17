# Adapted from the following links and pulling in options from old CROSSTOOL.template
# https://docs.bazel.build/versions/0.26.0/tutorial/cc-toolchain-config.html
# https://github.com/bazelbuild/bazel/blob/4dfc83d5f11e9190e9e25dee4c7dc2a71cd7b8fd/tools/osx/crosstool/cc_toolchain_config.bzl
# https://docs.bazel.build/versions/master/skylark/lib/cc_common.html#create_cc_toolchain_config_info

load(
    "@bazel_tools//tools/cpp:cc_toolchain_config_lib.bzl",
    "action_config",
    "artifact_name_pattern",
    "env_entry",
    "env_set",
    "feature",
    "feature_set",
    "flag_group",
    "flag_set",
    "make_variable",
    "tool",
    "tool_path",
    "variable_with_value",
    "with_feature_set",
)
load("@bazel_tools//tools/build_defs/cc:action_names.bzl", "ACTION_NAMES")

def _impl(ctx):
    toolchain_identifier = "clang-darwin"
    host_system_name = "x86_64-apple-macosx"
    target_system_name = "x86_64-apple-macosx"
    target_cpu = "darwin"
    target_libc = "macosx"
    compiler = "clang"
    abi_version = "darwin_x86_64"
    abi_libc_version = "darwin_x86_64"
    cc_target_os = None

    builtin_sysroot = "${CONDA_BUILD_SYSROOT}"

    all_compile_actions = [
        ACTION_NAMES.c_compile,
        ACTION_NAMES.cpp_compile,
        ACTION_NAMES.linkstamp_compile,
        ACTION_NAMES.assemble,
        ACTION_NAMES.preprocess_assemble,
        ACTION_NAMES.cpp_header_parsing,
        ACTION_NAMES.cpp_module_compile,
        ACTION_NAMES.cpp_module_codegen,
        ACTION_NAMES.clif_match,
        ACTION_NAMES.lto_backend,
    ]

    all_cpp_compile_actions = [
        ACTION_NAMES.cpp_compile,
        ACTION_NAMES.linkstamp_compile,
        ACTION_NAMES.cpp_header_parsing,
        ACTION_NAMES.cpp_module_compile,
        ACTION_NAMES.cpp_module_codegen,
        ACTION_NAMES.clif_match,
    ]

    preprocessor_compile_actions = [
        ACTION_NAMES.c_compile,
        ACTION_NAMES.cpp_compile,
        ACTION_NAMES.linkstamp_compile,
        ACTION_NAMES.preprocess_assemble,
        ACTION_NAMES.cpp_header_parsing,
        ACTION_NAMES.cpp_module_compile,
        ACTION_NAMES.clif_match,
    ]

    codegen_compile_actions = [
        ACTION_NAMES.c_compile,
        ACTION_NAMES.cpp_compile,
        ACTION_NAMES.linkstamp_compile,
        ACTION_NAMES.assemble,
        ACTION_NAMES.preprocess_assemble,
        ACTION_NAMES.cpp_module_codegen,
        ACTION_NAMES.lto_backend,
    ]

    all_link_actions = [
        ACTION_NAMES.cpp_link_executable,
        ACTION_NAMES.cpp_link_dynamic_library,
        ACTION_NAMES.cpp_link_nodeps_dynamic_library,
    ]

    action_configs = []

    linker_flags = [
        "-Wl,-dead_strip_dylibs",
        "-L${PREFIX}/lib",
        "-isystem ${CONDA_BUILD_SYSROOT}",
        # Difficult to guess options to statically link C++ libraries with the macOS linker.
        "-lc++",
        "-lc++abi",
        "-headerpad_max_install_names",
        "-undefined",
        "dynamic_lookup",
    ]

    opt_feature = feature(name = "opt")
    fastbuild_feature = feature(name = "fastbuild")

    random_seed_feature = feature(name = "random_seed", enabled = True)
    supports_pic_feature = feature(name = "supports_pic", enabled = True)
    supports_dynamic_linker_feature = feature(name = "supports_dynamic_linker", enabled = True)

    unfiltered_compile_flags_feature = feature(
        name = "unfiltered_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            # Do not resolve our smylinked resource prefixes to real paths.
                            "-no-canonical-prefixes",
                            # Reproducibility
                            "-Wno-builtin-macro-redefined",
                            "-D__DATE__=\"redacted\"",
                            "-D__TIMESTAMP__=\"redacted\"",
                            "-D__TIME__=\"redacted\"",
                        ],
                    ),
                ],
            ),
        ],
    )

    default_link_flags_feature = feature(
        name = "default_link_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_link_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            "-lm",
                            "-no-canonical-prefixes",
                        ] + linker_flags,
                    ),
                ],
            ),
        ],
    )

    default_compile_flags_feature = feature(
        name = "default_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            # Security
                            "-U_FORTIFY_SOURCE",  # https://github.com/google/sanitizers/issues/247
                            "-fstack-protector",
                            "-fno-omit-frame-pointer",
                            # Diagnostics
                            "-fcolor-diagnostics",
                            "-Wall",
                            "-Wthread-safety",
                            "-Wself-assign",
                        ],
                    ),
                ],
            ),
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = [
                            "-g0",
                            "-O2",
                            "-D_FORTIFY_SOURCE=1",
                            "-DNDEBUG",
                            "-ffunction-sections",
                            "-fdata-sections",
                        ],
                    ),
                ],
                with_features = [with_feature_set(features = ["opt"])],
            ),
            flag_set(
                actions = all_cpp_compile_actions,
                flag_groups = [flag_group(flags = ["-std=c++14", "-stdlib=libc++"])],
            ),
        ],
    )

    objcopy_embed_flags_feature = feature(
        name = "objcopy_embed_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = ["objcopy_embed_data"],
                flag_groups = [flag_group(flags = ["-I", "binary"])],
            ),
        ],
    )

    user_compile_flags_feature = feature(
        name = "user_compile_flags",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        expand_if_available = "user_compile_flags",
                        flags = ["%{user_compile_flags}"],
                        iterate_over = "user_compile_flags",
                    ),
                ],
            ),
        ],
    )

    sysroot_feature = feature(
        name = "sysroot",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = all_compile_actions + all_link_actions,
                flag_groups = [
                    flag_group(
                        expand_if_available = "sysroot",
                        flags = ["--sysroot=%{sysroot}"],
                    ),
                ],
            ),
        ],
    )

    coverage_feature = feature(
        name = "coverage",
        flag_sets = [
            flag_set(
                actions = all_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = ["-fprofile-instr-generate", "-fcoverage-mapping"],
                    ),
                ],
            ),
            flag_set(
                actions = all_link_actions,
                flag_groups = [flag_group(flags = ["-fprofile-instr-generate"])],
            ),
        ],
        provides = ["profile"],
    )

    framework_paths_feature = feature(
        name = "framework_paths",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.objc_compile,
                    ACTION_NAMES.objcpp_compile,
                    "objc-executable",
                    "objc++-executable",
                ],
                flag_groups = [
                    flag_group(
                        flags = ["-F%{framework_paths}"],
                        iterate_over = "framework_paths",
                    ),
                ],
            ),
        ],
    )

    include_paths_feature = feature(
        name = "include_paths",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = preprocessor_compile_actions,
                flag_groups = [
                    flag_group(
                        flags = ["/I%{quote_include_paths}"],
                        iterate_over = "quote_include_paths",
                    ),
                    flag_group(
                        flags = ["/I%{include_paths}"],
                        iterate_over = "include_paths",
                    ),
                    flag_group(
                        flags = ["/I%{system_include_paths}"],
                        iterate_over = "system_include_paths",
                    ),
                ],
            ),
        ],
    )

    dependency_file_feature = feature(
        name = "dependency_file",
        enabled = True,
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_header_parsing,
                ],
                flag_groups = [
                    flag_group(
                        expand_if_available = "dependency_file",
                        flags = ["/DEPENDENCY_FILE", "%{dependency_file}"],
                    ),
                ],
            ),
        ],
    )

    compiler_input_flags_feature = feature(
        name = "compiler_input_flags",
        flag_sets = [
            flag_set(
                actions = [
                    ACTION_NAMES.assemble,
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [
                    flag_group(
                        expand_if_available = "source_file",
                        flags = ["/c", "%{source_file}"],
                    ),
                ],
            ),
        ],
    )

    compiler_output_flags_feature = feature(
        name = "compiler_output_flags",
        flag_sets = [
            flag_set(
                actions = [ACTION_NAMES.assemble],
                flag_groups = [
                    flag_group(
                        expand_if_available = "output_file",
                        expand_if_not_available = "output_assembly_file",
                        flags = ["/Fo%{output_file}", "/Zi"],
                    ),
                ],
            ),
            flag_set(
                actions = [
                    ACTION_NAMES.preprocess_assemble,
                    ACTION_NAMES.c_compile,
                    ACTION_NAMES.cpp_compile,
                    ACTION_NAMES.cpp_header_parsing,
                    ACTION_NAMES.cpp_module_compile,
                    ACTION_NAMES.cpp_module_codegen,
                ],
                flag_groups = [
                    flag_group(
                        expand_if_available = "output_file",
                        expand_if_not_available = "output_assembly_file",
                        flags = ["/Fo%{output_file}"],
                    ),
                    flag_group(
                        expand_if_available = "output_file",
                        flags = ["/Fa%{output_file}"],
                    ),
                    flag_group(
                        expand_if_available = "output_file",
                        flags = ["/P", "/Fi%{output_file}"],
                    ),
                ],
            ),
        ],
    )

    features = [
        opt_feature,
        fastbuild_feature,
        random_seed_feature,
        supports_pic_feature,
        supports_dynamic_linker_feature,
        unfiltered_compile_flags_feature,
        default_link_flags_feature,
        default_compile_flags_feature,
        objcopy_embed_flags_feature,
        user_compile_flags_feature,
        sysroot_feature,
        coverage_feature,
        # Windows only features.
        # input_paths_feature
        # dependency_file_feature
        # compiler_input_flags_feature
        # compiler_output_flags_feature
    ]
    features.extend([framework_paths_feature])

    cxx_builtin_include_directories = [
        "${BUILD_PREFIX}/include",
        "${BUILD_PREFIX}/include/c++/v1",
        "${BUILD_PREFIX}/lib/clang/10.0.0/include",
        "${BUILD_PREFIX}/lib64/clang/10.0.0/include",
    ]
    cxx_builtin_include_directories += [
        "${CONDA_BUILD_SYSROOT}/usr/include",
        "${CONDA_BUILD_SYSROOT}/System/Library/Frameworks",
        "/Library/Frameworks",
    ]

    artifact_name_patterns = []

    make_variables = [
        make_variable(
            name = "STACK_FRAME_UNLIMITED",
            value = "-Wframe-larger-than=100000000 -Wno-vla",
        ),
    ]

    tool_paths = [
        tool_path(name = "ld", path = "${LD}"),
        tool_path(
            name = "cpp",
            path = "${PREFIX}/bin/clang-cpp",
        ),
        tool_path(
            name = "dwp",
            path = "${PREFIX}/bin/llvm-dwp",
        ),
        tool_path(
            name = "gcov",
            path = "${PREFIX}/bin/llvm-profdata",
        ),
        tool_path(
            name = "nm",
            path = "${NM}",
        ),
        tool_path(
            name = "objcopy",
            path = "${PREFIX}/bin/llvm-objcopy",
        ),
        tool_path(
            name = "objdump",
            path = "${PREFIX}/bin/llvm-objdump",
        ),
        tool_path(name = "strip", path = "${STRIP}"),
        tool_path(
            name = "gcc",
            path = "cc_wrapper.sh",
        ),
        tool_path(name = "ar", path = "${LIBTOOL}"),
    ]

    out = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(out, "Fake executable")
    return [
        cc_common.create_cc_toolchain_config_info(
            ctx = ctx,
            features = features,
            action_configs = action_configs,
            artifact_name_patterns = artifact_name_patterns,
            cxx_builtin_include_directories = cxx_builtin_include_directories,
            toolchain_identifier = toolchain_identifier,
            host_system_name = host_system_name,
            target_system_name = target_system_name,
            target_cpu = target_cpu,
            target_libc = target_libc,
            compiler = compiler,
            abi_version = abi_version,
            abi_libc_version = abi_libc_version,
            tool_paths = tool_paths,
            make_variables = make_variables,
            builtin_sysroot = builtin_sysroot,
            cc_target_os = cc_target_os,
        ),
        DefaultInfo(
            executable = out,
        ),
    ]

cc_toolchain_config = rule(
    attrs = {},
    executable = True,
    provides = [CcToolchainConfigInfo],
    implementation = _impl,
)
