# PointMapper

![here](Assets/UI.png)

PointMapper est un outil de fusion de données de profondeur qui a été développé pour le projet de recherche en interaction collective de la SAT.


## Builder pointmapper-native


### Sur Ubuntu 24.04:
```
cd pointmapper-native
sudo apt update
sudo apt install -y --no-install-recommends cmake build-essential git wget python3-pip libglib2.0-dev libgl1-mesa-dev libvulkan-dev libxkbcommon-dev libfontconfig-dev libfreetype-dev libdbus-1-dev
pip install aqtinstall --break-system-packages
aqt install-qt linux desktop 6.10 --modules qtshadertools qtquick3d
mkdir build
cmake -B build -DCMAKE_PREFIX_PATH={le path que aqt vous a donné et qui finit par 6.10.0/gcc_64}
cmake --build build --parallel
```

### Sur windows avec Msys2

Installez mys2 puis lancez le shell `CLANG64` puis

```
cd pointmapper-native
pacman -S pactoys
pacboy -S qt6-base:p qt6-declarative:p qt6-quick3d:p cmake:p ninja:p
pacboy -S clang
cmake -B build -GNinja
cmake --build build
```
