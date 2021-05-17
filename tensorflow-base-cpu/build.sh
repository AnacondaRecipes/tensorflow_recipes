#!/bin/bash

set -ex

bazel clean --expunge
bazel shutdown

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

if [[ ${HOST} =~ .*darwin.* ]]; then
#  export CC=clang
#  export CXX=clang++
# export PATH="$PWD:$PATH"
# export CC=$(basename $CC)
# export CXX=$(basename $CXX)
# export LIBDIR=$PREFIX/lib
# export INCLUDEDIR=$PREFIX/include
#    export PATH="$PREFIX/lib:$PATH"
    export GCC_HOST_COMPILER_PATH="${CC}"
    export CONDA_BUILD_SYSROOT=/opt/MacOSX10.14.sdk
    # set up bazel config file for conda provided clang toolchain
    cp -r ${RECIPE_DIR}/custom_clang_toolchain .
    cd custom_clang_toolchain
    sed -e "s:\${CLANG}:${CLANG}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        -e "s:\${MACOSX_DEPLOYMENT_TARGET}:${MACOSX_DEPLOYMENT_TARGET}:" \
        -e "s:\${LDFLAGS}:${LDFLAGS}:" \
        -e "s:\${CXXFLAGS}:${CFLAGS}:" \
        -e "s:\${PREFIX}:${PREFIX}:" \
        -e "s:\${LIBTOOL}:${LIBTOOL}:" \
        -e "s:\${PY_VER}:${PY_VER}:" \
        cc_wrapper.sh.template > cc_wrapper.sh
    chmod +x cc_wrapper.sh
     sed -e "s:\${PREFIX}:${BUILD_PREFIX}:" \
        -e "s:\${LD}:${LD}:" \
        -e "s:\${NM}:${NM}:" \
        -e "s:\${STRIP}:${STRIP}:" \
        -e "s:\${LIBTOOL}:${LIBTOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        CROSSTOOL.template > CROSSTOOL
    sed -i "" "s:\${PREFIX}:${PREFIX}:" cc_toolchain_config.bzl
    sed -i "" "s:\${BUILD_PREFIX}:${BUILD_PREFIX}:" cc_toolchain_config.bzl
    sed -i "" "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" cc_toolchain_config.bzl
    sed -i "" "s:\${LD}:${LD}:" cc_toolchain_config.bzl
    sed -i "" "s:\${NM}:${NM}:" cc_toolchain_config.bzl
    sed -i "" "s:\${STRIP}:${STRIP}:" cc_toolchain_config.bzl
    sed -i "" "s:\${LIBTOOL}:${LIBTOOL}:" cc_toolchain_config.bzl
    cd ..
    set
    # set build arguments
    export  BAZEL_USE_CPP_ONLY_TOOLCHAIN=1
    BUILD_OPTS="
        --crosstool_top=//custom_clang_toolchain:toolchain
        --verbose_failures
        ${BAZEL_MKL_OPT}
        --config=opt"
    export TF_ENABLE_XLA=1
else
    # Linux
    # the following arguments are useful for debugging
    #    --logging=6
    #    --subcommands
    # jobs can be used to limit parallel builds and reduce resource needs
    #    --jobs=20
    # Set compiler and linker flags as bazel does not account for CFLAGS,
    # CXXFLAGS and LDFLAGS.
    BUILD_OPTS="
    --copt=-march=nocona
    --copt=-mtune=haswell
    --copt=-ftree-vectorize
    --copt=-fPIC
    --copt=-fstack-protector-strong
    --copt=-O2
    --cxxopt=-fvisibility-inlines-hidden
    --cxxopt=-fmessage-length=0
    --linkopt=-zrelro
    --linkopt=-znow
    --verbose_failures
    ${BAZEL_MKL_OPT}
    --config=opt"
    export TF_ENABLE_XLA=1
fi

export TF_CONFIGURE_IOS=0

if [[ ${HOST} =~ "2*" ]]; then
    BUILD_OPTS="$BUILD_OPTS --config=v2"
fi

# Python settings
export PYTHON_BIN_PATH=${PYTHON}
export PYTHON_LIB_PATH=${SP_DIR}
export USE_DEFAULT_PYTHON_LIB_PATH=1

# additional settings
export CC_OPT_FLAGS="-march=nocona -mtune=haswell"
export TF_NEED_OPENCL=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_COMPUTECPP=0
export TF_NEED_CUDA=0
export TF_CUDA_CLANG=0
export TF_NEED_TENSORRT=0
export TF_NEED_ROCM=0
export TF_NEED_MPI=0
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0
./configure

# build using bazel
bazel ${BAZEL_OPTS} build ${BUILD_OPTS} \
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

# install the whl using pip
pip install --no-deps $SRC_DIR/tensorflow_pkg/*.whl

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
