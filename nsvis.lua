--[[

MIT License
Copyright 2022 Julia C

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

]]

--[[

    Nightscout Minecraft Visualizer
    Created and maintained by Julia C,

    for my Diabetic friends (and enemies). <3

    If you have any questions, or need help with anything, feel free to reach out to me on
    Tumblr, @notjustjulia.

]]

--declaring default config variables
config = {

    nightscout_url = "",

    range = {
        low = 70,
        high = 150,
        very_high = 200
    },

    refresh_rate = 5, --too fast may cause issues with nightscout server. Best to keep >= 10s.

    output = {
        low = "none",
        in_range = "none",
        high = "none",
        very_high = "none"
    },

    custom_text_size = 0, --if 0, scale to monitor size. (only affects monitors)

    theme = 1,

    background_color = "black"
}

--internal variables
suggest_change_monitor_size = false
no_connection = false
pauseEventPulling = false

monitor_mode = false
show_console_no_mon = false

--constants
themeAmount = 4


--declare functions

function printSplash()
    term.clear()
    term.setCursorPos(1,1)

    term.setTextColor(colors.purple)
    print("--Nightscout Minecraft Visualizer--")
    term.setTextColor(colors.gray)
    print("v1.0")
    term.setTextColor(colors.pink)
    print("Made by Julia C")
    term.setTextColor(colors.green)
    term.write("@notjustjulia on Tumblr\n\n")

    if monitor_mode then
        term.setTextColor(colors.gray)
        print("\n\nAttached to monitor.")
    else
        print("")
    end

    if suggest_change_monitor_size then
        term.setTextColor(colors.orange)
        print("You may want to change the size of your monitor. Currently, 3x2 and 1x1 are the only sizes officially supported.")
    end

    print("")

    if show_console_no_mon then
        term.setTextColor(colors.gray)
        print("No-Monitor Console mode. Type 'exit' to close.")
    end

    term.setTextColor(colors.lightGray)
    print("Type 'help' for a list of commands.")

    term.setTextColor(colors.white)
end

function configureScreen()
    --look for a monitor. If none present, set screen to computer window.
    if peripheral.find("monitor") then
        screen = peripheral.find("monitor")

        if monitor_mode == false then
            term.setBackgroundColor(colors.black) --set computer background back to black, so console is correct color.
            screen.setTextScale(1)
            printSplash()

            monitor_mode = true
        end
    else
        screen = term

        if monitor_mode then
            screen.clear()
            monitor_mode = false
            suggest_change_monitor_size = false

            term.setCursorBlink(false)
            os.queueEvent("key", keys.enter)
        end
    end

    screen_x, screen_y = screen.getSize()
    if monitor_mode then

        screen.setTextScale(1)

        screen_x, screen_y = screen.getSize()


        suggest_change_monitor_size = false
        if config.custom_text_size == 0 then
            if screen_x == 7 and screen_y == 5 then
                if screen.getTextScale() ~= 1 then
                    screen.setTextScale(1)
                end
            elseif screen_x == 29 and screen_y == 12 then
                --screen.setTextScale(math.floor(text_scale))
                if screen.getTextScale() ~= 4 then
                    screen.setTextScale(4) --4
                end
            else
                suggest_change_monitor_size = true
                if screen.getTextScale() ~= 2 then
                    screen.setTextScale(2)
                end
            end
        else
            screen.setTextScale(config.custom_text_size)
        end


        --[[if old_screen_x ~= screen_x or old_screen_y ~= screen_y then
            printSplash()
        end--]]
    end
end


--data pulling and interpreting from nightscout
function getData()
    nightsct_handle = nil
    nightsct_handle = http.get("https://"..config.nightscout_url.."/api/v1/entries?count=2")

    if nightsct_handle then
        no_connection = false
        --pull http page from nightscout and save as raw_content
        raw_content = nightsct_handle.readAll()
        nightsct_handle.close()

        --parse the pulled data into chunks, separated by spaces
        parseData()
    else
        no_connection = true
    end
end

function parseData()
    --seperates content into chunks
    data = {}
    for substring in raw_content:gmatch("%S+") do
        table.insert(data, substring)
    end

    return data
