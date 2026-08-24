local objectiveState = {}

local function GetQuestIdByTitle(questTitle)
    if not questTitle or not pfDB or not pfDB["quests"] or not pfDB["quests"]["enUS"] then
        return nil
    end

    for questId, localizedData in pairs(pfDB["quests"]["enUS"]) do
        if localizedData["T"] == questTitle then
            return questId
        end
    end

    return nil
end

local function FindQuestForObjective(objectiveName)
    local originalSelection = GetQuestLogSelection()
    local numQuestLogEntries = GetNumQuestLogEntries()

    for i = 1, numQuestLogEntries do
        local questTitle, level, questTag, isHeader = pfQuestCompat.GetQuestLogTitle(i)

        if not isHeader and questTitle then
            SelectQuestLogEntry(i)
            local numObjectives = GetNumQuestLeaderBoards()

            for j = 1, numObjectives do
                local description = GetQuestLogLeaderBoard(j)

                if description then
                    local objName = string.match(description, "(.*):%s*[-%d]+%s*/%s*[-%d]+%s*$")

                    if objName and string.find(string.lower(objName), string.lower(objectiveName), 1, true) then
                        SelectQuestLogEntry(originalSelection)
                        return questTitle, GetQuestIdByTitle(questTitle)
                    end
                end
            end
        end
    end

    SelectQuestLogEntry(originalSelection)
    return nil, nil
end

local function GetItemIdForObjective(objectiveName, questId)
    if questId and pfDB and pfDB["quests"] and pfDB["quests"]["data"] then
        local questData = pfDB["quests"]["data"][questId]

        if questData and questData["obj"] and questData["obj"]["I"] then
            for _, itemId in pairs(questData["obj"]["I"]) do
                local itemName = GetItemInfo(itemId)

                if itemName and string.find(string.lower(objectiveName), string.lower(itemName), 1, true) then
                    return itemId
                end
            end
        end
    end

    local originalSelection = GetQuestLogSelection()
    local questText = GetQuestLogQuestText()
    if questText then
        local _, _, itemId = string.find(questText, "item:(%d+)")
        if itemId then
            SelectQuestLogEntry(originalSelection)
            return tonumber(itemId)
        end
    end

    SelectQuestLogEntry(originalSelection)
    return nil
end

local function OnQuestUpdate(message, previewOnly)
    if GetNumPartyMembers() == 0 and not previewOnly then
        return
    end

    if not message or type(message) ~= "string" then
        return
    end

    local itemName, numItems, numNeeded = string.match(message, "(.*):%s*([-%d]+)%s*/%s*([-%d]+)%s*$")

    if itemName and numItems and numNeeded then
        local iNumItems = tonumber(numItems)
        local iNumNeeded = tonumber(numNeeded)
        local stillNeeded = iNumNeeded - iNumItems

        if not objectiveState[itemName] then
            objectiveState[itemName] = {lastCount = 0, announced = false}
        end

        if objectiveState[itemName].lastCount == iNumItems then
            return
        end

        objectiveState[itemName].lastCount = iNumItems

        local questName, questId = FindQuestForObjective(itemName)
        local itemId = GetItemIdForObjective(itemName, questId)
        local itemLink = nil

        if itemId then
            local name, link = GetItemInfo(itemId)
            if link and string.find(link, "|H") then
                itemLink = link
            end
        end

        local outMessage

        if stillNeeded < 1 then
            if pfQuest_config["announceFinished"] == "1" then
                if not objectiveState[itemName].announced then
                    objectiveState[itemName].announced = true

                    if pfQuest_config["announceShowItem"] == "1" and itemLink then
                        if questName then
                            outMessage = "Finished " .. itemLink .. " for " .. questName .. "."
                        else
                            outMessage = "I have finished collecting " .. itemLink .. "."
                        end
                    else
                        if questName then
                            outMessage = "Finished " .. itemName .. " for " .. questName .. "."
                        else
                            outMessage = "I have finished " .. itemName .. "."
                        end
                    end
                end
            end
        else
            objectiveState[itemName].announced = false

            if pfQuest_config["announceRemaining"] == "1" then
                local displayItem = itemLink or itemName

                if questName then
                    outMessage = "" .. displayItem .. " for " .. questName .. " (" .. stillNeeded .. " left)"
                else
                    outMessage = "" .. displayItem .. " (" .. stillNeeded .. " left)"
                end
            end
        end

        if outMessage and outMessage ~= "" then
            if previewOnly then
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[Announce preview]|r " .. outMessage)
            else
                SendChatMessage(outMessage, "PARTY")
            end
        end
    end
