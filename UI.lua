-- ============================================================================
-- ForeverGrudges - UI.lua
-- Client: World of Warcraft: Forever 1.60.1.70862 (Interface 16001)
-- Lazy-Loaded, Zero-Allocation Scroll & Bilingual UI (EN / ES)
-- ============================================================================

local addonName, ns = ...

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local strformat, strlower, strupper, strfind, strmatch, strsub =
    string.format, string.lower, string.upper, string.find, string.match, string.sub
local mfloor, mmax, mrad, mdeg, mcos, msin, matan2 =
    math.floor, math.max, math.rad, math.deg, math.cos, math.sin, math.atan2
local tsort = table.sort
local wipe = wipe or table.wipe

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local PANEL_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local EDITBOX_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- Lazy-instantiated UI frame references
local targetIndicator
local quickModal
local listFrame
local minimapButton

-- ============================================================================
-- 1. Target Portrait Indicator (Lazy-Created Only When Needed)
-- ============================================================================

local function CreateTargetIndicator()
    if targetIndicator then
        return
    end

    -- Parented to UIParent (not TargetFrame) to avoid tainting Blizzard's SecureUnitButton
    targetIndicator = CreateFrame("Button", "ForeverGrudgesTargetIndicator", UIParent, BACKDROP_TEMPLATE)
    targetIndicator:SetSize(190, 26)
    if TargetFrame then
        targetIndicator:SetPoint("BOTTOM", TargetFrame, "TOP", -10, -4)
    else
        targetIndicator:SetPoint("TOP", UIParent, "TOP", -200, -20)
    end
    targetIndicator:SetFrameStrata("MEDIUM")
    targetIndicator:SetFrameLevel(20)
    targetIndicator:SetBackdrop(PANEL_BACKDROP)
    targetIndicator:SetBackdropColor(0.15, 0.02, 0.02, 0.92)
    targetIndicator:SetBackdropBorderColor(0.85, 0.15, 0.15, 1.0)
    targetIndicator:EnableMouse(true)
    targetIndicator:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Left Book icon
    local bookIcon = targetIndicator:CreateTexture(nil, "ARTWORK")
    bookIcon:SetSize(18, 18)
    bookIcon:SetPoint("LEFT", targetIndicator, "LEFT", 6, 0)
    bookIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    targetIndicator.bookIcon = bookIcon

    -- Main text: [GRUDGE: <TAG>]
    local label = targetIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", bookIcon, "RIGHT", 4, 0)
    label:SetPoint("RIGHT", targetIndicator, "RIGHT", -6, 0)
    label:SetJustifyH("CENTER")
    targetIndicator.label = label

    -- Tooltip on mouseover
    targetIndicator:SetScript("OnEnter", function(self)
        if not self.grudgeData or not self.playerName then
            return
        end
        local entry = self.grudgeData
        local tagInfo = ns:GetTagInfo(entry.tagId or entry.tag)

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(ns:L("INDICATOR_TT_TITLE"), 1.0, 0.82, 0.0)
        GameTooltip:AddDoubleLine(ns:L("INDICATOR_TT_PLAYER"), ns:FormatPlayerName(self.playerName, entry.class), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(ns:L("INDICATOR_TT_TAG"), tagInfo.label, 0.8, 0.8, 0.8, tagInfo.color.r, tagInfo.color.g, tagInfo.color.b)
        if tagInfo.desc and tagInfo.desc ~= "" then
            GameTooltip:AddLine(tagInfo.desc, 0.9, 0.82, 0.6, true)
        end
        GameTooltip:AddDoubleLine(ns:L("INDICATOR_TT_DATE"), entry.date or ns:L("UNKNOWN_DATE"), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns:L("INDICATOR_TT_NOTE_HEADER"), 1.0, 0.82, 0.0)
        GameTooltip:AddLine(entry.note or ns:L("NO_NOTE"), 1.0, 1.0, 1.0, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns:L("INDICATOR_TT_LCLICK"))
        GameTooltip:Show()
    end)

    targetIndicator:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    targetIndicator:SetScript("OnClick", function(self)
        if not self.playerName then
            return
        end
        ns:OpenQuickModal(self.playerName, self.grudgeData and self.grudgeData.class)
    end)

    targetIndicator:Hide()
end

--- Fast-hide helper that avoids creating the frame if it was never shown.
function ns:HideTargetIndicator()
    if targetIndicator and targetIndicator:IsShown() then
        targetIndicator.grudgeData = nil
        targetIndicator.playerName = nil
        targetIndicator:Hide()
    end
end

--- Updates the visibility and text of the TargetFrame indicator.
function ns:UpdateTargetIndicator(preloadedEntry, preloadedNormName)
    local entry, normName = preloadedEntry, preloadedNormName

    if not entry then
        if not UnitExists("target") or not UnitIsPlayer("target") then
            self:HideTargetIndicator()
            return
        end
        local targetName = self:GetSafeUnitName("target")
        entry, normName = self:GetGrudge(targetName)
        if not entry then
            self:HideTargetIndicator()
            return
        end
    end

    if not targetIndicator then
        CreateTargetIndicator()
    end

    local tagInfo = self:GetTagInfo(entry.tagId or entry.tag)
    targetIndicator.grudgeData = entry
    targetIndicator.playerName = normName

    local text = strformat(self:L("INDICATOR_LABEL_FMT"), tagInfo.hex, strupper(tagInfo.label))
    targetIndicator.label:SetText(text)

    local textWidth = targetIndicator.label:GetStringWidth() or 120
    targetIndicator:SetWidth(mmax(155, textWidth + 38))
    targetIndicator:SetBackdropBorderColor(tagInfo.color.r, tagInfo.color.g, tagInfo.color.b, 1.0)
    targetIndicator:Show()
end

-- ============================================================================
-- 2. Quick Registration Modal Window (Lazy-Created on First Open)
-- ============================================================================

local function CreateQuickModal()
    if quickModal then
        return
    end

    quickModal = CreateFrame("Frame", "ForeverGrudgesQuickModal", UIParent, BACKDROP_TEMPLATE)
    quickModal:SetSize(370, 385)
    quickModal:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    quickModal:SetFrameStrata("DIALOG")
    quickModal:SetBackdrop(DIALOG_BACKDROP)
    quickModal:SetBackdropColor(0.08, 0.06, 0.05, 0.96)
    quickModal:EnableMouse(true)
    quickModal:SetMovable(true)
    quickModal:RegisterForDrag("LeftButton")
    quickModal:SetScript("OnDragStart", quickModal.StartMoving)
    quickModal:SetScript("OnDragStop", quickModal.StopMovingOrSizing)
    quickModal:Hide()

    -- Header / Title
    local headerTex = quickModal:CreateTexture(nil, "ARTWORK")
    headerTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    headerTex:SetSize(320, 64)
    headerTex:SetPoint("TOP", quickModal, "TOP", 0, 12)

    local title = quickModal:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", headerTex, "TOP", 0, -14)
    title:SetText(ns:L("MODAL_TITLE"))
    quickModal.title = title

    local closeBtn = CreateFrame("Button", nil, quickModal, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", quickModal, "TOPRIGHT", -5, -5)

    -- Field: Player Name
    local nameLabel = quickModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", quickModal, "TOPLEFT", 24, -36)
    nameLabel:SetText(ns:L("MODAL_NAME_LABEL"))
    quickModal.nameLabel = nameLabel

    local nameEdit = CreateFrame("EditBox", "ForeverGrudgesQuickNameEdit", quickModal, BACKDROP_TEMPLATE)
    nameEdit:SetSize(322, 24)
    nameEdit:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameEdit:SetFontObject(ChatFontNormal)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(40)
    nameEdit:SetBackdrop(EDITBOX_BACKDROP)
    nameEdit:SetBackdropColor(0.0, 0.0, 0.0, 0.75)
    nameEdit:SetBackdropBorderColor(0.5, 0.5, 0.5, 1.0)
    nameEdit:SetTextInsets(6, 6, 0, 0)
    nameEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        quickModal:Hide()
    end)
    nameEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    quickModal.nameEdit = nameEdit

    -- Quick Selector for the 6 Predefined Tags
    local tagLabel = quickModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tagLabel:SetPoint("TOPLEFT", nameEdit, "BOTTOMLEFT", 0, -10)
    tagLabel:SetText(ns:L("MODAL_TAG_LABEL"))
    quickModal.tagLabel = tagLabel

    -- Description box for the currently selected Tag
    local tagDescBox = CreateFrame("Frame", nil, quickModal, BACKDROP_TEMPLATE)
    tagDescBox:SetSize(322, 42)
    tagDescBox:SetPoint("TOPLEFT", tagLabel, "BOTTOMLEFT", 0, -88)
    tagDescBox:SetBackdrop(PANEL_BACKDROP)
    tagDescBox:SetBackdropColor(0.04, 0.04, 0.04, 0.85)
    tagDescBox:SetBackdropBorderColor(0.45, 0.38, 0.25, 0.9)

    local tagDescText = tagDescBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tagDescText:SetPoint("TOPLEFT", tagDescBox, "TOPLEFT", 8, -6)
    tagDescText:SetPoint("BOTTOMRIGHT", tagDescBox, "BOTTOMRIGHT", -8, 6)
    tagDescText:SetJustifyH("LEFT")
    tagDescText:SetJustifyV("MIDDLE")
    tagDescText:SetTextColor(0.95, 0.88, 0.65)
    quickModal.tagDescText = tagDescText
    quickModal.tagDescBox = tagDescBox

    quickModal.selectedTagIndex = 1
    quickModal.tagButtons = {}

    local function UpdateTagSelection(selectedIndex)
        if not ForeverGrudges_DefaultTags[selectedIndex] then
            selectedIndex = 1
        end
        quickModal.selectedTagIndex = selectedIndex

        for idx, btn in ipairs(quickModal.tagButtons) do
            local t = ForeverGrudges_DefaultTags[idx]
            local locLabel, _ = ns:GetLocalizedTagStrings(t)
            btn.txt:SetText(t.hex .. locLabel .. "|r")

            if idx == selectedIndex then
                btn:SetBackdropColor(t.color.r * 0.45, t.color.g * 0.45, t.color.b * 0.45, 0.95)
                btn:SetBackdropBorderColor(t.color.r, t.color.g, t.color.b, 1.0)
                btn.check:Show()
            else
                btn:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
                btn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.8)
                btn.check:Hide()
            end
        end

        local selTag = ForeverGrudges_DefaultTags[selectedIndex]
        local _, selDesc = ns:GetLocalizedTagStrings(selTag)
        quickModal.tagDescText:SetText(selDesc)
        quickModal.tagDescBox:SetBackdropBorderColor(selTag.color.r, selTag.color.g, selTag.color.b, 0.85)
    end
    quickModal.UpdateTagSelection = UpdateTagSelection

    for i, tagInfo in ipairs(ForeverGrudges_DefaultTags) do
        local btn = CreateFrame("Button", nil, quickModal, BACKDROP_TEMPLATE)
        btn:SetSize(157, 24)
        btn:SetBackdrop(PANEL_BACKDROP)

        local col = (i - 1) % 2
        local row = mfloor((i - 1) / 2)
        btn:SetPoint("TOPLEFT", tagLabel, "BOTTOMLEFT", col * 165, -4 - (row * 27))

        local check = btn:CreateTexture(nil, "OVERLAY")
        check:SetSize(14, 14)
        check:SetPoint("LEFT", btn, "LEFT", 6, 0)
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        btn.check = check

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", btn, "LEFT", 22, 0)
        txt:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        txt:SetJustifyH("LEFT")
        local locLabel, _ = ns:GetLocalizedTagStrings(tagInfo)
        txt:SetText(tagInfo.hex .. locLabel .. "|r")
        btn.txt = txt

        btn:SetScript("OnClick", function()
            ns:PlayAddonSound("IG_MAINMENU_OPTION_CHECKBOX_ON", 856)
            UpdateTagSelection(i)
        end)

        btn:SetScript("OnEnter", function(self)
            local lbl, dsc = ns:GetLocalizedTagStrings(tagInfo)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(lbl, tagInfo.color.r, tagInfo.color.g, tagInfo.color.b)
            GameTooltip:AddLine(dsc, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        quickModal.tagButtons[i] = btn
    end

    -- Field: Custom Note
    local noteLabel = quickModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    noteLabel:SetPoint("TOPLEFT", tagDescBox, "BOTTOMLEFT", 0, -10)
    noteLabel:SetText(ns:L("MODAL_NOTE_LABEL"))
    quickModal.noteLabel = noteLabel

    local noteBg = CreateFrame("Frame", nil, quickModal, BACKDROP_TEMPLATE)
    noteBg:SetSize(322, 60)
    noteBg:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 0, -4)
    noteBg:SetBackdrop(EDITBOX_BACKDROP)
    noteBg:SetBackdropColor(0.0, 0.0, 0.0, 0.75)
    noteBg:SetBackdropBorderColor(0.5, 0.5, 0.5, 1.0)

    local noteEdit = CreateFrame("EditBox", "ForeverGrudgesQuickNoteEdit", noteBg)
    noteEdit:SetPoint("TOPLEFT", noteBg, "TOPLEFT", 6, -6)
    noteEdit:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -6, 6)
    noteEdit:SetFontObject(ChatFontNormal)
    noteEdit:SetMultiLine(true)
    noteEdit:SetAutoFocus(false)
    noteEdit:SetMaxLetters(240)
    noteEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        quickModal:Hide()
    end)
    noteEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    noteBg:EnableMouse(true)
    noteBg:SetScript("OnMouseDown", function() noteEdit:SetFocus() end)
    quickModal.noteEdit = noteEdit

    -- Button: Save
    local saveBtn = CreateFrame("Button", nil, quickModal, "UIPanelButtonTemplate")
    saveBtn:SetSize(155, 26)
    saveBtn:SetPoint("BOTTOMLEFT", quickModal, "BOTTOMLEFT", 24, 16)
    saveBtn:SetText(ns:L("MODAL_BTN_SAVE"))
    saveBtn:SetScript("OnClick", function()
        local playerName = quickModal.nameEdit:GetText()
        local noteText = quickModal.noteEdit:GetText()
        local chosenTag = ForeverGrudges_DefaultTags[quickModal.selectedTagIndex] or ForeverGrudges_DefaultTags[1]
        local ok = ns:AddGrudge(playerName, chosenTag.id, noteText, quickModal.targetClass)
        if ok then
            quickModal:Hide()
        end
    end)
    quickModal.saveBtn = saveBtn

    -- Button: Cancel
    local cancelBtn = CreateFrame("Button", nil, quickModal, "UIPanelButtonTemplate")
    cancelBtn:SetSize(120, 26)
    cancelBtn:SetPoint("BOTTOMRIGHT", quickModal, "BOTTOMRIGHT", -24, 16)
    cancelBtn:SetText(ns:L("MODAL_BTN_CANCEL"))
    cancelBtn:SetScript("OnClick", function()
        quickModal:Hide()
    end)
    quickModal.cancelBtn = cancelBtn

    UpdateTagSelection(1)
