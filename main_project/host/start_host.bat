@echo off
setlocal

set "HOST_ROOT=%~dp0"
set "PYTHON_EXE=D:\conda_envs\ads807_host\python.exe"

if not exist "%PYTHON_EXE%" (
    echo [ERROR] Cannot find the configured Python environment:
    echo         %PYTHON_EXE%
    echo.
    echo Please create the Conda environment or edit PYTHON_EXE in this script.
    pause
    exit /b 1
)

pushd "%HOST_ROOT%"
"%PYTHON_EXE%" -B -m ads807 %*
set "EXIT_CODE=%ERRORLEVEL%"
popd

if not "%EXIT_CODE%"=="0" (
    echo.
    echo [ERROR] ADS807 host exited with code %EXIT_CODE%.
    pause
)

exit /b %EXIT_CODE%
