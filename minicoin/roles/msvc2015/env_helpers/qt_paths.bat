@echo off
SET _ROOT=C:\dev\qt5-build
cd %_ROOT%

SET PATH=%_ROOT%\qtbase\bin;%PATH%

SET PATH=%_ROOT%\qtrepotools\bin;%_ROOT%\gnuwin32\bin;%PATH%

REM Uncomment the below line when building with OpenSSL enabled. If so, make sure the directory points
REM to the correct location (binaries for OpenSSL).
REM SET PATH=C:\OpenSSL-Win32\bin;%PATH%

REM When compiling with ICU, uncomment the lines below and change <icupath> appropriately:
REM Note that -I <icupath>\include and -L <icupath>\lib need to be passed to
REM configure separately (that works for MSVC as well).
REM SET PATH=<icupath>\lib;%PATH%
SET _ROOT=
