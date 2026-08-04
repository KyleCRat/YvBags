# Profile And Category Customization Plan

Status: Phase 1 profile foundation complete; category customization not started.

This document is the implementation contract for profile support, category
customization, and the later category rule editor. Complete the phases in order.
Do not begin the rule editor before the profile and category configuration
boundaries are stable.

## Objectives

- Add shared profiles before persisting customizable categories.
- Let users create, remove, rename, and reorder categories.
- Preserve stable category identities when names and positions change.
- Provide a Settings design that can later edit a dynamic rule set for each
  category without replacing the category editor.
- Keep category and profile changes live without rescanning bag APIs.
- Preserve pinning, virtualized rows, native item interaction, Manual sorting,
  and all current grouping modes.

## Agreed Product Decisions

- Category configuration belongs to the active profile.
- Profile selection is per character; profile contents are shared account-wide.
- Every category except `Other` may be removed.
- `Other` is the mandatory fallback and cannot be removed.
- Removing a category reclassifies its items instead of hiding them.
- Future rule evaluation uses configured category order as precedence. The first
  matching category wins.
- `Other` is applied only when no configured category matches; it is not an
  ordinary catch-all rule evaluated in the configured sequence.
- Category names are presentation data. Renaming must never change identity,
  collapsed-group IDs, or rule references.
- Custom category IDs are monotonic stable IDs such as `custom:1` and are never
  derived from display names.
- Toy, Mount, Pet, and Battle Pet are distinct stable rule values even though
  the default configuration groups all four into `Collectables`.
- New custom categories are empty until category rules are implemented.
- Account-wide pin identities remain global and do not change with profiles.
- Pin presentation belongs to the active profile.
- Existing flat SavedVariables are adopted into Global exactly once. Addon-global
  feature settings and pin identities are split out before the profile manager
  takes ownership of its dedicated storage table.

## Configuration Ownership

### Global Account Scope

- Replace Blizzard Bags
- Gray-junk autosell
- Account-wide pinned item identities
- Profile table storage and profile metadata

Expose global settings through `NS.globalDB`.

### Active Profile Scope

- Grouping, primary sort, secondary sort, and directions
- Pin presentation mode
- Cooldown-name display
- Category definitions, order, names, and future rules
- Future column and appearance configuration

Expose the stable active profile database through `NS.db`, obtained from
`NS.profileManager:GetActiveDB()`.

### Character Scope

- Frame point, size, position, and scale

Continue exposing character settings through `NS.charDB`.

Profile selections are stored by character GUID inside the account-wide table
owned by `LibSimpleDBProfiles-1.0`; they do not use SavedVariablesPerCharacter.

## Target SavedVariables Shape

```lua
YvBagsDB = {
    __yvBags = {
        schema = 1,
    },
    global = {
        features = {
            replaceBlizzardBags = true,
            autosellGrayJunk = false,
        },
        pins = {
            items = {},
        },
    },
    profiles = {
        __lsdbProfiles = {
            schema = 1,
            payloadVersion = 1,
        },
        global = {
            list = {},
            display = {},
            pins = {
                displayMode = "top",
            },
        },
        -- Remaining permanent containers, user profiles, character metadata,
        -- and selections are private LibSimpleDBProfiles storage.
    },
}

YvBagsCharacterDB = {
    frame = {},
}
```

`NS.defaults` should be split into `global`, `profile`, and `character`
sections. Only the profile manager and database initialization code may manage
the raw `profiles` container. All consumers must use the appropriate
LibSimpleDB instance.

## Category Configuration Shape

```lua
categories = {
    schemaVersion = 1,
    nextCustomID = 1,
    order = {
        "openable",
        "cosmetic",
        "collectables",
        "keystone",
        "consumable",
        "equipment",
        -- Remaining stable IDs.
    },
    definitions = {
        openable = {
            name = "Openable",
        },
        equipment = {
            name = "Equipment",
        },
        cosmetic = {
            name = "Cosmetic",
        },
        collectables = {
            name = "Collectables",
        },
    },
}
```

- Store definitions by ID and order separately.
- Treat the profile's root category table as one transactional value.
- Clone before mutation and write the complete updated category table once.
- Never mutate tables returned from defaults.
- CRUD operations must preserve unknown definition fields so later rule data is
  not discarded by rename or reorder operations.
- A stored category root replaces the default root. Missing definitions in a
  stored root represent intentional removal and must not be backfilled.
- Resetting categories deletes the stored category root and rebuilds from
  profile defaults.
- Names must be trimmed, nonempty, length-limited, and case-insensitively unique.

## Phase 1: Profile Foundation (Complete)

