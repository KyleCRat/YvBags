# Column Customization

Status: Implemented. Bag and bank reordering, resizing, and visibility toggles
are confirmed in game. Resize-edge limits and direct header quick actions are
added follow-ups, along with optional Bag/Slot visibility; remaining regression
validation is tracked below.

## Scope

Add profile-owned column visibility, header drag-and-drop ordering, and
header-separator drag resizing to the shared bag and bank item list. Preserve
native item interaction, virtualization, sorting, grouping, and physical bag
ordering. This feature changes the presentation of existing item data; it does
not add new inventory fields or change category classification.

## Confirmed Product Decisions

1. **Overflow:** retain today's fixed-width layout and right-edge clipping.
   Columns that do not fit extend beyond the viewport; users can widen the
   window, reduce column widths, or hide other columns to reveal them. Do not
   add horizontal scrolling, automatic filling, or automatic shrinking.
2. **Visibility:** every current user-facing column can be hidden, including
   Item Icon and Name. Allow all columns to be hidden and retain an accessible
   way to show them again. Bag/Slot is now available as a display column, hidden
   by default; it does not add a separate sorting or grouping option.
3. **Defaults:** preserve the current column sizes, order, positions, and gaps.
   Reset Columns restores that same layout, not a new responsive arrangement.

The remaining sections describe the implementation and its validation contract.

## User Experience

- Left-click a header to sort, as today. Drag its body left or right to reorder
  it, with an insertion indicator and a movement threshold that prevents an
  ordinary click from becoming a drag. Completing a drag must not also sort.
- Drag a separator to resize the column on its left, including the final
  visible column. Show a live header-and-row preview. Icons retain their
  drawing size; changing an icon column's width changes its surrounding space.
- Stop interactive expansion at the inner list's right edge, retaining the
  separator's hit area. Widen the window before expanding further. Do not clamp
  stored or mirrored widths just because another window is narrower.
- Right-click a header or the unused header background for the existing
  grouping/sorting menu plus a Columns submenu with visibility checkboxes and
  Reset Columns. Keep the menu open when toggling columns.
- Hiding a column preserves its saved order and width. Showing it restores its
  place in the complete order. Reordering visible columns moves the dragged
  key relative to its visible target without rearranging hidden keys amongst
  themselves.
- Keep the header background's context menu available even when every column
  is hidden. The Settings actions provide the same recovery path. Hidden
  columns do not remove inventory rows or turn an occupied list into a
  misleading No Items state.
- Hiding a sort/group column does not change the active sort/group or remove
  that choice from menus. Search continues using the same normalized fields,
  regardless of column visibility.
- Reset Columns restores visibility, order, and widths only. It does not reset
  profiles, categories, sorting, grouping, pins, or window geometry. Explain
  when the reset affects both windows because bank mirroring is enabled.
- Expose the same visibility/reset actions from the bag and bank Settings
  pages so they are also accessible without an open inventory window. Keep
  drag interactions on the actual list headers, not a second reorder editor.
- Preserve the current set, order, and preferred widths as the starting
  defaults. Exact minimum widths and handle hit areas need in-game validation
  with the existing font and icon sizes.

### Width And Overflow Behavior

- Every column, including Name, uses its configured fixed width. Changing
  window width changes clipping only; it does not redistribute column space,
  alter visibility, or overwrite saved widths.
- Provide direct Hide COLUMN_NAME and Reset COLUMN_NAME actions at the top of
  the clicked header's menu. Reset restores only that column's original fixed
  width, with no automatic-fill mode or change to its order/visibility.
- Clip headers and cells at the same content edge, retaining the existing
  vertical-scrollbar allowance. Do not introduce a horizontal scrollbar,
  horizontal offset, edge auto-scrolling, or an overflow-driven minimum width.
- Users reveal clipped headers and resize handles by widening the window or
  hiding/narrowing preceding columns. Visibility remains configurable from the
  accessible header menu and Settings even when a column is fully clipped.
- Keep group headings, row backgrounds, pin/new-item markers, and native
  full-row interaction anchored to the viewport. Preserve the current default
  left offsets and gaps. A 20-unit marker inset is used only when a column other
  than Quantity leads; the default Quantity-first layout is unchanged.
- Keep the existing bag and bank minima and default window geometry. Update
  the old fixed-column maximum-width limit so users can widen the window to
  accommodate customized widths. Column edits must not automatically shrink,
  resize, or reposition a window, including when all columns are hidden.
- Shared settings store widths in frame-local units. Differently sized
  mirrored windows use the same column widths and order but may clip different
  amounts of the layout; each window retains its own size and scale.

