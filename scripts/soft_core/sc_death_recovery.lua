local level_loss_range = {
    [1] = 10,
    [10] = 5,
    [20] = 2.5,
    [30] = 1.5,
    [40] = 1,
    [50] = 0.5,
    [60] = 0,
    [61] = 0.25,
    [70] = 0,
    [71] = 0.25,
    [80] = 0,
}

local dungeon_loss_range = {
    [1] = 10,
    [10] = 0.5,
    [20] = 0.25,
    [30] = 0.1,
    [40] = 0.1,
    [50] = 0.1,
    [60] = 0,
    [61] = 0.1,
    [70] = 0,
    [71] = 0.1,
    [80] = 0,
}

local function lowerLevel(player, range_map)
    local level = player:GetLevel()
    local min_level = 1
    local level_loss = 10

    for _, k in pairs(get_sorted_keys(range_map)) do
        if k > level then
            break
        end
        min_level = k
        level_loss = range_map[k]
    end

    setLevel(player, level_loss, min_level)
end

local function onDungeonDeath(_, player)
    -- the only time to press resurrect is when you are in dungeon
    player:ResurrectPlayer()
    lowerLevel(player, dungeon_loss_range)
end

local function onOutdoorDeathInternal(player)
    local map = player:GetMap()
    if map ~= nil and (map:IsDungeon() or map:IsBattleground() or map:IsRaid()) then
        return
    end
    player:ResurrectPlayer()
    lowerLevel(player, level_loss_range)
    if player:IsAlliance() then
        player:TeleportTo("Stormwind")
        return
    end
    player:TeleportTo("Orgrimmar")
end

local function onOutdoorDeath(_, _, player)
    onOutdoorDeathInternal(player)
end

RegisterPlayerEvent(8, onOutdoorDeath)
RegisterPlayerEvent(35, onDungeonDeath)
