-- TODO: Create a useable item that can be placed using placeables logic
-- Maybe it has a custom option which is to open the traffic light menu (police / admin locked)
-- then it opens menu
-- menu has the diff options
local Config = TrafficLightsConfig
local stopPointRadius = Config.DefaultStopPointRadius

-- Represents the traffic light object entity that is currently/last interacted with
local trafficLightObject = nil
local isStoppingPointSet = false
local stoppingPointCoords = nil
local flashingYellowLights = false
local trafficLights = {} -- Used to store the traffic light zones settings for each player

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
				    stoppingPointCoords = coords
                    isStoppingPointSet = true
                    isInPlacementMode = false

                    -- Set this traffic light to green on setting/updating the stopping point
                    TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), Config.LightSetting.Green, stoppingPointCoords, stopPointRadius)
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
local function setTrafficLightMode(data)
    local lightMode = data.Value

    if not trafficLightObject then
        Notify('Lost connection to traffic light', 'error', 5000)
    elseif not stoppingPointCoords then
        Notify('You need to set the stopping point first', 'error', 5000)
    else
        if lightMode == Config.LightSetting.Red then
            -- Show 2 seconds of yellow then switch to red
            TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), Config.LightSetting.Yellow, stoppingPointCoords, stopPointRadius)
            Wait(2000)
            TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), Config.LightSetting.Red, stoppingPointCoords, stopPointRadius)
        else
            TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), lightMode, stoppingPointCoords, stopPointRadius)
        end
    end
end

-- Flash yellow lights on and off for this specific light
-- NOTE: There is a known bug with how this flashing light logic is setup
-- If a player sets his light to flashing it will only make that light flash,
-- but once he changes to a different setting, other traffic lights will have theirs turned off
-- and the player has to retoggle it. 
local function setYellowFlashingLights(obj)
    CreateThread(function()
        local obj = NetToObj(obj)
        while flashingYellowLights do
            local flashTime = Config.FlashInterval * 1000
            SetEntityTrafficlightOverride(obj, Config.LightSetting.Yellow)
            Wait(flashTime)
            SetEntityTrafficlightOverride(obj, Config.LightSetting.Off)
            Wait(flashTime)
        end
    end)
end

-- Delete the prop, remove the stopping zone, and clean up the variables
---@param data table The data passed in from the target script
local function removeTrafficLight(data)
    -- Call GreenLightSetting to get traffic moving again
    TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), Config.LightSetting.Green, stoppingPointCoords, stopPointRadius)
    
    -- Reset variables
    flashingYellowLights = false
    stoppingPointCoords = nil
    isStoppingPointSet = false
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
    select = setTrafficLightMode
})

menu:AddButton({
    icon = '🟡',
    label = "Set Flashing Yellow Lights",
    value = Config.LightSetting.YellowFlashing,
    description = "Toggle to flashing yellow lights",
    select = setTrafficLightMode
})

menu:AddButton({
    icon = '🟢',
    label = "Set Green Light",
    value = Config.LightSetting.Green,
    description = "Toggle to a green light",
    select = setTrafficLightMode
})

menu:AddButton({
    icon = '🏁',
    label = "Race Start",
    value = Config.LightSetting.RaceLight,
    description = "Toggle to a green light",
    select = setTrafficLightMode
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
RegisterNetEvent('wp-trafficlights:client:UpdateTrafficLightSetting')
AddEventHandler('wp-trafficlights:client:UpdateTrafficLightSetting', function(object, lightSetting, speedZoneCoords, playerName, radius)
	-- Light == Green, allow cars to move again
    if lightSetting == Config.LightSetting.Green then
		RemoveRoadNodeSpeedZone(trafficLights[playerName]) -- Allow cars to move again
		flashingYellowLights = false

		SetEntityTrafficlightOverride(NetToObj(object), lightSetting)
    -- Light == Red, stop cars at the stopping point. Cleans up any previous speed zones
	elseif lightSetting == Config.LightSetting.Red then
        RemoveRoadNodeSpeedZone(trafficLights[playerName]) -- Get rid of the zone if it already existed
		flashingYellowLights = false

		trafficLights[playerName] = AddRoadNodeSpeedZone(speedZoneCoords, radius, 0.0, false) -- Stops movement by setting speed to 0.0
		SetEntityTrafficlightOverride(NetToObj(object), lightSetting)
    -- Light == Solid Yellow, allow cars to move
	elseif lightSetting == Config.LightSetting.Yellow then
		flashingYellowLights = false

		SetEntityTrafficlightOverride(NetToObj(object), lightSetting)
    -- Light == Flashing Yellow, allow cars to move at a slower speed
	elseif lightSetting == Config.LightSetting.YellowFlashing then
        RemoveRoadNodeSpeedZone(trafficLights[playerName]) -- Allow cars to move again
		flashingYellowLights = true

        -- Lower the speed limit in this zone while lights are flashing
        trafficLights[playerName] = AddRoadNodeSpeedZone(speedZoneCoords, radius, Config.FlashingYellowSpeedLimit, false)

        setYellowFlashingLights(object)
    -- Light == Race start sequence. Lights will flash Red, Yellow, Yellow, Yellow, Green
    elseif lightSetting == Config.LightSetting.RaceLight then
        local obj = NetToObj(object)
        SetEntityTrafficlightOverride(obj, Config.LightSetting.Red)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, Config.LightSetting.Off)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, Config.LightSetting.Yellow)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, Config.LightSetting.Off)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, Config.LightSetting.Yellow)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, Config.LightSetting.Off)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, Config.LightSetting.Yellow)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, Config.LightSetting.Off)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, Config.LightSetting.Green)

        RemoveRoadNodeSpeedZone(trafficLights[playerName]) -- Allow cars to move again
	end
end)

-- When the player removes a traffic light, this is used to cleanup the state of the traffic light
RegisterNetEvent('wp-trafficlights:RemoveTrafficLight', function(data)
    removeTrafficLight(data)
end)