end

--- Opens the quick registration modal, pre-filling existing player data if available.
function ns:OpenQuickModal(prefillName, classToken)
    if not quickModal then
        CreateQuickModal()
    end

    local normName = self:NormalizeName(prefillName)
    quickModal.targetClass = classToken

    if normName then
        quickModal.nameEdit:SetText(normName)
        local existing = self:GetGrudge(normName)
        if existing then
            local tagInfo = self:GetTagInfo(existing.tagId or existing.tag)
            quickModal.UpdateTagSelection(tagInfo.index or 1)
            quickModal.noteEdit:SetText(existing.note or "")
            if not quickModal.targetClass then
                quickModal.targetClass = existing.class
            end
        else
            quickModal.UpdateTagSelection(1)
            quickModal.noteEdit:SetText("")
        end
    else
        quickModal.nameEdit:SetText("")
        quickModal.UpdateTagSelection(1)
        quickModal.noteEdit:SetText("")
    end

    quickModal:Show()
    if normName then
        quickModal.noteEdit:SetFocus()
    else
        quickModal.nameEdit:SetFocus()
    end
end

-- ============================================================================
-- 3. Main Window: Forever Grudges (Pooled Filter List & Zero-Alloc Scroll)
-- ============================================================================

local NUM_ROWS = 9
local ROW_HEIGHT = 36
local filteredList = {}
local entryPool = {}

