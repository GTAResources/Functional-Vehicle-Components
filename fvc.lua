script_name('Functional Vehicle Components')
script_author("Grinch_")
script_version("1.0-beta")
script_description("Adds more features/ functions to vehicle parts")
script_dependencies("ffi", "Memory", "MoonAdditions", "log")
script_properties('work-in-pause')

--------------------------------------------------
-- Libraries

ffi = require 'ffi'
memory = require 'memory'
mad = require 'MoonAdditions'
log = require 'log'

--------------------------------------------------
-- log

log.usecolor = false
log.outfile = script.this.name .. ".log"

local file_path = string.format("%s//%s", getGameDirectory(), log.outfile)
if doesFileExist(file_path) then os.remove(file_path) end

log.info("Log started")
log.info("Script version " .. script.this.version)
log.info("Please provide both 'moonloader.log' & '" .. log.outfile ..
             "' for debugging")
-- --------------------------------------------------

math.randomseed(os.time())
CVehicleModelInfo = ffi.cast("uintptr_t*", 0xA9B0C8)
isThisModelABike = ffi.cast("bool(*)(int model)", 0x4C5B60)

tmain = {
    name = -- don't change these, update your model instead (character limit 23)
    {
        anim = "fc_anim",
        chain = "fc_chain_ms=(-?%d+)",
        clutch = "fc_cl_z=(-?%d+)",
        dled = "fc_dled",
        fbrake = "fc_fbrake_z=(-?%d+)",
        rbrake = "fc_rbrake_x=(-?%d+)",
        gas_handle = "fc_gas_z=(-?%d+)",
        gear_lever = "fc_gear_x=(-?%d+)_(-?%d+)",
        nled = "fc_nled",
        odometer = "fc_om_x=(-?%d+)",
        pled = "fc_pled",
        speedo = "fc_speedo_y=(-?%d+)_(-?%d+)",
        unit = "unit=(%w+)_max=(-?%d+)"
    },
    veh_data = {}
}

--------------------------------------------------
-- Functions 

function ClearNonExistentVehicleData()
    while true do
        for k, v in pairs(tmain.veh_data) do
            if not doesVehicleExist(k) then tmain.veh_data[k] = nil end
        end
        wait(10000)
    end
end

function GetNameOfVehicleModel(model)
    return ffi.string(ffi.cast("char*",
                               CVehicleModelInfo[tonumber(model)] + 0x32)) or ""
end

function GetComponentData(veh, prefix)
    log.debug("Searching for component data " .. prefix)
    for _, comp in ipairs(mad.get_all_vehicle_components(veh)) do
        if string.match(comp.name, prefix) then
            local t = {string.match(comp.name, prefix)}
            local data = ""

            for k, v in ipairs(t) do data = data .. " " .. v end

            log.debug(string.format("Found %d component data (%s - %s)", #t,
                                    comp.name, data))
            return comp, {string.match(comp.name, prefix)}
        end
    end
end

