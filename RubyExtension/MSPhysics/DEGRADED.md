# MSPhysics 1.2.0 — Degraded / Removed Functionality (SketchUp 2024–2027)

This file lists what the port from AMS Library (Win32, Ruby 2.x) to the
bundled pure-Ruby shim (`ams_shim.rb`) could **not** preserve. Every item
here is a no-op in the shim and is recorded at runtime in
`MSPhysics::PORTING_DEGRADED` the first time it is requested
(`AMS.note_degraded`). Nothing here raises; the extension loads and the
rest of the simulation keeps working.

Background: AMS Library was a Win32 (HWND / `midiOut*` / `GetAsyncKeyState`)
wrapper. Since SketchUp 2022 the main window is a Qt window, so most Win32
window calls were already ineffective; Ruby 3.2 also removed `Win32API`.
There is no SketchUp Ruby API replacement for these operations.

## Fully working replacements (not degraded)

| Former AMS call | Replacement in 1.2.0 |
|---|---|
| `AMS::Geometry.*` (70 uses) | `AMS::Geometry` in `ams_shim.rb` (pure Ruby + `Geom::Vector3d`/`Transformation`) |
| `AMS::Group.*` (29 uses) | `AMS::Group` in `ams_shim.rb` (native `Group`/`ComponentInstance` API) |
| `AMS.clamp` / `AMS.validate_type` (139 uses) | `AMS.clamp` / `AMS.validate_type` in `ams_shim.rb` |
| `AMS::IS_PLATFORM_WINDOWS` | `Sketchup.platform` (fallback `RUBY_PLATFORM`) |
| `AMS::IS_RUBY_VERSION_18` | Constant `false`; branches deleted |
| `Array#x` / `#y` | Defined in `ams_shim.rb` only if `Array` lacks them |
| `AMS::ExtensionManager` | `MSPhysics::ExtensionLoader` (`extension_loader.rb`) |
| `AMS::Keyboard.key` / `key_down?` / `shift_down?` / `control_down?` / `control_up?` / `get_key_code` | `AMS::Keyboard` in `ams_shim.rb`, fed by native `Tool#onKeyDown`/`onKeyUp` (`Simulation`, `JointTool`, `JointConnectionTool`). Simulation key-nav (WASD/arrows), `key('…')` in user scripts and key sliders keep working while the Simulation tool is active. |
| `AMS::Sketchup.get_viewport_rect` | Native replacement: `active_view.vpwidth` / `vpheight` |
| `AMS::Sketchup.is_main_window_active?` | Assumed `true` (no hook exists to know otherwise; callers treat `false` as "ignore all keyboard input", which would be worse) |

## Degraded to no-op (Win32-only, no SketchUp API exists)

### Fullscreen / window chrome (`Simulation#view_full_screen`)

- `AMS::Sketchup.switch_full_screen`, `show_toolbar_container`,
  `show_scenes_bar`, `show_status_bar`, `show_dialogs`, `show_toolbars`,
  `set_menu_bar`, `set_viewport_border`, `refresh` — **fullscreen mode does
  nothing** in 1.2.0. The setting is still stored and the simulation runs;
  the chrome (menu bar, toolbars, scenes/status bar) stays visible.
  `Sketchup.resize_viewport` (SU 2023+) can resize the viewport but cannot
  hide the application chrome, so there is no native fullscreen.

### Dialog window handles (`Dialog`, `ControlPanel`)

