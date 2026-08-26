# YvBags Agent Guide

This file is the standing product and engineering contract for work in the YvBags repository. Read it before changing the addon, then use `TODO.md` for deferred work.

## Product Boundary

- YvBags is a list-based replacement for the current character's player bags.
- Supported containers are the backpack, equipped bag slots, and the equipped reagent bag.
- Bank, reagent bank, warband bank, guild bank, void storage, cached characters, and grid mode are intentionally out of scope unless the user explicitly changes the product boundary.
- Preserve manual bag-slot ordering alongside sorted and grouped list modes.
- Do not quietly expand scope into a general inventory database or bank addon.

## Environment

- Current target: World of Warcraft: Midnight, Interface `120100` (12.1.0).
- WoW uses Lua 5.1. Do not use `goto`, `continue`, native bitwise operators, or later-Lua features.
- Lua 5.1.5 and `luac` are available for reusable-library suites and syntax checks. YvBags intentionally does not maintain an addon-specific automated test suite. Do not add one unless the user explicitly changes this policy; library tests and syntax checks do not replace in-game testing.
- Use four spaces, no tabs. Keep source files UTF-8 with LF endings and a final newline.
- `.editorconfig` defines editor behavior and `.gitattributes` enforces LF normalization for repository text files. Do not introduce line-ending churn in embedded libraries while making feature changes.
- Files load in the explicit order in `YvBags.toc`. When adding or moving a module, verify that every dependency loads before its consumer.

## Engineering Priorities

Performance and extensibility are requirements, not cleanup tasks for later.

- Protect scrolling, hover, bag-update, and cooldown paths from repeated expensive work.
- Keep the virtualized list virtualized. Never create one permanent frame per inventory item.
- Normalize data once, cache stable derived values, and make row rendering consume the normalized model.
- Prefer targeted refreshes over rebuilding all inventory state when the affected container is known.
- Avoid new per-frame `OnUpdate` work. If continuous updates are necessary, limit them to visible rows or an active interaction and stop them immediately afterward.
- Do not perform item API, tooltip, atlas, or formatting lookups on every hover or scroll pass when the result can be normalized or cached.
- Add abstractions only when they establish useful ownership, remove real duplication, or provide a clear extension point.
- Split modules by contextual ownership, not merely because a file is long.
- Keep related constants grouped near the top of their owning file with short section comments.
- Add section headers where they help humans locate a behavior. Avoid comments that only restate the code.
- Use contextual local names. Reserve addon-prefixed names for globals or globally named frames that genuinely require collision safety.
- Do not add defensive fallbacks for namespace values that this addon unconditionally defines earlier in the TOC.

## Blizzard-First Rule

- Blizzard's current API documentation and exported Interface code are authoritative. Sorted is useful for feature discovery, not as the authority for current API behavior.
- Before manually implementing standard UI or item behavior, inspect the current Blizzard implementation and prefer supported APIs, templates, mixins, atlases, and utilities.
- Use modern Blizzard UI templates. The main frame uses `ButtonFrameTemplate`; text controls should use current Blizzard button assets such as the modern tertiary button atlases where appropriate.
- Keep custom visuals separate from native behavior when Blizzard's visual template is unsuitable.

## Required WoW Upgrade Audit

Every time the addon target is upgraded to a new WoW version or client patch:

1. Re-export the current Blizzard Interface Lua and generated API documentation.
2. Update the TOC Interface value and compatibility documentation only after reviewing the export.
3. Compare Blizzard's current container item button hover, leave, cursor, tooltip, comparison, merchant, readable-item, and modified-click behavior with the previous export.
4. Check especially `ContainerFrameItemButton_OnEnter`, its matching leave path, `ContainerFrameItemButton_CalculateItemTooltipAnchors`, and any mixins or helpers they now call.
5. Add any new mouseover cursor or visual behavior to YvBags' immediate implementation in `Modules/ItemList/Tooltip.lua`.
6. Keep the delayed native Blizzard hover call as the compatibility fallback unless Blizzard's implementation changes enough to require redesign.
7. Test rapid row sweeps, dress-up comparison modifiers, merchant sell cursors, readable items, item comparison tooltips, item use, drag, and cursor cleanup in game.

