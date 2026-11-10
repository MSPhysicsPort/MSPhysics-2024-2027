# Minimal replacement for AMS::ExtensionManager (MSPhysics 1.2.0, porting
# 2024-2027). Pure Ruby: resolves the native libraries from
# libraries/stage/<win64|osx64>/<ruby-version>/ and requires the Ruby
# files in the upstream order.
#
# The old AMS loader staged C extensions per Ruby version and copied DLLs
# around; this loader only adjusts the load path and requires by absolute
# path. It never raises for a missing native library: it records a
# bilingual (Chinese + English) error, main.rb shows it once, and the pure
# Ruby files still load so the extension degrades instead of crashing
# SketchUp at startup.
#
# @since 1.2.0

module MSPhysics
  module ExtensionLoader

    # Ruby files in upstream load order (the old AMS::ExtensionManager
    # add_ruby list, minus main/main_entry which are already loaded).
    # There are 41 .rb files in MSPhysics/: main.rb, main_entry.rb and the
    # 39 below ('language' is new in 1.2.0 and loads first: the toolbar
    # and menu code in main.rb calls Language.t at load time).
    RUBY_FILES = %w[
      language
      entity collision contact hit script_exception
      common_context controller_context body_context
      body world material materials
      joint gear
      joint_hinge joint_motor joint_servo joint_corkscrew
      joint_ball_and_socket joint_universal joint_slider joint_piston
      joint_spring joint_up_vector joint_fixed
      joint_curvy_slider joint_curvy_piston joint_plane joint_point_to_point
      simulation settings dialog control_panel
      joint_tool joint_connection_tool gear_connection_tool
      replay scene_data
    ].freeze

    # Native libraries that must be present next to msp_lib. SDL2_mixer
    # needs its codec DLLs on Windows, but those are optional: SDL2_mixer
    # still loads without them (fewer audio formats).
    WINDOWS_REQUIRED_DLLS = %w[SDL2.dll SDL2_mixer.dll newton.dll].freeze
    WINDOWS_OPTIONAL_DLLS = %w[
      libFLAC-8.dll libmikmod-2.dll libmodplug-1.dll libogg.dll
      libvorbis.dll libvorbisfile-3.dll smpeg2.dll
    ].freeze
    MACOS_REQUIRED_DYLIBS = %w[
      libSDL2-2.0.0.dylib libSDL2_mixer-2.0.0.dylib newton.dylib
    ].freeze

    @native_loaded = false
    @native_error = nil

    class << self

      # "3.2" for SketchUp 2024-2026 (Ruby 3.2.2), "3.4" for SketchUp 2027
      # (Ruby 3.4.9). SketchUp never shipped a Ruby 3.3.
      # @return [String]
      def ruby_version_dir
        RUBY_VERSION.split('.')[0, 2].join('.')
      end

      # @return [String] 'win64' or 'osx64' (32-bit builds are gone).
      def platform_dir
        AMS::IS_PLATFORM_WINDOWS ? 'win64' : 'osx64'
      end

      # @return [String] Absolute path of this extension's directory.
      def extension_dir
        File.dirname(__FILE__)
      end

      # @return [String] libraries/stage/<platform>/
      def stage_dir
        File.join(extension_dir, 'libraries', 'stage', platform_dir)
      end

      # @return [String] libraries/stage/<platform>/<ruby-version>/
      def version_dir
        File.join(stage_dir, ruby_version_dir)
      end

      # @return [String] Absolute path of the msp_lib C extension.
      def native_extension_path
        ext = AMS::IS_PLATFORM_WINDOWS ? 'msp_lib.so' : 'msp_lib.bundle'
        File.join(version_dir, ext)
      end

      # @return [Array<String>] Absolute paths of required native files
      #   that are missing (msp_lib + SDL + Newton).
      def missing_native_files
        missing = []
        missing << native_extension_path unless File.exist?(native_extension_path)
        if AMS::IS_PLATFORM_WINDOWS
          WINDOWS_REQUIRED_DLLS.each do |dll|
            path = File.join(stage_dir, dll)
            missing << path unless File.exist?(path)
          end
        else
          MACOS_REQUIRED_DYLIBS.each do |lib|
            path = File.join(stage_dir, lib)
            missing << path unless File.exist?(path)
          end
        end
        missing
      end

      # Load the native libraries (SDL, Newton, msp_lib).
      # Never raises: on failure records a bilingual error and returns
      # false; main.rb shows the message once and continues with the pure
      # Ruby files only.
      # @return [Boolean] true when msp_lib loaded successfully.
      def load_native_libraries
        missing = missing_native_files
        unless missing.empty?
          @native_loaded = false
          @native_error = build_missing_error(missing)
          puts @native_error
          return false
        end
        # Let the OS loader find SDL/Newton next to msp_lib.
        if AMS::IS_PLATFORM_WINDOWS
          sep = File::PATH_SEPARATOR
          ENV['PATH'] = "#{stage_dir}#{sep}#{ENV['PATH']}" unless
            ENV['PATH'].to_s.split(sep).include?(stage_dir)
        end
        $LOAD_PATH.unshift(version_dir) unless $LOAD_PATH.include?(version_dir)
        $LOAD_PATH.unshift(stage_dir) unless $LOAD_PATH.include?(stage_dir)
        begin
          require native_extension_path
        rescue LoadError => err
          @native_loaded = false
          @native_error = build_load_error(err)
          puts @native_error
          return false
        end
        @native_loaded = true
        @native_error = nil
        true
      end

      # @return [Boolean] Whether the native libraries loaded.
      def native_loaded?
        @native_loaded
      end

      # @return [String, nil] Bilingual error from the last failed native
      #   load, or nil when the native libraries loaded.
      def native_error_message
        @native_error
      end

      # Require every Ruby file in upstream order. Raises only if a Ruby
      # file itself is missing or has a syntax error (a real bug, unlike a
      # missing native library).
      # @return [Integer] Number of files required.
      def require_all_ruby_files
        count = 0
        RUBY_FILES.each do |name|
          require File.join(extension_dir, name)
          count += 1
        end
        count
      end

      private

      def build_missing_error(missing)
        lines = missing.map { |p| "  - #{p}" }
        "MSPhysics: native libraries are missing, physics simulation will " \
          "not run.\n" \
          "MSPhysics: 缺少原生库文件，物理仿真将无法运行。\n" \
          "Missing files (缺失的文件):\n#{lines.join("\n")}\n" \
          "Expected location (应位于): #{version_dir}\n" \
          "This SketchUp ships Ruby #{RUBY_VERSION} (expected stage " \
          "directory: #{ruby_version_dir}). Rebuild msp_lib for Ruby " \
          "#{ruby_version_dir} and copy SDL2/Newton here.\n" \
          "当前 SketchUp 内嵌 Ruby #{RUBY_VERSION}（对应 stage 目录：" \
          "#{ruby_version_dir}）。请为 Ruby #{ruby_version_dir} 重新编译 " \
          "msp_lib，并将 SDL2/Newton 库复制到此处。"
      end

      def build_load_error(err)
        "MSPhysics: failed to load the native library " \
          "#{native_extension_path}.\n" \
          "MSPhysics: 原生库加载失败：#{native_extension_path}。\n" \
          "Error (错误): #{err.class}: #{err.message}\n" \
          "This usually means msp_lib was built for a different Ruby " \
          "version/ABI (this SketchUp ships Ruby #{RUBY_VERSION}). " \
          "Rebuild msp_lib for Ruby #{ruby_version_dir}.\n" \
          "这通常表示 msp_lib 是为其他 Ruby 版本/ABI 编译的（当前 " \
          "SketchUp 内嵌 Ruby #{RUBY_VERSION}）。请为 Ruby " \
          "#{ruby_version_dir} 重新编译 msp_lib。"
      end

    end # class << self
  end # module ExtensionLoader
end # module MSPhysics
