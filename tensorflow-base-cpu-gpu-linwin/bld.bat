@echo on

set "PATH=%CD%:%PATH%"
set LIBDIR=%LIBRARY_BIN%
set INCLUDEDIR=%LIBRARY_INC%

set "TF_SYSTEM_LIBS=llvm,swig"

:: build with MKL support
set TF_NEED_MKL=1
@REM set BAZEL_MKL_OPT= 

mkdir -p ./bazel_output_base
set BAZEL_OPTS=

:: the following arguments are useful for debugging
::    --logging=6
::    --subcommands
:: jobs can be used to limit parallel builds and reduce resource needs
::    --jobs=20
:: Set compiler and linker flags as bazel does not account for CFLAGS,
:: CXXFLAGS and LDFLAGS.
set BUILD_OPTS="--copt=-march=nocona --copt=-mtune=haswell --copt=-ftree-vectorize --copt=-fPIC --copt=-fstack-protector-strong --copt=-O2 --cxxopt=-fvisibility-inlines-hidden --cxxopt=-fmessage-length=0 --linkopt=-zrelro --linkopt=-znow --verbose_failures --config=mkl --config=opt"

set TF_ENABLE_XLA=0
set BUILD_TARGET="//tensorflow/tools/pip_package:build_pip_package"

:: Python settings
set PYTHON_BIN_PATH=%PYTHON%
set PYTHON_LIB_PATH=%SP_DIR%
set USE_DEFAULT_PYTHON_LIB_PATH=1

:: additional settings
set CC_OPT_FLAGS="-march=nocona -mtune=haswell"
set TF_NEED_OPENCL=0
set TF_NEED_OPENCL_SYCL=0
set TF_NEED_COMPUTECPP=0
set TF_CUDA_CLANG=0
set TF_NEED_TENSORRT=0
set TF_NEED_ROCM=0
set TF_NEED_MPI=0
set TF_DOWNLOAD_CLANG=0
set TF_SET_ANDROID_WORKSPACE=0

:: try to avoid hangs in configure.py by setting environment
:: variables whose value might get prompted if missing, see
:: https://github.com/tensorflow/tensorflow/blob/master/configure.py
:: (searching for 'get_var' & 'get_from_env_or_user_or_default')
:: PYTHON_BIN_PATH / CC_OPT_FLAGS / TF_CUDA_CLANG / TF_DOWNLOAD_CLANG
:: / TF_NEED_ROCM / TF_NEED_TENSORRT set above already
set "HOST_C_COMPILER=%CC%"
set "HOST_CXX_COMPILER=%CXX%"
set "TF_OVERRIDE_EIGEN_STRONG_INLINE=0"
set "TF_NEED_CUDA=0"

bazel clean --expunge
bazel shutdown

:: configure step
COPY %RECIPE_DIR%\def_bazelrc .bazel.rc /Y
%PYTHON% configure.py
if %ERRORLEVEL% neq 0 exit 1

:: build using bazel
bazel %BAZEL_OPTS% build %BUILD_OPTS% %BUILD_TARGET%
if %ERRORLEVEL% neq 0 exit 1

:: build a whl file
mkdir -p %SRC_DIR%\\tensorflow_pkg
bazel-bin\\tensorflow\\tools\\pip_package\\build_pip_package %SRC_DIR%\\tensorflow_pkg
if %ERRORLEVEL% neq 0 exit 1

:: The tensorboard package has the proper entrypoint
DEL /f /q %PREFIX%\Scripts\tensorboard.exe

:: make sure we shutdown things again and are releasing locks ...
bazel clean --expunge
bazel shutdown