- [x] Split defaults and storage into addon-global, active-profile, and
      per-character ownership.
- [x] Upgrade to `LibSimpleDB-2.0` and construct one synchronous
      `LibSimpleDBProfiles-1.0` manager with the addon folder name.
- [x] Keep `manager:GetActiveDB()` stable across profile changes and route all
      profile setting consumers through `NS.db`.
- [x] Adopt recognized legacy flat settings as the initial Global payload once,
      without a SavedVariables cycle or a profile Migration.
- [x] Keep bag replacement, gray-junk selling, debug state, and pin identities
      in `NS.globalDB`; keep frame geometry in `NS.charDB`.
- [x] Add the unified permanent/user profile selector plus create, copy, reset,
      rename, and delete actions with consumer confirmations.
- [x] Refresh list/effective settings from active-DB lifecycle callbacks and
      refresh profile identity UI from manager lifecycle callbacks.
- [x] Apply profile changes without rescanning bag APIs.

In-game validation confirmed profile selection and CRUD operations, live profile
switching, per-character persistence, and cross-character Specialization
inheritance. A new Elemental Shaman selected an existing non-empty Elemental
profile during the one-time initial search.

Future category-profile work must continue using `NS.db` and must refresh from
active-DB lifecycle callbacks rather than also listening to `OnProfileChanged`.

## Phase 2: Category Domain Refactor

Keep `NS.Categories` as the public facade. A separate rules module is not needed
until the rule schema is designed.

### Runtime Registry

- [ ] Read the active profile's category root and normalize it once.
- [ ] Build ordered definitions, definitions-by-ID, labels-by-ID, and
      priorities-by-ID caches.
- [ ] Preserve the existing `GetCategoryKey`, `GetCategoryName`, and
      `GetSortPriority` consumer APIs.
- [ ] Add `GetOrderedDefinitions()` and `GetDefinition(categoryID)`.
- [ ] Add a category-change callback contract with change type and affected ID.
- [ ] Rebuild caches on category mutations and profile switches.
- [ ] Keep built-in IDs stable even when their categories are renamed.

### Category Mutation API

- [ ] `CreateCategory(name)`
- [ ] `RenameCategory(categoryID, name)`
- [ ] `MoveCategory(categoryID, targetIndex)`
- [ ] `RemoveCategory(categoryID)`
- [ ] `ResetCategories()`
- [ ] Reject removal of `Other`.
- [ ] Confirm that removed built-in categories do not reappear on reload.

### Classification Refresh Boundary

- [ ] Split `ItemModel.RefreshClassification` into category and pin refresh
      paths.
- [ ] Add an inventory method that reclassifies existing normalized items
      without item, tooltip, or bag API queries.
- [ ] Clear cached search documents when a category name or assignment changes.
- [ ] Refresh pending-item diagnostics when assignments change.
- [ ] Remove the unused `Inventory.categoryLabels` reference.

Use the smallest valid refresh:

- Reorder: rebuild category priorities and list rows.
- Rename: refresh names and search documents for affected items.
- Add empty category: rebuild category/editor data only.
- Remove: reclassify items assigned to that category and refresh rows.
- Profile switch: reload the registry and reclassify all normalized items.

Once rules exist, reorder must also reclassify all items because order controls
rule precedence.

## Phase 3: Category Settings Editor

Register one canvas subcategory with:

```lua
Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, "Categories")
```

Do not create a Blizzard Settings subcategory for each category. Blizzard
category registrations are static and do not fit dynamically created or renamed
categories.

### Layout

Use a dense master-detail layout rather than cards:

- Left pane: ordered, virtualized category list.
- Right pane: editor for the selected category.
- A restrained divider separates the panes.
- The detail pane is the permanent extension point for future category rules.

### Category List

- [ ] Show every active category, including empty custom categories.
- [ ] Provide a dedicated reorder handle and insertion indicator.
- [ ] Limit drag polling to an active drag and stop it immediately afterward.
- [ ] Preserve selection after reorder and settings refresh.
- [ ] Add a category with an icon-and-text command.
- [ ] Select and focus the new category's name after creation.
- [ ] Use pooled rows so custom category counts can grow safely.

### Category Detail

- [ ] Edit and validate the category name.
- [ ] Commit on Enter or focus loss; Escape restores the previous value.
- [ ] Provide a Remove action with confirmation.
- [ ] Disable Remove for `Other` with a tooltip explaining that it is the
      required fallback.
- [ ] Reserve layout ownership below the name editor for future rules without
      displaying placeholder instructional text.

### Canvas Lifecycle

