#!/bin/bash

set -vex

# expand PREFIX in tensor's build_config/BUILD file
sed -i -e "s:\${PREFIX}:${PREFIX}:" \
    tensorflow/core/platform/default/build_config/BUILD

###############################################################################
# Set defaults
###############################################################################

export MSYS2_ARG_CONV="*"
export MSYS_NO_PATHCONV=1

# Bazel settings
export BAZEL_MKL_OPT=""
export BAZEL_CUDA_OPT=""

# Compile tensorflow from source
export PYTHON_BIN_PATH=${PYTHON}
export PYTHON_LIB_PATH=${SP_DIR}
export USE_DEFAULT_PYTHON_LIB_PATH=1

# Tensorflow settings
export TF_CONFIGURE_IOS=0
export TF_CUDA_CLANG=0
export TF_CUDA_VERSION=${cudatoolkit}
export TF_CUDNN_VERSION=${cudnn:0:1}
export TF_DOWNLOAD_CLANG=0
export TF_ENABLE_XLA=0
export TF_NEED_CLANG=0
export TF_NEED_COMPUTECPP=0
export TF_NEED_CUDA=0
export TF_NEED_GCP=1
export TF_NEED_HDFS=0
export TF_NEED_KAFKA=0
export TF_NEED_MKL=0
export TF_NEED_MPI=0
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_ROCM=0
export TF_NEED_TENSORRT=0
export TF_NEED_VERBS=0

export TF_SET_ANDROID_WORKSPACE=0

###############################################################################
# Override per variant
###############################################################################

case "${tflow_variant}" in
    gpu)
        export BAZEL_CUDA_OPT="--config=cuda"
        export CUDA_TOOLKIT_PATH="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v${cudatoolkit}"
        export TF_ENABLE_XLA=1
        export TF_NEED_CUDA=1

        case "${cudatoolkit}" in
            9.0)
                export TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0"
                ;;
            9.2)
                export TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0"
                ;;
            10.*)
                export TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0,7.5"
                ;;
            11.*)
                export TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0,7.5,8.0"
                ;;
        esac

        export CUDNN_INSTALL_PATH=$(cygpath -m "$LIBRARY_PREFIX")
        export TF_CUDA_PATHS="${CUDA_TOOLKIT_PATH}"

        export PATH="/c/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v${cudatoolkit}/bin:$PATH"
        export PATH="/c/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v${cudatoolkit}/extras/CUPTI/libx64:$PATH"
        ;;
    mkl)
        export TF_NEED_MKL=1
        export BAZEL_MKL_OPT="--config=mkl"
        ;;
esac

###############################################################################
# CONFIGURE
###############################################################################

bazel clean --expunge
bazel shutdown

# rm -rf .bazelrc
mv .bazelrc bazelrc_old
cp -f ${RECIPE_DIR}/def_bazelrc .bazelrc
echo "" | ./configure

###############################################################################
# BUILD
###############################################################################

# IMPORTANT
#
# Right here, you need to cleanse the environment. Bazel will pass the complete
# environment through via the command line and exceed the maximum command line
# length on Windows.
#
# * Use `unset` to remove all unnecessary entries from the environment.
#
# * Shorten the PATH. You need to do that in the shell from which you are
#   calling your build, before invoking `conda build`.

cp $RECIPE_DIR/vile_hack.sh ./
bash vile_hack.sh &
VILE_HACK_PID=$!

trap "kill $VILE_HACK_PID" EXIT

# build using bazel
# for debugging the following lines may be helpful
#   --logging=6 \
#   --subcommands \
# jobs can be used to limit parallel builds and reduce resource needs
#    --jobs=20             \
${LIBRARY_BIN}/bazel build ${BAZEL_MKL_OPT} ${BAZEL_CUDA_OPT} \
    --define=no_tensorflow_py_deps=true
    --output_base "$SRC_DIR/../bazel" \
    --batch build \
    --verbose_failures \
    --config=opt \
    --copt=-D_copysign="copysign" \
    --host_copt=-D_copysign="copysign" \
    --cxxopt=-D_copysign="copysign" \
    --host_cxxopt=-D_copysign="copysign" \
    --copt=-DNO_CONSTEXPR_FOR_YOU=1 \
    --host_copt=-DNO_CONSTEXPR_FOR_YOU=1 \
    --python_path="${PYTHON}" \
    --action_env="PYTHON_BIN_PATH=${PYTHON}" \
    --action_env="PYTHON_LIB_PATH=${SP_DIR}" \
    --linkopt="-L$LIBRARY_PREFIX" \
    --python_path="${PYTHON}" \
    --strip=always \
    //tensorflow/tools/pip_package:build_pip_package

PY_TEST_DIR="${SRC_DIR}/py_test_dir"

rm    -fr "${PY_TEST_DIR}"
mkdir -p  "${PY_TEST_DIR}"

cmd //c "mklink /J $(cygpath -w ${PY_TEST_DIR})\\tensorflow) .\\tensorflow"

./bazel-bin/tensorflow/tools/pip_package/build_pip_package.exe \
    "$(cygpath -w ${PY_TEST_DIR})"

unzip "$(ls ${PY_TEST_DIR}/tensorflow-*.whl)" -d "$SP_DIR"

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/Scripts/tensorboard.exe

# make sure we shutdown things again and are releasing locks ...
bazel clean --expunge
bazel shutdown
