--[[
MIT License
Copyright 2022 Julia C

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

--[[
    This program is the auto-updater script for Nightscout Minecraft Visualizer.
    It runs every time the computer it is installed on is booted, and quickly downloads the most recent iteration
    of the pastebin file.
]]

function clear()
    term.clear()
    term.setCursorPos(1,1)
end
clear()

github_link = "http://raw.githubusercontent.com/aujuslia/nightscout-minecraft-visualizer/master/nsvis.lua"
pastebin_code = "4s3zAVAY" --used as mirror backup download

--make sure program is startup file.
currentProgramName = shell.getRunningProgram()
if currentProgramName ~= "startup.lua" then --if not, change program name to startup. This assures an update check and program launch on every reboot.

    if fs.exists("startup.lua") then
        term.setTextColor(colors.orange)
        print("Warning -- This computer already has a startup program. However, Nightscout Visualizer is made to update and run on startup. Okay to rename current startup file as 'startup_old.lua'? (y/n)")

        term.setTextColor(colors.white)
        term.write(">")
        input_startup_rename = io.read()
        if input_startup_rename == "y" or input_startup_rename == "yes" then
            print("Renaming startup.lua to startup_old.lua...")
            shell.run("rename startup.lua startup_old.lua")

            print("Setting updater / launcher as startup.")
            shell.run("rename "..currentProgramName.." startup.lua")
            sleep(1)
        else
            print("Keeping original startup program.")
            print("Nightscout Visualizer will not update or run on computer start / reboot.\nTo run manually, type 'nightscoutvis'.\nTo update manually, type 'nsvis_update'.\nPress ENTER to continue...")
            if fs.exists("nsvis_update.lua") == false then
                shell.run("rename "..currentProgramName.." nsvis_update.lua")
            end
            inputWait = io.read()
        end
    else
        shell.run("rename "..currentProgramName.." startup.lua")
    end
end


term.setTextColor(colors.purple)
print("Downloading update for Nightscout Visualizer...\n")
term.setTextColor(colors.white)

shell.run("wget "..github_link.." nightscoutvis_update.lua") --download nsvis code.

if fs.exists("nightscoutvis_update.lua") == false then
    --if github download unsuccessful, attempt to download from pastebin mirror.
    shell.run("pastebin get "..pastebin_code.." nightscoutvis_update.lua")
end

--download is saved as _update, as trying to download a file with the same name as a current file will fail.
--confirms that update has downloaded before removing the previous file, incase pastebin connection fails.
if fs.exists("nightscoutvis_update.lua") then --if the update successfully downloaded,
    if fs.exists("nightscoutvis.lua") then --and a previous version is on the system,
        fs.delete("nightscoutvis.lua") --delete the previous version file
    end

    shell.run("rename nightscoutvis_update.lua nightscoutvis.lua") --then rename update to actual file
end


if fs.exists("nightscoutvis.lua") then
    shell.run("nightscoutvis.lua") --if download successful, run nsvis.
else
    --if download unsuccessful, display error.
    term.setTextColor(colors.orange)
    print("Nightscout Visualizer failed to download.\nCheck that your internet connection is running properly.\n")
    term.setTextColor(colors.green)
    print("If problem persists, feel free to contact @notjustjulia on Tumblr for assistance :)")
end