- [ ] `OnRefresh` rebuilds the data provider and restores a valid selection.
- [ ] `OnDefault` restores default categories for the active profile.
- [ ] Profile changes refresh the canvas if Settings is open.
- [ ] Category changes apply live to an open bag list.

## Phase 4: Category Rules

Start this phase with a separate rule-schema design review. Do not store or
execute arbitrary Lua expressions.

### Rule Direction

- Rules are structured records with stable field and operator IDs.
- The normalized `collectionKind` field exposes the stable values `toy`,
  `mount`, `pet`, and `battlepet` for independent selection. `pet` identifies
  ordinary items that learn a pet; `battlepet` identifies caged battle-pet
  links.
- Category definitions own ordered rule data.
- Category order determines cross-category precedence.
- A category may eventually support `all` and `any` combinations.
- Rule fields read normalized item data only.
- New rule-required item fields belong in `ItemModel.lua`.
- Rule evaluation must handle asynchronous item data and secret values safely.
- Rule changes reclassify normalized items without rescanning bag APIs.
- Multi-control rule editing should debounce reclassification.

Illustrative shape only:

```lua
{
    field = "quality",
    operator = "greaterOrEqual",
    value = 3,
}
```

The final field registry, operators, grouping semantics, and built-in default
rules require approval before implementation.

## Performance Requirements

- Do not query container, item, tooltip, atlas, or formatting APIs while applying
  profile or category configuration.
- Category lookup during row construction must remain table-based.
- Continue caching category priorities before `table.sort`.
- Reclassification is acceptable across the current normalized bag item list
  because it is user-triggered and bounded by player bag capacity.
- Do not rebuild secure item-button geometry during any settings change.
- Keep the category Settings list virtualized.
- Do not add idle `OnUpdate` work.

## Expected File Impact

- `Defaults.lua`: split global/profile/character defaults and add category
  defaults.
- `Core.lua`: construct the database scopes in dependency order.
- `LibSimpleDBProfiles-1.0`: profile storage, CRUD, switching, and callbacks.
- `Modules/Inventory/Pins.lua`: split global pin identity and profile
  presentation storage.
- `Modules/Inventory/Categories.lua`: profile-backed registry and classification
  facade.
- `Modules/Inventory/ItemModel.lua`: separate pin and category refreshes.
- `Modules/Inventory/Inventory.lua`: targeted category reclassification.
- `Modules/ItemList/List.lua`: reload list controller state after profile changes.
- `Modules/ItemList/Model.lua`: continue consuming category priorities; no rule
  ownership belongs here.
- `Modules/Settings/CategoryEditor.lua`: canvas category editor.
- `Settings.lua`: register profile controls and the category canvas subcategory.
- `YvBags.toc`: load new modules before their consumers.
- `AGENTS.md`, `README.md`, `CHANGELOG.md`, and `TODO.md`: update contracts as
  phases are completed.

## Validation Gates

### After Phase 1

- [x] Fresh load creates and selects `Global` without Lua errors.
- [x] Create, copy, rename, switch, reset, and delete profiles.
- [x] Profile selection persists per character.
- [x] Two characters can select different shared profiles.
- [x] List, display, and pin-presentation settings switch live.
- [x] Global pins and feature settings remain unchanged across profile switches.
- [x] Frame geometry remains character-specific.

### After Phase 2

- [ ] Default category names and order match the current product defaults.
- [ ] Rename and reorder persist through reload and profile switching.
- [ ] Removed built-ins remain removed.
- [ ] `Other` cannot be removed.
- [ ] Items never disappear when their category is removed.
- [ ] Category search text updates after rename.
- [ ] Pins and Keystone stable pin identity remain unchanged.

### After Phase 3

- [ ] Category editor works at narrow and wide Settings panel sizes.
- [ ] Drag reorder remains correct while the list is scrolled.
- [ ] Add, rename, remove, reset, and profile switch update the editor live.
- [ ] Long names validate and fit without overlapping controls.
- [ ] Repeated opening and closing does not leak rows or drag state.

### After Phase 4

- [ ] First matching category wins in configured order.
- [ ] `Other` receives every unmatched item.
- [ ] Pending item data is re-evaluated when it completes.
- [ ] Rule edits do not trigger bag API rescans.
- [ ] Search, grouping, category sort, all pin modes, and Manual mode remain
      correct.
- [ ] Reclassification remains safe during combat and rapid bag updates.

Run `git diff --check` and inspect the complete diff at the end of every phase.
Run the reusable libraries' Lua 5.1 suites and compile every Lua file, then
perform proportionate in-game validation before the next phase begins. YvBags
intentionally does not maintain an addon-specific automated test suite.
