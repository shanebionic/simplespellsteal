---------------------------------------------------------------------------
-- Spellsteal Monitor
-- Creates a small frame with stealable spells from your current target.
---------------------------------------------------------------------------
local version = C_AddOns.GetAddOnMetadata("SimpleSpellsteal", "Version")

SSFrame = nil
SSFrameList = nil


function SS_handleCmd(msg, editbox)
	if (msg == "test" ) then
		if (debug == true) then
			debug = false
			DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Disabling test frame.")
			SSFrameUpdate()
		else
			debug = true
			SSFrameUpdate()
			DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Showing test frame.")
		end
	elseif (msg == "announce") then
		if (SSAnnounce == true) then
			DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Announcing to raid/party disabled.")
			SSAnnounce = false
			if (not SSFrametitle) then
				SSFrameCreate()
				SSFrameUpdate()
			end
			SSFrametitle:SetText("SimpleSpellsteal")
		else
			DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Announcing to raid/party enabled.")
			SSAnnounce  = true
			if (not SSFrametitle) then
				SSFrameCreate()
				SSFrameUpdate()
			end
			SSFrametitle:SetText("SimpleSpellsteal (Announce mode)")
		end
	elseif (msg == "lock" ) then
		if (SSFrame.Locked == true) then
			SSFrame.Locked = false
			DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Frame is now unlocked. Frame with auto lock if you reload UI or restart game.")
		else
			SSFrame.Locked = true
			DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Frame is now locked.")
		end
	elseif (msg == "growup") then
		if (SSGrowup == true) then
			SSGrowup = false
			DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: Frame will now grow down (normal).")
			SSFrameList:ClearAllPoints()
			SSFrameList:SetPoint("TOPLEFT",0,-21)
			SSFrameUpdate()
				
		else
			SSGrowup = true
			DEFAULT_CHAT_FRAME:AddMessage("SpellSteaker: Frame will now grow up (reverse).")
			SSFrameList:ClearAllPoints()
			SSFrameList:SetPoint("BOTTOMLEFT",0,21)
			SSFrameUpdate()
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("SimpleSpellsteal: The following commands are recognized. \n\r\"test\" -- Shows SimpleSpellsteal frame with fake buffs for positioning.\n\r\"announce\" -- Toggles on/off announcing spells stolen to raid/party. Detects which you are in and announces accordingly.\r\n\"lock\" --Toggles on/off the frame locking. (Defaults to locked)\r\n\"growup\" -- Toggles the frame growing down (default) or up (reversed)")
		
	end
end


function SS_OnLoad(self)
	local _, playerClass = UnitClass("player")
	
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("UNIT_AURA")	
	self:RegisterEvent("PLAYER_DEAD")
	self:RegisterEvent("UNIT_TARGET")
	SLASH_SimpleSpellsteal1 = "/ssteal"
	SLASH_SimpleSpellsteal2 = "/ss"
	SlashCmdList["SimpleSpellsteal"] = SS_handleCmd
	
	if (SSAnnounce == nil) then
		SSAnnounce = false
	end
	
	if ( SSGrowup == nil) then
		SSGrowup = false
	end
	
	SSFrameCreate()
	SSFrameUpdate()
	
end
function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end