This audit is mandatory because YvBags immediately mirrors selected Blizzard mouseover behavior before the 50 ms tooltip debounce completes. New Blizzard behavior will eventually run through the delayed native call, but it will not feel immediate until the mirror is updated.

## Architecture And Ownership

- `Defaults.lua`: addon identity constants plus addon-global, profile, character, and default category-registry data.
- `Core.lua`: `ADDON_LOADED`, legacy account-storage adoption, LibSimpleDB/Profile-manager construction, shared event dispatch, and initialization callbacks.
- `Modules/Inventory/Containers.lua`: discovery and metadata for player-owned bag containers and empty slots.
- `Modules/Inventory/Pins.lua`: account-wide stable pin identities, pin persistence, and pinned presentation settings.
- `Modules/Inventory/ItemModel.lua`: normalized occupied-slot item data, including async fallbacks, binding, pins, categories, keystones, collection kinds, caged pets, expansion, and profession quality.
- `Modules/Inventory/Inventory.lua`: live inventory state, targeted container refreshes, in-memory category reclassification, debounced reconciliation scans, pending item data, indexes, totals, and update callbacks.
- `Modules/Inventory/Categories.lua`: profile-backed category registry, stable category CRUD, cached ordering and labels, callbacks, and built-in item classification.
- `Constants/Binding.lua`: binding keys and binding predicates. Use these constants instead of repeating binding strings.
- `Modules/Bags/BagManagement.lua`: bag pickup/swap, compatible item placement, empty-bag state machine, and Blizzard bag cleanup. Keep the asynchronous emptying state machine together.
- `Modules/Bags/BlizzardBags.lua`: replacement wrappers for Blizzard bag open, close, toggle, and restore behavior.
- `Modules/Bags/JunkAutosell.lua`: optional use of Blizzard's native gray-junk selling API.
- `Modules/ItemList/Columns.lua`: fixed/disabled column definitions, header metadata, cell formatting, and column-owned visual metadata.
- `Modules/ItemList/Model.lua`: search, grouping, primary sorting, secondary sorting, manual ordering, and display-row construction. Cache sort values here rather than in row rendering.
- `Modules/ItemList/List.lua`: list state, ScrollBox composition, data-provider refreshes, and coordination between list-owned modules.
- `Modules/ItemList/Header.lua`: header visuals, sorting/grouping context menus, sort indicators, and separator interactions.
- `Modules/ItemList/SearchBox.lua`: search-box creation and list search dispatch.
- `Modules/ItemList/CursorDrop.lua`: cursor-item drop targets, insertion overlay, and active cursor polling.
- `Modules/ItemList/ItemRow.lua`: pooled item-row layout and custom visual rendering.
- `Modules/ItemList/ItemButton.lua`: native `ContainerFrameItemButtonTemplate` interaction bridge and suppression of native button art.
- `Modules/ItemList/Cooldown.lua`: secret-safe cooldown/GCD lookup, cached state, row shade, and cooldown name prefix.
- `Modules/ItemList/GroupRow.lua`: pooled category/group rows and collapse controls.
- `Modules/ItemList/Tooltip.lua`: debounced native tooltips, custom anchoring, immediate cursor feedback, and pooled-button cleanup.
- `Modules/ItemList/Layout.lua`: geometry shared by the list, header, scrollbar, and drop overlay.
- `Modules/MainFrame/MainFrame.lua`: top-level frame lifecycle, composition, and reason-scoped inventory refresh routing.
- `Modules/MainFrame/Geometry.lua`: frame scale, size, position persistence, pixel snapping, and position diagnostics.
- `Modules/MainFrame/Controls.lua`: title-bar scale control and subheader settings/search controls.
- `Modules/MainFrame/Layout.lua`: geometry shared by main-frame modules.
- `Modules/MainFrame/Footer.lua`: bag buttons, bag-space display, money, footer layout, and related tooltips.
- `Modules/MainFrame/FooterCurrencies.lua`: tracked backpack currencies, responsive fitting, currency tooltips, and untracking.
- `Modules/Settings/CategoryEditor.lua`: virtualized profile-backed category list, reorder interaction, category detail editor, and category canvas lifecycle.
- `Media.lua`: centralized fonts, textures, atlases, colors, and LibSharedMedia registration.
- `Formatting/Money.lua`: shared compact and exact money formatting.
- `Settings.lua`: LibModernSettings canvas composition, Blizzard Settings registrations, profile management, confirmations, and live setting callbacks.
- `Commands.lua`: slash commands and diagnostics.

