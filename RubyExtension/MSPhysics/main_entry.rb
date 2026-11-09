# MSPhysics entry point (1.2.0, porting 2024-2027).
#
# The old entry point refused to load without AMS Library >= 3.5. AMS
# Library was never built for Ruby 3.2/3.4 and is unmaintained, so the hard
# gate is gone: MSPhysics always loads. When a system AMS Library is
# installed, it is used if its version is >= 3.5 (compared with
# Gem::Version, not Float); otherwise the bundled pure-Ruby shim
# (MSPhysics/ams_shim.rb, loaded by main.rb) provides AMS::Geometry,
# AMS::Group, AMS.clamp and the rest. AMS is never required for loading.

# Prefer a system AMS Library when one is installed and usable.
begin
  require 'ams_Lib/main'
rescue LoadError
  # AMS Library is not installed; the bundled shim (ams_shim.rb) is used.
end

if defined?(AMS::Lib::VERSION)
  begin
    ams_version = Gem::Version.new(AMS::Lib::VERSION.to_s)
    if ams_version < Gem::Version.new('3.5')
      puts "MSPhysics: system AMS Library #{AMS::Lib::VERSION} is older " \
        "than 3.5; using the bundled AMS shim instead. " \
        "MSPhysics: 系统 AMS Library #{AMS::Lib::VERSION} 低于 3.5，" \
        "将使用自带的 AMS 兼容层。"
    end
  rescue ArgumentError
    # Unparseable version string; ignore it and use the bundled shim.
  end
end

dir = File.dirname(__FILE__)
require File.join(dir, 'main')
