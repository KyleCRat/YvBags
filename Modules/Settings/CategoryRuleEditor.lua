local _, NS = ...

-- Virtualized flat Rule Set editor embedded in the category detail pane.
local CategoryRuleEditor = {}
NS.CategoryRuleEditor = CategoryRuleEditor

local Categories = NS.Categories
local Media = NS.Media
local Rules = NS.CategoryRules
local ModernSettings = LibStub("LibModernSettings-1.0")

local OTHER_CATEGORY_ID = "other"
local HEADER_HEIGHT = 34
local SECTION_GAP = 8
local CONTROL_HEIGHT = 34
local SINGLE_LINE_ROW_HEIGHT = 46
local VALUE_ROW_HEIGHT = 88
local TEXT_VALUE_ROW_STEP = CONTROL_HEIGHT + SECTION_GAP
local ROW_INSET = 6
local CONTROL_GAP = 8
local DROPDOWN_EDGE_INSET = 2
local SCROLLBAR_GAP = 6
local SCROLLBAR_WIDTH = 17
local REMOVE_WIDTH = 65
local HANDLE_WIDTH = 26
local MOVER_ICON_SIZE = 18
local TEXT_ACTION_SIZE = 34
local BOOLEAN_IS_WIDTH = 16
local MODE_DROPDOWN_WIDTH = 170
local HEADER_CONTROL_GAP = 8

local RULE_ERROR_MESSAGES = {
    [Categories.ErrorCodes.MissingCategory] = "That category no longer exists.",
    [Categories.ErrorCodes.InvalidRuleMode] = "Select All Rules or Any Rule.",
    [Categories.ErrorCodes.InvalidRuleField] = "Select a supported rule field.",
    [Categories.ErrorCodes.InvalidRuleOperator] = "Select an operator supported by this field.",
    [Categories.ErrorCodes.InvalidRuleValue] = "Enter or select a valid value for this field.",
    [Categories.ErrorCodes.InvalidRuleValueIndex] = "That text match no longer exists.",
    [Categories.ErrorCodes.InvalidIndex] = "That rule position is no longer available.",
    [Categories.ErrorCodes.MissingRule] = "That rule no longer exists.",
    [Categories.ErrorCodes.RulesNotAllowed] = "Other is the unconditional fallback and cannot have rules.",
}

local function ReportRuleError(action, errorCode)
    NS:Print(("%s failed: %s"):format(
        action,
        RULE_ERROR_MESSAGES[errorCode] or tostring(errorCode)
    ))
end

local function UseVirtualizedRowClickTiming(button)
    -- Focus loss can rebuild a virtualized row before mouse-up.
    button:RegisterForClicks("LeftButtonDown")
end

local function RuleUsesValueRow(rule)
    return rule.field ~= nil
        and rule.operator ~= nil
        and Rules.OperatorNeedsValue(rule.operator)
end

local function IsBooleanRule(rule)
    return Rules.GetFieldValueKind(rule.field)
        == Rules.ValueKinds.Boolean
end

local function IsTextValueRule(rule)
    return RuleUsesValueRow(rule)
        and Rules.GetFieldValueKind(rule.field) == Rules.ValueKinds.Text
end

local function GetRuleRowHeight(rule)
    if not RuleUsesValueRow(rule) then
        return SINGLE_LINE_ROW_HEIGHT
    end

    if IsTextValueRule(rule) then
        return VALUE_ROW_HEIGHT
            + ((Rules.GetRuleTextValueCount(rule) - 1)
                * TEXT_VALUE_ROW_STEP)
    end

    return VALUE_ROW_HEIGHT
end

