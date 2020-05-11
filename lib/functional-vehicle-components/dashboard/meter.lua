
function UpdateOdometerNumber(number,angle,child_comps,shown_angle,default_type)

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

                            if default_type ~= "digital" then
                                wait(25)
                            end
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
                    
                    if default_type == "analog" then
                        wait(25)
                    end
                else
                    matrix:rotate_x(angle_table[i])
                    shown_angle[i] = angle_table[i]
                end
            end
        end
        ::breakloops::
    end

end

function module.Odometer(veh,comp)

    local rotation_angle = futil.GetValue(ODOMETER_ROTATION_ANGLE,36,comp.name,"_ax(%w+)")
    local default_type = futil.GetValue(ODOMETER_DEFAULT_TYPE,"analog",comp.name,"_t(%w+)")

    local current_number = 0
    local new_number = fgsx.Get(veh,"odo_val") or 0
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
        if isThisModelACar(model) then 
            offset = 0x828 
        end
    end

    flog.ProcessingComponent(comp.name)
    while true do
        if not doesVehicleExist(veh) or offset == nil then return end

        local val = math.abs(math.floor(memory.getfloat(getCarPointer(veh) + offset) / 200))
        new_number = new_number + math.abs(bac - val)
        bac = val
        if current_number ~= new_number then
            current_number = new_number
            UpdateOdometerNumber(current_number,rotation_angle,child_comps,shown_angle,default_type)
        end
        wait(0)
    end
end

function module.Speedometer(veh,comp)

    local angle_start = futil.GetValue(SPEEDOMETER_ANGLE_START,0,comp.name,"_ay(-?%d[%d.]*)")
    local angle_end = futil.GetValue(SPEEDOMETER_ANGLE_END,180,comp.name,"_(-?%d[%d.]*)")
    
    local matrix = comp.modeling_matrix
    local unit = futil.FindChildData(comp,"unit=",SPEEDOMETER_DEFAULT_UNIT,"mph")
    local speedm_max = futil.GetValue(SPEEDOMETER_MAX_SPEED,180,comp.name,"_m(%d+)")
    local total_rot = futil.CalcTotalRotation(angle_start,angle_end)
    local temp = 0
    local rotation = 0
    
    flog.ProcessingComponent(comp.name)
    while true do
        if not doesVehicleExist(veh) then return end

        local speed = futil.GetRealisticSpeed(veh, 1)
        
        if unit == "mph" then speed = speed / 1.6 end

        if speed > speedm_max then speed = speedm_max end
        
        temp = total_rot / speedm_max * speed + angle_start

        if rotation < temp then 
            rotation = rotation + (temp-rotation)/5
        end

        if rotation > temp then 
            rotation = rotation - (rotation-temp)/5
        end

        matrix:rotate_y(rotation)

        wait(0)
    end
end

function module.FuelMeter(veh,comp)

    local angle_start = futil.GetValue(FUELMETER_ANGLE_START,35,comp.name,"_ay(-?%d[%d.]*)")
    local angle_end = futil.GetValue(FUELMETER_ANGLE_END,155,comp.name,"_(-?%d[%d.]*)")

    local matrix = comp.modeling_matrix

    local total_rot = futil.CalcTotalRotation(angle_start,angle_end)
    local rotation = 0

    fgsx.Set(veh,"fm_fuel",math.random(30, 90))
    flog.ProcessingComponent(comp.name)
    
    while true do
        if not doesVehicleExist(veh) then return end

        local fuel = fgsx.Get(veh,"fm_fuel") or 0
        local speed = futil.GetRealisticSpeed(veh)
        rotation = (total_rot / 100) * fuel + angle_start
        
        matrix:rotate_y(rotation > angle_end and angle_end or rotation)

        if isCarEngineOn(veh) then
            fuel = fuel > 1 and fuel - speed/100000 or fuel
            fgsx.Set(veh,"fm_fuel",fuel)
        end

        wait(0)
    end
end

-- function module.RPMmeter(veh, comp)

--     local angle_start = futil.GetValue(RPMMETER_ANGLE_START,-30,comp.name,"_ay(-?%d+)")
--     local angle_end = futil.GetValue(RPMMETER_ANGLE_END,180,comp.name,"_(-?%d+)")

--     local matrix = comp.modeling_matrix

--     flog.ProcessingComponent(comp.name)

--     local meter_max = futil.GetValue(RPMMETER_MAX_RPM,9,comp.name,"_m(%d+)")
--     meter_max = 16
--     local total_rot = math.abs(angle_end) + math.abs(angle_start)
--     local cur_rpm = 0.6
--     local cur_speed = 0
--     local gear = 0
--     local temp = 0
--     local rotation = 0

