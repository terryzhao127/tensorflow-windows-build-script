# Requires -RunAsAdministrator
# This script needs to be run with administrator rights.

# Set parameters for execution.
Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

# Ask the specific version of Tensorflow.
$supportedVersions = @("v1.11.0")
$options = [Array]::CreateInstance([System.Management.Automation.Host.ChoiceDescription], $supportedVersions.Count + 1)
for ($i = 0; $i -lt $supportedVersions.Count; $i++) {
    $options[$i] = [System.Management.Automation.Host.ChoiceDescription]::new("&$($i + 1) - $($supportedVersions[$i])")
}
$options[$options.Count - 1] = [System.Management.Automation.Host.ChoiceDescription]::new("&Select another version")
$title = "Select a Tensorflow version:"
$chosenIndex = $Host.UI.PromptForChoice($title, "", $options, 0)

if ($chosenIndex -eq $supportedVersions.Count) {
    $installVersion = Read-Host "Please input the version number (e.g. v1.11.0)"
} else {
    $installVersion = $supportedVersions[$chosenIndex]
}

# Install dependencies.
function CheckInstalled {
    param ([string]$ExeName)
    $installed = Get-Command $ExeName -All -ErrorAction SilentlyContinue
    if ($null -eq ($installed)) {
        Write-Host "Unable to find $ExeName in your PATH" -ForegroundColor Red
        return $false
    } else {
        $Version = $installed.Version
        Write-Host "Found $ExeName with version $Version" -ForegroundColor Green
        return $true
    }
}

if (CheckInstalled chocolatey) {
    Write-Host "Chocolatey package manager is already installed." -ForegroundColor Green
} else {
    Write-Host "Installing Chocolatey package manager."
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
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
Set-Location tensorflow
git checkout tags/$installVersion

# C++ Symbol Patch
git apply --ignore-space-change --ignore-white ..\patches\cpp_symbol.patch
Copy-Item ..\patches\tf_exported_symbols_msvc.lds tensorflow\

# Eigen Patch
git apply --ignore-space-change --ignore-white ..\patches\eigen_build.patch
Copy-Item ..\patches\eigen.patch third_party\

Set-Location ..
Rename-Item tensorflow source

# Setup folder structure
mkdir build -ErrorAction SilentlyContinue
Set-Location build

$tensorFlowBuildDir = $pwd
$tensorflowDir = $tensorFlowBuildDir | Split-Path
$tensorflowDependenciesDir = "$tensorFlowBuildDir\deps"
$tensorFlowSourceDir = "$tensorflowDir\source"
$tensorFlowBinDir = "$tensorflowDir\bin"
$venvDir = "$tensorFlowBuildDir\venv"

mkdir $tensorflowDependenciesDir -ErrorAction SilentlyContinue
mkdir $tensorflowBinDir -ErrorAction SilentlyContinue
mkdir $venvDir -ErrorAction SilentlyContinue

mkdir ("$tensorFlowBinDir\tensorflow\lib") -ErrorAction SilentlyContinue
mkdir ("$tensorFlowBinDir\tensorflow\include") -ErrorAction SilentlyContinue

# Installing protobuf.
$ENV:Path += ";$tensorflowDependenciesDir\protobuf\bin\bin"
Set-Location $tensorflowDependenciesDir

mkdir (Join-Path $tensorflowDependenciesDir protobuf) -ErrorAction SilentlyContinue

Set-Location protobuf
$protobufSource = "$pwd\source"
$protobufBuild = "$pwd\build"
$protobufBin = "$pwd\bin"

$protobuf_tar = "protobuf3.6.0.tar.gz"
if (!(Test-Path (Join-Path $pwd $protobuf_tar))) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest https://github.com/google/protobuf/archive/v3.6.0.tar.gz -outfile $protobuf_tar
}
mkdir source -Force
tar -xf $protobuf_tar --directory source --strip-components=1
mkdir $protobufBuild -ErrorAction SilentlyContinue
mkdir $protobufBin -ErrorAction SilentlyContinue