local function LayoutRuleRow(row)
    local rowWidth = row:GetWidth()
    if rowWidth <= 1 and row.owner then
        rowWidth = row.owner.scrollBox:GetWidth()
    end

    local contentLeft = ROW_INSET + HANDLE_WIDTH
    local contentWidth = math.max(
        1,
        rowWidth - (ROW_INSET * 2) - HANDLE_WIDTH
    )
    local hasValueRow = row.hasValueRow == true
    local isBoolean = row.isBoolean == true
    local isTextValueRule = row.isTextValueRule == true
    local textValueCount = row.textValueCount or 0
    local fieldWidth
    local operatorWidth

    if hasValueRow then
        fieldWidth = math.max(
            32,
            math.floor((contentWidth - CONTROL_GAP) / 2)
        )
        operatorWidth = math.max(
            32,
            contentWidth - fieldWidth - CONTROL_GAP
        )
    else
        local separatorWidth = isBoolean
            and (BOOLEAN_IS_WIDTH + (CONTROL_GAP * 2))
            or CONTROL_GAP
        local controlsWidth = math.max(
            64,
            contentWidth
                - REMOVE_WIDTH
                - CONTROL_GAP
                - separatorWidth
        )

        fieldWidth = math.max(32, math.floor(controlsWidth * 0.58))
        operatorWidth = math.max(32, controlsWidth - fieldWidth)
    end

    local scalarValueWidth = math.max(
        32,
        contentWidth - REMOVE_WIDTH - CONTROL_GAP
    )
    local textValueWidth = math.max(
        32,
        contentWidth
            - REMOVE_WIDTH
            - TEXT_ACTION_SIZE
            - (CONTROL_GAP * 2)
    )

    row.fieldDropdown:SetControlWidth(fieldWidth)
    row.operatorDropdown:SetControlWidth(operatorWidth)
    row.valueDropdown:SetControlWidth(scalarValueWidth)
    row.scalarValueEdit:SetWidth(scalarValueWidth)

    for _, control in ipairs(row.textValueControls) do
        control.input:SetWidth(textValueWidth)
    end

    row.fieldDropdown:ClearAllPoints()
    row.fieldDropdown:SetPoint(
        "TOPLEFT",
        row,
        "TOPLEFT",
        contentLeft,
        -ROW_INSET
    )

    row.operatorDropdown:ClearAllPoints()
    row.booleanIsText:ClearAllPoints()
    if isBoolean then
        row.booleanIsText:SetPoint(
            "LEFT",
            row.fieldDropdown,
            "RIGHT",
            CONTROL_GAP,
            0
        )
        row.operatorDropdown:SetPoint(
            "LEFT",
            row.booleanIsText,
            "RIGHT",
            CONTROL_GAP,
            0
        )
    else
        row.operatorDropdown:SetPoint(
            "TOPLEFT",
            row.fieldDropdown,
            "TOPRIGHT",
            CONTROL_GAP,
            0
        )
    end

    row.valueDropdown:ClearAllPoints()
    row.valueDropdown:SetPoint(
        "TOPLEFT",
        row.fieldDropdown,
        "BOTTOMLEFT",
        0,
        -SECTION_GAP
    )

    row.scalarValueEdit:ClearAllPoints()
    row.scalarValueEdit:SetPoint(
        "TOPLEFT",
        row.fieldDropdown,
        "BOTTOMLEFT",
        0,
        -SECTION_GAP
    )

    local previousInput
    for _, control in ipairs(row.textValueControls) do
        control.input:ClearAllPoints()
        if previousInput then
            control.input:SetPoint(
                "TOPLEFT",
                previousInput,
                "BOTTOMLEFT",
                0,
                -SECTION_GAP
            )
        else
            control.input:SetPoint(
                "TOPLEFT",
                row.fieldDropdown,
                "BOTTOMLEFT",
                0,
                -SECTION_GAP
            )
        end

        control.removeButton:ClearAllPoints()
        control.removeButton:SetPoint(
            "LEFT",
            control.input,
            "RIGHT",
            CONTROL_GAP,
            0
        )
        previousInput = control.input
    end

    row.addTextValueButton:ClearAllPoints()
    local firstTextControl = row.textValueControls[1]
    local lastTextControl = row.textValueControls[textValueCount]

    if textValueCount > 1 and lastTextControl then
        row.addTextValueButton:SetPoint(
            "LEFT",
            lastTextControl.removeButton,
            "RIGHT",
            CONTROL_GAP,
            0
        )
    elseif firstTextControl then
        row.addTextValueButton:SetPoint(
            "LEFT",
            firstTextControl.input,
            "RIGHT",
            CONTROL_GAP,
            0
        )
    end

    row.removeButton:ClearAllPoints()
    if isTextValueRule and firstTextControl then
        local firstTextAction = textValueCount > 1
            and firstTextControl.removeButton
            or row.addTextValueButton

        row.removeButton:SetPoint(
            "LEFT",
            firstTextAction,
            "RIGHT",
            CONTROL_GAP,
            0
        )
    elseif hasValueRow then
        row.removeButton:SetPoint(
            "RIGHT",
            row,
            "BOTTOMRIGHT",
            -ROW_INSET,
            ROW_INSET + (CONTROL_HEIGHT / 2)
        )
    else
        row.removeButton:SetPoint(
            "RIGHT",
            row,
            "RIGHT",
            -ROW_INSET,
            0
        )
    end
end