local function SortByNameAsc(a, b)
    return a.name < b.name
end

--- Rebuilds and sorts `filteredList` using pooled row tables (only called when data or filter changes).
local function RebuildFilteredList()
    if not listFrame then
        return
    end

    local searchFilter = listFrame.searchBox and listFrame.searchBox:GetText() or ""
    local filter = searchFilter ~= "" and strlower(strmatch(searchFilter, "^%s*(.-)%s*$") or "") or ""

    wipe(filteredList)
    if not ForeverGrudgesDB then
        return
    end

    local count = 0
    for playerName, data in pairs(ForeverGrudgesDB) do
        if type(playerName) == "string" and strsub(playerName, 1, 1) ~= "_" and type(data) == "table" and (data.tag or data.tagId) then
            local tagInfo = ns:GetTagInfo(data.tagId or data.tag)
            local match = true
            if filter ~= "" then
                local inName = strfind(strlower(playerName), filter, 1, true)
                local inTag = strfind(strlower(tagInfo.label), filter, 1, true)
                local inNote = data.note and strfind(strlower(data.note), filter, 1, true)
                match = (inName or inTag or inNote) and true or false
            end
            if match then
                count = count + 1
                local item = entryPool[count]
                if not item then
                    item = {}
                    entryPool[count] = item
                end
                item.name = playerName
                item.tagInfo = tagInfo
                item.note = data.note or ""
                item.date = data.date or ""
                item.class = data.class
                filteredList[count] = item
            end
        end
    end

    tsort(filteredList, SortByNameAsc)