Set-Location $protobufBuild
cmake "$protobufSource\cmake" -G"Visual Studio 14 2015 Win64" -DCMAKE_INSTALL_PREFIX="$protobufBin" -DCMAKE_BUILD_TYPE=Release -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_MODULE_COMPATIBLE=ON -Dprotobuf_MSVC_STATIC_RUNTIME=OFF
cmake --build . --config Release
cmake --build . --target install --config Release

Set-Location $tensorFlowBuildDir

# Create python environment.
py -3 -m venv venv
.\venv\Scripts\activate.ps1
pip3 install six numpy wheel
pip3 install keras_applications==1.0.5 --no-deps
pip3 install keras_preprocessing==1.0.3 --no-deps

# Install dependencies with pacman
pacman -S --noconfirm patch unzip

Set-Location $tensorFlowSourceDir

# Cleaning
bazel clean --expunge
Remove-Item (Join-Path $tensorFlowSourceDir ".bazelrc") -ErrorAction SilentlyContinue

# Configure
$ENV:PYTHON_BIN_PATH = "$VenvDir/Scripts/python.exe" -replace '[\\]', '/'
$ENV:PYTHON_LIB_PATH = "$VenvDir/lib/site-packages" -replace '[\\]', '/'

py configure.py

# Build
bazel build --config=opt --config=cuda --define=no_tensorflow_py_deps=true --copt=-nvcc_options=disable-warnings //tensorflow:libtensorflow_cc.so --verbose_failures

Remove-Item $tensorFlowBinDir -ErrorAction SilentlyContinue -Force -Recurse
mkdir $tensorFlowBinDir

# Install Tensorflow and its dependencies to bin.
# Tensorflow lib and includes
mkdir $tensorFlowBinDir\tensorflow\lib\ -ErrorAction SilentlyContinue
Copy-Item  $tensorFlowSourceDir\bazel-bin\tensorflow\libtensorflow_cc.so $tensorFlowBinDir\tensorflow\lib\tensorflow_cc.dll
Copy-Item  $tensorFlowSourceDir\bazel-bin\tensorflow\liblibtensorflow_cc.so.ifso $tensorFlowBinDir\tensorflow\lib\tensorflow_cc.lib

Copy-Item $tensorFlowSourceDir\tensorflow\core $tensorFlowBinDir\tensorflow\include\tensorflow\core -Recurse -Container  -Filter "*.h"
Copy-Item $tensorFlowSourceDir\tensorflow\cc $tensorFlowBinDir\tensorflow\include\tensorflow\cc -Recurse -Container -Filter "*.h"

Copy-Item $tensorFlowSourceDir\bazel-genfiles\tensorflow\core\ $tensorFlowBinDir\tensorflow\include_pb\tensorflow\core -Recurse -Container -Filter "*.h"
Copy-Item $tensorFlowSourceDir\bazel-genfiles\tensorflow\cc $tensorFlowBinDir\tensorflow\include_pb\tensorflow\cc -Recurse -Container -Filter "*.h"

# Protobuf lib, bin and includes.
Get-ChildItem $tensorFlowBuildDir\deps\protobuf\bin -Directory | Copy-Item -Destination $tensorFlowBinDir\protobuf -Recurse -Container
mkdir $tensorFlowBinDir\protobuf\bin\ -ErrorAction SilentlyContinue
Move-Item $tensorFlowBinDir\protobuf\protoc.exe $tensorFlowBinDir\protobuf\bin\protoc.exe -ErrorAction SilentlyContinue

# Absl includes.
Copy-Item $tensorFlowSourceDir\bazel-source\external\com_google_absl\absl $tensorFlowBinDir\absl\include\absl\ -Recurse -Container -Filter "*.h" 

# Eigen includes
Copy-Item $tensorFlowSourceDir\bazel-source\external\eigen_archive\ $tensorFlowBinDir\Eigen\eigen_archive -Recurse
Copy-Item $tensorFlowSourceDir\third_party\eigen3 $tensorFlowBinDir\Eigen\include\third_party\eigen3\ -Recurse
