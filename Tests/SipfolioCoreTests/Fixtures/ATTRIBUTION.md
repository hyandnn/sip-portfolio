# Test photograph

`hendricks.jpg` is **Hendrick's gin 001.jpg** by **Lennert B**, copied without modification from Wikimedia Commons.

- Source: https://commons.wikimedia.org/wiki/File:Hendrick%27s_gin_001.jpg
- License selected: Creative Commons Attribution 3.0 Unported (CC BY 3.0)
- License: https://creativecommons.org/licenses/by/3.0/

This photograph is used only by development tests. Generated cutouts and screenshots are derivatives (background removed and a white outline added). The app does not preload this photo or a sample collection.

# Cocktail photograph and recipe fixture

`gin-tonic.jpg` was downloaded through TheCocktailDB's public Gin And Tonic record (11403). The record credits **pxhere.com**, links to https://pxhere.com/en/photo/1556755, and marks `strCreativeCommonsConfirmed` as `Yes`.

- Recipe and image record: https://www.thecocktaildb.com/drink/11403
- Image: https://www.thecocktaildb.com/images/media/drink/k0508k1668422436.jpg
- Original image source: https://pxhere.com/en/photo/1556755
- Public response captured for deterministic tests: `gin-tonic-reference.json`.

The test derivative removes the background and adds a white sticker outline. Photos represent the drink, not proof that the pictured glass follows a particular saved recipe. Tests do not insert fixtures into personal collections.
# Martini API regression fixture (0.6.0)

`martini-reference.json` contains the exact matched Martini record (id 11728) from https://www.thecocktaildb.com/api/json/v1/1/search.php?s=martini, fetched 2026-10-07. It reproduces an official image URL with `strCreativeCommonsConfirmed: No`. This flag is retained as false, not relabeled as CC. Used for the local development app's official-API availability regression test, according to the API documentation and its linked development-use terms: https://www.thecocktaildb.com/api.php and https://www.thecocktaildb.com/terms_of_use.php. No Martini image is bundled in the app or test resources.
