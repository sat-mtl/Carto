@echo off

cd /d "%~dp0"

pushd "%~dp0godot-orbbec"

cmd /c call "build_windows.cmd"

:: exit if build_windows.cmd failed
if %errorlevel% neq 0 (
   exit /b
)

:: go back to the scripts directory to copy the build's dlls
cd /d "%~dp0"

set GODOT_DEBUG_DLL=%~dp0godot-orbbec\bin\windows\godot-orbbec.windows.template_debug.x86_64.dll
set GODOT_RELEASE_DLL=%~dp0godot-orbbec\bin\windows\godot-orbbec.windows.template_release.x86_64.dll
SET ORBBEC_SDK_DLL=%~dp0godot-orbbec\build\bin\Debug\OrbbecSDK.dll
SET TARGET_DIR=%~dp0carto-godot-project\bin\windows
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
)

copy /Y "%GODOT_DEBUG_DLL%" "%TARGET_DIR%\godot-orbbec.windows.template_debug.x86_64.dll"
copy /Y "%GODOT_RELEASE_DLL%" "%TARGET_DIR%\godot-orbbec.windows.template_release.x86_64.dll"

copy /Y "%ORBBEC_SDK_DLL%" "%TARGET_DIR%\OrbbecSDK.dll"

echo end of script.

pause
