To build a conda tensorflow package with GPU support

* Build the required Docker containers:

    Dockerfiles can be found at: https://github.com/jjhelmus/docker-images

    CUDA  9.0: pkg_build_cos6_cuda90
    CUDA  9.2: pkg_build_cos6_cuda92
    CUDA 10.0: pkg_build_cos6_cuda100

* Start the docker container using:

    ```
    sudo nvidia-docker run -v `pwd`:/io -it pkg_build_cos6_cuda100
    ```

* Create a symlink for libcuda.so.1

    ```
    ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1
    ```

* Update conda and conda-build, and navigate to the recipe root folder.

    Modify conda_build_config.yaml in this directory to specifiy the
    CUDA, CuDNN, compiler and python versions.

    To start a build use:

    ```
    conda build .
    ```

    To time the build and log the build output use:
    ```
    time conda build . 2>&1 | tee ../tf_build_gpu.log
    ```
