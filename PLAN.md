# LibYvSkins And YvBags Appearance Plan

Status: approved, with a creation-first architecture. Phases 0, 1, 1.5, and 2
are complete with their in-game gates accepted. Phase 3 Modern/Flat styling and
built-in selection are accepted as MVP. The subsequent renderer separation and
explicit window-layout refactor are also confirmed working and visually intact
in game. EUI integration and the first library release remain later work.

Window-shell follow-up: LYS now owns generic Header/Body/Footer allocation,
optional Title Bar/native controls, and independent toolbars. YvBags owns its
per-skin sections, control arrangement, search minimum, and footer clearance in
`Modules/Appearance/WindowLayout.lua`. The library no longer infers structure
from `compactHeader` or requires a search field. See the terminology and current
API contracts below. Historical checkpoints follow; their pending approvals
were superseded by the MVP acceptance above.

Refactor checks: 62 Lua 5.1 library tests and 16 changed/new Lua syntax checks
pass, including optional sections, taller footers, Flat titles, search-free
toolbars, copied layouts, native-input preservation, and mixed-MINOR loading.
Both repositories pass whitespace checks. Modern/Flat bag/bank visual parity
after this refactor is confirmed by the user; MINOR and package pins are unchanged.

Visual iteration policy: while Flat appearance is being tuned, use changed-file
Lua syntax checks, focused diff review, and the user's in-game visual feedback.
Defer new visual test scaffolding and full suite/diagnostic reruns until the
skin is close to approval; retain targeted checks for nonvisual behavior changes.

Flat visual follow-up (2026-09-12): corrected text baselines, checkmark sizing,
action-icon accent tinting, symmetric compact padding and content framing,
scrollbar gutter centering and arrow alignment/gaps, outside icon borders,
bundled centered Vertex glyphs, a separate native checkmark offset, and the
flush unboxed resize grip with footer clearance. Flat header lines join the inset border; Modern
retains its texture-aware offsets. Column contents and row geometry stay fixed.
Both skins support non-action background dragging. Compact controls start at
the toolbar's left edge, with 4-unit control and section gaps and no reserved
drag slot. Flat footer controls now match the 24-unit bag/tab button footprints,
with a 4-unit content gap, 8-unit outer padding, and no extra inset before the
first icon; Modern footer geometry is retained. Modern restoration and native interactions remain
covered at the previous checkpoint by 59 passing library tests, 73-file Lua 5.1 syntax checks, and
whitespace checks. Actual popup integration and temporary list/appearance
diagnostics also pass. Recheck both skins in game before accepting the
Phase 3 gate; implementation MINOR remains unchanged.

Phase 3 checkpoint (2026-09-12): the shared addon-global Modern/Flat selector,
compact toolbar, physical-pixel Flat surfaces/icon borders, and deferred live
transitions are implemented. Additional viewport rows are prewarmed without
replacing providers, and visible Flat strokes update after scrolling. Lua 5.1
library suite (50 tests), 121-file syntax check, and whitespace checks pass.
Temporary diagnostics also exercise actual appearance persistence, bounded
viewport prewarming, and the existing column/pooled-row regression checks.
In-game validation is still
required; stop here before Phase 4. MINOR and release/package pins are unchanged.

Popup dependency follow-up (2026-09-12): converted the vendored LibPopupSlider
to its canonical Git submodule after updating the standalone checkout from
upstream `1.1.0`. Published `1.2.0` / MINOR `3` with the public presentation API
and the existing `showBorder` option so older addon embeds cannot mask Flat
support. The consumer package pin and committed parent gitlink now reference
`1.2.0`; the standalone checkout was reset and pulled to the same release.
Public popup API tests and both legacy load orders pass, including an active
popup created before upgrade. Actual popup/skin Modern-Flat-Modern diagnostics,
the 50-test skin suite, 125-file Lua syntax checks, and whitespace checks pass.

Phase 2 checkpoint (2026-09-12): YvBags now constructs toolbar, tab, search,
footer, scrollbar, icon, text/accent, and drop-glow presentation through
LibYvSkins. Native item bridges and banking actions remain authoritative.
LibPopupSlider exposes an additive public presentation contract; its explicit
library adapter preserves drag/value ownership. No LMS code, saved settings,
release counters, or package pins change in this phase.

The expanded Lua 5.1 library suite covers constructor/state contracts, native
control access, semantic colors, pooling, two consumers, popup capability
boundaries, and mixed/equal-MINOR loading (40 tests passing). All 118 Lua files
pass syntax checks, and root/library whitespace checks pass. Temporary diagnostics exercise
the actual popup implementation and YvBags footer construction with exported
Blizzard bank mixins. The user subsequently confirmed Modern visual parity,
bag/bank buttons and actions, sorting, and header actions in game. Broader
release regression coverage remains required after the remaining skin work.

## Outcome And Scope

Build a small reusable skinning library, developed directly inside YvBags as
the `Libs/LibYvSkins-1.0` Git submodule from
`git@github.com:KyleCRat/LibYvSkins.git`.

Deliver these capabilities in order:

1. Pixel-perfect header, column, category, and section dividers in the existing
   bag and bank lists, before changing their overall appearance.
2. A library-owned WoW Modern skin that preserves the current appearance.
3. A pixel-perfect Flat skin based on RaidGroupManager's visual technique,
   including compact window headers and one-physical-pixel icon borders.
4. Selectable EllesmereUI integration through its public API, with a reload
   required when entering or leaving that skin.
5. Reusable window/component constructors so YvBags and future addons build
   directly on the same structure and inherit its skins and EUI integration.

