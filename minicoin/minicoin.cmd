@echo off

set "MINICOIN_PROJECT_DIR=%cd%"
set "minicoin_dir=%~dp0"
cd %minicoin_dir%

call vagrant %*

cd "%MINICOIN_PROJECT_DIR%"
