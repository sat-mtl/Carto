@echo off
setlocal

cd /d "%~dp0"

set HESAI_DIR=%~dp03rdparty\godot-hesai
set TARGET_DIR=%~dp0carto-godot-project\bin\windows

:: ===========================================
:: Build template_debug
:: ===========================================
:: GODOTCPP_TARGET is cached by CMake, so clear the cache to switch targets
if exist "%HESAI_DIR%\build\CMakeCache.txt" del /q "%HESAI_DIR%\build\CMakeCache.txt"
set BUILD_RELEASE=
pushd "%HESAI_DIR%"
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
if exist "%HESAI_DIR%\build\CMakeCache.txt" del /q "%HESAI_DIR%\build\CMakeCache.txt"
set BUILD_RELEASE=YES
pushd "%HESAI_DIR%"
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

copy /Y "%HESAI_DIR%\bin\windows\godot-hesai.windows.template_debug.x86_64.dll" "%TARGET_DIR%\godot-hesai.windows.template_debug.x86_64.dll"
copy /Y "%HESAI_DIR%\bin\windows\godot-hesai.windows.template_release.x86_64.dll" "%TARGET_DIR%\godot-hesai.windows.template_release.x86_64.dll"

echo end of script.

pause
