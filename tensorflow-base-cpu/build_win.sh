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

export PYTHON_BIN_PATH="$PYTHON"
export PYTHON_LIB_PATH="$SP_DIR"

export TF_NEED_CUDA=0
export TF_ENABLE_XLA=0
export TF_NEED_VERBS=0
export TF_NEED_GCP=1
export TF_NEED_KAFKA=0
export TF_NEED_HDFS=0
export TF_NEED_OPENCL_SYCL=0
echo "" | ./configure

BUILD_OPTS="--define=override_eigen_strong_inline=true --experimental_shortened_obj_file_path=true ${BAZEL_MKL_OPT}"
${LIBRARY_BIN}/bazel --batch build -c opt $BUILD_OPTS tensorflow/tools/pip_package:build_pip_package || exit $?

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
KNOWN_FAIL="-${PY_TEST_DIR}/tensorflow/python/kernel_tests/boosted_trees:training_ops_test \
	-${PY_TEST_DIR}/tensorflow/python/kernel_tests/distributions:dirichlet_multinomial_test"

${LIBRARY_BIN}/bazel --batch test -c opt $BUILD_OPTS -k --test_output=errors \
  --define=no_tensorflow_py_deps=true --test_lang_filters=py \
  --build_tag_filters=-no_pip,-no_windows,-no_oss --build_tests_only \
  --test_timeout 9999999 --test_tag_filters=-no_pip,-no_windows,-no_oss \
  -- //${PY_TEST_DIR}/tensorflow/python/... \
     //${PY_TEST_DIR}/tensorflow/contrib/... \
     ${KNOWN_FAIL}
