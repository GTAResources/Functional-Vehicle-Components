script_name('Functional Vehicle Components')
script_author("Grinch_")
script_version("1.0-beta")
script_description("Adds more features/ functions to vehicle parts")
script_dependencies("ffi", "Memory", "MoonAdditions", "log")
script_properties('work-in-pause')

--------------------------------------------------
-- Ignore model values
-- If the flag is true then values from models are ignored and below values will be applied
-- This is just for ease of testing, do NOT distribute the script with the flag set to true
IGNORE_MODEL_VALUES = false

-- Below values are only applied if the above flag is set to 'true' (default values are already set)
-- Times are calculated in miliseceonds

-- FunctionalChain
CHAIN_TIME_FACTOR = 5

-- FucntionalGearLever
GEAR_LEVER_NORMAL_ANGLE = 15
GEAR_LEVER_OFFSET_ANGLE = 15
GEAR_LEVER_WAIT_TIME = 1

-- FunctionalOdometer
ODOMETER_ROTATION_ANGLE = 36
ODOMETER_ROTATION_WAIT_TIME = 25

-- FunctionalClutch
CLUTCH_ROTATION_ANGLE = 17
CLUTCH_WAIT_TIME = 1

-- FunctionalThrottle
THROTTLE_ROTATION_AXIS = "y"
THROTTLE_WAIT_TIME = 1
THROTTLE_ROTATION_ROT_X = 50
THROTTLE_ROTATION_ROT_Y = 0
THROTTLE_ROTATION_ROT_Z = 0

-- FunctionalSpeedometer
SPEEDOMETER_ANGLE_START = 0
SPEEDOMETER_ANGLE_END = 180
SPEEDOMETER_DEFAULT_UNIT = "mph"
SPEEDOMETER_MAX_SPEED = 120

-- FunctionalFrontBrake
FRONT_BRAKE_OFFSET_ANGLE = 15
FRONT_BRAKE_WAIT_TIME = 1

-- FunctionalReadBrake
REAR_BRAKE_OFFSET_ANGLE = 15
REAR_BRAKE_WAIT_TIME = 1

-- FunctionalRPMMeter
RPMMETER_ANGLE_START = 0
RPMMETER_ANGLE_END = 180
RPMMETER_MAX_RPM = 10
--------------------------------------------------
-- Libraries

ffi = require 'ffi'
memory = require 'memory'
mad = require 'MoonAdditions'
log = require 'log'

--------------------------------------------------
-- log

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
fTimeStep = ffi.cast("float*",0xB7CB5C) -- CTimer::ms_fTimeStep

