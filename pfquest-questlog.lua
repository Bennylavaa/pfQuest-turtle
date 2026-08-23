local function ExtendPfQuestConfig()
    -- Check if already added (prevents duplicates)
    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "autoQuests" then
            return true
        end
    end

    table.insert(
        pfQuest_defconfig,
        {
            text = "|cff33ffccQuest automation|r",
            type = "header"
        }
    )

    table.insert(pfQuest_defconfig,
    {
        text = "Automatically accept and complete quests",
        default = "0",
        type = "checkbox",
        config = "autoQuests"
    })

    table.insert(pfQuest_defconfig,
    {
        text = "Skip accepting low level quests",
        default = "0",
        type = "checkbox",
        config = "autoQuestsSkipLowLevel"
    })

    table.insert(pfQuest_defconfig,
    {
        text = "Automate runecloth donations",
        default = "0",
        type = "checkbox",
        config = "automateRuneclothDonations"
    })

    if not pfQuest_config["autoQuests"] then
        pfQuest_config["autoQuests"] = "0"
    end

    if not pfQuest_config["autoQuestsSkipLowLevel"] then
        pfQuest_config["autoQuestsSkipLowLevel"] = "1"
    end

    if not pfQuest_config["automateRuneclothDonations"] then
        pfQuest_config["automateRuneclothDonations"] = "0"
    end

    return true
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", function()
    ExtendPfQuestConfig()
end)

local questLogFrame = CreateFrame("Frame")
questLogFrame:RegisterEvent("QUEST_DETAIL")
questLogFrame:RegisterEvent('GOSSIP_SHOW')
questLogFrame:RegisterEvent('QUEST_COMPLETE')
questLogFrame:RegisterEvent('QUEST_GREETING')
questLogFrame:RegisterEvent('QUEST_PROGRESS')

local function CompleteQuestWithRewards()
    if GetNumQuestChoices() == 0 then
        GetQuestReward()
    end
end

local function SkipLowLevelQuest(isLowLevel)
    return pfQuest_config["autoQuestsSkipLowLevel"] == "1" and isLowLevel
end

local function IsTrivialQuest()
    local title = GetTitleText()
    return string.find(string.lower(title), "low level") ~= nil
end

questLogFrame:SetScript("OnEvent", function()
    if pfQuest_config["autoQuests"] == "0" or IsShiftKeyDown() then
        return
    end

    if event == "QUEST_PROGRESS" then
        if IsQuestCompletable() then
            CompleteQuest()
        end
    end

    if event == "QUEST_COMPLETE" then
        if GetNumQuestChoices() == 0 then
            GetQuestReward()
        elseif QuestFrameRewardPanel.itemChoice and QuestFrameRewardPanel.itemChoice > 0 then
            GetQuestReward(QuestFrameRewardPanel.itemChoice)
        end
    end

    if event == "QUEST_GREETING" then
        local numActiveQuests = GetNumActiveQuests()
        for i=1, numActiveQuests do
            local title, completed = GetActiveTitle(i)
            if completed then
                SelectActiveQuest(i)
                CompleteQuestWithRewards()
            end
        end

        -- The quest dialog closes when the quest gets accepted so no need to do this in a loop
        if GetNumAvailableQuests() >= 1 and not GetAvailableQuestInfo(1) then
            SelectAvailableQuest(1)
        end
    end

    if event == "QUEST_DETAIL" and not IsTrivialQuest() then
        AcceptQuest()
    end

    -- these globals don't exist on this client (unlike WotLK), so skip
    -- gossip-quest automation entirely rather than error every time a
    -- gossip window opens; direct quest-frame automation above still works
    if event == "GOSSIP_SHOW" and GetNumGossipAvailableQuests then
        local numAvailable = GetNumGossipAvailableQuests()
        for i = 1, numAvailable do
            local title,_,isLowLevel = GetGossipAvailableQuests(i)

            if not SkipLowLevelQuest(isLowLevel) then
                SelectGossipAvailableQuest(i)
            end
        end

        local numGossipActiveQuests = GetNumGossipActiveQuests()
        for i = 1, numGossipActiveQuests do
            local activeQuests = { GetGossipActiveQuests() }
            if (activeQuests[i * 4] == 1) then
                SelectGossipActiveQuest(i)
            end
        end

        if pfQuest_config["automateRuneclothDonations"] == "1" and GetNumGossipActiveQuests() == 1 then
            local title = GetGossipActiveQuests(1)
            if string.find(title, "Additional Runecloth") then
                SelectGossipActiveQuest(1)
            end
        end
    end
end)
