-- High-Risk death chest (AzerothCore + Eluna) — FINAL FIX
-- DB: gameobject_template(entry=900001):
--   type=3, faction=0, flags=0, Data0(lockId)=0, Data1(lootid)=0

local DEBUG = true
local function dbg(player, ...)
    return
end

-- Inventory layout
local ROOT = 255
local EQUIP_START, EQUIP_END       = 0, 18
local BAG_SLOT_START, BAG_SLOT_END = 19, 22
local PACK_START, PACK_END         = 23, 38
local KEY_START, KEY_END           = 86, 117
local CURR_START, CURR_END         = 118, 149

-- GO states
local GO_READY = 1
local GO_JUST_DEACTIVATED = 3

-- If your Eluna exposes these constants, great. If not, these guards avoid errors.
local FLAGS_FIELD_OK = (type(GAMEOBJECT_FLAGS) == "number")
local FLAG_LOCKED_OK = (type(GO_FLAG_LOCKED) == "number")
local FLAG_INUSE_OK  = (type(GO_FLAG_IN_USE) == "number")
local FLAG_NS_OK     = (type(GO_FLAG_NOT_SELECTABLE) == "number")

-- Config
local CHEST_ENTRY    = 900001
local CHEST_LIFETIME = 300 -- seconds

-- Per-death de-dupe
local processed = {}

-- Stored drops per spawned chest (by low GUID)
local CHEST_DROPS = {}  -- [chestLowGUID] = { {entry=xxxx, count=n, link="|cff...|r"}, ... }
local CLAIMED     = {}  -- [chestLowGUID] = true once first-click claims it

-- ===== helpers =====

local function notifyLoss(player, item)
  if not item then return end
  local link = item.GetItemLink and item:GetItemLink() or nil
end

local function addDropRecord(chest, item)
  if not chest or not item then return end
  local low = (chest.GetGUIDLow and chest:GetGUIDLow()) or 0
  CHEST_DROPS[low] = CHEST_DROPS[low] or {}
  table.insert(CHEST_DROPS[low], {
    entry = item:GetEntry(),
    count = item:GetCount() or 1,
    link  = item.GetItemLink and item:GetItemLink() or ("item:"..item:GetEntry())
  })
end

-- Put in GO runtime loot (requires lootid == 0), cache for first-click transfer, then remove from player
local function addItemToChestAndRemove(player, chest, item)
  if not player or not chest or not item then return 0 end
  local entry = item:GetEntry()
  local count = item:GetCount() or 1
  if count <= 0 then count = 1 end

  local addedLow = chest:AddLoot(entry, count)
  if DEBUG then dbg(player, "AddLoot entry=%d x%d -> ret=%s", entry, count, tostring(addedLow)) end
  if not addedLow or addedLow == 0 then
    dbg(player, "AddLoot FAILED (entry=%d). Ensure Data1(lootid)=0 and GO is READY", entry)
    return 0
  end

  addDropRecord(chest, item)
  notifyLoss(player, item)
  player:RemoveItem(item, count)
  return 1
end

local function dropEquipped(player, chest)
  local dropped = 0
  for slot = EQUIP_START, EQUIP_END do
    local it = player:GetItemByPos(ROOT, slot)
    if it then
      if DEBUG then dbg(player, "Equipped slot %d -> item %d x%d", slot, it:GetEntry(), it:GetCount() or -1) end
      dropped = dropped + addItemToChestAndRemove(player, chest, it)
    end
  end
  return dropped
end

local function dropBackpack(player, chest)
  local dropped = 0
  for slot = PACK_START, PACK_END do
    local it = player:GetItemByPos(ROOT, slot)
    if it then
      if DEBUG then dbg(player, "Backpack slot %d -> item %d x%d", slot, it:GetEntry(), it:GetCount() or -1) end
      dropped = dropped + addItemToChestAndRemove(player, chest, it)
    end
  end
  return dropped
end

local function dropBagContents(player, chest)
  local dropped = 0
  for bagSlot = BAG_SLOT_START, BAG_SLOT_END do
    local bag = player:GetItemByPos(ROOT, bagSlot)
    if bag then
      local bagSize = bag:GetBagSize() or 0
      if DEBUG then dbg(player, "Bag slot %d (size=%d) -> entry %d", bagSlot, bagSize, bag:GetEntry()) end
      for slot = bagSize - 1, 0, -1 do
        local it = player:GetItemByPos(bagSlot, slot)
        if it then
          if DEBUG then dbg(player, "  Bag[%d] slot %d -> item %d x%d", bagSlot, slot, it:GetEntry(), it:GetCount() or -1) end
          dropped = dropped + addItemToChestAndRemove(player, chest, it)
        end
      end
      dropped = dropped + addItemToChestAndRemove(player, chest, bag)
    end
  end
  return dropped
end

local function dropKeyringAndCurrency(player, chest)
  local dropped = 0
  for slot = KEY_START, KEY_END do
    local it = player:GetItemByPos(ROOT, slot)
    if it then
      if DEBUG then dbg(player, "Keyring slot %d -> item %d x%d", slot, it:GetEntry(), it:GetCount() or -1) end
      dropped = dropped + addItemToChestAndRemove(player, chest, it)
    end
  end
  for slot = CURR_START, CURR_END do
    local it = player:GetItemByPos(ROOT, slot)
    if it then
      if DEBUG then dbg(player, "Currency slot %d -> item %d x%d", slot, it:GetEntry(), it:GetCount() or -1) end
      dropped = dropped + addItemToChestAndRemove(player, chest, it)
    end
  end
  return dropped
end

-- ===== chest spawn =====

