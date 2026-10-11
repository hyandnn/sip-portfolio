# 项目结构与维护入口

本文件介绍当前工程，不记录私人对话或本机操作历史。首次开发请先阅读 [README](../README.md) 与 [开发指南](DEVELOPMENT.md)。

## 目录

| 目录 | 职责 |
| --- | --- |
| `Sources/Sipfolio/` | SwiftUI 页面、AppKit 集成、应用启动与设置 |
| `Sources/SipfolioCore/` | 模型、SwiftData、文件存储、图像处理、联网及纯逻辑 |
| `Tests/SipfolioCoreTests/` | 持久化、升级、配方准入、比例、匹配、请求与图片管线测试 |
| `Tests/SipfolioUITests/` | 离屏渲染与测试窗口内的导航事件检查 |
| `Tests/SipfolioTestSupport/` | 两组测试共享的固定素材和来源声明，不进入应用包 |
| `packaging/` | 应用 Info.plist、ICNS 与可重复导出的最终图标源图 |
| `scripts/` | Xcode 查找、打包、图标导出与仓库检查 |
| `.github/` | CI、问题模板与拉取请求模板 |
| `docs/` | 面向使用者和贡献者的长期文档 |

## 本地存储

`CollectionStore` 管理 `Drink` 与 `CocktailRecipe` 的 SwiftData 数据库。应用默认根目录为 `~/Library/Application Support/Sipfolio/`，可用启动参数指定隔离目录。

- `Sipfolio.store` 及其辅助文件：收藏记录。
- `Images/<UUID>/`：酒瓶原图、贴纸、缩略图与 `knowledge.json`。
- `CocktailImages/<UUID>/`：成品照片、兼容图片槽、缩略图与 `photo.json` 来源元数据。
- `recommendations.json`：已确认推荐的核对队列；临时网络失败可重试。
- `incomplete-recipes-archive.json`：旧不完整配方的本地恢复档案；原媒体保留，恢复标记避免重复恢复或删除后复活。

备份必须复制整个根目录。图片替换采用目录交换，失败时保留已有图片。模型升级测试用临时旧结构数据库，不读取个人收藏。

## 配方与图片流程

确认酒瓶推荐 → 本地核对队列 → 按名称获取公开配方 → 材料与实际步骤检查 → 保存／合并酒瓶关联 → 缺图时寻找封面。没有做法的推荐跳过，不能换算的用量保留原文。手动配方与用户确认的 AI 草稿使用相同准入规则。

`CocktailAmounts` 只负责展示比例，不改写存储内容。`CocktailNames` 处理已知别名，明确的口味和版本保留独立身份。`CollectionSearch` 处理组合关键词与排序。

图片首选名称匹配的 TheCocktailDB 原图，失败后由 `CocktailPhotoService` 搜索 Commons／Openverse。`CocktailPhotoMatcher` 依据名称、文件名、类别和尺寸排名；这是元数据匹配，不是视觉识别。下载前核对来源，写入前检查条目仍存在、名称未变且照片未被用户替换。

图片是否存在决定配方展示于杯中画还是调酒笺，不决定配方是否可保存。删除酒瓶不级联删除配方，关联名称保留。

## 维护文档

- [隐私与联网行为](PRIVACY.md)：请求内容与本地凭据。
- [第三方声明](../THIRD_PARTY_NOTICES.md)：字体、固定素材和联网来源。
- [测试与验收](VALIDATION.md)：可重复检查与验证边界。
- [CHANGELOG](../CHANGELOG.md)：功能变更历史。
- [ROADMAP](ROADMAP.md)：尚未实现的方向。