-- This function is taken from junior's vehfuncs
function GetRealisticSpeed(veh, wheel)

    if not doesVehicleExist(veh) then return end

    local pVeh = getCarPointer(veh)
    local realisticSpeed = 0
    local frontWheelSize = memory.getfloat(
                               CVehicleModelInfo[getCarModel(veh)] + 0x40)
    local rearWheelSize = memory.getfloat(
                              CVehicleModelInfo[getCarModel(veh)] + 0x44)

    if isThisModelABike(getCarModel(veh)) then -- bike
        local fWheelSpeed = ffi.cast("float*", pVeh + 0x758) -- CBike.fWheelSpeed[]

        if wheel == nil then
            realisticSpeed = (fWheelSpeed[1] * frontWheelSize + fWheelSpeed[2] *
                                 rearWheelSize) / 2
        else
            if wheel == 0 then
                realisticSpeed = fWheelSpeed[wheel] * frontWheelSize
            else
                realisticSpeed = fWheelSpeed[wheel] * rearWheelSize
            end
        end
    else
        if isThisModelACar(getCarModel(veh)) then -- bike
            local fWheelSpeed = ffi.cast("float*", pVeh + 0x848) -- Automobile.fWheelSpeed[]
            if wheel == nil then
                realisticSpeed = (fWheelSpeed[1] * frontWheelSize +
                                     fWheelSpeed[2] * frontWheelSize +
                                     fWheelSpeed[3] * rearWheelSize +
                                     fWheelSpeed[4] * rearWheelSize) / 4
            else
                if wheel == 0 or wheel == 1 then
                    realisticSpeed = fWheelSpeed[wheel] * frontWheelSize
                else
                    realisticSpeed = fWheelSpeed[wheel] * rearWheelSize
                end
            end
        else
            wheelSpeed = getCarSpeed(veh) * -0.0426 -- Manually tested
        end
    end

    realisticSpeed = realisticSpeed / 2.45 -- tweak based on distance (manually testing)
    realisticSpeed = realisticSpeed * -186.0 -- tweak based on km/h

    return realisticSpeed
end

function FindAnimations(parent_comp)
    local data = {}

    log.debug("Searching for animations in " .. parent_comp.name)
    for _, child_comp in ipairs(parent_comp:get_child_components()) do
        if child_comp.name == tmain.name.anim then
            for _, child_child_comp in ipairs(child_comp:get_child_components()) do

                local file, anim = string.match(child_child_comp.name,
                                                "([^_]+)_([^_]+)")

                table.insert(data, file)
                table.insert(data, anim)
                log.debug("Found animation " .. anim)
            end
            return data
        end
    end
    return {}
end

function FindChildData(parent_comp, pattern)

    log.debug("Searching for pattern in " .. parent_comp.name)

    for _, child_comp in ipairs(parent_comp:get_child_components()) do
        if string.match(child_comp.name, pattern) then
            return {string.match(child_comp.name, pattern)}
        end
    end

    print("YES")
    return {}
end

function DoesVehicleExist(veh, name)
    if doesVehicleExist(veh) then
        return true
    else
        log.debug("")
        log.debug(string.format("Vehicle doesn't exist. Quiting process %s",
                                name))
        return false
    end
end

function ConvertCheckDataType(data, dtype, index)
    if data == nil then return nil end
    if data[index] == nil then return nil end

    if dtype == "number" then
        data[index] = tonumber(data[index])
        if type(data[index]) == "number" then
            return data[index]
        else
            return nil
        end
    end

    if dtype == "string" then
        data[index] = tostring(data[index])
        if type(data[index]) == "string" then
            return data[index]
        else
            return nil
        end
    end

    return nil

end
--------------------------------------------------
-- Component specific stuff

function FunctionalChain(veh, prefix)

    local chain, tdata = GetComponentData(veh, prefix)
    local model = getCarModel(veh)
    local pVeh = getCarPointer(veh)
    local speed = nil
    local chain_table = {}

    local angle1 = ConvertCheckDataType(tdata, "number", 1)
    if not angle1 then return end

    for _, comp in ipairs(chain:get_child_components()) do
        table.insert(chain_table, comp)
    end

    log.debug("Processing component " .. chain.name)
    while true do

        if not DoesVehicleExist(veh, prefix) then return end

        speed = GetRealisticSpeed(veh, 1)

        if speed >= 1 then
            for i = 1, #chain_table, 1 do
                if not DoesVehicleExist(veh, prefix) then return end

                for j = 1, #chain_table, 1 do
                    if chain_table[i].name == chain_table[j].name then
                        chain_table[j]:set_alpha(255)
                    else
                        chain_table[j]:set_alpha(0)
                    end
                end
                wait(angle1 / math.abs(speed))
            end
        end
        if speed <= -1 then
            for i = #chain_table, 1, -1 do
                if not DoesVehicleExist(veh, prefix) then return end

                for j = 1, #chain_table, 1 do
                    if chain_table[i].name == chain_table[j].name then
                        chain_table[j]:set_alpha(255)
                    else
                        chain_table[j]:set_alpha(0)
                    end
                end
                wait(angle1 / math.abs(speed))
            end
        end
        wait(0)
    end
