- Plan an optional Warband Deposit All exclusion policy, such as retaining
  pinned items or selected categories (for example, frequently carried
  consumables). The current bank implementation deliberately uses Blizzard's
  native Deposit All behavior unchanged.

## Next Major Feature: Column Customization

- Create a dedicated implementation plan before coding profile-owned column
  customization. The plan must cover column visibility, drag-and-drop ordering
  directly from the YvBags headers, drag-to-resize column widths, profile
  persistence and reset behavior, fixed or internal columns, responsive layout
  constraints, header and row alignment, virtualization, and safe live
  refreshes.

## Future Appearance Settings

- Add a shared inset-background selector for the bag and bank windows. Start
  with a curated set of compatible Blizzard
  `Interface/FrameGeneral/UIFrame*Background` file textures, keep the current
  Midnight inset background as the default, and apply changes to both frames
  live while preserving their inherited outer backgrounds.
- Make the shared accent color customizable as a low-priority appearance
  option. Decide addon-global versus profile ownership (addon-global is likely
  the better fit), add a reusable LibModernSettings color control, and replace
  file-load color snapshots with a targeted live recolor path. Apply it only to
  YvBags accent and selection visuals; keep semantic colors such as rarity,
  money, binding, and errors unchanged.
- Downlaod and Use xpac_icons.md icons instead of numbers for expansions

## Inventory Organization Settings

- Add custom pinned-item ordering with a Settings-owned reorder UI and persistent pin ranks without changing native item-row dragging.
- Investigate classifying usable reward pouches that report `hasLoot = false`, using item `246754` (Pouch of Veteran Dawncrests) as the initial case. Prefer cached bag-tooltip detection if a reliable, localization-safe signature can be established; perform it during item normalization rather than row rendering or hover. Keep an offline/build-time-generated item-ID set from `ItemSparse`/`ItemEffect`/`SpellEffect` data as a fallback, not a runtime database build. These items belong in `Openable`, while `Container` remains reserved for Blizzard's container item class.

## Fixes

- Adding a new currency to be tracked in the backpack does not show up until after reopening the backpack.