Masque is deferred. Aurora, Skinner, and AddOnSkins are excluded. Do not add
dependencies, settings, placeholder adapters, or third-party detection for them.

The feature covers YvBags' bag and bank windows, their list visuals, header and
footer controls, and the scale popup. It does not reskin Blizzard's Settings
window, the LMS category editor, shared menus/tooltips, bank purchase/money/tab
configuration dialogs, or IconBrowser. Those remain with their current owners.

No inventory feature changes, profile migrations/resets, horizontal scrolling,
column auto-fitting, action bars, new artwork generation, or Blizzard art
exports are part of this work. Do not migrate RaidGroupManager or other addons
in this implementation; use a library harness to validate another consumer.

## Approved Product Decisions

These decisions guide the implementation:

- YvBags is the first native consumer of LibYvSkins, not a legacy window to
  adapt. Create its skinnable windows and controls through library factories.
  Do not add an existing-window registration path or YvBags frame-tree mapping
  layer. Adapters are reserved for real external boundaries, notably EUI and
  other owned libraries such as LibPopupSlider.
- One addon-global `appearance.skin` setting, shared by bags and bank, default
  `modern`. Store it through `NS.globalDB`; list profiles, list mirroring, and
  per-character geometry remain independent. The library has no SavedVariables
  or LibSimpleDB dependency.
- Player-facing choices: **WoW Modern**, **Flat**, and **EllesmereUI**. Do not
  automatically select EUI merely because it is installed.
- Present the same shared choice in the bag and bank Settings canvases, using
  LMS inline fields and a note that it applies to both windows. No new settings
  window or second profile selector.
- Show EUI when its installation/API can be detected. Disable its choice with
  an explanation while the required integration is unavailable. If it was
  previously selected, retain that selection visibly even when unavailable.
- Switching Modern/Flat is live outside combat. Switching to or from EUI is
  reload-bound in both directions. Saving a reload-bound choice does not
  partially restyle the running UI; show pending status and Reload UI action.
- If EUI cannot activate at startup, use WoW Modern for that session, retain
  the saved EUI preference, and explain the fallback in Settings. Do not modify
  EUI's settings or silently overwrite the user's preference.
- Profile switching/reset does not change the skin. Appearance reset returns
  the shared setting to Modern and obeys the same combat/reload rules.
- Use the existing owned-library conventions: MIT license and Yvairel author
  metadata, matching LMS, unless the new remote gains a different explicit
  project policy before bootstrap. Never overwrite an existing license.

### Visual Contract

| Area | WoW Modern | Flat | EllesmereUI |
|---|---|---|---|
| Outer frame | Existing ButtonFrame art, portrait, title | Dark flat surface, 1px physical border, no portrait/title | EUI shell, no portrait/title |
| Header controls | Existing title/subheader arrangement | One compact header | Same compact structural layout, EUI controls |
| List dividers | New crisp 1px physical lines | Same pixel technique | Same pixel technique with EUI appearance tokens |
| Item/container icon borders | Existing custom textured frame | 1px physical border | Pixel border preserving semantic color; EUI-compatible presentation |
| Accent and fonts | Current YvBags media | Current YvBags media, flat surfaces | EUI's live public accent/font values |
| Interaction/data | Unchanged | Unchanged | Unchanged |

The EUI icon adapter will use the public crop operation without requesting a
second EUI border, then use the library's semantic-color border. This avoids
replacing rarity/reagent meaning with an unconditional black frame. Flat uses
a 1px physical semantic border; EUI can use the same thickness.

Compact bag header: square settings cog, square scale control, flexible search,
close. Compact bank header: square settings cog, square scale control,
Character/Warband selectors, flexible search, close. Preserve the Vertex-Scale icon and its
placement immediately beside settings, matching square-button styling, and
shared toolbar spacing. Modern uses one shared 2-unit gap between buttons and
search; preserve this tuned value. Its search field retains the
native search/clear controls with a tertiary-depressed background and matches
the adjacent button's height. Hide only bank types the bank controller
reports unavailable; do not move or merge their inventory states.

YvBags declares a 28 UI-unit Flat Toolbar, 4-unit control/section gaps,
8-unit outer padding, a 24-unit Footer, and a minimum 96-unit search width.
Modern retains its Title Bar, 28-unit Toolbar/Footer, and texture-aware spacing.
These are addon layout choices in scale-aware units, not fixed physical pixels
or library policies. Keep the current bag/bank minimum widths as lower bounds.
Compute the actual window minimum from visible controls
and measured labels so required controls cannot overlap. Do not wrap the
header, shrink icons, or hide required actions to force a narrower width.

Preserve the user's outer window dimensions and anchor when changing skin;
the compact header yields additional list space. Keep column widths/order,
row heights, sorting, grouping, search, and item-count semantics unchanged.
Flat surface colors start from RaidGroupManager's dark palette; keep selected,
hovered, pressed, focused, disabled, and disabled-checked states distinguishable.

## Inspected Baseline

- At planning time LibYvSkins had no remote refs. The user bootstrapped and
  published `main` at `816ed1e`; the committed implementation checkpoint above
  supersedes that initial empty commit.
- Existing sibling reference: RaidGroupManager `bee6287`, especially
  `UI/PixelPerfect.lua`, `UI/Widgets.lua`, and `UI/MainFrame.lua`.
- Blizzard code export: Retail `12.1.0.69497` (`03b6f28`). The supplemental
  resource index reports `12.1.0.69587`; it is not an exact-build substitute.
  Pixel/ScrollBox contracts below were checked against the code export.
