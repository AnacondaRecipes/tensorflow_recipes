#!/bin/bash

set -ex

# bazel requires that $CC be set
export CC="/bin/echo"

# build the wheel
mkdir -p ./whl_temp
WHL_TMP=./whl_temp
bazel build //tensorflow_estimator/tools/pip_package:build_pip_package
bazel-bin/tensorflow_estimator/tools/pip_package/build_pip_package ${WHL_TMP}

# install the wheel
pip install --no-deps ${WHL_TMP}/*.whl
