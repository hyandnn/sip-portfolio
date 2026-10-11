# 参与 Sipfolio

欢迎使用反馈、文档改进与代码贡献。界面目前为简体中文，Issue 和 Pull Request 可用中文或英文。

## 报告问题

在 [Issues](https://github.com/hyandnn/sip-portfolio/issues) 中说明系统／Xcode／应用版本、复现步骤、预期和实际结果。图片匹配问题请附喝法名称及公开来源链接；UI 问题可附脱敏截图。不要上传 API 密钥、个人数据库、恢复档案或私人照片。

新功能建议请说明使用场景。涉及同步、额外联网或新依赖的改动，建议先通过 Issue 讨论设计。

## 本地开发

阅读 [README](README.md)、[项目结构](docs/PROJECT_HANDOFF.md) 和 [开发指南](docs/DEVELOPMENT.md)，安装完整 Xcode（Swift 6.0+）。

```sh
make build
make test
make audit
```

无 Neural Engine 的 CI 虚拟机使用 `make test-ci`，本机应保留完整 Vision 验证。测试不需要真实 API 密钥或个人收藏。手动体验使用隔离数据目录。

## 提交改动

提交围绕一个完整目标组织，发布前合并本地试错与同一问题的补充修正。提交标题说明最终变化，正文保留必要的原因和验证结果，让主分支历史易于阅读。

1. 从项目分支创建工作分支，聚焦一个问题，保留已有收藏兼容性和后台写入保护。
2. 对业务变化运行必要的测试；UI 说明实际验证的布局或操作范围。
3. 检查 `git diff --check` 与 `make audit`。本机记录、产物及素材草稿留在忽略目录。
4. 更新相应文档；用户可见变化写入 `CHANGELOG.md` 的 Unreleased 部分。
5. 在 Pull Request 中说明问题、改后行为、验证结果与未验证的范围。

代码采用当前 Swift 文件的格式（四空格缩进），优先 Apple 原生框架。新素材需提供来源和许可；第三方资源不要套用项目 MIT 许可。请勿提交真实凭据或添加依赖在线服务的默认测试。
