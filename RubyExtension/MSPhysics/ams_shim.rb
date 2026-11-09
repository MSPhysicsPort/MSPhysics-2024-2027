# AMS Library shim (pure Ruby) for MSPhysics on SketchUp 2024-2027.
#
# The upstream AMS Library (v3.7.1b, 2021) was never built for Ruby 3.2/3.4
# and is unmaintained, so MSPhysics no longer depends on it. This file
# re-implements the parts of AMS that are pure Ruby / SketchUp-API based:
#   * AMS.clamp / AMS.validate_type
#   * AMS::Geometry (vector/matrix math via Geom::Vector3d/Transformation)
#   * AMS::Group (via native SketchUp Group/ComponentInstance API)
#   * AMS::IS_PLATFORM_WINDOWS / AMS::IS_RUBY_VERSION_18 (constants)
#   * Array#x / #y / #z (only if Array does not already define them)
#   * AMS::Keyboard: polling-style key state fed by SketchUp Tool
#     onKeyDown/onKeyUp events (see Simulation#onKeyDown).
#
# Win32-only parts (AMS::Window, AMS::Sketchup HWND calls, AMS::MIDI,
# AMS::Cursor screen warping) cannot be re-implemented in pure Ruby and are
# provided as no-ops that record themselves in MSPhysics::PORTING_DEGRADED
# (see MSPhysics/DEGRADED.md). They never raise.
#
# If a system AMS Library >= 3.5 is installed and loads, this shim steps
# aside and the system library is used instead.
#
# @since 1.2.0 (porting 2024-2027)

begin
  require 'json'
rescue LoadError
  # JSON is a default gem in Ruby 3.2/3.4; if it is somehow unavailable the
  # JSON.parse call sites below will raise a clear NameError instead.
end

begin
  _ams_system_ok = defined?(AMS::Lib::VERSION) &&
    Gem::Version.new(AMS::Lib::VERSION.to_s) >= Gem::Version.new('3.5')
rescue ArgumentError, NoMethodError
  _ams_system_ok = false
end

unless _ams_system_ok