- Installed EUI and EUI Blizz UI Enhanced: `9.1.8`; public facade API version 1.
  Its source explicitly makes removal reload-bound.
- Current YvBags TOC advertises `120007, 120100`. Do not silently change that
  support policy. Validate built-in skins on supported targets before release;
  the inspected EUI implementation itself blocks pre-12.1 clients.
- LMS remains a separate settings/controls library; current package pin is
  `1.6.0`. The main bag/bank controls are currently addon-owned or native
  templates, not LMS fields requiring a settings-library rewrite.

Important implementation findings:

- Bag/bank roots remain `ButtonFrameTemplate`, now created by LibYvSkins with
  Header/Body/Footer sections, optional Title Bar/portrait, native close/resize
  controls, and geometry lifecycle. YvBags declares per-skin section dimensions
  and toolbar layout; LYS allocates the shell and generic control rows without
  duplicating constructors or requiring inventory-specific controls.
- Header, column, and new/pinned-section separators use the library's direct
  physical-pixel separator factory without changing their hit areas. Group/
  category headers now use its expandable-header factory; the Modern bar
  replaces their previous separate pixel divider.
- Item rows use 23-unit icons inside 29-unit textured borders and custom
  noninteractive regions beside native full-row interaction buttons. Footer
  container/tab icons are 18 units within 24-unit controls; bank tertiary
  controls are 28 units. Preserve these functional footprints initially.
- Header, group, and item modules cache some accent colors at file load.
  EUI live appearance changes require presentation tokens and targeted recolors,
  not rereading inventory data or globally replacing media values.
- EUI's EditBox primitive fades texture regions, which includes a search icon
  on the edit box. Its Tab primitive expects a standard label reference and
  refreshable selected state. The library's EUI provider must translate these
  known constructor-owned parts without consumer-side adapters.
- Bank footer hover/refresh code currently reapplies Modern atlases. Those
  writers must delegate to the selected renderer; leaving them active would
  overwrite Flat/EUI styling after a hover or bank update.
- Core precreates both windows and their viewport pools during addon
  initialization, before EUI's normal login dispatch. Preserve that prewarming
  while coordinating appearance readiness.

## Ownership And Architecture

### Shared Terminology

- Window: the complete movable/resizable container; the shell is its library
  construction and layout machinery, not a separate visible section.
- Header: everything above Body. Title Bar is an optional Header row holding
  the Title text; neither dragging nor Close is restricted to it.
- Toolbar: a row of controls that can appear in Header, Body, or Footer. It is
  optional, may be repeated, and does not inherently require search.
- Body: the primary working area; content is a general word, not another slot.
- Footer: the optional lower section, with arbitrary caller-defined contents
  and height rather than one mandatory short row.
- Layout: section presence, dimensions, arrangement, and space allocation.
  Skin/renderer: appearance, default visual measurements, and artwork offsets.
- Padding is inside a boundary, margin outside a component, gap between
  siblings, and visual offset affects artwork without moving its control.
- Qualify nested headers: Window Header, List Header, and Category Header.

### Ownership

| Owner | Responsibilities | Explicit exclusions |
|---|---|---|
| LibYvSkins core | Per-addon contexts, constructor-owned registry, renderer selection/status, revisions, external integration coordination | SavedVariables, profiles, automatic discovery of unrelated frames |
| Pixel primitives | Physical-pixel borders/lines, scale-aware layout rounding, visual alignment and invalidation | Changing UIParent scale, CVars, saved positions, inventory row geometry |
| Window/component layer | Creates ordinary frames, allocates declared sections/Body, provides generic toolbar layout and native controls | Choosing addon structure, bank semantics, search filtering, persistence |
| Modern/Flat renderers | Independent assets, colors, default measurements, state drawing and optical corrections | Inferring Title Bar/Footer presence or control order, invoking another renderer, native item interaction |
| EUI adapter | Public API registration per consuming addon, facade translation, availability and reload policy | Private EUI tables, forcing EUI settings, copying its engine |
| YvBags Appearance module | Context/media setup, LSDB preference, safe apply requests, Settings notifications | Frame adapters, part-discovery maps, constructor wrappers, duplicated renderers |
| YvBags WindowLayout module | Explicit Modern/Flat sections, toolbar order/anchors, search minimum, footer dimensions/clearance | Rendering skins, duplicating shell constructors or pixel helpers |
| Existing YvBags modules | Inventory, columns, virtualized lists, native bridges, geometry persistence, footer/bank behavior | Continuing to overwrite skin-owned art |

### Small Public Contract

Use these contracts to guide implementation; document final signatures before
the first release:

- `CreateContext(addonName, options)`: one stable context per consuming addon;
  options provide base media/tokens and application callbacks. No global
  selected skin shared by every LibStub consumer.
- Context skin choices/status expose requested and applied IDs, unavailable
  reason, and pending combat/reload state. `RequestSkin(id)` manages runtime
  application only; the addon owns persisting the preference and displaying
  confirmation UI.
- `CreateWindow(parent, options)` is the only window construction path. It
  returns an ordinary WoW Frame with `header`, `titleBar`, `body`, `footer`,
  and `resizeButton` parts, plus native title/portrait/close controls.
  YvBags supplies name/title/artwork, minimum/maximum size constraints, and
  move/resize completion callbacks. The library creates and owns the parts;
  YvBags mounts its content and restores/saves geometry on the returned frame.
  Complete `layout`/per-skin `layouts` specifications select optional sections,
  their heights/margins/gaps, Body padding, and Title Bar/Close/portrait choices.
  `onLayout` arranges existing addon contents after section anchors change;
  `SetWindowLayout` replaces a copied specification without rebuilding frames.
