@echo off
setlocal

cd /d "%~dp0"

set BLOBTRACK_DIR=%~dp03rdparty\godot-blobtrack-3d
set TARGET_DIR=%~dp0carto-godot-project\bin\windows
set ADDON_DIR=%~dp0carto-godot-project\addons\blobtrack3d

:: ===========================================
:: Build template_debug
:: ===========================================
:: GODOTCPP_TARGET is cached by CMake, so clear the cache to switch targets
if exist "%BLOBTRACK_DIR%\build\CMakeCache.txt" del /q "%BLOBTRACK_DIR%\build\CMakeCache.txt"
set BUILD_RELEASE=
pushd "%BLOBTRACK_DIR%"
cmd /c call "build_windows.cmd"
if %errorlevel% neq 0 (
   popd
   echo Debug build failed.
   pause
   exit /b %errorlevel%
)
popd

:: ===========================================
:: Build template_release
:: ===========================================
if exist "%BLOBTRACK_DIR%\build\CMakeCache.txt" del /q "%BLOBTRACK_DIR%\build\CMakeCache.txt"
set BUILD_RELEASE=YES
pushd "%BLOBTRACK_DIR%"
cmd /c call "build_windows.cmd"
if %errorlevel% neq 0 (
   popd
   echo Release build failed.
   pause
   exit /b %errorlevel%
)
popd
set BUILD_RELEASE=

:: ===========================================
:: Copy build results into the Carto Godot project
:: ===========================================
cd /d "%~dp0"

if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
if not exist "%ADDON_DIR%" mkdir "%ADDON_DIR%"

xcopy /E /I /Y "%BLOBTRACK_DIR%\addon\blobtrack3d" "%ADDON_DIR%"
copy /Y "%BLOBTRACK_DIR%\demo\bin\blobtrack3d.gdextension" "%~dp0carto-godot-project\bin\blobtrack3d.gdextension"
copy /Y "%BLOBTRACK_DIR%\bin\windows\blobtrack3d.windows.template_debug.x86_64.dll" "%TARGET_DIR%\blobtrack3d.windows.template_debug.x86_64.dll"
copy /Y "%BLOBTRACK_DIR%\bin\windows\blobtrack3d.windows.template_release.x86_64.dll" "%TARGET_DIR%\blobtrack3d.windows.template_release.x86_64.dll"

echo end of script.

pause
