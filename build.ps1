# Requires -RunAsAdministrator
# This script needs to be run with administrator rights.

# Set parameters for execution.
Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

# Ask the specific version of Tensorflow.
$SupportedVersions = @("v1.11.0")
$ChoiceIndex = 1
$Options = $SupportedVersions | ForEach-Object {
    New-Object System.Management.Automation.Host.ChoiceDescription "&$ChoiceIndex - $_"
    $ChoiceIndex += 1
}
$Options += New-Object System.Management.Automation.Host.ChoiceDescription "&Select another version"
$Title = "Select a Tensorflow version:"
$ChosenIndex = $Host.ui.PromptForChoice($Title, "", $Options, 0)

if ($ChosenIndex -eq $SupportedVersions.Length) {
    $InstallVersion = Read-Host "Please input the version number (e.g. v1.11.0)"
} else {
    $InstallVersion = $SupportedVersions[$ChosenIndex]
}

# Install dependencies.
function CheckInstalled {
    param ([string]$ExeName)
    $Installed = Get-Command $ExeName -All -ErrorAction SilentlyContinue
    if (($Installed) -eq $null) {
       Write-Host "Unable to find $ExeName in your PATH" -ForegroundColor Red
       return $False
    } else {
        $Version = $Installed.Version
        Write-Host "Found $ExeName with version $Version" -ForegroundColor Green
        return $True
    }
}

