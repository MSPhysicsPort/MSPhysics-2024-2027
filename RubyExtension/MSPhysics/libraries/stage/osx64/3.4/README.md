# stage/osx64/3.4 — macOS 64-bit, Ruby 3.4.9 (SketchUp 2027, Apple Silicon only)

This directory holds the macOS 64-bit native extension for **Ruby 3.4.9**,
for SketchUp 2027 only (27.0.264, Apple Silicon only, macOS 15/26/27).

## What goes here

| File | Source | Notes |
|---|---|---|
| `msp_lib.bundle` | CI job `build-macos-3.4-arm64` (`xcodebuild -target "Ruby 3.4 - 64" ARCHS=arm64`) | **arm64 only — no x86_64 slice, no `lipo` merge.** SU2027 cannot be installed on Intel Macs, so a universal bundle is unnecessary. `lipo -info` must show exactly `arm64`. |

## Blocker (expected)

This directory is intentionally empty for now. The `build-macos-3.4-arm64` CI
job cannot succeed until the SketchUp 2027 Ruby 3.4.9 headers are in the
tree (extracted from `SketchUp.app/Contents/Frameworks/Ruby.framework` on a
machine with SU2027 installed) — see `PORTING.md` ("Known limitations") and
`analysis/04 §3.3`. The 3.2 bundle does **not** work on SU2027: the Ruby
C-extension ABI changed between 3.2 and 3.4.

## What does NOT go here

- `newton.dylib`, `libSDL2-2.0.0.dylib`, `libSDL2_mixer-2.0.0.dylib` live in
  the parent `osx64/` directory — they are Ruby-independent and shared by
  the 3.2 and 3.4 builds (the arm64 slices of `newton.dylib`/SDL are reused
  from the universal 3.2 files). Do not copy them into this directory.
- Nothing for Ruby 1.8 / 2.0 / 2.2 / 2.5 and nothing 32-bit / x86_64 (see the
  `osx64/3.2/README.md` for why).
