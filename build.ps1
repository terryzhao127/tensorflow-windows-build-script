# Requires -RunAsAdministrator
# This script needs to be run with administrator rights.

param (
    [Parameter(Mandatory = $true)]
    [string]$BazelBuildParameters,

    [switch]$BuildCppAPI = $false,
    [switch]$BuildCppProtoBuf = $false,
    [switch]$ReserveSource = $false
)

# Set parameters for execution.
Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

# Cleaning Work
Remove-Item tensorflow -ErrorAction SilentlyContinue -Force -Recurse
Remove-Item build -ErrorAction SilentlyContinue -Force -Recurse
Remove-Item bin -ErrorAction SilentlyContinue -Force -Recurse
if (! $ReserveSource) {
    Remove-Item source -ErrorAction SilentlyContinue -Force -Recurse
}

# Ask the specific version of Tensorflow.
$supportedVersions = @("v1.11.0")
$options = [Array]::CreateInstance([System.Management.Automation.Host.ChoiceDescription], $supportedVersions.Count + 1)
for ($i = 0; $i -lt $supportedVersions.Count; $i++) {
    $options[$i] = [System.Management.Automation.Host.ChoiceDescription]::new("&$($i + 1) - $($supportedVersions[$i])",
        "Build Tensorflow $($supportedVersions[$i]).")
}
$options[$options.Count - 1] = [System.Management.Automation.Host.ChoiceDescription]::new("&Select another version",
    "Input the custom version tag you want to build.")
$title = "Select a Tensorflow version:"
$chosenIndex = $Host.UI.PromptForChoice($title, "", $options, 0)

if ($chosenIndex -eq $supportedVersions.Count) {
    $buildVersion = Read-Host "Please input the version tag (e.g. v1.11.0)"
} else {
    $buildVersion = $supportedVersions[$chosenIndex]
}

# Install dependencies.
function CheckInstalled {
    param (
        [string]$ExeName,

        [Parameter(Mandatory = $false)]
        [string]$RequiredVersion
    )
    $installed = Get-Command $ExeName -All -ErrorAction SilentlyContinue
    if ($null -eq ($installed)) {
        Write-Host "Unable to find $ExeName in your PATH" -ForegroundColor Red
        return $false
    } else {
        Write-Host "Found $ExeName installed." -ForegroundColor Green
        if ([string]::Empty -ne $RequiredVersion) {
            Write-Host $("But we've only tested with $ExeName $RequiredVersion. " +
                "Make sure you have installed one with the same version.") -ForegroundColor Yellow
            $confirmation = Read-Host "Are you sure you want to PROCEED? [y/n]"
            while ($confirmation -ne "y") {
                if ($confirmation -eq 'n') {exit}
                $confirmation = Read-Host "Are you sure you want to PROCEED? [y/n]"
            }
        }
        return $true
    }
}

