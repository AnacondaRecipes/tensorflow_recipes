#!/bin/bash

# xref: https://github.com/tensorflow/tensorflow/issues/21886
# xref: https://github.com/tensorflow/tensorflow/issues/6396
execroot=$SRC_DIR/../bazel/execroot/org_tensorflow/bazel-outx64_windows-opt/bin/tensorflow
export _param_file="$execroot/python/_pywrap_tensorflow_internal.so-2.params"
while true; do if [ -f $_param_file ]; then sed -i 's,^/WHOLEARCHIVE:\(.*external.*\),\1,' $_param_file; sed -i 's,\(.*icuuc.a\),\/WHOLEARCHIVE:\1,' $_param_file; echo done; break; fi; done
export _param_file="$execroot/contrib/lite/toco/python/_tensorflow_wrap_toco.so-2.params"
while true; do if [ -f $_param_file ]; then sed -i 's,^/WHOLEARCHIVE:\(.*external.*\),\1,' $_param_file; echo done; break; else sleep 1; fi; done