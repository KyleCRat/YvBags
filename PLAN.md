# YvBags Plan

YvBags is a player-bag replacement addon that presents bag contents as a sortable, searchable list instead of a grid.

## UI Implementation Rules

- Prefer current Blizzard templates, mixins, and widget patterns over custom-drawn addon chrome.
- Use `ButtonFrameTemplate` or another current Blizzard panel template for the main bag frame unless a specific limitation appears.
- Use `UIPanelButtonTemplate` or current Blizzard button templates for text/action buttons.
- Use native close buttons, title handling, insets, nine-slice borders, and tooltip helpers where practical.
- Use `WowScrollBoxList` / `MinimalScrollBar` patterns for the item list if they fit the virtualization requirements.
- Use a native/secure Blizzard item-button bridge for item interactions, while rendering custom list-row visuals ourselves.
- Check the local Blizzard Interface Code before manually recreating a standard frame, button, dropdown, scroll, or settings control.

## V1 Scope

### Core Bag Addon
- Replace Blizzard player bag open/close/toggle behavior.
- Hide default Blizzard player bag frames while YvBags is active.
- Restore/show Blizzard bags from an addon button.
- Main movable and resizable bag window.
- Save bag window position, size, and scale.
  - Scale should go through our `LibPopupSlider`, similar to our other addons.
  - Scale range is 50% to 150%, with 100% centered in the control range.
- Support current character bags only.
- Player inventory only; include backpack, equipped bag slots, and the equipped reagent bag.
- Do not replace bank, reagent bank, warband bank, guild bank, or void storage.

### Item Data
- Scan player bag contents with `C_Container`.
- Debounce bag updates from `BAG_UPDATE`.
- Build a normalized item data model per occupied bag slot.
- Cache item link, item ID, icon, quality, count, type, subtype, bind info, sell value, item level, required level, expansion, profession quality, bag ID, and slot ID.
- Handle async item loading safely.
- Track empty slots and total bag capacity.
- Track per-container slot counts and free-space counts for backpack, equipped bags, and the equipped reagent bag.
- Keep the data structure category-ready for future editor support.
- Do not combine equivalent item stacks in v1.
- Do not track equipped inventory items.
- Do not track equipment set membership.
- Do not track recently unequipped items.

### Binding Info
- V1 should include full binding information for the item row.
- Store the static bind type from item info, such as bind on pickup, bind on equip, bind on use, quest item, account-bound, or warbound where available.
- Store the current binding state when it can be determined, such as already soulbound, account-bound, warbound, or unbound.
- Use tooltip-derived binding details only where Blizzard item APIs do not expose enough data.

### Categories
- Implement a v1-lite category system.
- Include built-in default categories.
- Assign each item row a category key during item normalization.
- Support grouping by category.
- Do not include a category editor in v1.
- Do not include category import/export in v1.
- Do not support dropping an item onto a category.
- Design the category data model so a v2 editor can add category icons, ordering, include/exclude rules, and custom category definitions.

### List UI
- Show bags only as a list; no grid mode.
- Use a virtualized scrolling list for performance.
- Preserve native Blizzard item interaction behavior through a hidden native/secure item-button bridge.
- Treat the full row as the item for hover, tooltip, left-click, right-click, and drag behavior.
- Include clickable column headers for sorting.
- Center column header labels/icons.
- Show header tooltips describing each column and its sort behavior.
- Right-click a column header or header divider to open the list context menu.
- Use a reserved right-side scrollbar buffer so row hover visuals extend behind the floating scrollbar without covering clipped column data.
- Use fixed v1 columns:
  - Quantity (`#`)
  - Binding icon
  - Item icon / rarity
  - Profession quality icon
  - Name
  - Expansion
  - Sell value
  - Item level
  - Required level
  - Type
  - Subtype
- Do not include a visible Quality text column in v1; rarity is shown through item name color, icon border color, and the icon/rarity sort header.
- Do not include a visible Bag/Slot column in v1; keep the column definition disabled for future optional column visibility.
- Binding and profession quality columns should be icon-only with no text fallback.
- Do not implement column visibility editing in v1.
- Do not implement column resizing in v1.
- Do not implement column reordering in v1.

