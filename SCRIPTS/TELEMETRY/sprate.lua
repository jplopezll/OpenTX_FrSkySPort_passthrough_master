-- Telemetry script for Taranis X9D+
--   Just to analyse data rates received from flight controller to check if they match with the setup
--   Data from FrSky S.Port passthrough
--   Optimised for screen size (Taranis X9D+): 212x64 pixels.
--
-- For FrSky S.Port and Ardupilot passthrough protocol check:
--   https://cdn.rawgit.com/ArduPilot/ardupilot_wiki/33cd0c2c/images/FrSky_Passthrough_protocol.xlsx
--
-- Copyright (C) 2018. Juan Pedro López
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
--
-- Auxiliary files on github under dir BMP and SOUNDS/en
-- https://github.com/Clooney82/MavLink_FrSkySPort/tree/s-c-l-v-rc-opentx2.1/Lua_Telemetry/DisplayApmPosition

local screenCleared=0   -- Track if lcd needs full wiping
local lastUpdtRates=0     -- Last time rates were updated
local timeToRatesUpdt=1000  -- Minimum update time in tics (multiples of 10ms)

local dataSection={}     -- Track what message received data
  dataSection[0]=0
  dataSection[1]=0
  dataSection[2]=0
  dataSection[3]=0
  dataSection[4]=0
  dataSection[5]=0
  dataSection[6]=0
  dataSection[7]=0
  dataSection[8]=0

local rateSection={}    -- Track rates, reset as specified in timeToRatesUpdt above
  rateSection[0]=0
  rateSection[1]=0
  rateSection[2]=0
  rateSection[3]=0
  rateSection[4]=0
  rateSection[5]=0
  rateSection[6]=0
  rateSection[7]=0
  rateSection[8]=0


----------------------------------------------------------------------------------
-- Functions to draw certain areas of the screen when passthrough data is received
----------------------------------------------------------------------------------
local function drawLayout()
  lcd.drawText(0,0,"Data received from S.Port:",SMLSIZE)
  lcd.drawText(0,8,"0x5000:",SMLSIZE)
  lcd.drawText(0,16,"0x5001:",SMLSIZE)
  lcd.drawText(0,24,"0x5002:",SMLSIZE)
  lcd.drawText(0,32,"0x5003:",SMLSIZE)
  lcd.drawText(0,40,"0x5004:",SMLSIZE)
  lcd.drawText(0,48,"0x5005:",SMLSIZE)
  lcd.drawText(0,56,"0x5006:",SMLSIZE)
  lcd.drawText(100,8,"0x5007:",SMLSIZE)
  lcd.drawText(100,16,"Others:",SMLSIZE)
end