end


--Set customized redstone outputs based on blood glucose state.
function setOutputs()
    if no_connection == false then
        if bgNum < config.range.low then
            if config.output.low ~= "none" then
                redstone.setOutput(config.output.low, true)
            end
        elseif bgNum >= config.range.low and bgNum < config.range.high then
            if config.output.in_range ~= "none" then
                redstone.setOutput(config.output.in_range, true)
            end
        elseif bgNum < config.range.very_high and bgNum >= config.range.high then
            if config.output.high ~= "none" then
                redstone.setOutput(config.output.high, true)
            end
        elseif bgNum >= config.range.very_high then
            if config.output.very_high ~= "none" then
                redstone.setOutput(config.output.very_high, true)
            end
        end
    end
end

function clearOutputs()
    redstone.setOutput("front", false)
    redstone.setOutput("back", false)
    redstone.setOutput("top", false)
    redstone.setOutput("bottom", false)
    redstone.setOutput("left", false)
    redstone.setOutput("right", false)
end


--config writing and reading
function saveConfig()
    config_file = fs.open("nsvis_config", "w") --open / make the config file
    config_file.write(textutils.serialize(config)) --serialize config table into file
    config_file.close()
end

function loadConfig()
    if fs.exists("nsvis_config") then --if config file exists
        config_file = fs.open("nsvis_config", "r") --open it
        config = textutils.unserialize(config_file.readAll()) --unserialize its contents into the config table
        config_file.close()
    else
        setup()
    end
end


--Initial setup function.
function setup()
    --this function is called through loadConfig(), and is executed the first time the user opens the program (or if the config file is deleted).
    term.clear()
    term.setCursorPos(1,1)

    term.setTextColor(colors.purple)
    textutils.slowPrint("~*Nightscout Minecraft Visualizer*~")
    term.setTextColor(colors.pink)
    textutils.slowPrint("Made by Julia C.")

    term.setTextColor(colors.white)
    sleep(0.5)
    print("\nSince this is your first time running Nightscout Visualizer, you'll need to configure a few settings.")
    print("\nFirst of all, you'll need to have a Nightscout site up and running. More information about Nightscout can be found at nightscout.github.io")

    term.setTextColor(colors.green)
    print("\nPlease input your Nightscout URL")
    term.setTextColor(colors.lightGray)
    print("(ex: funnybloodsite.herokuapp.com):")
    term.setTextColor(colors.cyan)
    config.nightscout_url = io.read():gsub("http://", "")

    while http.get("https://"..config.nightscout_url.."/api/v1/entries?count=2") == nil do
        --if invalid URL, enter while loop that asks for new URL until a successful http request can be made.
        term.setTextColor(colors.red)
        print("Error: Invalid URL. Please ensure this URL is functional and inputted correctly.")

        term.setTextColor(colors.cyan)
        config.nightscout_url = io.read():gsub("http://", "")
    end

    function drawSetupHeader()
        term.clear()
        term.setCursorPos(1,1)

        term.setTextColor(colors.purple)
        print("~*Nightscout Minecraft Visualizer*~")
        term.setTextColor(colors.pink)
        print("Made by Julia C.")
    end

    if os.getComputerLabel() == nil then
        drawSetupHeader()
        term.setTextColor(colors.white)

        print("\nThis computer is not labeled. Please enter a label, to ensure data is not lost if computer is broken and replaced:\n")
        input = io.read()
        os.setComputerLabel(input)
    end


    drawSetupHeader()
    term.setTextColor(colors.white)
    print("\nSelect a background color. This can be changed later by typing the background command.\nblack is reccomended for readability.\n\n")
    term.setTextColor(colors.lightGray)
    print("[black, magenta, yellow, lime, pink, gray, lightGray, cyan, purple, blue, brown]\n")
    term.setTextColor(colors.white)
    config.background_color = io.read()


    drawSetupHeader()
    term.setTextColor(colors.white)
    print("\nA successful connection to your Nightscout site has been made!")
    print("\nSome additional things to note:\nConnecting a monitor on any side of the computer will, after a few seconds, become the display screen.\nIf a monitor is attached, the computer itself becomes a console, through which commands can be given.\nIf no monitor is attached, the console can be opened in the computer by pressing C.")
    print("\nPress ENTER to continue..")
    raninput = io.read()


    drawSetupHeader()
    term.setTextColor(colors.white)
    print("\nWhile most monitor sizes can technically be used, 3x2 or 1x1 is reccomended for centering.\nMonitor size changes may take a few seconds to take effect.\nThe theme can be changed by right clicking on the monitor, or through the theme command.\nRedstone outputs can be configured based on blood glucose states. Learn more by typing the output command.")
    print("\nPress ENTER to continue..")
    raninput = io.read()


    saveConfig()

    if monitor_mode then
        printSplash()
    else
        getData()
        drawData()
    end
