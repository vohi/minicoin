@echo off

set names=
set nameCount=0
set args=
set argCount=0
set POSITIONAL=
set posCount=0
set FLAGS=
set flagCount=0

:parseargs
  if /i "%~1" == "" goto endargs

  set arg=%~1

  if "%arg:~0,2%" == "--" (
      if %argCount% LSS %nameCount% (
          set /A argCount+=1
          set args[!argCount!]=
      )
      set /A nameCount+=1
      set names[!nameCount!]=%arg:~2%
  ) else if "%arg:~0,1%" == "-" (
      if %argCount% LSS %nameCount% (
          set /A argCount+=1
          set args[!argCount!]=
      )
      set /A nameCount+=1
      set names[!nameCount!]=%arg:~1%
  ) else (
      if %nameCount% EQU %argCount% (
        set /A posCount+=1
        set POSITIONAL[!posCount!]=%arg%
      ) else (
        set /A argCount+=1
        set args[!argCount!]=%arg%
      )
  )

:loopargs
  shift
  goto :parseargs
:endargs

for /L %%i in (1,1,%nameCount%) do (
    if "!args[%%i]!" == "" (
        set /A flagCount+=1
        set flags[!flagCount!]=!names[%%i]!
        set FLAG_!names[%%i]!=true
    ) else (
        set PARAM_!names[%%i]!=!args[%%i]!
    )
)

set names=
set nameCount=
set args=
set argCount=