### Bag/Slot Location Data
- Store each item's physical container location internally.
- The value should identify both the bag and slot, for example `Bag 0 / Slot 4` or a compact equivalent.
- Use bag/slot data for stable fallback ordering, manual sort mode, debugging, item lookup, and future optional column visibility.
- Do not expose Bag/Slot as a visible v1 column.
- Do not expose Bag/Slot as a user-facing v1 sort option.

### Bag Management
- Show equipped bag slot buttons in the YvBags frame.
- Include the equipped reagent bag slot.
- Bag buttons should show the currently equipped bag icon.
- Left-click an equipped bag button to pick up that bag for swapping.
- Drag an equipped bag button to pick up that bag for swapping.
- Right-click an equipped bag button to empty that bag into other compatible player bags.
- Empty-bag behavior should respect bag type/family compatibility.
- Empty-bag behavior should stop cleanly if there is not enough compatible space.
- Empty-bag behavior should not run if the cursor is already holding an item.
- Hovering a bag button should highlight rows from that physical bag.
- Bag button tooltips should explain left-click/drag swapping and right-click emptying.
- Support dropping a cursor-held item onto the YvBags bag/list area.
- Dropped items should stack into existing compatible stacks first when possible.
- Dropped items should then go into the first valid empty compatible slot.
- Dropping an item should avoid placing a bag into itself.
- Dropping an item should report an error if no compatible slot is available.

### Free Space Display
- Show used/total player inventory slots in the YvBags frame.
- Include backpack, equipped bags, and the equipped reagent bag in free-space totals.
- Show per-bag used/total slot details in the free-space tooltip.
- Use warning styling when free space is low or zero.
- Keep free-space data available to bag management and sorting logic.
- Clicking the free-space display should call Blizzard's built-in player bag cleanup/sort behavior.
- Bag cleanup should use Blizzard's bag sort API rather than manually rearranging the inventory.
- Bag cleanup is separate from emptying one equipped bag before replacing it.

### Sorting And Grouping
- Support Manual primary sort mode.
  - Manual sort should display items in physical bag/slot order.
  - Manual primary sort should force secondary sort to `None` and disable secondary sort selection.
- Sort by name.
- Sort by quality.
- Sort by item level.
- Sort by quantity.
- Sort by type.
- Sort by subtype.
- Sort by sell value.
- Sort by expansion.
- Sort by profession quality.
- Sort by binding.
- Sort by category.
- Support secondary sorting for non-manual primary sort modes.
- Expose grouping, primary sort, and secondary sort through the header context menu.
- Keep the open context menu visually synchronized when sort choices change.
- Group by category.
- Group by item type.
- Group by quality.
- Group by binding.
- Group by expansion.
- Support collapsible groups.
- Use styled category/group rows with modern expand/collapse buttons and accent dividers.
- Do not sort by age/newness in v1.
- Do not implement favorites-always-on-top in v1.
- Do not expose bag/slot sorting in v1.
- Do not expose inventory-slot grouping in v1.

### Search And Filtering
- Search by item name.
- Search by item type/subtype, category name, binding text, and item ID.
- Move tooltip-text search to a future category/filtering pass.
- Keep filtering architecture compatible with future category filters and custom rules.

### Item Interaction
- Show native item tooltips.
- Support item comparison tooltips.
- Click item to use/equip.
- Drag item from list.
- Pickup/split stacks through Blizzard item buttons where supported by native item button behavior.
- Show locked item state.
- Show item cooldowns.
- Render cooldown and GCD state as a smooth row-wide shade/progress overlay.
- Optionally prefix item cooldown text in the item name; do not show timer text for GCD-only cooldowns.

### Trash Automation
- Automatically sell Blizzard gray-quality junk items when a merchant/vendor window opens, if the setting is enabled.
- Do not implement manual junk marking.
- Do not implement Sorted-style trash flags.
- Do not implement favorite protection for junk selling in v1.

### Frame/UI Features
- Current character money display.
- Free-space display.
- Settings button.
  - Use a larger gear icon in the sub-header, immediately left of the search box.
- Title-bar scale control.
  - Use `LibPopupSlider`.
  - Place it immediately left of the close button.
  - Render as a text button showing the current value, such as `Scale: 100%`.
  - Use a 50% to 150% range.
