# Language support for MSPhysics (1.2.0, porting 2024-2027).
#
# Two locales: 'en' (upstream English strings, the default) and 'zh'
# (Simplified Chinese). The choice is stored in SketchUp preferences
# ('MSPhysics' / 'Language') so it survives restarts.
#
# How it applies:
# - Toolbar buttons, plugin menu and right-click menus are built when the
#   extension loads, so a language change applies to them after SketchUp
#   is relaunched (the switch shows the standard restart notice).
# - The UI dialog (html/dialog.html) and the control panel
#   (html/control_panel.html) read the setting every time they open, so
#   they switch language immediately on next open.
#
# Notes:
# - Only fixed UI chrome is translated (toolbar/menu labels, dialog
#   labels). Enum values stored in the model (body states, shape names,
#   material names, joint types) stay in English because they are data.
# - Long help tooltips inside the UI dialog stay in English in v1; the
#   visible labels are translated.
#
# @since 1.2.0

module MSPhysics
  module Language

    SUPPORTED = {
      'en' => 'English',
      'zh' => '中文（简体）'
    }.freeze

    DEFAULT = 'en'.freeze

    # English strings are the keys themselves (upstream text), so t() falls
    # back to the key when a translation is missing.
    STRINGS = {
      'zh' => {
        'Toggle UI' => '切换界面',
        'Toggle Play' => '播放 / 暂停',
        'Reset' => '重置',
        'Toggle Play 2' => '播放 / 暂停（所选）',
        'Stop' => '停止',
        'Joint Connection Tool' => '关节连接工具',
        'Edit Joints Scale' => '调整关节比例',
        'Toggle Record' => '录制开关',
        'Toggle Camera Replay' => '相机回放开关',
        'Play' => '播放',
        'Reverse' => '倒放',
        'Pause' => '暂停',
        'Clear Data' => '清除数据',
        'Show/hide MSPhysics UI.' => '显示 / 隐藏 MSPhysics 界面。',
        'Play/Pause simulation. This option starts simulation with all groups considered part of simulation.' =>
          '播放 / 暂停仿真。此选项将所有组都作为仿真的一部分启动仿真。',
        'End simulation, reset positions, and erase copied/emitted bodies.' =>
          '结束仿真，复位位置，并删除复制 / 发射的物体。',
        'Play/Pause simulation. This option starts simulation from selected groups/components. All non-selected instances will act as stationary bodies.' =>
          '播放 / 暂停仿真。此选项从选中的组 / 组件启动仿真，未选中的实例将作为静止物体。',
        'End simulation without resetting positions nor erasing emitted bodies.' =>
          '结束仿真，不复位位置，也不删除发射的物体。',
        'Activate/Deactivate joint connection tool.' => '启用 / 停用关节连接工具。',
        'Change scale of MSPhysics joints.' => '更改 MSPhysics 关节的缩放比例。',
        'Enable/disable replay animation recording.' => '启用 / 停用回放动画录制。',
        'Enable/disable camera replay.' => '启用 / 停用相机回放。',
        'Play replay animation forward.' => '正向播放回放动画。',
        'Play replay animation backward.' => '反向播放回放动画。',
        'Pause replay animation.' => '暂停回放动画。',
        'Stop replay animation and reset positions.' => '停止回放动画并复位位置。',
        'Stop replay animation, but avoid resetting positions.' => '停止回放动画，但不复位位置。',
        'Clear recorded data.' => '清除已录制的数据。',
        'State' => '状态',
        'Shape' => '形状',
        'Shape Dir' => '形状方向',
        'Material' => '材质',
        'Mass Control' => '质量控制',
        'Magnet Mode' => '磁铁模式',
        'Type' => '类型',
        'Default' => '默认',
        'Custom' => '自定义',
        'Clear Connected Joints' => '清除已连接的关节',
        'Reset Properties' => '重置属性',
        'Clear Script' => '清除脚本',
        'Make Unique ID' => '生成唯一 ID',
        'Make Same ID' => '设为相同 ID',
        'Connected Collide' => '连接体碰撞',
        'Properties' => '属性',
        'Ignore' => '忽略',
        'Export Replay to Images' => '导出回放为图片',
        'Export Replay to SKP' => '导出回放为 SKP',
        'Export Replay to Kerkythea' => '导出回放为 Kerkythea',
        'Export Replay to SkIndigo' => '导出回放为 SkIndigo',
        'Replay Settings' => '回放设置',
        'Create Buoyancy Plane' => '创建浮力平面',
        'Select All Joints' => '选择全部关节',
        'Make Compatible' => '设为兼容',
        'Delete All Attributes' => '删除全部属性',
        'Purge Unused' => '清除未用项',
        'Use Original Icons' => '使用原始图标',
        'Homepage' => '主页',
        'Wiki' => 'Wiki',
        'Models' => '模型',
        'About' => '关于',
        'Scale MSPhysics Joints' => '缩放 MSPhysics 关节',
        'Increase Speed' => '加快速度',
        'Decrease Speed' => '减慢速度',
        'MSPhysics Joints' => 'MSPhysics 关节',
        'MSPhysics Replay' => 'MSPhysics 回放',
        'Body' => '物体',
        'Bodies' => '物体',
        'Joint' => '关节',
        'Joints' => '关节',
        'Buoyancy Plane' => '浮力平面',
        'The change will take place when SketchUp is re-launched.' =>
          '更改将在 SketchUp 重新启动后生效。',
        'Language' => '语言',
        'language_restart_notice' =>
          '语言已切换。重启 SketchUp 后工具栏和菜单会使用新语言；界面对话框下次打开时即使用新语言。'
      }
    }.freeze

    class << self

      # @return [String] current language code ('en' or 'zh').
      def current
        code = Sketchup.read_default('MSPhysics', 'Language', DEFAULT)
        SUPPORTED.key?(code) ? code : DEFAULT
      end

      # Persist the language choice.
      # @param code [String] 'en' or 'zh'.
      # @return [String] the stored code.
      def set(code)
        code = SUPPORTED.key?(code) ? code : DEFAULT
        Sketchup.write_default('MSPhysics', 'Language', code)
        code
      end

      # Translate a UI string. Unknown keys and the 'en' locale return the
      # key itself, which is the upstream English text.
      # @param key [String] English UI string (or a symbolic key).
      # @return [String] translated string.
      def t(key)
        if current == DEFAULT
          key
        else
          (STRINGS[current] && STRINGS[current][key]) || key
        end
      end

      # @return [Boolean] true when the current language is Chinese.
      def chinese?
        current == 'zh'
      end

    end

  end
end
