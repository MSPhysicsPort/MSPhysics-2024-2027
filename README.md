[Homepage](http://sketchucation.com/forums/viewtopic.php?f=323&t=56852)

[Wiki](https://github.com/AntonSynytsia/MSPhysics/wiki)

[Documentation](http://www.rubydoc.info/github/AntonSynytsia/MSPhysics/index)

[GitHub](https://github.com/AntonSynytsia/MSPhysics)


## Demo video

[![Sketchup2026 successfully runs MSPhysics](https://img.youtube.com/vi/Yp9EG-Qn7ik/0.jpg)](https://youtu.be/Yp9EG-Qn7ik)

MSPhysics 1.2.0 running on SketchUp 2026 (Windows 11, Ruby 3.2.2). [Watch on YouTube](https://youtu.be/Yp9EG-Qn7ik)

## Testing status (v1.2.0, Windows)

- SketchUp 2026: tested on a real machine (Windows 11, SketchUp 26.0.429, Ruby 3.2.2). The extension loads and simulation runs. See the demo video above.
- SketchUp 2024 and SketchUp 2025: not tested yet. They use the same Ruby 3.2.2 build as SketchUp 2026, so v1.2.0 is expected to work, but this has not been verified on a real machine. Testing feedback is very welcome. Please open an issue with your SketchUp version, Windows version, and what happened.
- SketchUp 2027: not tested and not yet supported. The Ruby 3.4.9 native library has not been built (see `PORTING.md`), so physics simulation will not run on SU2027 with v1.2.0. Feedback is welcome, but please note a separate Ruby 3.4 build is needed first.

## Installation (v1.2.0, Windows)

1. Download `MSPhysics-1.2.0-unsigned.rbz` from [Releases](https://github.com/MSPhysicsPort/MSPhysics-2024-2027/releases/tag/v1.2.0). Do not try to install the repository ZIP itself; if you downloaded the repository, the installable file is `dist/MSPhysics-1.2.0-unsigned.rbz`.
2. If an older MSPhysics 1.2.0 is installed, uninstall it first in Extension Manager.
3. In SketchUp, open Extension Manager, choose Install Extension, and select the `.rbz` file. When SketchUp warns that the extension is unsigned, allow the installation, then restart SketchUp.
4. No separate AMS Library install is needed. v1.2.0 bundles its own compatibility layer, and a leftover `Plugins/ams_Lib/` folder does not affect loading.

Language: Plugins > MSPhysics > Language, choose English or Chinese (Simplified). Toolbar and menu text apply after restarting SketchUp; dialogs use the new language the next time they open.

# Overview

_Note: the description below is upstream's original text. In this 1.2.0 port, AMS Library is no longer required, and fullscreen switching is degraded; see Compatibility and Requirements below and `RubyExtension/MSPhysics/DEGRADED.md`._

MSPhysics is a real-time physics simulation extension for SketchUp.

MSPhysics allows doing physics simulation of groups and component instances,
where each object can be assigned a specific shape, specific states, density,
contact properties, magnet properties, script, and more. These features allow
complex interactions between objects and the physics world. The parameters of
the physics world, such as gravity, update timestep, and solver model, can too
be adjusted.

MSPhysics also allows interconnecting objects with joints (constraints) for
establishing mechanical interactions between objects. MSPhysics has 14 joints:
Hinge, Motor, Servo, Slider, Piston, UpVector, Spring, Corkscrew, BallAndSocket,
Universal, Fixed, CurvySlider, CurvyPiston, and Plane. Each joint can be
assigned its specific properties, such as minimum and maximum position/angle
limits, as well as controllers for controlling position, angle, speed, linear or
angular friction, and other. The controllers themselves can be stimulated with a
use of a slider controller, keyboard key(s), joystick, and/or a desired script.
This flexibility allows creating and inventing many things, such as vehicles,
robots, and instruments.

MSPhysics also comes with a reliable Replay animation tool, which allows
recording simulation and exporting to SkIndigo, KerkyThea, or a sequence of
images.

In many ways, MSPhysics resembles its predecessor SketchyPhysics. First of all,
MSPhysics is not a new version of SketchyPhysics. MSPhsyics is written entirely
from scratch, integrating the latest Newton Dynamics Physics SDK and heavily
basing on a C++ extension. Both are capable of achieving same things, in one way
or the other; however, MSPhysics is significantly faster and goes further,
especially with a lot of the features described above. MSPhysics has a by far
more advanced and a well documented scripting API, allowing users to write more
proficient scripts for their models. Another difference is having advantage over
user input. In SketchyPhysics there was a struggle in creating keyboard and
mouse controlled games. Whenever simulation would run, there had to be an active
control panel window to redirect user input, that is to prevent the interference
of SketchUp's keyboard shortcuts. In MSPhysics, however, the control panel is
not necessary. MSPhysics utilizes AMS Library, which on the Windows side, allows
taking control over user input and switching SketchUp fullscreen. Imagine
playing FPS games in SketchUp, in fullscreen mode, without having various
keyboard commands taking control over the simulation. All that is possible with
MSPhysics.


# Compatibility and Requirements (v1.2.0)

* Windows 64-bit only, SketchUp 2024, 2025, or 2026 (Ruby 3.2.2). See Testing status above. SketchUp 2027 is not yet supported: the Ruby 3.4.9 native library has not been built. macOS builds are not included in v1.2.0.
* No AMS Library is required or used. v1.2.0 bundles a pure-Ruby compatibility layer (`ams_shim.rb`). Some former AMS-only features (fullscreen switching, MIDI, control-panel translucency) are degraded to no-ops; see `RubyExtension/MSPhysics/DEGRADED.md`. For the full porting notes, see `PORTING.md`.
* This is an unsigned build for testing. A releasable build must be signed through the Trimble signing portal.


# ThirdParty Libraries

* NewtonDynamics 3.14
* SDL 2.0.5
* SDL_Mixer 2.0.1
* jQuery 1.12.4
* Ace 1.2.6
* Chosen 1.7.0
* dhtmlxSlider 4.6
