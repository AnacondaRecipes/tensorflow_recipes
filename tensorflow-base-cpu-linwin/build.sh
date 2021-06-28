#!/bin/bash

set -vex

# expand PREFIX in BUILD file
sed -i -e "s:\${PREFIX}:${PREFIX}:" tensorflow/core/platform/default/build_config/BUILD

mkdir -p ./bazel_output_base
export BAZEL_OPTS=""

# Compile tensorflow from source
export PYTHON_BIN_PATH=${PYTHON}
export PYTHON_LIB_PATH=${SP_DIR}
export USE_DEFAULT_PYTHON_LIB_PATH=1
# export CUDA_TOOLKIT_PATH=/usr/local/cuda-10.1

# export PATH="$CUDA_TOOLKIT_PATH/bin:$PATH"
# export LD_LIBRARY_PATH="$CUDA_TOOLKIT_PATH/lib64 $LD_LIBRARY_PATH"
# additional settings
# variant specific settings
if [ ${tflow_variant} == "mkl" ]; then
    export TF_NEED_MKL=1
    if [[ "${target_platform}" == "linux-aarch64" ]]; then
      export BAZEL_MKL_OPT="--config=mkl_aarch64"
    else
      export BAZEL_MKL_OPT="--config=mkl"
    fi
elif [ ${tflow_variant} == "onednn" ]; then
    # Source for BASE_CFLAGS: 
    # https://github.com/ARM-software/Tool-Solutions/blob/97090bf1bcfa3d928b72e8c5b0a8e5aade5097cd/docker/tensorflow-aarch64/Dockerfile#L134
    # NOTE: Hard-coding -mcpu to be "native".
    export BASE_CFLAGS="-mcpu=native  -moutline-atomics"

    # Copy additional build scripts.
    mkdir -p $PREFIX/bin
    cp $RECIPE_DIR/build-acl.sh $PREFIX/bin/
    cp $RECIPE_DIR/build-onednn.sh $PREFIX/bin/
    cp $RECIPE_DIR/patches/oneDNN.patch $PREFIX/

    # Build Arm Compute Library (ACL) from source.
    bash $PREFIX/bin/build-acl.sh
    echo "Finished building Arm Compute Library (ACL) from source."

    # Build OneDNN from source.
    bash $PREFIX/bin/build-onednn.sh
    echo "Finished building OneDNN from source."

    echo "EXITING"
    exit 0
else
    # eigen variant, do not build with MKL support
    export TF_NEED_MKL=0
    export BAZEL_MKL_OPT=""
fi

if [[ "${target_platform}" != "linux-aarch64" ]]; then
    export CC_OPT_FLAGS="-march=nocona -mtune=haswell"
    export OPT_BAZEL_FLAGS="    --copt=-march=nocona \
    --copt=-mtune=haswell"

else
    # we need to define it for configure.py's sake. we use
    # default compiler's optimization
    export CC_OPT_FLAGS="-Wno-sign-compare"
    export OPT_BAZEL_FLAG=""
fi

export TF_ENABLE_XLA=0
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_COMPUTECPP=0
export TF_NEED_ROCM=0
export TF_NEED_MPI=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_CONFIGURE_IOS=0
# CUDA details
export TF_NEED_CUDA=0
export TF_CUDA_VERSION="${cudatoolkit}"
export TF_CUDNN_VERSION="${cudnn}"
export TF_CUDA_CLANG=0
export TF_DOWNLOAD_CLANG=0
export TF_NEED_TENSORRT=0
# Additional compute capabilities can be added if desired but these increase
# the build time and size of the package.
export TF_NCCL_VERSION=""
export GCC_HOST_COMPILER_PATH="${CC}"

bazel clean --expunge
bazel shutdown

./configure

# build using bazel
# for debugging the following lines may be helpful
#   --logging=6 \
#   --subcommands \
# jobs can be used to limit parallel builds and reduce resource needs
#    --jobs=20             \
bazel ${BAZEL_OPTS} build ${BAZEL_MKL_OPT} ${OPT_BAZEL_FLAG} \
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
    --copt=-DNO_CONSTEXPR_FOR_YOU=1 \
    --host_copt=-DNO_CONSTEXPR_FOR_YOU=1 \
    --define=LIBDIR="$PREFIX/lib" \
    --define=INCLUDEDIR="$PREFIX/include" \
    //tensorflow/tools/pip_package:build_pip_package

# build a whl file
mkdir -p $SRC_DIR/tensorflow_pkg
bash -x bazel-bin/tensorflow/tools/pip_package/build_pip_package $SRC_DIR/tensorflow_pkg

# install using pip from the whl file
${PYTHON} -m pip install --no-deps $SRC_DIR/tensorflow_pkg/*.whl

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/bin/tensorboard
