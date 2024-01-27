# Waypoint Traffic Lights

![wp-trafficlights](https://github.com/WaypointRP/wp-trafficlights/assets/18689469/08129102-4bdb-43aa-b748-2724e1805374)

Simple deployable traffic lights that can be interacted with to control the flow of AI traffic.
This is an addon for [Waypoint Placeables](https://github.com/WaypointRP/wp-placeables), using it's logic for placing and picking up the objects. 
The traffic light menu allows players to control the traffic light using the following options: Green, Red, Yellow Flashing, and Race Start lights.

Players can get creative and use the traffic lights in a number of ways. Some examples include:
- Police DUI checkpoints
- Construction crews controlling traffic
- Traffic control at events
- Using the "Race Start" mode for the countdown for drag races

> Multiple traffic lights can be placed and operated at the same time. Updates to the traffic lights are synced between all players.

> This script is based off of Smallos [xnTrafficLights](https://github.com/smallo92/xnTrafficLights).

[Preview](https://www.youtube.com/watch?v=G4soDokEjZ8)

## Usage

Using the traffic lights is quite simple.
- Acquire a traffic light item
- Use the item and place the traffic light in the desired location
- Interact with the traffic light via target to open the menu
   - You can also use `/trafficlight` command to open the menu for the traffic light last interacted with
- Select the "Set stopping point" option
    - Choose the point where you want traffic to stop.
    - Change the radius of the stopping point using the mouse wheel up/down (configurable)
- Select the traffic light mode: Red, Green, Yellow Flashing, or Race Start

> Note: If using flashing yellow, it is recommended to have a large radius for your stopping point. Traffic will move slowly while inside the zone.

> Note: If you are using `ox` for any of the Framework options you need to uncomment `@ox_lib/init.lua` in the fxmanifest.lua.

## Setup

1. Ensure you have the dependencies [Waypoint Placeables](https://github.com/WaypointRP/wp-placeables) and menuv
2. Enable wp-trafficlights in your server.cfg.
    - Be sure to start it after `wp-placeables`
3. Update the config variables `Framework` and `Notify` to match your server setup.
4. Add the traffic light item to your items.lua file
    ```lua
    trafficlight = {name = "trafficlight", label = "Traffic Light", weight = 1000, type = "item", image = "trafficlight.png", unique = false, useable = true, shouldClose = true, combinable = nil, description = "A deployable traffic control device"},
    ```
5. Add the image `trafficlight.png` to your inventory script
6. Add a way for players to acquire the trafficlight item (ex: shop, crafting, etc.)
7. In `wp-placeables/shared/config.lua``, search for `-- Uncomment this line if you are using wp-trafficlights` and uncomment the following lines:
    ```lua
    local trafficLightCustomTargetOptions = {
        {
            event = "wp-trafficlights:client:OpenMenu",
            icon = "fas fa-traffic-light",
            label = "Remote control traffic light",
        },
    }

    local trafficLightCustomPickupEvent = "wp-trafficlights:RemoveTrafficLight"

    {item = "trafficlight", label= "Traffic light", model = "prop_traffic_03a", isFrozen = true, customTargetOptions = trafficLightCustomTargetOptions, customPickupEvent = trafficLightCustomPickupEvent},
    ```

## Performance

The script is designed to be as performant as possible.
Resource monitor results:
- While not in use: 0.00ms
- While in use w/ any mode: 0.00ms
- While placing stopping point (running a raycast): 0.12ms

## Dependencies

- [Waypoint Placeables](https://github.com/WaypointRP/wp-placeables)
   - This is used for placing/picking up the traffic lights items. If wish to use a different method or do not want an item based system, you can modify to suit your needs or use the original xnTrafficLights.
- QBCore / ESX / OX for Notifications 
- menuv

## Credit

This script is based off of Smallos [xnTrafficLights](https://github.com/smallo92/xnTrafficLights). Original logic and functionality is derived from xnTrafficLights.

Many modifications have been made to the original script to improve usability and performance. Some changes include:
- improve performance by removing several `while true` loops
- remove dependency on jaymenu
- add additional traffic light modes (flashing yellow, race start)
- allow placement and control of multiple traffic lights at the same time

@DonHulieo for providing insipiration and examples for structuring the framework.lua file.