function SSFrameUpdate()
	local  i = 1
	local stealableBuffs = { }
	local buffName, _, _, _, _, expireTime, _, isStealable = C_UnitAuras.GetAuraDataByIndex("target", i, "HELPFUL")
	
	if not SSFrame then
		SSFrameCreate()
	end

	while buffName do
		if (isStealable == true) then
			if (expireTime) then
				expireTime = round(expireTime - GetTime(),1)
				if (expireTime > 60) then
					expireTime = ""
				else
					expireTime = expireTime .. "s"
				end
			end
			stealableBuffs[#stealableBuffs +1] = buffName .. " " .. expireTime
		end
		i = i+1
		buffName, _, _, _, _, expireTime, _, isStealable = C_UnitAuras.GetAuraDataByIndex("target", i, "HELPFUL")
	end
	if (debug == true) then
		stealableBuffs[1] = "Steal me!"
		stealableBuffs[2] = "Nerf Ele Shaman!"
		stealableBuffs[3] = "Combo points are for Rogues"
		stealableBuffs[4] = "Paladins are dead"

	end
		
	if (#stealableBuffs<1) then
		SSFrame:Hide()
	else
		
		local height = 10* #stealableBuffs
		stealableBuffs = table.concat(stealableBuffs, "\n")
		SSFrameList:SetHeight(height)
		SSFrameList.DisplayText:SetText(stealableBuffs)
		if ( SSGrowup == true) then
			SSFrameList:ClearAllPoints()
			SSFrameList:SetPoint("BOTTOMLEFT",0,21)
		else
			SSFrameList:ClearAllPoints()
			SSFrameList:SetPoint("TOPLEFT",0,-21)
		end

		SSFrame:Show()
	end
end

function SS_handleEvent(self, event, ...)
	local isParty = ((GetNumSubgroupMembers() >0) and not IsInRaid())
	local isLFR = IsInRaid(LE_PARTY_CATEGORY_INSTANCE)
	
	local channel = nil
	
	if (SSAnnounce == true) then
		if (IsInRaid(LE_PARTY_CATEGORY_HOME)) then
			channel = "RAID"
		elseif (IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) then
			channel = "INSTANCE_CHAT"
		elseif (isParty) then
			channel = "PARTY"
		end
	else
		channel = nil
	end
	
	--SPELL_STOLEN,0x05000000045E6EDB,"Alfabravo",0x511,0x0,0x06800000006AC840,"Pison-Drenden",0x10548,0x0,21562,"Power Word: Fortitude",0x2,0x06800000006AC840,63325,48,9789,0,186685,30449,"Spellsteal",64,BUFF
	
	if (event == "PLAYER_TARGET_CHANGED") then
		SSFrameUpdate()
	elseif(event == "UNIT_TARGET" and select(1,...) == "player") then
		SSFrameUpdate()
	elseif (event == "PLAYER_DEAD") then
		SSFrameUpdate()
	elseif (event == "COMBAT_LOG_EVENT_UNFILTERED")	 then
		local cEvent, _, sourceGUID, sourceName, _,_, destGUID, destName = select(2, ...)
		local spellID = select(15,...)
		
		if (cEvent == "SPELL_STOLEN" and sourceGUID == UnitGUID("player")) then
			
			local msg = "Stole:"..GetSpellLink(spellID)
			local name, _, icon, _,_, _, _, _, _ = C_Spell.GetSpellInfo(spellID)
			
			if(GetCVar("enableCombatText") == '1') then
				CombatText_AddMessage(msg, CombatText_StandardScroll, 0.10, 0, 1, "sticky", nil);
			end
			if MikSBT then
				MikSBT.DisplayMessage(msg,MikSBT.DISPLAYTYPE_NOTIFICATION, true, 255, 255, 255, nil, nil, nil, icon)
			end
			if SCT then
				local rgbcolor = { r=1, g=1, b=1 };
				SCT:DisplayMessage(msg, rgbcolor);
			end
  			if Parrot then
				Parrot:ShowMessage(msg, "Notification", true, 1, 1, 1, nil, nil, "NORMAL", icon);
			end
			
			if (channel ~= nil) then
				local msg = "I have stolen "..GetSpellLink(spellID).." from "..destName
				SendChatMessage(msg, channel)
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cffFFFFFFYou have stolen:"..GetSpellLink(spellID).." from "..destName)
			end
				
			SSFrameUpdate()
	    	end
	elseif (event == "UNIT_AURA" and select(1,...) == "target") then
		
		SSFrameUpdate()
	end
end


function SSFrameCreate()
   
	local backdrop = {bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 3, left=2, right=2, top=2, bottom=2}
	
	if not SSFrame then
		SSFrame = CreateFrame("Frame", "SSFrame", UIParent)
		SSFrame:SetClampedToScreen(true)
		SSFrame:SetFrameStrata("HIGH")
		SSFrame:SetBackdrop(backdrop)
		SSFrame:SetBackdropColor(0,0,0,1)
		SSFrame:SetWidth(220)
		SSFrame:SetHeight(20) 
		SSFrame:SetPoint("CENTER",0,0)
		SSFrame:EnableMouse(true)
		SSFrame:SetMovable(true)
		SSFrame:RegisterForDrag("RightButton")
		SSFrame:SetUserPlaced(true)
		
		SSFrame.Locked = true
			
		SSFrame:SetScript('OnMouseDown', function(self) 
			if (self.Locked == false) then
				self:StartMoving()
				self.IsMoving = true
			end
		end)
		SSFrame:SetScript('OnMouseUp', function(self)
			if (self.Locked == false) then
				self:StopMovingOrSizing()
				self.IsMoving = false
			end
		end)
		SSFrame:SetScript("OnShow", function(self)
			SSFrameList:Show()
			if (SSAnnounce == true) then 
				SSFrametitle:SetText("SimpleSpellsteal (announce mode)")
			else
				SSFrametitle:SetText("SimpleSpellsteal")
			end
		end)
		
		SSFrame:SetScript("OnHide", function(self)
			if ( self.isMoving ) then
				self:StopMovingOrSizing();
				self.isMoving = false;
			end
		end)
		
		SSFrametitle = SSFrame:CreateFontString("SSFrametitletext", "OVERLAY")
		SSFrametitle:SetFont("Fonts\\FRIZQT__.TTF", 12)
		SSFrametitle:SetJustifyH("LEFT")
		

		if (SSAnnounce == true) then
			SSFrametitle:SetText("SimpleSpellsteal (announce mode)")
		else
			SSFrametitle:SetText("SimpleSpellsteal")
		end
		SSFrametitle:SetPoint("TOPLEFT", 0, -4)
				
		
		SSFrameList = CreateFrame("Frame", "SSFrameList", SSFrame)
		SSFrameList:SetFrameStrata("HIGH")
		
		if ( SSGrowup == true) then
			SSFrameList:SetPoint("BOTTOMLEFT",0,21)
		else
			SSFrameList:SetPoint("TOPLEFT",0,-21)
		end
		
		SSFrameList:SetWidth(220)
		SSFrameList:SetHeight(80)
		SSFrameList:SetBackdrop(backdrop)
		SSFrameList:SetBackdropColor(1,0,0,.5)
		SSFrameList:SetBackdropBorderColor(0,0,0)
		SSFrameList.elapsed = 0
		SSFrameList.DisplayText = SSFrameList:CreateFontString("SSFrameListText", "OVERLAY", SSFrameList)
		SSFrameList.DisplayText:SetFont("Fonts\\FRIZQT__.TTF", 10)
		SSFrameList.DisplayText:SetJustifyH("LEFT")
		SSFrameList.DisplayText:SetPoint("LEFT")
	end
end