## Persistence And Ownership

- Extend the existing `Modules/ItemList/Settings.lua` scope routing. Bag layout
  belongs to `list.columns`; detached bank layout to `bank.list.columns`.
  Character and Warband views continue sharing one Bank configuration.
- Extend Use Bag List Settings bidirectionally to column configuration. A
  committed edit from either mirrored window updates the shared bag values.
  On the first detach, copy the effective column configuration with the other
  list settings. Re-enabling mirroring preserves the detached layout for reuse.
- Store stable column keys, never translated labels or header positions.
  Configuration: a complete `order` array, a `hidden` map, and a
  `widths` override map. Read, normalize, clone, and commit through the settings
  owner and `NS.db`; never mutate a DB-returned table in place.
- Declare empty override defaults in `Defaults.lua`. Resolve absent values
  against the column registry's canonical defaults. Ignore invalid
  keys, remove duplicates in the effective order, append newly available keys
  deterministically, and clamp finite widths to the column's constraints.
- Resolve missing visibility from each column's default. Preserve explicit
  false in the hidden map when showing a default-hidden column. Reset Columns
  restores those defaults, including hiding Bag/Slot, without changing the
  initial frame width or requiring a profile migration.
- Existing profiles have no stored column configuration and use the defaults.
  This requires neither a profile reset nor a migration. Previously detached
  bank profiles also begin with the new column defaults.
- Keep frame size, position, and scale character-owned. Gesture previews are
  transient list state, not profile data.
- Profile copy/reset uses the existing profile-manager lifecycle. Cancel any
  gesture before applying a profile, reset, or mirroring change so a delayed
  drag completion cannot write into a different configuration.

## Architecture And Refresh Contract

- `Columns.lua` owns stable definitions, capabilities, canonical defaults,
  formatting, and visual metadata. Separate all available definitions from
  each list's selected columns; do not mutate the global registry per profile.
  Keep sort metadata independent of visibility, including the `count` column's
  `quantity` sort key and the `icon` column's `quality` sort key.
- `ItemList/Settings.lua` owns effective persistence, normalization at the
  mutation boundary, mirroring, and resets.
- `ItemList/Layout.lua` resolves one ordered set of fixed-width column bounds
  per list, including existing gaps and vertical-scrollbar allowance. Headers,
  separators, and item cells consume these same bounds and clipping edge
  rather than calculating their own offsets. Support an empty column layout.
- `Header.lua` owns header visuals and gesture coordination;
  `HeaderInteraction.lua` owns gestures and cancellation; `ColumnMenu.lua`
  shares visibility/reset actions with Settings. Keep these separate from
  item-row drag/drop and use the existing accent/media getters.
- `ItemRow.lua` creates all supported cell regions during viewport-pool
  initialization, including cells initially hidden. Reposition/show/hide only
  custom regions when layout changes. Recycled rows apply the current layout
  revision on binding; never allocate cells while scrolling.
- `List.lua` owns the resolved layout and a layout-only refresh path. Update
  headers and visible cell geometry without replacing the data provider,
  re-sorting, clearing cooldown caches, rebinding native buttons, or rescanning
  items. Retain search, collapsed groups, and vertical scroll position.
- Resize previews update only when the effective width changes and at most
  once per frame. Do not reformat item values on each pointer movement. Persist
  once on release; mirrored lists then receive the committed configuration.
  Stop interaction polling on completion or cancellation.
- Preserve full-row native interaction and cursor-drop targets. Never resize,
  re-anchor, or recreate protected item buttons for a column change. Hiding
  every column must not remove or rebind those interaction targets.
- Disable column editing in combat, with a
  clear explanation. Cancel unfinished previews on combat entry, window close,
  or Escape. Defer combat-time profile layout application and any protected
  viewport changes until combat ends, applying only the latest state. Existing
  item interaction and vertical scrolling must continue normally.

## Blizzard Reference Findings

The local Interface export is Retail `12.1.0.69497`. The supplemental resource
index is `12.1.0.69587`; do not treat the two as a same-build API comparison.

- `Blizzard_SharedXML/TableBuilder.lua` provides common header/cell spacing and
  fixed/fill width constraints. Its `Arrange` path reconstructs pooled cells;
  do not put that path into every live resize tick for YvBags' existing rows.
- `Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua` has ScrollBox drag behavior,
  but the current headers are a small fixed set of buttons, not ScrollBox
  elements. Check fit before replacing their lifecycle solely for dragging.
