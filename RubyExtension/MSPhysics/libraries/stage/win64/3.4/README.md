# stage/win64/3.4 — Windows x64, Ruby 3.4.9 (SketchUp 2027)

This directory holds the Windows 64-bit native extension for **Ruby 3.4.9**,
for SketchUp 2027 only (27.0.264, Windows 11 x64 only).

## What goes here

| File | Source | Notes |
|---|---|---|
| `msp_lib.so` | CI job `build-windows-3.4` (`msbuild … /p:Configuration="Release (3.4)" /p:Platform=x64`) | Build output: `C++Extension/Projects/VS/x64/msp_lib/Release (3.4)/msp_lib.so`. Must be PE32+ x86-64 and export `Init_msp_lib`. |

## Blocker (expected)

This directory is intentionally empty for now. The `build-windows-3.4` CI job
cannot succeed until the SketchUp 2027 Ruby 3.4.9 headers and import library
(`ThirdParty/Ruby/include/3.4`, `x64-ucrt-ruby340.lib`) are in the tree —
see `PORTING.md` ("Known limitations") and `analysis/04 §3.3`. The 3.2 build
does **not** work on SU2027: the Ruby C-extension ABI changed between 3.2
and 3.4, so a separate 3.4 build is mandatory.

## What does NOT go here

- `newton.dll`, `SDL2.dll`, `SDL2_mixer.dll` and the mixer dependency DLLs
  live in the parent `win64/` directory — they are Ruby-independent and
  shared by the 3.2 and 3.4 builds. Do not copy them into this directory.
- Nothing for Ruby 1.8 / 2.0 / 2.2 / 2.5 and nothing 32-bit (see the
  `win64/3.2/README.md` for why).