- Close button.
- Show Blizzard bags button.
  - Use left-click on the backpack footer icon as the v1 Show Blizzard bags control.
- Search box.
- Search box should live in the main frame sub-header area, not inside the list body.
- Do not include character selector dropdown.
- Do not include equipment set selector dropdown.
- Do not include side panels or side tabs for secondary inventory types.
- Do not include account/realm/faction money tooltip in v1.

### Settings
- Use SavedVariables through `LibSimpleDB-1.0`.
- Embed `Libs\LibSimpleDB-1.0\embed.xml` in the TOC.
- Initialize `NS.db` with `LibStub("LibSimpleDB-1.0"):New(savedTable, defaults)` after this addon's `ADDON_LOADED` event.
- Use `NS.db:Get(...)` and `NS.db:Set(...)` for addon settings and persisted UI state.
- Use LibSimpleDB defaults fallback instead of manually backfilling every saved key.
- Use LibSimpleDB callbacks where settings changes need to refresh UI immediately.
- Use account-wide settings for general addon options.
- Use per-character settings for position, size, and scale where appropriate.
- Use the standard Blizzard Settings UI, not a custom settings window.
- Include feature toggles needed for v1 behavior.
- Include sorting/grouping settings needed for v1 behavior.
- Include a display setting for showing cooldown text in item names.
- Include a per-character frame scale setting.
- Include gray-junk autosell setting.
- Do not include settings profile management in v1.
- Do not include copy/rename/delete profile UI in v1.
- Do not include column editing settings in v1.

## Future / V2 Candidates

### New Item Handling
- Track when items were added.
- Track newly acquired items.
- Optionally show new items at the top.
- Optionally add a new-item visual indicator.

### Favorites
- Mark items as favorites.
- Optionally keep favorites at the top.
- Decide later whether favorites are worth adding.

### Category Expansion
- User-created categories.
- Category icons.
- Category ordering.
- Category include/exclude rules.
- Category rules by item name.
- Category rules by tooltip text.
- Category rules by item type/subtype.
- Category rules by quality.
- Category rules by binding.
- Category rules by expansion.
- Category settings UI.
- Category import/export.

### Column Editing
- Customizable column visibility.
- Resizable columns.
- Reorderable columns.

### Settings / Profiles
- Settings profiles.
- Default profile selection.
- Copy/rename/delete profiles.
- Appearance settings.

### Money
- Account, realm, and faction money tooltip.

### Appearance
- Custom skins/themes.
- AddOnSkins/ElvUI integration.

### Other Future Features
- Optional stack combining.
- Currency support.
- Automation settings beyond v1 gray-junk autosell.

## Explicitly Not Implementing

- Grid mode.
- Cached bags for other characters.
- Bank replacement.
- Reagent bank replacement.
- Warband/account bank replacement.
- Guild bank replacement.
- Void storage replacement.
- Equipment set filtering.
- Recently unequipped tracking.
- Equipped inventory tracking.
- Marker icons.
- Manual trash marking.
- Sorted-style trash values/flags.
- Drop item onto category to add it.
- Side panel for bank/currency/guild/void views.
- Side tabs for secondary inventory types.
- Plugin API.

## Implementation Chunks

The detailed feature list above is the scope checklist. Implementation should happen in larger chunks that produce usable, testable milestones.

### Chunk 1: Addon Foundation
- Add TOC, addon namespace, file layout, and load order.
- Embed `LibSimpleDB-1.0`.
- Add SavedVariables and defaults.
- Initialize `NS.db` after this addon's `ADDON_LOADED`.
- Add event dispatch table and core lifecycle wiring.
- Add slash command or temporary debug command to open the frame during development.
- Add placeholder main frame so load/toggle behavior can be verified early.

Validation:
- Addon loads with no Lua errors.
- SavedVariables initialize through `LibSimpleDB-1.0`.
- Placeholder frame can be opened and closed.

### Chunk 2: Inventory Data Model
- Implement player inventory container discovery, including backpack, equipped bags, and equipped reagent bag.
- Scan player bag contents with `C_Container`.
- Debounce `BAG_UPDATE`.
- Normalize item data per occupied bag slot.
- Capture empty slots, total capacity, and per-container free-space data.
- Handle async item loading refreshes.
- Capture fields needed by v1 columns, sorting, grouping, binding, expansion, profession quality, and v1-lite categories.

