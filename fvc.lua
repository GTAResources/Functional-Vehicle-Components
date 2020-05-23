script_name('Functional Vehicle Components')
script_author("Grinch_")
script_version("1.0-beta")
script_version_number(2020052401) -- YYYYMMDDNN
script_description("Adds more features/ functions to vehicle components")
script_dependencies("ffi", "Memory", "MoonAdditions", "log")
script_properties('work-in-pause')
script_url("https://github.com/user-grinch/Functional-Vehicle-Components")

--------------------------------------------------
-- Special thanks to kkjj & Zeneric for their help
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
GEAR_LEVER_TYPE = 1

-- FunctionalOdometer
ODOMETER_ROTATION_ANGLE = 36
ODOMETER_ROTATION_WAIT_TIME = 25
ODOMETER_DEFAULT_TYPE = "analog"

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
REAR_BRAKE_NORMAL_ANGLE = 0
REAR_BRAKE_OFFSET_ANGLE = 15
REAR_BRAKE_WAIT_TIME = 1

-- FunctionalRPMMeter
RPMMETER_ANGLE_START = 0
RPMMETER_ANGLE_END = 180
RPMMETER_MAX_RPM = 10
--------------------------------------------------

tmain = 
{
    gsx = {
        handle = getModuleHandle("gsx.asi"),
        veh_data = {},
    },
    skygfx = {
        handle  =  getModuleHandle("skygfx.asi"),
        pconfig = nil, 
    }
}

--------------------------------------------------
-- Libraries & modules

ffi         = require 'ffi'
memory      = require 'memory'
mad         = require 'MoonAdditions'
imgui       = require 'imgui'

flog        = require 'lib.functional-vehicle-components.log'
futil       = require 'lib.functional-vehicle-components.util'

fdashboard  = require 'lib.functional-vehicle-components.dashboard'
fgsx        = require 'lib.functional-vehicle-components.gsx'
fmisc       = require 'lib.functional-vehicle-components.misc'
----------------------------------------------------

flog.Start()
math.randomseed(os.time())
CVehicleModelInfo = ffi.cast("uintptr_t*", 0xA9B0C8)
isThisModelABike = ffi.cast("bool(*)(int model)", 0x4C5B60)
fTimeStep = ffi.cast("float*",0xB7CB5C) -- CTimer::ms_fTimeStep

-- Get skygfx pconfig
if tmain.skygfx.handle ~= 0 then
    local result,addr =  getDynamicLibraryProcedure("GetConfig",tmain.skygfx.handle)

    if result then
        flog.Write("SkyGFX installed")
        tmain.skygfx.pconfig = callFunction(addr,0,0)
    end
end

local find_callback  = 
{
    ["fc_chain"]     = fmisc.Chain,
    ["fc_cl"]        = fmisc.Clutch,
    ["fc_dled"]      = fdashboard.DamageLed,
    ["fc_fbrake"]    = fmisc.FrontBrake,
    ["fc_fm"]        = fdashboard.FuelMeter,
    ["fc_gl"]        = fmisc.GearLever,
    ["fc_gv"]        = fdashboard.GearMeter,
    ["fc_nled"]      = fdashboard.NeutralLed,
    ["fc_pled"]      = fdashboard.PowerLed,
    ["fc_om"]        = fdashboard.Odometer,
    ["fc_sm"]        = fdashboard.Speedometer,
    ["fc_th"]        = fmisc.Throttle,
    ["fc_rbrake"]    = fmisc.RearBrake,
    ["fc_rpm"]       = fdashboard.RPMmeter,
}

function main()

    local veh_data = tmain.gsx.veh_data

    while true do
    
        for _, veh in ipairs(getAllVehicles()) do

            if doesVehicleExist(veh) and veh_data[veh] == nil then
                local model = getCarModel(veh)
                
                if tmain.gsx.handle ~= 0 then 
                    local pveh = getCarPointer(veh)
                    if DataToLoadExists(pveh,"FVC_DATA") == 1 then
                        local pdata = GetLoadDataByVehPtr(pveh,"FVC_DATA")
                        local size  = GetDataToLoadSize(pveh,"FVC_DATA") 
                        veh_data[veh] = decodeJson(memory.tostring(pdata,size,false))                 
                    end
                end

                if veh_data[veh] == nil then
                    fgsx.Set(veh,"odo_val",math.random(10000, 200000))
                end

                flog.Write("")
                flog.Write(string.format("Found vehicle %s (%d)",futil.GetNameOfVehicleModel(model), model))

                for _, comp in ipairs(mad.get_all_vehicle_components(veh)) do
                    local comp_name = comp.name

                    for name,func in pairs(find_callback) do
                        if string.find(comp_name,name) then
                            flog.Write(string.format("Found '%s' in '%s'",name,comp_name))
                            lua_thread.create(func,veh,comp)
                        end
                    end
                end
            end
        end
        wait(0)
    end
    wait(0)
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() then 
        flog.Close()
        if tmain.gsx.handle ~= 0 then
            fgsx.RemoveNotifyCallback(fgsx.pNotifyCallback)
        end
    end
end