if (!(CheckInstalled chocolatey)) {
    Write-Host "Installing Chocolatey package manager."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

choco feature enable -n allowGlobalConfirmation # Enable global confirmation for chocolatey package installation.

$ENV:Path += ";C:\msys64\usr\bin"
$ENV:Path += ";C:\Program Files\CMake\bin"
$ENV:BAZEL_SH = "C:\msys64\usr\bin\bash.exe"

if (!(CheckInstalled pacman)) {
    choco install msys2 --version 20180531.0.0 --params "/NoUpdate /InstallDir:C:\msys64"
    pacman -S --noconfirm patch unzip
}

if (!(CheckInstalled bazel "0.15.0")) {
    # Bazel will also install msys2, but with an incorrect version, so we will ignore the dependencies.
    choco install bazel --version 0.15.0 --ignore-dependencies
}

if (!(CheckInstalled cmake "3.12")) {
    choco install cmake --version 3.12
}

if (!(CheckInstalled git)) {
    choco install git
}

if (!(CheckInstalled python 3.6.7)) {
    choco install python --version 3.6.7 --params "'TARGETDIR:C:/Python36'"
}

# Get the source code of Tensorflow and apply patches.
if (! $ReserveSource) {
    git clone https://github.com/tensorflow/tensorflow.git
    Set-Location tensorflow
    git checkout tags/$buildVersion

    if ($BuildCppAPI) {
        # C++ Symbol Patch
        git apply --ignore-space-change --ignore-white ..\patches\cpp_symbol.patch
        Copy-Item ..\patches\tf_exported_symbols_msvc.lds tensorflow\
    }

    # Eigen Patch
    git apply --ignore-space-change --ignore-white ..\patches\eigen_build.patch
    Copy-Item ..\patches\eigen.patch third_party\

    Set-Location ..
    Rename-Item tensorflow source
} else {
    Set-Location source
    git checkout tags/$buildVersion
    Set-Location ..
}

# Setup folder structure.
mkdir build
Set-Location build

$tensorFlowBuildDir = $pwd
$tensorflowDir = $tensorFlowBuildDir | Split-Path
$tensorflowDependenciesDir = "$tensorFlowBuildDir\deps"
$tensorFlowSourceDir = "$tensorflowDir\source"
$tensorFlowBinDir = "$tensorflowDir\bin"
$venvDir = "$tensorFlowBuildDir\venv"

mkdir $tensorflowDependenciesDir
mkdir $tensorflowBinDir
mkdir $venvDir

mkdir "$tensorFlowBinDir\tensorflow\lib"
mkdir "$tensorFlowBinDir\tensorflow\include"

# Installing protobuf.
if ($BuildCppProtoBuf) {
    $ENV:Path += ";$tensorflowDependenciesDir\protobuf\bin\bin"
    Set-Location $tensorflowDependenciesDir

    mkdir (Join-Path $tensorflowDependenciesDir protobuf)

    Set-Location protobuf
    $protobufSource = "$pwd\source"
    $protobufBuild = "$pwd\build"
    $protobufBin = "$pwd\bin"

    $protobuf_tar = "protobuf3.6.0.tar.gz"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest "https://github.com/google/protobuf/archive/v3.6.0.tar.gz" -outfile $protobuf_tar

    mkdir source
    tar -xf $protobuf_tar --directory source --strip-components=1
    mkdir $protobufBuild
    mkdir $protobufBin

    Set-Location $protobufBuild
    cmake "$protobufSource\cmake" -G"Visual Studio 14 2015 Win64" -DCMAKE_INSTALL_PREFIX="$protobufBin" -DCMAKE_BUILD_TYPE=Release `
        -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_MODULE_COMPATIBLE=ON -Dprotobuf_MSVC_STATIC_RUNTIME=OFF
    cmake --build . --config Release
    cmake --build . --target install --config Release

    Set-Location $tensorFlowBuildDir
}

# Create python environment.
py -3 -m venv venv
.\venv\Scripts\Activate.ps1
pip3 install six numpy wheel
pip3 install keras_applications==1.0.5 --no-deps
pip3 install keras_preprocessing==1.0.3 --no-deps

Set-Location $tensorFlowSourceDir

if ($ReserveSource) {
    # Cleaning Bazel files.
    bazel clean --expunge
    Remove-Item (Join-Path $tensorFlowSourceDir ".bazelrc") -ErrorAction SilentlyContinue
}

# Configure
$ENV:PYTHON_BIN_PATH = "$VenvDir/Scripts/python.exe" -replace '[\\]', '/'
$ENV:PYTHON_LIB_PATH = "$VenvDir/lib/site-packages" -replace '[\\]', '/'

py configure.py

# Build
Invoke-Expression ("bazel build " + $BazelBuildParameters)

# Shutdown Bazel
bazel shutdown

if ($BuildCppAPI) {
    # Move Tensorflow C++ library and its dependencies to bin.

    # Tensorflow lib and includes
    Copy-Item  $tensorFlowSourceDir\bazel-bin\tensorflow\libtensorflow_cc.so $tensorFlowBinDir\tensorflow\lib\tensorflow_cc.dll
    Copy-Item  $tensorFlowSourceDir\bazel-bin\tensorflow\liblibtensorflow_cc.so.ifso $tensorFlowBinDir\tensorflow\lib\tensorflow_cc.lib

    Copy-Item $tensorFlowSourceDir\tensorflow\core $tensorFlowBinDir\tensorflow\include\tensorflow\core -Recurse -Container  -Filter "*.h"
    Copy-Item $tensorFlowSourceDir\tensorflow\cc $tensorFlowBinDir\tensorflow\include\tensorflow\cc -Recurse -Container -Filter "*.h"

    Copy-Item $tensorFlowSourceDir\bazel-genfiles\tensorflow\core\ $tensorFlowBinDir\tensorflow\include_pb\tensorflow\core -Recurse -Container -Filter "*.h"
    Copy-Item $tensorFlowSourceDir\bazel-genfiles\tensorflow\cc $tensorFlowBinDir\tensorflow\include_pb\tensorflow\cc -Recurse -Container -Filter "*.h"

    # Absl includes
    Copy-Item $tensorFlowSourceDir\bazel-source\external\com_google_absl\absl $tensorFlowBinDir\absl\include\absl\ -Recurse -Container -Filter "*.h" 

    # Eigen includes
    Copy-Item $tensorFlowSourceDir\bazel-source\external\eigen_archive\ $tensorFlowBinDir\Eigen\eigen_archive -Recurse
    Copy-Item $tensorFlowSourceDir\third_party\eigen3 $tensorFlowBinDir\Eigen\include\third_party\eigen3\ -Recurse

    if ($BuildCppProtoBuf) {
        # Protobuf lib, bin and includes
        Get-ChildItem $tensorFlowBuildDir\deps\protobuf\bin -Directory | Copy-Item -Destination $tensorFlowBinDir\protobuf -Recurse -Container
        mkdir $tensorFlowBinDir\protobuf\bin\
        Move-Item $tensorFlowBinDir\protobuf\protoc.exe $tensorFlowBinDir\protobuf\bin\protoc.exe -ErrorAction SilentlyContinue
    }

    Write-Host "Built files are located in 'bin' folder." -ForegroundColor Green
}