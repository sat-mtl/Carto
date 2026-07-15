# Carto release notes

## Carto 0.1.0 (2026-07-15)

### Features
- Rename PointMapper to Carto
- Hesai lidar integration (tested with Pandar 40P)
- Persistent user settings (ui scaling and save/load file path)
- Current .carto file path and edited marker in program title
- Save and load the 3D viewport camera's location
- Add an "active" toggle to network outputs
- Rework of camera UI
  - Merge camera settings and point clouds settings in a single tab
  - Add 3D camera icon. Click on them to gizmo select
  - Point cloud highlight when hovering over a camera or when they are gizmo-selected
  - Scroll to and highlight the menu item of a camera when gizmo-selecting a point cloud
  - Add camera names
  - Add a dedicated delete button for every camera
  - Change ui affordance to "toggle centroïd" to "rotation pivot" radio buttons
  - Device type selection with debug device being individually selectable
- Rework crop region ui
  - Change appearance
  - Add clickable handles that allows gizmo selection of the crop region
  - highlight when selected
  - disable rotation
- More responsive UI and UI scaling setting
- Add a "File" menu with a save-as option
- Opening a .carto file at startup from a command line argument
- 3D viewport camera manipulator gizmo
- Add a log window and add toast notifications when errors/warnings/other logs are shown
- Update to godot 4.7
- NDI output section rework

### Fixes and performance improvements
- Direct GPU upload of orbbec points
- Start cameras in a worker thread to prevent ui freezes
- Don't consider gizmo select/deselect in the undo-redo stack
- Fix centroid behaviours so that the point cloud never moves in space when changing its rotation pivot
- Fix undo-redo behaviour of group selection
- Fix undo-redo sometimes double-counting some point cloud transform changes
- Stability and performance improvements for TCP transfer
- Fix x axis mirroring of orbbec point clouds
- Better input handling management between 3D viewport and UI elements
- TCP transfer : correctly sends a frame with 0 points when there are no active points anymore

## Carto 0.0.1 (2026-04-17)

Features

- NDI output improvements !25, !22
- Specify Orbbec input format !32
- Settings page !27
- Save, load and autosave !30, !19
- Overall performance increase !35, !14
- FPS monitoring per camera !23
- Network output with TCP and MQTT !17
- Better gizmo behaviour !18
- All UI buttons work !38
- Improve build script for godot-orbbec !15
- Remove camera IP from list when selected !20
- Adjust point transparency !31


## Carto 0.0.0 (2026-02-27)

* Alpha Release Carto-Godot

Features

- Windows build
- Point cloud thinning sliders
- Perspective buttons
- Crop region activation button
- Crop region resizing
- NDI outputs
- Undo/Redo for most actions
