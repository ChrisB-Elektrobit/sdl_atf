local events = require('events')
local constants = require('protocol_handler/ford_protocol_constants')

local module = {}
local mt = { __index = { } }
local d = qt.dynamic()
local time_offset = 1000

function mt.__index:ExpectHeartbeatAck()
  self.session.connection:OnInputData(function(_, msg)
    if self.session.sessionId.get() ~= msg.sessionId then
      return
    end
    if self.heartbeatEnabled then
        if msg.frameType == constants.FRAME_TYPE.CONTROL_FRAME and
           msg.frameInfo == constants.FRAME_INFO.HEARTBEAT_ACK and
           self.IgnoreHeartBeatAck.get() then
            return
        end
        self.heartbeatFromSDLTimer:reset()
    end
  end)
end

function mt.__index:SendHeartbeatAck()
  self.control_services:SendControlMessage( {frameInfo = constants.FRAME_INFO.HEARTBEAT_ACK } )
end

function mt.__index:AddHeartbeatExpectation()
  local event = events.Event()
  event.matches = function(s, data)
    return data.frameType == constants.FRAME_TYPE.CONTROL_FRAME and
    data.serviceType == constants.SERVICE_TYPE.CONTROL and
    data.frameInfo == constants.FRAME_INFO.HEARTBEAT   and
    self.session.sessionId.get() == data.sessionId
  end
  self.expectations:ExpectEvent(event, "Heartbeat")
  :Pin()
  :Times(AnyNumber())
  :Do(function(data)
      if self.heartbeatEnabled and self.AnswerHeartbeatFromSDL.get() then
        self:SendHeartbeatAck()
      end
    end)
end


function mt.__index:StartHeartbeat()
  self.heartbeatEnabled = true

  function d.SendHeartbeat()
    if self.heartbeatEnabled and self.SendHeartbeatToSDL.get() then
      self.control_services:SendControlMessage( { frameInfo = constants.FRAME_INFO.HEARTBEAT } )
      if not self.IgnoreHeartBeatAck.get() then
        self.heartbeatToSDLTimer:reset()
      end
    end
  end

  function d.CloseSession()
    if self.heartbeatEnabled then
      print("\27[31m SDL didn't send anything for " .. self.heartbeatFromSDLTimer:interval()
        .. " msecs. Closing session # " .. self.session.sessionId.get().."\27[0m")
      self.control_services:StopService(7)
      :Do(self:StopHeartbeat())
    end
  end

  xmlReporter.AddMessage("StartHearbeat", "True", (config.heartbeatTimeout + time_offset))
  if self.heartbeatToSDLTimer then
    self.heartbeatToSDLTimer:start(config.heartbeatTimeout)
    qt.connect(self.heartbeatToSDLTimer, "timeout()", d, "SendHeartbeat()")
  end

  if self.heartbeatFromSDLTimer then
    self.heartbeatFromSDLTimer:start(config.heartbeatTimeout + time_offset)
    qt.connect(self.heartbeatFromSDLTimer, "timeout()", d, "CloseSession()")
  end

  self:ExpectHeartbeatAck()
end


function mt.__index:StopHeartbeat()
  if self.heartbeatEnabled then
    self.heartbeatEnabled = false
    if self.heartbeatToSDLTimer then
      self.heartbeatToSDLTimer:stop()
    end
    if self.heartbeatFromSDLTimer then
      self.heartbeatFromSDLTimer:stop()
    end
  xmlReporter.AddMessage("StopHearbeat", "True")
  end
end

function mt.__index:SetHeartbeatTimeout(timeout)
  if self.heartbeatToSDLTimer and self.sessionheartbeatFromSDLTimer then
    self.heartbeatToSDLTimer:setInterval(timeout)
    self.heartbeatFromSDLTimer:setInterval(timeout + time_offset)
  end
end


function module.HeartBeatMonitor(session)
  local res = { }
  res.session = session
  res.sessionId = session.sessionId
  res.control_services = session.control_services
  res.expectations = session.mobile_expectations

  res.heartbeatToSDLTimer = timers.Timer()
  res.heartbeatFromSDLTimer = timers.Timer()

  res.SendHeartbeatToSDL = {}
  function res.SendHeartbeatToSDL.get()
    return session.sendHeartbeatToSDL.get()
  end

  res.AnswerHeartbeatFromSDL = {}
  function res.AnswerHeartbeatFromSDL.get()
    return session.answerHeartbeatFromSDL.get()
  end

  res.IgnoreHeartBeatAck = {}
  function res.IgnoreHeartBeatAck.get()
    return session.ignoreHeartBeatAck.get()
  end

  res.heartbeatEnabled = true
  setmetatable(res, mt)
  return res
end


 return module
