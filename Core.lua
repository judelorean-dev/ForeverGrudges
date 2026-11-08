-- ============================================================================
-- ForeverGrudges - Core.lua
-- Client: World of Warcraft: Forever 1.60.1.70862 (Interface 16001)
-- High-Performance, Zero-Allocation Hot Paths & Bilingual Support (EN / ES)
-- ============================================================================

local addonName, ns = ...
ForeverGrudges = ns

-- Localize frequently used Lua & WoW globals for faster lookup in hot paths
local type, pairs, ipairs, tonumber, tostring, pcall = type, pairs, ipairs, tonumber, tostring, pcall
local strformat, strlower, strupper, strfind, strmatch, strsub, strgsub =
    string.format, string.lower, string.upper, string.find, string.match, string.sub, string.gsub
local mfloor = math.floor
local wipe = wipe or table.wipe
local GetTime = GetTime
local UnitExists, UnitIsPlayer, UnitName, UnitClass, UnitIsUnit =
    UnitExists, UnitIsPlayer, UnitName, UnitClass, UnitIsUnit
local issecretvalue = issecretvalue

-- Cooldown in seconds to prevent repeated sound/screen alerts for the same player
local ALERT_COOLDOWN = 60
local alertCooldowns = {}

-- Double-buffered group member tables to avoid table allocations on GROUP_ROSTER_UPDATE
local knownGroupMembers = {}
local nextGroupMembers = {}

-- Pre-allocated unit token strings to avoid string concatenation in raid/party loops
local RAID_UNITS = {}
for i = 1, 40 do
    RAID_UNITS[i] = "raid" .. i
end
local PARTY_UNITS = { "party1", "party2", "party3", "party4" }

-- Cached count of player entries in ForeverGrudgesDB for O(1) minimap tooltip access
local cachedGrudgeCount = 0
local activeLang = "en"

-- ============================================================================
-- 1. Lightweight Localization System (EN / ES)
-- ============================================================================

