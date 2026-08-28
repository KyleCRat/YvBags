w# Profile And Category Customization Plan

Status: Phase 1 complete; Phase 2 category domain implementation complete with
in-game validation pending; Phase 3 settings editor implementation and in-game
validation complete; Phase 4 category-rule implementation complete with in-game
validation pending.

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

## Terminology

- A **Category** is a persistent classification target with a stable ID, name,
  order, and Rule Set. Every item is assigned to exactly one Category. The first
  matching Category in configured order wins, with `Other` as the final
  fallback.
- A **Rule Set** is the single flat collection of Rules owned by a Category. Its
  mode is either `all` (every Rule must match) or `any` (at least one Rule must
  match).
- A **Rule** is one atomic predicate containing a stable rule ID, field,
  operator, and value. Examples include `Quality is at least Rare` and
  `Collection Type equals Mount`.
- A **Display Group** is a presentation section produced by the active Group By
  setting. Category grouping normally creates one Display Group per populated
  Category, but a Display Group does not own classification Rules and is not
  persisted as part of the category registry.

Do not introduce a separate `Condition` concept; it would only be another name
for a Rule. Phase 4 deliberately uses one flat Rule Set per Category. Nested
rule groups and draggable rule ordering are out of scope because `all` and `any`
provide the currently required behavior without additional hierarchy.

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
- New custom categories begin with an empty Rule Set and match nothing until a
  Rule is added.
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
- Category definitions, order, names, and Rule Sets
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
            rules = {
                mode = "all",
                nextRuleID = 2,
                entries = {
                    {
                        id = "rule:1",
                        field = "defaultCategory",
                        operator = "equals",
                        value = "openable",
                    },
                },
            },
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
- Names must be valid UTF-8, trimmed, nonempty, free of ASCII controls, and
  case-insensitively unique through Blizzard's UTF-8 comparison. The category
  domain has no arbitrary length limit; UI consumers must clip or truncate
  unusually long display names without changing their stored values.
- Rule IDs are monotonic within their owning Category (`rule:1`, `rule:2`, and
  so on) and are not derived from their field or displayed value.
- `Other` owns no Rule Set and remains the unconditional final fallback.
- Incomplete Rules are ignored while they are being configured. A Rule Set
  with no complete Rules matches nothing.
- Phase 4 does not migrate prerelease category test data. Profiles with a stored
  category root from Phases 2 or 3 must use Reset Categories to receive the new
  built-in Rule Sets; untouched profiles continue to inherit current defaults.

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

Keep `NS.Categories` as the public facade. Phase 2 deferred the separate rules
module until the Phase 4 schema was approved.

### Runtime Registry

- [x] Read the active profile's category root and normalize it once.
- [x] Build ordered definitions, definitions-by-ID, labels-by-ID, and
      priorities-by-ID caches.
- [x] Preserve the existing `GetCategoryKey`, `GetCategoryName`, and
      `GetSortPriority` consumer APIs.
- [x] Add `GetOrderedDefinitions()` and `GetDefinition(categoryID)`.
- [x] Add a category-change callback contract with change type and affected ID.
- [x] Rebuild caches on category mutations and profile switches.
- [x] Keep built-in IDs stable even when their categories are renamed.

### Category Mutation API

- [x] `CreateCategory(name)`
- [x] `RenameCategory(categoryID, name)`
- [x] `MoveCategory(categoryID, targetIndex)`
- [x] `RemoveCategory(categoryID)`
- [x] `ResetCategories()`
- [x] Reject removal of `Other`.
- [x] Confirm in the storage design that removed built-in categories are not
      backfilled on reload; in-game persistence remains a validation gate.

### Classification Refresh Boundary

- [x] Split `ItemModel.RefreshClassification` into category and pin refresh
      paths.
- [x] Add an inventory method that reclassifies existing normalized items
      without item, tooltip, or bag API queries.
- [x] Clear cached search documents when a category name or assignment changes.
- [x] Refresh pending-item diagnostics when assignments change.
- [x] Remove the unused `Inventory.categoryLabels` reference.

Use the smallest valid refresh:

- Reorder: rebuild category priorities and list rows.
- Rename: refresh names and search documents for affected items.
- Add empty category: rebuild category/editor data only.
- Remove: reclassify items assigned to that category and refresh rows.
- Profile switch: reload the registry and reclassify all normalized items.

Once rules exist, reorder must also reclassify all items because order controls
rule precedence.

## Phase 3: Category Settings Editor (Complete)

### Modern Settings Migration

- [x] Pull in the reviewed `LibModernSettings-1.0` release proven by
      ReadyCheckConsumables, pin its release tag in `.pkgmeta`, and load it
      after LibStub but before every YvBags settings consumer.
- [x] Reimplement YvBags' existing settings pages and profile-management UI
      with LibModernSettings canvas layouts, controls, and tables before adding
      the category editor to the same modern visual system.
- [x] Preserve the current setting labels, profile confirmations, storage
      ownership, defaults, and live-refresh boundaries. LibModernSettings owns
      control construction and layout; YvBags continues to own LibSimpleDB
      persistence, Blizzard category registration, page composition, and
      runtime callbacks.
- [x] Remove superseded hand-built settings controls only after the modern
      implementation has complete behavioral parity.

Register one canvas subcategory with:

```lua
Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, "Categories")
```

Do not create a Blizzard Settings subcategory for each category. Blizzard
category registrations are static and do not fit dynamically created or renamed
categories.

The unbounded category list uses a consumer-owned Blizzard `ScrollBox` rather
than LibModernSettings' fixed settings-table scaffold so the list remains
virtualized. The detail editor uses the library's public text-input control.

### Layout

Use a dense master-detail layout rather than cards:

