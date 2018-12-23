# Build Tensorflow C++ API with Bazel on Windows

If you should build tensorflow C++ API as a standalone library with Bazel on Windows, this repo is probably the only one way to achieve it.

I hope this repo will inspire someone with better ideas and please tell me or make a pull request.

## TODO

- [ ] Write more documentations.
- [ ] Add support for building PyPI wheels and C API.
- [ ] Add support for other versions of Tensorflow
- [ ] Check if a **specific** version of dependency is installed and give a warning if another version of it is installed.

## Known Issues

1. The absolute path of your cloned folder should not contain some *special characters*. Otherwise, the configure process will raise a `subprocess.CalledProcessError`.