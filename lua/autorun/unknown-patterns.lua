local addon_name = "unknown-patterns@0.1.0"

assert( glua_patches, "Failed to load '" .. addon_name .. "', glua-patches is missing!" )

local presets = list.GetForEdit( "UnknownPatterns", false )

---@class Entity
local ENTITY = FindMetaTable( "Entity" )
local ENTITY_FireBullets = ENTITY.FireBullets
local Entity_IsValid = ENTITY.IsValid

---@class Vector
local VECTOR = FindMetaTable( "Vector" )
local VECTOR_GetNormalized = VECTOR.GetNormalized
local VECTOR_SetUnpacked = VECTOR.SetUnpacked
local VECTOR_Angle = VECTOR.Angle
local VECTOR_Add = VECTOR.Add
local VECTOR_Mul = VECTOR.Mul

---@class Angle
local ANGLE = FindMetaTable( "Angle" )
local ANGLE_Forward = ANGLE.Forward
local ANGLE_Right = ANGLE.Right
local ANGLE_Up = ANGLE.Up

local math = _G.math
local math_rad = math.rad
local math_floor = math.floor
local math_sin, math_cos = math.sin, math.cos

local isfunction = isfunction
local isnumber = isnumber
local os_clock = os.clock

local temp_vector = Vector( 0, 0, 0 )
local vector_origin = vector_origin

local time = os_clock()

hook.Add( "Think", addon_name, function()
    time = os_clock()
end, PRE_HOOK )

---@param entity Entity
---@param bullet Bullet
hook.Add( "EntityFireBullets", addon_name, function( _, entity, bullet )
    local inflictor = bullet.Inflictor
    if inflictor == nil or not Entity_IsValid( inflictor ) then return end

    local preset = presets[ inflictor:GetClass() ]
    if preset == nil then return end

    local bullet_count = bullet.Num
    if bullet_count > 1 then
        bullet.Num = 1

        for _ = 1, bullet_count, 1 do
            ENTITY_FireBullets( entity, bullet, true )
        end

        return
    end

    local time_value = time

    local time_offset = preset.time_offset
    if time_offset ~= nil then
        if isfunction( time_offset ) then
            ---@cast time_offset fun( t: number ): number
            time = time + ( time_offset( time_value ) or 0 )
        elseif isnumber( time_offset ) then
            ---@type number
            time = time + time_offset
        end
    end

    local time_multiplier = preset.time_multiplier
    if time_multiplier ~= nil then
        if isfunction( time_multiplier ) then
            ---@cast time_multiplier fun( t: number ): number
            time_value = time_value * ( time_multiplier( time_value ) or 1 )
        elseif isnumber( time_multiplier ) then
            ---@type number
            time_value = time_value * time_multiplier
        end
    end

    local fraction = time_value - math_floor( time_value )

    ---@type function[]
    local pattern = preset.pattern
    if pattern == nil then return end

    ---@type fun( f: number, t: number ): number
    local fn = pattern[ ( math_floor( time_value ) % #pattern ) + 1 ]
    if fn == nil then return end

    local x, y = fn( fraction, time_value )

    local scale_multiplier = preset.scale_multiplier
    if scale_multiplier ~= nil then
        local multiplier = 1

        if isfunction( scale_multiplier ) then
            ---@cast scale_multiplier fun( f: number, t: number, x: number, y: number ): number
            multiplier = scale_multiplier( fraction, x, y, time_value ) or multiplier
        elseif isnumber( scale_multiplier ) then
            ---@type number
            multiplier = scale_multiplier
        end

        x, y = x * multiplier, y * multiplier
    end

    local rotation = preset.rotation
    if rotation ~= nil then
        local radians = 0

        if isfunction( rotation ) then
            ---@cast rotation fun( f: number, x: number, y: number, t: number ): number
            radians = rotation( fraction, x, y, time_value ) or radians
        elseif isnumber( rotation ) then
            ---@type number
            radians = math_rad( rotation )
        end

        x, y = x * math_cos( radians ) - y * math_sin( radians ), x * math_sin( radians ) + y * math_cos( radians )
    end

    local spread = preset.spread
    if spread ~= nil and isfunction( spread ) then
        ---@cast spread fun( x: number, y: number, f: number, t: number ): number, number
        x, y = spread( x, y, fraction, time_value )
    end

    VECTOR_SetUnpacked( temp_vector, 0, 0, 0 )

    local angles = VECTOR_Angle( bullet.Dir )

    VECTOR_Add( temp_vector, ANGLE_Forward( angles ) )

    local right = ANGLE_Right( angles )
    VECTOR_Mul( right, x )
    VECTOR_Add( temp_vector, right )

    local up = ANGLE_Up( angles )
    VECTOR_Mul( up, y )
    VECTOR_Add( temp_vector, up )

    bullet.Dir = VECTOR_GetNormalized( temp_vector )
    bullet.Spread = vector_origin

    return true
end, POST_HOOK_RETURN )
