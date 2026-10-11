# 开发指南

## 环境与构建

需要 macOS 14+、完整 Xcode 和 Swift 6.0+。SPM 包使用原生 SwiftUI、SwiftData、Vision、Core Image 与 AppKit，无第三方 Swift 包。仓库检查额外需要 Python 3 标准库。

```sh
make build
make test
make release
```

Makefile 优先使用显式 `XCODE_DIR`／`DEVELOPER_DIR`，随后检查 `xcode-select` 所选的完整 Xcode，最后尝试标准安装路径。仅在命令环境中设置开发目录，不执行系统级切换。如果 Xcode 不在标准位置：

```sh
make test XCODE_DIR="/path/to/Xcode.app/Contents/Developer"
```

首次使用 Xcode 时需完成它要求的组件安装与许可确认。Swift 编译器过旧时升级 Xcode；只有 Command Line Tools 时安装完整 Xcode。

SPM 缓存放在 `.build/`。打包脚本读取 SwiftPM 返回的实际二进制目录，把应用资源和图标一起复制后进行 ad-hoc 签名。输出为 `build/Sipfolio.app`；替换前先在临时目录完成签名校验，避免保留旧资源。

## 开发数据

不要用日常收藏测试。启动独立实例：

```sh
build/Sipfolio.app/Contents/MacOS/Sipfolio --data-directory "$PWD/.local-data/demo"
```

运行测试不需要 AI 密钥。网络测试注入模拟 transport，素材由测试支持目标共享，不打包到正式应用。`SIPFOLIO_QA_OUTPUT` 仅指定截图输出位置，不用来读取本机已有图片或 API 结果：

```sh
SIPFOLIO_QA_OUTPUT="$PWD/build/qa" make test-ci
```

`.local/` 可存放个人维护笔记、调试报告和设计草稿；`.local-data/` 可存放开发数据库；`build/` 和 `.build/` 分别存放产物与缓存，均不进入 Git。

## 修改与验证

- UI 与模型、联网、图片处理分层，避免把持久化或网络逻辑塞进视图。
- 提交前运行与改动相关的测试、`make audit` 和 `git diff --check`。
- 配方准入、升级、去重、来源核对或后台写入保护的变化需要相应业务测试。
- 仅调整文案或图标时做构建／资源检查，不必增加照抄实现的测试。
- 测试失败先区分业务问题与 Vision 硬件不可用。CI 跳过的单项需在本机执行；详见 [验收说明](VALIDATION.md)。

`make audit` 检查 Git 管理和未忽略的候选文件，排除已删除文件，检查常见密钥模式、个人绝对路径、私人对话链接、本地数据／产物、符号链接、文档内的本地引用和关键公开文件。它不是完整密钥检测服务，也不检查 Git 历史；提交前仍应审阅差异。

## 图标与分发

```sh
make icon
make release
```

图标导出使用 AppKit 与系统 `iconutil`，不需要图像生成工具或额外密钥。当前资源说明见 [artwork](../packaging/artwork/README.md)。应用标识与钥匙串服务标识保持稳定，避免破坏既有凭据。

`make dist` 构建通用架构并生成 DMG／ZIP，版本标签工作流发布 GitHub 预览包，详见 [安装包发布](RELEASING.md)。本工程尚未配置 Developer ID 签名、公证或 App Store 分发；商店发布时应依据 [TheCocktailDB 官方 API 说明](https://www.thecocktaildb.com/api.php)配置生产访问，公共开发测试 key 不是私密凭据。

## 诊断入口

应用保留开发诊断参数。普通使用无需运行它们：

| 参数 | 行为 |
| --- | --- |
| `--verify-app-shell <output.json>` | 检查启动图标与字体后退出；必须同时指定隔离的 `--data-directory` |
| `--verify-cocktail-media <directory> --cocktail-name <name>` | 真实查询公开配方与下载图片，不访问个人收藏 |
| `--verify-cocktail-photos <directory> --cocktail-name <name>` | 真实查询补充图源并重新核对来源，不访问个人收藏 |

这些实时查询不属于默认测试或 CI，受图源网络与限制影响。涉及 DeepSeek 密钥的旧命令行诊断只在 Debug 构建提供，需开发者明确运行；常规配置使用应用设置页。
