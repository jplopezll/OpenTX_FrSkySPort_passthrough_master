-- Telemetry script for Taranis X9D+
--   Data from FrSky S.Port passthrough.
--   It will record data received in the passthrough queue in /SCRIPTS/TELEMETRY/sportlog.txt
--   Data is stored in csv format for later analysis.
--
--
-- Copyright (C) 2017. Juan Pedro López
--   https://github.com/jplopezll
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.

logFile = nil

---------------------------------------------------------------
-- Init function global variable
---------------------------------------------------------------
-- Open the log file for passthrough packets storage
local function init_func()
  
end

---------------------------------------------------------------
-- Background loop function
---------------------------------------------------------------
-- Closing the file for passthrough packets storage
local function bg_func()
  if logFile ~= nil then io.close(logFile) end
end



---------------------------------------------------------------
-- Visible loop function
---------------------------------------------------------------
local function run(e)
  -- Prepare to extract SPort data
  -- if not open, open the file for packets storage
  lcd.clear()

  logFile = io.open("/SCRIPTS/TELEMETRY/sportlog.txt","a")
  -- get packets from queue
  local sensorID,frameID,dataID,value = sportTelemetryPop()
  lcd.drawText(0,0,"Sniffer:",SMLSIZE)
  lcd.drawText(10,10,tostring(dataID)..";"..tostring(value),SMLSIZE)

  -- Write packets to file
  if  logFile~=nil and value~=nil then
  	io.write(logFile, tostring(sensorID)..";"..tostring(frameID)..";"..tostring(dataID)..";"..tostring(value).."\r\n")
  end
end

return{run=run, background=bg_func, init=init_func}