tmain = {
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

function FindComponentData(comp_name,data_pattern)
    local comp_name = comp_name:gsub(",",".")
    local _,_,data = string.find(comp_name, data_pattern)

    if data then
        return data
    end
    return nil
end

function GetValue(script_val,default_value,comp_name,model_data_prefix)
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

-- This function is taken from junior's vehfuncs
function GetRealisticSpeed(veh, wheel)

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

function FindChildData(parent_comp,data_prefix,script_value,default_value)

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

function DoesVehicleExist(veh, name)
    if doesVehicleExist(veh) then
        return true
    else
        return false
    end
end

function LogProcessComponent(comp_name)
    log.debug(string.format("Processing component %s",comp_name))
end

function SetMaterialColor(comp,r,g,b,a)
    for _, obj in ipairs(comp:get_objects()) do
        for _, mat in ipairs(obj:get_materials()) do
            mat:set_color(r,g,b,a)
        end
    end
end

--------------------------------------------------
-- Component specific stuff

function FunctionalChain(veh,comp)

    local speed = nil
    local chain_table = {}
    local time = GetValue(CHAIN_TIME_FACTOR,5,comp.name,"_ms(%w+)")
    
    for _, comp in ipairs(comp:get_child_components()) do
        table.insert(chain_table, comp)
    end

    LogProcessComponent(comp.name)
    while true do

        if not DoesVehicleExist(veh, comp.name) then return end

        speed = GetRealisticSpeed(veh, 1)

        rotate_chain = function(i)
            if not DoesVehicleExist(veh, comp.name) then return end

            for j = 1, #chain_table, 1 do
                if chain_table[i].name == chain_table[j].name then
                    chain_table[j]:set_alpha(255)
                else
                    chain_table[j]:set_alpha(0)
                end
            end
            wait(time / math.abs(speed))
        end
        
        if speed >= 1 then
            for i = 1, #chain_table, 1 do
                rotate_chain(i)
            end
        end
        if speed <= -1 then
            for i = #chain_table, 1, -1 do
                rotate_chain(i)
            end
        end
        wait(0)
    end
end

function FunctionalGearLever(veh, comp)

    local normal_angle = GetValue(GEAR_LEVER_NORMAL_ANGLE,15,comp.name,"_an(%w+)")
    local offset_angle = GetValue(GEAR_LEVER_OFFSET_ANGLE,15,comp.name,"_ao(%w+)")
    local wait_time    = GetValue(GEAR_LEVER_WAIT_TIME,1,comp.name,"_ms(%w+)")

    local matrix = comp.modeling_matrix
    local current_gear = -1

    LogProcessComponent(comp.name)
    while true do

        if not DoesVehicleExist(veh, comp.name) then return end

        local gear = getCarCurrentGear(veh)
        if gear ~= current_gear then
            local v = 1

            if current_gear > gear then
                v = -1
            end
            
            current_gear = gear

            local change_angle = normal_angle - offset_angle*v

            for i = normal_angle, change_angle, 3*v do
                matrix:rotate_x(i)
                wait(wait_time)
            end
            for i = change_angle, normal_angle, 3*v do
                matrix:rotate_x(i)
                wait(wait_time)
            end
        end

        wait(0)
    end
end

function FunctionalNeutralLed(veh, comp)

    LogProcessComponent(comp.name)
    while true do
        if not DoesVehicleExist(veh, prefix) then return end

        if isCarEngineOn(veh) then
            if getCarCurrentGear(veh) == 0 then
                SetMaterialColor(comp,0,200,0,255)
            else
                SetMaterialColor(comp,0,25,0,255)
            end
        else
            SetMaterialColor(comp,0,25,0,255)
        end
        wait(0)
    end
end

function FunctionalDamageLed(veh, comp)

    LogProcessComponent(comp.name)
    while true do
        if not DoesVehicleExist(veh, prefix) then return end

        if getCarHealth(veh) < 650 and isCarEngineOn(veh) then
            SetMaterialColor(comp,255,30,21,255)
        else
            SetMaterialColor(comp,60,20,20,200)
        end
        wait(0)
    end
end

function FunctionalPowerLed(veh, comp)

    LogProcessComponent(comp.name)
    while true do
        local speed = GetRealisticSpeed(veh, 1)
        if not DoesVehicleExist(veh, prefix) then return end

        if isCarEngineOn(veh) then
            if speed >= 100 then
                SetMaterialColor(comp,240,0,0,255)
            else
                SetMaterialColor(comp,0,200,0,255)
            end
        else
            SetMaterialColor(comp,50,50,50,255)
        end
        wait(0)
    end
end

function UpdateOdometerNumber(number,angle,child_comps,shown_angle)

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

function FunctionalOdometer(veh,comp)

    local rotation_angle = GetValue(ODOMETER_ROTATION_ANGLE,36,comp.name,"_ax(%w+)")

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
        if isThisModelACar(model) then 
            offset = 0x828 
        end
    end

    LogProcessComponent(comp.name)
    while true do
        if not DoesVehicleExist(veh, prefix) or offset == nil then return end

        local val = math.abs(math.floor(memory.getfloat(getCarPointer(veh) + offset) / 200))
        new_number = new_number + math.abs(bac - val)
        bac = val

        if current_number ~= new_number then
            current_number = new_number
            UpdateOdometerNumber(current_number,rotation_angle,child_comps,shown_angle)
        end
        wait(0)
    end
end

function FunctionalClutch(veh, comp)

    local rotation_angle = GetValue(CLUTCH_ROTATION_ANGLE,17,comp.name,"_az(%w+)")
    local wait_time = GetValue(CLUTCH_WAIT_TIME,1,comp.name,"_ms(%w+)")
    
    local matrix = comp.modeling_matrix
    local current_gear = 0

    LogProcessComponent(comp.name)
    while true do
        if not DoesVehicleExist(veh, prefix) then return end

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

function FunctionalThrottle(veh, comp)

    local rotate_axis = GetValue(THROTTLE_ROTATION_AXIS,"x",comp.name,"_(%w)=")
    local rotation = GetValue(THROTTLE_ROTATION_VALUE,50,comp.name,"=(-?%d[%d.]*)")
    local wait_time = GetValue(THROTTLE_WAIT_TIME,100,comp.name,"_ms(%d+)")

    local rotx, roty, rotz

    rotation = rotation/20 -- manual test
    if rotate_axis ~= "x" then
        rotx = FindChildData(comp, "rotx=(-?%d[%d.]*)",THROTTLE_ROTATION_ROT_X,50)
    else
        rotx = rotation
    end
    if rotate_axis ~= "y" then
        roty = FindChildData(comp, "roty=(-?%d[%d.]*)",THROTTLE_ROTATION_ROT_Y,0)
    else
        roty = rotation
    end
    if rotate_axis ~= "z" then
        rotz = FindChildData(comp, "rotz=(-?%d[%d.]*)",THROTTLE_ROTATION_ROT_Z,0)
    else
        rotz = rotation
    end

    local matrix = comp.modeling_matrix
    local current_state = 0

    LogProcessComponent(comp.name)

    while true do
        if not DoesVehicleExist(veh, prefix) then return end

        local fGas_state = math.floor(memory.getfloat(getCarPointer(veh)+0x49C))
        local gear = getCarCurrentGear(veh)

        if fGas_state ~= current_state then -- fGas_state
            current_state = fGas_state

            if gear >= 1 then
                local cur_rotx = rotx or rotation
                local cur_roty = roty or rotation
                local cur_rotz = rotz or rotation

                local rotate_throttle = function(i)
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

                if fGas_state == 1 then         
                    for i=0,rotation,1 do
                        rotate_throttle(i)
                    end
                else
                    for i=rotation,0,-1 do
                        rotate_throttle(i)
                    end
                end

                while math.floor(memory.getfloat(getCarPointer(veh)+0x49C)) == fGas_state do
                    wait(0)
                end
            else
                current_state = 0
            end
        end

        wait(0)
    end
end

function FunctionalSpeedometer(veh, comp)

    local angle_start = GetValue(SPEEDOMETER_ANGLE_START,0,comp.name,"_ay=(-?%d[%d.]*)")
    local angle_end = GetValue(SPEEDOMETER_ANGLE_END,180,comp.name,"_(-?%d[%d.]*)")

    local matrix = comp.modeling_matrix

    local unit = FindChildData(comp, "unit=(%w+)",SPEEDOMETER_DEFAULT_UNIT,"mph")
    local speedm_max = GetValue(SPEEDOMETER_ANGLE_END,180,comp.name,"_m(%d+)")

    local total_rot = math.abs(angle_end) + math.abs(angle_start)
    local rotation = 0

    LogProcessComponent(comp.name)
    while true do
        if not DoesVehicleExist(veh, prefix) then return end

        local speed = GetRealisticSpeed(veh, 1)

        if speed < 0 then
            speed = GetRealisticSpeed(veh, 0)
        end

        if unit == "mph" then speed = speed / 1.6 end
        if speed > speedm_max then speed = speedm_max end

        rotation = math.floor(total_rot / speedm_max * speed + angle_start)

        matrix:rotate_y(rotation)

        wait(0)
    end
end

function FunctionalRPMmeter(veh, comp)

    local angle_start = GetValue(RPMMETER_ANGLE_START,-30,comp.name,"_ay=(-?%d+)")
    local angle_end = GetValue(RPMMETER_ANGLE_END,205,comp.name,"_(-?%d+)")

    local matrix = comp.modeling_matrix

    LogProcessComponent(comp.name)

    local meter_max = GetValue(RPMMETER_MAX_RPM,10,comp.name,"_m(%d+)")
    local total_rot = math.abs(angle_end) + math.abs(angle_start)
    local cur_rpm = 0.6
    local cur_speed = 0
    local gear = 0

    local rotate_rpm_neddle = function()
        if cur_rpm < 0.6 then cur_rpm = 0.6 end
        matrix:rotate_y((total_rot / meter_max * cur_rpm + angle_start))
    end

    while true do
        if not DoesVehicleExist(veh, prefix) then return end

        local rea_speed = GetRealisticSpeed(veh)
               
        local fGas_state = math.floor(memory.getfloat(getCarPointer(veh)+0x49C))
        if fGas_state > 0 then
            if rea_speed > cur_speed then
                cur_speed = rea_speed
                cur_rpm = cur_rpm + (fTimeStep[0]/ 1.6666) * (fGas_state / 6.0)
            end
        else
            cur_rpm = cur_rpm - (fTimeStep[0]/ 1.6666) * 0.3
            cur_speed = 0
        end

        if gear < getCarCurrentGear(veh) then
            gear = getCarCurrentGear(veh)

            for i=1,10,1 do
                cur_rpm = cur_rpm - 0.1
                rotate_rpm_neddle()
                wait(0)
            end
            wait(100)
        end

        if cur_rpm > meter_max then 
            for i=1,2,1 do
                cur_rpm = cur_rpm - 0.1
                rotate_rpm_neddle()
                wait(0)
            end
            cur_rpm = meter_max 
        end

        rotate_rpm_neddle()

        wait(0)
    end
end

function FunctionalFrontBrake(veh, comp)

    local offset_angle = GetValue(FRONT_BRAKE_OFFSET_ANGLE,15,comp.name,"_ax(-?%d[%d.]*)")
    local wait_time = GetValue(FRONT_BRAKE_WAIT_TIME,1,comp.name,"_ms(%d)")

    local matrix = comp.modeling_matrix
    local pveh = getCarPointer(veh)

    LogProcessComponent(comp.name)
    while true do
        if not DoesVehicleExist(veh, prefix) then return end

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

function FunctionalRearBrake(veh, comp)

    local offset_angle = GetValue(REAR_BRAKE_OFFSET_ANGLE,15,comp.name,"_ax(-?%d[%d.]*)")
    local wait_time = GetValue(REAR_BRAKE_WAIT_TIME,1,comp.name,"_ms(%d)")

    local matrix = comp.modeling_matrix
    local pveh = getCarPointer(veh)

    LogProcessComponent(comp.name)
    while true do
        if not DoesVehicleExist(veh, prefix) then return end

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

function HighlightComponent(veh, prefix)
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

--------------------------------------------------

local find_callback  = 
{
    ["fc_chain"]     = FunctionalChain,
    ["fc_cl"]        = FunctionalClutch,
    ["fc_dled"]      = FunctionalDamageLed,
    ["fc_fbrake"]    = FunctionalFrontBrake,
    ["fc_gear"]      = FunctionalGearLever,
    ["fc_nled"]      = FunctionalNeutralLed,
    ["fc_pled"]      = FunctionalPowerLed,
    ["fc_om"]        = FunctionalOdometer,
    ["fc_sm"]        = FunctionalSpeedometer,
    ["fc_th"]        = FunctionalThrottle,
    ["fc_rbrake"]    = FunctionalRearBrake,
    ["fc_rpm"]       = FunctionalRPMmeter,
}


function main()

    while true do
        for _, veh in ipairs(getAllVehicles()) do
            if doesVehicleExist(veh) and tmain.veh_data[veh] == nil then
                tmain.veh_data[veh] = veh
                local model = getCarModel(veh)
                log.debug("")
                log.debug(string.format("Found vehicle %s (%d) %d",GetNameOfVehicleModel(model), model,getCarPointer(veh)))

                for _, comp in ipairs(mad.get_all_vehicle_components(veh)) do
                    local comp_name = comp.name

                    for name,func in pairs(find_callback) do
                        if string.find(comp_name,name) then
                            log.debug(string.format("Found '%s' in '%s'",name,comp_name))
                            lua_thread.create(func,veh,comp)
                        end
                    end
                end
            end
        end
        wait(0)
    end
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() then log.info("Log ended") end
end
