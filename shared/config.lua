-- This is intentionally not named Config, else the menuv dependency Config variable ends up overwriting this Config variable
TrafficLightsConfig = {}

------------------------------------
-- FRAMEWORK / SCRIPT CONFIGURATION
-- Adjust these settings to match the framework and scripts you are using
-- Note: If using ox for any option, enable @ox_lib/init.lua in the manifest!
------------------------------------

--- @type "qb" | "qbx" | "esx"
TrafficLightsConfig.Framework = "qb"

-- The notification script you are using.
--- @type "qb" | "esx" | "ox" | "none"
TrafficLightsConfig.Notify = "qb"

------------------------------------
--- END FRAMEWORK / SCRIPT CONFIGURATION
------------------------------------

TrafficLightsConfig.ConfirmButton = 38     -- E
TrafficLightsConfig.CancelButton = 177     -- Right click / backspace
TrafficLightsConfig.StopPointSmaller = 241 -- Scroll wheel up
TrafficLightsConfig.StopPointBigger = 242  -- Scroll wheel down

TrafficLightsConfig.ConfirmButtonText = "Confirm"
TrafficLightsConfig.CancelButtonText = "Cancel"
TrafficLightsConfig.StopPointRadiusText = "+/- Radius"

TrafficLightsConfig.DefaultStopPointRadius = 4.5

-- Seconds between flashes when set to flashing mode
TrafficLightsConfig.FlashInterval = 1.0

-- The speed vehicles can travel at when the yellow lights are flashing
TrafficLightsConfig.FlashingYellowSpeedLimit = 5.0 -- in m/s (5m/s = ~11MPH)

-- Represents the different traffic light modes
-- 0-2 are used by the natives for green, red, yellow
TrafficLightsConfig.LightSetting = {
    Off = -1,
    Green = 0,
    Red = 1,
    Yellow = 2,
    -- Custom (non-native) settings below
    YellowFlashing = 3,
    RaceLight = 4,
}
