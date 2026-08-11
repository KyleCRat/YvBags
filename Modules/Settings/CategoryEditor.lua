local _, NS = ...

-- Profile-backed category editor for the Blizzard Settings canvas.
local CategoryEditor = {}
NS.CategoryEditor = CategoryEditor

local Categories = NS.Categories
local Media = NS.Media
local ModernSettings = LibStub("LibModernSettings-1.0")

local OTHER_CATEGORY_ID = "other"
local NEW_CATEGORY_NAME = "New Category"
local LIST_WIDTH = 250
local PANE_GAP = 14
local DIVIDER_WIDTH = 1
local LIST_HEADER_HEIGHT = 34
local LIST_ROW_HEIGHT = 34
local LIST_SCROLLBAR_GAP = 6
local LIST_SCROLLBAR_WIDTH = 17
local HANDLE_WIDTH = 26

local CATEGORY_ERROR_MESSAGES = {
    [Categories.ErrorCodes.InvalidName] = "The category name must contain valid UTF-8 text and no ASCII control characters.",
    [Categories.ErrorCodes.DuplicateName] = "A category with that name already exists.",
    [Categories.ErrorCodes.MissingCategory] = "That category no longer exists.",
    [Categories.ErrorCodes.RequiredCategory] = "Other is the required fallback category and cannot be removed.",
    [Categories.ErrorCodes.InvalidIndex] = "That category position is no longer available.",
}

local function ReportCategoryError(action, errorCode)
    NS:Print(("%s failed: %s"):format(
        action,
        CATEGORY_ERROR_MESSAGES[errorCode] or tostring(errorCode)
    ))
end

-- Virtualized category list rows
local function SetRowSelected(row, selected)
    row.selection:SetShown(selected)

    local color = selected and NORMAL_FONT_COLOR or HIGHLIGHT_FONT_COLOR

    row.label:SetTextColor(color.r, color.g, color.b)
end

local function InitializeCategoryRow(row)
    if row.categoryRowInitialized then
        return
    end

    row.categoryRowInitialized = true
    row:RegisterForClicks("LeftButtonUp")

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    row.stripe:SetColorTexture(1, 1, 1, 0.035)
    row.stripe:Hide()

    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints(row)
    row.hover:SetColorTexture(1, 1, 1, 0.05)
    row.hover:Hide()

    row.selection = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.selection:SetAllPoints(row)

    local accentR, accentG, accentB = Media.GetAccentColor()

    row.selection:SetColorTexture(accentR, accentG, accentB, 0.18)
    row.selection:Hide()

    row.handle = CreateFrame("Button", nil, row)
    row.handle:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.handle:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.handle:SetWidth(HANDLE_WIDTH)

    row.handle.icon = row.handle:CreateTexture(nil, "ARTWORK")
    row.handle.icon:SetAtlas(Media.GetCategoryMoveAtlas(), true)
    row.handle.icon:SetPoint("CENTER")

    row.handle.hoverIcon = row.handle:CreateTexture(nil, "OVERLAY")
    row.handle.hoverIcon:SetAtlas(Media.GetCategoryMoveAtlas(), true)
    row.handle.hoverIcon:SetPoint("CENTER")
    row.handle.hoverIcon:SetBlendMode("ADD")
    row.handle.hoverIcon:SetAlpha(0.4)
    row.handle.hoverIcon:Hide()

    ModernSettings:SetTooltip(row.handle, {
        title = "Reorder Category",
        text = "Drag to move this category in the configured order.",
    })

    row.label = row:CreateFontString(nil, "ARTWORK")
    row.label:SetFontObject(GameFontHighlight)
    row.label:SetPoint("LEFT", row.handle, "RIGHT", 2, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetJustifyV("MIDDLE")
    row.label:SetWordWrap(false)
    row.label:SetMaxLines(1)

    row:SetScript("OnClick", function(self)
        self.owner:SelectCategory(self.definition.id)
    end)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
    end)
    row.handle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:GetParent().owner:StartCategoryDrag(self:GetParent())
        end
    end)
    row.handle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:GetParent().owner:FinishCategoryDrag()
        end
    end)
    row.handle:HookScript("OnEnter", function(self)
        self.hoverIcon:Show()
    end)
    row.handle:HookScript("OnLeave", function(self)
        self.hoverIcon:Hide()
    end)