- `CreateToolbar`, `SetToolbarItems`, `LayoutToolbar`, and
  `GetToolbarMinimumWidth` are independent row helpers usable in any section.
  At most one flexible-width control separates fixed leading/trailing items;
  controls retain their heights and native scripts. Search is addon-owned.
- `GetWindowBodyWidthOverhead(window)` reports horizontal Body
  overhead so the consumer can calculate window bounds without copying the
  library's inset constants.
- `GetWindowBodyReserve(window)` derives the largest declared viewport for
  protected-row prewarming. `GetWindowMinimumWidth` combines constructor bounds
  with the consumer's optional `getMinimumWidth` measurement callback.
- `CreateSeparator(parent, options)` creates the texture and its appearance
  handle together, returning both. The window itself is the geometry root;
  no addon-side window-to-list map or region-construction wrapper is needed.
- Add focused constructors for command/icon button, checkbox, tab, search/edit
  box, scrollbar, icon, and text as each actual consumer is converted. Return
  ordinary controls and their declared visual state handles, not field/value
  wrappers. Constructors register their own visual parts internally.
- `RegisterComponent(role, target, parts, options)` remains the low-level
  visual registration backend and an explicit external extension point, not
  the primary YvBags integration path. Do not add `RegisterWindow` or
  `SkinExistingWindow` APIs for this MVP.
- Appearance handles accept visual state such as selected/enabled/focused,
  semantic border color, visibility, and sizing. State changes update reusable
  regions; they do not reconstruct components.
- Context geometry/appearance refreshes are separate. Registration is
  idempotent, and unregistering releases library-owned tracking. Unregistering
  is not an EUI unskin operation; that still requires reload.

Skin implementation and structural layout are separate. A Flat window may
still have a title in a future addon; YvBags explicitly declares its layouts
for each skin. The library's window layout owns the outer sections. Lists and
footers own their interior layouts and behaviors, composing library-created
visual components inside those slots.

Use a fixed MVP component vocabulary rather than a universal widget framework.
The library knows the parts it created; do not recursively inspect arbitrary
frame trees. Where a Blizzard behavior template is required, compose it in the
appropriate constructor without moving domain behavior into the library.
Keep native callbacks, setters, text/value access, and custom extensions
accessible on the returned controls. Native container/bank item-button bridges
remain addon-owned; create only their separate custom visuals with LibYvSkins.

### State And Restoration

- Register visual state in side tables; never put library metadata onto native
  container/bank item-button tables. Skin custom row visuals only.
- Establish ownership at construction. Replace addon-owned visual construction
  and atlas/color writers with direct factory calls and explicit state updates.
  Do not construct an old control and then pass it through a YvBags adapter.
- Modern and Flat must completely restore each other's declared art, alphas,
  texture coordinates/masks, font settings, focus/selection layers, and layout.
  Retain the known constructor baseline once, not a deep copy of frame objects
  and not a fresh snapshot of already-skinned state on every switch.
- Hook visual notifications once without replacing behavior scripts. Avoid
  adding permanent hooks for each renderer switch. Native checkbox and tab
  behavior remain authoritative; the renderer consumes their state.
- An unknown required role/part is an error in our contract, not a silent
  fallback. Optional-addon capability checks belong only at that boundary.
- Pooled components stay registered across item recycling. Reset item-specific
  state without releasing/rebuilding their skin; apply the latest appearance
  revision before a hidden/recycled component is shown again.
- Keep generic Modern assets/state mappings in the library. YvBags supplies
  its existing custom border texture, fonts, and semantic artwork as explicit
  media overrides; never hard-code another addon's installation path inside
  the library. No asset export or generated replacement art is required.

### Persistence And Apply State

Add `NS.defaults.global.appearance.skin = "modern"`; no schema migration.
Keep `requestedSkin` (saved choice), `appliedSkin` (actual renderer), and any
pending reason distinct. Settings must accurately display both when different.

1. Validate a selection and save it through NS.globalDB.
2. A single Appearance-owned callback requests application from the context.
3. Modern/Flat transitions coalesce into one safe post-input update. Apply
   both windows atomically outside combat; retain only the latest request.
4. If EUI is involved after startup resolution, leave the running appearance
   unchanged and mark reload pending. Choosing the currently applied skin
   again cancels the pending request.
5. Combat-delayed built-in transitions resume on combat exit. Cancel active
   header editing gestures; do not apply while moving/resizing or while the
   scale popup owns an active drag. Retry from the owning interaction's finish
   or cancel notification, not an idle polling loop.
6. Update only visual/layout state. Preserve search text/focus, open bank type,
   scroll position, collapsed groups, item locks, and native button identity.
   Close transient scale UI only after its active interaction ends.

Keep default Modern/Flat media local to the context. For EUI, read current
public appearance values into a context revision and recolor only registered
presentation regions. Rarity, binding, profession quality, currency, errors,
and low-space warning colors remain semantic and are not replaced by accent.

## Pixel-Perfect Rendering Contract

Two different operations must remain explicit:

- **Layout rounding:** round a UI-unit size/offset with Blizzard PixelUtil at
  the target region's effective scale. This preserves the user's UI scaling.
- **Physical thickness:** `pixels * PixelUtil.GetPixelToUIUnitFactor() /
  region:GetEffectiveScale()`. A one- or two-pixel border remains that many
  physical pixels at every supported frame/UI scale.

