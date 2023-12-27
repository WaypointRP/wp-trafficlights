-- This is intentionally not named Config, else the menuv dependency Config variable ends up overwriting this Config variable
TrafficLightsConfig = {}

-- Frameworks
-- Supported framework options are listed next to each option
-- If the framework you are using is not listed, you will need to modify the framework.lua code to work with your framework
-- Note: If using ox for any option, enable @ox_lib/init.lua in the manifest!

TrafficLightsConfig.Framework = 'qb' -- 'qb', 'esx'
TrafficLightsConfig.Notify = 'qb'    -- 'qb', 'esx', 'ox'

 -- Seconds between flashes when set to flashing mode
TrafficLightsConfig.FlashInterval = 1.0
