#!/bin/bash

set -ex

export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV="*"

# expand PREFIX in tensor's build_config/BUILD file
sed -i -e "s:\${PREFIX}:${PREFIX}:" tensorflow/core/platform/default/build_config/BUILD

# variant specific settings
if [ ${tflow_variant} == "mkl" ]; then
    export TF_NEED_MKL=1
    export BAZEL_MKL_OPT="--config=mkl "
else
    # eigen variant, do not build with MKL support
    export TF_NEED_MKL=0
    export BAZEL_MKL_OPT=""
fi
echo "TF_NEED_MKL: ${TF_NEED_MKL}"
echo "BAZEL_MKL_OPT: ${BAZEL_MKL_OPT}"

export PYTHON_BIN_PATH="$PYTHON"
export PYTHON_LIB_PATH="$SP_DIR"
export USE_DEFAULT_PYTHON_LIB_PATH=1

export TF_NEED_CUDA=0
export TF_CUDA_CLANG=0
export TF_DOWNLOAD_CLANG=0
export TF_ENABLE_XLA=0
export TF_NEED_VERBS=0
export TF_NEED_GCP=1
export TF_NEED_KAFKA=0
export TF_NEED_HDFS=0
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_CLANG=0
export TF_NEED_ROCM=0
export TF_NEED_TENSORRT=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_DOWNLOAD_CLANG=0
export TF_NEED_ROCM=0
export TF_NEED_MPI=0
export TF_NEED_COMPUTECPP=0
export TF_CONFIGURE_IOS=0
unset OLD_PATH
unset ORIGINAL_PATH
unset __VSCMD_PREINIT_PATH
unset ACLOCAL_PATH
unset WindowsSDK_ExecutablePath_x64
unset SSH_AUTH_SOCK
unset SSH_ASKPASS
unset PSMODULEPATH
unset PROMPT
unset PRINTER
unset PKG_CONFIG_PATH
unset VS140COMNTOOLS
unset __VSCMD_PREINIT_INCLUDE
unset VSINSTALLDIR
unset VCIDEInstallDir
unset VS150COMNTOOLS
unset pin_run_as_build
unset HTMLHelpDir
unset FrameworkDir
unset FrameworkDIR64
unset PATH_OVERRIDE
unset INSPECTOR_XE_2016_DIR
unset INSPECTOR_XE_2013_DIR
unset INTEL_LICENSE_FILE
unset ICPP_COMPILER14
unset ICPP_COMPILER16
unset CONDA_PROMPT_MODIFIER
unset CONDA_DEFAULT_ENV
unset STDLIB_DIR
unset SCRIPTS

bazel clean --expunge
bazel shutdown

# rm -rf .bazelrc
mv .bazelrc bazelrc_old
cp -f ${RECIPE_DIR}/def_bazelrc .bazelrc
echo "" | ./configure

# Modern versions of bazel also inject user environment variables in additional
# arguments. This causes the final command line argument length to explode on
# Windows. This can be mitigated by keeping the global build matrix contents to
# the absolute minimum.
BUILD_OPTS="
--config=opt
--define=override_eigen_strong_inline=true
--define=no_tensorflow_py_deps=true
${BAZEL_MKL_OPT}"

${LIBRARY_BIN}/bazel --output_base $SRC_DIR/../bazel --batch build -c opt ${BUILD_OPTS} \
    --copt=-D_copysign="copysign" \
    --host_copt=-D_copysign="copysign" \
    --cxxopt=-D_copysign="copysign" \
    --host_cxxopt=-D_copysign="copysign" \
    //tensorflow/tools/pip_package:build_pip_package || exit $?

# xref: https://github.com/tensorflow/tensorflow/issues/21886
# xref: https://github.com/tensorflow/tensorflow/issues/6396
# While the build is running, open a shell and type the following:
# export _param_file="/c/users/$USER/_bazel_$USER/xxxxxxxx/execroot/org_tensorflow/bazel-out/x64_windows-opt/bin/tensorflow/python/_pywrap_tensorflow_internal.so-2.params"
# while true; do if [ -f $_param_file ]; then sed -i 's,^/WHOLEARCHIVE:\(.*external.*\),\1,' $_param_file;  sed -i 's,\(.*icuuc.lib\),\/WHOLEARCHIVE:\1,' $_param_file; echo done; break; fi; done
# export _param_file="/c/users/$USER/_bazel_$USER/xxxxxxxx/execroot/org_tensorflow/bazel-out/x64_windows-opt/bin/tensorflow/lite/toco/python/_tensorflow_wrap_toco.so-2.params"
# while true; do if [ -f $_param_file ]; then sed -i 's,^/WHOLEARCHIVE:\(.*external.*\),\1,' $_param_file; echo done; break; else sleep 1; fi; done

PY_TEST_DIR="${SRC_DIR}/py_test_dir"
rm -fr ${PY_TEST_DIR}
mkdir -p ${PY_TEST_DIR}
cmd //c "mklink /J $(cygpath -w ${PY_TEST_DIR})\\tensorflow) .\\tensorflow"
./bazel-bin/tensorflow/tools/pip_package/build_pip_package.exe "$(cygpath -w ${PY_TEST_DIR})"

PIP_NAME=$(ls ${PY_TEST_DIR}/tensorflow-*.whl)
# python -m pip install ${PIP_NAME} --no-deps -vv --ignore-installed
unzip ${PIP_NAME} -d $SP_DIR

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/Scripts/tensorboard.exe

# make sure we shutdown things again and are releasing locks ...
bazel clean --expunge
bazel shutdown
