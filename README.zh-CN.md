[English version](README.md)

[上游论坛帖](https://community.sketchucation.com/topic/145378/msphysics-1-0-3-16-october-2017)

[Wiki](https://github.com/AntonSynytsia/MSPhysics/wiki)

[文档](https://www.rubydoc.info/github/AntonSynytsia/MSPhysics/index)

[上游 GitHub](https://github.com/AntonSynytsia/MSPhysics)


## 演示视频

[![Sketchup2026 successfully runs MSPhysics](https://img.youtube.com/vi/Yp9EG-Qn7ik/0.jpg)](https://youtu.be/Yp9EG-Qn7ik)

MSPhysics 1.2.0 在 SketchUp 2026（Windows 11、Ruby 3.2.2）上运行。[在 YouTube 上观看](https://youtu.be/Yp9EG-Qn7ik)

## 测试状态（v1.2.0，Windows）

- SketchUp 2026：已在真机上测过（Windows 11、SketchUp 26.0.429、Ruby 3.2.2），扩展能加载，仿真能运行，见上面的演示视频。
- SketchUp 2024 / 2025：还没测过。用的是同一个 Ruby 3.2.2 构建，预期能用，但未经真机验证。非常欢迎测试反馈，请到 Issues 里说明你的 SketchUp 版本、Windows 版本和测试结果。
- SketchUp 2027：还没测过，而且目前还不支持。Ruby 3.4.9 的原生库还没编出来（见 `PORTING.md`），用 v1.2.0 装上也跑不了仿真。欢迎反馈，但请注意，得先有单独的 Ruby 3.4 构建才行。

## 安装方法（v1.2.0，Windows）

1. 下载 [Releases](https://github.com/MSPhysicsPort/MSPhysics-2024-2027/releases/tag/v1.2.0) 里的 `MSPhysics-1.2.0-unsigned.rbz`。不要直接安装仓库的 ZIP 包；如果下载的是仓库，里面可安装的文件在 `dist/MSPhysics-1.2.0-unsigned.rbz`。
2. 如果装过旧版 MSPhysics 1.2.0，先在扩展程序管理器里卸载。
3. 在 SketchUp 里打开扩展程序管理器，选“安装扩展程序”，选中这个 `.rbz` 文件。弹未签名提示时选允许安装，然后重启 SketchUp。
4. 不用另装 AMS Library。v1.2.0 自带兼容层，机器上残留的 `Plugins/ams_Lib/` 文件夹不影响加载。

语言切换：插件菜单 > MSPhysics > Language（语言），选 English / 中文（简体）。工具栏和菜单文字重启 SketchUp 后生效，对话框下次打开就用新语言。

# 简介

_注：下面的介绍是上游原文的中文译文。在本 1.2.0 移植版中，不再需要 AMS Library，全屏切换已降级；见下面的兼容性与要求和 `RubyExtension/MSPhysics/DEGRADED.md`。_

MSPhysics 是 SketchUp 的实时物理仿真扩展。

MSPhysics 可以对组和组件实例做物理仿真，每个物体可以指定形状、状态、密度、接触属性、磁铁属性、脚本等，从而实现物体与物理世界之间的复杂交互。重力、更新时间步长、求解器模型等物理世界参数也可以调整。

MSPhysics 还可以用关节（约束）把物体连起来，实现机械交互。MSPhysics 有 14 种关节：Hinge（铰链）、Motor（电机）、Servo（舵机）、Slider（滑块）、Piston（活塞）、UpVector（向上向量）、Spring（弹簧）、Corkscrew（螺旋）、BallAndSocket（球窝）、Universal（万向节）、Fixed（固定）、CurvySlider（曲线滑块）、CurvyPiston（曲线活塞）、Plane（平面）。每种关节可以指定各自的属性，比如最小 / 最大位置和角度限制，以及控制位置、角度、速度、线摩擦 / 角摩擦等的控制器。控制器本身可以用滑块控制器、键盘按键、手柄或脚本来驱动。这种灵活性让它可以做出很多东西，比如车辆、机器人和仪器。

MSPhysics 还带一个可靠的 Replay 动画工具，可以录制仿真并导出到 SkIndigo、KerkyThea 或一连串图片。

很多方面，MSPhysics 很像它的前身 SketchyPhysics。首先，MSPhysics 不是 SketchyPhysics 的新版本，它是从头写起的，集成了最新的 Newton Dynamics 物理 SDK，并且大量基于 C++ 扩展。两者都能实现相似的事情，但 MSPhysics 快得多，而且走得更远，尤其是在上面说的这些功能上。MSPhysics 还有一个先进得多、文档完善得多的脚本 API，让用户可以为模型写出更强的脚本。另一个不同是用户输入的优势。在 SketchyPhysics 里，做键盘鼠标控制的游戏很费劲，仿真运行时必须有个活动的控制面板窗口来重定向用户输入，防止 SketchUp 的键盘快捷键干扰仿真。而在 MSPhysics 里，控制面板不是必需的。MSPhysics 用 AMS Library，在 Windows 一侧可以接管用户输入并切换 SketchUp 全屏。想象一下在 SketchUp 里玩 FPS 游戏，全屏，不用担心各种键盘命令抢走仿真的控制，这在 MSPhysics 里都是可能的。


# 兼容性与要求（v1.2.0）

* 仅 Windows 64 位，SketchUp 2024、2025 或 2026（Ruby 3.2.2），见上面的测试状态。SketchUp 2027 目前还不支持：Ruby 3.4.9 的原生库还没编出来。v1.2.0 不含 macOS 构建。
* 不需要、也不使用 AMS Library。v1.2.0 自带纯 Ruby 兼容层（`ams_shim.rb`）。部分原 AMS 专属功能（全屏切换、MIDI、控制面板半透明）已降级为无操作；见 `RubyExtension/MSPhysics/DEGRADED.md`。完整移植说明见 `PORTING.md`。
* 这是未签名的测试构建。正式可发布的构建须经过 Trimble 签名门户签名。


# 第三方库

* NewtonDynamics 3.14
* SDL 2.0.5
* SDL_Mixer 2.0.1
* jQuery 1.12.4
* Ace 1.2.6
* Chosen 1.7.0
* dhtmlxSlider 4.6