Validation:
- Data model accurately represents current player inventory.
- Bag/slot identity is stable.
- Reagent bag data is included.
- Empty-slot and capacity totals match the game UI.

### Chunk 3: Main Frame And Basic List
- Build the movable/resizable main frame.
- Persist position, size, and scale.
- Build virtualized list rows.
- Use a hidden native/secure item-button bridge for item interaction while rendering custom row visuals.
- Render fixed v1 columns.
- Show native item tooltips, item comparison, lock state, and cooldown state.
- Render cooldown/GCD state with a smooth row-wide overlay.
- Add current character money display.

Validation:
- The frame shows real bag items in a list.
- Scrolling works without creating one permanent row per item.
- Item click, drag, tooltip, and cooldown behavior work.
- Position and size persist after reload.

### Chunk 4: List Behavior And Categories
- Status: Complete.
- Add search in the main frame sub-header.
- Add column-header sorting with centered labels/icons, sort arrows, header tooltips, and header dividers.
- Add right-click header context menu for grouping, primary sort, and secondary sort.
- Add Manual primary sort mode using physical bag/slot order.
- Add secondary sorting for non-manual primary sort modes.
- Disable and clear secondary sort when primary sort is Manual.
- Add grouping.
- Add collapsible group rows with modern expand/collapse buttons and accent dividers.
- Implement v1-lite built-in categories.
- Assign category keys during item normalization.
- Support grouping by category, type, quality, binding, and expansion.
- Keep Bag/Slot data internal; do not show it as a v1 column, sort option, or group option.

Validation:
- Search filters visible rows correctly.
- Sorting is deterministic, including Manual fallback order.
- Secondary sorting applies only when a non-manual primary sort is active.
- Header context menu updates live when sort state changes.
- Grouping and collapse state behave correctly after bag updates.
- Category grouping works without a category editor.

### Chunk 5: Bag Management
- Status: Implemented, pending in-game validation.
- Add equipped bag buttons, including the equipped reagent bag.
- Show current equipped bag icons.
- Support left-click/drag bag pickup for swapping.
- Support right-click empty-bag behavior.
- Highlight rows from a hovered bag button.
- Support dropping a cursor-held item onto the YvBags bag/list area.
- Stack dropped items into compatible stacks first, then place into the first valid empty compatible slot.
- Add free-space display and per-bag free-space tooltip.
- Make clicking free-space call Blizzard's built-in player bag cleanup/sort behavior.

Validation:
- Bag swapping works.
- Emptying a bag respects compatibility and fails cleanly.
- Dropping items into the list places them correctly.
- Free-space display matches actual inventory state.
- Blizzard cleanup/sort triggers from the free-space display.

### Chunk 6: Replacement Behavior, Settings, And Automation
- Status: Implemented, pending in-game validation.
- Replace Blizzard player bag open/close/toggle behavior.
- Hide default Blizzard player bag frames while YvBags is active.
- Add Show Blizzard bags behavior.
  - Left-clicking the backpack icon in the footer opens/restores the Blizzard bag frames.
- Add standard Blizzard Settings UI.
- Add `LibPopupSlider` scale control.
  - Embed `Libs\LibPopupSlider-1.0\LibPopupSlider-1.0.xml` in the TOC.
  - Place the scale control on the title bar immediately left of the close button.
  - Render the scale control as a text button showing `Scale: X%`.
  - Use a 50% to 150% range.
- Add frame scale to the standard Blizzard Settings UI.
- Move the settings gear icon into the sub-header immediately left of the search box.
- Add feature toggles needed for v1.
- Add optional gray-junk autosell on merchant/vendor open.
- Final pass for combat guards, event cleanup, and reload behavior.

Validation:
- Standard bag hotkeys and bag API hooks open YvBags.
- Blizzard bags can be restored from the backpack footer icon.
- Scale changes through the title-bar `LibPopupSlider` button and Settings slider persist after reload.
- Settings persist and live-refresh where expected.
- Gray-junk autosell only runs when enabled and a merchant is open.
