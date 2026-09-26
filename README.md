# Animora

Free, open-source animation editor plugin for Roblox Studio — a community alternative to paid animation suites.

> Status: **Phase 0 (spikes)** — not usable yet. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Planned features

- Timeline with keyframes, scrubbing, play/loop
- Pose R6, R15 and custom Motor6D rigs
- Per-keyframe easing, copy/paste between animations, left/right mirror
- Export to / import from `KeyframeSequence`
- Later: IK, curve editor, camera and object animation, onion skin, pose library, marker-to-code, animation debugger

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

Animora adalah plugin animasi gratis dan open-source untuk Roblox Studio. Antarmuka tersedia dalam bahasa Inggris (default) dan Bahasa Indonesia. Kontribusi dan laporan bug sangat diterima lewat GitHub Issues.

## License

[MIT](LICENSE)
