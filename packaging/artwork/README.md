# 应用图标源文件

`sipfolio-pixel-maine-coon-v3.png` 是当前图标：白底、烟灰缅因猫、蜂蜜金色眼睛与薄荷绿酒瓶。素材通过 AI 图像工具生成，作为本项目资源按根目录 MIT 许可提供；不含原始私人照片。

```sh
make icon
```

脚本 `scripts/generate-icon.swift` 使用 AppKit 导出 16–1024 px 的标准 macOS 尺寸，系统 `iconutil` 生成 `packaging/AppIcon.icns`。素材绘制在统一白色圆角底板内，底板外透明，最终源图不被改写。构建应用只需要已提交的 ICNS；重新导出不需要 AI 服务或密钥。

公开仓库保留当前源图、导出工具和 ICNS。历史探索、提示词记录和草稿属于本地维护资料，不参与构建。
