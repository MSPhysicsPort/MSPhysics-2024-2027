# Ruby 3.4.9 headers / libraries for SketchUp 2027 — PLACEHOLDER

> **This directory is intentionally empty.** There are no Ruby 3.4 headers
> or libraries in this repository yet, and none have been downloaded from
> the internet. Do **not** fill it with a generic Ruby 3.4 build.

## Where the files must come from

Extract them from an installed **SketchUp 2027** (which embeds Ruby 3.4.9),
so the headers match the exact Ruby the extension will load against:
same patch version (3.4.9), same UCRT/MSVC build, same `config.h` macros.
A stock rubyinstaller / Homebrew Ruby 3.4 is **not** a substitute — its
`config.h`, ABI flags and import library will differ, and linking against
it can produce a `.so` that loads in tests but crashes inside SketchUp.

Suggested extraction points (verify against the actual SU2027 install):

- Windows: the Ruby headers + `x64-ucrt-ruby340.lib` shipped inside the
  SketchUp 2027 install tree (the 3.2 equivalents live in
  `ThirdParty/Ruby/include/3.2/win32_x64/` and
  `ThirdParty/Ruby/lib/win32/x64-ucrt-ruby320.lib`).
- macOS: the `Ruby.framework` inside the SketchUp 2027 app bundle
  (the 2.5 equivalent is `ThirdParty/Ruby/lib/mac/2.5/Ruby.Framework`;
  note macOS currently has **no** 3.2 library either — extract the 3.2
  framework from SU2024/2025/2026 the same way if macOS 3.2 builds are
  needed).

## Files that belong here (mirror the 3.2 layout)

```
ThirdParty/Ruby/include/3.4/
├── README.md                  (this file)
├── win32_x64/
│   ├── ruby.h                 (top-level Ruby headers)
│   └── ruby/                  (ruby/*.h, incl. ruby/config.h, ruby/internal/*)
└── mac/
    ├── ruby.h
    ├── ruby/                  (ruby/*.h)
    └── arm64-darwin/          (rb_mjit_min_header-3.4.9.h, ruby/config.h)
        # SU2027 is Apple Silicon only: no x86_64-darwin directory is needed.
        # (3.2 still has both x86_64-darwin and arm64-darwin.)

ThirdParty/Ruby/lib/win32/
└── x64-ucrt-ruby340.lib      (Windows import library, UCRT, /MD)

ThirdParty/Ruby/lib/mac/
└── 3.4/
    └── Ruby.framework        (macOS framework for the Xcode targets)
```

## What is blocked until these files exist

- `Projects/VS/msp_lib.vcxproj` — `Release (3.4)|x64` and
  `Debug (3.4)|x64` are skeletons only (they reference
  `include/3.4/win32_x64` and `x64-ucrt-ruby340.lib`, neither of which
  exists yet). They will fail to build until this directory is filled.
  The same applies to `dMath/dgCore/dgPhysics/newton.vcxproj` 3.4
  configurations (those need no Ruby headers, but the solution only
  builds end-to-end once msp_lib links).
- `Projects/xCode/msp_lib.xcodeproj` — the `Ruby 3.4 - arm64` target does
  not exist yet (see the TODO comment at the top of its
  `PBXNativeTarget` section); creating it needs the 3.4 headers +
  `Ruby.framework` above.
- Audit 02 §6 "unverified for 3.4" items: whether `ANYARGS` /
  `RUBY_METHOD_FUNC` / `rb_rescue2` / `rb_ull2inum` / `rb_num2ull` /
  `rb_str_new2` and the `RSTRING_PTR` / `RARRAY_LEN` inline functions
  still exist with the same signatures in Ruby 3.4.9. Re-check every one
  of these against the extracted headers before calling the 3.4 port done.
- SketchUp 2027's Ruby must also be re-confirmed as UCRT + `/MD`
  (the 3.4 VS configs assume it, mirroring 3.2).

## Checklist when filling this directory

1. Copy the headers + `.lib` / `.framework` from the SU2027 install.
2. Confirm `ruby/version.h` (or `ruby/ruby.h`) reports 3.4.9.
3. Confirm the Windows `.lib` is named `x64-ucrt-ruby340.lib` and matches
   the VS configs; confirm the macOS framework is arm64.
4. Build `Release (3.4)|x64` (VS2022, v143) and the Xcode
   `Ruby 3.4 - arm64` target; `require` the result in SU2027.
5. Delete this placeholder note's "blocked" section once 1–4 pass.