end

--- Renders visible scroll rows from `filteredList` (0 allocations, safe to call on every scroll tick).
local function RenderListScrollRows()
    if not listFrame or not listFrame:IsShown() then
        return
    end

    local total = #filteredList
    listFrame.countText:SetText(strformat(ns:L("LIST_COUNT_FMT"), total))

    FauxScrollFrame_Update(listFrame.scrollFrame, total, NUM_ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(listFrame.scrollFrame)

    if total == 0 then
        listFrame.emptyText:Show()
    else
        listFrame.emptyText:Hide()
    end

    for i = 1, NUM_ROWS do
        local row = listFrame.rows[i]
        local item = filteredList[offset + i]

        if item then
            local tagInfo = item.tagInfo
            row.playerName = item.name
            row.itemData = item

            row.nameText:SetText(ns:FormatPlayerName(item.name, item.class))
            row.tagText:SetText(strformat("%s[%s]|r", tagInfo.hex, tagInfo.label))
            row.dateText:SetText(item.date)
            row.noteText:SetText(item.note)
            row:Show()
        else
            row.playerName = nil
            row.itemData = nil
            row:Hide()
        end
    end
end

local function RebuildAndRenderList()
    if not listFrame or not listFrame:IsShown() then
        return
    end
    RebuildFilteredList()
    RenderListScrollRows()
end

local function CreateListWindow()
    if listFrame then
        return
    end

    listFrame = CreateFrame("Frame", "ForeverGrudgesMainFrame", UIParent, BACKDROP_TEMPLATE)
    listFrame:SetSize(650, 445)
    listFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    listFrame:SetFrameStrata("HIGH")
    listFrame:SetBackdrop(DIALOG_BACKDROP)
    listFrame:SetBackdropColor(0.07, 0.05, 0.04, 0.96)
    listFrame:EnableMouse(true)
    listFrame:SetMovable(true)
    listFrame:RegisterForDrag("LeftButton")
    listFrame:SetScript("OnDragStart", listFrame.StartMoving)
    listFrame:SetScript("OnDragStop", listFrame.StopMovingOrSizing)
    listFrame:Hide()

    -- Decorative header
    local headerTex = listFrame:CreateTexture(nil, "ARTWORK")
    headerTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    headerTex:SetSize(380, 64)
    headerTex:SetPoint("TOP", listFrame, "TOP", 0, 12)

    local title = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", headerTex, "TOP", 0, -14)
    title:SetText(ns:L("LIST_TITLE"))
    listFrame.title = title

    local closeBtn = CreateFrame("Button", nil, listFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -5, -5)

    -- Entry counter & Search box
    local countText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 22, -38)
    countText:SetText(strformat(ns:L("LIST_COUNT_FMT"), 0))
    listFrame.countText = countText

    local searchLabel = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -205, -38)
    searchLabel:SetText(ns:L("LIST_SEARCH_LABEL"))
    listFrame.searchLabel = searchLabel

    local searchBox = CreateFrame("EditBox", "ForeverGrudgesSearchBox", listFrame, BACKDROP_TEMPLATE)
    searchBox:SetSize(165, 22)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
    searchBox:SetFontObject(ChatFontSmall)
    searchBox:SetAutoFocus(false)
    searchBox:SetBackdrop(EDITBOX_BACKDROP)
    searchBox:SetBackdropColor(0, 0, 0, 0.75)
    searchBox:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    searchBox:SetTextInsets(6, 6, 0, 0)
    searchBox:SetScript("OnTextChanged", function()
        FauxScrollFrame_SetOffset(listFrame.scrollFrame, 0)
        RebuildAndRenderList()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        listFrame:Hide()
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    listFrame.searchBox = searchBox

    -- List background container
    local listBg = CreateFrame("Frame", nil, listFrame, BACKDROP_TEMPLATE)
    listBg:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 18, -62)
    listBg:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -38, 48)
    listBg:SetBackdrop(PANEL_BACKDROP)
    listBg:SetBackdropColor(0.03, 0.03, 0.03, 0.85)
    listBg:SetBackdropBorderColor(0.45, 0.38, 0.25, 1.0)

    local emptyText = listBg:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("CENTER", listBg, "CENTER", 0, 0)
    emptyText:SetText(ns:L("LIST_EMPTY_TEXT"))
    listFrame.emptyText = emptyText

    -- FauxScrollFrame: OnVerticalScroll only repaints visible rows without rebuilding or sorting data
    local scrollFrame = CreateFrame("ScrollFrame", "ForeverGrudgesListScrollFrame", listBg, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listBg, "TOPLEFT", 4, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -4, 6)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, RenderListScrollRows)
    end)
    listFrame.scrollFrame = scrollFrame

    -- List rows
    listFrame.rows = {}
    for i = 1, NUM_ROWS do
        local row = CreateFrame("Frame", nil, listBg, BACKDROP_TEMPLATE)
        row:SetHeight(ROW_HEIGHT - 2)
        row:SetPoint("TOPLEFT", listBg, "TOPLEFT", 8, -6 - ((i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", listBg, "RIGHT", -8, 0)
        row:SetBackdrop(PANEL_BACKDROP)
        row:SetBackdropColor(0.12, 0.10, 0.09, 0.75)
        row:SetBackdropBorderColor(0.3, 0.25, 0.2, 0.7)
        row:EnableMouse(true)

        -- Player name
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
        nameText:SetWidth(120)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        -- Colored tag label
        local tagText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tagText:SetPoint("LEFT", nameText, "RIGHT", 6, 0)
        tagText:SetWidth(145)
        tagText:SetJustifyH("LEFT")
        row.tagText = tagText

        -- Registration date
        local dateText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dateText:SetPoint("LEFT", tagText, "RIGHT", 6, 0)
        dateText:SetWidth(110)
        dateText:SetJustifyH("LEFT")
        dateText:SetTextColor(0.7, 0.7, 0.7)
        row.dateText = dateText

        -- Note preview (second line inside row)
        local noteText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noteText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 5)
        noteText:SetPoint("RIGHT", row, "RIGHT", -134, 0)
        noteText:SetJustifyH("LEFT")
        noteText:SetTextColor(0.9, 0.85, 0.7)
        row.noteText = noteText

        -- Button: Edit
        local editBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        editBtn:SetSize(58, 22)
        editBtn:SetPoint("RIGHT", row, "RIGHT", -68, 0)
        editBtn:SetText(ns:L("LIST_BTN_EDIT"))
        editBtn:SetScript("OnClick", function()
            if row.playerName then
                ns:OpenQuickModal(row.playerName, row.itemData and row.itemData.class)
            end
        end)
        row.editBtn = editBtn

        -- Button: Delete
        local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        delBtn:SetSize(58, 22)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        delBtn:SetText(ns:L("LIST_BTN_DELETE"))
        delBtn:SetScript("OnClick", function()
            if row.playerName then
                ns:RemoveGrudge(row.playerName)
            end
        end)
        row.delBtn = delBtn

        -- Row tooltip showing full tag description and custom note
        row:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(0.85, 0.7, 0.2, 1.0)
            if not self.itemData then
                return
            end
            local item = self.itemData
            local tagInfo = item.tagInfo
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(ns:FormatPlayerName(item.name, item.class))
            GameTooltip:AddDoubleLine(ns:L("INDICATOR_TT_TAG"), tagInfo.label, 0.8, 0.8, 0.8, tagInfo.color.r, tagInfo.color.g, tagInfo.color.b)
            if tagInfo.desc and tagInfo.desc ~= "" then
                GameTooltip:AddLine(tagInfo.desc, 0.9, 0.82, 0.6, true)
            end
            GameTooltip:AddDoubleLine(ns:L("INDICATOR_TT_DATE"), item.date, 0.8, 0.8, 0.8, 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns:L("INDICATOR_TT_NOTE_HEADER"), 1.0, 0.82, 0.0)
            GameTooltip:AddLine(item.note, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.3, 0.25, 0.2, 0.7)
            GameTooltip:Hide()
        end)

        listFrame.rows[i] = row
    end

    -- Bottom-left button: New Grudge
    local newBtn = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
    newBtn:SetSize(160, 26)
    newBtn:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", 18, 16)
    newBtn:SetText(ns:L("LIST_BTN_NEW"))
    newBtn:SetScript("OnClick", function()
        local name, cls = nil, nil
        if UnitExists("target") and UnitIsPlayer("target") then
            name = ns:GetSafeUnitName("target")
            _, cls = UnitClass("target")
        end
        ns:OpenQuickModal(name, cls)
    end)
    listFrame.newBtn = newBtn

    -- Bottom-right button: Quick language toggle (EN / ES)
    local langBtn = CreateFrame("Button", nil, listFrame, "UIPanelButtonTemplate")
    langBtn:SetSize(56, 22)
    langBtn:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -18, 18)
    langBtn:SetText(strupper(ns:GetLang()))
    langBtn:SetScript("OnClick", function()
        local nextLang = (ns:GetLang() == "es") and "en" or "es"
        ns:GetSettings().lang = nextLang
        ns:UpdateActiveLang()
        ns:ApplyLocalization()
        ns:Print(ns:L("SLASH_LANG_CHANGED"))
    end)
    listFrame.langBtn = langBtn

    -- Footer help text
    local footerHelp = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerHelp:SetPoint("LEFT", newBtn, "RIGHT", 10, 0)
    footerHelp:SetPoint("RIGHT", langBtn, "LEFT", -8, 0)
    footerHelp:SetJustifyH("LEFT")
    footerHelp:SetText(ns:L("LIST_FOOTER_HELP"))
    listFrame.footerHelp = footerHelp

    listFrame:SetScript("OnShow", function()
        ns:PlayAddonSound("IG_SPELLBOOK_OPEN", 829)
        RebuildAndRenderList()
    end)
    listFrame:SetScript("OnHide", function()
        ns:PlayAddonSound("IG_SPELLBOOK_CLOSE", 830)
    end)
