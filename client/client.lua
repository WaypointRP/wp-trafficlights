-- TODO: Create a useable item that can be placed using placeables logic
-- Maybe it has a custom option which is to open the traffic light menu (police / admin locked)
-- then it opens menu
-- menu has the diff options
local Config = TrafficLightsConfig


-- Used to store the data for each placed traffic light
local trafficLights = {}
-- Represents the traffic light object entity that is currently/last interacted with
local trafficLightObject = nil

-- Gets the direction the camera is looking to use for the raycast functions
local function RotationToDirection(rotation)
	local adjustedRotation =
	{
		x = (math.pi / 180) * rotation.x,
		y = (math.pi / 180) * rotation.y,
		z = (math.pi / 180) * rotation.z
	}
	local direction =
	{
		x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
		z = math.sin(adjustedRotation.x)
	}
	return direction
end

-- Uses a RayCast to get the entity, coords, and whether we "hit" something with the raycast
-- Object passed in, is the current object that we want the raycast to ignore
local function RayCastGamePlayCamera(distance, object)
    local entityToIgnore = object or 0
    local cameraRotation = GetGameplayCamRot()
	local cameraCoord = GetGameplayCamCoord()
	local direction = RotationToDirection(cameraRotation)
	local destination =
	{
		x = cameraCoord.x + direction.x * distance,
		y = cameraCoord.y + direction.y * distance,
		z = cameraCoord.z + direction.z * distance
	}

    local traceFlag = 1 -- 1 means the raycast will only intersect with the world (ignoring other entities like peds, cars, etc)
	local a, hit, coords, d, entity = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, traceFlag, entityToIgnore, 0))
	return hit, coords, entity
end

-- Starts a raycast thread for placing the stopping point where you want the cars to stop
-- Listens for key presses to change the radius of the stopping point, confirmation or cancel
local function setStoppingPoint()
    local color = {r = 255, g = 0, b = 0, a = 255}
    local stopPointRadius = Config.DefaultStopPointRadius

    -- Check that the trafficLightObject exists first
    if trafficLightObject then
        CreateThread(function()
            local isInPlacementMode = true
            while isInPlacementMode do
                local hit, coords, entity = RayCastGamePlayCamera(25.0)
                DrawMarker(25, coords.x, coords.y, coords.z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, stopPointRadius, stopPointRadius, 1.0, color.r, color.g, color.b, color.a, false, false, 2, nil, nil, false)

                DrawInstructionalButtons({
                    {id = Config.CancelButton, text = Config.CancelButtonText},
                    {id = Config.ConfirmButton, text = Config.ConfirmButtonText},
                    {id = Config.StopPointSmaller .. "." .. Config.StopPointBigger, text = Config.StopPointRadiusText},
                })

                -- Listen for keypresses

                -- Confirm stopping point position
                if IsControlJustReleased(0, Config.ConfirmButton) then
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    isInPlacementMode = false

                    -- Set this traffic light to green on setting/updating the stopping point
                    TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), Config.LightSetting.Green, coords, stopPointRadius)
                end

                -- Increase radius of stopping zone
                if IsControlJustReleased(0, Config.StopPointSmaller) then
                    stopPointRadius = stopPointRadius + 0.5
                end

                -- Decrease radius of stopping zone
                if IsControlJustReleased(0, Config.StopPointBigger) then
                    stopPointRadius = stopPointRadius - 0.5
                end

                -- Cancel placement mode
                if IsControlJustReleased(0, Config.CancelButton) then
                    isInPlacementMode = false
                end

                Wait(1)
            end
        end)
    else
        Notify('You need to place a traffic light first', 'error', 5000)
    end

end

-- Updates the traffic light mode and sends a call to sync other clients
---@param selectedLightSetting number The light setting to change to
local function setTrafficLightMode(selectedLightSetting)
    if not trafficLightObject then
        Notify('Lost connection to traffic light', 'error', 5000)
        return
    end

    local trafficLightNetId = ObjToNet(trafficLightObject)
    local speedZoneCoords = trafficLights[trafficLightNetId].speedZoneCoords
    local radius = trafficLights[trafficLightNetId].radius

    if not speedZoneCoords then
        Notify('You need to set the stopping point first', 'error', 5000)
    else
        -- Switch to yellow first before switching to red light
        if selectedLightSetting == Config.LightSetting.Red then
            TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), Config.LightSetting.Yellow, speedZoneCoords, radius)
            Wait(2000)
            TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), Config.LightSetting.Red, speedZoneCoords, radius)
        else
            TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), selectedLightSetting, speedZoneCoords, radius)
        end
    end
end

-- Flash yellow lights on and off for this specific light
-- NOTE: There is a known bug with how this flashing light logic is setup
-- If a player sets his light to flashing it will only make that light flash,
-- but once he changes to a different setting, other traffic lights will have theirs turned off
-- and the player has to retoggle it. 
---@param entityNetId number The entityId of the traffic light
local function setYellowFlashingLights(entityNetId)
    CreateThread(function()
        local trafficLightEntity = NetToObj(entityNetId)

        while trafficLights[entityNetId].lightSetting == Config.LightSetting.YellowFlashing do
            local flashTime = Config.FlashInterval * 1000
            SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Yellow)
            Wait(flashTime)

            -- Below check makes sure we are still in yellow flashing mode
            -- It is necessary to do the check here again because of the above wait. In this timeframe the user could have changed to a different lightsetting.
            -- If we don't check that we are still in flashing yellow mode, then it would end up executing the below line and result in changing from what the user just set
            if trafficLights[entityNetId].lightSetting == Config.LightSetting.YellowFlashing then
                SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Off)
                Wait(flashTime)
            end
        end
    end)
end

