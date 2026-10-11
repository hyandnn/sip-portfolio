提供可下载的 macOS 测试安装包，不需要 Xcode 或自行编译。

- **系统**：macOS 14 或更新版本。
- **架构**：Universal 包含 Apple Silicon 和 Intel 两种可执行切片；真实 Intel Mac 的安装与运行尚未完成验收。
- **安装**：下载 DMG，拖动 Sipfolio 到 Applications；也可使用 ZIP 解压后移动应用。更新前退出旧版。
- **首次打开**：测试包采用 ad-hoc 签名，未经 Apple 公证。只在确认来自本项目发布页且未被篡改时，按 [Apple 的单应用确认说明](https://support.apple.com/zh-cn/102445)处理系统提示。
- **完整性**：SHA256SUMS.txt 提供安装包校验值。

本版包含酒瓶贴纸收藏、杯中画／调酒笺、先核对做法再收录推荐、成品图匹配及换图、比例展示与原用量保留，以及此前可用旧配方的一次性恢复。图标为白底烟灰缅因猫与金黄色眼睛。

手动收藏无需 API 密钥；DeepSeek 功能需要自己的密钥，在应用设置中配置。收藏与照片保存在本机。升级前建议退出应用并备份整个 `~/Library/Application Support/Sipfolio/`；密钥单独存于钥匙串。

自动测试与本机 Vision 检查已覆盖核心流程；生产应用的完整人工操作、不同真实 Mac 的安装及首次下载后的系统确认仍需继续验收。此预览不代表已经完成签名公证或全部跨机器测试。

[使用说明](https://github.com/hyandnn/sip-portfolio#readme) · [源码许可与第三方声明](https://github.com/hyandnn/sip-portfolio/blob/main/THIRD_PARTY_NOTICES.md)
