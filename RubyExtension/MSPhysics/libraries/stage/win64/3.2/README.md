# stage/win64/3.2 — Windows x64, Ruby 3.2.2 (SketchUp 2024 / 2025 / 2026)

This directory holds the Windows 64-bit native extension for **Ruby 3.2.2**,
shared by SketchUp 2024, 2025 and 2026 (all three embed Ruby 3.2.2).

## What goes here

| File | Source | Notes |
|---|---|---|
| `msp_lib.so` | CI job `build-windows-3.2` (`msbuild … /p:Configuration="Release (3.2)" /p:Platform=x64`) | Build output: `C++Extension/Projects/VS/x64/msp_lib/Release (3.2)/msp_lib.so`. Must be PE32+ x86-64 and export `Init_msp_lib`. |

## What does NOT go here

- `newton.dll`, `SDL2.dll`, `SDL2_mixer.dll` and the mixer dependency DLLs
  (`libFLAC-8.dll`, `libmikmod-2.dll`, `libmodplug-1.dll`, `libogg.dll`,
  `libvorbis.dll`, `libvorbisfile-3.dll`, `smpeg2.dll`) live in the parent
  `win64/` directory — they are Ruby-independent and shared by the 3.2 and
  3.4 builds. Do not copy them into this directory.
- Nothing for Ruby 1.8 / 2.0 / 2.2 / 2.5: those versions are unsupported on
  SU2024+ and their old binaries were removed from the tree (still in git
  history). Nothing 32-bit: SketchUp has been 64-bit-only since 2017.

## Status

`msp_lib.so` (win64/3.2) and `newton.dll` (parent `win64/`) are present,
cross-compiled on Linux with MinGW-w64 — see `PORTING.md` §4.3. `file`
reports both as PE32+ x86-64 DLLs and `msp_lib.so` exports
`Init_msp_lib`. Still unverified on a real Windows + SketchUp machine
(see `PORTING.md` §7); the MSVC build (`.github/workflows/build.yml`)
remains the reference path.
