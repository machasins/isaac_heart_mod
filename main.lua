NoHeartWaste = RegisterMod("Heart Resourcing", 1)

-- Hearts to ignore
---@type table<HeartSubType, boolean>
NoHeartWaste.IGNORE_LIST = {
    [HeartSubType.HEART_BONE] = true,
    [HeartSubType.HEART_GOLDEN] = true,
    [HeartSubType.HEART_ROTTEN] = true,
    [HeartSubType.HEART_ETERNAL] = true,
}

-- Red and soul heart values
---@type table<HeartSubType, integer>
NoHeartWaste.BOTH_VALUES = {
    [HeartSubType.HEART_BLENDED] = 2,
}

-- Red heart values
---@type table<HeartSubType, integer>
NoHeartWaste.HEART_VALUES = {
    [HeartSubType.HEART_DOUBLEPACK] = 4,
    [HeartSubType.HEART_FULL] = 2,
    [HeartSubType.HEART_HALF] = 1,
    [HeartSubType.HEART_SCARED] = 2,
}

-- Soul heart values
---@type table<HeartSubType, integer>
NoHeartWaste.SOUL_VALUES = {
    [HeartSubType.HEART_BLACK] = 2,
    [HeartSubType.HEART_SOUL] = 2,
    [HeartSubType.HEART_HALF_SOUL] = 1,
}

-- The pickups being processed this frame
-- [key: The pickup entity; value: the player and the amount of red and soul hearts they have before collision]
---@type table<EntityPtr, { player: EntityPtr, otherPlayer: EntityPtr, heartAmnt: integer, soulAmnt: integer }>
local pickupList = {}

---Gets the amount of charge the player has for a specific collectible
---@param player EntityPlayer
---@param id CollectibleType
---@return integer
local function GetActiveItemCharge(player, id)
    local addition = 0
    for i = ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_POCKET2 do
        addition = addition + (player:GetActiveItem(i) == id and player:GetActiveCharge(i) or 0)
    end
    return addition
end

---Get the red hearts of the player
---@param player EntityPlayer
---@return integer
local function GetRedHearts(player)
    -- The player's character type
    local type = player:GetPlayerType()
    -- Additional hearts the player could have
    local addition = player:HasCollectible(CollectibleType.COLLECTIBLE_THE_JAR) and player:GetJarHearts() or 0
    -- Check if T. Bethany
    if type == PlayerType.PLAYER_BETHANY_B then
        -- Get Blood Charges
        return player:GetBloodCharge() + addition
    else
        -- Return red hearts
        return player:GetHearts() + addition
    end
end

---Get the soul hearts of the player
---@param player EntityPlayer
---@return integer
local function GetSoulHearts(player)
    -- The player's character type
    local type = player:GetPlayerType()
    -- Additional hearts the player could have
    local addition = GetActiveItemCharge(player, CollectibleType.COLLECTIBLE_ALABASTER_BOX)
    -- Check if the Forgotten
    if type == PlayerType.PLAYER_THEFORGOTTEN then
        -- Get the Soul's soul hearts
        return player:GetSubPlayer():GetSoulHearts() + addition
    -- Check if Bethany
    elseif type == PlayerType.PLAYER_BETHANY then
        -- Get Soul Charges
        return player:GetSoulCharge() + addition
    else
        -- Return soul hearts
        return player:GetSoulHearts() + addition
    end
end

---Checks whether a heart is interacted with and adds it to a list
---@param pickup EntityPickup
---@param other Entity
function NoHeartWaste:OnPickupCollision(pickup, other)
    -- The player, if it is the other collider
    local player = other:ToPlayer()
    -- Check that the main entity is a heart and that the other entity is a player
    if player and pickup.Variant == PickupVariant.PICKUP_HEART then
        -- Add the pickup to the list, along with the player and their health values
        pickupList[EntityPtr(pickup)] = { player = EntityPtr(player), heartAmnt = GetRedHearts(player), soulAmnt = GetSoulHearts(player) }
    end
end

NoHeartWaste:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, NoHeartWaste.OnPickupCollision)

---Spawn an amount of hearts
---@param amount integer
---@param half HeartSubType
---@param full HeartSubType
---@param player EntityPlayer
local function SpawnHearts(amount, half, full, player)
    -- While the amount of hearts to spawn is greater than 0
    while amount > 0 do
        -- If the amount can support a full heart
        if amount >= 2 then
            -- Spawn a full heart at a random postion
            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, full,
                Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true), Vector.Zero, player)
            -- Reduce the amount to spawn by 2
            amount = amount - 2
        else
            -- Spawn a half heart at a random position
            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, half,
                Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true), Vector.Zero, player)
            -- Reduce the amount to spawn by 1
            amount = amount - 1
        end
    end
end

---Check whether the player has consumed any hearts
function NoHeartWaste:OnUpdate()
    -- Loop through the pickup list
    for pickup, playerData in pairs(pickupList) do
        -- Check if the pickup is dead
        if pickup.Ref:IsDead() then
            -- The type of heart the pickup is
            local type = pickup.Ref.SubType
            -- The player interacting with the heart
            local player = playerData.player.Ref:ToPlayer()
            -- Check if the heart should be processed and that the player is not a Lost variant (Can't get health)
            if not NoHeartWaste.IGNORE_LIST[type] and player and player:GetHealthType() ~= HealthType.LOST then
                if NoHeartWaste.BOTH_VALUES[type] then
                    -- The excess amount of red hearts
                    local excessRed = (playerData.heartAmnt + NoHeartWaste.BOTH_VALUES[type]) - GetRedHearts(player)
                    -- The excess amount of soul hearts
                    local excessSoul = (playerData.soulAmnt + NoHeartWaste.BOTH_VALUES[type]) - GetSoulHearts(player)
                    -- Whether to spawn any hearts
                    local doSpawn = (excessRed + excessSoul) ~= NoHeartWaste.BOTH_VALUES[type]
                    -- Spawn red hearts
                    if doSpawn and excessRed < excessSoul then
                        SpawnHearts(excessRed, HeartSubType.HEART_HALF, HeartSubType.HEART_FULL, player)
                    -- Spawn soul hearts
                    elseif doSpawn and excessSoul < excessRed then
                        SpawnHearts(excessSoul, HeartSubType.HEART_HALF_SOUL, HeartSubType.HEART_SOUL, player)
                    end
                -- Check if the heart is a type of soul heart
                elseif NoHeartWaste.SOUL_VALUES[type] then
                    -- The amount of hearts to spawn
                    local excessAmnt = (playerData.soulAmnt + NoHeartWaste.SOUL_VALUES[type]) - GetSoulHearts(player)
                    -- Spawn the extra hearts
                    SpawnHearts(excessAmnt, HeartSubType.HEART_HALF_SOUL, HeartSubType.HEART_SOUL, player)
                -- Check if the heart is a type of red heart
                elseif NoHeartWaste.HEART_VALUES[type] then
                    -- The amount of hearts to spawn
                    local excessAmnt = (playerData.heartAmnt + NoHeartWaste.HEART_VALUES[type]) - GetRedHearts(player)
                    -- Spawn the extra hearts
                    SpawnHearts(excessAmnt, HeartSubType.HEART_HALF, HeartSubType.HEART_FULL, player)
                end
            end
        end
    end

    -- Reset the pickup list
    pickupList = {}
end

NoHeartWaste:AddCallback(ModCallbacks.MC_POST_UPDATE, NoHeartWaste.OnUpdate)