local function getLootState(go) return (go and go.GetLootState and go:GetLootState()) or "n/a" end
local function getGoState(go)   return (go and go.GetGoState   and go:GetGoState())   or "n/a" end

local function summonChest(player)
  local x, y, z, o = player:GetX(), player:GetY(), player:GetZ(), player:GetO()
  local dx, dy = math.cos(o) * 0.6, math.sin(o) * 0.6
  local chest = player:SummonGameObject(CHEST_ENTRY, x + dx, y + dy, z + 0.4, o, CHEST_LIFETIME)
  if not chest then
    dbg(player, "SummonGameObject FAILED for %d", CHEST_ENTRY)
    return nil
  end

    ---  In scripts/high-risk/hr_death_drop.lua:154 (inside summonChest) and again at scripts/high-risk/hr_death_drop.lua:206 (after the loot transfer) replace
    --
    --  chest:SetGoState(0)
    --
    --  with
    --
    --  chest:SetGoState(1) -- GO_STATE_READY keeps the lid closed
  -- Clear any residual, set states, and strip lock-related flags if available
  if chest.ClearLoot then chest:ClearLoot() end
  chest:SetLootState(GO_READY)
  if chest.SetGoState then chest:SetGoState(0) end

  if chest.RemoveFlag and FLAGS_FIELD_OK then
    if FLAG_LOCKED_OK then chest:RemoveFlag(GAMEOBJECT_FLAGS, GO_FLAG_LOCKED) end
    if FLAG_INUSE_OK  then chest:RemoveFlag(GAMEOBJECT_FLAGS, GO_FLAG_IN_USE) end
    if FLAG_NS_OK     then chest:RemoveFlag(GAMEOBJECT_FLAGS, GO_FLAG_NOT_SELECTABLE) end
  end

  if DEBUG then
    dbg(player, "Spawned chest guidLow=%s lootState=%s goState=%s",
      tostring(chest.GetGUIDLow and chest:GetGUIDLow() or "n/a"),
      tostring(getLootState(chest)), tostring(getGoState(chest)))
  end

  return chest
end

-- ===== main on-death =====

local function dropPlayerInventory(player, trigger)
  if not player then return end
  local guid = player:GetGUIDLow()

  -- De-dupe early to prevent double-spawn from overlapping events
  if processed[guid] then
    if DEBUG then dbg(player, "skip: already processed this death (trigger=%s)", tostring(trigger)) end
    return
  end
  processed[guid] = true
  if DEBUG then dbg(player, "begin drop (trigger=%s)", tostring(trigger)) end

  local map = player:GetMap()
  if not map then dbg(player, "no map; abort"); return end
  if map:IsDungeon() or map:IsBattleground() or map:IsArena() then
    dbg(player, "instanced map; abort")
    return
  end

  local chest = summonChest(player)
  if not chest then return end

  local dropped = 0
  dropped = dropped + dropEquipped(player, chest)
  dropped = dropped + dropBackpack(player, chest)
  dropped = dropped + dropBagContents(player, chest)
  dropped = dropped + dropKeyringAndCurrency(player, chest)

  chest:SetLootState(GO_READY)
  if chest.SetGoState then chest:SetGoState(0) end

  if DEBUG then
    dbg(player, "final: dropped=%d lootState=%s goState=%s",
      dropped, tostring(getLootState(chest)), tostring(getGoState(chest)))
  end

  if dropped == 0 then
    chest:SetLootState(GO_JUST_DEACTIVATED)
    dbg(player, "no items to drop; deactivated chest")
  end
end

local function clearFlag(player)
  if not player then return end
  processed[player:GetGUIDLow()] = nil
  if DEBUG then dbg(player, "clear processed flag") end
end

-- ===== ON_USE: first click claims and transfers items (bypasses loot window) =====
-- Eluna GameObject event: ON_USE = 14
local function OnChestUse(event, go, player)
  if not go or not player then return end
  local low = go:GetGUIDLow()
  if CLAIMED[low] then
    if DEBUG then dbg(player, "Chest %d already claimed", low) end
    return
  end
  CLAIMED[low] = true

  local drops = CHEST_DROPS[low] or {}
  if DEBUG then dbg(player, "OnUse: chest=%d drops=%d", low, #drops) end

  local moved, failed = 0, 0
  for _, it in ipairs(drops) do
    local ok = player:AddItem(it.entry, it.count)
    if ok then
      moved = moved + 1
    else
      failed = failed + 1
    end
  end

  if go.ClearLoot then go:ClearLoot() end
  go:SetLootState(GO_JUST_DEACTIVATED)
  go:Despawn()

  if DEBUG then dbg(player, "OnUse done: moved=%d failed=%d; chest despawned", moved, failed) end
end

-- ===== events (death-only to avoid double spawn on release) =====
local function OnKillPlayer(_, killer, killed)       dropPlayerInventory(killed, "PvP") end
local function OnKilledByCreature(_, killer, killed) dropPlayerInventory(killed, "PvE") end
local function OnResurrect(_, player)                clearFlag(player) end
local function OnLogout(_, player)                   clearFlag(player) end
local function OnLogin(_, player)                    clearFlag(player) end

RegisterPlayerEvent(6, OnKillPlayer)
RegisterPlayerEvent(8, OnKilledByCreature)
-- RegisterPlayerEvent(35, OnRepop) -- intentionally disabled to prevent “death + release” double spawn
RegisterPlayerEvent(36, OnResurrect)
RegisterPlayerEvent(4, OnLogout)
RegisterPlayerEvent(3, OnLogin)

RegisterGameObjectEvent(CHEST_ENTRY, 14, OnChestUse)  -- ON_USE