end

local questAnnounceFrame = CreateFrame("Frame", "pfQuestTurtleAnnounce")
questAnnounceFrame:RegisterEvent("UI_INFO_MESSAGE")
questAnnounceFrame:SetScript("OnEvent", function()
    if event == "UI_INFO_MESSAGE" and arg1 then
        OnQuestUpdate(arg1)
    end
end)

local function ExtendPfQuestConfig()
    if not pfQuest_defconfig or not pfQuestConfig then
        return false
    end

    local found = false
    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "announceFinished" then
            found = true
            break
        end
    end

    if found then
        return true
    end

    table.insert(pfQuest_defconfig, { text = "|cff33ffccAnnounce|r", type = "header" })
    table.insert(pfQuest_defconfig, { text = "Announce Finished Quest Objectives", default = "0", type = "checkbox", config = "announceFinished" })
    table.insert(pfQuest_defconfig, { text = "Announce Remaining Quest Objectives", default = "0", type = "checkbox", config = "announceRemaining" })
    table.insert(pfQuest_defconfig, { text = "Show Item Link in Finished Announcement", default = "1", type = "checkbox", config = "announceShowItem" })

    pfQuest_config["announceFinished"] = pfQuest_config["announceFinished"] or "0"
    pfQuest_config["announceRemaining"] = pfQuest_config["announceRemaining"] or "0"
    pfQuest_config["announceShowItem"] = pfQuest_config["announceShowItem"] or "1"

    return true
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", function()
    ExtendPfQuestConfig()
end)

local function SetupAnnounceCommands()
    local currentHandler = SlashCmdList["PFDB"]

    SlashCmdList["PFDB"] = function(input, editbox)
        local commandlist = {}

        for word in string.gfind(input, "[^%s]+") do
            table.insert(commandlist, word)
        end

        local arg1local = commandlist[1] and string.lower(commandlist[1])
        local arg2local = commandlist[2] and string.lower(commandlist[2])
        local arg3local = commandlist[3] and string.lower(commandlist[3])

        if arg1local == "announce" then
            if arg2local == "finished" then
                if arg3local == "on" then
                    pfQuest_config["announceFinished"] = "1"
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: Finished quest announcements enabled")
                    return
                elseif arg3local == "off" then
                    pfQuest_config["announceFinished"] = "0"
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: Finished quest announcements disabled")
                    return
                end
            elseif arg2local == "remaining" then
                if arg3local == "on" then
                    pfQuest_config["announceRemaining"] = "1"
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: Remaining quest announcements enabled")
                    return
                elseif arg3local == "off" then
                    pfQuest_config["announceRemaining"] = "0"
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: Remaining quest announcements disabled")
                    return
                end
            elseif arg2local == "item" then
                if arg3local == "on" then
                    pfQuest_config["announceShowItem"] = "1"
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: Item links in announcements enabled")
                    return
                elseif arg3local == "off" then
                    pfQuest_config["announceShowItem"] = "0"
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: Item links in announcements disabled")
                    return
                end
            elseif arg2local == "test" then
                local _, _, fakeMessage = string.find(input, "test%s+(.+)$")
                if fakeMessage then
                    OnQuestUpdate(fakeMessage, true)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r: Usage: /pfdb announce test ItemName: 3/10")
                end
                return
            elseif not arg2local then
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest|r Announce commands:")
                DEFAULT_CHAT_FRAME:AddMessage("  /pfdb announce finished on|off")
                DEFAULT_CHAT_FRAME:AddMessage("  /pfdb announce remaining on|off")
                DEFAULT_CHAT_FRAME:AddMessage("  /pfdb announce item on|off")
                DEFAULT_CHAT_FRAME:AddMessage("  /pfdb announce test <ItemName>: <cur>/<total> - preview a progress popup, never sent to party")
                return
            end
        end

        if currentHandler then
            currentHandler(input, editbox)
        end
    end
end

local commandSetupFrame = CreateFrame("Frame")
commandSetupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
commandSetupFrame:SetScript("OnEvent", function()
    local timer = 0
    this:SetScript("OnUpdate", function()
        timer = timer + 1
        if timer > 60 then
            SetupAnnounceCommands()
            this:SetScript("OnUpdate", nil)
            this:UnregisterAllEvents()
        end
    end)
end)
