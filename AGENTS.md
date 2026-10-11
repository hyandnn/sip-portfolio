# Sipfolio repository guidance

Read `README.md` and `docs/PROJECT_HANDOFF.md` before editing. Current user instructions take precedence.

## Product rules

- Sipfolio is a local macOS bottle and cocktail collection app. The three shelves are 藏酒屋 (bottles), 杯中画 (recipes with photos), 调酒笺 (recipes without photos).
- Bottle identity is name + manual taste variant + year. Manual taste and AI flavor descriptions are separate. Categories are free text, suggested from existing records.
- Admit recipes only with ingredients and actual instructions. Non-numeric measures are valid; keep original wording when ratios cannot be computed. Name-only recommendations must not create empty recipes.
- Confirmed recommendations are checked against public recipes before admission. Merge exact aliases, retain explicit variants and multiple bottle associations. Deleting a bottle keeps its recipes.
- Keep bottle stickers and cocktail photographs real. Cocktail images retain their background. Missing photos do not invalidate usable recipes.
- Preserve hand-entered content, notes and selected photos during enrichment; reject stale responses after rename, deletion or photo replacement.

## Architecture and privacy

- Keep models, persistence, image processing and networking in `SipfolioCore`; SwiftUI/AppKit presentation stays in `Sipfolio`.
- Prefer native Apple frameworks; no third-party Swift packages are currently required.
- Keys belong in macOS Keychain, never source, logs, ordinary config or snapshots. AI requests require a user action and editable confirmation.
- Bottle AI requests send only the selected image and name. Recipe AI requests send only the recipe name and associated bottle name/category. Public lookup sends only the drink name or entered query; never personal notes.
- Preserve source/author/license metadata. Recheck Commons/Flickr original sources before saving; a CocktailDB CC confirmation flag is not an image-existence test or a universal license guarantee.
- Persist migration/recovery archives before removing incomplete records. Keep original IDs, notes and media; explicitly deleted recipes must not reappear.

## Working and checking

- Keep public history concise: prefer one coherent commit per completed task, squash local iteration before publishing, and describe the final behavior in the commit message.
- Build with `make build` / `make release`; run `make test` for relevant checks. `make test-ci` omits only the hardware-dependent Vision integration test.
- Use temporary directories or `--data-directory` for development. Do not access personal collection data or credentials without explicit user authorization; never seed sample photos into normal collections.
- Run `make audit` before preparing changes for publication. Keep local reports, history, drafts and data under ignored `.local/`, `.local-data/` or `build/`.
- Embed fonts and retain upstream licenses. Keep current icon source in `packaging/artwork/`; regenerate with `make icon`.
- Report verified scope accurately: simulated HTTP and offscreen rendering do not establish live-service correctness or complete manual UI acceptance.
