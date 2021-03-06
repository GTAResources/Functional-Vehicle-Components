local module = {}

function module.Chain(veh,comp)

    local speed = nil
    local chain_table = {}
    local time = futil.GetValue(CHAIN_TIME_FACTOR,5,comp.name,"_ms(%d+)")

    for _, comp in ipairs(comp:get_child_components()) do
        table.insert(chain_table, comp)
    end

    rotate_chain = function(i)
        if futil.VehicleCheck(veh) then return end
        speed = futil.GetRealisticSpeed(veh, 1)

        if speed >= 2 or speed <= -2 then
            futil.HideChildsExcept(chain_table,i)
            wait(time / math.abs(speed))
        end
    end

    flog.ProcessingComponent(comp.name)
    while true do

        if futil.VehicleCheck(veh) then return end

        speed = futil.GetRealisticSpeed(veh, 1)
        
        if speed >= 2 then
            for i = 1, #chain_table, 1 do
                rotate_chain(i)
            end
        end
        if speed <= -2 then
            for i = #chain_table, 1, -1 do
                rotate_chain(i)
            end
        end
        
       
        wait(0)
    end
end

function module.ExtraWheels(veh,comp)
    
    local wheel_no = futil.GetValue(EXTRA_WHEEL_NUMBER,1,comp.name,"_w(%d+)")
    local rot_mul = futil.GetValue(EXTRA_WHEEL_ROTATION_MULTIPLIER,30,comp.name,"_rmul(%d+)")

    local pVeh = getCarPointer(veh)
    local model = getCarModel(veh)
    local matrix = comp.modeling_matrix
    local rotation = 0
    local fWheelSpeed = nil
    
    if isThisModelABike(model) then
        fWheelSpeed = ffi.cast("float*", pVeh + 0x758)
        wheel_no = wheel_no > 1 and 1 or wheel_no
    end
    if isThisModelACar(model) then
        fWheelSpeed = ffi.cast("float*", pVeh + 0x848)
        wheel_no = wheel_no > 3 and 3 or wheel_no
    end

    if fWheelSpeed == nil then   
        flog.Write(string.format("%s can't have extra wheel.",futil.GetNameOfVehicleModel(model)))
        return
    end

    flog.ProcessingComponent(comp.name)
    while true do

        if futil.VehicleCheck(veh) then return end
        
        rotation = rotation + fWheelSpeed[wheel_no]*rot_mul

        if rotation > 360 then
            rotation = rotation - 360
        end
        if rotation < 0 then
            rotation = 360 + rotation
        end
        matrix:rotate_x(rotation)

        wait(0)
    end
end

function module.GearLever(veh, comp)

    local normal_angle = futil.GetValue(GEAR_LEVER_NORMAL_ANGLE,15,comp.name,"_ax(%w+)")
    local offset_angle = futil.GetValue(GEAR_LEVER_OFFSET_ANGLE,15,comp.name,"_o(%w+)")
    local wait_time    = futil.GetValue(GEAR_LEVER_WAIT_TIME,1,comp.name,"_ms(%d+)")
    local gear_type    = futil.GetValue(GEAR_LEVER_TYPE,2,comp.name,"_t(%d+)")

    local matrix = comp.modeling_matrix
    local current_gear = -1

    rotate_gear = function(val)
        local change_angle = normal_angle - offset_angle*val

        for i = normal_angle, change_angle, 3*val do
            matrix:rotate_x(i)
            wait(wait_time)
        end
        for i = change_angle, normal_angle, 3*val do
            matrix:rotate_x(i)
            wait(wait_time)
        end
    end

    flog.ProcessingComponent(comp.name)
    while true do

        if futil.VehicleCheck(veh) then return end
       
        local gear = getCarCurrentGear(veh)
        if gear ~= current_gear then
            local val = 1

            if current_gear > gear then
                val = -1
            end

            if gear_type == 1 then
                rotate_gear(val)
            else
                -- N-> 1
                if current_gear == 0 then
                    rotate_gear(1)
                end

                -- 1->4
                if current_gear > 0 and val == 1 then
                    rotate_gear(-1)
                end

                -- 4->1
                if current_gear > 0 and val == -1 then
                    rotate_gear(1)
                end

                -- 1->N
                if current_gear == 1 and val == -1 then
                    local temp = offset_angle
                    offset_angle = offset_angle/2
                    rotate_gear(-1)
                    offset_angle = temp
                end
            end

            current_gear = gear
        end

        wait(0)
    end
end

function module.Clutch(veh, comp)

    local rotation_angle = futil.GetValue(CLUTCH_ROTATION_ANGLE,17,comp.name,"_az(%w+)")
    local wait_time = futil.GetValue(CLUTCH_WAIT_TIME,1,comp.name,"_ms(%d+)")

    local matrix = comp.modeling_matrix
    local current_gear = 0

    flog.ProcessingComponent(comp.name)
    while true do
        if futil.VehicleCheck(veh) then return end

        if getCarCurrentGear(veh) ~= current_gear then
            current_gear = getCarCurrentGear(veh)
            for i = 0, rotation_angle / 4, 1 do
                matrix:rotate_z(i * 4)
                wait(wait_time)
            end
            for i = rotation_angle / 4, 0, -1 do
                matrix:rotate_z(i * 4)
                wait(wait_time)
            end
        end
        wait(0)
    end
