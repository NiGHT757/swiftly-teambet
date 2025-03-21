local _gPlayerInfo = {}
local _gIsBetRestricted = false

AddEventHandler("OnPluginStart", function (event)
    config:Create("teambet", {
        min_bet_amount = 1,
        max_bet_amount = 16000
    })
end)

AddEventHandler("OnRoundStart", function()
    _gPlayerInfo = {}
    _gIsBetRestricted = false
end)

AddEventHandler("OnClientDisconnect", function(_, playerid)
    _gPlayerInfo[playerid] = nil
end)

AddEventHandler("OnRoundEnd", function(event)
    _gIsBetRestricted = true

    local count = 0
    for _ in pairs(_gPlayerInfo) do
        count = count + 1
    end

    if count == 0 then return end

    for k, v in pairs(_gPlayerInfo) do
        local player = GetPlayer(k)
        if not player or not player:IsValid() or player:CBasePlayerController().Connected ~= PlayerConnectedState.PlayerConnected then return end

        local playerMoney = player:CCSPlayerController().InGameMoneyServices.Account
        local maxMoney = convar:Get("mp_maxmoney")

        if v[1] == event:GetInt("winner") then
            local amount
            if playerMoney + (v[2] * 2) > maxMoney then
                amount = maxMoney
            else
                amount = playerMoney + (v[2] * 2)
            end

            player:CCSPlayerController().InGameMoneyServices.Account = tonumber(amount) or 0
            ReplyToCommand(k, FetchTranslation("teambet.prefix", k), FetchTranslation("teambet.won", k):gsub("{amount}", tostring(amount)))
        else
            ReplyToCommand(k, FetchTranslation("teambet.prefix", k), FetchTranslation("teambet.lost", k):gsub("{amount}", v[2]))
        end

        _gPlayerInfo[k] = nil
    end
end)

AddEventHandler("OnClientChat", function(event, playerid, text, teamonly)
    local player = GetPlayer(playerid)
    if not player or not player:IsValid() then return end

    if text:sub(1, 1) == "!" or text:sub(1, 1) == "/" then return end

    if not text or text:match("^%s*$") then return end
    local args = text:split(" ")
    local argc = #args

    if args[1]:lower() ~= "bet" then return end

    if argc < 3 then
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid), FetchTranslation("teambet.usage", playerid))
        return
    end

    local teams = {"", "{RED}T{DEFAULT}", "{BLUE}CT{DEFAULT}"}

    if _gPlayerInfo[playerid] ~= nil then
        local msg = FetchTranslation("teambet.alreadyBet", playerid)
            :gsub("{team}", teams[_gPlayerInfo[playerid][1]])
            :gsub("{amount}", _gPlayerInfo[playerid][2])
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid), msg)
        return
    end

    if player:CBaseEntity().LifeState == LifeState_t.LIFE_ALIVE or player:CCSPlayerController().ControllingBot then
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid), FetchTranslation("teambet.betAlive", playerid))
        return
    end

    if _gIsBetRestricted or GetCCSGameRules().WarmupPeriod then
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid), FetchTranslation("teambet.restrictedBet", playerid))
        return
    end

    if player:CBaseEntity().TeamNum <= Team.Spectator then
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid), FetchTranslation("teambet.restrictedTeam", playerid))
        return
    end

    if not HasTeamAlivePlayers(Team.CT) or not HasTeamAlivePlayers(Team.T) then
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid), FetchTranslation("teambet.allPlayersDeath", playerid))
        return
    end

    local team = args[2]:lower() == "t" and Team.T or args[2]:lower() == "ct" and Team.CT
    if not team then
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid), FetchTranslation("teambet.invalidTeam", playerid))
        return
    end

    local playerMoney = player:CCSPlayerController().InGameMoneyServices.Account
    local maxMoney = convar:Get("mp_maxmoney")

    if playerMoney >= maxMoney then
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid), FetchTranslation("teambet.maxMoney", playerid))
        return
    end

    local betAmount = args[3]:lower() == "all" and playerMoney or tonumber(args[3])
    if betAmount == nil or betAmount < 1 or
       betAmount < config:Fetch("teambet.min_bet_amount") or
       betAmount > config:Fetch("teambet.max_bet_amount") then
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid),
            FetchTranslation("teambet.invalidAmount", playerid)
            :gsub("{min}", config:Fetch("teambet.min_bet_amount"))
            :gsub("{max}", config:Fetch("teambet.max_bet_amount")))
        return
    end

    if playerMoney < betAmount then
        ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid),
            FetchTranslation("teambet.notEnoughMoney", playerid)
            :gsub("{money}", betAmount - playerMoney)
            :gsub("{amount}", betAmount))
        return
    end

    _gPlayerInfo[playerid] = {team, betAmount}
    player:CCSPlayerController().InGameMoneyServices.Account = playerMoney - betAmount

    ReplyToCommand(playerid, FetchTranslation("teambet.prefix", playerid),
        FetchTranslation("teambet.bet", playerid)
        :gsub("{amount}", betAmount)
        :gsub("{team}", teams[_gPlayerInfo[playerid][1]]))
end)


function HasTeamAlivePlayers(team)
    for i = 0, playermanager:GetPlayerCap() - 1, 1 do
        local player = GetPlayer(i)
        if player ~= nil and player:IsValid() and player:CBasePlayerController().Connected == PlayerConnectedState.PlayerConnected and player:CBaseEntity().TeamNum == team and player:CBaseEntity().LifeState == LifeState_t.LIFE_ALIVE then
            return true
        end
    end
    return false
end