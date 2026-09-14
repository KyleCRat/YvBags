- Plan an optional Warband Deposit All exclusion policy, such as retaining
  pinned items or selected categories (for example, frequently carried
  consumables). The current bank implementation deliberately uses Blizzard's
  native Deposit All behavior unchanged.

## Current Feature Plan: Shared Skins

- [PLAN.md](PLAN.md) tracks LibYvSkins development in a YvBags Libs submodule.
  Pixel dividers, creation-first windows, and Modern controls are implemented
  without frame adapters. Phase 2's in-game parity gate passed; Phase 3 Flat
  skin/selection MVP and subsequent flexible window-shell refactor are confirmed
  in game. Reload-bound EllesmereUI integration is next. Masque is deferred;
  preserve its separate icon ownership extension point.

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

- is "At least" and "At most" inclusive or exclusive? is there good terms for inclusive and exclusive so we can have all options? or shoudl we swap to == != > < >= <= ?
- invalid entries need to describe WHAT is invalid, not just that it's invalid. e.g. Item ID field can't just say "Updating rule value failed: Enter or select valid value for this field." It needs to say something like: ID fields only accept numbers, enter a valid number, giving actual context to what about it was invalid
- Item ID needs to allow multiple values for a single field similar to item name / tooltip
- Binding has a blank dropdown value between "Binds to Warband" and "Bound" in the 8th slot (7th index from 0), if's a invalid selection we need to not show it
- Expansion dropdown needs to show the naems of the expansions, not "Expansion X". These should be in"Midnight" "The War Within" full name format.
- Profession Quality selector needs the icons for what the qualities are, not "Quality 1". Quality 1 and 2 will need both the war within 5 step quality icons, and the midight 2 step quality versions. There is on way to distinguise a 2 step rank 2 from a 5 step rank 2 correct?
