# Animora user guide

A short walk through everything Animora does today. Indonesian version: [PANDUAN.md](PANDUAN.md).

## 1. Install and open

1. Get Animora free from the [Creator Store](https://create.roblox.com/store/asset/116677988518638/Animora) (Studio installs it for you), or copy `Animora.rbxmx` from a GitHub release into your Studio plugins folder (Studio: **Plugins → Plugins Folder**) and restart Studio.
2. Click **Animora** in the **Plugins** tab. The editor opens as a panel at the bottom of Studio.
3. Pick your language with the **EN / ID** buttons (top right of the panel).

## 2. Pick a rig

- Click any body part of a character in the viewport. Animora selects the rig and that part's joint.
- Clicks go through hair, clothing and other accessories, and a click just beside a thin limb still counts.
- The status line (third row) shows the rig, its type (**R15**, **R6**, **Custom rig**, plus **Constraint** for Avatar Joint Upgrade avatars) and the selected joint.
- You can also select a joint by clicking its row in the timeline.

Supported: R6, R15, custom Motor6D rigs and AnimationConstraint avatars. Skinned (bone) meshes are not supported yet.

## 3. Pose

There are two gizmo modes. Switch with the toolbar buttons or with **R** and **T** while the mouse is over the viewport.

| Mode | What it does |
| --- | --- |
| **Rotate (R)** | Rings around the selected part. Drag a ring to rotate the joint. |
| **Move (T)** | Arrows on the root (LowerTorso on R15, Torso on R6). Drag to raise, lower or shift the whole body. Moves snap to 0.05 studs. Other joints always show the rotate rings. |

Every drag creates or updates a keyframe at the playhead as soon as you release the mouse (auto-key). **Ctrl+Z / Ctrl+Y** undo and redo it, together with the rest of Studio's history.

## 4. Timeline

- **Scrub:** drag on the ruler at the top. **Zoom:** mouse wheel. **Pan:** Shift + mouse wheel.
- **Step:** `|<` and `>|` jump to the previous / next keyframe, `<` and `>` move one frame.
- **Select keyframes:** click a marker; Shift or Ctrl + click adds to the selection; drag over empty space to box-select.
- **Move keyframes:** drag selected markers sideways. They snap to whole frames.

## 5. Edit keyframes

| Button | What it does |
| --- | --- |
| **Copy** | Copies the selected keyframes, or the whole pose at the playhead when nothing is selected. |
| **Paste** | Pastes at the playhead. |
| **Delete** | Deletes the selected keyframes. |
| **Mirror** | Mirrors the selected joint left/right, or the whole pose when no joint is selected. |
| **Easing** | Opens the easing panel: select keyframes first, then pick a style and direction. Easing shapes the motion towards the next keyframe. |

## 6. Animations and clip settings

The first toolbar row holds the clip settings:

- **Anim: name** opens the animation list of this rig: **New**, **Duplicate**, **Rename**, **Delete**, and **From template** (20 starters: Idle, Walk, Run, Jump, Wave, a Scared set, Flashlight, a ghost set and a NISKALA set). Templates are starting points; press Play and adjust the poses.
- **Length** in seconds (type a value and press Enter).
- **Loop** on or off.
- **FPS** cycles 24 → 30 → 60. Keyframes keep their time in seconds.
- **Priority** cycles Core → Idle → Movement → Action → Action2 → Action3 → Action4.

Play / pause with the **Play** button in the second row.

## 7. Saving

Animora saves automatically into the place, so your work travels with the `.rbxl` file and Team Create:

- `ServerStorage > AnimoraSaves > Rigs > <rig name>` holds each rig's animations.

Save the place as usual (Ctrl+S). Press Run (F8) or Play to test: the rig goes back to its rest pose so the game starts clean.

## 8. Export and publish

1. Press **Export**. The animation is written as a KeyframeSequence to `ServerStorage > RBX_ANIMSAVES > <rig name>` and selected.
2. Right-click it → **Save to Roblox**, or open it in Roblox's own Animation Editor and publish from there.
3. Copy the animation's asset ID and use it in your game (`rbxassetid://<id>`).

## 9. Camera (cutscenes)

The **[ Camera ]** and **FOV (zoom)** rows at the top of the timeline animate the camera together with the rig.

1. Move the Studio camera to the shot you want, put the playhead where it should be, and press **Key camera**. The view and its field of view are keyed together.
2. Type a value (1-120) in the **FOV** box (third toolbar row) and press Enter to key a zoom at the playhead.
3. Turn on **View camera** to look through the animated camera while scrubbing or playing. Turn it off before framing the next shot.
4. In the viewport, a purple line shows the camera's path, a small orange camera marks each keyframe (white when selected) and a red dot shows where the camera is at the playhead.

Camera keys ease, move, copy and delete like any other keys. When a key looks at the character, the camera orbits around it between keys instead of cutting a straight line.

**Export** also writes the camera:

- `ReplicatedStorage > AnimoraCameras > <animation name>`: the shot (a ModuleScript).
- `ReplicatedStorage > AnimoraCamera`: the player module.

Play it from a LocalScript:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimoraCamera = require(ReplicatedStorage.AnimoraCamera)
local shot = require(ReplicatedStorage.AnimoraCameras.ColdOpen)

local playing = AnimoraCamera.play(shot) -- options: origin, speed, restore, onEnded
playing:Wait() -- the camera goes back to the player when the shot ends
```

Pass `origin = character.HumanoidRootPart.CFrame` to replay the shot around a character standing somewhere else. Start the character's animation at the same moment to keep both in sync.

## 10. Import

Press **Import**:

- If a KeyframeSequence is selected in the Explorer, it is imported straight away.
- Otherwise a menu lists the animations saved in the place (`RBX_ANIMSAVES`) and lets you load one by asset ID. Curve animations cannot be imported yet.

## 11. Shortcuts

Animora's commands are Studio plugin actions. Give them keys under **File → Customize Shortcuts** (search for "Animora"): Play / Pause, Next / Previous frame, Next / Previous keyframe, Copy, Paste, Delete keyframes, Mirror, Rotate mode, Move mode. **R** and **T** work in the viewport without setting anything up.

## 12. Troubleshooting

| Problem | Try this |
| --- | --- |
| A click selects the whole model | Click the body part again; Animora picks it as soon as its panel is open. |
| "has no Motor6D or AnimationConstraint joints" | The model is not a rig Animora can drive (for example a skinned mesh). |
| No arrows in Move mode | Arrows only appear on the root joint; press T to select it. |
| R / T do nothing | Click once in the viewport so it has focus, or use the toolbar buttons. |
| The rig looks posed after closing Animora | Open Animora and close it again; it restores the rest pose. |

Found a bug or missing a feature? Open an issue on [GitHub](https://github.com/Dofly2003/Animora-/issues).
