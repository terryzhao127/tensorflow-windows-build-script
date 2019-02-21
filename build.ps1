# Requires -RunAsAdministrator
# This script needs to be run with administrator rights.

param (
    [Parameter(Mandatory = $true)]
    [string]$BazelBuildParameters,

    [switch]$BuildCppAPI = $false,
    [switch]$ReserveSource = $false,
    [switch]$ReserveVenv = $false,
    [switch]$IgnoreDepsVersionIssues = $false,
    [switch]$InstallDefaultDeps = $false
)

# Set parameters for execution.
Set-StrictMode -Version latest
$ErrorActionPreference = "Stop"

# Cleaning Work
if (Test-Path tensorflow) {
    Remove-Item tensorflow -Force -Recurse
}
if (! $ReserveVenv -and (Test-Path venv)) {
    Remove-Item venv -Force -Recurse
}
if (! $ReserveSource -and (Test-Path source)) {
    Remove-Item source -Force -Recurse
}

# Ask the specific version of Tensorflow.
$supportedVersions = @("v1.12.0", "v1.11.0")
$options = [Array]::CreateInstance([System.Management.Automation.Host.ChoiceDescription], $supportedVersions.Count + 1)
for ($i = 0; $i -lt $supportedVersions.Count; $i++) {
    $options[$i] = [System.Management.Automation.Host.ChoiceDescription]::new("&$($i + 1) - $($supportedVersions[$i])",
        "Build Tensorflow $($supportedVersions[$i]).")
}
$options[$options.Count - 1] = [System.Management.Automation.Host.ChoiceDescription]::new("&Select another version",
    "Input the custom version tag you want to build.")
$title = "Select a Tensorflow version:"
$chosenIndex = $Host.UI.PromptForChoice($title, "", $options, 0)

if ($supportedVersions.Count -eq $chosenIndex) {
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
    $installed = Get-Command $ExeName -All
    if ($null -eq $installed) {
        Write-Host "Unable to find $ExeName." -ForegroundColor Red
        return $false
    } else {
        Write-Host "Found $ExeName installed." -ForegroundColor Green
        if ([string]::Empty -ne $RequiredVersion -and $true -ne $IgnoreDepsVersionIssues) {
            Write-Host $("But we've only tested with $ExeName $RequiredVersion.") -ForegroundColor Yellow
            $confirmation = Read-Host "Are you sure you want to PROCEED? [y/n]"
            while ($confirmation -ne "y") {
                if ($confirmation -eq "n") {exit}
                $confirmation = Read-Host "Are you sure you want to PROCEED? [y/n]"
            }
        }
        return $true
    }
}

function askForVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DefaultVersion
    )

    if ($InstallDefaultDeps) {
        return $DefaultVersion
    }

    $version = Read-Host "Which version would you like to install? [Default version: $DefaultVersion]"
    if ($version -eq "") {
        return $DefaultVersion
    }
    return $version
}

if (! (CheckInstalled chocolatey)) {
    Write-Host "Installing Chocolatey package manager."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1"))
}

choco feature enable -n allowGlobalConfirmation | Out-Null # Enable global confirmation for chocolatey package installation.

$ENV:Path += ";C:\msys64\usr\bin"
$ENV:Path += ";C:\Program Files\CMake\bin"
$ENV:BAZEL_SH = "C:\msys64\usr\bin\bash.exe"

if (! (CheckInstalled pacman)) {
    $version = askForVersion "20180531.0.0"
    choco install msys2 --version $version --params "/NoUpdate /InstallDir:C:\msys64"
}

# Install tools that are necessary for buiding.
pacman -S --noconfirm patch unzip

if (! (CheckInstalled bazel "0.15.0")) {
    # Bazel will also install msys2, but with an incorrect version, so we will ignore the dependencies.
    $version = askForVersion "0.15.0"
    choco install bazel --version $version --ignore-dependencies
}

if (! (CheckInstalled cmake "3.12")) {
    $version = askForVersion "3.12"
    choco install cmake --version $version
}

if (! (CheckInstalled git)) {
    choco install git
}

if (! (CheckInstalled python "3.6.7")) {
    $version = askForVersion "3.6.7"
    choco install python --version $version --params "'TARGETDIR:C:/Python36'"
}

# Get the source code of Tensorflow and checkout to the specific version.
if (! $ReserveSource) {
    git clone https://github.com/tensorflow/tensorflow.git
    Rename-Item tensorflow source
}
Set-Location source
git checkout -f tags/$buildVersion
git clean -fx

# Apply patches to source.
if ($buildVersion -eq "v1.11.0") {
    # Eigen Patch for v1.11.0
    git apply --ignore-space-change --ignore-white "..\patches\eigen.1.11.0.patch"
    Copy-Item ..\patches\eigen_half.patch third_party\
} elseif ($buildVersion -eq "v1.12.0") {
    # Eigen Patch for v1.12.0
    git apply --ignore-space-change --ignore-white "..\patches\eigen.1.12.0.patch"
    Copy-Item ..\patches\eigen_half.patch third_party\
}

if ($BuildCppAPI) {
    if ($buildVersion -eq "v1.11.0") {
        # C++ Symbol Patch for v1.11.0
        git apply --ignore-space-change --ignore-white "..\patches\cpp_symbol.1.11.0.patch"
        Copy-Item ..\patches\tf_exported_symbols_msvc.lds tensorflow\
    } elseif ($buildVersion -eq "v1.12.0") {
        # C++ Symbol Patch for v1.12.0
        git apply --ignore-space-change --ignore-white "..\patches\cpp_symbol.1.12.0.patch"
        Copy-Item ..\patches\tf_exported_symbols_msvc.lds tensorflow\
    }
}

Set-Location ..

# Setup folder structure.
$rootDir = $pwd
$sourceDir = "$rootDir\source"
$venvDir = "$rootDir\venv"

# Create python environment.
if (! $ReserveVenv) {
    mkdir $venvDir | Out-Null
    py -3 -m venv venv
    .\venv\Scripts\Activate.ps1
    pip3 install six numpy wheel
    pip3 install keras_applications==1.0.5 --no-deps
    pip3 install keras_preprocessing==1.0.3 --no-deps
} else {
    .\venv\Scripts\Activate.ps1
}

Set-Location $sourceDir

if ($ReserveSource) {
    # Cleaning Bazel files.
    bazel clean --expunge
    $bazelSetting = Join-Path $sourceDir ".bazelrc"
    if (Test-Path $bazelSetting) {
        Remove-Item $bazelSetting
    }
}

# Configure
$ENV:PYTHON_BIN_PATH = "$VenvDir/Scripts/python.exe" -replace "[\\]", "/"
$ENV:PYTHON_LIB_PATH = "$VenvDir/lib/site-packages" -replace "[\\]", "/"

py configure.py

# Build
Invoke-Expression ("bazel build " + $BazelBuildParameters)

# Shutdown Bazel
bazel shutdown

Set-Location $rootDir