end

function module.Throttle(veh, comp)

    local rotate_axis = futil.GetValue(THROTTLE_ROTATION_AXIS,"x",comp.name,"_(%w)=")
    local rotation = futil.GetValue(THROTTLE_ROTATION_VALUE,50,comp.name,"=(-?%d[%d.]*)")
    local wait_time = futil.GetValue(THROTTLE_WAIT_TIME,50,comp.name,"_ms(%d+)")
    
    local rotx, roty, rotz

    rotation = rotation/20 -- manual test
    if rotate_axis ~= "x" then
        rotx = futil.FindChildData(comp, "rotx=(-?%d[%d.]*)",THROTTLE_ROTATION_ROT_X,50)
    else
        rotx = rotation
    end
    if rotate_axis ~= "y" then
        roty = futil.FindChildData(comp, "roty=(-?%d[%d.]*)",THROTTLE_ROTATION_ROT_Y,0)
    else
        roty = rotation
    end
    if rotate_axis ~= "z" then
        rotz = futil.FindChildData(comp, "rotz=(-?%d[%d.]*)",THROTTLE_ROTATION_ROT_Z,0)
    else
        rotz = rotation
    end

    local matrix = comp.modeling_matrix
    local current_state = 0

    flog.ProcessingComponent(comp.name)

    local rotate_throttle = function(i,cur_rotx,cur_roty,cur_rotz)
        if rotate_axis == "x" then
            cur_rotx = cur_rotx + i
        end
        if rotate_axis == "y" then
            cur_roty = cur_roty + i
        end
        if rotate_axis == "z" then
            cur_rotz = cur_rotz + i
        end

        matrix:rotate(cur_rotx,cur_roty,cur_rotz)
        wait(wait_time)
    end

    while true do
        if futil.VehicleCheck(veh) then return end

        local fGas_state = math.floor(memory.getfloat(getCarPointer(veh)+0x49C))
        local gear = getCarCurrentGear(veh)

        if fGas_state ~= current_state then -- fGas_state
            current_state = fGas_state

            if gear >= 1 then
                local cur_rotx = rotx or rotation
                local cur_roty = roty or rotation
                local cur_rotz = rotz or rotation

                if futil.VehicleCheck(veh) then return end

                if fGas_state == 1 then      
                    for i=0,rotation,0.5 do
                        rotate_throttle(i,cur_rotx,cur_roty,cur_rotz)
                    end
                else
                    for i=rotation,0,-0.5 do
                        rotate_throttle(i,cur_rotx,cur_roty,cur_rotz)
                    end
                end

                while doesVehicleExist(veh) and math.floor(memory.getfloat(getCarPointer(veh)+0x49C)) == fGas_state do
                    wait(0)
                end
            end
        end
        wait(0)
    end
end

function module.FrontBrake(veh, comp)

    local offset_angle = futil.GetValue(FRONT_BRAKE_OFFSET_ANGLE,15,comp.name,"_az(-?%d[%d.]*)")
    local wait_time = futil.GetValue(FRONT_BRAKE_WAIT_TIME,1,comp.name,"_ms(%d)")

    local matrix = comp.modeling_matrix
    local pveh = getCarPointer(veh)

    flog.ProcessingComponent(comp.name)
    while true do
        if futil.VehicleCheck(veh) then return end

        if memory.getfloat(pveh + 0x4A0) == 1 then -- bIsHandbrakeOn

            local temp = 1

            if offset_angle < 0 then temp = -1 end

            for i = 0, offset_angle / 4, temp do
                matrix:rotate_z(i * 4)
                wait(wait_time)
            end

            while memory.getfloat(pveh + 0x4A0) == 1 do wait(0) end

            for i = offset_angle / 4, 0, (temp * -1) do
                matrix:rotate_z(i * 4)
                wait(wait_time)
            end

        end

        wait(0)
    end
end

function module.RearBrake(veh, comp)

    local offset_angle = futil.GetValue(REAR_BRAKE_OFFSET_ANGLE,5,comp.name,"_ax(-?%d[%d.]*)")
    local wait_time = futil.GetValue(REAR_BRAKE_WAIT_TIME,1,comp.name,"_ms(%d)")

    local matrix = comp.modeling_matrix
    local pveh = getCarPointer(veh)

    flog.ProcessingComponent(comp.name)
    while true do
        if futil.VehicleCheck(veh) then return end

        if bit.band(memory.read(pveh + 0x428, 2), 32) == 32 then -- m_fBrakePedal

            local temp = 1

            if offset_angle < 0 then temp = -1 end
            
            for i = 0, offset_angle/2, temp do
                matrix:rotate_x(i*2)
                wait(wait_time)
            end

            while bit.band(memory.read(pveh + 0x428, 2), 32) == 32 do
                wait(0)
            end

            for i = offset_angle/2, 0, (temp * -1) do
                matrix:rotate_x(i*2)
                wait(wait_time)
            end

        end

        wait(0)
    end
end


return module