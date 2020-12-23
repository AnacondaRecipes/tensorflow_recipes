# tensorflow-base-gpu

To build a conda tensorflow package with GPU support

## Linux

- Build the required Docker containers:

    Dockerfiles can be found at: https://github.com/conda/conda-concourse-ci/tree/master/docker/gpu

    - CUDA 9.0: `pkg_build_cos6_cuda90`
    - CUDA 9.2: `pkg_build_cos6_cuda92`
    - CUDA 10.0: `pkg_build_cos6_cuda100`

- Start the docker container using:

    ```
    sudo nvidia-docker run -v `pwd`:/io -it pkg_build_cos6_cuda100
    ```

- Create a symlink for `libcuda.so.1`

    ```
    ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1
    ```

- Open *Anaconda Prompt*. Update `conda` and `conda-build`, and navigate to the recipe root folder.

    - Update the `conda_build_config.yaml` files for your build (there may be several `conda_build_config.yaml` files you will need to update at different directory levels, starting from the `aggregate` level down to your specific tensorflow recipe directory). Be sure to specifiy the CUDA, CuDNN, compiler and python versions.

    - To start a build use:
    ```
    conda build .
    ```

    - To time the build and log the build output use:
    ```
    time conda build . 2>&1 | tee ../tf_build_gpu.log
    ```

## Windows

- Use *Microsoft Remote Desktop* to log into a Windows GPU-enabled machine in the Concourse build cluster.

- Copy or clone the tensorflow recipes you need to build into a local directory. (As of 12/23/2020, you will likely need the whole `tensorflow_recipes` directory and its contents.)

- Open *Anaconda Prompt*. Update `conda` and `conda-build`, and navigate to the recipe root folder.

    - Update the `conda_build_config.yaml` files for your build (there may be several `conda_build_config.yaml` files you will need to update at different directory levels, starting from the `aggregate` level down to your specific tensorflow recipe directory). Be sure to specifiy the CUDA, CuDNN, compiler and python versions.

    - To start a build use:
    ```
    conda build . --croot=C:\b --no-build-id > PATH_WHERE_YOU_WANT_TO_SAVE_LOGFILE 2>&1

    EXAMPLE:
    conda build . --croot=C:\b --no-build-id > C:\Users\builder\pyim\tf_build_logfile_0.txt 2>&1
    ```

### Error handling

- `FATAL: Command line too long (34263 > 32768):  -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=c:\\ci\\tensorflow-base_1607630317667\\bazel -Xverify:none -Djava.util.logging.config.file=c:\\ci\\tensorflow-base_1607630317667\\bazel\\javalog.properties -Dcom.google.devtools.build.lib.util.LogHandlerQuerier.class=com.google.devtools.build.lib.util.SimpleLogHandler$HandlerQuerier -XX:-MaxFDLimit
...`
    - Windows has a command line length limit that `bazel` is known to violate.
    - **RESOLUTION**: Make sure to use the `--croot=C:\b` and `--no-build-id` parameters in your `conda-build` commmand to shorten the commands as much as possible.

- `mktemp: failed to create directory via template ‘/c/t/tmp.XXXXXXXXXX’: No such file or directory`
    - This is likely coming from the `./bazel-bin/tensorflow/tools/pip_package/build_pip_package` command, which tries to create a temp directory when it runs.
    - **RESOLUTION**: In the local `C:` directory, create a directory called `t`, so you end up with a directory at `C:\t`. Re-run the `conda-build` command; it should now be able create the `/c/t/tmp.XXXXXXXXXX` file.

