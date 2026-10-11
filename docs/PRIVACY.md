# 隐私与联网行为

收藏保存于本机，应用没有用户账户、云同步或分析统计上报。手动导入、编辑和浏览已存资料不需要 API 密钥。缺图的配方及待核对的推荐在应用运行时可能自动查询公开服务；断网不影响浏览已存收藏。

## 发出的内容

| 功能 | 接收方 | 请求中的内容 | 触发方式 |
| --- | --- | --- | --- |
| 酒瓶识别／补充资料 | DeepSeek 官方 API | 所选酒瓶图与酒名；图像最长边缩至 1280 px | 点击 AI 操作 |
| AI 配方草稿 | DeepSeek 官方 API | 喝法名、关联酒瓶名与类别 | 点击生成后核对保存 |
| 公开配方 | TheCocktailDB | 喝法名称及已知名称别名 | 已确认推荐的后台核对或重试 |
| 成品图搜索 | Commons／Openverse | 喝法名或输入的搜索词 | 缺图自动补充或主动换图 |
| 图片预览、下载与来源核对 | TheCocktailDB／Commons／Flickr 及其图片服务器 | 对应公开图片和来源地址 | 自动补图或手动选图 |

个人备注、既有配方内容与整个收藏数据库不会发送。AI 酒瓶识别不自动运行；生成内容需用户核对。联网服务会按其自身政策处理连接信息，例如 IP 地址。公开图片匹配不调用 DeepSeek。

## 本地保存

DeepSeek 密钥保存在 macOS 钥匙串，不写入配置文件或收藏备份。AI 确认结果存入酒瓶目录的 `knowledge.json`；照片作者、来源和许可存入成品图片目录的 `photo.json`。推荐队列和旧配方恢复档案也保存在本机。

普通更新不删除收藏。备份时退出应用并复制整个 `~/Library/Application Support/Sipfolio/`。向项目反馈问题时只提供需要的脱敏材料，不上传密钥、数据库、恢复档案或个人照片。

## 外部服务

- [DeepSeek 隐私政策](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)
- [TheCocktailDB API](https://www.thecocktaildb.com/api.php) 与 [条款](https://www.thecocktaildb.com/terms_of_use.php)
- [Wikimedia 隐私政策](https://foundation.wikimedia.org/wiki/Policy:Privacy_policy)
- [Openverse](https://openverse.org/)
- [Flickr 隐私政策](https://www.flickr.com/help/privacy)

服务与图片来源的许可说明见 [第三方声明](../THIRD_PARTY_NOTICES.md)。