The inspected `PixelUtil.ConvertPixelsToUI*` functions round a requested size;
do not substitute them for the physical-thickness equation based on the name.

Use four solid rectangular edges for borders and one solid rectangle for a
separator, following RGM's technique. Avoid corner overlap, rotated separator
textures, baked glow padding, and odd-thickness lines centered on half pixels.
Disable automatic texel snapping/bias on these manually aligned solid regions.
Keep their visual bounds pixel-aligned as well as their thickness: rounded
relative offsets alone cannot fix a fractional ancestor or scroll origin.

All new list separator strokes start at one physical pixel. Retain existing
category/section row extents and column separator hit widths; replace the old
texture's padded offsets with placement inside the intended visible bounds.
The header owns the full inner-frame width above the scrollbar, including
titles and controls. Only scrolling rows reserve the scrollbar gutter. Join
column strokes to the header line using physical-pixel insets, not scaled
UI-unit gaps.

Geometry invalidation must cover window scale/size/move completion, parent UI
scale, display size, layout changes, and row placement. Use the exported
`BaseScrollBoxEvents.OnLayout`/`OnScroll` callbacks if visual edge compensation
is required during scrolling. Only adjust visible custom visuals there; do
not change protected row anchors or call a full context/layout rebuild per
scroll event. New/recycled rows receive current pixel metrics at initialization
or presentation refresh.

Cache the physical conversion factor per display revision and effective-scale
metrics per window revision. Run parent layout before child layout explicitly,
rather than copying RGM's two global weak-table passes. No new permanent
OnUpdate, global scale changes, item queries, or inventory-sized frame pools.

## EUI Integration Contract

Use only `EllesmereUI.RegisterSkin(addonName, callback)` and the documented
facade passed into that callback. Each consumer declares optional dependencies
on `EllesmereUI` and its `EllesmereUIBlizzardSkin` module; neither is embedded
in our package. Preserve YvBags' existing IconBrowser optional dependency.

- Register once per addon, not once per bag/bank window or embedded library
  copy. Centralize this state on the shared LibStub implementation.
- A registration can discover the public facade without applying it. If our
  context is not using EUI, the callback must not style anything, even though
  EUI enables third-party integrations by default.
- Core presence is not sufficient readiness: the skin module may be disabled,
  the client blocked, or EUI's master/per-addon skinning disabled. Require the
  callback and supported public facade before treating EUI as usable. Use
  `S.IsEnabled()` once available; never read/write EUI SavedVariables or private
  dispatch registries to infer or force state.
- Preserve early window/native-row prewarming. Resolve startup appearance
  after the EUI login callback has had a chance to run, using a bounded
  post-login reconciliation. If it never arrives, select the session's Modern
  fallback; never wait indefinitely or retry every frame. A facade arriving
  after fallback readiness requires a reload to activate EUI.
- Keep first-open presentation coherent: do not reveal a partially restyled
  window during startup resolution. Continue normal bag/bank replacement and
  open/close routing; appearance readiness must not trap the UI closed.
- Apply EUI primitives to declared visual controls, not a full native item
  interaction button or an unrelated Blizzard dialog. Never call private
  `WSkin`, frame-data tables, or undocumented helpers.
- For search inputs, place preserved search art in a declared visual child
  or restore only the explicitly registered icon after EUI's public edit-box
  styling. Preserve native placeholder, clear button, text-change behavior,
  focus, Escape, and Ctrl+F behavior.
- Expose standard label references for custom tab/button visuals. Feed bank
  selection through the library tab handle and invoke the public tab primitive
  on state refresh; do not leave a second Modern selected/hover renderer active.
- Use public EUI primitives where they fit. For our custom list dividers,
  markers, semantic icon borders, and focus indicators, use library drawing
  with public EUI tokens. Do not pass our custom header into a primitive that
  assumes an auction-house header hierarchy.
- Subscribe once per context to `S.OnLooksChanged`. Refresh context tokens and
  affected colors/fonts/layout measurements, without rescanning or sorting
  items. Do not install callbacks per pooled row or per refresh.
- EUI disabling while already applied cannot safely restore Modern live.
  Keep the applied-session contract and explain that reload is required; do
  not overlay a fallback on top of still-installed EUI hooks. Query availability
  when Settings opens/refreshes and through public notifications, not polling.
- Catch capability/version mismatches before applying any EUI art. Report
  adapter failures clearly; do not pretend an already partially applied skin
  was successfully rolled back. Restore through reload if necessary.

The adapter belongs in LibYvSkins, not YvBags. Future addons create their own
named context and library controls and declare dependencies, but should
not need to duplicate EUI-specific integration code for supported roles.

## Module And Dependency Map

Proposed library structure, split further only for distinct ownership:

```text
Libs/LibYvSkins-1.0/
  LibYvSkins-1.0.lua       # LibStub bootstrap, persistent shared prototypes
  Context.lua             # registrations, selection/status, revisions
  Pixel.lua               # physical borders/lines and geometry helpers
  Window.lua              # generic sections, native controls, window lifecycle
  Toolbar.lua             # optional control-row layout and measurement
  Components/             # visual contracts used by both built-in skins
  Skins/Modern.lua
  Skins/Flat.lua
  Integrations/EllesmereUI.lua
  embed.xml
  README.md
  CHANGELOG.md
  LICENSE
  .editorconfig
  .gitattributes
  .pkgmeta
  tests/                  # Lua 5.1 mocks, contract and mixed-copy suites
  examples/               # development-only two-context/visual harness
```

YvBags changes:

