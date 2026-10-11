# 构建与发布安装包

项目提供源码构建和 GitHub Releases 的预编译测试包。下载者不需要安装 Xcode；本地构建仍需要完整 Xcode。

## 本地生成

```sh
make dist
```

先构建 Apple Silicon／Intel 通用应用，再生成 `build/dist/` 下的 DMG、ZIP 和 SHA256 校验清单。脚本会检查应用签名、两种架构、最低系统版本并验证磁盘映像。DMG 包含应用、Applications 快捷入口、安装说明和许可；ZIP 可解压后移动应用。

生成后执行 `./scripts/verify-release.sh`：解压归档，核对签名与许可资源，在隔离目录中启动应用验证字体／图标，并检查安装包校验值。检查不会读取个人收藏或钥匙串，也不代替第一次从互联网下载后的 Gatekeeper 验收。

包名从 `packaging/Info.plist` 的版本生成。构建缓存、安装包与临时目录不进入 Git。输入仅为当前应用和公开安装／许可文件，不包含收藏数据库、钥匙串或测试素材。

## 自动发布

1. 修改 Info.plist 的应用版本与构建号，更新 CHANGELOG 和 `packaging/RELEASE_NOTES.md`。
2. 完成 `make audit`、相关测试、`make dist` 与产物检查，提交源码，确认分支 CI 通过。
3. 为该提交创建对应 `v<version>` 标签并推送。
4. 发布工作流检查标签与版本一致，执行 CI 测试并构建通用安装包，成功后创建 **prerelease** 并上传文件。

流程只使用 GitHub Actions 自带的仓库令牌，不需要上传个人 API 密钥。发布作业单独申请写入 release 的权限，其余作业仅有读取权限。工作流失败时不发布；不要通过移动已有版本标签掩盖失败。

## 签名范围

当前测试包采用 ad-hoc 签名，没有 Developer ID 身份和 Apple 公证。GitHub 分发预编译包与 App Store 上架是不同流程：可以先提供可下载包，首次打开仍可能需要系统对单个可信应用的确认。[Apple 启动验证说明](https://support.apple.com/zh-cn/102445)。

如需改善首次安装的系统验证体验，可另行使用 Developer ID 签名、启用适当的 hardened runtime，再提交公证与附加票据。该步骤需要可用的开发者身份；不会把证书或其私钥写入源码。它不要求上架 App Store。[Apple 分发说明](https://developer.apple.com/developer-id/)。

## 验收范围

通用架构构建和代码签名校验不等同于两种真实 Mac 都能正常使用。验证至少应包括：下载校验、拖入 Applications、首次打开、照片导入、保存／编辑、退出重开、更新保留数据与导出。当前自动检查覆盖核心、离屏布局和测试窗口中的导航；完整手动及真实 Intel 验收继续单独记录。
