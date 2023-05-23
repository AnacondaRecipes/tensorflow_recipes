#!/bin/bash

set -vex

# expand PREFIX in tensor's build_config/BUILD file
sed -i -e "s:\${PREFIX}:${PREFIX}:" \
    tensorflow/tsl/platform/default/build_config/BUILD

###############################################################################
# Set defaults
###############################################################################

# Bazel settings
export BAZEL_MKL_OPT=""
export BAZEL_CUDA_OPT=""
export BAZEL_OPT_FLAG=""

# Compile tensorflow from source
export PYTHON_BIN_PATH=${PYTHON}
export PYTHON_LIB_PATH=${SP_DIR}
export USE_DEFAULT_PYTHON_LIB_PATH=1

# Tensorflow settings
export TF_CONFIGURE_IOS=0
export TF_CUDA_CLANG=0
export TF_CUDA_VERSION="${cudatoolkit}"
export TF_CUDNN_VERSION="${cudnn:0:1}"
export TF_DOWNLOAD_CLANG=0
export TF_ENABLE_XLA=1
export TF_NCCL_VERSION=""
export TF_NEED_COMPUTECPP=0
export TF_NEED_CUDA=0
export TF_NEED_MKL=0
export TF_NEED_MPI=0
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_ROCM=0
export TF_NEED_TENSORRT=0

export TF_SET_ANDROID_WORKSPACE=0

# Make build use our compilers
export CC="${HOST}-gcc"
export GCC_HOST_COMPILER_PREFIX="${BUILD_PREFIX}/bin"
export GCC_HOST_COMPILER_PATH="$(which ${CC})"

###############################################################################
# Override per variant
###############################################################################

case "${tflow_variant}" in
    gpu)
        export BAZEL_CUDA_OPT="--config=cuda"
        export CUDA_TOOLKIT_PATH="/usr/local/cuda-${cudatoolkit}"
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

        # Use system paths here rather than $PREFIX to allow Bazel to find the
        # correct libraries. RPATH is adjusted post build to link to the DSOs
        # in $PREFIX
        export TF_CUDA_PATHS="${PREFIX},/usr/local/cuda-${cudatoolkit},/usr"
        ;;
    mkl)
        export TF_NEED_MKL=1

        case "${target_platform}" in
            linux-aarch64)
                export BAZEL_MKL_OPT="--config=mkl_aarch64"
                ;;
            *)
                export BAZEL_MKL_OPT="--config=mkl"
                ;;
        esac
        ;;
esac

###############################################################################
# Architecture specific settings
###############################################################################

case "${target_platform}" in
    linux-64)
        export CC_OPT_FLAGS="-march=nocona -mtune=haswell"
        export BAZEL_OPT_FLAGS="--copt=-march=nocona --copt=-mtune=haswell"
        ;;
    *)
        export CC_OPT_FLAGS="-Wno-sign-compare"
        ;;
esac

###############################################################################
# CONFIGURE
###############################################################################

# Make our tools available under their short names
for TOOL in ar gcc g++ ld strip; do
    if [ ! -e "${BUILD_PREFIX}/bin/${TOOL}" ]; then
        ln -s "${HOST}-${TOOL}" "${BUILD_PREFIX}/bin/${TOOL}"
    fi
done

bazel clean --expunge
bazel shutdown

./configure

###############################################################################
# BUILD
###############################################################################

# build using bazel
# for debugging the following lines may be helpful
#   --logging=6 \
#   --subcommands \
# jobs can be used to limit parallel builds and reduce resource needs
#    --jobs=20             \
bazel build ${BAZEL_MKL_OPT} ${BAZEL_CUDA_OPT} ${BAZEL_OPT_FLAG} \
    --copt=-ftree-vectorize \
    --copt=-fPIC \
    --copt=-fstack-protector-strong \
    --copt=-O2 \
    --cxxopt=-fvisibility-inlines-hidden \
    --cxxopt=-fmessage-length=0 \
    --linkopt=-zrelro \
    --linkopt=-znow \
    --linkopt="-L${PREFIX}/lib" \
    --verbose_failures \
    --config=opt \
    --strip=always \
    --color=yes \
    --curses=no \
    --action_env="PYTHON_BIN_PATH=${PYTHON}" \
    --action_env="PYTHON_LIB_PATH=${SP_DIR}" \
    --python_path="${PYTHON}" \
    --define=PREFIX="$PREFIX" \
    --define=LIBDIR="$PREFIX/lib" \
    --define=INCLUDEDIR="$PREFIX/include" \
    //tensorflow/tools/pip_package:build_pip_package

# Build a whl file
mkdir -p $SRC_DIR/tensorflow_pkg
bash -x bazel-bin/tensorflow/tools/pip_package/build_pip_package $SRC_DIR/tensorflow_pkg

# Install using pip from the whl file
${PYTHON} -m pip install --no-deps $SRC_DIR/tensorflow_pkg/*.whl

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/bin/tensorboard

# make sure we shutdown things again and are releasing locks ...
bazel clean --expunge
bazel shutdown
