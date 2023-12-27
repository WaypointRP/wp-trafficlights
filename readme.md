# Traffic Lights

Simple deployable traffic lights that can be interacted with to control the flow of AI traffic.

The menu has options for Green, Red, Yellow Flashing, Race Start lights.

Player places a stopping point, which dictates where traffic will stop when the light is red.

While the script doesnt limit you to putting one traffic light down, its recommended to only control one at a time for the time being.


## Credit
This script is based off of Smallos [xnTrafficLights](https://github.com/smallo92/xnTrafficLights). It is heavily modified to run more performantly (removed several `while true` loops), remove dependency on jaymenu and work better with our custom [wp-placeables](https://github.com/WaypointRP/wp-placeables) script to handle the placement of the props.


 FOr items.lua
["trafficlight"] 			= {["name"] = "trafficlight", 			["label"] = "Traffic Light", 			        ["weight"] = 1000, 		    ["type"] = "item", 		["image"] = "trafficlight.png", 		["unique"] = false, 	["useable"] = true, 	["shouldClose"] = true,    ["combinable"] = nil,   ["description"] = "A deployable traffic control device"},


ensure wp-placeables
ensure menuv
ensure wp-trafficlights

## Dependencies
- wp-placeables
- menuv