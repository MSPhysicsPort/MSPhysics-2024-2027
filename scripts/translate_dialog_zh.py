#!/usr/bin/env python3
# Generate the Simplified Chinese copies of the MSPhysics UI dialog HTML
# files (html/dialog.zh.html, html/control_panel.zh.html) from the English
# originals. Only visible UI chrome is translated: tab names, headings,
# field labels, buttons and short status notes. Deliberately NOT translated:
#   - <option> values (solver passes, units, editor themes, joint types):
#     they are data/enum values, and the dialog JS reads some of them back.
#   - title="..." tooltips: long English help texts (v1 keeps them).
#   - Script-tab help paragraphs: they contain Ruby code identifiers.
#   - Joint description paragraphs: long English documentation.
# Re-run after editing dialog.html: python3 scripts/translate_dialog_zh.py
# (Ruby 1.2.0, language support).
import re

DIALOG_LABELS = {
    'Accel': '加速度', 'Adjust Pin to Child': '调整销钉到子体',
    'Adjust Pin to Parent': '调整销钉到父体', 'Alignment': '对齐',
    'Alignment Power': '对齐强度', 'Angle Limits': '角度限制',
    'Angle Units': '角度单位', 'Angular Damp': '角阻尼',
    'Angular Friction': '角摩擦', 'Angular Rate': '角速度',
    'Auto Sleep': '自动休眠', 'Bodies': '物体',
    'Bounding Box': '包围盒', 'Breaking Force': '断裂力',
    'Centre of Mass': '质心', 'Collidable': '可碰撞',
    'Collision Wireframe': '碰撞线框', 'Cone Limits': '锥形限制',
    'Connected Collide': '连接体碰撞', 'Contact Forces': '接触力',
    'Contact Points': '接触点', 'Continuous Collision': '连续碰撞',
    'Controller Mode': '控制器模式', 'Damp': '阻尼', 'Delay': '延迟',
    'Density': '密度', "Don't Readjust Pin": '不重调销钉',
    'Elasticity': '弹性', 'Enable Rotation': '启用旋转',
    'Entity ID: ': '实体 ID：', 'Free Rotate': '自由旋转',
    'Friction': '摩擦', 'Frozen': '冻结', 'Fullscreen Mode': '全屏模式',
    'Game Mode': '游戏模式', 'General Properties': '常规属性',
    'Gravity': '重力', 'Help Box': '帮助框',
    'Hide Joint Layer': '隐藏关节图层', 'Ignore': '忽略',
    'Ignore Hidden Instances': '忽略隐藏实例', 'Index: ': '索引：',
    'Kinetic Friction': '动摩擦', 'Life': '寿命', 'Limits': '限制',
    'Limits 1': '限制 1', 'Limits 2': '限制 2', 'Linear Damp': '线阻尼',
    'Linear Friction': '线摩擦', 'Linear Rate': '线速度',
    'Lock to Body Axes': '锁定到物体轴', 'Loop': '循环',
    'Magnet Force': '磁力', 'Magnet Mode': '磁铁模式',
    'Magnet Range': '磁铁范围', 'Magnet Strength': '磁铁强度',
    'Magnetic': '磁性', 'Mass': '质量', 'Mass Control': '质量控制',
    'Mat. Thickness': '材质厚度', 'Material': '材质', 'Max': '最大',
    'Max 1': '最大 1', 'Max 2': '最大 2', 'Max Angle': '最大角度',
    'Max Cone Angle': '最大锥角', 'Max Position': '最大位置',
    'Max Twist Angle': '最大扭转角', 'Min': '最小', 'Min 1': '最小 1',
    'Min 2': '最小 2', 'Min Angle': '最小角度',
    'Min Position': '最小位置', 'Min Twist Angle': '最小扭转角',
    'Mode': '模式', 'Name': '名称', 'Omega': '角速度',
    'Playing Music:': '正在播放音乐：', 'Playing Sound:': '正在播放音效：',
    'Position Limits': '位置限制', 'Position Units': '位置单位',
    'Power': '功率', 'Print Margin': '打印边距', 'Rate': '速率',
    'Read Only': '只读', 'Recoil': '回弹', 'Reduction Ratio': '减速比',
    'Reverse': '反向', 'Rotation': '旋转',
    'Rotation Along Z-Axis': '沿 Z 轴旋转', 'Scale': '缩放',
    'Shape': '形状', 'Shape Dir': '形状方向', 'Softness': '柔软度',
    'Spring Constant': '弹簧常数', 'Spring Drag': '弹簧阻力',
    'Start Angle': '起始角度', 'Start Position': '起始位置',
    'Static': '静态', 'Static Friction': '静摩擦', 'Stiffness': '刚度',
    'Strength': '强度', 'Turned On': '已启用', 'Twist Limits': '扭转限制',
    'Type': '类型', 'Undo on End': '结束时撤销',
    'Update Rate': '更新频率', 'Velocity': '速度', 'aTime': '加速时间',
    # Headings (<p class="heading">) and tabs share the same texts.
    'Dialog Settings': '对话框设置', 'Scenes Animation': '场景动画',
    'Keyboard Navigation': '键盘导航', 'Debug Draw': '调试绘制',
    'Update Timestep': '更新步长', 'Solver Model': '求解器模型',
    'Settings': '设置', 'Properties': '属性', 'Entity Info': '实体信息',
    'Collision Properties': '碰撞属性', 'State': '状态', 'General': '常规',
    'Body Properties': '物体属性', 'Thruster': '推进器',
    'Emitter': '发射器', 'Simulation': '仿真', 'Script': '脚本',
    'Joint': '关节', 'Sound': '声音',
    # Buttons (<a class="button">).
    'Add': '添加', 'Assign Options to All with Name': '按名称批量设置选项',
    'Assign Script to All with Name': '按名称批量设置脚本',
    'Assign to All with Name and Type': '按名称和类型批量设置',
    'Generate Slider Controller': '生成滑块控制器',
    'Pause/Resume': '暂停 / 继续', 'Play': '播放', 'Remove': '删除',
    'Remove All': '全部删除', 'Stop': '停止',
    # Short status notes (<p class="description">).
    'Body properties cannot be edited while simulation is running.':
        '仿真运行时无法编辑物体属性。',
    'Body script cannot be edited while simulation is running.':
        '仿真运行时无法编辑物体脚本。',
    'Joint properties cannot be edited while simulation is running.':
        '仿真运行时无法编辑关节属性。',
    'Select a component instance of a joint type to edit joint properties.':
        '选择一个关节类型的组件实例以编辑关节属性。',
    'Select a group/component instance of a body type to edit body properties.':
        '选择一个物体类型的组 / 组件实例以编辑物体属性。',
    'Select a top level group/component of a body type to edit body script.':
        '选择一个物体类型的顶层组 / 组件以编辑物体脚本。',
    'Internal groups and component instances are limited to a few options.':
        '内部组和组件实例仅支持少量选项。',
    'Music may be used as background and sounds may be used as effects.':
        '音乐可用作背景，音效可用作效果音。',
    'Only one music can be played at a time.': '一次只能播放一首音乐。',
    'Up to 20 sounds can be played simultaneously.':
        '最多可同时播放 20 个音效。',
    'Font Size': '字号', 'Soft Wrap': '自动换行', 'Theme': '主题',
    'Joints work best with the world solver model set to iterative, 64 passes.':
        '关节在世界求解器模型设为迭代、64 次时效果最佳。',
    'MSPhysics UI': 'MSPhysics 界面',
}