local function CreateTextValueControl(row)
    local control = {}

    control.input = ModernSettings:CreateTextInput(row, {
        onCommit = function(value)
            if not row.owner
                or not row.categoryID
                or not row.ruleID
                or not control.valueIndex then
                return nil, Categories.ErrorCodes.MissingRule
            end

            return row.owner:CommitRuleTextValue(
                row.categoryID,
                row.ruleID,
                control.valueIndex,
                value
            )
        end,
        onError = function(errorCode)
            ReportRuleError("Updating rule value", errorCode)
        end,
    })
    control.removeButton = ModernSettings:CreateButton(row, {
        variant = "square",
        width = TEXT_ACTION_SIZE,
        iconAtlas = Media.GetRemoveAtlas(),
        tooltip = "Remove this text match.",
        onClick = function()
            if row.owner
                and row.categoryID
                and row.ruleID
                and control.valueIndex then
                row.owner:RemoveRuleTextValue(
                    row.categoryID,
                    row.ruleID,
                    control.valueIndex
                )
            end
        end,
    })
    UseVirtualizedRowClickTiming(control.removeButton)
    control.input:Hide()
    control.removeButton:Hide()
    row.textValueControls[#row.textValueControls + 1] = control
    return control
end

local function EnsureTextValueControls(row, count)
    while #row.textValueControls < count do
        CreateTextValueControl(row)
    end
end

local function InitializeRuleRow(row)
    -- ScrollBox calls the element initializer again when it reacquires a row.
    if row.ruleRowInitialized then
        return
    end

    row.ruleRowInitialized = true

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    row.stripe:SetColorTexture(1, 1, 1, 0.035)
    row.stripe:Hide()

    row.handle = CreateFrame("Button", nil, row)
    row.handle:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.handle:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.handle:SetWidth(HANDLE_WIDTH)

    local moverR, moverG, moverB = Media.GetMoverColor()

    row.handle.icon = row.handle:CreateTexture(nil, "ARTWORK")
    row.handle.icon:SetTexture(Media.GetMoverTexture())
    row.handle.icon:SetSize(MOVER_ICON_SIZE, MOVER_ICON_SIZE)
    row.handle.icon:SetPoint("CENTER")
    row.handle.icon:SetVertexColor(moverR, moverG, moverB)

    row.handle.hoverIcon = row.handle:CreateTexture(nil, "OVERLAY")
    row.handle.hoverIcon:SetTexture(Media.GetMoverTexture())
    row.handle.hoverIcon:SetSize(MOVER_ICON_SIZE, MOVER_ICON_SIZE)
    row.handle.hoverIcon:SetPoint("CENTER")
    row.handle.hoverIcon:SetVertexColor(moverR, moverG, moverB)
    row.handle.hoverIcon:SetBlendMode("ADD")
    row.handle.hoverIcon:SetAlpha(0.4)
    row.handle.hoverIcon:Hide()

    ModernSettings:SetTooltip(row.handle, {
        title = "Reorder Rule",
        text = "Drag to move this rule within the category.",
    })

    row.handle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:GetParent().owner:StartRuleDrag(self:GetParent())
        end
    end)
    row.handle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:GetParent().owner:FinishRuleDrag()
        end
    end)
    row.handle:HookScript("OnEnter", function(self)
        self.hoverIcon:Show()
    end)
    row.handle:HookScript("OnLeave", function(self)
        self.hoverIcon:Hide()
    end)

    row.fieldDropdown = ModernSettings:CreateDropdown(row, {
        label = "Field",
        showLabel = false,
        leftInset = DROPDOWN_EDGE_INSET,
        rightInset = 0,
        choices = Rules.GetFieldChoices(),
        onChanged = function(fieldID)
            if row.owner and row.categoryID and row.ruleID then
                row.owner:UpdateRuleField(
                    row.categoryID,
                    row.ruleID,
                    fieldID
                )
            end
        end,
    })

    row.operatorDropdown = ModernSettings:CreateDropdown(row, {
        label = "Operator",
        showLabel = false,
        leftInset = 0,
        rightInset = DROPDOWN_EDGE_INSET,
        choices = {},
        onChanged = function(operatorID)
            if row.owner and row.categoryID and row.ruleID then
                row.owner:UpdateRuleOperator(
                    row.categoryID,
                    row.ruleID,
                    operatorID
                )
            end
        end,
    })

    row.valueDropdown = ModernSettings:CreateDropdown(row, {
        label = "Value",
        showLabel = false,
        leftInset = DROPDOWN_EDGE_INSET,
        rightInset = DROPDOWN_EDGE_INSET,
        choices = {},
        onChanged = function(value)
            if row.owner and row.categoryID and row.ruleID then
                row.owner:UpdateRuleValue(
                    row.categoryID,
                    row.ruleID,
                    value
                )
            end
        end,
    })

    row.scalarValueEdit = ModernSettings:CreateTextInput(row, {
        onCommit = function(value)
            if not row.owner or not row.categoryID or not row.ruleID then
                return nil, Categories.ErrorCodes.MissingRule
            end

            return row.owner:CommitRuleScalarValue(
                row.categoryID,
                row.ruleID,
                value
            )
        end,
        onError = function(errorCode)
            ReportRuleError("Updating rule value", errorCode)
        end,
    })

    row.textValueControls = {}
    row.addTextValueButton = ModernSettings:CreateButton(row, {
        variant = "square",
        width = TEXT_ACTION_SIZE,
        iconAtlas = Media.GetAddAtlas(),
        tooltip = "Add another text alternative. Positive operators match any "
            .. "alternative; negative operators require none to match.",
        onClick = function()
            if row.owner and row.categoryID and row.ruleID then
                row.owner:AddRuleTextValue(row.categoryID, row.ruleID)
            end
        end,
    })
    UseVirtualizedRowClickTiming(row.addTextValueButton)
    row.addTextValueButton:Hide()

    row.booleanIsText = ModernSettings:CreateText(row, {
        fontObject = GameFontHighlight,
        text = "is",
        width = BOOLEAN_IS_WIDTH,
    })
    row.booleanIsText:SetJustifyH("CENTER")
    row.booleanIsText:Hide()

    row.removeButton = ModernSettings:CreateButton(row, {
        text = "Remove",
        variant = "small",
        width = REMOVE_WIDTH,
        tooltip = "Remove this rule from the category.",
        onClick = function()
            if row.owner and row.categoryID and row.ruleID then
                row.owner:RemoveRule(row.categoryID, row.ruleID)
            end
        end,
    })

    row:SetScript("OnSizeChanged", LayoutRuleRow)
    LayoutRuleRow(row)
