#!/bin/bash

cd godot-hesai/
./build.sh
cd ..
mkdir -p carto-godot-project/bin/linux/
cp godot-hesai/demo/bin/linux/* carto-godot-project/bin/linux/