CONTROL_PANEL = {
    'MSPhysics Control Panel': 'MSPhysics 控制面板',
    'Test Note': '测试说明',
    'Click on the main window to redirect input.': '点击主窗口以重定向输入。',
    'Move cursor outside the control panel to redirect input.':
        '将光标移出控制面板以重定向输入。',
    'Drag slider to control.': '拖动滑块进行控制。',
}


def translate_text_nodes(src, mapping):
    """Replace inner text of label/heading/tab/title/button/description
    elements when the exact text is in mapping. Attributes are untouched."""
    def sub(pattern, text):
        def repl(m):
            inner = m.group(1)
            return m.group(0).replace('>' + inner + '<',
                                       '>' + mapping[inner] + '<') \
                if inner in mapping else m.group(0)
        return re.sub(pattern, repl, text)

    src = sub(r'<label[^>]*>([^<]*)</label>', src)
    src = sub(r'<p class="heading"[^>]*>([^<]*)</p>', src)
    src = sub(r'<a href="#tab\d+">([^<]*)</a>', src)
    src = sub(r'<title>([^<]*)</title>', src)
    src = sub(r'<a[^>]*class="button"[^>]*>([^<]*)</a>', src)
    src = sub(r'<p class="description">([^<]*)</p>', src)
    src = sub(r'<pre[^>]*>([^<]*)</pre>', src)
    src = sub(r'<p[^>]*class="title"[^>]*>([^<]*)</p>', src)
    src = sub(r'<p class="note"[^>]*>([^<]*)</p>', src)
    return src


def main():
    import os
    base = os.path.join(os.path.dirname(__file__), '..', 'RubyExtension',
                        'MSPhysics', 'html')
    for name, mapping in (('dialog.html', DIALOG_LABELS),
                          ('control_panel.html', CONTROL_PANEL)):
        src_path = os.path.join(base, name)
        dst_path = os.path.join(base, name.replace('.html', '.zh.html'))
        src = open(src_path, encoding='utf-8').read()
        out = translate_text_nodes(src, mapping)
        out = out.replace('<html lang="en">', '<html lang="zh-CN">', 1)
        open(dst_path, 'w', encoding='utf-8').write(out)
        changed = len(re.findall(r'>[^<]*<', out))
        print(f'{dst_path}: written ({len(out)} bytes)')


if __name__ == '__main__':
    main()