local LOCALES = {
    en = {
        CHAT_PREFIX = "|cffD4AF37[Forever Grudges]|r ",
        ADDON_LOADED_MSG = "Loaded. Use |cffFFD700/grudge|r, |cffFFD700/fg|r or the minimap button.",
        ERR_INVALID_NAME = "|cffFF4444Error:|r Invalid player name.",
        ERR_SELF_GRUDGE = "|cffFF4444Error:|r You cannot add yourself.",
        ERR_INVALID_TAG = "|cffFF4444Error:|r Tag must be a number between 1 and %d (or its ID).",
        ERR_NOT_FOUND = "Player |cffFFFFFF%s|r is not in Forever Grudges.",
        DEFAULT_NOTE = "Unspecified.",
        UNKNOWN_DATE = "Unknown",
        NO_NOTE = "No note.",

        -- Registration & removal
        GRUDGE_ADDED_FMT = "Grudge recorded: %s | %s[%s]|r | |cffCCCCCC\"%s\"|r",
        GRUDGE_REMOVED_FMT = "Grudge removed: %s.",

        -- Alerts & contexts
        ALERT_RAID_FMT = "GRUDGE%s: %s! %s[%s]|r",
        ALERT_CHAT_FMT = "|cffFF3333ALERT!|r %s%s — %s[%s]|r (%s): |cffFFFF99\"%s\"|r",
        CTX_TARGET = "Target",
        CTX_MOUSEOVER = "Mouseover",
        CTX_RAID = "in Raid",
        CTX_PARTY = "in Party",
        CTX_TRADE = "Trade",
        CTX_WHISPER = "Whisper",

        -- Tooltips & Context Menu
        TOOLTIP_UNIT_HEADER = "IN FOREVER GRUDGES!: %s%s|r - %s",
        TOOLTIP_INSCRIBED_ON = "Recorded on: %s",
        MENU_ADD_GRUDGE = "|cffFFD700Add to Forever Grudges|r",
        MENU_EDIT_GRUDGE = "|cffFF6600Edit in Forever Grudges|r",

        -- TargetFrame Indicator
        INDICATOR_LABEL_FMT = "%s[GRUDGE: %s]|r",
        INDICATOR_TT_TITLE = "Listed in Forever Grudges",
        INDICATOR_TT_PLAYER = "Player:",
        INDICATOR_TT_TAG = "Tag:",
        INDICATOR_TT_DATE = "Date:",
        INDICATOR_TT_NOTE_HEADER = "Note:",
        INDICATOR_TT_LCLICK = "|cff888888Click: Edit entry|r",

        -- Quick Modal Window
        MODAL_TITLE = "Add to Forever Grudges",
        MODAL_NAME_LABEL = "Player Name:",
        MODAL_TAG_LABEL = "Tag:",
        MODAL_NOTE_LABEL = "Custom Note:",
        MODAL_BTN_SAVE = "Save",
        MODAL_BTN_CANCEL = "Cancel",

        -- Main Window
        LIST_TITLE = "Forever Grudges",
        LIST_COUNT_FMT = "Entries: |cffFFD700%d|r",
        LIST_SEARCH_LABEL = "Search:",
        LIST_EMPTY_TEXT = "No matching entries found.\nClick 'New Grudge' or Right-Click a player's portrait.",
        LIST_BTN_EDIT = "Edit",
        LIST_BTN_DELETE = "Delete",
        LIST_BTN_NEW = "New Grudge...",
        LIST_FOOTER_HELP = "Right-Click a player's portrait or the minimap button for quick registration.",

        -- Minimap Button
        MINIMAP_TT_TITLE = "Forever Grudges",
        MINIMAP_TT_COUNT = "Entries:",
        MINIMAP_TT_LCLICK = "|cffFFD700Left-Click:|r Open Forever Grudges",
        MINIMAP_TT_RCLICK = "|cffFFD700Right-Click:|r Add current target",
        MINIMAP_TT_DRAG = "|cff888888Drag: Move icon|r",

        -- Slash Commands
        SLASH_USAGE_ADD = "Usage: |cffFFD700/grudge add <Name> <Tag (1-%d)> <Note>|r",
        SLASH_USAGE_DEL = "Usage: |cffFFD700/grudge del <Name>|r",
        SLASH_LANG_CHANGED = "Language changed to |cffFFD700English (EN)|r.",
        SLASH_HELP_HEADER = "Commands:",
        SLASH_HELP_1 = "  |cffFFD700/grudge|r or |cffFFD700/fg|r - Opens quick registration (with target) or the list.",
        SLASH_HELP_2 = "  |cffFFD700/grudge list|r - Opens/closes Forever Grudges.",
        SLASH_HELP_3 = "  |cffFFD700/grudge new|r - Opens the quick registration modal.",
        SLASH_HELP_4 = "  |cffFFD700/grudge add <Name> <1-6> <Note>|r - Adds via command.",
        SLASH_HELP_5 = "  |cffFFD700/grudge del <Name>|r - Removes a player.",
        SLASH_HELP_6 = "  |cffFFD700/grudge lang <es|en>|r - Switches language (ES / EN).",
    },

    es = {
        CHAT_PREFIX = "|cffD4AF37[Forever Grudges]|r ",
        ADDON_LOADED_MSG = "Cargado. Usa |cffFFD700/grudge|r, |cffFFD700/fg|r o el botón del minimapa.",
        ERR_INVALID_NAME = "|cffFF4444Error:|r Nombre de jugador no válido.",
        ERR_SELF_GRUDGE = "|cffFF4444Error:|r No puedes registrarte a ti mismo.",
        ERR_INVALID_TAG = "|cffFF4444Error:|r La etiqueta debe ser un número entre 1 y %d (o su ID).",
        ERR_NOT_FOUND = "El jugador |cffFFFFFF%s|r no figura en Forever Grudges.",
        DEFAULT_NOTE = "Sin especificar.",
        UNKNOWN_DATE = "Desconocida",
        NO_NOTE = "Sin nota.",

        -- Registration & removal
        GRUDGE_ADDED_FMT = "Agravio registrado: %s | %s[%s]|r | |cffCCCCCC\"%s\"|r",
        GRUDGE_REMOVED_FMT = "Agravio eliminado: %s.",

        -- Alerts & contexts
        ALERT_RAID_FMT = "¡AGRAVIADO%s: %s! %s[%s]|r",
        ALERT_CHAT_FMT = "|cffFF3333¡ALERTA!|r %s%s — %s[%s]|r (%s): |cffFFFF99\"%s\"|r",
        CTX_TARGET = "Objetivo",
        CTX_MOUSEOVER = "Ratón encima",
        CTX_RAID = "en Banda",
        CTX_PARTY = "en Grupo",
        CTX_TRADE = "Comercio",
        CTX_WHISPER = "Susurro",

        -- Tooltips & Context Menu
        TOOLTIP_UNIT_HEADER = "¡EN FOREVER GRUDGES!: %s%s|r - %s",
        TOOLTIP_INSCRIBED_ON = "Inscrito el: %s",
        MENU_ADD_GRUDGE = "|cffFFD700Añadir a Forever Grudges|r",
        MENU_EDIT_GRUDGE = "|cffFF6600Editar en Forever Grudges|r",

        -- TargetFrame Indicator
        INDICATOR_LABEL_FMT = "%s[AGRAVIO: %s]|r",
        INDICATOR_TT_TITLE = "Inscrito en Forever Grudges",
        INDICATOR_TT_PLAYER = "Jugador:",
        INDICATOR_TT_TAG = "Etiqueta:",
        INDICATOR_TT_DATE = "Fecha:",
        INDICATOR_TT_NOTE_HEADER = "Nota:",
        INDICATOR_TT_LCLICK = "|cff888888Click: Editar nota|r",

        -- Quick Modal Window
        MODAL_TITLE = "Inscribir en Forever Grudges",
        MODAL_NAME_LABEL = "Nombre del Jugador:",
        MODAL_TAG_LABEL = "Etiqueta:",
        MODAL_NOTE_LABEL = "Nota personalizada:",
        MODAL_BTN_SAVE = "Guardar",
        MODAL_BTN_CANCEL = "Cancelar",

        -- Main Window
        LIST_TITLE = "Forever Grudges (Rencor Eterno)",
        LIST_COUNT_FMT = "Registros: |cffFFD700%d|r",
        LIST_SEARCH_LABEL = "Buscar:",
        LIST_EMPTY_TEXT = "No hay registros que coincidan.\nUsa 'Nuevo Agravio' o haz Click Derecho sobre el retrato de un jugador.",
        LIST_BTN_EDIT = "Editar",
        LIST_BTN_DELETE = "Borrar",
        LIST_BTN_NEW = "Nuevo Agravio...",
        LIST_FOOTER_HELP = "Click Derecho en el retrato de un jugador o en el botón del minimapa para añadir rápido.",

        -- Minimap Button
        MINIMAP_TT_TITLE = "Forever Grudges",
        MINIMAP_TT_COUNT = "Registros:",
        MINIMAP_TT_LCLICK = "|cffFFD700Click Izquierdo:|r Abrir Forever Grudges",
        MINIMAP_TT_RCLICK = "|cffFFD700Click Derecho:|r Registrar objetivo actual",
        MINIMAP_TT_DRAG = "|cff888888Arrastrar: Mover icono|r",

        -- Slash Commands
        SLASH_USAGE_ADD = "Uso: |cffFFD700/grudge add <Nombre> <Tag (1-%d)> <Nota>|r",
        SLASH_USAGE_DEL = "Uso: |cffFFD700/grudge del <Nombre>|r",
        SLASH_LANG_CHANGED = "Idioma cambiado a |cffFFD700Español (ES)|r.",
        SLASH_HELP_HEADER = "Comandos:",
        SLASH_HELP_1 = "  |cffFFD700/grudge|r o |cffFFD700/fg|r - Abre registro rápido (con objetivo) o la lista.",
        SLASH_HELP_2 = "  |cffFFD700/grudge list|r - Abre/cierra Forever Grudges.",
        SLASH_HELP_3 = "  |cffFFD700/grudge new|r - Abre el modal de registro rápido.",
        SLASH_HELP_4 = "  |cffFFD700/grudge add <Nombre> <1-6> <Nota>|r - Añade por comando.",
        SLASH_HELP_5 = "  |cffFFD700/grudge del <Nombre>|r - Elimina un jugador.",
        SLASH_HELP_6 = "  |cffFFD700/grudge lang <es|en>|r - Cambia el idioma (ES / EN).",
    },
}

