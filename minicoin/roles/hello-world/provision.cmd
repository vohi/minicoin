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
    for %%a in (!PARAM_%%p[@]!) do echo   - %%a
  ) else (
    echo - %%p: !PARAM_%%p!
  )
)
echo Positional:
for %%p in (!POSITIONAL[@]!) do echo - %%p
echo Flags:
for %%f in (!FLAGS[@]!) do echo - %%f