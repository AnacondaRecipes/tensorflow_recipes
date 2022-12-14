#!/bin/bash

set -ex

bazel clean --expunge
bazel shutdown

export PATH="$PWD:$PATH"
export CC=$(basename $CC)
export CXX=$(basename $CXX)
export LIBDIR=$PREFIX/lib
export INCLUDEDIR=$PREFIX/include
export CC_FOR_BUILD=$CC

# expand PREFIX in tensor's build_config/BUILD file
sed -i -e "s:\${PREFIX}:${PREFIX}:" tensorflow/core/platform/default/build_config/BUILD

# variant specific settings
if [ ${tflow_variant} == "mkl" ]; then
    export TF_NEED_MKL=1
    export BAZEL_MKL_OPT="--config=mkl"
else
    # eigen variant, do not build with MKL support
    export TF_NEED_MKL=0
    export BAZEL_MKL_OPT=""
fi
echo "TF_NEED_MKL: ${TF_NEED_MKL}"
echo "BAZEL_MKL_OPT: ${BAZEL_MKL_OPT}"

mkdir -p ./bazel_output_base
export BAZEL_OPTS=""

export TF_SV_SYSTEM_LIBS="
  absl_py
  astor_archive
  astunparse_archive
  boringssl
  com_github_googlecloudplatform_google_cloud_cpp
  com_github_grpc_grpc
  com_google_protobuf
  curl
  cython
  dill_archive
  flatbuffers
  gast_archive
  gif
  icu
  libjpeg_turbo
  org_sqlite
  png
  pybind11
  snappy
  zlib
  "

sed -i -e "s/GRPCIO_VERSION/${grpc_cpp}/" tensorflow/tools/pip_package/setup.py

export CC_OPT_FLAGS="${CFLAGS}"

if [[ "${target_platform}" == osx-64 ]]; then
  export CONDA_BUILD_SYSROOT=/opt/MacOSX10.14.sdk
  export MACOSX_DEPLOYMENT_TARGET=10.14
  export LDFLAGS="${LDFLAGS} -lz -framework CoreFoundation -isysroot ${CONDA_BUILD_SYSROOT} -Xlinker -undefined -Xlinker dynamic_lookup"
else
  export CONDA_BUILD_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX13.0.sdk/
  export LDFLAGS="${LDFLAGS} -lz -framework CoreFoundation -isysroot ${CONDA_BUILD_SYSROOT} -Xlinker -undefined -Xlinker dynamic_lookup"
fi

chmod +x ${RECIPE_DIR}/gen-bazel-toolchain.sh
source ${RECIPE_DIR}/gen-bazel-toolchain.sh

# set build arguments
export  BAZEL_USE_CPP_ONLY_TOOLCHAIN=1
BUILD_OPTS="
    --crosstool_top=//custom_toolchain:toolchain
    --verbose_failures
    ${BAZEL_MKL_OPT}
    --config=opt"
export TF_ENABLE_XLA=0

if [[ "${target_platform}" == "osx-64" ]]; then
  # Tensorflow doesn't cope yet with an explicit architecture (darwin_x86_64) on osx-64 yet.
  TARGET_CPU=darwin
else
  TARGET_CPU=darwin_arm64
fi

export TF_CONFIGURE_IOS=0

# Python settings
export PYTHON_BIN_PATH=${PYTHON}
export PYTHON_LIB_PATH=${SP_DIR}
export USE_DEFAULT_PYTHON_LIB_PATH=1

# additional settings
export CC_OPT_FLAGS="${CFLAGS}"
export TF_NEED_OPENCL=0
export TF_NEED_TENSORRT=0
export TF_NCCL_VERSION=
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_COMPUTECPP=0
export TF_NEED_CUDA=0
export TF_CUDA_CLANG=0
export TF_NEED_TENSORRT=0
export TF_NEED_ROCM=0
export TF_NEED_MPI=0
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_CONFIGURE_IOS=0

# Get rid of unwanted defaults
sed -i -e "/PROTOBUF_INCLUDE_PATH/c\ " .bazelrc
sed -i -e "/PREFIX/c\ " .bazelrc

bazel clean --expunge
bazel shutdown

./configure
echo "build --config=noaws" >> .bazelrc

# build using bazel
bazel ${BAZEL_OPTS} build ${BUILD_OPTS} \
    --cpu=${TARGET_CPU} \
    --action_env="PYTHON_BIN_PATH=${PYTHON}" \
    --action_env="PYTHON_LIB_PATH=${SP_DIR}" \
    --python_path="${PYTHON}" \
    --define=PREFIX="$PREFIX" \
    --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include \
    --define=LIBDIR="$PREFIX/lib" \
    --define=INCLUDEDIR="$PREFIX/include" \
    //tensorflow/tools/pip_package:build_pip_package

# //tensorflow/tools/lib_package:libtensorflow //tensorflow:libtensorflow_cc.so

# build a whl file
mkdir -p $SRC_DIR/tensorflow_pkg
bazel-bin/tensorflow/tools/pip_package/build_pip_package $SRC_DIR/tensorflow_pkg

# install the whl using pip
${PYTHON} -m pip install --no-deps $SRC_DIR/tensorflow_pkg/*.whl

# tflow vendors libmklml.dylib and libiomp5.dylib
if [ $target_platform == osx-64 ] && [ ${tflow_variant} == "mkl" ]; then
    # https://github.com/ContinuumIO/anaconda-issues/issues/6423
    # https://github.com/JuliaPy/PyPlot.jl/issues/315
    # Also required to make the overlinking check happy
    _xternal_libmklml_dylib=$(find $SP_DIR/ -name libmklml.dylib)
    install_name_tool -change @rpath/libiomp5.dylib @loader_path/libiomp5.dylib $_xternal_libmklml_dylib
fi

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/bin/tensorboard