-- ============================================================================
-- 2. Predefined Tags Configuration & O(1) Lookup Cache
-- ============================================================================

ForeverGrudges_DefaultTags = {
    [1] = {
        id = "NINJA",
        label = "Ninja Looter",
        label_en = "Ninja Looter",
        color = { r = 1.0, g = 0.2, b = 0.2 },
        desc = "Reclamó botín ajeno tirando necesidad indebida o rompió las reglas de loteo pactadas.",
        desc_en = "Claimed someone else's loot by rolling Need improperly or broke agreed loot rules.",
    },
    [2] = {
        id = "FIREWALK",
        label = "Comefuegos",
        label_en = "Firewalker",
        color = { r = 1.0, g = 0.53, b = 0.0 },
        desc = "Ignora mecánicas de daño continuo, permanece sobre áreas dañinas o pullea patrullas por despiste.",
        desc_en = "Ignores ground mechanics, stands in harmful areas, or accidentally pulls extra patrols.",
    },
    [3] = {
        id = "DESERTER",
        label = "Ragequitter",
        label_en = "Ragequitter",
        color = { r = 1.0, g = 0.82, b = 0.0 },
        desc = "Abandonó la mazmorra o banda tras el primer wipe dejando al grupo colgado.",
        desc_en = "Abandoned the dungeon or raid after the first wipe, leaving the group stranded.",
    },
    [4] = {
        id = "AFK",
        label = "Estatua (AFK)",
        label_en = "AFK Statue",
        color = { r = 0.5, g = 0.75, b = 1.0 },
        desc = "En seguimiento pasivo o ausente prolongado sin justificación mientras el grupo hace el trabajo.",
        desc_en = "On passive follow or prolonged unexplained AFK while the rest of the group does the work.",
    },
    [5] = {
        id = "RAGER",
        label = "Rager de Chat",
        label_en = "Chat Rager",
        color = { r = 0.64, g = 0.21, b = 0.93 },
        desc = "Usa el chat de grupo para generar crispación, culpar al resto y entorpecer la coordinación.",
        desc_en = "Uses group chat to stir up drama, blame others, and disrupt team coordination.",
    },
    [6] = {
        id = "GANKER",
        label = "Ganker / Acechador",
        label_en = "Ganker / Stalker",
        color = { r = 0.67, g = 0.13, b = 0.13 },
        desc = "Campea cementerios o persigue sistemáticamente a objetivos con gran desventaja de nivel.",
        desc_en = "Camps graveyards or relentlessly hunts down low-level or outnumbered players.",
    },
}

