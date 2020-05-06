local module = {}

function FindComponentData(comp_name,data_pattern)
    local comp_name = comp_name:gsub(",",".")
    local _,_,data = string.find(comp_name, data_pattern)

    if data then
        return data
    end
    return nil
end

function module.GetNameOfVehicleModel(model)
    return ffi.string(ffi.cast("char*",CVehicleModelInfo[tonumber(model)] + 0x32)) or ""
end

function module.GetValue(script_val,default_value,comp_name,model_data_prefix)
    if IGNORE_MODEL_VALUES then
        return script_val or default_value
    else
        local rtn_val = FindComponentData(comp_name,model_data_prefix)

        if type(default_value) == "number" then
            rtn_val = tonumber(rtn_val)
        end
        
        return rtn_val or default_value
    end
end

-- This function is taken from juniors vehfuncs
function module.GetRealisticSpeed(veh, wheel)

    if not doesVehicleExist(veh) then return end
    -- if isCarStopped(veh) then return 0 end

    local pVeh = getCarPointer(veh)
    local realisticSpeed = 0
    local frontWheelSize = memory.getfloat(
                               CVehicleModelInfo[getCarModel(veh)] + 0x40)
    local rearWheelSize = memory.getfloat(
                              CVehicleModelInfo[getCarModel(veh)] + 0x44)

    if isThisModelABike(getCarModel(veh)) then -- bike
        local fWheelSpeed = ffi.cast("float*", pVeh + 0x758) -- CBike.fWheelSpeed[]

        if wheel == nil then
            realisticSpeed = (fWheelSpeed[1] * frontWheelSize + fWheelSpeed[2] * frontWheelSize) / 2
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

function module.FindChildData(parent_comp,data_prefix,script_value,default_value)

    if IGNORE_MODEL_VALUES then
        return script_value
    end

    for _, child_comp in ipairs(parent_comp:get_child_components()) do
        child_comp_name = child_comp.name:gsub(",",".")
        local _,_,data = string.find(child_comp_name, data_prefix)
        if data then
            return data
        end
    end
    return default_value
end

function module.SetMaterialColor(comp,r,g,b,a)
    for _, obj in ipairs(comp:get_objects()) do
        for _, mat in ipairs(obj:get_materials()) do
            mat:set_color(r,g,b,a)
        end
    end
end

function module.HideChildsExcept(model_table,show_index)
    for j = 1, #model_table, 1 do
        if model_table[show_index].name == model_table[j].name then
            model_table[j]:set_alpha(255)
        else
            model_table[j]:set_alpha(0)
        end
    end
end

function module.HighlightComponent(veh, prefix)
    while true do
        for i, comp in ipairs(mad.get_all_vehicle_components(veh)) do
            if string.find(comp.name, prefix) ~= nil then
                for _, obj in ipairs(comp:get_objects()) do
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

return module