- `Modules/Appearance/Appearance.lua`: expose the shared `NS.Skins` context;
  later own preference/application requests and Settings notifications. Do not
  add constructor proxies, window/list maps, or an Appearance/Window adapter.
- `Defaults.lua`, `Settings.lua`: shared preference, inline selectors,
  pending/unavailable status, reset and reload UI, targeted notifications.
- `Media.lua`: retain addon artwork and semantic media; supply context inputs
  without globally changing LMS or other consumers' colors/fonts.
- MainFrame and Bank frame/layout/geometry modules: construct roots through
  `NS.Skins:CreateWindow`, use library slots and chrome measurements, and keep
  geometry storage and native lifecycle. Bank refreshes report visible/selected
  tabs to the eventual library toolbar layout instead of restoring old anchors.
- Both footers and Controls/SearchBox modules: populate library-created slots
  and use component constructors as they become available. Remove competing
  style writers. Preserve native click/drag/money/deposit flows, icon preloading,
  and disabled readiness states.
- ItemList Header/GroupRow/DividerRow/ItemRow and Layout/List: directly created
  visual primitives, style/pixel revision refreshes, and viewport-pool capacity.
  Do not alter Model, inventory normalization, sorting, category rules, or
  native item-button bridges to implement appearance.
- `YvBags.toc`: LibStub before the new embed; Appearance after Media and before
  list/frame consumers. Initialize the context before Core constructs windows.
  Preserve dependency order for existing Layout/Geometry/Controls modules.
- `.gitmodules`, `.pkgmeta`, README, AGENTS, TODO and both project changelogs:
  update with implemented contracts and completed validation, not prematurely.

LMS continues to own Settings layout, fields, input commits, and callbacks.
LibYvSkins owns appearance, not a replacement field/control-value abstraction.
Do not alter LMS merely to apply the bag/bank skin.

The scale popup remains LibPopupSlider-owned behavior. Its public
`GetVisualParts`, `IsInteracting`, and `SetFontAppearance` contract is developed
in the canonical LibPopupSlider submodule and consumed by
`Integrations/PopupSlider.lua`. Font fitting is deferred during an active drag.
The published `1.2.0` / MINOR `3` release preserves RGM's `showBorder` option and
supersedes older embeds. Legacy popup instances retain their original working
behavior; an external instance without the public API still reports unavailable
styling so skin selection can reject incomplete transitions. YvBags pins this
published popup contract independently of the unreleased skinning library.

## Implementation Phases And Gates

### Phase 0: Bootstrap And Contract Harness

- [x] Recheck worktrees, remote refs, branch, and any existing library files.
- [x] Bootstrap the initially empty repository on `main` in the intended Libs
  path. The user created and published its initial commit before registering
  the gitlink; no attempt to register an unborn HEAD is needed.
- [x] Register that existing committed clone as the submodule using the supplied
  SSH URL and branch `main`; normalize its Git directory with Git's supported
  submodule workflow. Never replace an existing directory or discard work.
- [x] Add library metadata, neutral API family `LibYvSkins-1.0`, MINOR `1`,
  ordered embed, the agreed license, and Lua 5.1 harness.
- [x] Implement context/registration skeleton and fixture components sufficient
  for two independent consumers, not a broad speculative widget toolkit.
- [x] Add mixed-copy tests before expanding the public API.

Gate passed (2026-09-12): library source is committed and YvBags records the
matching gitlink. Loader, context-isolation, and mixed-copy tests pass without
duplicate registrations.

### Phase 1: Pixel Primitives And Existing List Dividers

- [x] Implement tested physical thickness, scale-aware rounding, solid lines
  and four-edge borders, plus explicit geometry invalidation.
- [x] Load the new embed and initial Appearance context in YvBags.
- [x] Replace header bottom, column separators, group/category, and new/pinned
  section divider drawing in both lists. Keep hit targets and row extents.
- [x] Connect both Geometry scale paths and list placement callbacks to targeted
  pixel refreshes. Correct fractional-origin alignment without moving native
  item buttons or changing column settings.

Initial in-game review found a header join gap at 125%+ and premature header
clipping at the scrollbar. Physical-pixel join insets and full-width header
bounds are implemented and included in the accepted Modern foundation.

Gate passed (2026-09-12): the user confirmed the current Modern appearance and
functionality. Retain regression coverage for crisp 1px strokes at 50%, 75%,
100%, 125%, and 150% frame scales, multiple UI scales, and 1080p/1440p/4K where
available, plus drag, resize, reload, smooth scrolling, clipping, and header
interactions. The checkpoint confirmation is not a claim that every display
combination has been tested.

### Phase 1.5: Creation-First Window Foundation

User-directed architecture update before continuing broader skin work:

- [x] Build the canonical library window constructor, preserving the current
  Modern shell, outer background, tiled inset, title/portrait, footer height,
  and toolbar/content positions.
- [x] Create bag/bank windows directly through the library. Remove duplicated
  shell/content/footer/resize creation and addon-owned chrome measurements.
- [x] Replace the temporary Appearance separator wrapper and window/list map
  with direct separator factories and window-root geometry refreshes.
- [x] Keep ordinary frames/controls directly accessible and preserve native
  close/resize behavior with consumer-owned persistence callbacks.
- [x] Add constructor, geometry/lifecycle, raw-control, and mixed-copy tests.

Gate passed (2026-09-12): the user confirmed the current Modern appearance and
functionality after the creation-first refactor. Preserve open/close,
move/resize/scale, toolbar interactions, footer alignment, bank switching, and
pixel corrections as regression checks for subsequent work. This foundation
does not imply the remaining control skins are done.