-- O(1) lookup table mapping any tag index, ID, or label (original or lowercase) to its cached tag record
local TAG_LOOKUP = {}
local CACHED_TAGS = {}

for idx, tag in ipairs(ForeverGrudges_DefaultTags) do
    tag.index = idx
    tag.hex = strformat(
        "|cff%02x%02x%02x",
        mfloor((tag.color.r or 1) * 255 + 0.5),
        mfloor((tag.color.g or 1) * 255 + 0.5),
        mfloor((tag.color.b or 1) * 255 + 0.5)
    )

    -- Pre-allocate a single reusable view object per tag (0 allocations during gameplay)
    local cached = {
        index = idx,
        id = tag.id,
        label = tag.label_en or tag.label,
        name = tag.label_en or tag.label,
        desc = tag.desc_en or tag.desc,
        color = tag.color,
        hex = tag.hex,
        raw = tag,
    }
    CACHED_TAGS[idx] = cached

    TAG_LOOKUP[idx] = cached
    TAG_LOOKUP[tostring(idx)] = cached
    TAG_LOOKUP[tag.id] = cached
    TAG_LOOKUP[strlower(tag.id)] = cached
    TAG_LOOKUP[tag.label] = cached
    TAG_LOOKUP[strlower(tag.label)] = cached
    if tag.label_en then
        TAG_LOOKUP[tag.label_en] = cached
        TAG_LOOKUP[strlower(tag.label_en)] = cached
    end
end

ns.TAGS = ForeverGrudges_DefaultTags

--- Updates cached localized tag strings in-place whenever the active language changes.
local function RefreshCachedTags()
    local isEn = (activeLang == "en")
    for idx, cached in ipairs(CACHED_TAGS) do
        local raw = cached.raw
        local lbl = isEn and (raw.label_en or raw.label) or raw.label
        local dsc = isEn and (raw.desc_en or raw.desc) or raw.desc
        cached.label = lbl
        cached.name = lbl
        cached.desc = dsc
    end
end

-- ============================================================================
-- 3. Language, Sound & Name Normalization Helpers
-- ============================================================================

--- Synchronizes activeLang from saved settings or client locale.
function ns:UpdateActiveLang()
    if ForeverGrudgesDB and ForeverGrudgesDB._settings and ForeverGrudgesDB._settings.lang then
        local saved = ForeverGrudgesDB._settings.lang
        if LOCALES[saved] then
            activeLang = saved
            RefreshCachedTags()
            return activeLang
        end
    end
    local clientLocale = type(GetLocale) == "function" and GetLocale() or "enUS"
    if clientLocale == "esES" or clientLocale == "esMX" then
        activeLang = "es"
    else
        activeLang = "en"
    end
    RefreshCachedTags()
    return activeLang
end

--- Returns the active language code ("en" or "es") in O(1).
function ns:GetLang()
    return activeLang
end

--- Retrieves a localized string by key in O(1).
function ns:L(key)
    local tbl = LOCALES[activeLang] or LOCALES.en
    return tbl[key] or LOCALES.en[key] or key
end

--- Returns the localized label and description for a given raw tag table.
function ns:GetLocalizedTagStrings(tagInfo)
    if not tagInfo then
        return "Ninja Looter", ""
    end
    if activeLang == "en" then
        return (tagInfo.label_en or tagInfo.label or "Grudge"),
               (tagInfo.desc_en or tagInfo.desc or "")
    end
    return (tagInfo.label or "Agravio"), (tagInfo.desc or "")
end

--- Prints a prefixed message to the default chat frame.
function ns:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(self:L("CHAT_PREFIX") .. tostring(msg))
    end
end

--- Plays a sound safely using numeric SOUNDKIT IDs in 1.60.1.
function ns:PlayAddonSound(soundKitKey, fallbackId)
    if SOUNDKIT and SOUNDKIT[soundKitKey] then
        pcall(PlaySound, SOUNDKIT[soundKitKey], "Master")
    elseif fallbackId and type(PlaySound) == "function" then
        pcall(PlaySound, fallbackId, "Master")
    end
end

--- Normalizes a player name:
--- Strips the realm name (if present) and capitalizes the first character while
--- lowercasing the rest (supports 2-byte UTF-8 characters).
function ns:NormalizeName(rawName)
    if not rawName or type(rawName) ~= "string" then
        return nil
    end

    if issecretvalue and issecretvalue(rawName) then
        return nil
    end

    if strsub(rawName, 1, 1) == "_" then
        return nil
    end

    -- Trim whitespace and strip realm suffix ("Name-Realm" -> "Name")
    local clean = strmatch(rawName, "^%s*([^%-]+)%s*")
    if not clean or clean == "" then
        return nil
    end
    clean = strgsub(clean, "%s+$", "")
    if clean == "" then
        return nil
    end

    -- Split first UTF-8 character from the remainder
    local first, rest = strmatch(clean, "^([%z\1-\127\194-\244][\128-\191]*)(.*)")
    if not first then
        return nil
    end
    return strupper(first) .. strlower(rest or "")
end

