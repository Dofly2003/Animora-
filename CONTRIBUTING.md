# Contributing to Animora

Thanks for helping! Issues and pull requests in English or Bahasa Indonesia are welcome.

1. Fork the repo and create a branch per feature (`feat/timeline-zoom`, `fix/mirror-r6`).
2. Run `stylua src tests scripts` and `selene src` before committing.
3. Add or update tests in `tests/` for anything in `src/Core`.
4. Test Studio features on the R6, R15 and custom rigs in `test-place/`.
5. Open a pull request describing what changed and how you tested it.

## Clean-room rule

Animora is an independent implementation. Do **not** copy code, icons, UI layouts, names or documentation from other animation plugins (including Moon Animator). Reading another plugin's *saved data format* to support importing is fine; copying its source is not.

## Adding a UI string

Add the key to `src/Localization/en.luau` and, if you can, `src/Localization/id.luau`. Missing Indonesian keys fall back to English.
