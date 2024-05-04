local mod = RegisterMod("Heart Resourcing", 1)

-- Hearts to ignore
---@type table<HeartSubType, boolean>
mod.IGNORE_LIST = {
    [HeartSubType.HEART_BONE] = true,
    [HeartSubType.HEART_GOLDEN] = true,
    [HeartSubType.HEART_ROTTEN] = true,
    [HeartSubType.HEART_ETERNAL] = true,
}

-- Red and soul heart values
---@type table<HeartSubType, integer>
mod.BOTH_VALUES = {
    [HeartSubType.HEART_BLENDED] = 2,
}

-- Red heart values
---@type table<HeartSubType, integer>
mod.HEART_VALUES = {
    [HeartSubType.HEART_DOUBLEPACK] = 4,
    [HeartSubType.HEART_FULL] = 2,
    [HeartSubType.HEART_HALF] = 1,
    [HeartSubType.HEART_SCARED] = 2,
}

-- Soul heart values
---@type table<HeartSubType, integer>
mod.SOUL_VALUES = {
    [HeartSubType.HEART_BLACK] = 2,
    [HeartSubType.HEART_SOUL] = 2,
    [HeartSubType.HEART_HALF_SOUL] = 1,
}

-- The pickups being processed this frame
-- [key: The pickup entity; value: the player and the amount of red and soul hearts they have before collision]
---@type table<EntityPtr, { player: EntityPtr, heartAmnt: integer, soulAmnt: integer }>
local pickupList = {}

---Checks whether a heart is interacted with and adds it to a list
---@param pickup EntityPickup
---@param other Entity
---@param low boolean
function mod:OnPickupCollision(pickup, other, low)
    -- The player, if it is the other collider
    local player = other:ToPlayer()
    -- Check that the main entity is a heart and that the other entity is a player
    if player and pickup.Variant == PickupVariant.PICKUP_HEART then
        -- Add the pickup to the list, along with the player and their health values
        pickupList[EntityPtr(pickup)] = { player = EntityPtr(player), heartAmnt = player:GetHearts(), soulAmnt = player:GetSoulHearts() }
    end
end

mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, mod.OnPickupCollision)

---comment
---@param amount integer
---@param half HeartSubType
---@param full HeartSubType
---@param player EntityPlayer
local function SpawnHearts(amount, half, full, player)
    while amount > 0 do
        if amount >= 2 then
            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, full,
                Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true), Vector.Zero, player)
            amount = amount - 2
        else
            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, half,
                Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true), Vector.Zero, player)
            amount = amount - 1
        end
    end
end

---Check whether the player has consumed any hearts
function mod:OnUpdate()
    -- Loop through the pickup list
    for pickup, playerData in pairs(pickupList) do
        -- Check if the pickup is dead
        if pickup.Ref:IsDead() then
            -- The type of heart the pickup is
            local type = pickup.Ref.SubType
            -- The player interacting with the heart
            local player = playerData.player.Ref:ToPlayer()
            -- Check if the heart should be processed and that the player is not a Lost variant (Can't get health)
            if not mod.IGNORE_LIST[type] and player and player:GetHealthType() ~= HealthType.LOST then
                local playerType = player:GetPlayerType()
                -- Check if the heart has a soul value 
                if mod.BOTH_VALUES[type] and playerType ~= PlayerType.PLAYER_BETHANY and playerType ~= PlayerType.PLAYER_BETHANY_B then
                    local excessRed = (playerData.heartAmnt + mod.BOTH_VALUES[type]) - player:GetHearts()
                    local excessSoul = (playerData.soulAmnt + mod.BOTH_VALUES[type]) - player:GetSoulHearts()
                    local doSpawn = (excessRed + excessSoul) ~= mod.BOTH_VALUES[type]
                    print(excessRed, excessSoul, doSpawn)
                    if doSpawn and excessRed > 0 then
                        SpawnHearts(excessRed, HeartSubType.HEART_HALF, HeartSubType.HEART_FULL, player)
                    elseif doSpawn and excessSoul > 0 then
                        SpawnHearts(excessSoul, HeartSubType.HEART_HALF_SOUL, HeartSubType.HEART_SOUL, player)
                    end
                elseif mod.SOUL_VALUES[type] and playerType ~= PlayerType.PLAYER_BETHANY then
                    local excessAmnt = (playerData.soulAmnt + mod.SOUL_VALUES[type]) - player:GetSoulHearts()
                    SpawnHearts(excessAmnt, HeartSubType.HEART_HALF_SOUL, HeartSubType.HEART_SOUL, player)
                elseif mod.HEART_VALUES[type] and playerType ~= PlayerType.PLAYER_BETHANY_B then
                    local excessAmnt = (playerData.heartAmnt + mod.HEART_VALUES[type]) - player:GetHearts()
                    SpawnHearts(excessAmnt, HeartSubType.HEART_HALF, HeartSubType.HEART_FULL, player)
                end
            end
        end
    end

    pickupList = {}
end

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdate)