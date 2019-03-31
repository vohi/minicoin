@echo off
REM Needs to be set in the calling script
REM setlocal ENABLEDELAYEDEXPANSION

set names=
set nameCount=0
set args=
set argCount=0
set POSITIONAL[@]=
set posCount=0
set FLAGS[@]=
set flagCount=0
set PARAMS[@]=

:parseargs
  if /i "%~1" == "" goto endargs

  set "arg=%~1"

  if "%arg:~0,2%" == "--" (
    if %argCount% LSS %nameCount% (
      set args[!argCount!]=
      set /A argCount+=1
    )
    set names[!nameCount!]=%arg:~2%
    set /A nameCount+=1
  ) else if "%arg:~0,1%" == "-" (
    if %argCount% LSS %nameCount% (
      set args[!argCount!]=
      set /A argCount+=1
    )
    set names[!nameCount!]=%arg:~1%
    set /A nameCount+=1
  ) else (
    if %nameCount% EQU %argCount% (
      set POSITIONAL[!posCount!]=%arg%
      if "!POSITIONAL[@]!" == "" (
        set "POSITIONAL[@]=%arg%"
        set /A "POSITIONAL[#]=1"
      ) else (
        set "POSITIONAL[@]=!POSITIONAL[@]! %arg%"
        set /A "POSITIONAL[#]+=1"
      )
      set /A posCount+=1
    ) else (
      set "args[!argCount!]=%arg%"
      set /A argCount+=1
    )
  )
  shift
  goto :parseargs
:endargs

for /L %%i in (0,1,%nameCount%) do (
  set "name=!names[%%i]!"
  if "!args[%%i]!" == "" (
    if NOT "!name!" == "" (
      set "name=!name:-=_!"
      set "fname=FLAG_!name!"
      if "!FLAGS[@]!" == "" (
        set "FLAGS[@]=!name!"
        set /A "FLAGS[#]=1"
      ) else (
        set "FLAGS[@]=!FLAGS[@]! !name!"
        set /A "FLAGS[#]+=1"
      )
      set "FLAGS[!flagCount!]=!name!"
      set "!fname!=true"
      set /A flagCount+=1
    )
  ) else (
    set "name=!name:-=_!"
    set "pname=PARAM_!name!"
    for %%j in (!pname![@]) do set "value=!%%j!"
    if NOT "!value!" == "" (
      set "newvalue=!args[%%i]!"
      for %%j in (!pname![#]) do set /A "length=!%%j!"
      set /A index=!length!+1
      set /A "!pname![#]=!index!"
      set "!pname![!index!]=!newvalue!"
      set "!pname![@]=!value! !newvalue!"
    ) else (
      set "value=!args[%%i]!"
      set "!pname!=!value!"
      REM always assume we end up with an array
      set "!pname![@]=!value!"
      set "!pname![0]=!value!"
      set /A "!pname![#]=0"
      if "!PARAMS[@]!" == "" (
        set "PARAMS[@]=!name!"
        set /A "PARAMS[#]=1"
      ) else (
        set "PARAMS[@]=!PARAMS[@]! !name!"
        set /A "PARAMS[#]+=1"
      )
    )
  )
)

REM cleanup "namespace"
set names=
set nameCount=
set args=
set argCount=
set posCount=
set flagCount=