- `AMS::Sketchup.find_window_by_caption` returns `nil`, so `@handle` is
  always `nil`. Consequently:
  - `AMS::Window.get_long` / `set_long` / `lock_update` / `set_pos` /
    `set_size` / `get_size` / `get_client_rect` — no-ops. Dialog border
    size falls back to the hardcoded `[2, 24]`; dialog resize goes through
    `HtmlDialog#set_size` instead.
  - `AMS::Window.set_layered_attributes` — no-op: **the control panel no
    longer fades to translucent** (`udpdate_opacity` never runs; opacity
    stays at the HtmlDialog default).
  - `AMS::Window.show` / `close` / `is_visible?` / `is_active?` /
    `is_restored?` — no-ops (or constant answers). `ControlPanel#show` /
    `#hide` / `#visible?` therefore only work via the `HtmlDialog` object
    itself (`visible?` returns `true` whenever the dialog exists).
  - `AMS::Sketchup.ignore_dialog` / `include_dialog` / `add_observer` /
    `remove_observer` / `activate` — no-ops. The old Win32 window-procedure
    observer that delivered key/mouse/menu events to `Simulation`
    (`swo_*` / `swp_*` methods) is gone; key events now come from the
    native `Tool#onKeyDown`/`onKeyUp`, mouse events already did.
  - `AMS::Sketchup.activate_scenes_bar_tab` — no-op (scene animation still
    switches pages; only the scenes-bar tab highlight is not forced).
  - `AMS::System.get_windows_version` — returns `10.0` (only used for a
    `< 6.0` comparison that is unreachable now).

### Replay export abort dialog

- `AMS::Sketchup.threaded_messagebox` — no-op (message goes to the status
  bar instead). The old non-blocking "abort export" dialog is gone, so a
  running Replay image/Kerkythea/Indigo export **cannot be aborted
  mid-run**; it runs to completion.
- `AMS::Sketchup.show_trays` — no-op: trays are no longer hidden during
  Replay playback/export.

### MIDI (`Simulation` sound triggers)

- `AMS::MIDI.open_device` / `close_device` / `play_note` / `stop_note` /
  `reset` / `set_note_position` / `change_channel_controller` — no-ops.
  **MIDI notes triggered by the simulation are silent.** SDL audio
  (sounds/music via `MSPhysics::Sound`/`Music`) is unaffected.

### Cursor warping / hiding

- `AMS::Cursor.set_pos` — no-op: the OS cursor can no longer be warped to
  a screen pixel (`Simulation#set_cursor_pos` only updates the stored
  position). `AMS::Cursor.show` / `is_visible?` — no-op / constant `true`;
  cursor visibility is controlled by the Tool via `onSetCursor` only.

### Replay exporters (SU2KT / SkIndigo)

- Not removed, but guarded: `export_to_kerkythea` and
  `export_to_skindigo` return `false` with a friendly messagebox when
  `SU2KT` / `SkIndigo` is not installed (both renderers are unmaintained
  and have no SU 2024+ builds). The `.bat` render starter is only ever
  created on Windows (`AMS::IS_PLATFORM_WINDOWS`); on macOS the old
  `Thread` + `system(kt_path …)` path is kept as-is.
- `.mspreplay` files keep the legacy Ruby-literal format (lines contain
  `Geom::Transformation.new(...)` etc.), so `Replay.load_data_from_file`
  still uses `eval` for those lines only. That `eval` reads the user's own
  replay file, never JS input; converting the format to JSON would break
  existing replay files and is out of scope for this port.

## Known behaviour changes to verify on first run (SU 2024/2027)

1. Control-panel sliders: values are now pushed from JS (`slider_changed`
   callback) and cached in Ruby; `get_slider_value` returns the cached
   value (default until the first change) instead of reading the DOM.
2. Keyboard input only reaches the simulation while the Simulation tool is
   active (as with any SketchUp tool). The old AMS hook also delivered keys
   when the main window had focus but another tool was active.
3. `MSPhysics::Settings` are now stored as JSON; the old Ruby-literal
   registry value is still read once (legacy fallback in `load_options`)
   and then re-saved as JSON.
4. Native libraries (`msp_lib.so`/`.bundle`, SDL2, Newton) must exist under
   `libraries/stage/<win64|osx64>/<3.2|3.4>/`. When they are missing the
   extension still loads and shows a bilingual error once; simulation,
   audio init and the About dialog's Newton version are skipped.
