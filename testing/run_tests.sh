bazel clean

export PYTHON_BIN_PATH="$(which python)"
export PYTHON_LIB_PATH="$(python -c 'import site; print(site.getsitepackages()[0])')"
export USE_DEFAULT_PYTHON_LIB_PATH=1

export CC_OPT_FLAGS="-march=nocona -mtune=haswell"
export TF_ENABLE_XLA=1
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_CUDA=0
export TF_NEED_ROCM=0
export TF_NEED_MPI=0
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0

${PYTHON_BIN_PATH} configure.py

PIP_TEST_PREFIX=bazel_pip
PIP_TEST_ROOT=$(pwd)/${PIP_TEST_PREFIX}
rm -rf $PIP_TEST_ROOT
mkdir -p $PIP_TEST_ROOT
ln -s $(pwd)/tensorflow ${PIP_TEST_ROOT}/tensorflow

PIP_TEST_FILTER_TAG="-no_pip,-no_oss,-oss_serial,-benchmark-test"
BAZEL_FLAGS="--define=no_tensorflow_py_deps=true --test_lang_filters=py \
      --build_tests_only -k --test_tag_filters=${PIP_TEST_FILTER_TAG} \
      --test_timeout 9999999"
BAZEL_TEST_TARGETS="${PIP_TEST_PREFIX}/tensorflow/python/..."
BAZEL_PARALLEL_TEST_FLAGS="--local_test_jobs=$(grep -c ^processor /proc/cpuinfo)"
bazel test ${BAZEL_FLAGS} ${BAZEL_PARALLEL_TEST_FLAGS} -- ${BAZEL_TEST_TARGETS}
