# Test fixtures

These files are used only in isolated development tests. The test-support bundle is not an application dependency and is not copied into `Sipfolio.app`. Test databases and generated screenshots are never inserted into normal collections.

## Bottle photograph

`hendricks.jpg` is **Hendrick’s gin 001.jpg** by **Lennert B**, copied without modification from [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Hendrick%27s_gin_001.jpg).

License selected: [Creative Commons Attribution 3.0 Unported (CC BY 3.0)](https://creativecommons.org/licenses/by/3.0/). Vision cutouts and screenshots are derivatives (background removal, white outline, scaling or UI composition). When sharing those derivatives, retain this credit and indicate the changes.

## Cocktail photograph

`gin-tonic.jpg` is copied without modification from the image URL returned by TheCocktailDB’s **Gin And Tonic** record (11403):

- [TheCocktailDB record](https://www.thecocktaildb.com/drink/11403)
- [Downloaded photograph](https://www.thecocktaildb.com/images/media/drink/k0508k1668422436.jpg)
- [Original source credited by that record: pxhere.com](https://pxhere.com/en/photo/1556755)
- [PxHere’s site-wide CC0 license statement](https://pxhere.com/en/license)

The API record credits pxhere.com and reports `strCreativeCommonsConfirmed: Yes`. PxHere’s current license page states that its photos are CC0; the individual photo page was not accessible during the repository review, so no individual photographer identity is asserted. The API flag alone is not used as proof of a particular license. Use is also subject to [TheCocktailDB’s API documentation](https://www.thecocktaildb.com/api.php) and [linked content-use terms](https://www.thecocktaildb.com/terms_of_use.php).

Tests preserve the cocktail background and generate resized images or UI composites. Mock photo candidates in UI tests reuse this fixture to check layout; they do not establish a real search result or a drink/photo match.

## API responses

`gin-tonic-reference.json` and `martini-reference.json` are captured official TheCocktailDB V1 responses for deterministic development tests. Their content belongs to its sources, not Sipfolio’s MIT license. Use follows the official-endpoint development terms linked above; source links and credit fields remain in the responses.

- [Gin And Tonic](https://www.thecocktaildb.com/api/json/v1/1/search.php?s=gin%20and%20tonic)
- [Martini](https://www.thecocktaildb.com/api/json/v1/1/search.php?s=martini), captured 2026-10-07

The Martini fixture deliberately retains `strCreativeCommonsConfirmed: No` for a valid official image URL. It tests image availability separately from CC confirmation. No Martini photograph is bundled.