## Critical Implementation Invariants

### Inventory Data

- `BAG_UPDATE` uses `Inventory:RefreshContainerNow` for the affected player container so counts and rows update promptly.
- Noisier follow-up events use the 0.2-second `Inventory:ScheduleScan` path to reconcile all containers.
- Preserve `itemsByLocation`, `locationKey`, bag ID, and slot index even when Bag/Slot is not user-visible. Manual mode and item-button routing depend on physical location.
- New normalized fields belong in `Modules/Inventory/ItemModel.lua`. Update pending-item diagnostics, sorting/filtering consumers, and row formatting only when they need that field.
- Item data is asynchronous. A temporary cache miss must not permanently classify an item as unknown.
- Keystone links and caged battle-pet links are special item-like records. Do not simplify them back to ordinary item-info-only handling.

### Virtualized Secure Rows

- The visible row is the item. Hovering or clicking any part of it must behave like the item icon would in Blizzard bags.
- Each pooled row uses a named `ContainerFrameItemButtonTemplate` button stretched across the row as a native interaction bridge.
- The bridge owns Blizzard click, use, drag, pickup, split-stack, cursor, and tooltip semantics. Do not replace those paths with direct calls such as `UseContainerItem`, which can taint or fail in combat.
- Keep YvBags-owned row, hover, and routing state outside the native item-button table. Use weak-keyed side tables so pooled-button refreshes do not contaminate Blizzard's protected click path.
- Middle-click is reserved for the account-wide pin toggle through the button's unregistered `OnMouseUp` path. Do not register MiddleButton with the native bridge because Blizzard routes every non-left registered click through its right-click behavior.
- All visible pixels belong to custom row regions. Native button textures are deliberately suppressed so template art is not stretched across the row.
- Configure protected button geometry and reusable regions during row initialization. Do not resize, re-anchor, or recreate protected row buttons during combat refreshes.
- Before assigning the first data provider, prewarm enough fully initialized item rows for the current viewport so ScrollBox does not lazily create native interaction bridges during combat. Keep this pool viewport-sized rather than inventory-sized.
- ScrollBox rows are pooled. Every render and reset path must clear state that could leak to the next item, including tooltip, highlight, pin marker, icon, binding, lock, cooldown, and bag-hover state.
- Never reassign the item-list data provider while a native item-button input handler is still on the stack or a normalized player item is locked. Coalesce inventory-driven rebuilds into an owned next-frame timer, retain pending work through lock transitions, and resume after unlock without polling.
- `ITEM_LOCK_CHANGED` updates only the affected normalized lock state and visible custom desaturation immediately. Do not replace the data provider or rebind the native interaction bridge from that synchronous event handler.
- Keep fast scrolling and item interaction functional in combat.

### Hover And Tooltips

- `Modules/ItemList/Tooltip.lua` immediately handles the currently mirrored cursor feedback, including dress-up, merchant sell, readable-item, and `SetCursorHoveredItem` state.
- The full Blizzard `ContainerFrameItemButton_OnEnter` path runs after `TOOLTIP_SHOW_DELAY` (`0.05` seconds) to avoid expensive tooltip rendering during quick row sweeps.
- Do not move heavy tooltip work back into immediate `OnEnter` handlers.
- Tooltip positioning can use row-edge or cursor anchoring through `USE_CURSOR_ANCHOR`. Row-edge placement chooses the side nearest the cursor, then falls back to the side with room.
- Custom tooltip lines may still be added after the native tooltip is populated; the debounce does not prevent addon-specific tooltip content.

