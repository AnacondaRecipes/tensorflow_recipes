#!/bin/bash

set -ex

# remove files in setuptools that have spaces, these cause issues with bazel
rm -rf "${SP_DIR}/setuptools/command/launcher manifest.xml"
rm -rf "${SP_DIR}/setuptools/script (dev).tmpl"

# build using bazel
mkdir -p ./bazel_output_base
export BAZEL_OPTS="--batch"
bazel ${BAZEL_OPTS} build //tensorboard/pip_package:build_pip_package

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

chmod -R u+w,go+r .

find tensorboard -name \*.py |
  xargs $sedi -e '
    s/^import html5lib$/from tensorboard._vendor import html5lib/
    s/^from html5lib/from tensorboard._vendor.html5lib/
    s/^import bleach$/from tensorboard._vendor import bleach/
    s/^from bleach/from tensorboard._vendor.bleach/
  '
# install the package
python setup.py install --single-version-externally-managed --record record.txt

# Remove bin/tensorboard since the entry_point takes care of creating this.
rm $PREFIX/bin/tensorboard
