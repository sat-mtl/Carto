#!/bin/bash

cd 3rdparty/godot-hesai/
./build.sh
cd ../..
mkdir -p carto-godot-project/bin/linux/
cp 3rdparty/godot-hesai/demo/bin/linux/* carto-godot-project/bin/linux/