end

function FunctionalGearLever(veh, prefix)

    local gear_lever, tdata = GetComponentData(veh, prefix)

    local angle1 = ConvertCheckDataType(tdata, "number", 1)
    if not angle1 then return end

    local angle2 = ConvertCheckDataType(tdata, "number", 2)
    if not angle2 then return end

    local matrix = gear_lever.modeling_matrix
    local current_gear = getCarCurrentGear(veh)

    matrix:rotate_x(tonumber(angle1))

    local anims = FindAnimations(gear_lever)

    if anims[1] ~= nil then
        requestAnimation(anims[1])
        loadAllModelsNow()
    end

    log.debug("Processing component " .. gear_lever.name)
    while true do

        if not DoesVehicleExist(veh, prefix) then return end

        if getCarCurrentGear(veh) > current_gear then
            current_gear = getCarCurrentGear(veh)

            if anims[1] ~= nil then
                local driver = getDriverOfCar(veh)

                if doesCharExist(driver) and isCharInCar(driver, veh) then
                    taskPlayAnimSecondary(driver, anims[2], anims[1], 4.0,
                                          false, false, false, false, -1)
                end
            end

            local temp1 = tonumber(angle1)
            local temp2 = temp1 - tonumber(angle2)

            for i = temp1, temp2, -3 do
                matrix:rotate_x(i)
                wait(1)
            end
            for i = temp2, temp1, 3 do
                matrix:rotate_x(i)
                wait(1)
            end
        end

        if getCarCurrentGear(veh) < current_gear then
            current_gear = getCarCurrentGear(veh)

            if anims[3] ~= nil then
                local driver = getDriverOfCar(veh)

                if doesCharExist(driver) and isCharInCar(driver, veh) then
                    taskPlayAnimSecondary(driver, anims[4], anims[3], 4.0,
                                          false, false, false, false, -1)
                end
            end

            local temp1 = tonumber(angle1)
            local temp2 = temp1 + tonumber(angle2)

            for i = temp1, temp2, 3 do
                matrix:rotate_x(i)
                wait(1)
            end
            for i = temp2, temp1, -3 do
                matrix:rotate_x(i)
                wait(1)
            end
        end

        wait(0)
    end
    removeAnimation(anims[1])
    removeAnimation(anims[3])
end

function FunctionalNeutralLed(veh, prefix)

    local pVeh = getCarPointer(veh)
    local model = getCarModel(veh)
    local nled = mad.get_vehicle_component(veh, prefix)

    if not nled then return end

    log.debug("Processing component " .. nled.name)
    while true do

        if not DoesVehicleExist(veh, prefix) then return end

        if isCarEngineOn(veh) then

            if getCarCurrentGear(veh) == 0 then

                for _, obj in ipairs(nled:get_objects()) do
                    for _, mat in ipairs(obj:get_materials()) do
                        mat:set_color(0, 160, 0, 255)
                    end
                end
            else
                for _, obj in ipairs(nled:get_objects()) do
                    for _, mat in ipairs(obj:get_materials()) do
                        mat:set_color(0, 30, 0, 255)
                    end
                end
            end
        else
            for _, obj in ipairs(nled:get_objects()) do
                for _, mat in ipairs(obj:get_materials()) do
                    mat:set_color(0, 30, 0, 255)
                end
            end
        end

        wait(0)
    end
end

