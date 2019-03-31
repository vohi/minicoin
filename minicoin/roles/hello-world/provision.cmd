@echo off
setlocal ENABLEDELAYEDEXPANSION

call C:\minicoin\util\parse-opts.cmd %*

set "welcome=Hello world,"
if DEFINED PARAM_welcome set welcome=%PARAM_welcome%

echo %welcome% %3

if NOT !FLAG_debug! == true exit 0

echo All arguments: %*
echo Named:
for %%p in (!PARAMS[@]!) do (
  if NOT "!PARAM_%%p[1]!" == "" (
    echo - %%p
    for /L %%i in (0, 1, !PARAM_%%p[#]!) do echo   - !PARAM_%%p[%%i]!
  ) else (
    echo - %%p: !PARAM_%%p!
  )
)
echo Positional:
for /L %%i in (0, 1, !POSITIONAL[#]!) do echo - !POSITIONAL[%%i]!
echo Flags:
for %%f in (!FLAGS[@]!) do echo - %%f