if (CheckInstalled chocolatey) {
    Write-Host "Chocolatey package manager is already installed." -ForegroundColor Green
} else {
    Write-Host "Installing Chocolatey package manager."
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Enable global confirmation for chocolatey package installation.
choco feature enable -n allowGlobalConfirmation

$ENV:Path += ";C:\msys64\usr\bin"
$ENV:Path += ";C:\Program Files\CMake\bin"
$ENV:BAZEL_SH = "C:\msys64\usr\bin\bash.exe"

if (!(CheckInstalled pacman)) {
    choco install msys2 --version 20180531.0.0 --params "/NoUpdate /InstallDir:C:\msys64"
}

if (!(CheckInstalled bazel)) {
    # Bazel will also install msys2, but with an incorrect version, so we will ignore the dependencies.
    choco install bazel --version 0.15.0 --ignore-dependencies
}

if (!(CheckInstalled cmake)) {
    choco install cmake --version 3.12
}

if (!(CheckInstalled git)) {
    choco install git
}

if (!(CheckInstalled python)) {
    choco install python --version 3.6.7 --params "'TARGETDIR:C:/Python36'"
}

# Get the source code of Tensorflow and apply patch
git clone https://github.com/tensorflow/tensorflow.git
cd tensorflow
git checkout tags/$InstallVersion

# C++ Symbol Patch
git apply --ignore-space-change --ignore-white ..\patches\cpp_symbol.patch
Copy-Item ..\patches\tf_exported_symbols_msvc.lds tensorflow\

# Eigen Patch
git apply --ignore-space-change --ignore-white ..\patches\eigen_build.patch
Copy-Item ..\patches\eigen.patch third_party\

cd ..
Rename-Item tensorflow source

# Setup folder structure
mkdir build -ErrorAction SilentlyContinue
cd build

$TensorFlowBuildDir = $pwd
$TensorflowDir=$TensorFlowBuildDir | Split-Path
$TensorflowDependenciesDir="$TensorFlowBuildDir\deps"
$TensorFlowSourceDir="$TensorflowDir\source"
$TensorFlowBinDir="$TensorflowDir\bin"
$VenvDir="$TensorFlowBuildDir\venv"

mkdir $TensorflowDependenciesDir -ErrorAction SilentlyContinue
mkdir $TensorflowBinDir -ErrorAction SilentlyContinue
mkdir $VenvDir -ErrorAction SilentlyContinue

mkdir ("$TensorFlowBinDir\tensorflow\lib") -ErrorAction SilentlyContinue
mkdir ("$TensorFlowBinDir\tensorflow\include") -ErrorAction SilentlyContinue

# Installing protobuf.
$ENV:Path+=";$TensorflowDependenciesDir\protobuf\bin\bin"
cd $TensorflowDependenciesDir

mkdir (Join-Path $TensorflowDependenciesDir protobuf) -ErrorAction SilentlyContinue

cd protobuf
$ProtobufSource = "$pwd\source"
$ProtobufBuild = "$pwd\build"
$ProtobufBin = "$pwd\bin"

$protobuf_tar="protobuf3.6.0.tar.gz"
if (!(Test-Path (Join-Path $pwd $protobuf_tar))) {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    wget https://github.com/google/protobuf/archive/v3.6.0.tar.gz -outfile $protobuf_tar
}
mkdir source -Force
tar -xf $protobuf_tar --directory source --strip-components=1
mkdir $ProtobufBuild -ErrorAction SilentlyContinue
mkdir $ProtobufBin -ErrorAction SilentlyContinue

cd $ProtobufBuild
cmake "$ProtobufSource\cmake" -G"Visual Studio 14 2015 Win64" -DCMAKE_INSTALL_PREFIX="$ProtobufBin" -DCMAKE_BUILD_TYPE=Release -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_MODULE_COMPATIBLE=ON -Dprotobuf_MSVC_STATIC_RUNTIME=OFF
cmake --build . --config Release
cmake --build . --target install --config Release

cd $TensorFlowBuildDir

# Create python environment.
$PY_PYTHON=3
py -3 -m venv venv
.\venv\Scripts\activate.ps1
pip3 install six numpy wheel
pip3 install keras_applications==1.0.5 --no-deps
pip3 install keras_preprocessing==1.0.3 --no-deps

# Install dependencies with pacman
pacman -S --noconfirm patch unzip

cd $TensorFlowSourceDir

# Cleaning tensorflow.
bazel clean --expunge
Remove-Item (Join-Path $TensorFlowSourceDir ".bazelrc") -ErrorAction SilentlyContinue

# Configure tensorflow.
$ENV:PYTHON_BIN_PATH="$VenvDir/Scripts/python.exe" -replace '[\\]', '/'
$ENV:PYTHON_LIB_PATH="$VenvDir/lib/site-packages" -replace '[\\]', '/'

py configure.py

# Build
bazel build --config=opt --config=cuda --define=no_tensorflow_py_deps=true --copt=-nvcc_options=disable-warnings //tensorflow:libtensorflow_cc.so --verbose_failures

Remove-Item $TensorFlowBinDir -ErrorAction SilentlyContinue -Force -Recurse
mkdir $TensorFlowBinDir

# Install tensorflow and its dependencies to bin.
# Tensorflow lib and includes
mkdir $TensorFlowBinDir\tensorflow\lib\ -ErrorAction SilentlyContinue
Copy-Item  $TensorFlowSourceDir\bazel-bin\tensorflow\libtensorflow_cc.so $TensorFlowBinDir\tensorflow\lib\tensorflow_cc.dll
Copy-Item  $TensorFlowSourceDir\bazel-bin\tensorflow\liblibtensorflow_cc.so.ifso $TensorFlowBinDir\tensorflow\lib\tensorflow_cc.lib

Copy-Item $TensorFlowSourceDir\tensorflow\core $TensorFlowBinDir\tensorflow\include\tensorflow\core -Recurse -Container  -Filter "*.h"
Copy-Item $TensorFlowSourceDir\tensorflow\cc $TensorFlowBinDir\tensorflow\include\tensorflow\cc -Recurse -Container -Filter "*.h"

Copy-Item $TensorFlowSourceDir\bazel-genfiles\tensorflow\core\ $TensorFlowBinDir\tensorflow\include_pb\tensorflow\core -Recurse -Container -Filter "*.h"
Copy-Item $TensorFlowSourceDir\bazel-genfiles\tensorflow\cc $TensorFlowBinDir\tensorflow\include_pb\tensorflow\cc -Recurse -Container -Filter "*.h"

# Protobuf lib, bin and includes.
Get-ChildItem $TensorFlowBuildDir\deps\protobuf\bin -Directory | Copy-Item -Destination $TensorFlowBinDir\protobuf -Recurse -Container
mkdir $TensorFlowBinDir\protobuf\bin\ -ErrorAction SilentlyContinue
Move-Item $TensorFlowBinDir\protobuf\protoc.exe $TensorFlowBinDir\protobuf\bin\protoc.exe -ErrorAction SilentlyContinue

# Absl includes.
Copy-Item $TensorFlowSourceDir\bazel-source\external\com_google_absl\absl $TensorFlowBinDir\absl\include\absl\ -Recurse -Container -Filter "*.h" 

# Eigen includes
Copy-Item $TensorFlowSourceDir\bazel-source\external\eigen_archive\ $TensorFlowBinDir\Eigen\eigen_archive -Recurse
Copy-Item $TensorFlowSourceDir\third_party\eigen3 $TensorFlowBinDir\Eigen\include\third_party\eigen3\ -Recurse