---------------------------------------------------------------
-- Visible loop function
---------------------------------------------------------------
local function run(e)
  -- Record the time to print total exec time during debugging
  local runTime = getTime()
 
  -- Prepare to extract SPort data
  local sensorID,frameID,dataID,value = sportTelemetryPop()

  -- Loop until the FIFO buffer is empty
  while dataID~=nil do
    dataSection[8]=dataSection[8]+1

    -- unpack 0x5000  -- 32 bits. Sending 4 characters with 7 bits at a time. Msg sent 3 times.
    -- 0x5000         -- (I) 32 bits. Sending 4 characters with 7 bits at a time. Msg sent 3 times.
    --MsgSeverity=0     -- (I) 3 bits. Severity is sent as the MSB of each of the last three bytes of the last chunk (bits 24, 16, and 8) since a character is on 7 bits.
    --MsgText=" "       -- (I) 28 bits. The 7 LSB bits of each byte.
    --MsgLastReceived="No messages"
    --MsgLastChunk=0
    --MsgPrevChunk=""
    --MsgByte1=0        -- (I) For the LSB of the message, bits 0 to 7
    --MsgByte2=0        -- (I)    bits 8 to 15
    --MsgByte3=0        -- (I)    bits 16 to 23
    --MsgByte4=0        -- (I) For the MSB of the message, bits 24 to 31
    if dataID == 0x5000 then
      MsgByte1=bit32.extract(value,0,7)      -- For the LSB of the message, bits 0 to 7
      MsgByte2=bit32.extract(value,8,7)      --    bits 8 to 15
      MsgByte3=bit32.extract(value,16,7)     --    bits 16 to 23
      MsgByte4=bit32.extract(value,24,7)     -- For the MSB of the message, bits 24 to 31
      local MsgNewChunk=""
      if MsgByte4~=0 then
        MsgNewChunk=string.char(MsgByte4)
      else
        MsgLastChunk=1
      end
      if MsgByte3~=0 then
        MsgNewChunk=MsgNewChunk..string.char(MsgByte3)
      else
        MsgLastChunk=1
      end
      if MsgByte2~=0 then
        MsgNewChunk=MsgNewChunk..string.char(MsgByte2)
      else
        MsgLastChunk=1
      end
      if MsgByte1~=0 then
        MsgNewChunk=MsgNewChunk..string.char(MsgByte1)
      else
        MsgLastChunk=1
      end

      if MsgPrevChunk~=MsgNewChunk then
        MsgText=MsgText..MsgNewChunk
        MsgPrevChunk=MsgNewChunk
      end
      if MsgLastChunk==1 then
        MsgSeverity=(bit32.extract(value,23,1)*4)+(bit32.extract(value,15,1)*2)+bit32.extract(value,7,1)
        MsgLastReceived=MsgText
        MsgLastChunk=0
        MsgText=""
        MsgPrevChunk=""
      end

      -- Register received data
      dataSection[0]=dataSection[0]+1
    end

    -- unpack 0x5001 packet
    if dataID == 0x5001 then
      StatusFtMode=bit32.extract(value,0,5)    -- 5 bits
      --StatusSimpleSS=bit32.extract(value,5,2)  -- 2 bits
      StatusLandComp=bit32.extract(value,7,1)    -- 1 bit
      StatusArmed=bit32.extract(value,8,1)     -- 1 bit
      StatusBatFS=bit32.extract(value,9,1)     -- 1 bit
      StatusEKFFS=bit32.extract(value,10,1)     -- 1 bit

      -- Register received data
      dataSection[1]=dataSection[1]+1
    end

    -- unpack 0x5002 packet
    if dataID == 0x5002 then
      GPSNumSats = bit32.extract(value,0,4)
      GPSFix = bit32.extract(value,4,2)
      --GPSHDOP = bit32.extract(value,7,7)*(10^(bit32.extract(value,6,1)-1))
      --GPSVDOP = bit32.extract(value,15,7)*(10^(bit32.extract(value,14,1)-1))
      GPSAlt = bit32.extract(value,24,7)*(10^bit32.extract(value,22,2))  -- In dm
      --if (bit32.extract(value,31,1) == 1) then GPSAlt = -GPSAlt end

      -- Register received data
      dataSection[2]=dataSection[2]+1
    end

    -- unpack 0x5003 packet
    if dataID == 0x5003 then
      UAVBatVolt=bit32.extract(value,0,9) -- 9 bits. dV
      UAVCurr=bit32.extract(value,10,7)*(10^bit32.extract(value,9,1)) -- 1+7 bits. 10^x + dA
      UAVCurrTot=bit32.extract(value,17,15) -- 15 bits. mAh. Limit to 32767 = 15 bits

      -- Register received data
      dataSection[3]=dataSection[3]+1
    end

     -- unpack 0x5004 packet
    if dataID == 0x5004 then
      HomeDist=bit32.extract(value,2,10)*(10^bit32.extract(value,0,2)) -- 2+10 bits. 10^x + m.
      HomeAngle=bit32.extract(value,12,7)*3 -- 7 bits. By 3 to get up to 360 degrees.
      HomeAlt=bit32.extract(value,21,10)*(10^bit32.extract(value,19,2)) -- 2+10+1 bit. 10^x + dm * sign
      if (bit32.extract(value,31,1) == 1) then HomeAlt = -HomeAlt end

      -- Register received data
      dataSection[4]=dataSection[4]+1
    end
   
    -- unpack 0x5005 packet
    if dataID == 0x5005 then
     SpdVert= bit32.extract(value,1,7)*(10^bit32.extract(value,0,1)) -- 1+7+1 bits. 10^x + dm * sign
     if (bit32.extract(value,8,1) == 1) then SpdVert = -SpdVert end
     SpdHor=bit32.extract(value,10,7)*(10^bit32.extract(value,9,1)) -- 1+7 bits. 10^x + dm (per second?)
     Yaw = bit32.extract(value,17,11) * 0.2

      -- Register received data
      dataSection[5]=dataSection[5]+1
    end
    
    -- unpack 0x5006 packet
    if dataID == 0x5006 then
      Roll = (bit32.extract(value,0,11) - 900) * 0.2
      Pitch = (bit32.extract(value,11,10 ) - 450) * 0.2

      -- Register received data
      dataSection[6]=dataSection[6]+1
    end

    -- unpack 0x5007 packet
    if dataID == 0x5007 then
      -- 0x5007         -- 8 bits. Reserve fist 8 bits for param ID
      local ParamID=bit32.extract(value,24,8)
      --if ParamID==0x10 then MAVType=bit32.extract(value,0,8) end -- 8 bits.
      if ParamID==0x20 then UAVBattCapacity=bit32.extract(value,0,24) end -- 24 bits. mAh
      if ParamID==0x30 then UAVBattCapResFS=bit32.extract(value,0,24) end -- 24 bits. mAh
      if ParamID==0x40 then UAVBattVoltFS=bit32.extract(value,0,24) end -- 24 bits. dV

      -- Register received data
      dataSection[7]=dataSection[7]+1
    end

    -- Check if there are messages in the queue to avoid exit from the while-do loop
    sensorID,frameID,dataID,value = sportTelemetryPop()
  end

  -- If first called, wipe out the lcd
  if screenCleared==0 then
    lcd.clear()
    drawLayout()
    screenCleared=1
  end

  -- Update rates when it is time
  if runTime > (lastUpdtRates+timeToRatesUpdt) then
    for i=0,8 do
      -- Let's calculate the position of the number
      local x1=math.floor(i/7)*100 + 33
      local y1=math.floor(i%7)*8 + 8

      -- Change rates per section
      rateSection[i]=dataSection[i]

      -- Reset section counters
      dataSection[i]=0

      -- Print values
      lcd.drawNumber(x1,y1,rateSection[i],SMLSIZE)
    end

    -- Prepare for next updates
    lastUpdtRates=runTime
  end
  
  -- Print total exec time on the first line
  lcd.drawNumber(120,0,runTime,SMLSIZE)

end

return{run=run}