end

local function ShowRuleValueControl(row, rule)
    local fieldID = rule.field
    local valueKind = Rules.GetFieldValueKind(fieldID)
    local needsValue = Rules.OperatorNeedsValue(rule.operator)

    row.valueDropdown:Hide()
    row.scalarValueEdit:Hide()
    row.addTextValueButton:Hide()
    row.textValueCount = nil
    for _, control in ipairs(row.textValueControls) do
        control.valueIndex = nil
        control.input:Hide()
        control.removeButton:Hide()
    end
    row.booleanIsText:SetShown(row.isBoolean)

    if fieldID
        and rule.operator
        and needsValue
        and (valueKind == Rules.ValueKinds.Enum
            or valueKind == Rules.ValueKinds.OrderedEnum) then
        row.valueDropdown:SetChoices(row.owner:GetValueChoices(fieldID))
        row.valueDropdown:SetValue(rule.value)
        row.valueDropdown:Show()
    elseif fieldID
        and rule.operator
        and needsValue
        and valueKind == Rules.ValueKinds.Text then
        local values = Rules.GetRuleTextValues(rule)
        if #values == 0 then
            values[1] = ""
        end

        EnsureTextValueControls(row, #values)
        row.textValueCount = #values
        local hasMultipleValues = #values > 1

        for valueIndex, value in ipairs(values) do
            local control = row.textValueControls[valueIndex]

            control.valueIndex = valueIndex
            control.input:SetValue(value)
            control.input:Show()
            control.removeButton:SetShown(hasMultipleValues)
        end
        row.addTextValueButton:Show()
    elseif fieldID and rule.operator and needsValue then
        row.scalarValueEdit:SetValue(Rules.GetRuleValueText(rule))
        row.scalarValueEdit:Show()
    end
end

local function GetValueChoices(editor, fieldID)
    if not editor.valueChoiceCache[fieldID] then
        editor.valueChoiceCache[fieldID] = Rules.GetValueChoices(fieldID)
    end

    return editor.valueChoiceCache[fieldID]
end

local function RenderRuleRow(row, rule, editor)
    row.owner = editor
    row.hasValueRow = RuleUsesValueRow(rule)
    row.isBoolean = IsBooleanRule(rule)
    row.isTextValueRule = IsTextValueRule(rule)
    InitializeRuleRow(row)
    row.ruleID = rule.id
    row.ruleIndex = rule.index
    row.categoryID = editor.categoryID
    row.stripe:SetShown(rule.index % 2 == 0)
    row.handle.hoverIcon:Hide()
    row.fieldDropdown:SetValue(rule.field)
    row.operatorDropdown:SetChoices(
        Rules.GetOperatorChoices(rule.field)
    )
    row.operatorDropdown:SetValue(rule.operator)
    row.operatorDropdown:SetControlEnabled(rule.field ~= nil)
    ShowRuleValueControl(row, rule)
    LayoutRuleRow(row)

    if editor.pendingTextValueIndex
        and editor.pendingTextValueCategoryID == row.categoryID
        and editor.pendingTextValueRuleID == row.ruleID then
        local control = row.textValueControls[
            editor.pendingTextValueIndex
        ]

        if control then
            editor.pendingTextValueCategoryID = nil
            editor.pendingTextValueRuleID = nil
            editor.pendingTextValueIndex = nil
            control.input:FocusValue()
        end
    end
end

local function ResetRuleRow(row)
    if row.scalarValueEdit:HasFocus() then
        if row.owner and not row.owner.cancelFocusedValueOnReset then
            row.scalarValueEdit:CommitAndClearFocus()
        else
            row.scalarValueEdit:CancelAndClearFocus()
        end
    end

    for _, control in ipairs(row.textValueControls) do
        if control.input:HasFocus() then
            if row.owner and not row.owner.cancelFocusedValueOnReset then
                control.input:CommitAndClearFocus()
            else
                control.input:CancelAndClearFocus()
            end
        end
    end

    row.owner = nil
    row.ruleID = nil
    row.ruleIndex = nil
    row.categoryID = nil
    row.hasValueRow = nil
    row.isBoolean = nil
    row.isTextValueRule = nil
    row.textValueCount = nil
    row.stripe:Hide()
    row.handle.hoverIcon:Hide()
    row.fieldDropdown:SetValue(nil)
    row.operatorDropdown:SetChoices({})
    row.operatorDropdown:SetValue(nil)
    row.valueDropdown:SetChoices({})
    row.valueDropdown:SetValue(nil)
    row.scalarValueEdit:SetValue("")
    row.valueDropdown:Hide()
    row.scalarValueEdit:Hide()
    row.addTextValueButton:Hide()
    for _, control in ipairs(row.textValueControls) do
        control.valueIndex = nil
        control.input:SetValue("")
        control.input:Hide()
        control.removeButton:Hide()
    end
    row.booleanIsText:Hide()
end

local function CreateRuleListView(editor)
    local view = CreateScrollBoxListLinearView()

    view:SetElementExtentCalculator(function(_, rule)
        return GetRuleRowHeight(rule)
    end)
    view:SetElementFactory(function(factory)
        factory("Frame", function(row, rule)
            RenderRuleRow(row, rule, editor)
        end)
    end)
    view:SetElementResetter(ResetRuleRow)

    return view
end

-- Transactional mutations and detached-snapshot refresh
local function PerformMutation(editor, action, mutation)
    editor.categoryEditor:CommitCategoryNameEdit()
    editor.categoryEditor:CancelScheduledRefresh()
    editor.categoryEditor.suppressCategoryRefresh = true

    local succeeded, result, errorCode = pcall(mutation)

    editor.categoryEditor.suppressCategoryRefresh = nil
    if not succeeded then
        error(result, 0)
    end

    if result == nil or result == false then
        ReportRuleError(action, errorCode)
        return nil, errorCode
    end

    editor:ScheduleRefresh()
    return result
end

local function ScheduleRefresh(editor)
    if editor.refreshTimer then
        editor.refreshTimer:Cancel()
    end

    editor.refreshTimer = C_Timer.NewTimer(0, function()
        editor.refreshTimer = nil
        if editor.categoryEditor:IsShown() then
            editor.categoryEditor:RefreshCategories(true)
        end
    end)
end

local function SetDefinition(editor, definition)
    editor:CancelRuleDrag()
    editor.definition = definition
    editor.categoryID = definition and definition.id or nil

    if editor.pendingTextValueCategoryID
        and editor.pendingTextValueCategoryID ~= editor.categoryID then
        editor.pendingTextValueCategoryID = nil
        editor.pendingTextValueRuleID = nil
        editor.pendingTextValueIndex = nil
        editor.pendingTextValueScrollOffset = nil
    end

    local pendingTextValueScrollOffset =
        editor.pendingTextValueScrollOffset

    local isOther = editor.categoryID == OTHER_CATEGORY_ID
    local hasDefinition = definition ~= nil
    local hasRuleSet = hasDefinition and not isOther

    editor.addButton:SetShown(hasRuleSet)
    editor.matchLabel:SetShown(hasRuleSet)
    editor.modeDropdown:SetShown(hasRuleSet)
    editor.scrollBox:SetShown(hasRuleSet)
    editor.scrollBar:SetShown(hasRuleSet)
    editor.fallbackText:SetShown(not hasDefinition or isOther)

    if not hasDefinition then
        editor.fallbackText:SetText("Select a category to edit its rules.")
    elseif isOther then
        editor.fallbackText:SetText(
            "Other is the unconditional fallback. It receives every item "
                .. "that does not match an earlier category and therefore "
                .. "does not have a Rule Set."
        )
    else
        editor.modeDropdown:SetValue(definition.rules.mode)
    end

    local entries = {}
    if hasDefinition and not isOther then
        for index, rule in ipairs(definition.rules.entries) do
            entries[index] = CopyTable(rule)
            entries[index].index = index
        end
    end

    local dataProvider = CreateDataProvider(entries)
    editor.cancelFocusedValueOnReset = true
    editor.scrollBox:SetDataProvider(
        dataProvider,
        ScrollBoxConstants.RetainScrollPosition
    )
    editor.cancelFocusedValueOnReset = nil
    editor.dataProvider = dataProvider
    editor.emptyText:SetShown(hasDefinition and not isOther and #entries == 0)

    if pendingTextValueScrollOffset then
        editor.pendingTextValueScrollOffset = nil
        editor.scrollBox:ScrollToOffset(
            pendingTextValueScrollOffset,
            ScrollBoxConstants.NoScrollInterpolation
        )
    end

    if editor.pendingRuleID
        and editor.pendingRuleCategoryID == editor.categoryID then
        for index, rule in ipairs(entries) do
            if rule.id == editor.pendingRuleID then
                editor.scrollBox:ScrollToElementDataIndex(
                    index,
                    ScrollBoxConstants.AlignCenter
                )
                editor.pendingRuleID = nil
                editor.pendingRuleCategoryID = nil
                break
            end
        end
    elseif editor.pendingRuleID then
        editor.pendingRuleID = nil
        editor.pendingRuleCategoryID = nil
    end
end

local function CommitFocusedValue(editor)
    local committed = true
    editor.scrollBox:ForEachFrame(function(row)
        if row.scalarValueEdit:HasFocus() then
            local rowCommitted = row.scalarValueEdit:CommitAndClearFocus()
            if not rowCommitted then
                committed = false
            end
        end

        for _, control in ipairs(row.textValueControls) do
            if control.input:HasFocus() then
                local rowCommitted = control.input:CommitAndClearFocus()
                if not rowCommitted then
                    committed = false
                end
            end
        end
    end)
    return committed
end

local function ChangeMode(editor, mode)
    return PerformMutation(editor, "Changing Rule Set mode", function()
        return Categories.SetRuleMode(editor.categoryID, mode)
    end)
end

local function AddRule(editor)
    local ruleID = PerformMutation(editor, "Adding rule", function()
        return Categories.CreateRule(editor.categoryID)
    end)

    if ruleID then
        editor.pendingRuleID = ruleID
        editor.pendingRuleCategoryID = editor.categoryID
    end
end

local function UpdateRuleField(editor, categoryID, ruleID, fieldID)
    return PerformMutation(editor, "Updating rule field", function()
        return Categories.UpdateRuleField(
            categoryID,
            ruleID,
            fieldID
        )
    end)
end

local function UpdateRuleOperator(editor, categoryID, ruleID, operatorID)
    return PerformMutation(editor, "Updating rule operator", function()
        return Categories.UpdateRuleOperator(
            categoryID,
            ruleID,
            operatorID
        )
    end)
end

local function UpdateRuleValue(editor, categoryID, ruleID, value)
    return PerformMutation(editor, "Updating rule value", function()
        return Categories.UpdateRuleValue(
            categoryID,
            ruleID,
            value
        )
    end)
end

local function CommitRuleScalarValue(editor, categoryID, ruleID, value)
    local updated, errorCode = UpdateRuleValue(
        editor,
        categoryID,
        ruleID,
        value
    )
    if updated == nil then
        return nil, errorCode
    end

    return tostring(updated)
end

local function CommitRuleTextValue(
    editor,
    categoryID,
    ruleID,
    valueIndex,
    value
)
    local updated, errorCode = PerformMutation(
        editor,
        "Updating rule value",
        function()
            return Categories.UpdateRuleTextValue(
                categoryID,
                ruleID,
                valueIndex,
                value
            )
        end
    )
    if updated == nil then
        return nil, errorCode
    end

    return updated
end

local function AddRuleTextValue(editor, categoryID, ruleID)
    if not editor:CommitFocusedValue() then
        return
    end

    local scrollOffset = editor.scrollBox:GetDerivedScrollOffset()

    local valueIndex = PerformMutation(
        editor,
        "Adding text match",
        function()
            return Categories.AddRuleTextValue(categoryID, ruleID)
        end
    )
    if valueIndex then
        editor.pendingTextValueCategoryID = categoryID
        editor.pendingTextValueRuleID = ruleID
        editor.pendingTextValueIndex = valueIndex
        editor.pendingTextValueScrollOffset =
            scrollOffset + TEXT_VALUE_ROW_STEP
    end
end

local function RemoveRuleTextValue(
    editor,
    categoryID,
    ruleID,
    valueIndex
)
    if not editor:CommitFocusedValue() then
        return
    end

    return PerformMutation(editor, "Removing text match", function()
        return Categories.RemoveRuleTextValue(
            categoryID,
            ruleID,
            valueIndex
        )
    end)
end

local function RemoveRule(editor, categoryID, ruleID)
    return PerformMutation(editor, "Removing rule", function()
        return Categories.RemoveRule(categoryID, ruleID)
    end)
end

local function CancelPendingRefresh(editor)
    if editor.refreshTimer then
        editor.refreshTimer:Cancel()
        editor.refreshTimer = nil
    end
end

-- Active-only drag polling and insertion geometry
local function CancelRuleDrag(editor)
    editor.draggedRuleID = nil
    editor.draggedRuleCategoryID = nil
    editor.dragInsertionPosition = nil
    editor.insertionIndicator:Hide()
    editor:SetScript("OnUpdate", nil)
end

local function UpdateRuleDrag(editor)
    if not editor.draggedRuleID then
        CancelRuleDrag(editor)
        return
    end

    if not IsMouseButtonDown("LeftButton") then
        editor:FinishRuleDrag()
        return
    end

    local _, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()

    cursorY = cursorY / scale

    local nearestRow
    local nearestDistance
    local insertBefore

    editor.scrollBox:ForEachFrame(function(row)
        if not row.ruleID then
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

    editor.dragInsertionPosition = nearestRow.ruleIndex
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

local function StartRuleDrag(editor, row)
    if not row.ruleID or row.categoryID ~= editor.categoryID then
        return
    end

    editor.categoryEditor:CommitCategoryNameEdit()
    editor:CommitFocusedValue()
    editor:CancelPendingRefresh()
    editor.categoryEditor:CancelScheduledRefresh()
    editor.categoryEditor:CancelCategoryDrag()
    editor.draggedRuleID = row.ruleID
    editor.draggedRuleCategoryID = row.categoryID
    editor.dragInsertionPosition = row.ruleIndex
    editor:SetScript("OnUpdate", UpdateRuleDrag)
    UpdateRuleDrag(editor)
end

local function FinishRuleDrag(editor)
    local ruleID = editor.draggedRuleID
    local categoryID = editor.draggedRuleCategoryID
    local insertionPosition = editor.dragInsertionPosition
    local ruleSet = editor.definition and editor.definition.rules
    local _, currentIndex = Rules.FindRule(ruleSet, ruleID)
    local ruleCount = ruleSet and #ruleSet.entries or 0

    CancelRuleDrag(editor)

    if not ruleID
        or categoryID ~= editor.categoryID
        or not insertionPosition
        or not currentIndex then
        return
    end

    local targetIndex = insertionPosition

    if insertionPosition > currentIndex then
        targetIndex = insertionPosition - 1
    end

    targetIndex = math.max(1, math.min(ruleCount, targetIndex))

    if targetIndex == currentIndex then
        return
    end

    PerformMutation(editor, "Moving rule", function()
        return Categories.MoveRule(categoryID, ruleID, targetIndex)
    end)
end

-- Editor construction
local function CreateHeader(editor)
    local header = CreateFrame("Frame", nil, editor)

    header:SetPoint("TOPLEFT", editor, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", editor, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_HEIGHT)

    local title = ModernSettings:CreateText(header, {
        fontObject = GameFontNormal,
        text = "Rules",
    })
    title:SetPoint("LEFT", header, "LEFT", 0, 0)

    local matchLabel = ModernSettings:CreateText(header, {
        fontObject = GameFontHighlight,
        text = "Match",
    })
    matchLabel:SetPoint(
        "LEFT",
        title,
        "RIGHT",
        HEADER_CONTROL_GAP * 2,
        0
    )

    local modeDropdown = ModernSettings:CreateDropdown(header, {
        label = "Match",
        showLabel = false,
        leftInset = DROPDOWN_EDGE_INSET,
        rightInset = DROPDOWN_EDGE_INSET,
        width = MODE_DROPDOWN_WIDTH,
        choices = Rules.GetModeChoices(),
        tooltip = "Require all rules or any one rule to match.",
        onChanged = function(mode)
            editor:ChangeMode(mode)
        end,
    })
    modeDropdown:SetPoint(
        "LEFT",
        matchLabel,
        "RIGHT",
        HEADER_CONTROL_GAP,
        0
    )

    local addButton = ModernSettings:CreateButton(header, {
        text = "Add Rule",
        iconAtlas = Media.GetAddAtlas(),
        fitToContent = true,
        tooltip = "Add a rule. Incomplete rules are ignored until configured.",
        onClick = function()
            editor:AddRule()
        end,
    })
    addButton:SetPoint("RIGHT", header, "RIGHT", 0, 0)

    editor.header = header
    editor.matchLabel = matchLabel
    editor.modeDropdown = modeDropdown
    editor.addButton = addButton
end

local function CreateRuleList(editor)
    local scrollBox = CreateFrame(
        "Frame",
        nil,
        editor,
        "WowScrollBoxList"
    )

    scrollBox:SetPoint(
        "TOPLEFT",
        editor.header,
        "BOTTOMLEFT",
        0,
        -SECTION_GAP
    )
    scrollBox:SetPoint(
        "BOTTOMRIGHT",
        editor,
        "BOTTOMRIGHT",
        -(SCROLLBAR_GAP + SCROLLBAR_WIDTH),
        0
    )
    scrollBox:SetClipsChildren(true)

    local scrollBar = CreateFrame(
        "EventFrame",
        nil,
        editor,
        "MinimalScrollBar"
    )

    scrollBar:SetWidth(SCROLLBAR_WIDTH)
    scrollBar:SetPoint(
        "TOPLEFT",
        scrollBox,
        "TOPRIGHT",
        SCROLLBAR_GAP,
        0
    )
    scrollBar:SetPoint(
        "BOTTOMLEFT",
        scrollBox,
        "BOTTOMRIGHT",
        SCROLLBAR_GAP,
        0
    )

    local view = CreateRuleListView(editor)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    editor.scrollBox = scrollBox
    editor.scrollBar = scrollBar
    editor.listView = view

    local indicator = editor:CreateTexture(nil, "OVERLAY")
    local accentR, accentG, accentB = Media.GetAccentColor()

    indicator:SetHeight(2)
    indicator:SetColorTexture(accentR, accentG, accentB, 1)
    indicator:Hide()
    editor.insertionIndicator = indicator

    local emptyText = ModernSettings:CreateText(scrollBox, {
        fontObject = GameFontDisable,
        text = "No rules. This category will remain empty.",
    })
    emptyText:SetPoint("TOPLEFT", scrollBox, "TOPLEFT", 12, -18)
    emptyText:SetPoint("TOPRIGHT", scrollBox, "TOPRIGHT", -12, -18)
    emptyText:SetJustifyH("LEFT")
    editor.emptyText = emptyText
end

local function CreateFallbackText(editor)
    local fallbackText = ModernSettings:CreateText(editor, {
        fontObject = GameFontHighlight,
        text = "",
    })

    fallbackText:SetPoint(
        "TOPLEFT",
        editor.header,
        "BOTTOMLEFT",
        0,
        -SECTION_GAP
    )
    fallbackText:SetPoint(
        "TOPRIGHT",
        editor.header,
        "BOTTOMRIGHT",
        0,
        -SECTION_GAP
    )
    fallbackText:SetJustifyH("LEFT")
    fallbackText:SetJustifyV("TOP")
    editor.fallbackText = fallbackText
end

function CategoryRuleEditor.Create(parent, categoryEditor)
    local editor = CreateFrame("Frame", nil, parent)

    editor:SetAllPoints(parent)
    editor.categoryEditor = categoryEditor
    editor.valueChoiceCache = {}
    editor.ScheduleRefresh = ScheduleRefresh
    editor.SetDefinition = SetDefinition
    editor.CommitFocusedValue = CommitFocusedValue
    editor.GetValueChoices = GetValueChoices
    editor.ChangeMode = ChangeMode
    editor.AddRule = AddRule
    editor.UpdateRuleField = UpdateRuleField
    editor.UpdateRuleOperator = UpdateRuleOperator
    editor.UpdateRuleValue = UpdateRuleValue
    editor.CommitRuleScalarValue = CommitRuleScalarValue
    editor.CommitRuleTextValue = CommitRuleTextValue
    editor.AddRuleTextValue = AddRuleTextValue
    editor.RemoveRuleTextValue = RemoveRuleTextValue
    editor.RemoveRule = RemoveRule
    editor.CancelPendingRefresh = CancelPendingRefresh
    editor.CancelRuleDrag = CancelRuleDrag
    editor.StartRuleDrag = StartRuleDrag
    editor.FinishRuleDrag = FinishRuleDrag

    CreateHeader(editor)
    CreateRuleList(editor)
    CreateFallbackText(editor)
    editor:SetDefinition(nil)

    return editor
end
