#!/bin/bash

set -vex

# expand PREFIX in BUILD file
sed -i -e "s:\${PREFIX}:${PREFIX}:" tensorflow/core/platform/default/build_config/BUILD

mkdir -p ./bazel_output_base
export BAZEL_OPTS=""

# cp ${RECIPE_DIR}/lin_bazelrc .bazelrc
# Compile tensorflow from source
export PYTHON_BIN_PATH=${PYTHON}
export PYTHON_LIB_PATH=${SP_DIR}
export USE_DEFAULT_PYTHON_LIB_PATH=1
export CUDA_TOOLKIT_PATH=/usr/local/cuda-10.1

# export PATH="$CUDA_TOOLKIT_PATH/bin:$PATH"
# export LD_LIBRARY_PATH="$CUDA_TOOLKIT_PATH/lib64 $LD_LIBRARY_PATH"
# additional settings
# do not build with MKL support
export TF_NEED_MKL=0
export CC_OPT_FLAGS="-march=nocona -mtune=haswell"
export TF_ENABLE_XLA=1
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_COMPUTECPP=0
export TF_NEED_COMPUTECPP=0
export TF_NEED_ROCM=0
export TF_NEED_MPI=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_CONFIGURE_IOS=0
# CUDA details
export TF_NEED_CUDA=1
export TF_CUDA_VERSION="${cudatoolkit}"
export TF_CUDNN_VERSION="${cudnn}"
export TF_CUDA_CLANG=0
export TF_DOWNLOAD_CLANG=0
export TF_NEED_TENSORRT=0
# Additional compute capabilities can be added if desired but these increase
# the build time and size of the package.
if [ ${cudatoolkit} == "9.0" ]; then
    export TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0"
fi
if [ ${cudatoolkit} == "9.2" ]; then
    export TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0"
fi
if [[ ${cudatoolkit} == 10.* ]]; then
    export TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0,7.5"
fi
export TF_NCCL_VERSION=""
export GCC_HOST_COMPILER_PATH="${CC}"
# Use system paths here rather than $PREFIX to allow Bazel to find the correct
# libraries.  RPATH is adjusted post build to link to the DSOs in $PREFIX
export TF_CUDA_PATHS="${PREFIX},/usr/local/cuda-10.1,/usr"

bazel clean --expunge
bazel shutdown

./configure

# build using bazel
# for debugging the following lines may be helpful
#   --logging=6 \
#   --subcommands \
# jobs can be used to limit parallel builds and reduce resource needs
#    --jobs=20             \
bazel ${BAZEL_OPTS} build \
    --copt=-march=nocona \
    --copt=-mtune=haswell \
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
    --config=cuda \
    --strip=always \
    --color=yes \
    --curses=no \
    --action_env="PYTHON_BIN_PATH=${PYTHON}" \
    --action_env="PYTHON_LIB_PATH=${SP_DIR}" \
    --python_path="${PYTHON}" \
    --define=PREFIX="$PREFIX" \
    --copt=-DNO_CONSTEXPR_FOR_YOU=1 \
    --host_copt=-DNO_CONSTEXPR_FOR_YOU=1 \
    --define=LIBDIR="$PREFIX/lib" \
    --define=INCLUDEDIR="$PREFIX/include" \
    //tensorflow/tools/pip_package:build_pip_package

# build a whl file
mkdir -p $SRC_DIR/tensorflow_pkg
bazel-bin/tensorflow/tools/pip_package/build_pip_package $SRC_DIR/tensorflow_pkg

# install using pip from the whl file
pip install --no-deps $SRC_DIR/tensorflow_pkg/*.whl

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/bin/tensorboard
