---------------------------------------------------------------------------
-- Spellsteal Monitor
-- Creates a small frame with stealable spells from your current target.
---------------------------------------------------------------------------

local version = C_AddOns.GetAddOnMetadata("SimpleSpellsteal", "Version")

SSFrame = nil
SSFrameList = nil

-- Slash Command Handler
function SS_handleCmd(msg, editbox)
    msg = string.lower(msg)
    if msg == "test" then
        if debug then
            debug = false
            DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Disabling test frame.")
            SSFrameUpdate()
        else
            debug = true
            SSFrameUpdate()
            DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Showing test frame.")
        end
    elseif msg == "announce" then
        SSAnnounce = not SSAnnounce
        DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Announcing to raid/party " .. (SSAnnounce and "enabled." or "disabled."))
        SSFrametitle:SetText("SimpleSpellsteal" .. (SSAnnounce and " (Announce mode)" or ""))
    elseif msg == "lock" then
        SSFrame.Locked = not SSFrame.Locked
        DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Frame is now " .. (SSFrame.Locked and "locked." or "unlocked."))
    elseif msg == "growup" then
        SSGrowup = not SSGrowup
        DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Frame will now grow " .. (SSGrowup and "up (reverse)." or "down (normal)."))
        SSFrameList:ClearAllPoints()
        SSFrameList:SetPoint(SSGrowup and "BOTTOMLEFT" or "TOPLEFT", 0, SSGrowup and 21 or -21)
        SSFrameUpdate()
    else
        DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Recognized commands:\n\"test\" - Shows SimpleSpellsteal frame with fake buffs.\n\"announce\" - Toggles announcing stolen spells to raid/party.\n\"lock\" - Toggles frame locking.\n\"growup\" - Toggles frame growth direction.")
    end
end

-- OnLoad Event Handler
function SS_OnLoad(self)
    local _, playerClass = UnitClass("player")
    if playerClass ~= "MAGE" then return end  -- Ensure the player is a mage

    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("PLAYER_DEAD")
    self:RegisterEvent("UNIT_TARGET")

    SLASH_SimpleSpellsteal1 = "/ssteal"
    SLASH_SimpleSpellsteal2 = "/ss"
    SlashCmdList["SimpleSpellsteal"] = SS_handleCmd

    SSAnnounce = SSAnnounce or false
    SSGrowup = SSGrowup or false

    SSFrameCreate()
    SSFrameUpdate()
end

-- Round Function
function round(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Frame Update Function
function SSFrameUpdate()
    local i = 1
    local stealableBuffs = {}
    local buffName, _, _, _, _, expireTime, _, isStealable = C_UnitAuras.GetBuffDataByIndex("target", i)

    if not SSFrame then SSFrameCreate() end

    while buffName do
        if isStealable then
            if expireTime then
                expireTime = round(expireTime - GetTime(), 1)
                if expireTime > 60 then
                    expireTime = ""
                else
                    expireTime = expireTime .. "s"
                end
            end
            table.insert(stealableBuffs, buffName .. " " .. expireTime)
        end
        i = i + 1
        buffName, _, _, _, _, expireTime, _, isStealable = C_UnitAuras.GetBuffDataByIndex("target", i)
    end

    if debug then
        stealableBuffs = {"Steal me!", "Nerf Ele Shaman!", "Combo points are for Rogues", "Paladins are dead"}
    end

    if #stealableBuffs < 1 then
        SSFrame:Hide()
    else
        local height = 20 + (14 * #stealableBuffs)  -- Title height + 14px per line
        SSFrame:SetHeight(height)  -- Adjust frame height dynamically
        stealableBuffs = table.concat(stealableBuffs, "\n")
        SSFrameList:SetHeight(14 * #stealableBuffs)  -- Adjust list height
        SSFrameList.DisplayText:SetText(stealableBuffs)
        SSFrameList:ClearAllPoints()
        SSFrameList:SetPoint(SSGrowup and "BOTTOMLEFT" or "TOPLEFT", 0, SSGrowup and 21 or -21)
        SSFrame:Show()
    end
end

-- Event Handler Function
function SS_handleEvent(self, event, ...)
    if event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_TARGET" and select(1, ...) == "player") or event == "PLAYER_DEAD" then
        SSFrameUpdate()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, eventType, _, sourceGUID, _, _, _, destName, _, _, spellID = CombatLogGetCurrentEventInfo()

        if eventType == "SPELL_STOLEN" and sourceGUID == UnitGUID("player") then
            local spellLink = GetSpellLink(spellID)
            local msg = "You have stolen: " .. spellLink .. " from " .. destName
            if SSAnnounce then
                local channel = IsInRaid() and (IsInRaid(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "RAID") or (GetNumSubgroupMembers() > 0 and "PARTY")
                if channel then SendChatMessage(msg, channel) end
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFFFFF" .. msg)
            SSFrameUpdate()
        end
    elseif event == "UNIT_AURA" and select(1, ...) == "target" then
        SSFrameUpdate()
    end
end

-- Frame Creation Function
function SSFrameCreate()
    if SSFrame then return end

    SSFrame = CreateFrame("Frame", "SSFrame", UIParent, "BackdropTemplate")
    SSFrame:SetClampedToScreen(true)
    SSFrame:SetFrameStrata("HIGH")
    SSFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 3, insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    SSFrame:SetBackdropColor(0, 0, 0, 1)
    SSFrame:SetSize(220, 40)  -- Adjust the base size to fit the title
    SSFrame:SetPoint("CENTER")
    SSFrame:EnableMouse(true)
    SSFrame:SetMovable(true)
    SSFrame:RegisterForDrag("RightButton")
    SSFrame:SetUserPlaced(true)
    SSFrame.Locked = true

    SSFrame:SetScript("OnMouseDown", function(self)
        if not self.Locked then self:StartMoving() end
    end)
    SSFrame:SetScript("OnMouseUp", function(self)
        if not self.Locked then self:StopMovingOrSizing() end
    end)
    SSFrame:SetScript("OnShow", function()
        SSFrameList:Show()
        SSFrametitle:SetText("SimpleSpellsteal" .. (SSAnnounce and " (Announce mode)" or ""))
    end)
    SSFrame:SetScript("OnHide", function(self)
        if self.isMoving then
            self:StopMovingOrSizing()
            self.isMoving = false
        end
    end)

    SSFrametitle = SSFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SSFrametitle:SetPoint("TOPLEFT", SSFrame, "TOPLEFT", 0, -4)
    SSFrametitle:SetText("SimpleSpellsteal")

    SSFrameList = CreateFrame("Frame", "SSFrameList", SSFrame, "BackdropTemplate")
    SSFrameList:SetSize(220, 100)
    SSFrameList:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 3, insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    SSFrameList:SetBackdropColor(1, 0, 0, 0.5)
    SSFrameList:SetBackdropBorderColor(0, 0, 0)

    SSFrameList.DisplayText = SSFrameList:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SSFrameList.DisplayText:SetPoint("TOPLEFT", SSFrameList, "TOPLEFT", 5, -5)
    SSFrameList.DisplayText:SetJustifyH("LEFT")
end