module AMS

  # @!group Platform / version sentinels

  # True on Windows, false on macOS. Sketchup.platform exists since SU 2021;
  # RUBY_PLATFORM is the fallback.
  IS_PLATFORM_WINDOWS =
    if defined?(Sketchup) && Sketchup.respond_to?(:platform)
      Sketchup.platform == :platform_win
    else
      !!(RUBY_PLATFORM =~ /mswin|mingw|cygwin/i)
    end
  IS_PLATFORM_MAC = !IS_PLATFORM_WINDOWS
  # Ruby 1.8 is long gone; kept only so old references do not raise.
  IS_RUBY_VERSION_18 = false

  # @!endgroup

  # @!group Degraded-feature bookkeeping

  # Record a Win32-only feature that was requested but is degraded to a
  # no-op on SketchUp 2024+. Each feature is recorded once.
  # @param [String] feature Short feature name, e.g. 'AMS::Window.set_pos'.
  # @param [String] detail What the caller asked for / what happens instead.
  # @return [void]
  def self.note_degraded(feature, detail = nil)
    if defined?(MSPhysics) && MSPhysics.const_defined?(:PORTING_DEGRADED, false)
      list = MSPhysics::PORTING_DEGRADED
      unless list.any? { |entry| entry[:feature] == feature }
        list << { :feature => feature, :detail => detail }
        puts "MSPhysics (porting): degraded, no-op: #{feature}" +
          (detail ? " (#{detail})" : '') +
          '. See MSPhysics/DEGRADED.md.'
      end
    end
  end

  # @!endgroup

  # @!group Generic helpers

  # Clamp a value between min and max. Either bound may be nil (unbounded).
  # @param [Numeric] value
  # @param [Numeric, nil] min
  # @param [Numeric, nil] max
  # @return [Numeric] The clamped value (same object/type when in range).
  def self.clamp(value, min, max)
    return min if !min.nil? && value < min
    return max if !max.nil? && value > max
    value
  end

  # Verify that an object is an instance of one of the given classes.
  # @param [Object] obj
  # @param [Class] types One or more acceptable classes.
  # @return [Object] obj, when valid.
  # @raise [TypeError] When obj is none of the given classes.
  def self.validate_type(obj, *types)
    return obj if types.any? { |t| obj.is_a?(t) }
    raise(TypeError,
      "Expected #{types.map(&:to_s).join(' or ')}, got #{obj.class}.", caller)
  end

  # Parse a JSON string coming from a JavaScript callback (HtmlDialog).
  # Returns the fallback when the input is not a parseable JSON string.
  # Non-string input (e.g. an Array already converted by HtmlDialog) is
  # returned as-is.
  # @param [Object] params
  # @param [Object] fallback Value to return when parsing fails.
  # @return [Object]
  def self.parse_json_value(params, fallback = nil)
    return params unless params.is_a?(String)
    return fallback if params.strip.empty?
    JSON.parse(params)
  rescue JSON::ParserError
    fallback
  end

  # @!endgroup

  # Pure-Ruby replacements for AMS::Geometry (vector/matrix math).
  module Geometry

    # Scale a vector by a scalar.
    # @param [Geom::Vector3d, Array] vector
    # @param [Numeric] scale
    # @return [Geom::Vector3d]
    def self.scale_vector(vector, scale)
      to_vector(vector) * scale.to_f
    end

    # Scale a point by a scalar.
    # @param [Geom::Point3d, Geom::Vector3d, Array] point
    # @param [Numeric] scale
    # @return [Geom::Point3d, Geom::Vector3d]
    def self.scale_point(point, scale)
      s = scale.to_f
      if point.is_a?(Geom::Vector3d)
        Geom::Vector3d.new(point.x * s, point.y * s, point.z * s)
      else
        p = to_point(point)
        Geom::Point3d.new(p.x * s, p.y * s, p.z * s)
      end
    end

    # Linear interpolation between two vectors/points.
    # @param [Geom::Vector3d, Geom::Point3d] v1
    # @param [Geom::Vector3d, Geom::Point3d] v2
    # @param [Numeric] ratio 0.0..1.0
    # @return [Geom::Vector3d, Geom::Point3d]
    def self.transition_vector(v1, v2, ratio)
      r = ratio.to_f
      if v1.is_a?(Geom::Point3d) || v2.is_a?(Geom::Point3d)
        a = to_point(v1)
        b = to_point(v2)
        Geom::Point3d.new(
          a.x + (b.x - a.x) * r,
          a.y + (b.y - a.y) * r,
          a.z + (b.z - a.z) * r)
      else
        a = to_vector(v1)
        b = to_vector(v2)
        a + (b - a) * r
      end
    end

    # Linear interpolation between two numbers.
    # @param [Numeric] n1
    # @param [Numeric] n2
    # @param [Numeric] ratio 0.0..1.0
    # @return [Numeric]
    def self.transition_number(n1, n2, ratio)
      n1 + (n2 - n1) * ratio.to_f
    end

    # Linear interpolation between two colors.
    # @param [::Sketchup::Color] c1
    # @param [::Sketchup::Color] c2
    # @param [Numeric] ratio 0.0..1.0
    # @return [::Sketchup::Color]
    def self.transition_color(c1, c2, ratio)
      r = ratio.to_f
      ::Sketchup::Color.new(
        (c1.red + (c2.red - c1.red) * r).round,
        (c1.green + (c2.green - c1.green) * r).round,
        (c1.blue + (c2.blue - c1.blue) * r).round,
        (c1.alpha + (c2.alpha - c1.alpha) * r).round)
    end

    # Linear interpolation between two transformations (origin and axes are
    # lerped independently, axes re-normalized).
    # @param [Geom::Transformation] t1
    # @param [Geom::Transformation] t2
    # @param [Numeric] ratio 0.0..1.0
    # @return [Geom::Transformation]
    def self.transition_transformation(t1, t2, ratio)
      r = ratio.to_f
      origin = transition_vector(t1.origin, t2.origin, r)
      xaxis = safe_normalize(transition_vector(t1.xaxis, t2.xaxis, r))
      yaxis = safe_normalize(transition_vector(t1.yaxis, t2.yaxis, r))
      zaxis = safe_normalize(transition_vector(t1.zaxis, t2.zaxis, r))
      Geom::Transformation.new(xaxis, yaxis, zaxis, origin)
    end

    # Linear interpolation between two cameras.
    # @note The only call site (SceneData#transition) is commented out
    #   upstream; this is a best-effort implementation.
    # @param [::Sketchup::Camera] c1
    # @param [::Sketchup::Camera] c2
    # @param [Numeric] ratio 0.0..1.0
    # @return [::Sketchup::Camera]
    def self.transition_camera(c1, c2, ratio)
      r = ratio.to_f
      eye = transition_vector(c1.eye, c2.eye, r)
      target = transition_vector(c1.target, c2.target, r)
      up = transition_vector(c1.up, c2.up, r)
      cam = ::Sketchup::Camera.new(eye, target, up)
      cam.perspective = (r < 0.5 ? c1.perspective? : c2.perspective?)
      cam
    end

    # Determine whether a transformation flips handedness (negative
    # determinant, e.g. a negative scale on one axis).
    # @param [Geom::Transformation] tra
    # @return [Boolean]
    def self.is_matrix_flipped?(tra)
      tra.xaxis.cross(tra.yaxis).dot(tra.zaxis) < 0
    end

    # Get the per-axis scale of a transformation.
    # @param [Geom::Transformation] tra
    # @return [Geom::Vector3d] Scale along X, Y and Z.
    def self.get_matrix_scale(tra)
      Geom::Vector3d.new(
        tra.xaxis.length, tra.yaxis.length, tra.zaxis.length)
    end

    # Return a copy of a transformation with the scale removed.
    # @param [Geom::Transformation] tra
    # @return [Geom::Transformation]
    def self.extract_matrix_scale(tra)
      Geom::Transformation.new(
        safe_normalize(tra.xaxis),
        safe_normalize(tra.yaxis),
        safe_normalize(tra.zaxis),
        tra.origin)
    end

    # Determine whether a transformation has mutually perpendicular axes
    # (i.e. it is a rotation + (uniform or non-uniform) scale, no shear).
    # @param [Geom::Transformation] tra
    # @return [Boolean]
    def self.is_matrix_uniform?(tra)
      return false if tra.xaxis.length < 1.0e-12 ||
        tra.yaxis.length < 1.0e-12 || tra.zaxis.length < 1.0e-12
      x = tra.xaxis.normalize
      y = tra.yaxis.normalize
      z = tra.zaxis.normalize
      x.dot(y).abs < 1.0e-6 &&
        x.dot(z).abs < 1.0e-6 && y.dot(z).abs < 1.0e-6
    end

    # Determine whether all given points lie in one plane.
    # @param [Array<Geom::Point3d>] points
    # @return [Boolean]
    def self.points_coplanar?(points)
      pts = points.to_a
      return true if pts.size < 4
      p0 = to_point(pts[0])
      p1 = nil
      p2 = nil
      pts[1..-1].each do |p|
        p = to_point(p)
        if p1.nil?
          p1 = p unless p == p0
        elsif p2.nil?
          p2 = p unless (p - p0).cross(p1 - p0).length < 1.0e-12
        end
        break if p1 && p2
      end
      # Fewer than 3 distinct, non-collinear points: trivially coplanar.
      return true if p1.nil? || p2.nil?
      normal = (p1 - p0).cross(p2 - p0)
      return true if normal.length < 1.0e-12
      normal.normalize!
      spread = pts.map { |p| (to_point(p) - p0).length }.max || 0.0
      tolerance = 1.0e-6 * [spread, 1.0].max
      pts.all? { |p| (normal.dot(to_point(p) - p0)).abs <= tolerance }
    end

    # Evaluate a cubic Bezier curve at parameter t.
    # @param [Numeric] t 0.0..1.0
    # @param [Geom::Point3d] p0..p3 Control points.
    # @return [Geom::Point3d]
    def self.calc_cubic_bezier_point(t, p0, p1, p2, p3)
      t = t.to_f
      u = 1.0 - t
      a = to_point(p0)
      b = to_point(p1)
      c = to_point(p2)
      d = to_point(p3)
      Geom::Point3d.new(
        u**3 * a.x + 3 * u**2 * t * b.x + 3 * u * t**2 * c.x + t**3 * d.x,
        u**3 * a.y + 3 * u**2 * t * b.y + 3 * u * t**2 * c.y + t**3 * d.y,
        u**3 * a.z + 3 * u**2 * t * b.z + 3 * u * t**2 * c.z + t**3 * d.z)
    end

    class << self
      private

      def to_vector(v)
        return v if v.is_a?(Geom::Vector3d)
        a = v.to_a
        Geom::Vector3d.new(a[0].to_f, a[1].to_f, a[2].to_f)
      end

      def to_point(p)
        return p if p.is_a?(Geom::Point3d)
        a = p.to_a
        Geom::Point3d.new(a[0].to_f, a[1].to_f, a[2].to_f)
      end

      def safe_normalize(v)
        v = to_vector(v)
        v.length > 1.0e-12 ? v.normalize : v
      end
    end

  end # module Geometry

  # Pure-Ruby replacements for AMS::Group, built on the native SketchUp API.
  #
  # Signatures mirror the AMS originals:
  #   get_definition(entity)
  #   get_entities(entity)
  #   get_bounding_box_from_faces(entity, recurse, transformation, &validation)
  #   get_vertices_from_faces(entity, recurse, transformation, &validation)
  #   get_vertices_from_faces2(entity, recurse, transformation, &validation)
  #   get_triangular_mesh(entity, recurse, transformation, &validation)
  #   get_triangular_meshes(entity, recurse, transformation, &validation)
  #   get_polygons_from_faces(entity, recurse, transformation, &validation)
  # `transformation` is an extra transform applied to the returned points
  # (callers pass nil, or a scale transform for the `*2` mesh variants).
  # `validation` is a proc deciding whether a child group/instance is
  # recursed into (see MSPhysics::Collision::ENTITY_VALIDATION_PROC).
  module Group

    # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
    # @return [Sketchup::ComponentDefinition]
    def self.get_definition(entity)
      entity.definition
    end

    # @param [::Sketchup::Group, ::Sketchup::ComponentInstance] entity
    # @return [Sketchup::Entities]
    def self.get_entities(entity)
      if entity.is_a?(::Sketchup::ComponentInstance)
        entity.definition.entities
      else
        entity.entities
      end
    end

    # @return [Geom::BoundingBox] Bounding box of all (valid) faces,
    #   in the entity's local coordinates.
    def self.get_bounding_box_from_faces(entity, recurse, transformation, &validation_proc)
      bb = Geom::BoundingBox.new
      collect_faces(get_entities(entity), transformation, recurse, validation_proc) do |face, tra|
        face.vertices.each { |v| bb.add(v.position.transform(tra)) }
      end
      bb
    end

    # @return [Array<Geom::Point3d>] Unique face vertices, in the entity's
    #   local coordinates. Fresh Point3d objects (callers mutate them).
    def self.get_vertices_from_faces(entity, recurse, transformation, &validation_proc)
      vertices = []
      collect_faces(get_entities(entity), transformation, recurse, validation_proc) do |face, tra|
        face.vertices.each do |v|
          p = v.position.transform(tra)
          vertices << p unless vertices.include?(p)
        end
      end
      vertices
    end

    # @return [Array<Array<Geom::Point3d>>] One vertex array per direct
    #   child group/instance (plus one for faces directly in the entity).
    #   Used for compound collisions, where every sub-group is one convex.
    def self.get_vertices_from_faces2(entity, recurse, transformation, &validation_proc)
      collections = []
      entities = get_entities(entity)
      direct = []
      entities.each do |e|
        next unless e.is_a?(::Sketchup::Face)
        e.vertices.each do |v|
          p = v.position.transform(transformation || Geom::Transformation.new)
          direct << p unless direct.include?(p)
        end
      end
      collections << direct unless direct.empty?
      return collections unless recurse
      entities.each do |e|
        next unless e.is_a?(::Sketchup::Group) || e.is_a?(::Sketchup::ComponentInstance)
        next if validation_proc && !validation_proc.call(e)
        sub = get_vertices_from_faces(e, true, transformation, &validation_proc)
        collections << sub unless sub.empty?
      end
      collections
    end

    # @return [Geom::PolygonMesh] Triangulated mesh of all (valid) faces.
    def self.get_triangular_mesh(entity, recurse, transformation, &validation_proc)
      mesh = Geom::PolygonMesh.new
      collect_faces(get_entities(entity), transformation, recurse, validation_proc) do |face, tra|
        add_face_to_mesh(mesh, face, tra)
      end
      mesh
    end

    # @return [Array<Geom::PolygonMesh>] One mesh per direct child
    #   group/instance (plus one for faces directly in the entity).
    def self.get_triangular_meshes(entity, recurse, transformation, &validation_proc)
      meshes = []
      entities = get_entities(entity)
      direct = Geom::PolygonMesh.new
      entities.each do |e|
        next unless e.is_a?(::Sketchup::Face)
        add_face_to_mesh(direct, e, transformation || Geom::Transformation.new)
      end
      meshes << direct if direct.count_polygons > 0
      return meshes unless recurse
      entities.each do |e|
        next unless e.is_a?(::Sketchup::Group) || e.is_a?(::Sketchup::ComponentInstance)
        next if validation_proc && !validation_proc.call(e)
        sub = get_triangular_mesh(e, true, transformation, &validation_proc)
        meshes << sub if sub.count_polygons > 0
      end
      meshes
    end

    # @return [Array<Array<Geom::Point3d>>] One 3-point array per triangle.
    def self.get_polygons_from_faces(entity, recurse, transformation, &validation_proc)
      triplets = []
      collect_faces(get_entities(entity), transformation, recurse, validation_proc) do |face, tra|
        face_mesh = face.mesh(0)
        (1..face_mesh.count_polygons).each do |i|
          triplets << face_mesh.polygon_points_at(i).map { |p| p.transform(tra) }
        end
      end
      triplets
    end

    class << self
      private

      # Yield each [face, accumulated_transform] pair. `base_tra` (nil for
      # identity) is applied to top-level faces; child transforms accumulate
      # down the hierarchy so returned points are in the top entity's
      # local coordinates.
      def collect_faces(entities, base_tra, recurse, validation_proc, &block)
        base = base_tra || Geom::Transformation.new
        entities.each do |e|
          if e.is_a?(::Sketchup::Face)
            block.call(e, base)
          elsif recurse && (e.is_a?(::Sketchup::Group) || e.is_a?(::Sketchup::ComponentInstance))
            next if validation_proc && !validation_proc.call(e)
            collect_faces(get_entities(e), base * e.transformation,
              true, validation_proc, &block)
          end
        end
      end

      # Append one (triangulated) face to a PolygonMesh.
      def add_face_to_mesh(mesh, face, tra)
        face_mesh = face.mesh(0)
        (1..face_mesh.count_polygons).each do |i|
          points = face_mesh.polygon_points_at(i).map { |p| p.transform(tra) }
          indices = points.map { |p| mesh.add_point(p) }
          mesh.add_polygon(*indices)
        end
      end
    end

  end # module Group

  # Polling-style keyboard state, fed by native SketchUp Tool events.
  #
  # The old AMS implementation queried the Win32 keyboard state at any
  # moment. There is no SketchUp API for that; instead the active Tool's
  # onKeyDown/onKeyUp (Simulation, JointTool, JointConnectionTool) feed
  # this queue via note_key_down/note_key_up, and simulation/script code
  # polls key/key_down?/shift_down?/control_down? as before.
  # Key state is cleared when the simulation tool deactivates.
  module Keyboard

    # Virtual-key codes (Win32 VK_ values, which SketchUp passes to
    # Tool#onKeyDown/onKeyUp) for the key names used by MSPhysics scripts.
    KEY_CODES = {
      'backspace' => 8, 'tab' => 9, 'return' => 13, 'enter' => 13,
      'shift' => 16, 'control' => 17, 'ctrl' => 17, 'alt' => 18,
      'pause' => 19, 'capslock' => 20, 'escape' => 27, 'space' => 32,
      'pageup' => 33, 'pagedown' => 34, 'end' => 35, 'home' => 36,
      'left' => 37, 'up' => 38, 'right' => 39, 'down' => 40,
      'insert' => 45, 'delete' => 46,
      'numpad0' => 96, 'numpad1' => 97, 'numpad2' => 98, 'numpad3' => 99,
      'numpad4' => 100, 'numpad5' => 101, 'numpad6' => 102, 'numpad7' => 103,
      'numpad8' => 104, 'numpad9' => 105,
      'multiply' => 106, 'add' => 107, 'subtract' => 109,
      'decimal' => 110, 'divide' => 111,
      'f1' => 112, 'f2' => 113, 'f3' => 114, 'f4' => 115, 'f5' => 116,
      'f6' => 117, 'f7' => 118, 'f8' => 119, 'f9' => 120, 'f10' => 121,
      'f11' => 122, 'f12' => 123
    }.freeze
    CODE_TO_NAME = KEY_CODES.invert.freeze
    # SketchUp Tool flags bitmask (see Sketchup::Tool docs).
    FLAG_SHIFT = 0x0004
    FLAG_CONTROL = 0x0008

    @states = {}

    class << self
      # @!group Polling (AMS-compatible)

      # Get state of a key: 1 if down, 0 if up.
      # @param [String, Symbol, Integer] vk Key name or virtual-key code.
      # @return [Integer]
      def key(vk)
        key_down?(vk) ? 1 : 0
      end

      # Determine whether a key is currently down.
      # @param [String, Symbol, Integer] vk Key name or virtual-key code.
      # @return [Boolean]
      def key_down?(vk)
        !!@states[normalize_key(vk)]
      end

      # Determine whether Shift is currently down.
      # @return [Boolean]
      def shift_down?
        !!@states['shift']
      end

      # Determine whether Ctrl is currently down.
      # @return [Boolean]
      def control_down?
        !!@states['control'] || !!@states['ctrl']
      end

      # Determine whether Ctrl is currently up (inverse of control_down?).
      # @return [Boolean]
      def control_up?
        !control_down?
      end

      # Get the virtual-key code for a key name.
      # @param [String, Symbol, Integer] vk Key name or code.
      # @return [Integer, nil]
      def get_key_code(vk)
        return vk if vk.is_a?(Integer)
        name = vk.to_s.downcase
        return KEY_CODES[name] if KEY_CODES.key?(name)
        return name.upcase.ord if name.length == 1
        nil
      end

      # @!endgroup
      # @!group Native Tool event feed

      # Record a key press from Tool#onKeyDown. `key` is the integer
      # virtual-key code SketchUp passes; `flags` is its flags bitmask.
      # @param [Integer] key
      # @param [Integer] flags
      # @return [void]
      def note_key_down(key, flags = 0)
        name = key_name_for_code(key)
        @states[name] = true
        @states['shift'] = true if (flags & FLAG_SHIFT) != 0
        @states['control'] = true if (flags & FLAG_CONTROL) != 0
        @states['shift'] = true if name == 'shift'
        @states['control'] = true if name == 'control' || name == 'ctrl'
      end

      # Record a key release from Tool#onKeyUp.
      # @param [Integer] key
      # @param [Integer] flags
      # @return [void]
      def note_key_up(key, flags = 0)
        name = key_name_for_code(key)
        @states.delete(name)
        @states.delete('shift') if name == 'shift' && (flags & FLAG_SHIFT) == 0
        if (name == 'control' || name == 'ctrl') && (flags & FLAG_CONTROL) == 0
          @states.delete('control')
          @states.delete('ctrl')
        end
      end

      # Forget all key state (called when the simulation tool deactivates).
      # @return [void]
      def clear_all
        @states.clear
      end

      # Translate a virtual-key code to the AMS key name used by scripts.
      # @param [Integer] code
      # @return [String]
      def key_name_for_code(code)
        return CODE_TO_NAME[code] if CODE_TO_NAME.key?(code)
        return code.chr.downcase if code >= 32 && code < 127
        "vk#{code}"
      end

      # @!endgroup

      private

      def normalize_key(vk)
        # Integer codes go through the same mapping as note_key_down, so
        # key(87) and key('w') address the same state.
        return key_name_for_code(vk) if vk.is_a?(Integer)
        name = vk.to_s.downcase
        return 'control' if name == 'ctrl'
        name
      end
    end

  end # module Keyboard

  # Win32-only window manipulation. No-ops on SketchUp 2024+ (Qt windows):
  # there is no Ruby API for HWND-level operations, and Win32 calls against
  # Qt windows are ineffective. Every call is recorded once in
  # MSPhysics::PORTING_DEGRADED.
  module Window
    class << self
      def lock_update(_handle)
        AMS.note_degraded('AMS::Window.lock_update', 'window redraw locking is not available')
        nil
      end

      def close(_handle)
        AMS.note_degraded('AMS::Window.close', 'dialog close via HWND is not available')
        nil
      end

      def set_pos(_handle, *_args)
        AMS.note_degraded('AMS::Window.set_pos', 'dialog positioning via HWND is not available; HtmlDialog# set_size/position is used instead')
        nil
      end

      def set_long(_handle, _index, _value)
        AMS.note_degraded('AMS::Window.set_long', 'window style changes via HWND are not available')
        nil
      end

      def get_long(_handle, _index)
        AMS.note_degraded('AMS::Window.get_long', 'window style query via HWND is not available')
        0
      end

      def show(_handle, _cmd)
        AMS.note_degraded('AMS::Window.show', 'window show/hide via HWND is not available')
        nil
      end

      def set_layered_attributes(_handle, _key, _alpha, _flags)
        AMS.note_degraded('AMS::Window.set_layered_attributes', 'control-panel fade/transparency via layered windows is not available')
        nil
      end

      def get_size(_handle)
        AMS.note_degraded('AMS::Window.get_size', 'window size via HWND is not available')
        nil
      end

      def get_client_rect(_handle)
        AMS.note_degraded('AMS::Window.get_client_rect', 'client rect via HWND is not available')
        nil
      end

      def set_size(_handle, _w, _h, _repaint)
        AMS.note_degraded('AMS::Window.set_size', 'dialog resize via HWND is not available; HtmlDialog#set_size is used instead')
        nil
      end

      def is_visible?(_handle)
        true
      end

      def is_restored?(_handle)
        true
      end

      def is_active?(_handle)
        AMS.note_degraded('AMS::Window.is_active?', 'dialog focus query via HWND is not available')
        false
      end
    end
  end # module Window

  # Win32-only SketchUp main-window operations. No-ops, except
  # get_viewport_rect (native replacement) and is_main_window_active?
  # (assumed true: without the Win32 hook there is no way to know, and
  # callers treat false as "ignore all keyboard input").
  module Sketchup
    class << self
      def is_main_window_active?
        true
      end

      def find_window_by_caption(_caption)
        AMS.note_degraded('AMS::Sketchup.find_window_by_caption', 'dialog HWND lookup is not available; dialog handles are nil')
        nil
      end

      def show_trays(_state)
        AMS.note_degraded('AMS::Sketchup.show_trays', 'tray show/hide during replay is not available')
        nil
      end

      # The old threaded (non-blocking) abort dialog has no HtmlDialog
      # equivalent; the export simply runs to completion. The message is
      # shown on the status bar instead of blocking the export.
      def threaded_messagebox(_caption, message, &_block)
        AMS.note_degraded('AMS::Sketchup.threaded_messagebox', 'non-blocking abort dialog is not available; export cannot be aborted mid-run')
        ::Sketchup.set_status_text(message.to_s, SB_PROMPT) if defined?(SB_PROMPT)
        nil
      end

      def get_caption
        if defined?(::Sketchup) && ::Sketchup.active_model && ::Sketchup.active_model.title
          ::Sketchup.active_model.title
        else
          'SketchUp'
        end
      end

      def add_observer(_observer)
        AMS.note_degraded('AMS::Sketchup.add_observer', 'Win32 window-procedure observer is not available; Simulation key/mouse events now come from native Tool callbacks')
        nil
      end

      def remove_observer(_observer)
        nil
      end

      def ignore_dialog(_handle)
        nil
      end

      def include_dialog(_handle)
        nil
      end

      def activate
        AMS.note_degraded('AMS::Sketchup.activate', 'bringing the main window to front via Win32 is not available')
        nil
      end

      def switch_full_screen(_state)
        AMS.note_degraded('AMS::Sketchup.switch_full_screen', 'fullscreen toggle via Win32 is not available')
        false
      end

      def show_toolbars(_state)
        AMS.note_degraded('AMS::Sketchup.show_toolbars', 'toolbar show/hide via Win32 is not available')
        nil
      end

      def show_toolbar_container(_index, _state, _redraw)
        AMS.note_degraded('AMS::Sketchup.show_toolbar_container', 'toolbar container show/hide via Win32 is not available')
        nil
      end

      def show_scenes_bar(_state, _redraw)
        AMS.note_degraded('AMS::Sketchup.show_scenes_bar', 'scenes bar show/hide via Win32 is not available')
        nil
      end

      def show_status_bar(_state, _redraw)
        AMS.note_degraded('AMS::Sketchup.show_status_bar', 'status bar show/hide via Win32 is not available')
        nil
      end

      def show_dialogs(_state)
        AMS.note_degraded('AMS::Sketchup.show_dialogs', 'dialog show/hide via Win32 is not available')
        nil
      end

      def set_menu_bar(_state)
        AMS.note_degraded('AMS::Sketchup.set_menu_bar', 'menu bar show/hide via Win32 is not available')
        false
      end

      def set_viewport_border(_state)
        AMS.note_degraded('AMS::Sketchup.set_viewport_border', 'viewport border via Win32 is not available')
        nil
      end

      def refresh
        nil
      end

      # Native replacement: viewport size from the active view.
      # @return [Array<Integer>] [left, top, right, bottom] in pixels.
      def get_viewport_rect
        view = defined?(::Sketchup) && ::Sketchup.active_model ?
          ::Sketchup.active_model.active_view : nil
        if view
          [0, 0, view.vpwidth, view.vpheight]
        else
          [0, 0, 800, 600]
        end
      end

      def activate_scenes_bar_tab(_tab)
        AMS.note_degraded('AMS::Sketchup.activate_scenes_bar_tab', 'scenes bar tab activation via Win32 is not available')
        nil
      end
    end
  end # module Sketchup

  # Win32 MIDI (midiOut*). No-ops: there is no cross-platform MIDI API in
  # SketchUp Ruby. Simulation sounds that used MIDI are silent.
  module MIDI
    class << self
      def open_device
        AMS.note_degraded('AMS::MIDI.open_device', 'MIDI output is Windows-only and not available')
        nil
      end

      def close_device
        nil
      end

      def play_note(_instrument, _note, _channel, _volume)
        AMS.note_degraded('AMS::MIDI.play_note', 'MIDI notes are silent')
        0
      end

      def stop_note(_id)
        nil
      end

      def reset
        nil
      end

      def set_note_position(_id, _pos, _max_range)
        nil
      end

      def change_channel_controller(_channel, _controller, _value)
        nil
      end
    end
  end # module MIDI

  # Mouse cursor control. Warping the OS cursor to a screen pixel has no
  # SketchUp API; hiding/showing is done by the Tool via onSetCursor.
  module Cursor
    class << self
      def set_pos(_x, _y, _mode = 0)
        AMS.note_degraded('AMS::Cursor.set_pos', 'warping the OS cursor to a screen pixel is not available')
        nil
      end

      def show(_state)
        AMS.note_degraded('AMS::Cursor.show', 'hiding the OS cursor via Win32 is not available')
        nil
      end

      def is_visible?
        true
      end
    end
  end # module Cursor

  # Minimal system info.
  module System
    class << self
      # The only call site compared against 6.0 (Vista); return a modern
      # version so the comparison keeps its upstream meaning.
      # @return [Float]
      def get_windows_version
        10.0
      end
    end
  end # module System

end # module AMS

end # unless _ams_system_ok

# Degraded-feature list, owned by MSPhysics (created here so AMS no-ops can
# record into it even before main.rb runs).
module MSPhysics
  PORTING_DEGRADED = [] unless const_defined?(:PORTING_DEGRADED, false)
end

# AMS gave Array #x/#y (and #z). SketchUp's own Ruby does not define them,
# but dialog/control_panel use `array.x` / `array.y` for [width, height]
# pairs. Only patch when missing, so a future SketchUp/AMS definition wins.
class Array
  unless method_defined?(:x)
    # @return [Object] First element.
    def x
      self[0]
    end
  end
  unless method_defined?(:y)
    # @return [Object] Second element.
    def y
      self[1]
    end
  end
  unless method_defined?(:z)
    # @return [Object] Third element.
    def z
      self[2]
    end
  end
end
