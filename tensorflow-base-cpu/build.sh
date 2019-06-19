#!/bin/bash

set -ex

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

    # set up bazel config file for conda provided clang toolchain
    cp -r ${RECIPE_DIR}/custom_clang_toolchain .
    cd custom_clang_toolchain
    sed -e "s:\${CLANG}:${CLANG}:" \
        -e "s:\${INSTALL_NAME_TOOL}:${INSTALL_NAME_TOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        cc_wrapper.sh.template > cc_wrapper.sh
    chmod +x cc_wrapper.sh
    sed -e "s:\${PREFIX}:${BUILD_PREFIX}:" \
        -e "s:\${LD}:${LD}:" \
        -e "s:\${NM}:${NM}:" \
        -e "s:\${STRIP}:${STRIP}:" \
        -e "s:\${LIBTOOL}:${LIBTOOL}:" \
        -e "s:\${CONDA_BUILD_SYSROOT}:${CONDA_BUILD_SYSROOT}:" \
        CROSSTOOL.template > CROSSTOOL
    cd ..

    # set build arguments
    export  BAZEL_USE_CPP_ONLY_TOOLCHAIN=1
    BUILD_OPTS="
        --crosstool_top=//custom_clang_toolchain:toolchain
        --verbose_failures
        ${BAZEL_MKL_OPT}
        --config=opt"
    export TF_ENABLE_XLA=0
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
bazel ${BAZEL_OPTS} build ${BUILD_OPTS} //tensorflow/tools/pip_package:build_pip_package

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

# Run unit tests on the pip installation
# Logic here is based off run_pip_tests.sh in the tensorflow repo
# https://github.com/tensorflow/tensorflow/blob/v1.1.0/tensorflow/tools/ci_build/builds/run_pip_tests.sh
# Note that not all tensorflow tests are run here, only python specific

# tests neeed to be moved into a sub-directory to prevent python from picking
# up the local tensorflow directory
PIP_TEST_PREFIX=bazel_pip
PIP_TEST_ROOT=$(pwd)/${PIP_TEST_PREFIX}
rm -rf $PIP_TEST_ROOT
mkdir -p $PIP_TEST_ROOT
ln -s $(pwd)/tensorflow ${PIP_TEST_ROOT}/tensorflow

# Test which are known to fail and do not effect the package
KNOWN_FAIL=""
PIP_TEST_FILTER_TAG="-no_pip,-no_oss,-oss_serial"
BAZEL_FLAGS="--define=no_tensorflow_py_deps=true --test_lang_filters=py \
      --build_tests_only -k --test_tag_filters=${PIP_TEST_FILTER_TAG} \
      --test_timeout 9999999"
BAZEL_TEST_TARGETS="${PIP_TEST_PREFIX}/tensorflow/contrib/... \
    ${PIP_TEST_PREFIX}/tensorflow/python/... \
     -//${PIP_TEST_PREFIX}/tensorflow/contrib/tensorboard/..."
BAZEL_PARALLEL_TEST_FLAGS="--local_test_jobs=${CPU_COUNT}"
if [ "${CPU_COUNT}" -gt 20 ]; then
    BAZEL_PARALLEL_TEST_FLAGS="--local_test_jobs=20"
fi
# to reduce build time on worker skip tests, run when testing
#bazel ${BAZEL_OPTS} test ${BAZEL_FLAGS} \
#    ${BAZEL_PARALLEL_TEST_FLAGS} -- ${BAZEL_TEST_TARGETS} ${KNOWN_FAIL}
