@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
call C:\opt\minicoin\util\parse-opts.cmd %*

cd %USERPROFILE%

for /f "tokens=*" %%F in ('dir /b /s /od conan.exe') do (
    set "conan_path=%%F"
)
for /f %%F in ("%conan_path%") do set "conan_path=%%~dpF"

if not defined conan_path (
    >&2 echo Can't locate conan
    exit 1
)

echo Using conan from %conan_path%
set PATH=%conan_path%;%PATH%

if defined FLAG_profiles echo Available profiles:
cd %conan_path%\profiles
for /f "tokens=*" %%F in ('dir /b /s qt-*-!PARAM_profile!*') do (
    if defined FLAG_profiles echo %%~nxF
    set "conan_profile=%%F"
)
if defined FLAG_profiles exit 0

if not defined conan_profile (
    >&2 echo Can't locate conan profiles
    exit 2
)

echo Using conan profile %conan_profile%

for /F "usebackq tokens=1,2 delims==" %%L in ("%conan_profile%") do (
    if %%L == qt6 set "QT_VERSION=%%M"
    if %%L == QT_PATH set "QT_PATH=%%M"
)

if not defined QT_VERSION (
    >&2 echo Can't read Qt version from %conan_profile%
    exit 3
)

echo Using Qt version %QT_VERSION% at %QT_PATH%

cd %JOBDIR%
if not exist conanfile.py (
    >&2 echo No conanfile.py file found in %JOBDIR%
    exit 4
)

for %%F in (%JOBDIR%) do set "module_name=%%~nF"
echo Exporting module %module_name%
conan export . %module_name%/%QT_VERSION%@qt/testing

cd %USERPROFILE%
if exist conan_test rmdir /S/Q conan_test
mkdir conan_test
cd conan_test

echo Installing module %module_name% with profile %conan_profile%
conan install %module_name%/%QT_VERSION%@qt/testing --build=missing --profile=%conan_profile%
