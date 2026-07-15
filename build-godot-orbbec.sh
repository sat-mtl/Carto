#!/bin/bash

cd 3rdparty/godot-orbbec/
./build.sh
cd ../..
mkdir -p carto-godot-project/bin/linux/
cp 3rdparty/godot-orbbec/demo/bin/linux/* carto-godot-project/bin/linux/
