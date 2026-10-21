@echo off
rem Build the bitstream from the command line (no GUI).
rem Usage: build.bat [jobs]
rem Override the Vivado install with the VIVADO_DIR environment variable.
setlocal

if "%VIVADO_DIR%"=="" set "VIVADO_DIR=C:\Xilinx\Vivado\2022.1"
if not exist "%VIVADO_DIR%\bin\vivado.bat" (
    echo Vivado not found at "%VIVADO_DIR%". Set VIVADO_DIR to your install.
    exit /b 1
)

set "JOBS=%~1"
if "%JOBS%"=="" set "JOBS=%NUMBER_OF_PROCESSORS%"

cd /d "%~dp0"
if not exist output mkdir output
call "%VIVADO_DIR%\bin\vivado.bat" -mode batch -nojournal ^
    -log output\build.log ^
    -source scripts\build.tcl -tclargs %JOBS%
exit /b %ERRORLEVEL%
