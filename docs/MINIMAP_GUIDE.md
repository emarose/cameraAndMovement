# Minimap Implementation Guide

## Overview
The minimap is now fully implemented in your Godot game! It displays a top-down view of the current map chunk with the player position marked.

## Components

### 1. **Minimap.tscn** - The minimap UI element
- **Location**: `res://scenes/Minimap.tscn`
- **Features**:
  - 200x200 pixel display in the top-right corner
  - Stylized border (blue outline on dark background)
  - Uses a SubViewportContainer to render a 3D camera view as 2D UI
  - Automatically positioned in the HUD

### 2. **minimap.gd** - Camera script
- **Location**: `res://scenes/minimap.gd`
- **Features**:
  - Automatically detects the player using the "player" group
  - Maintains a top-down orthographic view (100 units above the map)
  - Follows player position smoothly
  - Configurable zoom level through `zoom_level` export variable

### 3. **BaseMap.gd** - Map initialization
- **Location**: `res://scenes/maps/BaseMap.gd`
- **Features**:
  - Automatically configures terrain visibility for minimap
  - Sets all terrain to render on both layer 1 (main view) and layer 2 (minimap)

### 4. **Player.tscn** - Player marker
- **Component**: MinimapMarker (a sphere mesh on layer 2)
- **Location**: Under Player node > MinimapMarker
- **Features**:
  - Visible only in minimap (layer 2 only)
  - Shows player position as an orange sphere

## Layer System

The game uses a 2-layer rendering system:

| Layer | Purpose | Visibility |
|-------|---------|-----------|
| **Layer 1** | Main game view | Player's main camera |
| **Layer 2** | Minimap view | Minimap camera only |

### Current Layer Configuration:
- **Terrain**: Renders on both layers 1+2 (main view + minimap)
- **Player**: Main body on layer 1 (hidden from minimap)
- **MinimapMarker**: On layer 2 only (visible only on minimap)
- **Minimap Camera**: Cull mask set to 2 (sees layer 2 only)

## How to Customize

### Change Minimap Size
Edit `Minimap.tscn` and modify the `custom_minimum_size` property:
```
# Current: 200x200
custom_minimum_size = Vector2(300, 300)  # Larger minimap
```

### Change Minimap Position
Edit the PanelContainer positioning properties in `Minimap.tscn`:
```
offset_left = -244.0    # Distance from right edge
offset_top = 38.0       # Distance from top edge
```

### Adjust Zoom Level
Edit the `zoom_level` export variable in `minimap.gd`:
```gdscript
@export var zoom_level: float = 30.0  # Smaller = more zoomed in
```

### Change Camera Height
For a different perspective, modify in `minimap.gd`:
```gdscript
@export var height: float = 100.0  # Higher = more top-down
```

### Change Border Color
Edit `Minimap.tscn` StyleBoxFlat border color:
```
border_color = Color(0.4, 0.7, 1.0, 1.0)  # Current: Cyan blue
```

### Change MinimapMarker Color/Style
In `Player.tscn`, modify the MinimapMarker sphere material; currently orange-red at color `(0.6117647, 0.23921569, 0, 1)`

## Adding Elements to Minimap

To make any game object visible on the minimap:

### 1. Static Objects (Terrain, Buildings)
Already configured via `BaseMap.gd` - terrain automatically gets layers set to 3 (1+2)

### 2. Dynamic Objects (NPCs, Enemies, Bosses)
Add a marker/indicator node with `layers = 3` (visible on both main and minimap):

```gdscript
# In your NPC/Enemy scene
func _ready():
    # Create a small indicator sphere for the minimap
    var minimap_marker = MeshInstance3D.new()
    minimap_marker.mesh = SphereMesh.new()
    minimap_marker.layers = 3  # Visible on both main view and minimap
    # Adjust material to distinguish from player marker
    add_child(minimap_marker)
```

Or simply set the object's layer property:
```gdscript
var npc = load("res://scenes/NPC_Merchant.tscn").instantiate()
# To make it visible on minimap:
for child in npc.get_children():
    if child is CanvasItem or child is Node3D:
        child.layers = 3  # Shows on both views
```

## Common Controls

| Button | Action |
|--------|--------|
| **N** | Toggle skill tree (no minimap button yet) |
| **S** | Toggle skills UI |
| **E** | Toggle equipment UI |
| **I** | Toggle inventory UI |

## Troubleshooting

### Minimap appears blank
1. Check that terrain nodes have been set to layers = 3 (see `BaseMap.gd`)
2. Verify minimap camera has `cull_mask = 2`
3. Ensure player node is in the "player" group (required for script auto-detection)

### Player marker not showing
1. Verify MinimapMarker exists as child of Player
2. Check MinimapMarker has `layers = 2`
3. Ensure the mesh material is visible (currently orange sphere)

### Wrong perspective
1. Adjust `height` value in minimap.gd (currently 100.0)
2. Modify `size` in Camera3D (currently 30.0 for orthographic view)

### Performance issues
- Reduce SubViewport size if needed
- Disable terrain simplification in minimap view by adjusting LOD if applicable

## Future Enhancements

Consider implementing:
- [ ] Zoom in/out controls for minimap
- [ ] Rotation indicator (showing player facing direction)
- [ ] Quick-click teleport from minimap
- [ ] Enemy/NPC indicators (different colors)
- [ ] Quest marker display
- [ ] Fog of war / explored areas
- [ ] Minimap toggle button in HUD