-- Delete the prop, remove the stopping zone, and clean up the variables
---@param data table The data passed in from the target script
local function removeTrafficLight(data)
    -- Call GreenLightSetting to get traffic moving again
    TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), Config.LightSetting.Green, nil, nil)

    -- Reset variables
    trafficLightObject = nil

    -- Utilizing wp-placeables to pickup and delete object
    TriggerEvent('wp-placeables:client:pickUpItem', data)
end

---------------------------
-- Menu
---------------------------
local menuLocation = 'topright'

local menu = MenuV:CreateMenu(false, "Traffic Control Device", menuLocation, 154, 189, 191, 'size-125', 'none', 'menuv', 'mainmenu')

-- Add the main menu screen buttons
menu:AddButton({
    icon = '🛑',
    label = "Set Stopping Point",
    value = nil,
    description = "The point where traffic should stop at",
    select = setStoppingPoint
})

menu:AddButton({
    icon = '🔴',
    label = "Set Red Light",
    value = Config.LightSetting.Red,
    description = "Toggle to a red light",
    select = function(data) 
        setTrafficLightMode(data.Value)
    end
})

menu:AddButton({
    icon = '🟡',
    label = "Set Flashing Yellow Lights",
    value = Config.LightSetting.YellowFlashing,
    description = "Toggle to flashing yellow lights",
    select = function(data) 
        setTrafficLightMode(data.Value)
    end
})

menu:AddButton({
    icon = '🟢',
    label = "Set Green Light",
    value = Config.LightSetting.Green,
    description = "Toggle to a green light",
    select = function(data) 
        setTrafficLightMode(data.Value)
    end
})

menu:AddButton({
    icon = '🏁',
    label = "Race Start",
    value = Config.LightSetting.RaceLight,
    description = "Toggle to a green light",
    select = function(data) 
        setTrafficLightMode(data.Value)
    end
})

---------------------------
-- End Menu
---------------------------

-- Opens menu from using target or if you've already used it you can use the command to open the menu for the last selected traffic light
RegisterNetEvent('wp-trafficlights:client:OpenMenu', function(data)
    -- Opening via command make sure already has a traffic light object
    local isOpeningViaCommand = not data and trafficLightObject

    -- Opening via target, make sure we have data.entity
    local isOpeningViaTarget = (data and data.entity)
    if isOpeningViaTarget then
        trafficLightObject = data.entity
    end

    if isOpeningViaCommand or isOpeningViaTarget then
        MenuV:OpenMenu(menu)
    else 
        Notify('You need to connect to a traffic light first', 'error', 5000)
    end
end)

-- Updates the given traffic light to a different light setting
---@param entityNetId number The network id of the traffic light entity
---@param lightSetting number The light setting to change to
---@param speedZoneCoords table The coords of the speed zone / stopping point
---@param radius number The radius of the speed zone / stopping point
RegisterNetEvent('wp-trafficlights:client:UpdateTrafficLightSetting')
AddEventHandler('wp-trafficlights:client:UpdateTrafficLightSetting', function(entityNetId, lightSetting, speedZoneCoords, radius)
    local trafficLightEntity = NetToObj(entityNetId)

    -- Create an entry if it does not yet exist
    if not trafficLights[entityNetId] then 
        trafficLights[entityNetId] = {}
    end

    -- Update the fields
    trafficLights[entityNetId].speedZoneCoords = speedZoneCoords
    trafficLights[entityNetId].radius = radius
    trafficLights[entityNetId].lightSetting = lightSetting

    -- Remove the speed zone (if it exists) and allow cars to move again
    if trafficLights[entityNetId].roadNodeSpeedZone then
        RemoveRoadNodeSpeedZone(trafficLights[entityNetId].roadNodeSpeedZone) 
    end

    -- Light == Green, allow cars to move again
    if lightSetting == Config.LightSetting.Green then
		SetEntityTrafficlightOverride(trafficLightEntity, lightSetting)
    -- Light == Red, stop cars at the stopping point by creating a road node speed zone with speed 0.
	elseif lightSetting == Config.LightSetting.Red then
		trafficLights[entityNetId].roadNodeSpeedZone = AddRoadNodeSpeedZone(speedZoneCoords, radius, 0.0, false)
		SetEntityTrafficlightOverride(trafficLightEntity, lightSetting)
    -- Light == Solid Yellow, allow cars to move
	elseif lightSetting == Config.LightSetting.Yellow then
		SetEntityTrafficlightOverride(trafficLightEntity, lightSetting)
    -- Light == Flashing Yellow, creates a road node speed zone with a slow speed, allowing cars to move slowly through
	elseif lightSetting == Config.LightSetting.YellowFlashing then
        -- Lower the speed limit in this zone while lights are flashing
        trafficLights[entityNetId].roadNodeSpeedZone = AddRoadNodeSpeedZone(speedZoneCoords, radius, Config.FlashingYellowSpeedLimit, false)

        setYellowFlashingLights(entityNetId)
    -- Light == Race start sequence. Lights will flash Red, Yellow, Yellow, Yellow, Green
    elseif lightSetting == Config.LightSetting.RaceLight then
        SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Red)
        Wait(1000)
        SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Off)
        Wait(1000)
        SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Yellow)
        Wait(1000)
        SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Off)
        Wait(1000)
        SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Yellow)
        Wait(1000)
        SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Off)
        Wait(1000)
        SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Yellow)
        Wait(1000)
        SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Off)
        Wait(1000)
        SetEntityTrafficlightOverride(trafficLightEntity, Config.LightSetting.Green)
	end
end)

-- When the player removes a traffic light, this is used to cleanup the state of the traffic light
RegisterNetEvent('wp-trafficlights:RemoveTrafficLight', function(data)
    removeTrafficLight(data)
end)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/trafficlight', 'Use the menu for the traffic light last interacted with')
end)