end

-- ============================================================================
-- 4. Minimap Button (Draggable around Minimap border)
-- ============================================================================

local function UpdateMinimapButtonPosition()
    if not minimapButton or not Minimap then
        return
    end
    local settings = ns:GetSettings()
    local angle = mrad(settings.minimapAngle or 215)
    local radius = (Minimap:GetWidth() / 2) + 5
    local x = mcos(angle) * radius
    local y = msin(angle) * radius
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    if minimapButton or not Minimap then
        return
    end

    minimapButton = CreateFrame("Button", "ForeverGrudgesMinimapButton", Minimap)
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 1)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    minimapButton.icon = icon

    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = mdeg(matan2(cy - my, cx - mx))
            ns:GetSettings().minimapAngle = angle
            UpdateMinimapButtonPosition()
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    minimapButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            local name, cls = nil, nil
            if UnitExists("target") and UnitIsPlayer("target") then
                name = ns:GetSafeUnitName("target")
                _, cls = UnitClass("target")
            end
            ns:OpenQuickModal(name, cls)
        else
            ns:ToggleListWindow()
        end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(ns:L("MINIMAP_TT_TITLE"), 1.0, 0.82, 0.0)
        GameTooltip:AddDoubleLine(ns:L("MINIMAP_TT_COUNT"), tostring(ns:GetGrudgeCount()), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(ns:L("MINIMAP_TT_LCLICK"), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(ns:L("MINIMAP_TT_RCLICK"), 0.9, 0.9, 0.9)
        GameTooltip:AddLine(ns:L("MINIMAP_TT_DRAG"))
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdateMinimapButtonPosition()
end

-- ============================================================================
-- 5. Dynamic Localization Refresh & Lazy Initialization
-- ============================================================================

function ns:ApplyLocalization()
    if quickModal then
        quickModal.title:SetText(self:L("MODAL_TITLE"))
        quickModal.nameLabel:SetText(self:L("MODAL_NAME_LABEL"))
        quickModal.tagLabel:SetText(self:L("MODAL_TAG_LABEL"))
        quickModal.noteLabel:SetText(self:L("MODAL_NOTE_LABEL"))
        quickModal.saveBtn:SetText(self:L("MODAL_BTN_SAVE"))
        quickModal.cancelBtn:SetText(self:L("MODAL_BTN_CANCEL"))
        quickModal.UpdateTagSelection(quickModal.selectedTagIndex or 1)
    end

    if listFrame then
        listFrame.title:SetText(self:L("LIST_TITLE"))
        listFrame.searchLabel:SetText(self:L("LIST_SEARCH_LABEL"))
        listFrame.emptyText:SetText(self:L("LIST_EMPTY_TEXT"))
        listFrame.newBtn:SetText(self:L("LIST_BTN_NEW"))
        listFrame.footerHelp:SetText(self:L("LIST_FOOTER_HELP"))
        listFrame.langBtn:SetText(strupper(self:GetLang()))
        for _, row in ipairs(listFrame.rows) do
            row.editBtn:SetText(self:L("LIST_BTN_EDIT"))
            row.delBtn:SetText(self:L("LIST_BTN_DELETE"))
        end
        RebuildAndRenderList()
    end

    self:UpdateTargetIndicator()
end

function ns:RefreshListWindow()
    RebuildAndRenderList()
end

function ns:ToggleListWindow()
    if not listFrame then
        CreateListWindow()
    end
    if listFrame:IsShown() then
        listFrame:Hide()
    else
        listFrame:Show()
    end
end

--- Only creates the lightweight Minimap button at login; heavier windows are lazy-created on demand.
function ns:InitUI()
    CreateMinimapButton()
end
