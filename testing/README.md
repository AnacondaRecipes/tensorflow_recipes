## To test the tensorflow conda packages

* Prepare a conda environment with tensorflow and related packages:
    conda create -n tf_test -c defaults -c jjhelmus python=3.7 tensorflow=1.14 portpicker scipy scikit-learn
  Here jjhelmus is the channel where the testing packages where uploaded

* Install a "good" version of bazel.  This can be done in the above enviornment
  or using the files from https://github.com/bazelbuild/bazel/releases
  The tests seem be be picky about the bazel version, 0.25.2 works for 1.14.0.

* Clone the tensorflow repository and checkout the tag to test:
    git clone https://github.com/tensorflow/tensorflow.git
    cd tensorflow
    git checkout v1.14.0

* Use the `run_test.sh` script in this directory to run the tests in in the
  activated environment:
    cp ../run_tests.sh
    conda activate tf_test
    ./run_tests.sh
