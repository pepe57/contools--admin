@echo off & goto DOC_END

rem USAGE:
rem   fix_installdir_perms.bat [-skip-parent-dirs] [--] <INSTALLDIR>

rem Description:
rem   Fixes the INSTALLDIR directory permissions for inner files and
rem   directories. Includes directory permissions above the INSTALLDIR
rem   directory.
rem
rem   Works for the VirtualBox setup executable version 7.0.16+.
rem
rem   Based on:
rem     https://forums.virtualbox.org/viewtopic.php?p=552778#p552778 :
rem     `Invalid installation directory message on default directory`
rem     https://www.virtualbox.org/ticket/22044 :
rem     `Can't install Virtualbox 7.0.16 outside of C:\Program Files`
rem

rem CAUTION:
rem   1. INSTALLDIR must be the end installation directory, otherwise the permissions would be overwritten everywhere!
rem   2. You must create the end installation directory if does not exist and run the script on it.
rem

rem NOTE:
rem   The elevation shell code is based on:
rem     `Uniform variant of a command line as a single argument for the mshta.exe executable and other cases` :
rem     https://github.com/andry81/contools/discussions/11

rem NOTE:
rem   A command line or a variable (ex: `__SCRIPT__`) can contain an even
rem   number of double quotes prefixed by the `\` character.
rem
rem   It can be replaced by N/2 number of quotes without the prefix or
rem   a quote with N/2-nested escape sequence:
rem
rem     \""     -> "    or \"
rem     \""""   -> ""   or \\\"
rem     \"""""" -> """  or \\\\\\\"
rem     etc
rem
rem   The meaning is to always use an even number of quotes to insert an
rem   arbitrary number of quotes with or without an escape sequence.
rem
rem   For example, in the `set` command, because
rem   the `set` command argument is started by a double quote:
rem
rem     >
rem     set "A=X \"" | & < > \"""
rem     set "B=Y \"" | & < > \"" | & < > \"""" | & < > \"""""

rem CAUTION:
rem   The environment variables does use by the shell code to workaround the
rem   `mshta.exe` command line length limitation (see the link).

rem CAUTION:
rem   The `mshta.exe` does expand all the %-escape placeholders (`%NN`).
rem   The script does not use `%` character in the shell code. In case of a
rem   change in the future you must prevent the expansion by replacing all the
rem   `%` by `%25` to avoid the command line breakage.
rem   All the `"` does process for the same reason.

rem NOTE:
rem   The `ExecuteGlobal` is used as a workaround, because the `mshta.exe`
rem   first argument must not be used with the surrounded quotes.

rem CAUTION:
rem   The `ShellExecute` does not wait a child process close.

rem CAUTION:
rem   The `cmd.exe` does expand the %-variables in the context of an elevated
rem   process. You must properly escape these to avoid the expansion before the
rem   elevation!

rem CAUTION:
rem   `\""`, `\""""`, etc expressions only has meaning inside a `.bat` script.
rem   Any attempt to use it outside of a script (including a terminal command
rem   line) will lead into incorrect expansion because a terminal command
rem   line or an `.exe` command line has their own different expansion rules
rem   including command line of the `cmd.exe` executable.

rem CAUTION:
rem   Avoid a back slash before the double quote in an executable (`.exe`)
rem   command line, otherwise a command line parse will be broken:
rem     >
rem     some.exe "... ... \"
rem                        ^ - escaped
rem     >
rem     some.exe "... ... \""
rem                        ^ - escaped
rem   To workaround:
rem     >
rem     some.exe "... ... \\"
rem                        ^ - escaped
rem     >
rem     some.exe "... ... \\""
rem                        ^ - escaped
rem
rem   A trailing double quote will be escaped in some command line parse code
rem   runtimes. But not everywhere, for example, `cmd.exe` has different rules:
rem
rem     >
rem     cmd.exe /c @echo "... ... \"
rem                               ^ - prints as is

rem NOTE:
rem   The `::"::"::` is an unexisted statement in the VBS
rem   (error: `VBScript compilation error: Expected statement`) in case of
rem   strip from a string with a valid VBS shell code. So it can be used as a
rem   VBS shell code lines delimiter in another shell code or Windows Batch
rem   script.

rem CAUTION:
rem   If you pass a parameter or set of parameters starting the first argument,
rem   then these may be skipped, due to the internal `cmd.exe` command line
rem   parse logic. The command line does not ignored if started using the slash
rem   character with the known option - `/k`, `/c` and etc.
:DOC_END

rem second `setlocal` to drop locals before a command line execution
setlocal DISABLEDELAYEDEXPANSION & setlocal