### Cooldowns And Secret Values

- Cooldown and GCD progress is rendered as a smooth row-wide shade, not as Blizzard icon art.
- Only visible rows with active cooldowns should run cooldown `OnUpdate` work.
- Cooldown lookups are cached briefly. Preserve or improve that cache when extending cooldown display.
- WoW 12.0 cooldown values may be secret. Never compare, divide, format, or curve a secret value. If values are secret or not safely numeric, omit the custom cooldown visualization and let Blizzard behavior remain authoritative.

### Sorting, Grouping, And Drops

- The fresh default list view groups by Category, sorts primarily by Rarity descending, and sorts secondarily by Item Level descending.
- Manual primary sort means physical bag/slot order within each active group and pin-presentation partition. It forces secondary sort to `None` and disables secondary selection.
- In non-manual modes, item name and item ID break ties after the selected primary and secondary sorts so duplicate stacks remain adjacent. Within an identical item, higher-count stacks come first unless Quantity is an active sort key; physical bag/slot provides the final stable order.
- Pin state is presentation metadata and must not replace an item's base `categoryKey`; future ordered and custom category rules depend on that separation.
- Pinned presentation applies across all grouping and sort modes. The supported modes are direct top rows, a collapsible Pinned group, pins first within their normal groups, and normal active-sort placement.
- Default Category grouping uses the explicit profile-backed order declared in `Defaults.lua`. Openable, Cosmetic, Collectables, Mythic Keystone, Consumable, and Equipment lead in that order; Blizzard loot containers plus Utility Curio, Combat Curio, and Relic consumables map to `openable`; `toy`, `mount`, `pet`, and `battlepet` collection kinds share the `collectables` category; armor and weapons share the `equipment` category unless Blizzard tags the item as cosmetic; and Junk remains last. Removed built-in classifications fall back to `other` without recreating the removed definition.
- Mythic Keystones retain their own prioritized category unless pinned. Keystone pin identity is kind-based rather than link- or item-instance-based so it survives dungeon and level changes.
- Bag/Slot remains an internal, disabled column and is not a user-facing sort or group option.
- In sorted modes, a cursor-held item shows a full-list insertion overlay backed by a native container item button bound to one actual compatible empty slot.
- In Manual mode, rows remain available for normal item swapping and a bottom insertion area exposes that same native empty-slot target.
- Cursor-drop visuals never call `PickupContainerItem` or distribute a cursor stack through custom Lua. Blizzard's native item-button scripts own the single physical-slot drop in and out of combat.
- Header context menus intentionally stay open and return refresh responses when choices change.

### Bag Management

- Emptying a bag is an asynchronous state machine. Move one source slot, wait for a confirmed source-slot change, then continue.
- Never turn emptying back into a tight loop. WoW bag locks and update events do not complete synchronously.
- Exclude the source bag from destinations or items can swap back and forth forever.
- Preserve item-family compatibility, stack-first placement, cursor checks, timeout/failure handling, and the single-operation guard.
- Use Blizzard's bag sort API for cleanup; do not implement a custom physical inventory sorter.

### Persistence And Settings

