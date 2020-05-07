
function module.NeutralLed(veh, comp)

    flog.ProcessingComponent(comp.name)
    while true do
        if not doesVehicleExist(veh) then return end

        if getCarCurrentGear(veh) == 0 and isCarEngineOn(veh) then
            futil.SetMaterialColor(comp,0,200,0,200)
        else
            futil.SetMaterialColor(comp,10,25,10,200)
        end
        
        wait(0)
    end
end

function module.DamageLed(veh, comp)

    flog.ProcessingComponent(comp.name)
    while true do
        if not doesVehicleExist(veh) then return end

        if getCarHealth(veh) < 650 and isCarEngineOn(veh) then
            futil.SetMaterialColor(comp,255,30,21,200)
        else
            futil.SetMaterialColor(comp,30,10,10,200)
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
                futil.SetMaterialColor(comp,240,0,0,200)
            else
                futil.SetMaterialColor(comp,0,200,0,200)
            end
        else
            futil.SetMaterialColor(comp,30,30,30,200)
        end
        wait(0)
    end
end

function module.HighBeamLed(veh, comp)
    if tmain.ImVehFt.handle ~= 0 then
        local pveh = getCarPointer(veh)
        local hb_status = fgsx.Get(pveh,"hb_led") or 0

        while true do

            if isCharInCar(PLAYER_PED, veh) then
                local timer = readMemory(tmain.ImVehFt.handle+0x3BC20,4,true)
                if tmain.ImVehFt.hb_timer < timer then
                    tmain.ImVehFt.hb_timer = timer
                    hb_status = not hb_status
                end
            end

            if hb_status and bit.band(memory.read(pveh + 0x428, 2), 64) ~= 0 and isCarEngineOn(veh) then
                futil.SetMaterialColor(comp,30,30,60,200)
            else
                futil.SetMaterialColor(comp,50,50,255,255)
            end

            wait(0)
        end
    end
end