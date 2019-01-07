# Tensorflow Windows Build Script

Building Tensorflow on Windows is really a tough thing and there should be many problems to solve. Thus, this script automates the process of building on Windows, which does the following things for you:

* Installation of Dependencies
* Management of Environment Variables
* Patching

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
1. The output files should be in `bazel-bin` and `deps` folder.

### Details of Parameters

* `-BazelBuildParameters <string>` *Mandotory*

    A string which is passed to Bazel to build Tensorflow.

    If you want to build a PyPI wheel, you need `//tensorflow/tools/pip_package:build_pip_package`.

    If you want to build a C API, you need `//tensorflow:libtensorflow.so`.

    If you want to build a C++ API, you need `//tensorflow:libtensorflow_cc.so`.

    *For more information, click [here](https://www.tensorflow.org/install/source_windows#build_the_pip_package)*.

* `-BuildCppAPI` *Optional*

    This is needed when buiding C++ API.

* `-BuildCppProtoBuf` *Optional*

    Denote it to build Protocol Buffer when building C++ API.

* `-ReserveSource` *Optional*

    Denote it when you confirm that you have a **valid tensorflow repository** in `source` folder and do not want to re-clone it in the next building.

* `-ReserveVenv` *Optional*

    Denote it when you confirm that you have a **valid virtual environment** in `venv` folder and do not recreate one.

* `-IgnoreDepsVersionIssues` *Optional*

    Denote it to ignore the warnings due to different versions of dependencies you have installed.

### Example

```powershell
# It is an example for building C++ API with GPU support.
$parameterString = "--config=opt --config=cuda --define=no_tensorflow_py_deps=true --copt=-nvcc_options=disable-warnings //tensorflow:libtensorflow_cc.so --verbose_failures"
.\build.ps1 `
    -BazelBuildParameters $parameterString `
    -BuildCppAPI -BuildCppProtoBuf -ReserveSource -ReserveVenv
```

## Known Issues

* The absolute path of your cloned folder should not contain any *special characters*. Otherwise, the configure process will raise a `subprocess.CalledProcessError`.

## Acknowledgements

* My script is based on [Steroes](https://github.com/Steroes)'s work.
* My solution to build C++ API library is based on [gittyupagain](https://github.com/gittyupagain).

## References

These are what I have referenced during contributing to this repo. They are probably useful for you to solve some problems and even get a better idea to build.

### General Build Methods

* [Official Tutorial](https://www.tensorflow.org/install/source_windows)
* [How to build and install TensorFlow GPU/CPU for Windows from source code using bazel and Python 3.6](https://medium.com/@amsokol.com/update-1-how-to-build-and-install-tensorflow-gpu-cpu-for-windows-from-source-code-using-bazel-and-c2e86fec9ef2)

### For Building C++ API

* [No C++ symbols exported after built libtensorflow_cc with bazel on windows](https://github.com/tensorflow/tensorflow/issues/23542)
* [How to build and use Google TensorFlow C++ api](https://stackoverflow.com/questions/33620794/how-to-build-and-use-google-tensorflow-c-api)

## TODO

- [ ] Add support for other versions of Tensorflow.
- [ ] Write a wiki about details of patches.
- [ ] Read parameters from a JSON file for Bazel configure process.

<details>
  <summary>Done</summary>
  
- [x] Check if a **specific** version of dependency is installed and give a warning if another version of it is installed.
- [x] Refactor the structure of script.
- [x] Change how to process the output files.
- [x] Denote how to solve the symbol problem in C++ API.
- [x] Let user choose what versions of dependencies to install.

</details>
