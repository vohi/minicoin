@ECHO OFF

REM discover build tool

SET QTCONFIGFLAGS=""
SET MAKETOOL=""
SET NINJA=""

for %%C in (ninja.exe jom.exe mingw32-make.exe nmake.exe) do set %%C=%%~$PATH:C

if NOT "%mingw32-make.exe%" == "" (
    set MAKETOOL=mingw32-make.exe
) else if NOT "%jom.exe%" == "" (
    set MAKETOOL=jom.exe
) else if NOT "%nmake.exe%" == "" (
    set MAKETOOL=nmake.exe
)

if NOT "%ninja.exe%" == "" (
    set NINJA=ninja.exe
)

set QTCONFIGFLAGS=-opengl desktop
