#!/bin/bash

cd 3rdparty/godot-blobtrack-3d/
./build.sh
cd ../..
mkdir -p carto-godot-project/bin/linux/
mkdir -p carto-godot-project/addons/blobtrack3d/
cp -r 3rdparty/godot-blobtrack-3d/addon/blobtrack3d/* carto-godot-project/addons/blobtrack3d/
cp 3rdparty/godot-blobtrack-3d/demo/bin/blobtrack3d.gdextension carto-godot-project/bin/blobtrack3d.gdextension
cp 3rdparty/godot-blobtrack-3d/bin/linux/blobtrack3d.linux.template_debug.x86_64.so carto-godot-project/bin/linux/
cp 3rdparty/godot-blobtrack-3d/bin/linux/blobtrack3d.linux.template_release.x86_64.so carto-godot-project/bin/linux/
