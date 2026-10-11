# 第三方资源与来源

[MIT](LICENSE) 适用于 Sipfolio 源码与本项目图标。下列资源以及运行时下载的资料保留各自许可，不因存入收藏或测试目录而改为 MIT。

## 嵌入字体

应用包含未修改的 [Fusion Pixel Font](https://github.com/TakWolf/fusion-pixel-font) 简体中文 12px 比例 OTF，来自 [2026.09.25 release](https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.09.25)，使用 SIL Open Font License 1.1。完整版权与许可证随应用资源打包：

- [主 OFL](Sources/Sipfolio/Resources/Fonts/OFL.txt)
- [ark-pixel OFL](Sources/Sipfolio/Resources/Fonts/LICENSES/ark-pixel/OFL.txt)
- [cubic-11 OFL](Sources/Sipfolio/Resources/Fonts/LICENSES/cubic-11/OFL.txt)
- [galmuri 许可证](Sources/Sipfolio/Resources/Fonts/LICENSES/galmuri/LICENSE.txt)

字体仅注册到应用进程，不安装到系统字体目录。

## 测试素材

测试照片与 API 响应仅用于开发，不进入正式应用，也不预置到用户收藏。来源、许可和派生截图说明见 [固定素材声明](Tests/SipfolioTestSupport/Fixtures/ATTRIBUTION.md)。

## 联网数据与图片

**TheCocktailDB**：通过官方 API 按名称获取配方与成品图，保留其来源页、图片原始来源和署名。官方 [API 说明](https://www.thecocktaildb.com/api.php)允许测试 key `1` 用于开发或教学，并要求公开商店发布使用生产 key；[其链接的条款](https://www.thecocktaildb.com/terms_of_use.php)说明官方接口内容使用、署名与第三方权利范围（该页面正文目前使用 TheMealDB 名称）。本工程使用开发测试访问，没有配置生产 key。MIT 不授予这些配方或图片的再分发权。

接口 `strCreativeCommonsConfirmed` 仅按原值保存。`No` 或空值不表示没有图片，也不标为已确认 CC；图片的具体使用范围要查看原始来源。

**Wikimedia Commons**：图片依照各文件页面的许可。下载前通过官方 imageinfo 核对作者、来源与许可，记录许可链接；不能把整个 Commons 当作单一许可来源。[Commons 复用说明](https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia)。

**Openverse／Flickr**：Openverse 是索引，索引中的许可可能滞后。应用只查询 Commons／Flickr 候选，保存前重新核对原始来源；无法确认时不采用。索引和下载许可分别以来源记录为准。[Openverse API 文档](https://docs.openverse.org/api/)。

用户自己的照片及备注由用户管理，项目许可证不改变其权利。分享导出的图片或收藏内容时，应一并保留来源所要求的署名和许可信息。
