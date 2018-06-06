Recipes for creating Tensorflow conda packages.

In the `defaults` channel Tensorflow is provided via a number of packages.  
As of version 1.8.0, the library itself is provided by the `tensorflow-base`
package.  On Windows and Mac the **tensorflow-base** recipe is used to produce
this package. On Linux, three different variants of the `tensorflow-base`
package are provided, a variant which uses MKL, a variant which uses Eigen, and
a GPU variant.  These are created using the **tensorflow-base-mkl**,
**tensorflow-base-eigen**, and **tensorflow-gpu-base** recipes.

Installing the `tensorflow` package using conda installs both the tensorflow
library as well as tensorboard.  The **tensorboard** recipe is used to create 
the `tensorboard` package.  

The `tensorflow` metapackage package is created by the **tensorflow** recipe.  
On Windows and Mac a single `tensorflow` metapackage is used which depends on
the correct versions of the `tensorflow-base` and `tensorboard` packages.
On Linux, the `tensorflow` metapackage depends on `tensorboard`, an exact
build of `tensorflow-base` and the version of the `_tflow_180_select` package
which matches the `tensorflow-base` variant.  The `_tflow_180_select` package,
created from the **_tflow_180_select** recipe, establishes the priority of the
variants using the version number. The variant with the highest version will
be installed by default. The non-default variant can be installed using the
`tensorflow-mkl`, `tensorflow-eigen` and `tensorflow-gpu` packages which are
created from the **tensorflow-variants** recipe.

Available Recipe:

* tensorboard : Tensorboard.
* tensorflow : Metapackage which installs tensorflow-base and tensorboard.
* tensorflow-base : The Tensorflow library. Used on Windows and Mac.
* tensorflow-base-eigen : Eigen variant of the Tensorflow library, Linux only.
* tensorflow-base-mkl : MKL variant of the Tensorflow library, Linux only.
* tensorflow-gpu :  Old recipe for producing the GPU variant.
* tensorflow-gpu-base : GPU variant of the Tensorflow library, Linux only.
* tensorflow-variants : Recipe used to create tensorflow variant packages, e.g. tensorflow-mkl.
* _tflow_180_select : Metapackage to establish priority in tensorflow-base packages.