- Keep the existing virtualized vertical item list. Horizontal scrolling and
  its associated controls are explicitly out of scope for this implementation.

## Implementation Phases

### Phase 1: Column Registry And Profile Configuration

- [x] Confirm fixed-width overflow, unrestricted user-facing column visibility,
  and preservation of the current default layout.
- [x] Preserve canonical default widths and define per-column resize minima.
- [x] Separate available-column/sort metadata from effective display selection.
- [x] Add defaults, normalized mutations, column-only reset, and bag/bank
  mirroring with a copied first-detach snapshot.
- [ ] In-game check: profile creation, switching, copying, resetting, and
  detached bank reuse. The underlying DB replacement/reset and mirroring paths
  pass one-off Lua checks.

### Phase 2: Shared Layout And Visibility

- [x] Build per-list column bounds and update headers/cells from the same data.
- [x] Precreate all supported cells in both viewport pools and introduce the
  layout-only refresh path, including hidden/recycled rows.
- [x] Add shared visibility/reset menus to the headers and Settings pages.
- [x] Preserve right-edge clipping and update frame width bounds for customized
  widths without adding horizontal scrolling or changing the default layout.
- [ ] Validate marker spacing, long names, icon columns, sort indicators, empty
  lists, all-columns-hidden recovery, group headings, and header/row alignment
  at multiple frame scales.
- [ ] Validate optional Bag/Slot display in bags and bank: initially hidden,
  saved visibility after reload, header dragging/resizing, and Reset Columns
  hiding it again without changing the original default layout.

### Phase 3: Header Resizing And Reordering

- [x] User confirmed reordering, resizing, and enabling/disabling columns in
  bags and bank. The resize-edge cap and direct Hide/Reset actions still need
  an in-game check after this follow-up.
- [x] Add separator hit targets, live width previews, and one commit on release.
- [x] Add header drag threshold, insertion feedback, and stable-key reordering.
- [x] Keep sorting clicks, context menus, and item-cursor drops unambiguous.
- [x] Add cancellation and combat/lifecycle handling; ensure previews cannot
  write stale state after a profile or mirroring change.
- [ ] Verify first/last columns, hidden-column restoration, minimum-width
  clamping, clipped headers/handles, gesture cancellation outside the header,
  and mirror propagation after each committed edit.

### Phase 4: Regression Validation And Documentation

- [ ] Test reload and cold start, narrow/wide windows, frame scaling, profile
  switching/reset, and all mirroring/detach/re-enable combinations.
- [ ] Test manual/sorted/grouped modes, hidden active sort columns, search,
  collapsed groups, pins, new-item markers, hidden Name/Icon columns,
  all-columns-hidden recovery, and cooldown-name display.
- [ ] Test rapid scroll/hover, item use, split, pickup/drop, lock recovery, and
  combat entry during header interaction without pooled-state leakage or taint.
- [ ] Repeat relevant checks in both Character and Warband views, with bags
  also open at a different size/scale.
- [x] Run Lua 5.1 syntax checks and `git diff --check`; do not introduce an
  addon-specific automated test suite. Record in-game checks separately.
- [x] Update README, AGENTS, and the unreleased changelog for completed behavior.
- [ ] Remove the TODO entry after in-game validation is complete.

### Local Verification

- Lua 5.1 parsing passes for all 48 addon Lua files; whitespace checks pass.
- One-off Lua checks use the real column/settings/layout modules and
  LibSimpleDB to cover exact default widths/positions, malformed configuration,
  hide-all, ordering, mirrored edits, detached-state reuse, combat mutation
  guards, and DB/profile replacement/reset.
- Mocked header/row boundary checks cover preview versus commit, Escape and
  combat cancellation, reorder without sorting, marker inset, hide-all recovery,
  and unchanged region-allocation/native-rebind counts during layout edits.
- Follow-up checks cover the inner-edge resize cap on middle/final columns in
  both settings scopes at three scales, direct header Hide/Reset actions,
  mirrored persistence, width-only reset, and combat guards.
- Bag/Slot checks cover hidden defaults, explicit visible overrides across
  profile/mirroring changes, reset behavior, unchanged default frame width,
  cached row rendering, and header menu/tooltip/reorder/resize interactions.
- These checks are not an addon test suite and do not replace client testing.
  No reusable-library files or version pins were changed.

No horizontal scrolling, automatic width redistribution, required user-facing
columns, new column types, frozen-column feature, custom per-category layouts,
inventory-model rewrite, library release, or unrelated appearance settings are
included in this plan. Revisit library ownership only if implementation exposes
a genuinely reusable missing capability.
