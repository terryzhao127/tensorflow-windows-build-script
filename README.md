# Tensorflow Windows Build Script

Building Tensorflow on Windows is really a **tough** thing and there should be many problems to solve. Thus, this script automates the process of building on Windows, which does the following things for you:

* Installation of Dependencies
* Management of Environment Variables
* Patching *(For more information, view [wiki](https://github.com/guikarist/tensorflow-windows-build-script/wiki/patches))*

*This script has been tested on `v1.13.1`, `v1.12.0` and `v1.11.0`.*

However, this script may work on several unsupported versions. If you did this and succeeded, it would be nice of you to add your configurations to the script by pull requests! Through [Bulletin Board](#bulletin-board)

## Getting Started

### Prerequisites

You may need to do some preparations below:
* [Turn on function of running PowerShell scripts](https://go.microsoft.com/fwlink/?LinkID=135170) on your computer if not done before.
* **If you need to build GPU version,** you need to follow this [official guide](https://www.tensorflow.org/install/gpu) to install GPU support.
* **If you need to build C++ API on `v1.11.0`， `v1.12.0` and `v1.13.1`,** you should add symbols that you need into `patches\tf_exported_symbols_msvc.lds`. If you don't know what symbols you need, never mind and skip this step. When you use the built C++ API, the linker will probably give you link errors, telling what symbols you need.

### Building

1. Clone this repository or directly download it.
1. Run the script **in the repository directory** with **administrator rights**.

    ```powershell
    .\build.ps1 -BazelBuildParameters <parameter_string> [optional_parameters]
    ```

    * **When you encounter `Make sure you have installed same version of $ExeName $RequiredVersion`,** make sure you have installed same version of what we recommend, otherwise we advise you to uninstall your installed ones and re-run the script which will automatically install recommended ones. Or you can proceed with high possibility to get stuck in problems. After having cleared the version issues, you must be glad to add `-IgnoreDepsVersionIssues` flag next time.

      Considering that not every installed software is installed by [chocolatey](https://chocolatey.org/), we cannot automate the uninstallation process for you. On the other hand, if some of your installed ones are indeed choco packages, please view [chocolatey docs](https://chocolatey.org/docs/commands-uninstall) to uninstall them manually.
1. The output files should be in `source\bazel-bin` folder. View [wiki](https://github.com/guikarist/tensorflow-windows-build-script/wiki/Using-the-built-results#building-c-library) to find some advice on how to use the built results.

### Details of Parameters

* `-BazelBuildParameters <string>` *Mandatory*

  A string which is passed to Bazel to build Tensorflow.

  * If you want to build a PyPI wheel, you need `//tensorflow/tools/pip_package:build_pip_package`.

  * If you want to build a C API, you need `//tensorflow:libtensorflow.so`.

  * If you want to build a C++ API, you need `//tensorflow:libtensorflow_cc.so`.

  *For more information, click [here](https://www.tensorflow.org/install/source_windows#build_the_pip_package)*.

* `-BuildCppAPI` *Optional*

    This is needed when buiding C++ API of `v1.11.0`， `v1.12.0` and `v1.13.1`.

* `-ReserveSource` *Optional*

    Denote it when you confirm that you have a **valid tensorflow repository** in `source` folder and do not want to re-clone it in the next building.

* `-ReserveVenv` *Optional*

    Denote it when you confirm that you have a **valid virtual environment** in `venv` folder and do not recreate one.

* `-IgnoreDepsVersionIssues` *Optional*

    Denote it to ignore the warnings due to different versions of dependencies you have installed.

* `-InstallDefaultDeps` *Optional*

    Install default version of dependencies if not installed.

### Example

```powershell
# It is an example for building C++ API with GPU support.
$parameterString = "--config=opt --config=cuda --define=no_tensorflow_py_deps=true --copt=-nvcc_options=disable-warnings //tensorflow:libtensorflow_cc.so --verbose_failures"
.\build.ps1 `
    -BazelBuildParameters $parameterString `
    -BuildCppAPI -ReserveSource -ReserveVenv
```

## Known Issues

* The absolute path of your cloned folder should not contain any *special characters*. Otherwise, the configure process will raise a `subprocess.CalledProcessError`.

## Acknowledgements

* My script is based on [Steroes](https://github.com/Steroes)'s work.
* My solution to build C++ API library is based on [gittyupagain](https://github.com/gittyupagain).

## Bulletin Board

* New C API (committed): <https://github.com/tensorflow/tensorflow/pull/24963>
* New C++ API (closed): <https://github.com/tensorflow/tensorflow/pull/26152>