rem script names call stack, disabled due to self call and partial inheritance (process elevation does not inherit a parent process variables by default)
rem if defined ?~ ( set "?~=%?~%-^>%~nx0" ) else if defined ?~nx0 ( set "?~=%?~nx0%-^>%~nx0" ) else set "?~=%~nx0"
set "?~=%~nx0"

set "?~f0=%~f0"

set /A ELEVATED+=0

rem script flags
set FLAG_SHIFT=0
set FLAG_SKIP_PARENT_DIRS=0

:FLAGS_LOOP

rem flags always at first
set "FLAG=%~1"

if defined FLAG ^
if not "%FLAG:~0,1%" == "-" set "FLAG="

if defined FLAG (
  if "%FLAG%" == "-skip-parent-dirs" (
    set FLAG_SKIP_PARENT_DIRS=1
  ) else if not "%FLAG%" == "--" (
    echo;%?~%: error: invalid flag: %FLAG%
    exit /b -255
  ) >&2

  shift
  set /A FLAG_SHIFT+=1

  rem read until no flags
  if not "%FLAG%" == "--" goto FLAGS_LOOP
)

if %IMPL_MODE%0 NEQ 0 goto IMPL
call :IS_ADMIN_ELEVATED || goto CALL_ELEVATE_AND_EXIT

goto ELEVATED

rem CAUTIOM:
rem   Windows 7 has an issue around the `find.exe` utility and code page 65001.
rem   We use `findstr.exe` instead of `find.exe` to workaround it.
rem
rem   Based on: https://superuser.com/questions/557387/pipe-not-working-in-cmd-exe-on-windows-7/1869422#1869422

rem CAUTION:
rem   In Windows XP an elevated call under data protection flag will block the wmic tool, so we have to use `ver` command instead!

:IS_ADMIN_ELEVATED
set "WINDOWS_VER_STR=" & set "WINDOWS_MAJOR_VER=0" & for /F "usebackq tokens=1,2,* delims=[]" %%i in (`@ver 2^>nul`) do set "WINDOWS_VER_STR=%%j"
if not defined WINDOWS_VER_STR goto SKIP_VER
setlocal ENABLEDELAYEDEXPANSION & for /F "usebackq tokens=* delims="eol^= %%i in ('"!WINDOWS_VER_STR:* =!"') do endlocal & set "WINDOWS_VER_STR=%%~i"
for /F "tokens=1,2,* delims=."eol^= %%i in ("%WINDOWS_VER_STR%") do set "WINDOWS_MAJOR_VER=%%i"
:SKIP_VER
if %WINDOWS_MAJOR_VER% GEQ 6 (
  if exist "%SystemRoot%\System32\where.exe" "%SystemRoot%\System32\whoami.exe" /groups | "%SystemRoot%\System32\findstr.exe" /L "S-1-16-12288" >nul 2>nul & exit /b
) else if exist "%SystemRoot%\System32\fltmc.exe" "%SystemRoot%\System32\fltmc.exe" >nul 2>nul & exit /b
exit /b 255

:CALL_ELEVATE_AND_EXIT
for /F "tokens=* delims="eol^= %%i in ("%CD%\.") do set "CWD=%%~fi"

if "%CWD:~-1%" == "\" set "CWD=%CWD%."

rem CAUTION:
rem   The `cd "%CD%" ^& %CD:~0,2%` must be before the command, otherwise the system root will be the current directory!
rem

rem Windows Batch compatible command line with escapes
set "?@=/c @set \""IMPL_MODE=1\"" & cd \""%CWD%\"" & %CWD:~0,2% & \""%~f0\"" %* & pause"

