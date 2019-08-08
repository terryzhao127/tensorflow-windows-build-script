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

# Cleaning work
if (Test-Path tensorflow) {
    Remove-Item tensorflow -Force -Recurse
}
if (!$ReserveVenv -and (Test-Path venv)) {
    Remove-Item venv -Force -Recurse
}
if (!$ReserveSource -and (Test-Path source)) {
    Remove-Item source -Force -Recurse
}

# Ask the specific version of Tensorflow.
$supportedVersions = @("v1.13.1", "v1.12.0", "v1.11.0")
$options = [Array]::CreateInstance([System.Management.Automation.Host.ChoiceDescription], $supportedVersions.Count)
for ($i = 0; $i -lt $supportedVersions.Count; $i++) {
    $options[$i] = [System.Management.Automation.Host.ChoiceDescription]::new("&$($i + 1) - $($supportedVersions[$i])",
        "Build Tensorflow $($supportedVersions[$i]).")
}
$options += [System.Management.Automation.Host.ChoiceDescription]::new("&Select another version",
    "Input the custom version tag you want to build.")

$title = "Select a Tensorflow version:"
$chosenIndex = $Host.UI.PromptForChoice($title, "", $options, 0)

if ($supportedVersions.Count -eq $chosenIndex) {
    $buildVersion = Read-Host "Please input the version tag (e.g. v1.11.0)"
} else {
    $buildVersion = $supportedVersions[$chosenIndex]
}

# Functions used in installation of dependencies
function CheckInstalled {
    param (
        [string]$ExeName,

        [Parameter(Mandatory = $false)]
        [string]$RequiredVersion
    )
    $installed = Get-Command $ExeName -ErrorAction SilentlyContinue
    if ($null -eq $installed) {
        Write-Host "Unable to find $ExeName." -ForegroundColor Red
        return $false
    } else {
        Write-Host "Found $ExeName installed." -ForegroundColor Green
        if ([string]::Empty -ne $RequiredVersion -and $true -ne $IgnoreDepsVersionIssues) {
            Write-Host $("Make sure you have installed same version of $ExeName $RequiredVersion.") -ForegroundColor Yellow
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

# Assign correct versions of dependencies.
if ($buildVersion -eq "v1.11.0" -or $buildVersion -eq "v1.12.0") {
    $bazelVersion = "0.15.0"
} elseif ($buildVersion -eq "v1.13.1") {
    $bazelVersion = "0.20.0"
}

# Installation of dependencies
if (!(CheckInstalled chocolatey)) {
    Write-Host "Installing Chocolatey package manager."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1"))
}
choco feature enable -n allowGlobalConfirmation | Out-Null # Enable global confirmation for chocolatey package installation.

if (!(CheckInstalled pacman)) {
    $version = askForVersion "20180531.0.0"
    choco install msys2 --version $version --params "/NoUpdate /InstallDir:C:\msys64"
}
$ENV:Path += ";C:\msys64\usr\bin"
$ENV:BAZEL_SH = "C:\msys64\usr\bin\bash.exe"

if (!(CheckInstalled patch)) {
    pacman -S --noconfirm patch
}

if (!(CheckInstalled unzip)) {
    pacman -S --noconfirm unzip
}

if (!(CheckInstalled bazel $bazelVersion)) {
    $version = askForVersion $bazelVersion

    # Bazel will also install msys2, but with an incorrect version, so we will ignore the dependencies.
    choco install bazel --version $version --ignore-dependencies
}

if (!(CheckInstalled git)) {
    choco install git
}

if (!(CheckInstalled python "3.6.7")) {
    $version = askForVersion "3.6.7"
    choco install python --version $version --params "'TARGETDIR:C:/Python36'"
}

# Get the source code of Tensorflow and checkout to the specific version.
if (!$ReserveSource) {
    git clone https://github.com/tensorflow/tensorflow.git
    Rename-Item tensorflow source
    Set-Location source
} else {
    Set-Location source
    git fetch
    git reset --hard origin/master
    git checkout -f master
    git pull
}

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
} elseif ($buildVersion -eq "v1.13.1") {
    git apply --ignore-space-change --ignore-white '..\patches\vs_2017.1.13.1.patch'
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
    } elseif ($buildVersion -eq "v1.13.1") {
        # C++ Symbol Patch for v1.13.1
        git apply --ignore-space-change --ignore-white "..\patches\cpp_symbol.1.13.1.patch"
        Copy-Item ..\patches\tf_exported_symbols_msvc.lds tensorflow\
    }
}

Set-Location ..

# Setup folder structure.
$rootDir = $pwd
$sourceDir = "$rootDir\source"
$venvDir = "$rootDir\venv"

# Create python environment.
if (!$ReserveVenv) {
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
    # Clean Bazel files.
    bazel clean --expunge
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