function FunctionalDamageLed(veh, prefix)

    local model = getCarModel(veh)
    local dled = mad.get_vehicle_component(veh, prefix)

    if not dled then return end

    log.debug("Processing component " .. dled.name)
    while true do

        if not DoesVehicleExist(veh, prefix) then return end

        if getCarHealth(veh) < 650 and isCarEngineOn(veh) then
            for _, obj in ipairs(dled:get_objects()) do
                for _, mat in ipairs(obj:get_materials()) do
                    mat:set_color(209, 30, 21, 255)
                end
            end
        else
            for _, obj in ipairs(dled:get_objects()) do
                for _, mat in ipairs(obj:get_materials()) do
                    mat:set_color(60, 20, 20, 170)
                end
            end
        end
        wait(0)
    end
end

function FunctionalPowerLed(veh, prefix)

    local model = getCarModel(veh)
    local pled = mad.get_vehicle_component(veh, prefix)

    if not pled then return end

    log.debug("Processing component " .. pled.name)
    while true do

        local speed = GetRealisticSpeed(veh, 1)

        if not DoesVehicleExist(veh, prefix) then return end

        if isCarEngineOn(veh) then
            if speed >= 100 then
                for _, obj in ipairs(pled:get_objects()) do
                    for _, mat in ipairs(obj:get_materials()) do
                        mat:set_color(240, 0, 0, 255)
                    end
                end
            else
                for _, obj in ipairs(pled:get_objects()) do
                    for _, mat in ipairs(obj:get_materials()) do
                        mat:set_color(0, 200, 0, 255)
                    end
                end
            end
        else
            for _, obj in ipairs(pled:get_objects()) do
                for _, mat in ipairs(obj:get_materials()) do
                    mat:set_color(50, 50, 50, 255)
                end
            end
        end

        wait(0)
    end
end

function UpdateOdometerNumber(number, veh, comp, angle, prefix, child_comps,
                              shown_angle)

    if number > 999999 then number = 999999 end

    local angle_table = {}

    for c in string.gmatch(tostring(number), ".") do
        table.insert(angle_table, 1, tonumber(c) * angle)
    end
    for i = 1, 6, 1 do
        if child_comps[i] ~= nil then

            if angle_table[i] == nil then angle_table[i] = 0 end
            if shown_angle[i] == nil then shown_angle[i] = -1 end

            local matrix = child_comps[i].modeling_matrix

            while shown_angle[i] ~= angle_table[i] do

                if shown_angle[i] ~= -1 then
                    if shown_angle[i] == angle * 9 then

                        while shown_angle[i] ~= angle * 10 do
                            shown_angle[i] = shown_angle[i] + angle / 16
                            matrix:rotate_x(shown_angle[i])
                            wait(25)
                        end

                        shown_angle[i] = angle_table[i]
                        goto breakloops
                    end

                    if shown_angle[i] > angle_table[i] then
                        shown_angle[i] = shown_angle[i] - angle / 16
                    end
                    if shown_angle[i] < angle_table[i] then
                        shown_angle[i] = shown_angle[i] + angle / 16
                    end
                    matrix:rotate_x(shown_angle[i])

                    wait(25)
                else
                    matrix:rotate_x(angle_table[i])
                    shown_angle[i] = angle_table[i]
                end
            end
        end
        ::breakloops::
    end

end

function FunctionalOdometer(veh, prefix)

    local comp, tdata = GetComponentData(veh, prefix)

    local angle = ConvertCheckDataType(tdata, "number", 1)

    if not angle then return end

    local current_number = 0
    local new_number = math.random(10000, 200000)
    local bac = 0
    local offset = nil
    local model = getCarModel(veh)
    local shown_angle = {}
    local child_comps = {}

    for index, child in ipairs(comp:get_child_components()) do
        table.insert(child_comps, child)
    end

    if isThisModelABike(model) then
        offset = 0x750
    else
        if isThisModelACar(model) then offset = 0x828 end
    end

    log.debug("Processing component " .. comp.name)
    while true do

        if not DoesVehicleExist(veh, prefix) or offset == nil then return end

        local val = math.abs(math.floor(memory.getfloat(
                                            getCarPointer(veh) + offset) / 200))
        new_number = new_number + math.abs(bac - val)
        bac = val

        if current_number ~= new_number then
            current_number = new_number
            UpdateOdometerNumber(current_number, veh, comp, angle, prefix,
                                 child_comps, shown_angle)
        end
        wait(0)
    end