end

local function RenderCategoryRow(row, definition, editor)
    InitializeCategoryRow(row)
    row.owner = editor
    row.definition = definition
    row.label:SetText(definition.name)
    row.stripe:SetShown(definition.index % 2 == 0)
    row.hover:Hide()
    row.handle.hoverIcon:Hide()
    SetRowSelected(row, definition.id == editor.selectedCategoryID)
end

local function ResetCategoryRow(row)
    row.owner = nil
    row.definition = nil
    row.label:SetText("")
    row.stripe:Hide()
    row.hover:Hide()
    row.handle.hoverIcon:Hide()
    row.selection:Hide()
end

local function CreateCategoryListView(editor)
    local view = CreateScrollBoxListLinearView()

    view:SetElementExtent(LIST_ROW_HEIGHT)
    view:SetElementFactory(function(factory)
        factory("Button", function(row, definition)
            RenderCategoryRow(row, definition, editor)
        end)
    end)
    view:SetElementResetter(ResetCategoryRow)

    return view
end

local function CreateAddCategoryButton(parent, editor)
    local button = ModernSettings:CreateButton(parent, {
        text = "Add Category",
        iconAtlas = Media.GetCategoryAddAtlas(),
        fitToContent = true,
        tooltip = "Create an empty category in the active profile.",
        onClick = function()
            editor:AddCategory()
        end,
    })

    return button
end

-- Editor state and mutations
local function FindDefinition(editor, categoryID)
    for index = 1, #editor.definitions do
        local definition = editor.definitions[index]

        if definition.id == categoryID then
            return definition, index
        end
    end

    return nil, nil
end

local function RefreshVisibleSelection(editor)
    editor.scrollBox:ForEachFrame(function(row)
        if row.definition then
            SetRowSelected(
                row,
                row.definition.id == editor.selectedCategoryID
            )
        end
    end)
end

local function RefreshCategoryDetail(editor)
    local definition = FindDefinition(editor, editor.selectedCategoryID)

    if not definition then
        editor.nameEdit:SetValue("")
        editor.nameEdit:SetControlEnabled(false)
        editor.removeButton:SetControlEnabled(false)
        return
    end

    editor.nameEdit:SetControlEnabled(true)
    editor.nameEdit:SetValue(definition.name)

    local canRemove = definition.id ~= OTHER_CATEGORY_ID

    editor.removeButton:SetControlEnabled(
        canRemove,
        canRemove and nil or {
            title = "Required Category",
            text = "Other is the required fallback and cannot be removed.",
        }
    )
end

local function CommitCategoryNameEdit(editor)
    local editBox = editor.nameEdit

    if editBox then
        editBox:CommitAndClearFocus()
    end
end

local function SelectCategory(editor, categoryID)
    if not FindDefinition(editor, categoryID) then
        return false
    end

    if categoryID ~= editor.selectedCategoryID then
        CommitCategoryNameEdit(editor)
    end

    editor.selectedCategoryID = categoryID
    RefreshVisibleSelection(editor)
    RefreshCategoryDetail(editor)

    return true
end

local function RefreshCategories(editor, retainScroll, focusName)
    editor:CancelCategoryDrag()
    editor.definitions = Categories.GetOrderedDefinitions()

    for index = 1, #editor.definitions do
        editor.definitions[index].index = index
    end

    if not FindDefinition(editor, editor.selectedCategoryID) then
        if not SelectCategory(editor, OTHER_CATEGORY_ID) then
            editor.selectedCategoryID = editor.definitions[1]
                and editor.definitions[1].id
                or nil
        end
    end

    local dataProvider = CreateDataProvider(editor.definitions)
    local retain = retainScroll
        and ScrollBoxConstants.RetainScrollPosition
        or nil

    editor.scrollBox:SetDataProvider(dataProvider, retain)
    editor.dataProvider = dataProvider
    RefreshCategoryDetail(editor)

    if focusName then
        local _, selectedIndex = FindDefinition(
            editor,
            editor.selectedCategoryID
        )

        if selectedIndex then
            editor.scrollBox:ScrollToElementDataIndex(
                selectedIndex,
                ScrollBoxConstants.AlignCenter
            )
        end

        editor.nameEdit:FocusValue()
    end