--- Safely retrieves a unit's name without triggering secret value errors.
function ns:GetSafeUnitName(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local name = UnitName(unit)
    if issecretvalue and issecretvalue(name) then
        return nil
    end
    return name
end

--- Resolves tag metadata in O(1) with zero table allocations.
function ns:GetTagInfo(tagOrId)
    if tagOrId then
        local direct = TAG_LOOKUP[tagOrId]
        if direct then
            return direct
        end
        if type(tagOrId) == "string" then
            local byLower = TAG_LOOKUP[strlower(tagOrId)]
            if byLower then
                return byLower
            end
        end
    end
    return CACHED_TAGS[1]
end

-- Precompute class color hex prefixes once for O(1) formatting
local CLASS_HEX_CACHE = {}
function ns:FormatPlayerName(name, classToken)
    if classToken then
        local hex = CLASS_HEX_CACHE[classToken]
        if not hex and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
            local c = RAID_CLASS_COLORS[classToken]
            hex = strformat("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
            CLASS_HEX_CACHE[classToken] = hex
        end
        if hex then
            return hex .. tostring(name) .. "|r"
        end
    end
    return "|cffFFFFFF" .. tostring(name) .. "|r"
end

--- Returns the internal addon settings table stored in ForeverGrudgesDB._settings.
function ns:GetSettings()
    if type(ForeverGrudgesDB) ~= "table" then
        ForeverGrudgesDB = {}
    end
    if type(ForeverGrudgesDB._settings) ~= "table" then
        ForeverGrudgesDB._settings = {
            minimapAngle = 215,
        }
    end
    return ForeverGrudgesDB._settings
end

--- Recomputes cachedGrudgeCount once on startup.
local function RecountGrudges()
    cachedGrudgeCount = 0
    if not ForeverGrudgesDB then
        return
    end
    for k, v in pairs(ForeverGrudgesDB) do
        if type(k) == "string" and strsub(k, 1, 1) ~= "_" and type(v) == "table" and (v.tag or v.tagId) then
            cachedGrudgeCount = cachedGrudgeCount + 1
        end
    end
end

--- Returns the total number of player grudge entries in O(1).
function ns:GetGrudgeCount()
    return cachedGrudgeCount
end

-- ============================================================================
-- 4. Data Management (SavedVariables: ForeverGrudgesDB)
-- ============================================================================

--- Adds or updates a player entry in ForeverGrudgesDB.
function ns:AddGrudge(playerName, tagOrId, note, classToken)
    local normName = self:NormalizeName(playerName)
    if not normName then
        self:Print(self:L("ERR_INVALID_NAME"))
        return false
    end

    local myName = self:NormalizeName(self:GetSafeUnitName("player"))
    if normName == myName then
        self:Print(self:L("ERR_SELF_GRUDGE"))
        return false
    end

    local tagInfo = self:GetTagInfo(tagOrId)
    local cleanNote = (note and strmatch(note, "^%s*(.-)%s*$")) or ""
    if cleanNote == "" then
        cleanNote = self:L("DEFAULT_NOTE")
    end

    local existingEntry = ForeverGrudgesDB[normName]
    local isNew = not (type(existingEntry) == "table" and (existingEntry.tag or existingEntry.tagId))

    if not classToken then
        if UnitExists("target") and UnitIsPlayer("target") and self:NormalizeName(self:GetSafeUnitName("target")) == normName then
            local _, englishClass = UnitClass("target")
            classToken = englishClass
        elseif UnitExists("mouseover") and UnitIsPlayer("mouseover") and self:NormalizeName(self:GetSafeUnitName("mouseover")) == normName then
            local _, englishClass = UnitClass("mouseover")
            classToken = englishClass
        elseif existingEntry and existingEntry.class then
            classToken = existingEntry.class
        end
    end

    if isNew then
        ForeverGrudgesDB[normName] = {
            tagId = tagInfo.id,
            tag = tagInfo.label,
            note = cleanNote,
            date = date("%d/%m/%Y %H:%M"),
            class = classToken,
        }
        cachedGrudgeCount = cachedGrudgeCount + 1
    else
        existingEntry.tagId = tagInfo.id
        existingEntry.tag = tagInfo.label
        existingEntry.note = cleanNote
        existingEntry.date = date("%d/%m/%Y %H:%M")
        existingEntry.class = classToken
    end

    local coloredName = self:FormatPlayerName(normName, classToken)
    self:Print(strformat(
        self:L("GRUDGE_ADDED_FMT"),
        coloredName, tagInfo.hex, tagInfo.label, cleanNote
    ))
    self:PlayAddonSound("IG_QUEST_LOG_OPEN", 844)

    if self.UpdateTargetIndicator then
        self:UpdateTargetIndicator()
    end
    if self.RefreshListWindow then
        self:RefreshListWindow()
    end

    return true
end

--- Removes a player entry from ForeverGrudgesDB.
function ns:RemoveGrudge(playerName)
    local normName = self:NormalizeName(playerName)
    if not normName or not ForeverGrudgesDB[normName] then
        self:Print(strformat(self:L("ERR_NOT_FOUND"), tostring(playerName)))
        return false
    end

    local oldData = ForeverGrudgesDB[normName]
    local coloredName = self:FormatPlayerName(normName, oldData.class)
    ForeverGrudgesDB[normName] = nil
    alertCooldowns[normName] = nil
    if cachedGrudgeCount > 0 then
        cachedGrudgeCount = cachedGrudgeCount - 1
    end

    self:Print(strformat(self:L("GRUDGE_REMOVED_FMT"), coloredName))
    self:PlayAddonSound("IG_QUEST_LIST_COMPLETE", 878)

    if self.UpdateTargetIndicator then
        self:UpdateTargetIndicator()
    end
    if self.RefreshListWindow then
        self:RefreshListWindow()
    end
    return true
end

--- Looks up a player in ForeverGrudgesDB with a zero-allocation O(1) fast-path.
function ns:GetGrudge(playerName)
    if not ForeverGrudgesDB or not playerName or type(playerName) ~= "string" then
        return nil
    end
    if issecretvalue and issecretvalue(playerName) then
        return nil
    end
    if strsub(playerName, 1, 1) == "_" then
        return nil
    end

    -- Fast-path: UnitName() in WoW returns an already normalized single-word name ("Arthas").
    -- Direct table lookup avoids all string pattern matching and allocations during mouseover/target events.
    local directEntry = ForeverGrudgesDB[playerName]
    if type(directEntry) == "table" and (directEntry.tag or directEntry.tagId) then
        return directEntry, playerName
    end

    -- Only run full normalization if the string contains a realm separator, spaces, or uppercase/lowercase mismatch
    local normName = self:NormalizeName(playerName)
    if not normName then
        return nil
    end
    local entry = ForeverGrudgesDB[normName]
    if type(entry) ~= "table" or not (entry.tag or entry.tagId) then
        return nil
    end
    return entry, normName
end

-- ============================================================================
-- 5. Visual & Sound Alert System (with Anti-Spam Cooldown)
-- ============================================================================

--- Triggers screen, chat, and sound alerts if the player's alert cooldown has expired.
function ns:TriggerGrudgeAlert(playerName, contextText, preloadedEntry, preloadedNormName)
    local entry, normName = preloadedEntry, preloadedNormName
    if not entry or not normName then
        entry, normName = self:GetGrudge(playerName)
    end
    if not entry then
        return
    end

    local now = GetTime()
    local lastAlert = alertCooldowns[normName]
    if lastAlert and (now - lastAlert) < ALERT_COOLDOWN then
        return
    end
    alertCooldowns[normName] = now

    local tagInfo = self:GetTagInfo(entry.tagId or entry.tag)
    local coloredName = self:FormatPlayerName(normName, entry.class)
    local sourceLabel = contextText and (" (" .. contextText .. ")") or ""

    -- 1. Screen alert via RaidWarningFrame (or UIErrorsFrame fallback)
    local raidMsg = strformat(
        self:L("ALERT_RAID_FMT"),
        sourceLabel, strupper(normName), tagInfo.hex, tagInfo.label
    )
    if RaidWarningFrame and RaidNotice_AddMessage then
        RaidNotice_AddMessage(RaidWarningFrame, raidMsg, ChatTypeInfo["RAID_WARNING"])
    elseif UIErrorsFrame then
        UIErrorsFrame:AddMessage(raidMsg, 1.0, 0.1, 0.1, 1.0)
    end

    -- 2. Detailed message in general chat
    self:Print(strformat(
        self:L("ALERT_CHAT_FMT"),
        coloredName, sourceLabel, tagInfo.hex, tagInfo.label, entry.date or self:L("UNKNOWN_DATE"), entry.note or ""
    ))

    -- 3. Sound alert (8959 = SOUNDKIT.RAID_WARNING)
    self:PlayAddonSound("RAID_WARNING", 8959)
end

--- Scans current party or raid members for listed players using zero-allocation double buffering.
function ns:ScanGroupMembers()
    if cachedGrudgeCount == 0 then
        wipe(knownGroupMembers)
        return
    end

    wipe(nextGroupMembers)

    if IsInRaid and IsInRaid() then
        local total = (GetNumGroupMembers and GetNumGroupMembers()) or 0
        if total > 40 then total = 40 end
        for i = 1, total do
            local unit = RAID_UNITS[i]
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local rawName = self:GetSafeUnitName(unit)
                if rawName then
                    local entry, normName = self:GetGrudge(rawName)
                    local key = normName or rawName
                    nextGroupMembers[key] = true
                    if entry and not knownGroupMembers[key] then
                        if not entry.class then
                            local _, cls = UnitClass(unit)
                            entry.class = cls
                        end
                        self:TriggerGrudgeAlert(key, self:L("CTX_RAID"), entry, normName)
                    end
                end
            end
        end
    elseif IsInGroup and IsInGroup() then
        local total = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or 4
        if total > 4 then total = 4 end
        for i = 1, total do
            local unit = PARTY_UNITS[i]
            if UnitExists(unit) then
                local rawName = self:GetSafeUnitName(unit)
                if rawName then
                    local entry, normName = self:GetGrudge(rawName)
                    local key = normName or rawName
                    nextGroupMembers[key] = true
                    if entry and not knownGroupMembers[key] then
                        if not entry.class then
                            local _, cls = UnitClass(unit)
                            entry.class = cls
                        end
                        self:TriggerGrudgeAlert(key, self:L("CTX_PARTY"), entry, normName)
                    end
                end
            end
        end
    end

    -- Swap double buffers without allocating a new table
    knownGroupMembers, nextGroupMembers = nextGroupMembers, knownGroupMembers
end

-- ============================================================================
-- 6. Safe Hooks (Taint-Free / No Protected Calls in 1.60.1)
-- ============================================================================

local function AddGrudgeLinesToTooltip(tooltip, unit)
    if cachedGrudgeCount == 0 or not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return
    end
    local rawName = ns:GetSafeUnitName(unit)
    local entry = ns:GetGrudge(rawName)
    if entry then
        if not entry.class then
            local _, cls = UnitClass(unit)
            entry.class = cls
        end
        local tagInfo = ns:GetTagInfo(entry.tagId or entry.tag)
        tooltip:AddLine(" ")
        tooltip:AddLine(
            strformat(ns:L("TOOLTIP_UNIT_HEADER"), tagInfo.hex, tagInfo.label, entry.note or ""),
            1.0, 0.15, 0.15, true
        )
        if tagInfo.desc and tagInfo.desc ~= "" then
            tooltip:AddLine(tagInfo.desc, 0.9, 0.82, 0.6, true)
        end
        tooltip:AddLine(strformat(ns:L("TOOLTIP_INSCRIBED_ON"), entry.date or ns:L("UNKNOWN_DATE")), 0.75, 0.75, 0.75)
        tooltip:Show()
    end
end

local function SetupHooks()
    -- 1. Hook GameTooltip to append grudge details when hovering over a player unit
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            if tooltip ~= GameTooltip then
                return
            end
            local _, unit = tooltip:GetUnit()
            AddGrudgeLinesToTooltip(tooltip, unit or "mouseover")
        end)
    elseif GameTooltip and GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            local _, unit = tooltip:GetUnit()
            AddGrudgeLinesToTooltip(tooltip, unit)
        end)
    end

    -- 2. Right-click unit portrait context menu (using Menu.ModifyMenu API in 1.60.1)
    if Menu and Menu.ModifyMenu then
        local MENU_TAGS = {
            "MENU_UNIT_PLAYER",
            "MENU_UNIT_ENEMY_PLAYER",
            "MENU_UNIT_PARTY",
            "MENU_UNIT_RAID_PLAYER",
            "MENU_UNIT_FRIEND",
        }

        local function OnUnitMenuModify(owner, rootDescription, contextData)
            if not contextData then
                return
            end
            local unit = contextData.unit
            local targetName = contextData.name
            local targetClass = nil

            if unit and UnitExists(unit) then
                if not UnitIsPlayer(unit) then
                    return
                end
                targetName = ns:GetSafeUnitName(unit) or targetName
                local _, cls = UnitClass(unit)
                targetClass = cls
            end

            local normName = ns:NormalizeName(targetName)
            if not normName or normName == ns:NormalizeName(ns:GetSafeUnitName("player")) then
                return
            end

            rootDescription:CreateDivider()
            local existing = ns:GetGrudge(normName)
            local btnLabel = existing and ns:L("MENU_EDIT_GRUDGE") or ns:L("MENU_ADD_GRUDGE")

            rootDescription:CreateButton(btnLabel, function()
                if ns.OpenQuickModal then
                    ns:OpenQuickModal(normName, targetClass)
                end
            end)
        end

        for _, menuTag in ipairs(MENU_TAGS) do
            pcall(Menu.ModifyMenu, menuTag, OnUnitMenuModify)
        end
    end