end

--console to edit config variables
function inputConsole()
    while true do
        if monitor_mode or show_console_no_mon then
            term.write(">")
            input = io.read()

            if monitor_mode == false and show_console_no_mon == false then
                input = "none"
            else

                printSplash()

                term.setTextColor(colors.white)
            end

            --print("")


            if input == "help" then
                print("Commands: nightscout, range, refresh_rate, output, theme, custom_text_size, info.\nType 'help [command]' to get more information.")

            elseif input:sub(1,4) == "help" then --help commands
                input = input:sub(6)

                if input == "nightscout" then
                    print("The nightscout command allows you to change your Nightscout site URL.")
                elseif input == "range" then
                    print("The range command allows you to define which values are considered low, in range, high, and extreme high.\nThese ranges are color coded, and are used for custom redstone outputs.")
                elseif input == "refresh_rate" then
                    print("The refresh_rate command changes how quickly the program will update data from your nightscout site.\nSetting it too low can cause problems for some nightscout hosts. If you're having problems with data consistency, try setting this value to around 25 seconds.")
                elseif input == "output" then
                    print("The output command allows you to set customizable redstone outputs based on the state of your blood glucose.\nFor example, you can set it so that if your blood sugar is low, a redstone signal will output from the left of the computer. This signal can in turn power an alarm, a flashing light, etc.")
                elseif input == "background" then
                    print("The background command allows you to change the background color of the display. See options by typing 'background'. Command can be entered either through typing 'background', then a color, or by typing 'background [color].'")
                elseif input == "custom_text_size" then
                    print("The custom_text_size command allows you to specify the size of text. By default, the text size will scale to the size of the monitor.\nThis command only applies to monitor functionality.\nSet to 0 to return to default text scaling.")
                elseif input == "theme" then
                    print("The theme command lets you change the text style theme for the display. It can be entered by typing theme, then a number, by typing 'theme [number]', or by right clicking on an attached monitor.")
                elseif input == "info" then
                    print("Additional information about Nightscout Minecraft Visualizer.")
                end

            elseif input == "range" then
                print("Set Blood Glucose Ranges? y/n")
                input = io.read()

                if input == "y" then
                    print("Input a Low value: ")
                    config.range.low = tonumber(io.read())

                    print("Input a High value: ")
                    config.range.high = tonumber(io.read())

                    print("Input an Extreme High value: ")
                    config.range.very_high = tonumber(io.read())

                    print("Ranges configured!")
                    saveConfig()
                else
                    printSplash()
                end

            elseif input == "refresh_rate" then
                input = 0
                while input < 5 do
                    print("Input data refresh rate in seconds (Must be above 5): ")
                    input = tonumber(io.read())
                    if input < 5 then
                        printSplash()
                        print("Number must be above 5!")
                    else
                        config.refresh_rate = input
                    end
                end
                print("Data will refresh every "..config.refresh_rate.. " seconds.")

            elseif input == "output" then
                print("Choose a state [low, in_range, high, very_high], or type cancel.")

                outputState = io.read()
                if config.range[outputState] == nil and outputState ~= "cancel" then
                    print("Invalid state.")
                elseif outputState == "cancel" then
                    printSplash()
                else
                    print("Choose a side [front, back, left, right, top, bottom, none], or type cancel.")

                    outputSide = io.read()

                    if outputSide ~= "front" and outputSide ~= "back" and outputSide ~= "left" and outputSide ~= "right" and outputSide ~= "top" and outputSide ~= "bottom" and outputSide ~= "none" and outputSide ~= "cancel" then
                        print("Invalid side.")
                    elseif outputSide == "cancel" then
                        printSplash()
                    else
                        config.output[outputState] = outputSide
                        print("When blood glucose "..outputState.. " "..outputSide.." will output a redstone signal.")
                    end
                end

            elseif input == "nightscout" then
                print("Change Nightscout URL? y/n")
                input = io.read()

                if input == "y" then
                    print("Input new Nightscout URL.\nEx: mysillysite.herokuapp.com")

                    input = io.read()
                    config.nightscout_url = input:gsub("http://", "")
                    print("Nightscout URL changed to: "..config.nightscout_url)
                else
                    printSplash()
                end

            elseif input:sub(1, 10) == "background" then
                if input == "background" then
                    print("Which background color would you like?\n[black, magenta, yellow, lime, pink, gray, lightGray, cyan, purple, blue, brown]")
                    input = io.read()
                else
                    input = input:sub(12)
                end

                if colors[input] ~= nil then
                    print("Background color changed to "..input..".")
                    config.background_color = input

                    if monitor_mode then
                        drawData()
                    end

                    saveConfig()
                else
                    print("Invalid color choice.")
                end

            elseif input:sub(1, 5) == "theme" then
                if input == "theme" then
                    print("Which theme would you like?\n[1, 2, 3, 4]")
                    input = io.read()
                else
                    input = input:sub(7)
                end

                input = tonumber(input)

                if input >= 1 and input <= themeAmount then
                    print("Theme changed to "..input..".")
                    config.theme = input

                    if monitor_mode then --if not in monitor mode, forcing draw update will glitch out console.
                        drawData()
                    end
                    saveConfig()
                else
                    print("Invalid theme choice.")
                end

            elseif input == "exit" then
                if monitor_mode == false then
                    show_console_no_mon = false
                    drawData()
                else
                    print("Console cannot be exited while monitor is attached.")
                end

            elseif input == "info" then
                print("It is reccomended you use this software connected to a monitor, although it will also function on computers and pocket computers.\nTo connect a monitor, simply place them in either a 1x1 or 3x2 configuration, touching any face of the computer.\nI also reccomend using the help command, to see all functionality provided -- such as themes, redstone outputs, background colors, and custom ranges.")
            end
        else
            sleep(0.01)
        end
    end
