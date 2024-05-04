local mod = RegisterMod("Heart Resourcing", 1)

mod.IGNORE_LIST = {
    [HeartSubType.HEART_BONE] = true,
    [HeartSubType.HEART_GOLDEN] = true,
    [HeartSubType.HEART_ROTTEN] = true,
    [HeartSubType.HEART_ETERNAL] = true,
}

mod.HEART_VALUES = {
    [HeartSubType.HEART_BLENDED] = 2,
    [HeartSubType.HEART_DOUBLEPACK] = 4,
    [HeartSubType.HEART_FULL] = 2,
    [HeartSubType.HEART_HALF] = 1,
    [HeartSubType.HEART_SCARED] = 2,
}

mod.SOUL_VALUES = {
    [HeartSubType.HEART_BLACK] = 2,
    [HeartSubType.HEART_SOUL] = 2,
    [HeartSubType.HEART_HALF_SOUL] = 1,
    [HeartSubType.HEART_BLENDED] = 2,
}

---@type table<EntityPtr, { player: EntityPtr, heartAmnt: integer, soulAmnt: integer }>
local pickupList = {}

---comment
---@param pickup EntityPickup
---@param other Entity
---@param low boolean
function mod:OnPickupCollision(pickup, other, low)
    local player = other:ToPlayer()
    if player and pickup.Variant == PickupVariant.PICKUP_HEART then
        pickupList[EntityPtr(pickup)] = { player = EntityPtr(player), heartAmnt = player:GetHearts(), soulAmnt = player:GetSoulHearts() }
    end
end

mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, mod.OnPickupCollision)

---comment
function mod:OnUpdate()
    for pickup, playerData in pairs(pickupList) do
        if pickup.Ref:IsDead() then
            local type = pickup.Ref.SubType
            local player = playerData.player.Ref:ToPlayer()
            if not mod.IGNORE_LIST[type] and player and player:GetHealthType() ~= HealthType.LOST then
                if mod.SOUL_VALUES[type] and player:GetPlayerType() ~= PlayerType.PLAYER_BETHANY then
                    local excessAmnt = (playerData.soulAmnt + mod.SOUL_VALUES[type]) - player:GetSoulHearts()
                    while excessAmnt > 0 do
                        if excessAmnt >= 2 then
                            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL,
                                Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true), Vector.Zero, player)
                            excessAmnt = excessAmnt - 2
                        else
                            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_HALF_SOUL,
                                Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true), Vector.Zero, player)
                            excessAmnt = excessAmnt - 1
                        end
                    end
                elseif mod.HEART_VALUES[type] and player:GetPlayerType() ~= PlayerType.PLAYER_BETHANY_B then
                    local excessAmnt = (playerData.heartAmnt + mod.HEART_VALUES[type]) - player:GetHearts()
                    while excessAmnt > 0 do
                        if excessAmnt >= 2 then
                            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_FULL,
                                Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true), Vector.Zero, player)
                            excessAmnt = excessAmnt - 2
                        else
                            Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_HALF,
                                Game():GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true), Vector.Zero, player)
                            excessAmnt = excessAmnt - 1
                        end
                    end
                end
            end
        end
    end

    pickupList = {}
end

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.OnUpdate)