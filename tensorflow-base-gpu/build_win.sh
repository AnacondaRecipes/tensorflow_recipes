#!/bin/bash

set -ex

export PYTHON_BIN_PATH="$PYTHON"
export PYTHON_LIB_PATH="$SP_DIR"

export TF_NEED_CUDA=1
export TF_ENABLE_XLA=0
export TF_NEED_MKL=0
export TF_NEED_VERBS=0
export TF_NEED_GCP=1
export TF_NEED_KAFKA=0
export TF_NEED_HDFS=0
export TF_NEED_OPENCL_SYCL=0

export USE_MSVC_WRAPPER=1
export TF_CUDA_VERSION=${cudatoolkit}
export CUDA_TOOLKIT_PATH="C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v${cudatoolkit}"
export CUDNN_INSTALL_PATH="$LIBRARY_PREFIX"
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

echo "" | ./configure

BUILD_OPTS="--logging=6 --subcommands --define=override_eigen_strong_inline=true --experimental_shortened_obj_file_path=true"
${LIBRARY_BIN}/bazel --batch build -c opt $BUILD_OPTS tensorflow/tools/pip_package:build_pip_package || exit $?

# xref: https://github.com/tensorflow/tensorflow/issues/20332#issuecomment-415974623
# Run the following in another shell as the build proceeds (replace $USER and xxxxxxxx):
# export _param_file="/c/users/$USER/_bazel_$USER/xxxxxxxx/execroot/org_tensorflow/bazel-out/x64_windows-opt/bin/tensorflow/tools/pip_package/simple_console_for_windows.zip-2.params" 
# while true; do if [ -f $_param__file ]; then sed -i '/zip=/d' $_param_file; echo done; break; else sleep 1; fi; done

PY_TEST_DIR="py_test_dir"
rm -fr ${PY_TEST_DIR}
mkdir -p ${PY_TEST_DIR}
cmd /c "mklink /J ${PY_TEST_DIR}\\tensorflow .\\tensorflow"

./bazel-bin/tensorflow/tools/pip_package/build_pip_package "$PWD/${PY_TEST_DIR}"

PIP_NAME=$(ls ${PY_TEST_DIR}/tensorflow-*.whl)
pip install ${PIP_NAME} --no-deps

# The tensorboard package has the proper entrypoint
rm -f ${PREFIX}/Scripts/tensorboard.exe

# Test which are known to fail and do not effect the package
#KNOWN_FAIL="-${PY_TEST_DIR}/tensorflow/python/estimator:boosted_trees_test"
#
#${LIBRARY_BIN}/bazel --batch test -c opt ${BUILD_OPTS} -k --test_output=errors --flaky_test_attempts=3 \
#   --define=no_tensorflow_py_deps=true --test_lang_filters=py --local_test_jobs=1 \
#   --build_tag_filters=-no_pip,-no_windows,-no_windows_gpu,-no_gpu,-no_pip_gpu,-no_oss --build_tests_only \
#   --test_timeout 9999999 --test_tag_filters=-no_pip,-no_windows,-no_windows_gpu,-no_gpu,-no_pip_gpu,-no_oss \
#   -- //${PY_TEST_DIR}/tensorflow/python/... \
#      //${PY_TEST_DIR}/tensorflow/contrib/... \
#      ${KNOWN_FAIL}