- Use `LibSimpleDB-2.0` for all SavedVariables reads and writes.
- `NS.db` is the stable active profile DB returned by `NS.profileManager:GetActiveDB()`. Never replace it or read profile payload tables directly.
- `NS.globalDB` is account-wide and owns feature toggles, debug state, and pinned item identities. `NS.charDB` is per-character and owns frame position, size, and scale.
- `YvBagsDB.profiles` is exclusively owned by `LibSimpleDBProfiles-1.0`; profile selections and payloads must be accessed through `NS.profileManager` and `NS.db`.
- Account-wide pins live under the addon-global `pins.items`; regular item pins use item-ID identities and keystones use the stable `kind:keystone` identity. Pin presentation belongs to the active profile.
- Profile-owned settings are list grouping/sorting, pin presentation, cooldown-name display, and the complete category registry. Bag replacement and gray-junk selling remain addon-global.
- Keep Rename Profile and Delete Profile as selectors directly on the Settings canvas. Rename may open the name input after selection, and Delete must retain its destructive confirmation, but neither action should open an intermediate profile-selection modal.
- Treat the profile's `categories` root as one transactional value: clone it, mutate the clone, and commit the complete root through `NS.Categories`. Category changes reclassify existing normalized inventory records and must not query bag, item, or tooltip APIs.
- Add defaults in `Defaults.lua` before reading new settings. Use `Get` and `Set`, and register callbacks when a setting must refresh live UI.
- Expose user settings and profile management through Blizzard's standard Settings API. Column editors remain future work.
- UI that displays active profile identity or profile descriptors listens to manager lifecycle callbacks. `OnCharacterInfoChanged` refreshes identity-backed permanent descriptors even when the active profile does not change. Features that apply effective profile data listen to active-DB `OnDataChanged`/`OnReset`; do not refresh one feature through both manager and active-DB paths.
- A character without a stored selection performs the manager's one-time Character > Specialization > Class > Realm > Faction > Global search. If specialization identity is still loading, the manager completes that search during login without deferring construction. The persisted result is not promoted later.
- Preserve the frame's reported point, relative point, x, and y. `SetDontSavePosition(true)` and `SetUserPlaced(false)` prevent the client from applying a second saved position.

### Media And Visual Settings

- Use regular tertiary command buttons by default. Reserve small buttons for
  dense rows, tables, or genuinely constrained layouts.
- Register shared media from the structured tables in `Media.lua`; do not duplicate texture, atlas, font, binding-icon, or accent definitions in consumers.
- Access shared assets through `NS.Media` getters.
- The accent color is currently centralized but static. `TODO.md` tracks making it user-configurable, so new accent-colored regions should use `NS.Media.GetAccentColor()` and remain compatible with a future live refresh.
- Keep visual constants in the module that owns the visual. Future appearance settings should be able to override them without restructuring behavior.

## Change Workflow

1. Read `AGENTS.md`, `TODO.md`, and the owning module before changing behavior.
2. Check Blizzard's current docs/export before recreating standard UI, item, container, tooltip, or cursor behavior.
3. Identify the normalized data, model, controller, and row-rendering impact before editing. Keep those responsibilities separated.
4. Consider performance explicitly: event frequency, visible-row count, cacheability, allocations, tooltip work, and combat restrictions.
5. Implement the smallest coherent change and preserve extension points documented here or in `TODO.md`.
6. Update defaults, settings, TOC load order, README, `TODO.md`, or changelog when the behavior changes their contract.
7. Run `git diff --check` and inspect the final diff. Do not introduce unrelated formatting or metadata churn.
8. Run applicable reusable-library suites for library changes, run Lua 5.1 syntax checks for addon code, then validate in game in proportion to risk.
9. Do not commit, tag, or push unless the user explicitly asks.

## In-Game Regression Checklist

Use the relevant subset for small changes and the full list before release:

- Reload with no Lua errors and confirm SavedVariables persist.
- Open, close, and toggle YvBags through normal bag bindings; test restoring Blizzard bags.
- Resize, move, scale, reload, and confirm geometry does not jump.
- Scroll rapidly and hover rapidly without visible hitching.
- Use, drag, split, compare, and inspect items; repeat scrolling and item use in combat.
- Confirm immediate cursor feedback and the 50 ms tooltip debounce.
- Use an item and confirm targeted count refresh plus cooldown/GCD rendering.
- Test search, all grouping modes, every pin presentation mode, primary/secondary sorting, Manual mode, and collapsed groups.
- Swap and empty normal and reagent bags; test insufficient compatible space and concurrent empty attempts.
- Drop cursor items in sorted and Manual modes, including stack merging and specialty-bag compatibility.
- Check free-space totals, Blizzard cleanup, money, tracked currencies, tooltips, and currency fitting at narrow widths.
- Test settings live refresh and persistence.
- Test gray-junk autosell at a merchant with the setting both disabled and enabled.
