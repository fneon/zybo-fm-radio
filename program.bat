@echo off
rem Program the bitstream into the Zybo Z7-20 over the USB-JTAG attached to a
rem remote host, using openFPGALoader there. Configuration is volatile (SRAM):
rem it is lost on power cycle.
rem Usage: program.bat [path\to\file.bit]     (default: output\LO.bit)
rem Override the host with the FPGA_HOST environment variable (default: ca1).
setlocal

if "%FPGA_HOST%"=="" set "FPGA_HOST=ca1"

cd /d "%~dp0"
set "BIT=%~1"
if "%BIT%"=="" set "BIT=output\LO.bit"
if not exist "%BIT%" (
    echo Bitstream "%BIT%" not found. Run build.bat first.
    exit /b 1
)

set "REMOTE_BIT=/tmp/zybo-fm-radio-%USERNAME%.bit"

echo Copying %BIT% to %FPGA_HOST%:%REMOTE_BIT% ...
scp -q "%BIT%" "%FPGA_HOST%:%REMOTE_BIT%" || exit /b 1

echo Programming FPGA on %FPGA_HOST% ...
ssh %FPGA_HOST% "openFPGALoader -b zybo_z7_20 '%REMOTE_BIT%'; rc=$?; rm -f '%REMOTE_BIT%'; exit $rc"
exit /b %ERRORLEVEL%
