RegisterServerEvent('xnTrafficLights:UpdateTrafficLight')
AddEventHandler('xnTrafficLights:UpdateTrafficLight', function(trafficLightObject, lightSetting, speedZoneCoords, radius)
	local src = source
	TriggerClientEvent('xnTrafficLights:client:UpdateTrafficLightSetting', -1, trafficLightObject, lightSetting, speedZoneCoords, GetPlayerName(src), radius)
end)

-- If you want to add conditions for opening the menu, this is where you'd do it, or you could even use Ace Permissions
-- This command will also only work if the player has already "interacted" with a traffic light
RegisterCommand("trafficlight", function(source, args)
	TriggerClientEvent('xnTrafficLights:client:OpenMenu', source)
end, false)