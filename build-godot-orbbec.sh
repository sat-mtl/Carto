#!/bin/bash

cd godot-orbbec/
./build.sh
cd ..
mkdir -p carto-godot-project/bin/linux/
cp godot-orbbec/demo/bin/linux/* carto-godot-project/bin/linux/