end

local function CommitSelectedCategoryName(editor, name)
    editor.suppressCategoryRefresh = true
    local renamed, errorCode = Categories.RenameCategory(
        editor.selectedCategoryID,
        name
    )
    editor.suppressCategoryRefresh = nil

    if not renamed then
        return nil, errorCode
    end

    RefreshCategories(editor, true)
    return renamed
end

local function AddCategory(editor)
    CommitCategoryNameEdit(editor)

    local suffix = 1
    local categoryID
    local errorCode

    repeat
        local name = suffix == 1
            and NEW_CATEGORY_NAME
            or (NEW_CATEGORY_NAME .. " " .. suffix)

        editor.suppressCategoryRefresh = true
        categoryID, errorCode = Categories.CreateCategory(name)
        editor.suppressCategoryRefresh = nil
        suffix = suffix + 1
    until categoryID or errorCode ~= Categories.ErrorCodes.DuplicateName

    if not categoryID then
        ReportCategoryError("Creating category", errorCode)
        return
    end

    editor.selectedCategoryID = categoryID
    RefreshCategories(editor, true, true)
end

local function RemoveSelectedCategory(editor)
    CommitCategoryNameEdit(editor)

    local definition = FindDefinition(editor, editor.selectedCategoryID)

    if not definition then
        return
    end

    if definition.id == OTHER_CATEGORY_ID then
        ReportCategoryError(
            "Removing category",
            Categories.ErrorCodes.RequiredCategory
        )
        return
    end

    local categoryID = definition.id
    local categoryName = definition.name

    StaticPopup_ShowCustomGenericConfirmation({
        text = "Remove %s? Items assigned to it will move to Other.",
        text_arg1 = categoryName,
        acceptText = "Remove",
        showAlert = true,
        callback = function()
            editor.suppressCategoryRefresh = true
            local removed, errorCode = Categories.RemoveCategory(categoryID)
            editor.suppressCategoryRefresh = nil

            if not removed then
                ReportCategoryError("Removing category", errorCode)
                return
            end

            editor:RefreshCategories(true)
        end,
    })
end

-- Active-only drag polling and insertion geometry
local function CancelCategoryDrag(editor)
    editor.draggedCategoryID = nil
    editor.dragInsertionPosition = nil
    editor.insertionIndicator:Hide()
    editor:SetScript("OnUpdate", nil)
end

local function UpdateCategoryDrag(editor)
    if not editor.draggedCategoryID then
        CancelCategoryDrag(editor)
        return
    end

    if not IsMouseButtonDown("LeftButton") then
        editor:FinishCategoryDrag()
        return
    end

    local _, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()

    cursorY = cursorY / scale

    local nearestRow
    local nearestDistance
    local insertBefore

    editor.scrollBox:ForEachFrame(function(row)
        if not row.definition then
            return
        end

        local top = row:GetTop()
        local bottom = row:GetBottom()

        if not top or not bottom then
            return
        end

        local midpoint = (top + bottom) / 2
        local distance = math.abs(cursorY - midpoint)

        if not nearestDistance or distance < nearestDistance then
            nearestRow = row
            nearestDistance = distance
            insertBefore = cursorY >= midpoint
        end
    end)

    if not nearestRow then
        editor.dragInsertionPosition = nil
        editor.insertionIndicator:Hide()
        return
    end

    editor.dragInsertionPosition = nearestRow.definition.index
        + (insertBefore and 0 or 1)
    editor.insertionIndicator:ClearAllPoints()
    editor.insertionIndicator:SetWidth(editor.scrollBox:GetWidth())
    editor.insertionIndicator:SetPoint(
        "CENTER",
        nearestRow,
        insertBefore and "TOP" or "BOTTOM",
        0,
        0
    )
    editor.insertionIndicator:Show()
