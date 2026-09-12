- Plan an optional Warband Deposit All exclusion policy, such as retaining
  pinned items or selected categories (for example, frequently carried
  consumables). The current bank implementation deliberately uses Blizzard's
  native Deposit All behavior unchanged.

## Current Feature Plan: Shared Skins

- [PLAN.md](PLAN.md) tracks LibYvSkins development in a YvBags Libs submodule.
  The pixel dividers and creation-first window foundation are implemented:
  YvBags builds directly on library-owned window parts, without frame adapters.
  Their in-game gates precede the remaining Modern control constructors,
  Flat skin, and optional reload-bound EllesmereUI integration. Masque is
  deferred; preserve its separate icon
  ownership extension point without implementing an adapter yet.

## Future Appearance Settings

- After LibYvSkins' Modern/Flat controls are stable, plan opt-in LMS use of
  LYS for visuals, including Flat settings controls. LMS retains fields,
  layout, value synchronization, and input commits; LYS stays independent of
  LMS. Scope appearance per addon/canvas, preserve existing LMS APIs and
  default Modern behavior, and leave unrelated addons and Blizzard's Settings
  shell untouched. Include dropdown menus, sliders, tables, and focus states.
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
