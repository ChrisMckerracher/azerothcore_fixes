-- Bare Necessities: shared periodic tick for player needs

local TICK_INTERVAL_SECONDS = 1200000--120
local TICK_INTERVAL_MS = TICK_INTERVAL_SECONDS * 1000

local RESOURCE_REFRESH_INTERVAL_SECONDS = 120000000--3
local RESOURCE_REFRESH_INTERVAL_MS = RESOURCE_REFRESH_INTERVAL_SECONDS * 1000

local RESOURCES = {
    Hunger = Necessity:new({ column = "Hunger", label = "hunger", decrement_step = 1, increment_step = 1, default = 5, minimum = 0, maximum = 5, debuff_spell = DEBUFFS.DAZED }),
    Thirst = Necessity:new({ column = "Thirst", label = "thirst", decrement_step = 1, increment_step = 1, default = 5, minimum = 0, maximum = 5, debuff_spell = DEBUFFS.DAZED }),
    Rest = Necessity:new({ column = "Rest", label = "fatigue", decrement_step = 10, increment_step = 2, default = 50, minimum = 0, maximum = 50, debuff_spell = DEBUFFS.DAZED, notify_modulus = 10 })
}

local RESOURCE_ORDER = { "Hunger", "Thirst", "Rest" }

local STATUS_ADDON_PREFIX = "BNSTAT"

--[[
Status Broadcast Format
prefix: BNSTAT (addon message prefix)
payload: "PlayerName|label=value,label=value"
example: "Fizzlesprocket|hunger=45,thirst=32,fatigue=50,damage=48"
Addons can consume via RegisterAddonMessagePrefix("BNSTAT") and listening to CHAT_MSG_ADDON.
]]

local function format_status_value(value)
    if math.floor(value) == value then
        return string.format("%d", value)
    end

    return string.format("%.2f", value)
end

local function refreshResourceDebuffs()
    local players = GetPlayersInWorld()
    if not players then
        return
    end

    local resource_map = NecessityResources or RESOURCES
    local order = NecessityResourceOrder or RESOURCE_ORDER

    for _, player in pairs(players) do
        if player and player:IsInWorld() then
            local status_parts = {}
            for _, key in ipairs(order) do
                local resource = resource_map and resource_map[key]
                if resource then
                    local current = select(1, resource:fetch(player:GetName()))
                    table.insert(status_parts, string.format("%s=%s", resource.label, format_status_value(current)))

                    if resource.debuff_spell then
                        if current <= resource.minimum then
                            if not player:HasAura(resource.debuff_spell) then
                                player:AddAura(resource.debuff_spell, player)
                            end
                        elseif resource.debuff_spell == DEBUFFS.RESURRECTION_SICKNESS and player:HasAura(resource.debuff_spell) then
                            player:RemoveAura(resource.debuff_spell)
                        end
                    end
                end
            end

            if type(DamageResourceRefresh) == "function" then
                DamageResourceRefresh(player)
            end

            if #status_parts > 0 then
                local payload = string.format("%s|%s", player:GetName(), table.concat(status_parts, ","))
                player:SendAddonMessage(STATUS_ADDON_PREFIX, payload, 0x07, player)
            end
        end
    end
end

NecessityResources = NecessityResources or {}
for key, resource in pairs(RESOURCES) do
    if not NecessityResources[key] then
        NecessityResources[key] = resource
    end
end

NecessityResourceOrder = NecessityResourceOrder or {}
local seen_order = {}
for _, key in ipairs(NecessityResourceOrder) do
    seen_order[key] = true
end
for _, key in ipairs(RESOURCE_ORDER) do
    if not seen_order[key] then
        table.insert(NecessityResourceOrder, key)
        seen_order[key] = true
    end
end

local function runTick()
    local players = GetPlayersInWorld()
    if not players then
        return
    end

    for _, key in ipairs(RESOURCE_ORDER) do
        local resource = RESOURCES[key]
        local filtered = {}
        for _, player in pairs(players) do
            if player and player:IsAlive() then
                table.insert(filtered, player)
            end
        end

        if #filtered > 0 then
            resource:tick(filtered)
        end
    end
end

CreateLuaEvent(runTick, TICK_INTERVAL_MS, 0)
CreateLuaEvent(refreshResourceDebuffs, RESOURCE_REFRESH_INTERVAL_MS, 0)
refreshResourceDebuffs()
