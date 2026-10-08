# Animora

Free, open-source animation editor plugin for Roblox Studio — a community alternative to paid animation suites.

> Status: **MVP done, preparing the beta (v0.1.0)**. Usable for real work, but expect rough edges. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Features

- Timeline with keyframes, scrubbing, play/loop, frame stepping and FPS
- Rotate gizmo with auto-key; pick single body parts in the viewport
- Select, move, delete, copy/paste and left/right mirror keyframes
- Per-keyframe easing
- R6, R15 and AnimationConstraint (Avatar Joint Upgrade) rigs; several animations per rig
- Studio undo/redo (Ctrl+Z / Ctrl+Y) and bindable shortcuts
- Autosave in the place; export to / import from `KeyframeSequence`, saved clips or an asset ID
- 20 starter templates: Idle, Walk, Run, Jump, Wave, a Scared set, Flashlight, a horror ghost set (Kuntilanak, Pocong, Tuyul) and a NISKALA everyday set

### Planned

- Before the beta: move gizmo for the root joint, toolbar layout, rig-type label, plugin icon, user guide
- v1: IK, curve editor, camera and object animation, multiple rigs, onion skin, pose library
- v2: markers with a Luau code generator, animation debugger

UI language: English (default) and Bahasa Indonesia, switchable in the plugin.

## Development

Requirements: [Rokit](https://github.com/rojo-rbx/rokit), VS Code with the Rojo, Luau Language Server, StyLua and Selene extensions, and the Rojo Studio plugin.

```bash
rokit install          # installs rojo, wally, stylua, selene (versions in rokit.toml)
wally install          # downloads Fusion and Jest into Packages/ and DevPackages/
rojo build -o build/Animora.rbxmx
```

Copy `build/Animora.rbxmx` into your Studio plugins folder (`%LOCALAPPDATA%\Roblox\Plugins`) and restart Studio, or use **Plugins → Plugins Folder**.

Live sync while developing: `rojo serve`, then connect from the Rojo plugin in Studio.

### Tests

```bash
rojo build test.project.json -o build/tests.rbxl
```

Open `build/tests.rbxl` in Studio and press **Run** (F8). Results appear in the Output window.

### Lint and format

```bash
stylua src tests scripts
selene src
```

## Project layout

| Folder | Contents |
| --- | --- |
| `src/Core` | Pure Luau: data model, interpolation, undo/redo, mirror (unit-tested) |
| `src/Studio` | Studio integration: rig binding, gizmos, import/export, saving |
| `src/UI` | Fusion UI components and Studio theme |
| `src/Localization` | English and Indonesian strings |
| `tests` | Jest-lua specs for `src/Core` |
| `test-place` | Test place with R6, R15 and custom rigs |
| `docs` | Roadmap and spike results |

## Bahasa Indonesia

Animora adalah plugin animasi gratis dan open-source untuk Roblox Studio. Tahap MVP sudah selesai dan sekarang sedang menuju beta (v0.1.0): timeline, gizmo putar, easing, mirror, ekspor/impor, autosave dan 20 template animasi sudah bisa dipakai. Antarmuka tersedia dalam bahasa Inggris (default) dan Bahasa Indonesia. Kontribusi dan laporan bug sangat diterima lewat GitHub Issues.

## License

[MIT](LICENSE)
