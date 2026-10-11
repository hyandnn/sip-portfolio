# 测试与验收

## 自动化检查

```sh
make audit
make test
make release
git diff --check
```

`make test` 执行 Swift Testing 的核心和界面测试。所有持久化测试使用临时目录，HTTP 测试注入模拟响应，无需读取个人收藏、钥匙串或访问在线服务。

| 范围 | 检查内容 |
| --- | --- |
| 酒瓶与存储 | 保存、重启读取、编辑删除、照片写入失败、口味／年份去重、旧结构升级 |
| 配方 | 材料与实际步骤准入、别名与明确变体、推荐队列、关联保留、档案恢复与删除后不再恢复 |
| 比例 | 支持单位与分数的换算、不能完整换算时保留原文、原数据不被改写 |
| 请求与图片 | 请求字段、来源域名、缓存与限流、下载前当前许可、失败回退、后台竞争保护 |
| Vision | 真实酒瓶照片抠图，检查透明区域及不透明主体，拒绝空图或实心矩形 |
| UI | 内嵌字体、空／非空收藏、导入与编辑、照片候选和完整预览、窄窗口及导航往返 |
| 打包 | 可执行文件、字体资源、图标、Info.plist、ad-hoc 签名与完整性 |

## CI 与硬件要求

GitHub Actions 在 macOS runner 上执行 `make audit`、`make test-ci` 与 `make release`。`make test-ci` **只跳过** `realBottleBecomesTransparentSticker`：该测试依赖 Vision 前景模型，本机曾因受限环境或 Neural Engine 不可用而加载失败。

CI 通过不代表 Vision 已验收。在有正常硬件访问的 Mac 上运行 `make test`，或单独执行：

```sh
make test TEST_FLAGS='--filter realBottleBecomesTransparentSticker'
```

UI 测试使用离屏视图与测试自己的 AppKit 窗口，不操作正在使用的 Sipfolio。导航通过合成鼠标事件和实际选中状态核对，不要求不同 macOS 下截图字节一致；这些检查不替代生产应用的完整人工操作验收。

## 可重复的界面预览

```sh
SIPFOLIO_QA_OUTPUT="$PWD/build/qa" make test-ci
```

该变量只控制输出。空状态、带照片收藏、文字酒单等布局都会运行，输入始终来自测试支持目标的固定素材，不读取之前生成的截图或真实 API 结果。素材与派生截图的署名见 [ATTRIBUTION](../Tests/SipfolioTestSupport/Fixtures/ATTRIBUTION.md)。

## 手动验收

用隔离数据目录进行，避免影响日常收藏：

```sh
build/Sipfolio.app/Contents/MacOS/Sipfolio --data-directory "$PWD/.local-data/manual-qa"
```

1. 导入和拖入自己的测试照片，检查横竖方向、多个主体、重试和原图回退。
2. 保存酒瓶，编辑备注、类别、口味、年份和日期，导出 PNG；退出重开后检查记录与照片。
3. 创建有材料和步骤的配方；核对空材料／空步骤不能保存，非标准用量能保留。
4. 在三本册子间往返，组合搜索和排序；无图配方取得照片后应进入杯中画。
5. 换图时检查完整预览、失败重试和来源；下载期间换自己的照片，确认不会被后台结果替换。
6. 检查取消、删除确认、原生文件选择和嵌套弹窗。

默认测试不覆盖实时服务的可用性、所有小众喝法的图片匹配或收费 AI 调用。实时服务诊断与手动验收应独立记录，不把固定响应或离屏图片视作已经完成这些检查。预览安装包的公证、首次网络下载后的系统确认与真实跨机器安装尚不在当前验证范围。

## 可重复构建基线（2026-10-11）

从待公开文件建立不含本机缓存或资料的副本，完成 `make audit`、`make test` 和 `make release`：58 项核心与 5 项界面检查通过，包含真实照片 Vision 抠图；应用包的字体、许可证、图标及 ad-hoc 签名检查通过。本次没有读取个人收藏或钥匙串，也没有做完整生产窗口人工验收。

首次 GitHub CI 暴露导航截图逐字节比较的误报，改为核对真实选择状态后，macOS 15／Xcode 16.4 的远程 CI 已通过核心及界面测试和 Release 打包。CI 仍跳过硬件依赖的单项 Vision 检查。[远程验证记录](https://github.com/hyandnn/sip-portfolio/actions/runs/38138341018)。
