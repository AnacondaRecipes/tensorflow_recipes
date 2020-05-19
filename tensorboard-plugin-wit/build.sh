#!/bin/bash

set -ex

bazel build //tensorboard_plugin_wit/pip_package:build_pip_package

# Adapted from:
# https://github.com/PAIR-code/what-if-tool/blob/v1.6.0/tensorboard_plugin_wit/pip_package/build_pip_package.sh
RUNFILES=$(pwd)/bazel-bin/tensorboard_plugin_wit/pip_package/build_pip_package.runfiles

if [ "$(uname)" = "Darwin" ]; then
      sedi="sed -i ''"
else
        sedi="sed -i"
fi

plugin_runfile_dir="${RUNFILES}/ai_google_pair_wit"

dest=tmp_pip_dir
mkdir -p ${dest}
pushd ${dest}

mkdir -p release
pushd release

rm -rf tensorboard_plugin_wit
# Copy over all necessary files from tensorboard_plugin_wit
cp -LR "$plugin_runfile_dir/tensorboard_plugin_wit" .
cp -LR "$plugin_runfile_dir/utils" .

# Move files related to pip building to pwd.
mv -f "tensorboard_plugin_wit/pip_package/README.rst" .
mv -f "tensorboard_plugin_wit/pip_package/setup.py" .

# Copy over other built resources
mkdir -p tensorboard_plugin_wit/static
mv -f "tensorboard_plugin_wit/pip_package/index.js" tensorboard_plugin_wit/static
rm -rf tensorboard_plugin_wit/pip_package
cp "$plugin_runfile_dir/wit_dashboard/wit_tb_bin.html" "$plugin_runfile_dir/wit_dashboard/wit_tb_bin.js" tensorboard_plugin_wit/static

find . -name __init__.py | xargs chmod -x  # which goes for all genfiles

# Copy interactive inference common utils over and ship it as part of the pip
# package.
mkdir -p tensorboard_plugin_wit/_utils
cp "$plugin_runfile_dir/utils/common_utils.py" tensorboard_plugin_wit/_utils
cp "$plugin_runfile_dir/utils/inference_utils.py" tensorboard_plugin_wit/_utils
cp "$plugin_runfile_dir/utils/platform_utils.py" tensorboard_plugin_wit/_utils
touch tensorboard_plugin_wit/_utils/__init__.py

mkdir -p tensorboard_plugin_wit/_vendor 
# Vendor tensorflow-serving-api because it depends directly on TensorFlow.
# TODO(jameswex): de-vendor if they're able to relax that dependency.
cp -LR "${RUNFILES}/org_tensorflow_serving_api/tensorflow_serving" tensorboard_plugin_wit/_vendor
touch tensorboard_plugin_wit/_vendor/__init__.py

# Fix the import statements to reflect the copied over path.
find tensorboard_plugin_wit -name \*.py |
  xargs $sedi -e '
      s/^from utils/from tensorboard_plugin_wit._utils/
      s/from tensorflow_serving/from tensorboard_plugin_wit._vendor.tensorflow_serving/
     '

# install the package
python -m pip install . --no-deps --ignore-installed -vvv