end

local function StartCategoryDrag(editor, row)
    if not row.definition then
        return
    end

    CommitCategoryNameEdit(editor)
    editor.draggedCategoryID = row.definition.id
    editor.dragInsertionPosition = row.definition.index
    editor:SelectCategory(row.definition.id)
    editor:SetScript("OnUpdate", UpdateCategoryDrag)
    UpdateCategoryDrag(editor)
end

local function FinishCategoryDrag(editor)
    local categoryID = editor.draggedCategoryID
    local insertionPosition = editor.dragInsertionPosition
    local _, currentIndex = FindDefinition(editor, categoryID)
    local categoryCount = #editor.definitions

    CancelCategoryDrag(editor)

    if not categoryID or not insertionPosition or not currentIndex then
        return
    end

    local targetIndex = insertionPosition

    if insertionPosition > currentIndex then
        targetIndex = insertionPosition - 1
    end

    targetIndex = math.max(1, math.min(categoryCount, targetIndex))

    if targetIndex == currentIndex then
        return
    end

    editor.suppressCategoryRefresh = true
    local moved, errorCode = Categories.MoveCategory(categoryID, targetIndex)
    editor.suppressCategoryRefresh = nil

    if not moved then
        ReportCategoryError("Moving category", errorCode)
        return
    end

    editor:RefreshCategories(true)
end

-- Master-detail canvas construction
local function CreateCategoryList(parent, editor)
    local header = CreateFrame("Frame", nil, parent)

    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    header:SetHeight(LIST_HEADER_HEIGHT)

    local title = ModernSettings:CreateText(header, {
        fontObject = GameFontNormal,
        text = "Categories",
    })

    title:SetPoint("LEFT", header, "LEFT", 0, 0)

    local addButton = CreateAddCategoryButton(header, editor)

    addButton:SetPoint("RIGHT", header, "RIGHT", 0, 0)
    editor.addButton = addButton

    local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")

    scrollBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    scrollBox:SetPoint(
        "BOTTOMRIGHT",
        parent,
        "BOTTOMRIGHT",
        -(LIST_SCROLLBAR_GAP + LIST_SCROLLBAR_WIDTH),
        0
    )
    scrollBox:SetClipsChildren(true)

    local scrollBar = CreateFrame(
        "EventFrame",
        nil,
        parent,
        "MinimalScrollBar"
    )

    scrollBar:SetWidth(LIST_SCROLLBAR_WIDTH)
    scrollBar:SetPoint(
        "TOPLEFT",
        scrollBox,
        "TOPRIGHT",
        LIST_SCROLLBAR_GAP,
        0
    )
    scrollBar:SetPoint(
        "BOTTOMLEFT",
        scrollBox,
        "BOTTOMRIGHT",
        LIST_SCROLLBAR_GAP,
        0
    )

    local view = CreateCategoryListView(editor)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    editor.scrollBox = scrollBox
    editor.scrollBar = scrollBar
    editor.listView = view

    local indicator = parent:CreateTexture(nil, "OVERLAY")
    local accentR, accentG, accentB = Media.GetAccentColor()

    indicator:SetHeight(2)
    indicator:SetColorTexture(accentR, accentG, accentB, 1)
    indicator:Hide()
    editor.insertionIndicator = indicator
end