### Phase 2: Modern Ownership And Window/Component Layer

- [x] Establish the common window constructor and direct first-consumer path
  in Phase 1.5. No legacy-window adapter is required.
- [x] Convert group/category accordion bars through the library's expandable
  header constructor, with native click/text access, visual expansion state,
  context-owned appearance, and pooled-state/load-order tests. Match LMS's
  Modern bar without leading icons or separate category dividers.
- [x] Implement the remaining concrete control factories and supported state
  handles. Preserve independent layout and skin selection.
- [x] Move generic Modern assets/state drawing out of addon-owned controls.
  Build search, scale/close/resize presentation, tabs, footer controls, list
  accents/text, and icon surfaces through library constructors.
- [x] Remove competing hover/refresh atlas writers as components are converted.
  Preserve tab selection precedence, correct atlas families/outsets, disabled
  controls, and input focus behavior.
- [x] Establish a presentation-only refresh path for both windows and pooled
  rows. Keep the old geometry/storage and all native banking actions intact.
- [x] Exercise the same window/control constructors in YvBags and the second
  library harness consumer; verify raw controls remain directly accessible.

Gate passed (2026-09-12): the user confirmed that bag and bank buttons/actions,
sorting, and header actions work as expected, and the Modern appearance is
unchanged by the migration. This accepts Phase 2 and clears the way for Phase 3;
it does not replace the full release regression matrix below.

### Phase 3: Flat Skin, Compact Chrome, And Built-In Selection

- [x] Implement Flat surfaces and all control states; use 1px physical window/
  input borders and 1px physical item/container icon borders.
- [x] Remove portrait/title visually in Flat while preserving the ButtonFrame
  structural root. Anchor the existing actions in the compact header and
  retain a non-intercepting drag region around its interactive controls.
- [x] Separate skin-default metrics from explicit addon-owned section/toolbar
  layouts. Calculate Body allocation and viewport reserves in LYS; keep search
  minimums and footer clearance in YvBags. Keep fixed columns clipped as before.
- [x] Prewarm any additional viewport capacity needed by the shorter header
  before allowing a combat-time open; do not rebuild providers to restyle.
- [x] Add the shared LSDB preference and LMS selectors/status. Implement
  coalesced live Modern/Flat transitions, appearance reset, combat deferral,
  and interaction cancellation/end handling.
- [x] Preserve and restore Modern art on repeated round trips. Update active
  custom row art in place and mark hidden pool members for the next revision.

MVP appearance and subsequent window-shell refactor accepted by the user.
Retain Modern -> Flat -> Modern checks in both windows without lost search,
changed bank selection, scroll jumps beyond unavoidable viewport clamping,
provider replacement, duplicate regions/hooks, or saved-position changes.
Validate narrow headers, all-hidden columns, footer alignment, both bank
views, and combat transitions during subsequent work.

### Phase 4: Optional EllesmereUI Provider

- [ ] Implement the library-owned public-API adapter and one registration per
  consuming addon; use fake facades in library tests and real EUI in game.
- [ ] Implement startup readiness/fallback and capability diagnostics. Ensure
  EUI installed with Modern/Flat selected causes no styling calls.
- [ ] Adapt search preservation, native label references, tab state, checkbox
  state, custom icon borders, and context-owned pixel dividers explicitly.
- [ ] Add the EUI choice plus entering/leaving reload workflow and pending
  cancellation. Neither global EUI settings nor other addons may be changed.
- [ ] Apply live EUI appearance-token updates through one context subscription;
  remeasure affected labels/footer fitting without rebuilding item data.
- [ ] Test late components/pool reuse and EUI readiness before first bag/bank
  opening. Finish any required upstream scale-popup presentation contract.

Gate: EUI is selectable, matches the user's EUI style, and remains optional.
Both directions of transition are coherent across reload. With EUI absent,
disabled, unsupported, or blocked for this addon, the built-in skins still work.

### Phase 5: Regression, Documentation, And Release Readiness

- [ ] Complete the library suites and in-game matrix below. Audit hot paths,
  persistent registrations, and multi-addon load-order behavior.
- [ ] Update library README with API, ownership, two consumer examples, EUI
  prerequisites, reload semantics, fallback behavior, and Masque extension
  boundary. Add a small skin-authoring guide for supported component roles.
- [ ] Update YvBags README/AGENTS and incremental changelog entries to reflect
  implemented behavior. Retain unrelated TODOs and column-validation work.
- [ ] Prepare the first library release and matching consumer package metadata
  only after validation. Do not commit, tag, or push without explicit authority.
- [ ] Remove this plan only after required implementation and in-game gates
  pass; move genuinely deferred work to TODO rather than marking it complete.

## Library And Package Release Workflow

- The submodule working tree is the development source of truth. Do not edit a
  standalone LibYvSkins checkout in parallel. A standalone checkout can pull
  the released commit later.
- Repository name: `LibYvSkins`; LibStub family/embed path:
  `LibYvSkins-1.0`; first intended SemVer release: `1.0.0`, without `v`.
- Keep persistent library tables/prototypes and integration registries across
  compatible LibStub upgrades. Guard split runtime modules so an older embed
  cannot overwrite the newer implementation selected by LibStub.
- MINOR is release metadata, not a per-change counter. Develop the initial
  release at MINOR 1; bump once for each later published implementation.
  Test old-first/new-first and pre-existing instances explicitly. Equal-MINOR
  development copies can mask each other; isolate the dev copy during testing.
- Make the library commit/tag available upstream before releasing a YvBags
  gitlink/package that depends on it. User-authorized library commit/tag comes
  first, followed by the YvBags submodule pointer and matching package pin.
