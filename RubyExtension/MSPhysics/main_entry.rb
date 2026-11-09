# MSPhysics entry point (1.2.0, porting 2024-2027).
#
# The old entry point refused to load without AMS Library >= 3.5. AMS
# Library was never built for Ruby 3.2/3.4 and is unmaintained, so the hard
# gate is gone: MSPhysics always loads, using the bundled pure-Ruby shim
# (MSPhysics/ams_shim.rb, loaded by main.rb) which provides AMS::Geometry,
# AMS::Group, AMS.clamp and the rest.
#
# NOTE (2026-11-09, real-machine bug): do NOT probe for a system AMS
# Library with `require 'ams_Lib/main'`, not even inside `rescue LoadError`.
# A machine may carry a leftover Plugins/ams_Lib/ folder (Ruby files only,
# no Ruby 3.2 .so). That stray main.rb raises a non-LoadError
# ("Could not find included file .../ams_lib") which escapes a LoadError
# rescue and kills the whole extension load. The shim is the only AMS
# implementation on Ruby 3.2/3.4, so nothing is probed here at all.

dir = File.dirname(__FILE__)
require File.join(dir, 'main')
