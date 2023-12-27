-- TODO: Create a useable item that can be placed using placeables logic
-- Maybe it has a custom option which is to open the traffic light menu (police / admin locked)
-- then it opens menu
-- menu has the diff options
local Config = TrafficLightsConfig

local trafficLightObject = nil
local isStoppingPointSet = false
local speedZoneStoppingPointCoords = nil
local stopPointRadius = 4.5
local flashingYellowLights = false
local playerTrafficLights = {} -- Used to store the traffic light zones settings for each player
-- The different light modes
local GreenLightSetting = 0
local RedLightSetting = 1
local YellowLightSetting = 2
local YellowLightFlashingSetting = 3
local RaceLightSetting = 4

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

local function setStoppingPoint()
    local color = {r = 255, g = 0, b = 0, a = 255}

    -- Check that the trafficLightObject exists first
    if trafficLightObject then
        CreateThread(function()
            local isInPlacementMode = true
            while isInPlacementMode do
                local hit, coords, entity = RayCastGamePlayCamera(25.0)
                DrawMarker(25, coords.x, coords.y, coords.z+0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, stopPointRadius, stopPointRadius, 1.0, color.r, color.g, color.b, color.a, false, false, 2, nil, nil, false)

                DrawInstructionalButtons({
                    {id = Config.CancelButton, text = Config.CancelButtonText},
                    {id = Config.ConfirmButton, text = Config.ConfirmButtonText},
                    {id = Config.StopPointSmaller .. "." .. Config.StopPointBigger, text = Config.StopPointRadiusText},
                })

                -- Listen for keypresses

                -- E to confirm
                if IsControlJustReleased(0, 38) then
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
				    speedZoneStoppingPointCoords = coords
                    isStoppingPointSet = true
                    isInPlacementMode = false

                    -- Set this traffic light to green on setting/updating the stopping point
                    TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), GreenLightSetting, speedZoneStoppingPointCoords, stopPointRadius)
                end

                -- Scroll wheel up to increase radius
                if IsControlJustReleased(0, 241) then
                    stopPointRadius = stopPointRadius + 0.5
                end

                -- Scroll wheel down to decrease radius
                if IsControlJustReleased(0, 242) then
                    stopPointRadius = stopPointRadius - 0.5
                end

                -- Right click or Backspace to cancel
                if IsControlJustReleased(0, 177) then
                    isInPlacementMode = false
                end

                Wait(1)
            end
        end)
    else
        Notify('You need to place a traffic light first', 'error', 5000)
    end

end

-- Updates the traffic light to green, red, or yellow flashing lights and sends a call to sync other clients
local function setTrafficLightMode(data)
    local lightMode = data.Value

    if not trafficLightObject then
        Notify('Lost connection to traffic light', 'error', 5000)
    elseif not speedZoneStoppingPointCoords then
        Notify('You need to set the stopping point first', 'error', 5000)
    else
        if lightMode == RedLightSetting then
            -- Show 2 seconds of yellow then switch to red
            TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), YellowLightSetting, speedZoneStoppingPointCoords, stopPointRadius)
            Wait(2000)
            TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), RedLightSetting, speedZoneStoppingPointCoords, stopPointRadius)
        else
            TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), lightMode, speedZoneStoppingPointCoords, stopPointRadius)
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
        while flashingYellowLights do
            local flashTime = Config.FlashInterval * 1000
            SetEntityTrafficlightOverride(obj, 2)
            Wait(flashTime)
            SetEntityTrafficlightOverride(obj, -1)
            Wait(flashTime)
        end
    end)
end

-- Delete the prop and clean up the variables
local function removeTrafficLight(data)
    -- Call GreenLightSetting to get traffic moving again
    TriggerServerEvent('wp-trafficlights:UpdateTrafficLight', ObjToNet(trafficLightObject), GreenLightSetting, speedZoneStoppingPointCoords, stopPointRadius)
    flashingYellowLights = false
    speedZoneStoppingPointCoords = nil
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
    value = RedLightSetting,
    description = "Toggle to a red light",
    select = setTrafficLightMode
})

menu:AddButton({
    icon = '🟡',
    label = "Set Flashing Yellow Lights",
    value = YellowLightFlashingSetting,
    description = "Toggle to flashing yellow lights",
    select = setTrafficLightMode
})

menu:AddButton({
    icon = '🟢',
    label = "Set Green Light",
    value = GreenLightSetting,
    description = "Toggle to a green light",
    select = setTrafficLightMode
})

menu:AddButton({
    icon = '🏁',
    label = "Race Start",
    value = RaceLightSetting,
    description = "Toggle to a green light",
    select = setTrafficLightMode
})

---------------------------
-- End Menu
---------------------------

-- Opens menu from using qbtarget or if you've already used it you can use the command to open this menu
RegisterNetEvent('wp-trafficlights:client:OpenMenu', function(data)
    -- Opening via command make sure already has a traffic light object
    local openingViaCommand = not data and trafficLightObject
    -- Opening via target, make sure we have data.entity
    local hasData = (data and data.entity)
    if openingViaCommand or hasData then
        if hasData then
            trafficLightObject = data.entity
        end

        MenuV:OpenMenu(menu)
    else 
        Notify('You need to connect to a traffic light first', 'error', 5000)
    end
end)

-- Updates the given traffic light to a different light setting
RegisterNetEvent('wp-trafficlights:client:UpdateTrafficLightSetting')
AddEventHandler('wp-trafficlights:client:UpdateTrafficLightSetting', function(object, lightSetting, speedZoneCoords, playerName, radius)
	if lightSetting == GreenLightSetting then
		flashingYellowLights = false
		RemoveSpeedZone(playerTrafficLights[playerName]) -- Allow cars to move again
		SetEntityTrafficlightOverride(NetToObj(object), lightSetting)
	elseif lightSetting == RedLightSetting then
        RemoveSpeedZone(playerTrafficLights[playerName]) -- Allow cars to move again (get rid of the zone if it already existed)
		flashingYellowLights = false
		playerTrafficLights[playerName] = AddSpeedZoneForCoord(speedZoneCoords, radius, 0.0, false) -- Make them stop
		SetEntityTrafficlightOverride(NetToObj(object), lightSetting)
	elseif lightSetting == YellowLightSetting then
		flashingYellowLights = false
		SetEntityTrafficlightOverride(NetToObj(object), lightSetting)
	elseif lightSetting == YellowLightFlashingSetting then
        RemoveSpeedZone(playerTrafficLights[playerName]) -- Allow cars to move again
		flashingYellowLights = true
        -- Make the speed limit 5m/s (~11MPH) in this zone while lights are flashing
        playerTrafficLights[playerName] = AddSpeedZoneForCoord(speedZoneCoords, radius, 5.0, false)

        local obj = NetToObj(object) 
        setYellowFlashingLights(obj)
    elseif lightSetting == RaceLightSetting then
        -- Red, Yellow, Yellow, Yellow, Green
        local obj = NetToObj(object)
        SetEntityTrafficlightOverride(obj, RedLightSetting)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, -1)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, YellowLightSetting)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, -1)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, YellowLightSetting)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, -1)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, YellowLightSetting)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, -1)
        Wait(1000)
        SetEntityTrafficlightOverride(obj, GreenLightSetting)
        RemoveSpeedZone(playerTrafficLights[playerName]) -- Allow cars to move again
	end
end)

RegisterNetEvent('wp-trafficlights:RemoveTrafficLight', function(data)
    removeTrafficLight(data)
end)
