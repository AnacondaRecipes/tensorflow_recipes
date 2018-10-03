Recipes for creating Tensorflow conda packages.

In the `defaults` channel Tensorflow is provided via a number of packages.
As of version 1.11.0, the library itself is provided by the `tensorflow-base`
package. Different variants of this package are created for each platform from
the **tensorflow-base-cpu** and **tensorflow-base-gpu** recipes.

Installing the `tensorflow` package using conda installs both the tensorflow
library as well as tensorboard.  The **tensorboard** recipe is used to create
the `tensorboard` package.

The `tensorflow` metapackage package is created by the **tensorflow** recipe.
The `tensorflow` metapackage depends on `tensorboard`, an exact
build of `tensorflow-base` and the version of the `_tflow_select` package
which matches the `tensorflow-base` variant.

The `_tflow_select` package, created from the **_tflow_select** recipe,
establishes the priority of the variants using the version number. The variant
with the highest version will be installed by default. The non-default variant
can be installed using the `tensorflow-mkl`, `tensorflow-eigen` and
`tensorflow-gpu` packages which are created from the **tensorflow-variants**
recipe.  Note that not some platforms do not support all variants.

Available Recipe:

* tensorboard : Tensorboard.
* tensorflow : Metapackage which installs tensorflow-base and tensorboard.
* tensorflow-base-cpu : Eigen and MKL variants of the Tensorflow library.
* tensorflow-base-gpu : GPU variant of the Tensorflow library.
* tensorflow-variants : Recipe used to create tensorflow variant packages, e.g. tensorflow-mkl.
* _tflow_select : Metapackage to establish priority in tensorflow-base packages.