end

function FunctionalClutch(veh, prefix)

    local clutch, tdata = GetComponentData(veh, prefix)

    local angle = ConvertCheckDataType(tdata, "number", 1)

    if not angle then return end

    local matrix = clutch.modeling_matrix
    local current_gear = 0
    local anims = FindAnimations(clutch)

    if anims[1] ~= nil then
        requestAnimation(anims[1])
        loadAllModelsNow()
    end

    log.debug("Processing component " .. clutch.name)
    while true do
        if not DoesVehicleExist(veh, prefix) then return end

        if getCarCurrentGear(veh) ~= current_gear then
            current_gear = getCarCurrentGear(veh)

            if anims[1] ~= nil then
                local driver = getDriverOfCar(veh)

                if doesCharExist(driver) and isCharInCar(driver, veh) then
                    taskPlayAnimSecondary(driver, anims[2], anims[1], 4.0,
                                          false, false, false, false, -1)
                end
            end

            for i = 0, angle / 4, 1 do
                matrix:rotate_z(i * 4)
                wait(0.1)
            end

            for i = angle / 4, 0, -1 do
                matrix:rotate_z(i * 4)
                wait(0.1)
            end

        end

        wait(0)
    end
    if anims[1] ~= nil then removeAnimation(anims[1]) end
end

function FunctionalSpeedometer(veh, prefix)

    local comp, tdata = GetComponentData(veh, prefix)

    if not comp then return end
    local matrix = comp.modeling_matrix

    local cdata = FindChildData(comp, tmain.name.unit)

    log.debug("Processing component " .. comp.name)

    local low = tdata[1]
    local high = tdata[2]
    local unit = cdata[1] or "mph"
    local speedm_max = tonumber(cdata[2]) or 120
    local total_rot = math.abs(high) + math.abs(low)
    local rotation = total_rot / speedm_max

    while true do
        if not DoesVehicleExist(veh, prefix) then return end

        local speed = GetRealisticSpeed(veh, 1) - 0.2

        if unit == "mph" then speed = speed / 1.6 end

        if speed > speedm_max then speed = speedm_max end
        matrix:rotate_y(rotation * speed + low)
        wait(0)
    end
end

function FunctionalFrontBrake(veh, prefix)

    local comp, tdata = GetComponentData(veh, prefix)

    local angle = ConvertCheckDataType(tdata, "number", 1)

    if not angle then return end

    local matrix = comp.modeling_matrix
    local anims = FindAnimations(comp)
    local pveh = getCarPointer(veh)

    if anims[1] ~= nil then
        requestAnimation(anims[1])
        loadAllModelsNow()
    end

    log.debug("Processing component " .. comp.name)
    while true do
        if not DoesVehicleExist(veh, prefix) then return end

        if memory.getfloat(pveh + 0x4A0) == 1 then -- bIsHandbrakeOn 
            if anims[1] ~= nil then
                local driver = getDriverOfCar(veh)

                if doesCharExist(driver) and isCharInCar(driver, veh) then
                    taskPlayAnimSecondary(driver, anims[2], anims[1], 4.0,
                                          false, false, false, false, -1)
                end
            end

            local temp = 1

            if angle < 0 then temp = -1 end

            for i = 0, angle / 4, temp do
                matrix:rotate_z(i * 4)
                wait(0.1)
            end

            while memory.getfloat(pveh + 0x4A0) == 1 do wait(0) end

            for i = angle / 4, 0, (temp * -1) do
                matrix:rotate_z(i * 4)
                wait(0.1)
            end

        end

        wait(0)
    end
