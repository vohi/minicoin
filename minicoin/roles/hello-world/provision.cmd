@echo off
setlocal ENABLEDELAYEDEXPANSION

call C:\minicoin\util\parse-opts.cmd %*

echo Hello world, %3

if NOT !FLAG_debug! == true exit 0

echo All arguments: %*
echo Named:
for %%p in (!PARAMS[@]!) do echo - %%p: !PARAM_%%p!
echo Positional:
for %%p in (!POSITIONAL[@]!) do echo - %%p
echo Flags:
for %%f in (!FLAGS[@]!) do echo - %%f