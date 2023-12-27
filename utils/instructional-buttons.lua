-- Referenced from glitchdetector: https://github.com/glitchdetector/fivem-instructional-buttons

local function ButtonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

local function Button(ControlButton)
    ScaleformMovieMethodAddParamPlayerNameString(ControlButton)
end

-- Accepts an array of button objects containing the button id and text to display next to it
-- Ex: { { id = 38, text = "Confirm" }, { id = 177, text = "Cancel" } }
-- Note: The buttons are rendered from right to left, so structure the array accordingly (first item will be on the right)
-- Multiple button ids can be passed in an id if they are separted by a period. Ex: { id = "38.154", text = "Confirm" }. This will render [E][X] Confirm
function DrawInstructionalButtons(buttons)
    local scaleform = RequestScaleformMovie("instructional_buttons")
    while not HasScaleformMovieLoaded(scaleform) do
        Wait(0)
    end

    -- draw it once to set up layout
    DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 0, 0)

    PushScaleformMovieFunction(scaleform, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()
    
    PushScaleformMovieFunction(scaleform, "SET_CLEAR_SPACE")
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    local position = 0
    for _, button in pairs(buttons) do
        PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(position)

        -- Renders the button(s) based on its id
        if string.match(button.id, "%.") then
			for i in string.gmatch(button.id, "[^.]+") do
				Button(GetControlInstructionalButton(2, tonumber(i), true))
			end
		else
			Button(GetControlInstructionalButton(2, button.id, true))
		end

        -- Renders the message next to the button
        ButtonMessage(button.text) 
        PopScaleformMovieFunctionVoid()
        position = position + 1
    end

    PushScaleformMovieFunction(scaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_BACKGROUND_COLOUR")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(80)
    PopScaleformMovieFunctionVoid()

    return scaleform
end
