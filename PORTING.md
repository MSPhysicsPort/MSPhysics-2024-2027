# MSPhysics — Porting Notes (SketchUp 2024–2027)

Version **1.2.0** (2026-11-09). This document describes the ported tree in
`ported/` — what changed relative to upstream, what is supported, how to
build and package it, and what is still blocked.

## 1. Upstream source and copyright

- Upstream: https://github.com/AntonSynytsia/MSPhysics, HEAD `f543557`
  (Merge PR #32, "Add SketchUp 2026 / Ruby 3.2 compatibility", 2026-09-15).
- Copyright: 2014–2018, Anton Synytsia (see `LICENCE.txt` and
  `RubyExtension/MSPhysics.rb`). This port keeps the upstream licence and
  attribution; no copyright headers were changed.
- The ported tree's first commit is the upstream HEAD, so all upstream
  history before that point is a single squashed commit. Old binaries removed
  during this port remain recoverable in git history (`git log --all`).

## 2. Support matrix

There is **no Ruby 3.3 tier**: SketchUp 2024/2025/2026 all embed Ruby 3.2.2,
and SketchUp 2027 jumps straight to Ruby 3.4.9. Only two Ruby ABIs are
needed — one `msp_lib` build per ABI.

| SketchUp | Ruby | Windows | macOS | `msp_lib` |
|---|---|---|---|---|
| 2024 (24.0) | **3.2.2** | Win 10/11, x64 | macOS 12+, Intel + Apple Silicon | `win64/3.2/msp_lib.so` / `osx64/3.2/msp_lib.bundle` (universal) |
| 2025 (25.0) | **3.2.2** | Win 10/11, x64 | macOS 13+ (15 Sequoia added), Intel + ARM | same 3.2 build |
| 2026 (26.0–26.2) | **3.2.2** | Win 10 (26.0) → **Win 11 only (26.1+)** | macOS 14/15/26; 26.2 is the last Intel-Mac release | same 3.2 build |
| 2027 (27.0.264) | **3.4.9** | **Win 11 only**, x64 | **Apple Silicon only**, macOS 15/26/27; Intel Macs cannot install | `win64/3.4/msp_lib.so` / `osx64/3.4/msp_lib.bundle` (arm64 only) |

Explicitly **not** supported: Win32/x86, macOS i386/32-bit, Ruby 1.8 / 2.0 /
2.2 / 2.5, Windows ARM64 (Trimble: x64 emulation only, not a supported
configuration), Linux (SketchUp has no Linux build). The old `stage/win32/`,
`stage/osx32/` and `1.8/2.0/2.2/2.5` binaries were deleted from the tree.

Newton and SDL are Ruby-independent: one `newton.dll/.dylib` per
platform/architecture is shared by the 3.2 and 3.4 builds. The macOS 3.2
`msp_lib.bundle` is a universal binary (`x86_64` + `arm64`, merged with
`lipo`); the 3.4 bundle is arm64-only.

Sources: `analysis/01-sketchup-version-matrix.md` (version matrix) and
`analysis/04-build-packaging-plan.md` (build/packaging plan). Note that
Trimble lists 2025/2026/2027 as the currently supported SketchUp versions;
2024 support reportedly ended 2027-01-31 — the 3.2 build still covers it
technically, but it is out of Trimble support.

## 3. AMS Library: stripped, and what is degraded

### 3.1 The problem

`MSPhysics/main_entry.rb` hard-requires AMS Library (`require 'ams_Lib/main'`,
`AMS::Lib::VERSION >= 3.5`) and refuses to load without it. AMS Library's
latest public release is **3.7.1b (2021-05-29)**, which ships only Ruby 2.5 /
2.7 `.so` files — there is **no Ruby 3.2 or 3.4 build**, and the project has
had no update since 2021. AMS is an external dependency: it is not in this
repository and it is not in the `.rbz`. Without AMS (or without removing the
dependency), MSPhysics does not load at all on SU2024–2027.

AMS is also a Windows-API library at its core (fullscreen, toolbar/status-bar
visibility, window-procedure hooks, keyboard hooks, MIDI via `midiOut*`).
Since SU2022/2023 SketchUp's windows are Qt objects, most Win32 window calls
no longer work even if AMS were rebuilt; Ruby 3.x also removed `Win32API.rb`
(use `Fiddle` instead) and `File.exists?` (AMS's `extension_manager.rb`
still calls it). See `analysis/01 §3` and `analysis/03 §3.2, §7`.

### 3.2 Degraded-feature list

The authoritative degraded-feature list is
**`RubyExtension/MSPhysics/DEGRADED.md`** — it is referenced here, not
duplicated, so the two do not drift apart. It was delivered by the Ruby
workstream (2026-11-09) together with the pure-Ruby shim
(`ams_shim.rb`) and the replacement loader (`extension_loader.rb`).

Summary of what is known to be degraded or removed (from analysis/03):

- **Windows-only, needs AMS rebuilt or reimplemented**: window operations
  (`AMS::Window`, control-panel borderless/translucent/topmost, fullscreen
  switching, toolbar/scene-bar/status-bar/menu-bar visibility), keyboard
  hooks (`AMS::Keyboard` — simulation keyboard control without the control
  panel), `AMS::MIDI` (7 calls, `play_note`/`stop_note`/etc. — no macOS
  equivalent; downgraded to Windows-only).
- **macOS: degraded by design** — fullscreen, keyboard navigation,
  borderless control panel and MIDI have no macOS counterpart and are
  disabled/downgraded there (AMS is Windows-only; macOS never had these
  hooks).
- **Kept as pure-Ruby replacements**: `AMS::Geometry`, `AMS::Group`,
  `AMS.validate_type`, `AMS.clamp` and similar tool helpers are reimplemented
  in MSPhysics's own Ruby code (no native dependency).
- **Loading gate (resolved 2026-11-09)**: `main_entry.rb` no longer
  refuses to load without AMS. It tries `require 'ams_Lib/main'` inside
  `begin/rescue LoadError` and, when AMS is absent or older than 3.5,
  falls back to the bundled pure-Ruby shim (`ams_shim.rb`) with a console
  notice. The extension always loads; AMS is never required.

### 3.3 What this means for the package

- The `.rbz` built by this repo does **not** include AMS Library and does
  not need it. The stripped build has landed: `main_entry.rb` loads the
  bundled pure-Ruby shim (`RubyExtension/MSPhysics/ams_shim.rb`) when no
  system AMS is present, and `extension_loader.rb` replaces
  `AMS::ExtensionManager` for native-library staging (it selects
  `stage/<win64|osx64>/<3.2|3.4>/` by platform + `RUBY_VERSION`,
  major.minor). If a Ruby 3.2/3.4-compatible AMS build ever appears, the
  shim steps aside for it automatically (see `ams_shim.rb`).

## 4. Building

### 4.1 GitHub Actions (recommended)

`.github/workflows/build.yml` — six jobs (see the workflow header for the
3.4 blocker notice and the missing-Xcode-targets notice):

| Job | Runner | Builds |
|---|---|---|
| `build-windows-3.2` | `windows-2022` | `msp_lib.so` (Ruby 3.2) + `newton.dll` — the only job that can pass today |
| `build-windows-3.4` | `windows-2022` | `msp_lib.so` (Ruby 3.4) — **expected to fail until 3.4 headers/libs land** |
| `build-macos-3.2-x86_64` | `macos-14`, Xcode 15.4 | `msp_lib.bundle` (x86_64) + `newton.dylib` (x86_64) — **blocked: the `Ruby 3.2 - 64` Xcode target does not exist yet** (comment placeholder in the `.pbxproj`, must be created by hand in Xcode) |
| `build-macos-3.2-arm64` | `macos-14`, Xcode 15.4 | `msp_lib.bundle` (arm64) + `newton.dylib` (arm64) — **blocked: same missing target** |
| `build-macos-3.4-arm64` | `macos-14`, Xcode 15.4 | `msp_lib.bundle` (arm64, Ruby 3.4) — **blocked: missing target + missing 3.4 headers** |
| `package` | `ubuntu-latest` | `lipo`-merges (via `llvm-lipo`, see below) the 3.2 macOS pair into a universal bundle, assembles the `.rbz`, runs structural checks. **Currently needs only `build-windows-3.2`** (coordinator decision 2026-11-09 — otherwise it could never run); 3.4/macOS artifacts are assembled when present, skipped with a warning when absent. Revert `needs` to all five build jobs once the 3.4 headers/libs and the Xcode targets land. |

Each build job takes ~10–20 minutes; the five build jobs run in parallel.
Xcode is pinned to 15.4 with `xcode-select` — never float the runner default.
No job needs a SketchUp licence (compile + link + `file`/`lipo` inspection
only).

One correction to analysis/04 §5.1: Apple's `lipo` only ships with Xcode,
so it does not exist on `ubuntu-latest`. The `package` job therefore uses
`llvm-lipo` (from the `llvm` apt package), which creates the same fat Mach-O
binaries; the result is re-verified with `lipo -info` on a real Mac before
release.

### 4.2 Local builds

Windows (VS2022, from a Developer Command Prompt):

```bat
msbuild C++Extension\Projects\VS\MSPhysics.sln /p:Configuration="Release (3.2)" /p:Platform=x64 /m /v:m
msbuild C++Extension\Projects\VS\MSPhysics.sln /p:Configuration="Release (3.4)" /p:Platform=x64 /m /v:m
```

Products (the `.vcxproj` `OutDir` is `$(Platform)/$(ProjectName)/$(Configuration)\`):

```
C++Extension\Projects\VS\x64\msp_lib\Release (3.2)\msp_lib.so
C++Extension\Projects\VS\x64\msp_lib\Release (3.4)\msp_lib.so
C++Extension\Projects\VS\x64\newton\Release (3.2)\newton.dll
```

Verify exports: `dumpbin /EXPORTS …\msp_lib.so` must list `Init_msp_lib`.

macOS (Xcode 15.4, `sudo xcode-select -s /Applications/Xcode_15.4.app` first).
**First, create the `Ruby 3.2 - 64` (and later `Ruby 3.4 - 64`) targets by
hand in Xcode** — they do not exist yet; the `.pbxproj` only carries a
comment placeholder at the top of the `PBXNativeTarget` section listing
every setting to apply (copy the `Ruby 2.5 - 64` target, then change
`HEADER_SEARCH_PATHS`, `RUBY_VERSION32`/`RUBY_VERSION34`, deployment
target and architectures). Also review the `msp_lib` ShellScript phase,
which still references an old SDL x86 path. Then:

```bash
xcodebuild -project C++Extension/Projects/xCode/msp_lib.xcodeproj \
  -target "Ruby 3.2 - 64" -configuration Release \
  ARCHS=x86_64 MACOSX_DEPLOYMENT_TARGET=12.0 \
  -derivedDataPath build/macos-3.2-x86_64
xcodebuild -project C++Extension/Projects/xCode/msp_lib.xcodeproj \
  -target "Ruby 3.2 - 64" -configuration Release \
  ARCHS=arm64 MACOSX_DEPLOYMENT_TARGET=12.0 \
  -derivedDataPath build/macos-3.2-arm64
lipo -create \
  build/macos-3.2-x86_64/Build/Products/Release/msp_lib.bundle \
  build/macos-3.2-arm64/Build/Products/Release/msp_lib.bundle \
  -output RubyExtension/MSPhysics/libraries/stage/osx64/3.2/msp_lib.bundle
lipo -info RubyExtension/MSPhysics/libraries/stage/osx64/3.2/msp_lib.bundle
# must show: x86_64 arm64
```

The 3.4 macOS build is the same command with `-target "Ruby 3.4 - 64"` and
`ARCHS=arm64` only (no `lipo` step). Both 3.4 builds additionally need the
Ruby 3.4.9 headers/libs — see §6.

## 5. Packaging

```bash
bash scripts/package.rbz.sh --version 1.2.0 --out dist/MSPhysics-1.2.0-unsigned.rbz
```

- The `.rbz` is a ZIP. Its root contains **only** `MSPhysics.rb` and
  `MSPhysics/` — never `C++Extension/`, `.git/`, `.github/`, `__MACOSX/` or
  `.DS_Store`. Packing uses python3 `zipfile` (`ZIP_DEFLATED`).
- The script checks that `MSPhysics.rb`'s `VERSION` matches `--version`,
  then runs `unzip -l` and lists the `stage/` contents automatically.
- `bash scripts/check_stage.sh` validates the `stage/` layout: `win64/3.2`,
  `win64/3.4`, `osx64/3.2`, `osx64/3.4` must exist; `win32/`, `osx32/` and
  any `1.8/2.0/2.2/2.5` directory must not. CI runs it in the `package` job.
- The output is **unsigned** and for internal testing only. A releasable
  package must be signed via the Trimble signing portal
  (https://extensions.sketchup.com/developer/sign-extension) — signing is a
  manual step with a Trimble account, ~10 minutes, and does not test or
  review the extension. Do not mix signed and unsigned files in one
  directory (same file name); keep them in `dist/unsigned/` vs
  `dist/signed/`. Extension Warehouse submission is a separate path with a
  2–3 working-day review and is out of scope for the 24-hour delivery.
- First sign without encryption (`.rb` → `.rbe` is optional and must be
  load-tested separately afterwards).

Expected `.rbz` layout:

```
MSPhysics-1.2.0-unsigned.rbz
├── MSPhysics.rb
└── MSPhysics/
    ├── main.rb  main_entry.rb  *.rb
    ├── css/  html/  images/  js/  models/
    └── libraries/
        └── stage/
            ├── win64/3.2/msp_lib.so  win64/3.4/msp_lib.so
            ├── win64/newton.dll  win64/SDL2.dll  win64/SDL2_mixer.dll
            │   (+ 7 mixer dependency DLLs)
            ├── osx64/3.2/msp_lib.bundle  osx64/3.4/msp_lib.bundle
            └── osx64/newton.dylib  osx64/libSDL2-2.0.0.dylib
                osx64/libSDL2_mixer-2.0.0.dylib
```

Total size estimate: ~12–15 MB (was ~20 MB with the deleted 32-bit/old-Ruby
binaries).

## 6. Known limitations

- **Ruby 3.4 headers/libs missing (blocker, expected).** The tree has no
  Ruby 3.4 headers, no `x64-ucrt-ruby340.lib`, no macOS Ruby.framework 3.4.
  Sources, in priority order: extract from a machine with SU2027 installed
  (Windows: SketchUp install dir; macOS:
  `SketchUp.app/Contents/Frameworks/Ruby.framework`), or build Ruby 3.4.9
  from source with the same toolchain (MSVC 2022 + UCRT; see MSP-Greg's
  `ruby-loco` for a CI-friendly approach). Do not download a random
  `ruby340.lib` — the import library must match SketchUp's embedded Ruby
  (UCRT, API version), or `Init_msp_lib` will fail at load time.
  Until this lands, the two 3.4 CI jobs fail and no SU2027 binary exists.
- **macOS SDL arm64 missing (risk R4).** The bundled SDL2/SDL2_mixer
  `.dylib` files are x86_64-only. Apple Silicon builds need SDL 2.0.5 /
  SDL_mixer 2.0.1 recompiled for arm64 from source and `lipo`-merged; SDL is
  deliberately not upgraded (2.0.5 → 2.30.x would be a behaviour change).
- **macOS Ruby linking unconfirmed (risk R2).** There is no
  `ThirdParty/Ruby/lib/mac/3.2/Ruby.framework` in the tree. The macOS build
  links against SketchUp's own Ruby.framework, or falls back to
  `-undefined dynamic_lookup`; to be confirmed by measurement, not by this
  document.
- **Xcode 3.2/3.4 targets do not exist yet.** The 32-bit targets were
  deleted, but the new `Ruby 3.2 - 64` / `Ruby 3.4 - 64` targets are only
  comment placeholders in the `.pbxproj` (cloning the whole object graph
  as text was judged too risky); they must be created by hand in Xcode
  (see §4.2). Until then every macOS CI job fails. The `msp_lib`
  ShellScript phase still references an old SDL x86 path — review it when
  creating the new targets.
- **AMS stage-selection logic is moot (was risk R1).** AMS's
  `ExtensionManager` is no longer used: the replacement
  `extension_loader.rb` selects `stage/<platform>/<major.minor>/` by
  platform + `RUBY_VERSION`. No `3.4.9/` alias directory is needed.
- **`msp_lib.vcxproj` 3.2 config fixed (was a §6 item).** The C++
  workstream changed `RUBY_VERSION25` → `RUBY_VERSION32`, unified all
  remaining configs on v143 / C++17 / `/MD`, and deleted the
  `Release (3.2)|Win32` orphan configuration. Verified by grep: 0
  `RUBY_VERSION25` / `|Win32` hits in `Projects/VS/`.
- **SU2027 macOS Qt rebuild.** SketchUp 2027 replaced Cocoa with Qt on Mac;
  any macOS-specific workaround code (including the HTML/JS control panel
  via `UI::HtmlDialog`, CEF 149) must be re-tested on a real Apple Silicon
  Mac — the build side cannot verify this.
- **This Linux workspace cannot verify the Windows/macOS build.** No
  MSVC, Xcode or SketchUp here — but Ruby **is** present (system Ruby
  3.2.3): all 43 `.rb` files pass `ruby -c`, both dialog JS files pass
  `node --check`, and the shim + loader pass a 57-check stub test (see
  §7). CI + real machines are the only verification path for compiling,
  linking and loading (see §7).

## 7. 真机验证清单 (Real-machine verification — from analysis/02 §5)

Each item must be checked on real hardware before release. Check them off
only with a dated, machine-specific result — "CI green" is not a substitute
for the `require` / runtime items.

- [ ] **VS2022 (v143) 编译**: `Release (3.2)|x64` 与 `Debug (3.2)|x64` 全链
  编译 0 错误 (`WarningLevel Level4`, `TreatWarningAsError=false` 不变，
  先只看错误)。Machine/date: ________
- [ ] **VS2022 (v143) 编译 (3.4)**: `Release (3.4)|x64` /
  `Debug (3.4)|x64` 同上（须先有 3.4 头文件/库，见 §6）。Machine/date: ________
- [ ] **Xcode 编译**: 先在 Xcode 里手工创建 `Ruby 3.2 - 64` 与
  `Ruby 3.4 - 64` 目标（见 §4.2，.pbxproj 内只有注释占位），再编译
  `Ruby 3.2 - 64` (x86_64 + arm64) 与 `Ruby 3.4 - arm64`
  (Xcode 15.4, 部署目标 12.0)。Machine/date: ________
- [ ] **require 加载**: 产物放入 `stage/` 的 `win64/3.2`、`win64/3.4`、
  `osx64/3.2`、`osx64/3.4` 后，在 SU 2024/2025/2026 (3.2) 与 SU 2027
  (3.4) 上 `require` 成功，`Init_msp_lib` 符号可解析，无 `LoadError`。
  Machine/date: ________
- [ ] **GC 压力测试**: 反复创建/销毁世界与 body、反复设置
  `user_data`/`destructor_proc`、强制 `GC.start` 多次，仿真不崩溃
  (针对 analysis/02 §E；1.2.0 已加 `WorldData::m_gc_roots` 根保护与
  `rb_obj_id` 键，析构回调改为 Ruby 线程排空队列，见 §3)。Machine/date: ________
- [ ] **多线程测试**: `set_max_threads_count` 从 1 调到 4，仿真 + 析构
  回调不崩溃 (针对 analysis/02 §F，Newton 回调里直接调 Ruby)。
  Machine/date: ________
- [ ] **中文路径测试**: 含中文的音效/音乐文件路径能加载 (针对
  analysis/02 §G1/G2 的编码路径)。Machine/date: ________
- [ ] **32 位残留检查**: `sln`/`vcxproj`/`xcodeproj` 中无 Win32/x86/i386
  残留；`.rbz` 中无 `win32/`、`osx32/`、`1.8/2.0/2.2/2.5/` 目录。
  Machine/date: ________
- [ ] **AMS 加载 (前置，已在 Linux 上以桩测试验证，须在真机复核)**:
  在无 AMS 的干净 SU 2024–2027 上安装，确认扩展正常加载并走自带
  shim（`main_entry.rb` 不再拒载），`AMS::Geometry`/`AMS::Group` 等
  调用工作；`MSPhysics::PORTING_DEGRADED` 只记录预期的降级项。
  Machine/date: ________
- [ ] **控制面板**: SU2027 (Mac Qt / Win) 上打开控制面板
  (`UI::HtmlDialog`)，确认显示与交互正常 (针对 analysis/04 风险 R9)。
  Machine/date: ________
- [ ] **签名包复测**: Trimble 签名门户签名后的 `.rbz` 在真机上重新安装
  一次，确认能加载 (未签名包只能用于内部测试)。Machine/date: ________
