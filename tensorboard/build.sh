#!/bin/bash

set -ex

# remove files in setuptools that have spaces, these cause issues with bazel
rm -rf "${SP_DIR}/setuptools/command/launcher manifest.xml"
rm -rf "${SP_DIR}/setuptools/script (dev).tmpl"

export PYTHON_BIN_PATH="$PYTHON"
export PYTHON_LIB_PATH="$SP_DIR"

# forcing bazel to use our python - scattershot floundering
# https://github.com/bazelbuild/bazel/issues/7101
# https://github.com/bazelbuild/bazel/issues/6473
# https://github.com/bazelbuild/bazel/issues/4643
# https://github.com/bazelbuild/bazel/issues/7026
cat <<EOF >> .bazelrc
build --announce_rc
build --noincompatible_strict_action_env
build --distinct_host_configuration=false
build --action_env=PATH="$PATH"
build --action_env=PYTHON_BIN_PATH="$PYTHON_BIN_PATH"
build --action_env=PYTHON_LIB_PATH="$PYTHON_LIB_PATH"
build --action_env=PREFIX="$PREFIX"
build --python_path="$PYTHON"
build --java_toolchain=@bazel_tools//tools/jdk:toolchain_hostjdk8
EOF

# rm .bazelrc
# cat <<EOF > .bazelrc
# build --announce_rc
# build --noincompatible_strict_action_env
# build --incompatible_use_python_toolchains=false
# build --action_env=PATH="$PATH"
# build --action_env=PYTHON_BIN_PATH="$PYTHON"
# build --action_env=PYTHON_LIB_PATH="$SP_DIR"
# build --action_env=PREFIX="$PREFIX"
# build --python_path="$PYTHON"
# build --distinct_host_configuration=false
# EOF

# build using bazel
mkdir -p ./bazel_output_base
BAZEL_OPTS=""
BUILD_OPTS=""
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
    BUILD_OPTS="$BUILD_OPTS --crosstool_top=//custom_clang_toolchain:toolchain"
fi
bazel ${BAZEL_OPTS} build ${BUILD_OPTS:-} //tensorboard/pip_package:build_pip_package

# Adapted from: https://github.com/tensorflow/tensorboard/blob/1.9.0/tensorboard/pip_package/build_pip_package.sh
if [ "$(uname)" = "Darwin" ]; then
  sedi="sed -i ''"
else
  sedi="sed -i"
fi

TMPDIR=tmp_pip_dir
mkdir -p ${TMPDIR}
RUNFILES=$(pwd)/bazel-bin/tensorboard/pip_package/build_pip_package.runfiles

pushd ${TMPDIR}

cp -LR "${RUNFILES}/org_tensorflow_tensorboard/tensorboard" .
mv -f "tensorboard/pip_package/LICENSE" .
mv -f "tensorboard/pip_package/MANIFEST.in" .
mv -f "tensorboard/pip_package/README.rst" .
mv -f "tensorboard/pip_package/setup.cfg" .
mv -f "tensorboard/pip_package/setup.py" .
rm -rf tensorboard/pip_package

rm -f tensorboard/tensorboard              # bazel py_binary sh wrapper
chmod -x LICENSE                           # bazel symlinks confuse cp
find . -name __init__.py | xargs chmod -x  # which goes for all genfiles

mkdir -p tensorboard/_vendor
touch tensorboard/_vendor/__init__.py
cp -LR "${RUNFILES}/org_html5lib/html5lib" tensorboard/_vendor
cp -LR "${RUNFILES}/org_mozilla_bleach/bleach" tensorboard/_vendor
cp -LR "${RUNFILES}/org_tensorflow_serving_api/tensorflow_serving" tensorboard/_vendor

chmod -R u+w,go+r .

find tensorboard -name \*.py |
  xargs $sedi -e '
    s/^import html5lib$/from tensorboard._vendor import html5lib/
    s/^from html5lib/from tensorboard._vendor.html5lib/
    s/^import bleach$/from tensorboard._vendor import bleach/
    s/^from bleach/from tensorboard._vendor.bleach/
    s/from tensorflow_serving/from tensorboard._vendor.tensorflow_serving/
  '
# install the package
python -m pip install . --no-deps --ignore-installed -vvv

# Remove bin/tensorboard since the entry_point takes care of creating this.
rm $PREFIX/bin/tensorboard
