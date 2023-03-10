## To test the tensorflow conda packages

* Prepare a conda environment with tensorflow and related packages:
  ```
    conda create -n tf_test -c defaults -c <path to env>/conda-bld python=<python version> tensorflow=<tensorflow version> portpicker scipy scikit-learn
  ```
  Here \<path to conda-env\> is the local path to the environment tensorflow was built into

* Install a "good" version of bazel.  This can be done in the above enviornment
  or using the files from https://github.com/bazelbuild/bazel/releases
  The tests seem be be picky about the bazel version, 0.25.2 works for 1.14.0.

* Additionally, `gxx` and `gcc` may need to be installed because not all builders support C++17

* Clone the tensorflow repository and checkout the tag to test:
    git clone https://github.com/tensorflow/tensorflow.git
    cd tensorflow
    git checkout <branch for tensorflow version>

* Use the `run_tests.sh` script in this directory to run the tests in in the
  activated environment:
    cp ../run_tests.sh
    conda activate tf_test
    ./run_tests.sh

To test the GPU packages use the above instructions but create an environment
with a gpu variant and use the `run_gpu_tests.sh` script.