end

-- ============================================================================
-- 7. Slash Commands (/grudge and /fg)
-- ============================================================================

local function HandleSlashCommand(msg)
    local input = (msg and strmatch(msg, "^%s*(.-)%s*$")) or ""
    local cmd, rest = strmatch(input, "^(%S+)%s*(.*)$")
    cmd = cmd and strlower(cmd) or ""

    if cmd == "" then
        if UnitExists("target") and UnitIsPlayer("target") then
            local name = ns:GetSafeUnitName("target")
            local _, cls = UnitClass("target")
            ns:OpenQuickModal(name, cls)
        else
            ns:ToggleListWindow()
        end
        return
    end

    if cmd == "lang" or cmd == "locale" then
        local targetLang = strlower(rest or "")
        if targetLang ~= "es" and targetLang ~= "en" then
            targetLang = (ns:GetLang() == "es") and "en" or "es"
        end
        ns:GetSettings().lang = targetLang
        ns:UpdateActiveLang()
        if ns.ApplyLocalization then
            ns:ApplyLocalization()
        end
        ns:Print(ns:L("SLASH_LANG_CHANGED"))
        return
    end

    if cmd == "add" then
        local targetName, tagToken, noteText = strmatch(rest, "^(%S+)%s+(%S+)%s*(.*)$")
        if not targetName or not tagToken then
            ns:Print(strformat(ns:L("SLASH_USAGE_ADD"), #ForeverGrudges_DefaultTags))
            for i, t in ipairs(ForeverGrudges_DefaultTags) do
                local locLabel, locDesc = ns:GetLocalizedTagStrings(t)
                ns:Print(strformat("  %d (%s) = %s%s|r — %s", i, t.id, t.hex, locLabel, locDesc))
            end
            return
        end

        local validTag = TAG_LOOKUP[tagToken] or TAG_LOOKUP[strlower(tagToken)]
        if not validTag then
            ns:Print(strformat(ns:L("ERR_INVALID_TAG"), #ForeverGrudges_DefaultTags))
            return
        end

        ns:AddGrudge(targetName, validTag.id, noteText)
        return
    end

    if cmd == "del" or cmd == "remove" or cmd == "rm" then
        if rest == "" then
            ns:Print(ns:L("SLASH_USAGE_DEL"))
            return
        end
        ns:RemoveGrudge(rest)
        return
    end

    if cmd == "new" or cmd == "quick" then
        local name, cls = nil, nil
        if UnitExists("target") and UnitIsPlayer("target") then
            name = ns:GetSafeUnitName("target")
            _, cls = UnitClass("target")
        end
        ns:OpenQuickModal(name, cls)
        return
    end

    if cmd == "list" or cmd == "book" or cmd == "show" then
        ns:ToggleListWindow()
        return
    end

    ns:Print(ns:L("SLASH_HELP_HEADER"))
    ns:Print(ns:L("SLASH_HELP_1"))
    ns:Print(ns:L("SLASH_HELP_2"))
    ns:Print(ns:L("SLASH_HELP_3"))
    ns:Print(ns:L("SLASH_HELP_4"))
    ns:Print(ns:L("SLASH_HELP_5"))
    ns:Print(ns:L("SLASH_HELP_6"))
end

SLASH_FOREVERGRUDGES1 = "/grudge"
SLASH_FOREVERGRUDGES2 = "/fg"
SlashCmdList["FOREVERGRUDGES"] = HandleSlashCommand

-- ============================================================================
-- 8. Main Event Handler (Client 1.60.1.70862)
-- ============================================================================

local eventFrame = CreateFrame("Frame", "ForeverGrudgesEventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("TRADE_SHOW")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName or loadedAddon == "ForeverGrudges" then
            if type(ForeverGrudgesDB) ~= "table" then
                ForeverGrudgesDB = {}
            end
            ns:GetSettings()
            ns:UpdateActiveLang()
            RecountGrudges()
            if ns.InitUI then
                ns:InitUI()
            end
            SetupHooks()
            ns:Print(ns:L("ADDON_LOADED_MSG"))
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        if cachedGrudgeCount == 0 then
            if ns.HideTargetIndicator then
                ns:HideTargetIndicator()
            end
            return
        end

        if UnitExists("target") and UnitIsPlayer("target") then
            local rawName = ns:GetSafeUnitName("target")
            local entry, normName = ns:GetGrudge(rawName)
            if entry then
                if not entry.class then
                    local _, cls = UnitClass("target")
                    entry.class = cls
                end
                if ns.UpdateTargetIndicator then
                    ns:UpdateTargetIndicator(entry, normName)
                end
                ns:TriggerGrudgeAlert(normName, ns:L("CTX_TARGET"), entry, normName)
                return
            end
        end

        if ns.HideTargetIndicator then
            ns:HideTargetIndicator()
        end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if cachedGrudgeCount == 0 then
            return
        end
        if UnitExists("mouseover") and UnitIsPlayer("mouseover") then
            local rawName = ns:GetSafeUnitName("mouseover")
            local entry, normName = ns:GetGrudge(rawName)
            if entry then
                if not entry.class then
                    local _, cls = UnitClass("mouseover")
                    entry.class = cls
                end
                ns:TriggerGrudgeAlert(normName, ns:L("CTX_MOUSEOVER"), entry, normName)
            end
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        ns:ScanGroupMembers()

    elseif event == "TRADE_SHOW" then
        if cachedGrudgeCount == 0 then
            return
        end
        if UnitExists("NPC") and UnitIsPlayer("NPC") then
            local rawName = ns:GetSafeUnitName("NPC")
            local entry, normName = ns:GetGrudge(rawName)
            if entry then
                ns:TriggerGrudgeAlert(normName, ns:L("CTX_TRADE"), entry, normName)
            end
        end

    elseif event == "CHAT_MSG_WHISPER" then
        if cachedGrudgeCount == 0 then
            return
        end
        local _, author = ...
        if issecretvalue and issecretvalue(author) then
            return
        end
        if author then
            local entry, normName = ns:GetGrudge(author)
            if entry then
                ns:TriggerGrudgeAlert(normName, ns:L("CTX_WHISPER"), entry, normName)
            end
        end
    end
end)