end

function FunctionalRearBrake(veh, prefix, brake_type)

    local comp, tdata = GetComponentData(veh, prefix)

    local angle = ConvertCheckDataType(tdata, "number", 1)

    if not angle then return end

    local matrix = comp.modeling_matrix
    local anims = FindAnimations(comp)
    local pveh = getCarPointer(veh)

    if anims[1] ~= nil then
        requestAnimation(anims[1])
        loadAllModelsNow()
    end

    log.debug("Processing component " .. comp.name)
    while true do
        if not DoesVehicleExist(veh, prefix) then return end

        if bit.band(memory.read(pveh + 0x428, 2), 32) == 32 then -- m_fBrakePedal

            if anims[1] ~= nil then
                local driver = getDriverOfCar(veh)

                if doesCharExist(driver) and isCharInCar(driver, veh) then
                    taskPlayAnimSecondary(driver, anims[2], anims[1], 4.0,
                                          false, false, false, false, -1)
                end
            end

            local temp = 1

            if angle < 0 then temp = -1 end

            for i = 0, angle, temp do
                matrix:rotate_x(i)
                wait(0.1)
            end

            while bit.band(memory.read(pveh + 0x428, 2), 32) == 32 do
                wait(0)
            end

            for i = angle, 0, (temp * -1) do
                matrix:rotate_x(i)
                wait(0.1)
            end

        end

        wait(0)
    end
end

function HighlightComponent(veh, prefix)
    while true do
        for i, comp in ipairs(mad.get_all_vehicle_components(veh)) do
            if string.match(comp.name, prefix) then
                for _, obj in ipairs(child:get_objects()) do
                    for i, mat in ipairs(obj:get_materials()) do
                        mat:set_color(0, 255, 0, 255)
                    end
                end
                local x, y, z = comp.matrix.pos:get()
                local sx, sy = convert3DCoordsToScreen(x, y, z)
                mad.draw_text(string.format('%s', comp.name), sx, sy,
                              mad.font_style.SUBTITLES, 0.3, 0.6,
                              mad.font_align.LEFT, 2000, true, false, 255, 255,
                              255, 255, 1, 0, 30, 30, 30, 120)
            end
        end
        wait(0)
    end
end

--------------------------------------------------

function main()
    -- lua_thread.create(ClearNonExistentVehicleData)
    while true do
        for i, veh in ipairs(getAllVehicles()) do
            if doesVehicleExist(veh) and tmain.veh_data[veh] == nil then
                tmain.veh_data[veh] = veh
                local model = getCarModel(veh)
                log.debug("")
                log.debug(string.format("Found vehicle %s (%d) %d",
                                        GetNameOfVehicleModel(model), model,
                                        getCarPointer(veh)))

                lua_thread.create(FunctionalChain, veh, tmain.name.chain)
                lua_thread.create(FunctionalClutch, veh, tmain.name.clutch)
                lua_thread.create(FunctionalDamageLed, veh, tmain.name.dled)
                lua_thread.create(FunctionalGearLever, veh,
                                  tmain.name.gear_lever)
                lua_thread.create(FunctionalNeutralLed, veh, tmain.name.nled)
                lua_thread.create(FunctionalOdometer, veh, tmain.name.odometer)
                lua_thread.create(FunctionalPowerLed, veh, tmain.name.pled)
                lua_thread.create(FunctionalFrontBrake, veh, tmain.name.fbrake)
                lua_thread.create(FunctionalRearBrake, veh, tmain.name.rbrake)
                -- lua_thread.create(HighlightComponent, veh, tmain.name.chain)
                lua_thread.create(FunctionalSpeedometer, veh, tmain.name.speedo)
            end
        end
        wait(0)
    end
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() then log.info("Log ended") end
end
