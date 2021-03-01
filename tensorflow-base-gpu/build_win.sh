#!/bin/bash

set -x

error_exit()
{
    kill $1
    if [ "$?" != "0" ]; then
        exit 1
    fi
}

# expand PREFIX in tensor's build_config/BUILD file
sed -i -e "s:\${PREFIX}:${PREFIX}:" tensorflow/core/platform/default/build_config/BUILD

export PYTHON_BIN_PATH="$PYTHON"
export PYTHON_LIB_PATH="$SP_DIR"

export TF_NEED_CUDA=1
export TF_CUDA_CLANG=0
export TF_ENABLE_XLA=1
export TF_NEED_MKL=0
export TF_NEED_VERBS=0
export TF_NEED_GCP=1
export TF_NEED_KAFKA=0
export TF_NEED_OPENCL=0
export TF_NEED_HDFS=0
export TF_NEED_OPENCL_SYCL=0

export USE_MSVC_WRAPPER=1
export TF_CUDA_VERSION=${cudatoolkit}
export CUDA_TOOLKIT_PATH="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v${cudatoolkit}"
export CUDNN_INSTALL_PATH=$(cygpath -m "$LIBRARY_PREFIX")
export TF_CUDNN_VERSION=${cudnn}

export PATH="/c/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v${cudatoolkit}/bin:$PATH"
export PATH="/c/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v${cudatoolkit}/extras/CUPTI/libx64:$PATH"

export TF_CUDA_COMPUTE_CAPABILITIES="3.0,3.5,5.2"
if [ ${cudatoolkit} == "8.0" ]; then
    export TF_CUDA_COMPUTE_CAPABILITIES="3.0,3.5,5.2,6.0,6.1"
fi
if [ ${cudatoolkit} == "9.0" ]; then
    export TF_CUDA_COMPUTE_CAPABILITIES="3.0,3.5,5.2,6.0,6.1,7.0"
fi
if [[ ${cudatoolkit} == 10.* ]]; then
    export TF_CUDA_COMPUTE_CAPABILITIES="3.0,3.5,5.2,6.0,6.1,7.0,7.5"
fi

export TF_NEED_CLANG=0
export TF_NEED_ROCM=0
export TF_NEED_TENSORRT=0
export TF_ANDROID_WORKSPACE=0
export TF_DOWNLOAD_CLANG=0
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
unset HOME
unset ICPP_COMPILER19
unset IFORT_COMPILER14
unset IFORT_COMPILER16
unset IFORT_COMPILER19
unset INFOPATH
unset INSPECTOR_2019_DIR
unset INTEL_DEV_REDIST
unset LIBRARY_LIB
unset LIBRARY_INC
unset LIBRARY_PREFIX

bazel clean --expunge
bazel shutdown

mv .bazelrc bazelrc_old
cp -f ${RECIPE_DIR}/def_bazelrc .bazelrc
echo "" | ./configure

cp $RECIPE_DIR/vile_hack.sh ./
bash vile_hack.sh &
pid=$!

BUILD_OPTS="--logging=6 --subcommands --define=override_eigen_strong_inline=true --experimental_shortened_obj_file_path=true --define=no_tensorflow_py_deps=true"
${LIBRARY_BIN}/bazel --output_base $SRC_DIR/../bazel --batch build -c opt $BUILD_OPTS \
  --action_env="PYTHON_BIN_PATH=${PYTHON}" \
  --action_env="PYTHON_LIB_PATH=${SP_DIR}" \
  --python_path="${PYTHON}" \
  --copt=-DNO_CONSTEXPR_FOR_YOU=1 \
  --host_copt=-DNO_CONSTEXPR_FOR_YOU=1 \
  //tensorflow/tools/pip_package:build_pip_package || exit $?
error_exit $pid

PY_TEST_DIR="$SRC_DIR/py_test_dir"
rm -fr ${PY_TEST_DIR}
mkdir -p ${PY_TEST_DIR}
cmd /c "mklink /J $(cygpath -w ${PY_TEST_DIR})\\tensorflow .\\tensorflow"

./bazel-bin/tensorflow/tools/pip_package/build_pip_package "$(cygpath -w ${PY_TEST_DIR})"

PIP_NAME=$(ls ${PY_TEST_DIR}/tensorflow-*.whl)
# python -m pip install ${PIP_NAME} --no-deps -vv --ignore-installed
unzip ${PIP_NAME} -d $SP_DIR

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/Scripts/tensorboard.exe
