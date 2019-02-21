# Tensorflow Windows Build Script

Building Tensorflow on Windows is really a tough thing and there should be many problems to solve. Thus, this script automates the process of building on Windows, which does the following things for you:

* Installation of Dependencies
* Management of Environment Variables
* Patching *(For more information, view [wiki](https://github.com/guikarist/tensorflow-windows-build-script/wiki/patches))*

*This script has tested on `v1.12.0` and `v1.11.0`.*

## Getting Started

### Prerequisites

You may need to do some preparations below:

* **If you need to build GPU version,** you need to follow this [official guide](https://www.tensorflow.org/install/gpu) to install GPU support.

* **If you need to build C++ API,** you should add symbols that you need into `patches\tf_exported_symbols_msvc.lds`. If you don't know what symbols you need, never mind and skip this step. When you use the built C++ API, the linker will probably give you link errors, telling what symbols you need.

### Building

1. Clone this repository or directly download it.
1. Run the script **in the repository directory** with **administrator rights**.
    ```powershell
    .\build.ps1 -BazelBuildParameters <parameter_string> [optional_parameters]
    ```
1. The output files should be in `source\bazel-bin` folder.

### Details of Parameters

* `-BazelBuildParameters <string>` *Mandatory*

    A string which is passed to Bazel to build Tensorflow.

    If you want to build a PyPI wheel, you need `//tensorflow/tools/pip_package:build_pip_package`.

    If you want to build a C API, you need `//tensorflow:libtensorflow.so`.

    If you want to build a C++ API, you need `//tensorflow:libtensorflow_cc.so`.

    *For more information, click [here](https://www.tensorflow.org/install/source_windows#build_the_pip_package)*.

* `-BuildCppAPI` *Optional*

    This is needed when buiding C++ API.

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

## References

These are what I have referenced during contributing to this repo. They are probably useful for you to solve some problems and even get a better idea to build.

## TODO

- [ ] Create template for issue.
- [ ] Put latest news on related topics in Wiki together.
- [ ] Write an example to use built results.
- [ ] Pay continuous attention to [new building API on Windows](https://github.com/tensorflow/tensorflow/issues/24885).

<details>
  <summary>Done</summary>
  
- [x] Delete the API which builds protobuf.
- [x] Write a wiki about details of patches.
- [x] Add support for other versions of Tensorflow.
- [x] Check if a **specific** version of dependency is installed and give a warning if another version of it is installed.
- [x] Refactor the structure of script.
- [x] Change how to process the output files.
- [x] Denote how to solve the symbol problem in C++ API.
- [x] Let user choose what versions of dependencies to install.

</details>