- Add the packager external at `Libs/LibYvSkins-1.0` using the HTTPS form of the
  repository URL and the actual released tag. Do not ship a pin to a nonexistent
  tag or a floating development branch. SSH remains the development remote.
- Exclude PLAN.md, library tests/examples, and development-only files from the
  addon package. Preserve licenses and required runtime files. Verify a clean
  recursive checkout and packaged addon contain every embed dependency and no
  accidental standalone-copy references.
- Keep LMS and other dependency version changes separate unless their public
  API actually changes for this feature; run their applicable suites if so.

## Validation Matrix

### Automated Library Checks

- [ ] Lua 5.1 syntax and public-contract tests, including invalid required
  parts/roles and optional external capability failures.
- [ ] Canonical constructors are the actual consumer path; no YvBags existing-
  window adapters, frame-tree maps, or duplicated chrome constructors remain.
- [ ] Physical thickness and rounded layout values at multiple resolutions,
  effective scales, negative offsets, fractional origins, and odd/even sizes.
- [ ] Border edges do not overlap at corners, clips are respected, and repeated
  refreshes do not allocate new regions or add hooks/callbacks.
- [ ] Contexts for two addons select independently; one addon has two windows
  sharing selection but different scales. No global media/theme contamination.
- [ ] Modern/Flat state transitions and restoration for all supported controls;
  selected, disabled, focused, hidden, and recycled components retain meaning.
- [ ] Requested/applied/pending state, latest-request coalescing, reset, cancel,
  combat deferral, startup fallback, and both reload-bound EUI directions.
- [ ] EUI callback before/after context construction, unavailable module,
  disabled facade, late activation, duplicate registration, and live looks
  updates. Non-EUI selection must produce zero EUI styling calls.
- [ ] Old-first/new-first/equal-MINOR loading, existing instances before a
  compatible upgrade, and older split modules loading after newer ones.

Do not add an addon-specific automated test suite to YvBags. Library mocks are
not proof of visual correctness, protected-frame safety, or EUI compatibility.

### In-Game Checks

- [ ] Cold login and reload with Modern/Flat, with and without EUI installed;
  cold bank Character/Warband switching and icon/configuration readiness.
- [ ] EUI selected with both modules enabled; master/per-addon skinning off;
  module disabled/removed; saved unavailable selection; re-enable and reload.
- [ ] EUI installed while Modern/Flat selected: neither window changes from
  EUI callbacks, Settings toggles, hover, bank refresh, or later pool creation.
- [ ] EUI accent/font/style changes update relevant visuals only. Rarity,
  binding, money, reagent indicators, warnings, and errors retain their meaning.
- [ ] Pixel checks at the scales/resolutions in Phase 1, including stationary
  and scrolling rows, fractional positions, move/resize, UI/display changes,
  and independently scaled bag/bank windows.
- [ ] Search icon/clear button/focus/placeholder/Ctrl+F, scale popup, background dragging,
  close/Escape, input hit areas, and no invisible title region intercepting
  compact-header clicks. Modern restores its portrait/title/selected atlases.
- [ ] Column reordering/resizing/hiding, hide-all recovery, header/cell
  alignment, clipping, sort/group state, pin modes, category collapse, and new
  item markers/breathing/hover acknowledgement under every skin.
- [ ] Bag and bank use, drag, split, compare, merchant/readable hover, tooltip
  anchoring, real-empty-slot drops, item locks, and rapid scrolling, including
  combat. No native bridge recreation/rebinding from a skin change.
- [ ] All footer actions, counts, money/currency fitting, deposit checkbox,
  disabled/purchase states, readiness and texture preloading remain intact.
- [ ] Profile switch/reset and mirror/detach do not alter global skin; appearance
  reset changes both windows without resetting profiles or geometry.
- [ ] Repeated switches and long scroll sessions leave stable frame/texture/
  callback counts. No new idle OnUpdate; skin changes do not invoke inventory
  scans, category classification, sorting, or data-provider replacement.

## Deferred Work

- Masque: retain a separate icon visual contract and replaceable border owner.
  Implement its adapter, grouping, preferences, and tests only in a later task.
- User-editable accent/background choices remain in TODO. The context token
  refresh path added here is the extension point, not a new color picker.
- Migrate RGM, ReadyCheckConsumables, or other addons after this library's
  consumer contract is proven. Do not turn their migration into an MVP gate.
- Third-party arbitrary skin packs/editor, live EUI uninstall, and reskinning
  Blizzard/LMS settings or unrelated addon windows are not MVP requirements.

## Reference Entry Points

- RGM: `../RaidGroupManager/UI/PixelPerfect.lua`, `UI/Widgets.lua`, and
  `UI/MainFrame.lua` (reference implementation, not a dependency).
- Blizzard export: `Blizzard_SharedXML/PixelUtil.lua`, `PixelUtilSecure.lua`,
  and `Shared/Scroll/ScrollBox.lua` under the inspected code export; use current
  ButtonFrame/SearchBox/MinimalScrollBar templates as the behavior authority.
- [EllesmereUI public skinning API](https://github.com/EllesmereGaming/EllesmereUI/blob/main/SKINNING_API.md).
  Local implementation: `../EllesmereUIBlizzardSkin/EllesmereUIBlizzardSkin_SkinAPI.lua`
  and `EllesmereUIBlizzardSkin_WindowEngine.lua` for verifying compatibility,
  never as private interfaces to call.
- Library development remote: `git@github.com:KyleCRat/LibYvSkins.git`.