end

--listen for system events, such as key presses and monitor events.
function eventListener()
    while true do
        if pauseEventPulling == false then
            event, arg = os.pullEvent()

            if event == "key" then
                if arg == keys.c then
                    if monitor_mode == false and show_console_no_mon == false then
                        screen.setBackgroundColor(colors.black)

                        show_console_no_mon = true
                        printSplash()
                        term.setCursorBlink(true)
                    end
                end

            elseif event == "monitor_touch" then
                config.theme = config.theme + 1
                if config.theme > themeAmount then config.theme = 1 end
                drawData()

            elseif (event == "monitor_resize" or event == "peripheral_detach") then
                --if monitor gets resized or removed (or added),

                show_console_no_mon = false --force out of console
                configureScreen() --update the screen configuration
                sleep(0.1) --pause for a second to avoid issues (necessary, trust me)
                drawData() --push draw update so screens update on change

                if monitor_mode then
                    printSplash() --push print update incase error messages necessary (such as incorrect resolution)
                    term.write(">") --reinsert > when reconnecting to monitor, if previously in console only mode.
                end
            end
        end
    end
end

--Drawing the on screen data.
function drawData()
    screen.setBackgroundColor(colors[config.background_color])

    screen.clear()
    --screen.setCursorPos(1,1)

    local draw_x = 1
    if monitor_mode == false then
        draw_x = (screen_x / 2) - 3
    end

    if no_connection == false then

        bg = data[3]
        bgNum = tonumber(bg)
        delta = bgNum - tonumber(data[8])

        screen.setCursorPos(draw_x,1)

        if bgNum < config.range.low then
            screen.setTextColor(colors.lightBlue)
        elseif bgNum >= config.range.low and bgNum < config.range.high then
            screen.setTextColor(colors.green)
        elseif bgNum < config.range.very_high and bgNum >= config.range.high then
            screen.setTextColor(colors.orange)
        elseif bgNum >= config.range.very_high then
            screen.setTextColor(colors.red)
        end

        --draw blood glucose
        if config.theme == 1 then
            screen.setCursorPos(draw_x,2)
            if bgNum >= 100 then
                screen.write("--"..bg.."--")
            else
                screen.write("--_"..bg.."--")
            end

        elseif config.theme == 2 then
            screen.setCursorPos(draw_x+1,2)
            if bgNum >= 100 then
                screen.write(">"..bg.."<")
            else
                screen.write(">_"..bg.."<")
            end

        elseif config.theme == 3 then
            screen.setCursorPos(draw_x,2)
            if bgNum >= 100 then
                screen.write("<>"..bg.."<>")
            else
                screen.write("<>_"..bg.."<>")
            end

        elseif config.theme == 4 then
            screen.setCursorPos(draw_x+2,2)
            if bgNum >= 100 then
                screen.write(bg)
            else
                screen.write("_"..bg.."")
            end
        end

        --set delta color code
        if delta > 0 then
            if bgNum >= 150 then
                screen.setTextColor(colors.red)
            elseif bgNum <= 70 then
                screen.setTextColor(colors.green)
            else
                screen.setTextColor(colors.white)
            end
        elseif delta < 0 then
            if bgNum >= 150 then
                screen.setTextColor(colors.green)
            elseif bgNum <= 70 then
                screen.setTextColor(colors.red)
            else
                screen.setTextColor(colors.white)
            end
        else
            screen.setTextColor(colors.white)
        end

        --draw delta arrow
        screen.setCursorPos(draw_x+5,3)
        if delta >= 5 then
            screen.write("^")
        elseif delta < 5 and delta > 0 then
            screen.write("/")
        elseif delta < 0 and delta > -5 then
            screen.write("\\")
        elseif delta <= -5 then
            screen.write("v")
        elseif delta == 0 then
            screen.write("->")
        end

        --draw delta
        screen.setCursorPos(draw_x,3)

        if delta < -60 then
            delta = "X-"
        end
        --screen.write("Delta: ")
        if delta > 0 then
            delta = "+"..tostring(delta)
        end
        screen.write(tostring(delta))
        --screen.write("/5m")
        --screen.setTextColor(colors.white)
    else
        --if no connection to nightscout can be made:
        screen.setCursorPos(draw_x,2)
        screen.setTextColor(colors.red)
        screen.write("NO DATA")
        screen.setCursorPos(draw_x+2,3)
        screen.write(":(")
    end

    if monitor_mode == false then
        screen.setCursorPos(draw_x - 8,5)
        screen.setTextColor(colors.lightGray)
        screen.write("Press C to open Console")
    end
end

--startup functions

configureScreen() --check if monitor is attached, find dimensions, etc
printSplash() --draw first splash, after screen is configured, to potentially notify about monitor issues.

screen.clear()


loadConfig() --if a config file already exists, load it into program. If not, this function will start the setup() function.

--use this block to add in new variables from updates into config
if config.theme == nil then config.theme = 1 end
if config.background_color == nil then config.background_color = "black" end
--------


--start program
getData()

function mainLoop()
    while true do
        if show_console_no_mon == false then

            drawData() --main part of function

            setOutputs() --set redstone outputs

            getData() --get new data at end of function, so there's no flicker when updating data on screen.

            sleep(config.refresh_rate)
            while show_console_no_mon do --stall function until no_monitor console is exited (to prevent configureScreen() from triggering, in case that monitor gets attached.)
                sleep(0.01)
            end

            if monitor_mode == false then
                configureScreen() --check to see if monitor status has changed. If so, move to (or away from) monitor screen.
            end

            clearOutputs() --clear all redstone outputs to prepare for next reading.
        else
            sleep(0.01)
        end
    end
end

parallel.waitForAll(mainLoop, inputConsole, eventListener) --run all of these functions in parallel.
