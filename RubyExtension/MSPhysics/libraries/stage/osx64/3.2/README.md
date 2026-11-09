# stage/osx64/3.2 — macOS 64-bit, Ruby 3.2.2 (SketchUp 2024 / 2025 / 2026)

This directory holds the macOS 64-bit native extension for **Ruby 3.2.2**,
shared by SketchUp 2024, 2025 and 2026 (all three embed Ruby 3.2.2).

## What goes here

| File | Source | Notes |
|---|---|---|
| `msp_lib.bundle` | CI jobs `build-macos-3.2-x86_64` + `build-macos-3.2-arm64`, merged by the `package` job with `lipo -create` | **Universal binary: must contain both `x86_64` and `arm64` slices** (`lipo -info` shows `x86_64 arm64`). The two architectures are built separately because Ruby 3.2 ships a different `config.h` per architecture. |

## What does NOT go here

- `newton.dylib`, `libSDL2-2.0.0.dylib`, `libSDL2_mixer-2.0.0.dylib` live in
  the parent `osx64/` directory — they are Ruby-independent and shared by
  the 3.2 and 3.4 builds. Do not copy them into this directory.
- Nothing for Ruby 1.8 / 2.0 / 2.2 / 2.5: those versions are unsupported on
  SU2024+ and their old binaries were removed from the tree (still in git
  history). Nothing 32-bit (`i386`): macOS has not supported 32-bit since
  10.15.

## Status

Placeholder only — `msp_lib.bundle` is produced by CI
(`.github/workflows/build.yml`) and merged/copied here by the `package` job.
Until the first green CI run, this directory contains only this README.
