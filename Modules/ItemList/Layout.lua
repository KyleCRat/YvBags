local _, NS = ...

-- Shared geometry contract for list components.
local Layout = {
    HeaderHeight = 24,
    HeaderLeftOffset = 0,
    HeaderTopOffset = 0,
    HeaderRightOffset = 0,
    ScrollBarContentPadding = 22,
    ItemMarkerWidth = 20,
    ScrollBoxLeftOffset = 0,
    ScrollBoxRightOffset = 0,
    ScrollBoxTopGap = -2,
    ScrollBoxBottomOffset = 0,
    ScrollBarRightOffset = -8,
    ScrollBarTopOffset = -2,
    ScrollBarBottomOffset = 2,
}
NS.ItemListLayout = Layout

-- One geometry snapshot feeds both headers and custom cell regions. Preview
-- updates reuse the entries; pooled rows only relayout when the revision moves.
function Layout.UpdateColumns(layout, config)
    local Columns = NS.ItemListColumns
    local gap = Columns.GetColumnGap()
    wipe(layout.byKey)
    local count = 0
    local x = 0
    for _, key in ipairs(config.order) do
        if not config.hidden[key] then
            count = count + 1
            if count == 1 and key ~= "count" then
                -- Quantity already leaves room for the existing row-edge marker.
                -- Other leading cells need an inset without moving the defaults.
                x = Layout.ItemMarkerWidth
            end
            local column = Columns.GetColumn(key)
            local entry = layout.entries[count] or {}
            entry.column = column
            entry.x = x
            entry.width = config.widths[key] or column.width
            layout.entries[count] = entry
            layout.byKey[key] = entry
            x = x + entry.width + gap
        end
    end
    for index = #layout.entries, count + 1, -1 do
        layout.entries[index] = nil
    end
    layout.width = count > 0 and x - gap or 0
    layout.revision = layout.revision + 1
end
