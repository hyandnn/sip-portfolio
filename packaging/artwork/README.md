# Sipfolio 像素图标

最终采用 `sipfolio-pixel-smile-white-v1.png`：薄荷绿像素酒瓶、奶油色标签、黄色笑脸和腮红、白色圆角底，底外透明。原紫底探索保留在 `sipfolio-pixel-smile-v1.png`。通过内置 image_gen 工具生成和编辑；未使用 CLI。

`make icon` 从最终 PNG 生成 macOS 各尺寸图标和 `packaging/AppIcon.icns`，打包时复制到应用。整个应用界面暂沿用现有风格。

## 初始提示词

Use case: logo-brand. Asset type: macOS application icon for a personal bottle collection app, Sipfolio. Primary request: one cute pixel-art liquor bottle with a cheerful smiling emoji face drawn on its front label, anime/kawaii feeling. Style: authentic crisp square-pixel sprite art, stepped edges, limited colors, no smooth illustrated outlines. Composition: square 1024x1024 canvas, one large centered bottle taking up about 70% of height, wide enough for a clearly readable smiling face at small Dock sizes. Mint green glass bottle, pale cream label, warm yellow simple smiling emoji with friendly dark eyes and tiny rosy cheeks, subtle pixel glass highlights, playful pastel lilac icon tile behind it. Dark plum pixel outlines for clear contrast. The lilac rounded square app tile has generous inset margins and transparent space outside the tile; the bottle stays completely within the tile. Friendly collectible game-item feeling. No text, no letters, no branding, no watermarks, no extra objects, no hands or limbs. Deliver one finished icon, not a mockup, not a sheet of alternatives.

## 最终白底编辑提示词

Use case: precise-object-edit. Edit the supplied Sipfolio app icon. Change ONLY the lilac/purple rounded-square background tile to clean solid white. Keep the mint-green pixel-art bottle, cream label, cheerful yellow smiling emoji with rosy cheeks, cork, all outlines, proportions, exact positioning and pixel-art details unchanged. Preserve the same rounded-square tile shape, generous margins, and transparent area outside that tile. Remove any stray edge specks outside the tile for a clean alpha edge. No purple tint or gradient in the background. No text, no watermark. One finished icon.
