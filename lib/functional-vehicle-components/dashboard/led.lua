
function module.NeutralLed(veh, comp)

    flog.ProcessingComponent(comp.name)
    while true do
        if not doesVehicleExist(veh) then return end

        if getCarCurrentGear(veh) == 0 and isCarEngineOn(veh) then
            futil.SetMaterialColor(comp,0,200,0,255)
        else
            futil.SetMaterialColor(comp,10,25,10,255)
        end
        
        wait(0)
    end
end

function module.DamageLed(veh, comp)

    flog.ProcessingComponent(comp.name)
    while true do
        if not doesVehicleExist(veh) then return end

        if getCarHealth(veh) < 650 and isCarEngineOn(veh) then
            futil.SetMaterialColor(comp,255,30,21,255)
        else
            futil.SetMaterialColor(comp,30,10,10,255)
        end
        wait(0)
    end
end

function module.PowerLed(veh, comp)

    flog.ProcessingComponent(comp.name)
    while true do
        local speed = futil.GetRealisticSpeed(veh, 1)
        if not doesVehicleExist(veh) then return end

        if isCarEngineOn(veh) then
            if speed >= 100 then
                futil.SetMaterialColor(comp,240,0,0,255)
            else
                futil.SetMaterialColor(comp,0,200,0,255)
            end
        else
            futil.SetMaterialColor(comp,30,30,30,255)
        end
        wait(0)
    end
end

function module.HighBeamLed(veh, comp)
    if tmain.ImVehFt.handle ~= 0 then
        
        local pveh = getCarPointer(veh)
        local hb_status = fgsx.Get(veh,"hb_led")
        local timer
        local light_status = 0
        while true do
            timer = memory.read(tmain.ImVehFt.handle+0x3BC20,4)
            light_status = bit.band(memory.read(pveh + 0x428, 2), 64)
            if isCharInCar(PLAYER_PED, veh) then
                if tmain.ImVehFt.hb_timer < timer and light_status == 64 then
                    tmain.ImVehFt.hb_timer = timer
                    hb_status = not hb_status
                end
            end

            if hb_status and light_status == 64 and isCarEngineOn(veh) then
                futil.SetMaterialColor(comp,30,30,60,255)
            else
                futil.SetMaterialColor(comp,50,50,255,255)
            end
        
            wait(0)
        end
    end
end