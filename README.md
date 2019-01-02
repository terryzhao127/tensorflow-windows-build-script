# Tensorflow Windows Build Script

Building Tensorflow on Windows is really a tough thing and there should be many problems to solve. Thus, this script automates the process of building on Windows, which does the following things for you:

 * Installation of Dependencies
 * Management of Environment Variables
 * Patching

## Getting Started

### Prerequisites

*For Buiding CPU Version:* If you build with CPU version, you need no more preparation.

*For Building GPU Version:* If you build with GPU version, you need to follow this [official guide](https://www.tensorflow.org/install/gpu) to install necessary dependencies.

### Building

1. Clone this repository or directly download it.
1. Run the script **in the repository directory** with **administrator rights**.
    ```powershell
    .\build.ps1 -BazelBuildParameters <parameter_string> [optional_parameter] [...]
    ```
1. The output files should be in `bin` or `bazel-*` folder.

### Details of Parameters

* `-BazelBuildParameters <string>` *Mandotory*

    A string which is passed to Bazel to build Tensorflow.

    If you want to build a PyPI wheel, you need `//tensorflow/tools/pip_package:build_pip_package`.

    If you want to build a C API, you need `//tensorflow:libtensorflow.so`.

    If you want to build a C++ API, you need `//tensorflow:libtensorflow_cc.so`.
    
    *For more information, click [here](https://www.tensorflow.org/install/source_windows#build_the_pip_package)*.

* `BuildCppAPI` *Optional*

    This is needed when buiding C++ API.

* `BuildCppProtoBuf` *Optional*

    Denote it to build Protocol Buffer.

* `ReserveSource` *Optional*

    Denote it when you confirm that you have a **valid tensorflow repository** in `source` folder and do not want to re-clone it in the next building.

### Example

```powershell
# It is an example for building C++ API with GPU support.
.\build.ps1 -BazelBuildParameters "--config=opt --config=cuda --define=no_tensorflow_py_deps=true --copt=-nvcc_options=disable-warnings //tensorflow:libtensorflow_cc.so --verbose_failures" -BuildCppAPI -BuildCppProtoBuf -ReserveSource
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

- [x] Write more documentations.
- [x] Add support for building PyPI wheels and C API.
- [ ] Add support for other versions of Tensorflow.
- [x] Check if a **specific** version of dependency is installed and give a warning if another version of it is installed.
- [ ] Refactor the structure of script.
- [ ] Change how to process the output files.
- [ ] Denote how to solve the symbol problem in C++ API.'
- [ ] Let user choose which version of dependencies to install.