local function CreateCategoryDetail(parent, editor)
    local title = ModernSettings:CreateText(parent, {
        fontObject = GameFontNormalLarge,
        text = "Category",
    })

    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

    local nameLabel = ModernSettings:CreateText(parent, {
        fontObject = GameFontHighlight,
        text = "Name",
    })

    nameLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)

    local nameEdit = ModernSettings:CreateTextInput(parent, {
        width = parent:GetWidth(),
        onCommit = function(name)
            return CommitSelectedCategoryName(editor, name)
        end,
        onError = function(errorCode)
            ReportCategoryError("Renaming category", errorCode)
        end,
    })

    nameEdit:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -6)
    editor.nameEdit = nameEdit

    local removeButton = ModernSettings:CreateButton(parent, {
        text = "Remove",
        width = 110,
        tooltip = "Remove this category from the active profile.",
        onClick = function()
            RemoveSelectedCategory(editor)
        end,
    })

    removeButton:SetPoint(
        "TOPLEFT",
        nameEdit,
        "BOTTOMLEFT",
        0,
        -16
    )
    editor.removeButton = removeButton

    local rulesRegion = CreateFrame("Frame", nil, parent)

    rulesRegion:SetPoint("TOPLEFT", removeButton, "BOTTOMLEFT", 0, -16)
    rulesRegion:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    editor.rulesRegion = rulesRegion
end

local function BuildEditorFrame(frame, measurementFrame)
    local layout = ModernSettings:CreateCanvasLayout(frame, {
        measurementFrame = measurementFrame,
    })
    local flow = layout:GetRootFlow()

    layout:AddHeader(
        "Categories",
        "Create, rename, remove, and reorder the categories stored in the active profile."
    )

    local editorHeight = math.max(
        layout:GetCanvasHeight()
            - flow:GetCursor()
            - layout:GetStyleValue("paddingBottom"),
        360
    )
    local editorRegion = flow:AddCustom(editorHeight, {
        marginBottom = 0,
    })
    local availableWidth = editorRegion:GetWidth()
    local listWidth = math.max(
        200,
        math.min(LIST_WIDTH, math.floor(availableWidth * 0.38))
    )
    local rightWidth = availableWidth
        - listWidth
        - PANE_GAP
        - DIVIDER_WIDTH

    local listPane = CreateFrame("Frame", nil, editorRegion)

    listPane:SetSize(listWidth, editorHeight)
    listPane:SetPoint("TOPLEFT", editorRegion, "TOPLEFT", 0, 0)

    local divider = editorRegion:CreateTexture(nil, "ARTWORK")

    divider:SetColorTexture(1, 1, 1, 0.12)
    divider:SetWidth(DIVIDER_WIDTH)
    divider:SetPoint("TOPLEFT", listPane, "TOPRIGHT", PANE_GAP / 2, 0)
    divider:SetPoint("BOTTOMLEFT", listPane, "BOTTOMRIGHT", PANE_GAP / 2, 0)

    local detailPane = CreateFrame("Frame", nil, editorRegion)

    detailPane:SetSize(rightWidth, editorHeight)
    detailPane:SetPoint(
        "TOPLEFT",
        divider,
        "TOPRIGHT",
        PANE_GAP / 2,
        0
    )

    CreateCategoryList(listPane, frame)
    CreateCategoryDetail(detailPane, frame)
    layout:Finalize()

    frame.layout = layout
    frame.editorRegion = editorRegion
    frame.listPane = listPane
    frame.detailPane = detailPane
end

-- Public module contract
function CategoryEditor.CreateFrame(measurementFrame)
    local frame = CreateFrame("Frame")

    frame.definitions = {}
    frame.SelectCategory = SelectCategory
    frame.RefreshCategories = RefreshCategories
    frame.AddCategory = AddCategory
    frame.CancelCategoryDrag = CancelCategoryDrag
    frame.StartCategoryDrag = StartCategoryDrag
    frame.FinishCategoryDrag = FinishCategoryDrag

    BuildEditorFrame(frame, measurementFrame)

    frame.OnRefresh = function(self)
        self:RefreshCategories(true)
    end
    frame.OnDefault = function(self)
        CommitCategoryNameEdit(self)
        self.suppressCategoryRefresh = true
        Categories.ResetCategories()
        self.suppressCategoryRefresh = nil
        self:RefreshCategories(true)
    end
    frame:SetScript("OnHide", function(self)
        self:CancelCategoryDrag()
    end)

    Categories.RegisterCallback(function()
        if frame:IsShown() and not frame.suppressCategoryRefresh then
            frame:RefreshCategories(true)
        end
    end)

    frame:RefreshCategories(false)

    return frame
end
