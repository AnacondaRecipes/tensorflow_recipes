move tensorboard-%PKG_VERSION%-py3-none-any.whl.dummy tensorboard-%PKG_VERSION%-py3-none-any.whl
%PYTHON% -m pip install --no-deps tensorboard-%PKG_VERSION%-py3-none-any.whl

:: We don't have a protobuf package on Windows with the C++ implementation, so
:: revert the patch which forces it. Remove it when we do.
cd %SP_DIR%
git apply %RECIPE_DIR%\0001-Revert-enable-fast-C-implementation-of-python-protob.patch