- Left pane: ordered, virtualized category list.
- Right pane: editor for the selected category.
- A restrained divider separates the panes.
- The detail pane is the permanent extension point for future category rules.

### Category List

- [x] Show every active category, including empty custom categories.
- [x] Use alternating row shading and Blizzard's native move icon to keep the
      reorder affordance clear at every UI scale.
- [x] Provide a dedicated reorder handle and insertion indicator.
- [x] Limit drag polling to an active drag and stop it immediately afterward.
- [x] Preserve selection after reorder and settings refresh.
- [x] Add a category with an icon-and-text command.
- [x] Provide a confirmed Reset Categories action beside the list header.
- [x] Select and focus the new category's name after creation.
- [x] Use pooled rows so custom category counts can grow safely.

### Category Detail

- [x] Edit and validate the category name.
- [x] Commit on Enter or focus loss; Escape restores the previous value.
- [x] Provide a Remove action with confirmation.
- [x] Disable Remove for `Other` with a tooltip explaining that it is the
      required fallback.
- [x] Reserve layout ownership below the name editor for the Phase 4 Rule Set
      editor without displaying placeholder instructional text early.

### Canvas Lifecycle

- [x] `OnRefresh` rebuilds the data provider and restores a valid selection.
- [x] `OnDefault` restores default categories for the active profile.
- [x] Profile changes refresh the canvas if Settings is open.
- [x] Category changes apply live to an open bag list.

## Phase 4: Category Rules

The terminology, schema, field registry, operator registry, and flat evaluation
model are approved. Do not store or execute arbitrary Lua expressions.

### Approved Rule Model

- [x] Each Category except `Other` owns exactly one flat Rule Set.
- [x] Rule Set mode is `all` or `any`; nested rule groups are not supported.
- [x] Rules use stable IDs and structured field/operator/value records.
- [x] Category order determines cross-category precedence; the first matching
      Category wins.
- [x] `Other` is skipped during normal evaluation and applied only after every
      other configured Category fails to match.
- [x] Rule order has no semantic effect in a flat Rule Set, so Phase 4 does not
      add rule dragging.
- [x] Incomplete Rules are ignored while editing. Missing, pending, or secret
      item data makes a complete Rule evaluate false rather than match
      accidentally.
- [x] The built-in classifier is retained as normalized
      `defaultCategoryID` data. Each built-in Category's default Rule Set
      matches its corresponding default classification, preserving existing
      behavior and ensuring items from a removed built-in Category fall through
      to `Other`.

### Approved Field Registry

- Default Classification
- Item Name, Tooltip Text, and Item ID
- Quality
- Item Level and Required Level
- Item Type and Item Subtype
- Equipment Slot
- Binding
- Expansion
- Profession Quality
- Collection Type (`toy`, `mount`, `pet`, and `battlepet` remain distinct)
- Crafting Reagent, Cosmetic, Keystone, Contains Loot, Readable, and Bound

Physical location, bag/slot, lock state, cursor state, stack quantity, and
prices are intentionally excluded from the initial registry. They are transient
inventory or presentation state rather than stable classification attributes.

### Approved Operators

- Text: Equals, Does Not Equal, Contains, Does Not Contain
- Enum and Item ID: Equals, Does Not Equal
- Ordered numbers and ordered enums: Equals, Does Not Equal, At Least, At Most
- Boolean: Is True, Is False

Text matching is literal and case-insensitive. Negative operators still fail
closed when item data is missing or secret.

### Implementation

- [x] Add the normalized default classification, cached tooltip text, and other
      rule-required item fields in `ItemModel.lua`.
- [x] Add a rule registry/compiler/evaluator that consumes normalized item data
      only.
- [x] Add transactional Rule Set mutation APIs to `NS.Categories`.
- [x] Reclassify all normalized items after precedence or rule changes without
      querying bag, item, or tooltip APIs.
- [x] Debounce multi-control rule edits and coalesce the resulting live list
      refresh.
- [x] Extend the Category detail pane with the `all`/`any` selector and a
      virtualized Rule list.
- [x] Support adding, editing, and removing Rules through structured controls.
- [x] Explain in the `Other` editor that it is the unconditional fallback and
      therefore has no Rule Set.

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
- `Modules/Inventory/CategoryRules.lua`: structured field/operator registry,
  built-in default classification, compilation, and normalized-item evaluation.
- `Modules/Inventory/Categories.lua`: profile-backed registry and classification
  facade.
- `Modules/Inventory/ItemModel.lua`: separate pin and category refreshes.
- `Modules/Inventory/Inventory.lua`: targeted category reclassification.
- `Modules/ItemList/List.lua`: reload list controller state after profile changes.
- `Modules/ItemList/Model.lua`: continue consuming category priorities; no rule
  ownership belongs here.
- `Libs/LibModernSettings-1.0`, `.pkgmeta`, and `.gitmodules`: embed and pin the
  reviewed release already proven by ReadyCheckConsumables.
- `Modules/Settings/CategoryEditor.lua`: canvas category editor.
- `Modules/Settings/CategoryRuleEditor.lua`: virtualized flat Rule Set editor.
- `Settings.lua`: reimplement existing settings and profile controls with
  LibModernSettings, then register the category canvas subcategory.
- `YvBags.toc`: load LibModernSettings and new modules before their consumers.
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

- [x] Existing settings, dependent states, profile actions, defaults, and live
      refresh behavior retain parity after the LibModernSettings migration.
- [x] Every modern settings page reopens and refreshes without stale control
      values or duplicated frames.
- [x] Category editor works at narrow and wide Settings panel sizes.
- [x] Drag reorder remains correct while the list is scrolled.
- [x] Add, rename, remove, reset, and profile switch update the editor live.
- [x] Long names validate and fit without overlapping controls.
- [x] Repeated opening and closing does not leak rows or drag state.

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