rem shell code
set "__SCRIPT__=ExecuteGlobal(\""Set objProc = CreateObject(\""""WScript.Shell\"""").Environment(\""""Process\"""") : ::"^
::"::CreateObject(\""""Shell.Application\"""").ShellExecute objProc(\""""?0\""""), objProc(\""""?@\""""), \""""\"""", \""""runas\"""", 1 : Close()\"")"

set "__SCRIPT__=%__SCRIPT__:::"::"::=%"

rem command
set "?0="

(
  setlocal ENABLEDELAYEDEXPANSION

  if defined COMSPEC set "?0=!COMSPEC!"

  rem translate Windows Batch compatible escapes into escape placeholders
  set "__SCRIPT__=!__SCRIPT__:$=$0!"
  set "__SCRIPT__=!__SCRIPT__:\""""""=$3!"
  set "__SCRIPT__=!__SCRIPT__:\""""=$2!"
  set "__SCRIPT__=!__SCRIPT__:\""=$1!"
  set "__SCRIPT__=!__SCRIPT__:"^=$1!"

  set "?@=!?@:$=$0!"
  set "?@=!?@:\""""""=$3!"
  set "?@=!?@:\""""=$2!"
  set "?@=!?@:\""=$1!"
  set "?@=!?@:"^=$1!"

  rem translate escape placeholders into `mshta.exe` (vbs) escapes
  set "__SCRIPT__=!__SCRIPT__:$3=""""!"
  set "__SCRIPT__=!__SCRIPT__:$2=""!"
  set "__SCRIPT__=!__SCRIPT__:$1="!"
  set "__SCRIPT__=!__SCRIPT__:$0=$!"

  set "?@=!?@:$3=""""!"
  set "?@=!?@:$2=""!"
  set "?@=!?@:$1="!"
  set "?@=!?@:$0=$!"

  rem with locals drop
  for /F "tokens=* delims="eol^= %%i in ("!__SCRIPT__!") do break ^
  & for /F "usebackq tokens=* delims="eol^= %%j in ('"!?0!"') do break ^
  & for /F "usebackq tokens=* delims="eol^= %%k in ('"!?@!"') do endlocal & endlocal ^
  & set "?0=%%~j" & set "?@=%%~k" ^
  & start "" /B /WAIT "%SystemRoot%\System32\mshta.exe" vbscript:%%i
  exit /b
)

:ELEVATED
set ELEVATED=1

:IMPL
if %ELEVATED% EQU 0 call :IS_ADMIN_ELEVATED || (
  echo;%?~%: error: process must be elevated before continue.
  exit /b 255
) >&2

set "INSTALLDIR=%~1"

if not defined INSTALLDIR set INSTALLDIR=.

for /F "tokens=* delims="eol^= %%i in ("%INSTALLDIR%\.") do set "INSTALLDIR=%%~fi"

if not exist "%INSTALLDIR%" (
  echo;%~nx0: error: installation directory does not exits: "%INSTALLDIR%".
  exit /b 255
) >&2

for /F "tokens=1,* delims=\" %%i in ("%INSTALLDIR%") do set "INSTALLDIR_PREFIX=%%i" & set "INSTALLDIR_SUFFIX=%%j"

if not defined INSTALLDIR_SUFFIX (
  echo;%~nx0: error: installation directory must be not a drive root: "%INSTALLDIR%".
  exit /b 255
) >&2

:LOOP
if %FLAG_SKIP_PARENT_DIRS% EQU 0 (
  for /F "tokens=1,* delims=\" %%i in ("%INSTALLDIR_SUFFIX%") do set "INSTALLDIR_PREFIX=%INSTALLDIR_PREFIX%\%%i" & set "INSTALLDIR_SUFFIX=%%j"
) else (
  set "INSTALLDIR_PREFIX=%INSTALLDIR%"
  set "INSTALLDIR_SUFFIX="
)

setlocal ENABLEDELAYEDEXPANSION & echo;^>!INSTALLDIR_PREFIX!& endlocal
echo;

if defined INSTALLDIR_SUFFIX (
  rem not the end installation directory, without recursion
  call :CMD "%%SystemRoot%%\System32\icacls.exe" "%%INSTALLDIR_PREFIX%%" /reset /c || exit /b
  call :CMD "%%SystemRoot%%\System32\icacls.exe" "%%INSTALLDIR_PREFIX%%" /inheritance:d /c || exit /b
) else (
  rem the end installation directory, with recursion
  call :CMD "%%SystemRoot%%\System32\icacls.exe" "%%INSTALLDIR_PREFIX%%" /reset /t /c || exit /b
  call :CMD "%%SystemRoot%%\System32\icacls.exe" "%%INSTALLDIR_PREFIX%%" /inheritance:d /t /c || exit /b
)

call :CMD "%%SystemRoot%%\System32\icacls.exe" "%%INSTALLDIR_PREFIX%%" /grant "*S-1-5-32-545:(OI)(CI)(RX)" || exit /b
call :CMD "%%SystemRoot%%\System32\icacls.exe" "%%INSTALLDIR_PREFIX%%" /deny "*S-1-5-32-545:(DE,WD,AD,WEA,WA)" || exit /b
call :CMD "%%SystemRoot%%\System32\icacls.exe" "%%INSTALLDIR_PREFIX%%" /grant "*S-1-5-11:(OI)(CI)(RX)" || exit /b
call :CMD "%%SystemRoot%%\System32\icacls.exe" "%%INSTALLDIR_PREFIX%%" /deny "*S-1-5-11:(DE,WD,AD,WEA,WA)" || exit /b

echo;

if not defined INSTALLDIR_SUFFIX exit /b 0

goto LOOP

:CMD
echo;^>%*
(
  %*
)
