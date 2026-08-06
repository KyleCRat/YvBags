# Changelog

## Unreleased

### Added
- Added profile management with Character, Specialization, Class, Realm, Faction, Global, and user-created profiles.
- Added profile selection, creation, copying, resetting, renaming, and deletion to the Blizzard Settings panel.
- Added `Ctrl+F` to focus bag search while the YvBags frame is open and the player is out of combat without changing the player's saved binding.
- Expanded bag search to include tooltip text and displayed column values.
- Added a prioritized `Openable` category for lootable container items.
- Added an explicit built-in category order led by `Openable`, `Mythic Keystone`, `Consumable`, and `Equipment`; combined armor and weapons into `Equipment`; and moved `Junk` to the bottom.
- Added a `Cosmetic` category based on Blizzard's cosmetic item tag.
- Added stable Toy, Mount, Pet, and Battle Pet collection identifiers grouped into the default `Collectables` category without tooltip matching.
- Changed the default list view to Category grouping with Rarity descending and Item Level descending as the secondary sort.
- Added account-wide item pinning through middle-click, including top-row, collapsible-group, top-of-group, and normal-sort presentation modes across all grouping and sort modes.
- Added an accent-colored item-tooltip action hint for middle-click pinning and unpinning.
- Added a compact accent marker on the left edge of pinned item rows.
- Restored Mythic Keystones to their own prioritized category and gave keystone pins a stable identity across dungeon and level changes.

### Changed
- Upgraded persistence from `LibSimpleDB-1.0` to `LibSimpleDB-2.0` and added `LibSimpleDBProfiles-1.0`.
- Adopted existing flat settings into Global once while keeping feature toggles and pinned item identities outside profile payloads.
- Classified Utility Curio, Combat Curio, and Relic consumables as Openable instead of general Consumables.

### Fixed
- Stopped showing the bound-item lock for unbound Bind on Equip and Bind on Use items.
- Kept duplicate item stacks adjacent when the selected sorts tie and placed higher-count stacks before partial stacks unless Quantity is explicitly selected.
- Fixed first-login profile selection so a character can inherit an existing Specialization profile when specialization information becomes available during login.
- Fixed intermittent item use from YvBags rows being blocked by Blizzard's protected container-action checks after other UI interactions.

## [12.0.7-1] - 2026-07-11

### Added
- Initial release of YvBags as a list-based player bag replacement.
- Added Blizzard bag open, close, and toggle replacement behavior.
- Added current-character inventory scanning for the backpack, equipped bags, and equipped reagent bag.
- Added a virtualized item list with search, grouping, primary sorting, secondary sorting, and manual bag-slot ordering.
- Added fixed columns for quantity, binding, rarity/icon, profession quality, name, expansion, sell value, item level, required level, type, and subtype.
- Added full-row item interaction with native Blizzard item behavior, tooltips, drag, use, and cooldown display.
- Added built-in category grouping and collapsible group rows.
- Added equipped bag buttons, bag swapping, empty-bag behavior, cursor item drop support, and Blizzard bag restore from the backpack button.
- Added free-space display with Blizzard bag cleanup on click.
- Added current-character money display and tracked backpack currency display.
- Added standard Blizzard settings for bag replacement, gray-junk autosell, cooldown text, scale, grouping, and sorting.
- Added optional automatic Blizzard gray-quality junk selling at vendors.
