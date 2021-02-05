@echo off
setlocal
setlocal enabledelayedexpansion

set PARSE_OPTS_FLAGS=flag4
set args=pos1 %USERPOFILE% --param1 value1 --param2 value2 pos3 --flag1 --param3 value3 --array "a 1" --array "a 2" --flag2 --array a3 "pos 4" --flag3 --flag4 pos5 --param4 "--value4 123 --value5" -- pass "pass through" --pass
set /A errors=0
set debug=false

if "%1" == "--debug" (
  set debug=true
  shift
  set "args=%*"
)

call ..\util\parse-opts.cmd %args%

if "%debug%" == "true" (
  echo Positional: !POSITIONAL[@]!
  for %%p in (!POSITIONAL[@]!) do echo - %%p
  echo Flags: !FLAGS[@]!
  for %%f in (!FLAGS[@]!) do echo - %%f
  echo Params: !PARAMS[@]!
  for %%p in (!PARAMS[@]!) do echo - %%p: !PARAM_%%p!
  echo Pass-through: !PASSTHROUGH!
  exit /B
)

call :assert "!POSITIONAL[@]!" "pos1 %USERPROFILE% pos3 pos 4 pos5"
call :assert "!POSITIONAL[#]!" 5
call :assert "!POSITIONAL[0]!" pos1
call :assert "!POSITIONAL[1]!" %USERPROFILE%
call :assert "!POSITIONAL[2]!" pos3
call :assert "!POSITIONAL[3]!" "pos 4"
call :assert "!POSITIONAL[4]!" "pos5"

call :assert "!FLAGS[@]!" "flag1 flag2 flag3 flag4"
call :assert "!FLAGS[#]!" 4
call :assert "!FLAG_flag1!" true
call :assert "!FLAG_flag2!" true
call :assert "!FLAG_flag3!" true
call :assert "!FLAG_flag4!" true
call :assert "!FLAG_flag5!" ""

call :assert "!PARAMS[@]!" "param1 param2 param3 array param4"
call :assert "!PARAMS[#]!" 5
call :assert "!PARAM_param1!" "value1"
call :assert "!PARAM_param2!" "value2"
call :assert "!PARAM_param3!" "value3"
call :assert "!PARAM_array!" "a 1"
call :assert "!PARAM_param4!" "--value4 123 --value5"

call :assert "!PARAM_array[@]!" "a 1 a 2 a3"
call :assert "!PARAM_array[0]!" "a 1"
call :assert "!PARAM_array[1]!" "a 2"
call :assert "!PARAM_array[2]!" "a3"

call :assert "!PASSTHROUGH[@]!" "pass pass through --pass"
call :assert "!PASSTHROUGH[#]!" 3
call :assert "!PASSTHROUGH[0]!" "pass"
call :assert "!PASSTHROUGH[1]!" "pass through"
call :assert "!PASSTHROUGH[2]!" "--pass"

goto :result

:assert

@echo off
REM echo verifying "%~1" == "%~2"
if "%~1" == "%~2" (
  REM echo PASS "%~1" equals "%~2"
) else (
  echo FAIL "%~1" vs "%~2"
  set /A errors+=1
)
exit /B

:result

if NOT %errors% == 0 (
  echo %errors% errors!
) else (
  echo No errors
)
