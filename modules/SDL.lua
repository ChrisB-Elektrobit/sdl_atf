require('os')
local sdl_logger = require('sdl_logger')
local config = require('config')
local SDL = { }

require('atf.util')

SDL.exitOnCrash = true
SDL.STOPPED = 0
SDL.RUNNING = 1
SDL.CRASH = -1

function sleep(n)
  os.execute("sleep " .. tonumber(n))
end

function CopyFile(file, newfile)
  return os.execute (string.format('cp "%s" "%s"', file, newfile))
end

function CopyInterface()
  if config.pathToSDLInterfaces~="" and config.pathToSDLInterfaces~=nil then
    local mobile_api = config.pathToSDLInterfaces .. '/MOBILE_API.xml'
    local hmi_api = config.pathToSDLInterfaces .. '/HMI_API.xml'
    CopyFile(mobile_api, 'data/MOBILE_API.xml')
    CopyFile(hmi_api, 'data/HMI_API.xml')
  end
end

function SDL:StartSDL(pathToSDL, smartDeviceLinkCore, ExitOnCrash)
  if ExitOnCrash ~= nil then
    self.exitOnCrash = ExitOnCrash
  end
  local status = self:CheckStatusSDL()

  if (status == self.RUNNING) then
    local msg = "SDL had already started out of ATF"
    xmlReporter.AddMessage("StartSDL", {["message"] = msg})
    print(console.setattr(msg, "cyan", 1))
    return false, msg
  end

  CopyInterface()
  local result = os.execute ('./tools/StartSDL.sh ' .. pathToSDL .. ' ' .. smartDeviceLinkCore)

  local msg
  if result then
    msg = "SDL started"
    if config.storeFullSDLLogs == true then
      sdl_logger.init_log(get_script_file_name())
    end
  else
    msg = "SDL had already started not from ATF or unexpectedly crashed"
    print(console.setattr(msg, "cyan", 1))
  end
  xmlReporter.AddMessage("StartSDL", {["message"] = msg})
  return result, msg

end

function SDL:StopSDL()
  self.autoStarted = false
  local status = self:CheckStatusSDL()
  if status == self.RUNNING then
    local result = os.execute ('./tools/StopSDL.sh')
    if result then
      if config.storeFullSDLLogs == true then
        sdl_logger.close()
      end
      return true
    end
  else
    local msg = "SDL had already stopped"
    xmlReporter.AddMessage("StopSDL", {["message"] = msg})
    print(console.setattr(msg, "cyan", 1))
    return nil, msg
  end
end

function SDL:CheckStatusSDL()
  local testFile = os.execute ('test -e sdl.pid')
  if testFile then
    local testCatFile = os.execute ('test -e /proc/$(cat sdl.pid)')
    if not testCatFile then
      return self.CRASH
    end
    return self.RUNNING
  end
  return self.STOPPED
end

function SDL:DeleteFile()
  if os.execute ('test -e sdl.pid') then
    os.execute('rm -f sdl.pid')
  end
end

return SDL
