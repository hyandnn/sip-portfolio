# Sipfolio icon v2 (0.6.0)

Method: built-in image_gen, using the imagegen skill. No CLI/API fallback or additional API key was used. The user requested a redesigned cute pixel-style icon; the final mint bottle with a smiling cream label was applied to AppIcon.icns.

Final asset: `sipfolio-pixel-smile-v2-final.png`. The earlier `sipfolio-pixel-smile-v2.png` is retained as the unpolished draft. The final prompt edited the tile edge while preserving the bottle. macOS sizes are produced by the AppKit packaging script, preserving alpha outside the white tile.

## Generation prompt

+Use case: logo-brand
Asset type: final macOS application icon for Sipfolio, single icon, transparent PNG.
Primary request: a beautiful minimal cute Japanese pixel-art collectible bottle with a smiling face on the label. This is a new design. A bold, instantly readable silhouette at Dock size.
Subject: one upright short broad mint-green liquor bottle, dark forest-green chunky pixel outline, short amber cork, large warm white rectangular label bearing two dark square eyes and a tiny curved stepped pixel smile, very small soft coral cheeks. The bottle itself is the lovable mascot, no separate emoji circle. Symmetrical balanced silhouette, big simple pixel clusters, restrained two-tone glass highlights.
Backdrop: a clean pure-white macOS app tile with gently stepped rounded corners, surrounded by actual transparent alpha. White tile occupies roughly 86 percent of the square canvas. Bottle occupies about 70 percent of tile height, perfectly centered with generous breathing room.
Style: authentic crisp 16-bit pixel sprite drawn on a coherent approximately 64x64 logical pixel grid, uniformly enlarged square pixels, premium calm and friendly look. Palette: mint, deep forest ink, warm white, muted amber, tiny coral accents.
Constraints: exactly one finished icon; no text or lettering; no watermark; no extra objects, stars, sparkles, hearts, border ornament, ground scene, purple background, circular yellow emoji; no glossy 3D rendering, no blur, no soft gradients; keep edges crisp. Real transparency outside the white tile.

## Tile refinement prompt

+Use case: precise-object-edit. Edit target: the supplied Sipfolio icon.
Change ONLY the white app tile and its exterior: replace the ragged textured white perimeter with ONE perfectly clean flat pure-white macOS squircle tile, geometrically smooth rounded-square edge, consistent generous margins. Remove ALL white flecks, stray pixels, textures, grey marks, soft shading, glows, grain and halos outside or inside the white tile. Every pixel outside the clean tile must be completely transparent. The white tile interior is uniformly pure white. Preserve the mint-green pixel bottle, amber cork, smiling cream label, face, colors, size and centered placement exactly. Do not change the bottle or add any object or text. The final result is a polished production app icon, not a distressed sticker.