--     while true do
--         if not doesVehicleExist(veh) then return end

--         local rea_speed = futil.GetRealisticSpeed(veh)
               
--         local fGas_state = math.floor(memory.getfloat(getCarPointer(veh)+0x49C))
--         if fGas_state > 0 then
--             if rea_speed > cur_speed then
--                 cur_speed = rea_speed
--                 cur_rpm = cur_rpm + (fTimeStep[0]/ 1.6666) * (fGas_state / 6.0)
--             end
--         else
--             cur_rpm = cur_rpm - (fTimeStep[0]/ 1.6666) * 0.3
--             cur_speed = 0
--         end
        
--         local cur_gear = getCarCurrentGear(veh)
--         if gear ~= cur_gear then
--             if gear < cur_gear then
--                 cur_rpm = cur_rpm - 2
--             end
--             gear = cur_gear
--         end

--         if cur_rpm < 0 then cur_rpm = 0 end
--         temp = total_rot / meter_max * cur_rpm + angle_start
        
--         if isCarEngineOn(veh) then
--             temp = temp+20
--         end

--         if rotation < temp then 
--             rotation = rotation + (temp-rotation)/5
--         end

--         if rotation > temp then 
--             rotation = rotation - (rotation-temp)/5
--         end

--         cur_rpm = cur_rpm > meter_max and meter_max or cur_rpm
--         rotation = rotation > angle_end and angle_end or rotation
        
--         matrix:rotate_y(rotation)

--         wait(0)
--     end
-- end

function module.RPMmeter(veh, comp)

    local angle_start = futil.GetValue(RPMMETER_ANGLE_START,-30,comp.name,"_ay(-?%d+)")
    local angle_end = futil.GetValue(RPMMETER_ANGLE_END,180,comp.name,"_(-?%d+)")

    local matrix = comp.modeling_matrix

    flog.ProcessingComponent(comp.name)

    local meter_max = futil.GetValue(RPMMETER_MAX_RPM,9,comp.name,"_m(%d+)")
    meter_max = 16
    local total_rot = math.abs(angle_end) + math.abs(angle_start)
    local cur_rpm = 0.6
    local cur_speed = 0
    local gear = 0
    local temp = 0
    local rotation = 0
    local rea_speed = 0

    local pVeh = getCarPointer(veh)
    while true do
        if not doesVehicleExist(veh) then return end

        if isThisModelABike(getCarModel(veh)) then -- bike
            local fWheelSpeed = ffi.cast("float*", pVeh + 0x758) -- CBike.fWheelSpeed[]
            rea_speed = fWheelSpeed[1]
        else
            if isThisModelACar(getCarModel(veh)) then -- bike
                local fWheelSpeed = ffi.cast("float*", pVeh + 0x848) -- Automobile.fWheelSpeed[]
                rea_speed = fWheelSpeed[3]
            else
                rea_speed = getCarSpeed(veh) * -0.0426 -- Manually tested
            end
        end
        rea_speed = rea_speed*-5

        printString(tostring(cur_rpm),100)
        if rea_speed > cur_speed then
            local rpm = cur_rpm + (fTimeStep[0]/ 1.6666) * (1 / 6.0)
            if rpm < angle_end then
                cur_rpm = rpm
            end
        else
            local rpm = cur_rpm - (fTimeStep[0]/ 1.6666) * (1 / 6.0)
            if rpm > angle_start then
                cur_rpm = rpm
            end
        end
        cur_speed = rea_speed

        local cur_gear = getCarCurrentGear(veh)
        if gear ~= cur_gear then
            if gear < cur_gear then
                cur_rpm = cur_rpm - 2
            end
            gear = cur_gear
        end

        if cur_rpm < 0 then cur_rpm = 0 end
        temp = total_rot / meter_max * cur_rpm + angle_start
        
        if isCarEngineOn(veh) then
            temp = temp+20
        end

        if rotation < temp then 
            rotation = rotation + (temp-rotation)/5
        end

        if rotation > temp then 
            rotation = rotation - (rotation-temp)/5
        end

        cur_rpm = cur_rpm > meter_max and meter_max or cur_rpm
        rotation = rotation > angle_end and angle_end or rotation
        
        matrix:rotate_y(rotation)

        wait(0)
    end
end

function module.DigitalGearMeter(veh,comp)

    local number_table = {}
    
    for _, comp in ipairs(comp:get_child_components()) do
        table.insert(number_table, comp)
    end

    flog.ProcessingComponent(comp.name)
    while true do

        if not doesVehicleExist(veh) then return end
        futil.HideChildsExcept(number_table,getCarCurrentGear(veh))
        
        wait(0)
    end
end