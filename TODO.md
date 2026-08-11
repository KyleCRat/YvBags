## Future Appearance Settings

- Make the shared accent color customizable, including header text, header dividers, category text, category dividers, and matching hover/pressed accents.

## Inventory Organization Settings

- Add custom pinned-item ordering with a Settings-owned reorder UI and persistent pin ranks without changing native item-row dragging.
- Add ordered category rules to the modern category editor while preserving stable category IDs and the existing master-detail layout.
- Investigate classifying usable reward pouches that report `hasLoot = false`, using item `246754` (Pouch of Veteran Dawncrests) as the initial case. Prefer cached bag-tooltip detection if a reliable, localization-safe signature can be established; perform it during item normalization rather than row rendering or hover. Keep an offline/build-time-generated item-ID set from `ItemSparse`/`ItemEffect`/`SpellEffect` data as a fallback, not a runtime database build. These items belong in `Openable`, while `Container` remains reserved for Blizzard's container item class.

## Fixes

- Adding a new currency to be tracked in the backpack does not show up until after reopening the backpack.
