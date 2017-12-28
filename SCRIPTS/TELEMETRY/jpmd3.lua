-- Telemetry script for Taranis X9D+
--   Data from FrSky S.Port passthrough
--   Optimised for screen size (Taranis X9D+): 212x64 pixels.
--
-- This script reuses some coding found in:
--   MyFlyDream <-> TBS Crossfire Telemetry script
--   by Hélio Teixeira <helio.b.teixeira@gmail.com>
-- 
-- For FrSky S.Port and Ardupilot passthrough protocol check:
--   https://cdn.rawgit.com/ArduPilot/ardupilot_wiki/33cd0c2c/images/FrSky_Passthrough_protocol.xlsx
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
--
-- Auxiliary files on github under dir BMP and SOUNDS/en
-- https://github.com/Clooney82/MavLink_FrSkySPort/tree/s-c-l-v-rc-opentx2.1/Lua_Telemetry/DisplayApmPosition

local drawTime=0        -- Keep track of number of ticks for redraw or debugging
local queueTime=0       -- Keep track of queue process time used
local totalTime=0       -- Keep track of total run time used
local screenCleared=0   -- Track if lcd needs full wiping
local lastUpdtTelem=0     -- Last moment normal telemetry < 0x5000 was updated
local timeToTelemUpdt=200  -- Minimum redraw time (multiples of 10ms)
local drawPrio0=1       -- Inmediate redraw
local drawPrio1=2       -- Medium priority
local drawPrio2=4       -- Low priority

local drawSection={}     -- Track what sections to redraw
  drawSection[0]=0
  drawSection[1]=0
  drawSection[2]=0
  drawSection[3]=0
  drawSection[4]=0
  drawSection[5]=0
  drawSection[6]=0
  drawSection[7]=0
  drawSection[8]=0

local padding = 1       -- padding between lines and number bar
local num_x_offset = 10     -- additional x offset for numbers, since these are right-aligned
local max_speed = 998     -- maximum speed (Km/h) in the bar
local num_rows = 5        -- maximum number of visible rows
local mid_pos = 36        -- position of target value
local height = 8        -- line height including spacing
local txt_height = 6      -- height of the text
local curr_speed_offset = -3  -- offset of the current speed to align the text vertically
local box_height = 14     -- height of current speed box
local box_width = 25      -- width of current speed box

local alt_padding = 6     -- extra width for the altitude bar
local max_alt = 999       -- maximum altitude (m) in the bar

local boxW = 53
local boxH = 40
local boxOffX = 46
local boxOffY = 29
local P1X = boxOffX - boxW/2
local P1Y = boxOffY + 0
local P2X = boxOffX + boxW/2
local P2Y = boxOffY + 0
local alphaTransit = math.atan(boxH/boxW)


local SeverityMeaning = {}
  SeverityMeaning[0]="[Emrg]"
  SeverityMeaning[1]="[Alrt]"
  SeverityMeaning[2]="[Crit]"
  SeverityMeaning[3]="[Err]"
  SeverityMeaning[4]="[Wrng]"
  SeverityMeaning[5]="[Noti]"
  SeverityMeaning[6]="[Info]"
  SeverityMeaning[7]="[Debg]"
  SeverityMeaning[8]="[]"

local FlightModeName = {}
  -- Pixhawk Flight Modes verified
  FlightModeName[0]="ND"
  FlightModeName[1]="Stabilize"
  FlightModeName[2]="ND"
  FlightModeName[3]="Alt Hold"
  FlightModeName[4]="ND"
  FlightModeName[5]="ND"
  FlightModeName[6]="Loiter"
  FlightModeName[7]="RTL"
  FlightModeName[8]="Circle"
  FlightModeName[9]="ND"
  FlightModeName[10]="ND"
  FlightModeName[11]="ND"
  FlightModeName[12]="Drift"
 
  FlightModeName[31]="No Telemetry"


-- Rounding function
local function round(num) 
  if num >= 0 then return math.floor(num + 0.5)
  else return math.ceil(num - 0.5) end
end


-- Function to clear screen areas. To be improved
local function clearRectangle(x,y,w,h)
  lcd.drawFilledRectangle(x,y,w,h,SOLID + GREY(0))
  lcd.drawFilledRectangle(x,y,w,h,GREY(0))
  lcd.drawPoint(x,y)
  lcd.drawPoint(x+w-1,y)
  lcd.drawPoint(x,y+h-1)
  lcd.drawPoint(x+w-1,y+h-1)
end


-- Function to move values in Companion simulator
local function debugFeed()
  return getDateTime().sec
end


-- Draws the left speed indicator in the FPD
local function drawSpeed( speed )   -- It is passed in dm (per second?)
  -- Convert from dm/s to Km/h
  speed = round(speed * 0.36)

  -- left and right lines
  local right_edge = num_x_offset +1 * padding
  lcd.drawRectangle(0,7, right_edge + 6, 50, SOLID)

  -- limit speed to min/max
  local limited_speed = speed 
  if limited_speed > max_speed+1 then
    limited_speed = max_speed+1
  end
  if limited_speed < -1 then
    limited_speed = -1  
  end
  
  local rounded_speed = math.floor( limited_speed + 0.5 )
  local topnum = rounded_speed + math.floor(num_rows/2 + 0.5)
  local topnum_pos = mid_pos - (topnum-limited_speed) * height - txt_height/2

  for s=0,num_rows do
    local current_num = topnum-s
    if current_num <= max_speed and current_num >= 0 and current_num ~= speed then
      lcd.drawNumber( num_x_offset + padding + 5, s*height + topnum_pos, topnum-s, RIGHT + SMLSIZE )
    end
    
  end
  
  -- Draw legend text: Km/h
  lcd.drawPixmap(1,mid_pos-8,"/SCRIPTS/BMP/kmh.bmp")

  -- Draw box and display current speed (unrounded)
  lcd.drawFilledRectangle(0, mid_pos-9, 20, 14, GREY(15))
  lcd.drawRectangle(0, mid_pos-9, 19, 14, SOLID)
  lcd.drawNumber( box_width * padding-7, mid_pos + curr_speed_offset-5, rounded_speed, SMLSIZE+RIGHT )
end


-- Draws an "arrow" used to indicate heading of the UAV on the top right corner
local function drawArrow(xPos,yPos,angle,size)
  local radius=size/2-2
  local spX = xPos + (radius*math.cos(angle))
  local spY = yPos - (radius*math.sin(angle))
  local epX = xPos - (radius*math.cos(angle))
  local epY = yPos + (radius*math.sin(angle))
  lcd.drawRectangle(xPos-size/2,yPos-size/2,size,size)
  lcd.drawLine(spX,spY,epX,epY,SOLID,FORCE)
  lcd.drawFilledRectangle(spX-1,spY-1,3,3,SOLID)
end


-- Draws the right altitude indicator in the FPD
local function drawAlt( altitude )
  -- left and right lines
  local left_edge = 79
  local altAttr = SMLSIZE
  if altitude > 1000 then
    altitude = altitude - 1000
    altAttr = SMLSIZE + BLINK
  end
  lcd.drawRectangle(left_edge-4,7, 19, 50, SOLID)

  -- limit to min/max
  local limited_alt = altitude
  if limited_alt > max_alt+1 then
    limited_alt = max_alt+1
  end
  if limited_alt < -1 then
    limited_alt = -1  
  end
  
  local rounded_alt = math.floor( limited_alt + 0.5 )
  local topnum = rounded_alt + math.floor(num_rows/2 + 0.5)
  local topnum_pos = mid_pos - (topnum-limited_alt) * height - txt_height/2

  for s=0,num_rows do
    local current_num = topnum-s
    if current_num <= max_alt and current_num >= 0 and current_num ~= altitude then
      lcd.drawText( left_edge-2 , s*height + topnum_pos, topnum-s,altAttr)
    end
  end
  
  -- Draw legend text: m
  lcd.drawPixmap(left_edge-5,mid_pos-8,"/SCRIPTS/BMP/m.bmp")

  -- Draw box and display current speed (unrounded)
  lcd.drawNumber(left_edge-4 , mid_pos + curr_speed_offset-5, round(altitude), SMLSIZE )
  lcd.drawRectangle(left_edge-6, mid_pos-9, 21, 14, SOLID)
end


local function drawArtificialHorizon(roll, pitch)
  local pitchOffset = pitch*boxH/math.pi
  local oriRad = roll
  -- Simplify Angle
  roll = (roll % (2*math.pi)) 
  
  if (roll>3*math.pi/2) then
    roll = roll - 2*math.pi
  elseif (roll>math.pi/2) then
    roll=roll-math.pi
  elseif (roll<-3*math.pi/2) then
    roll=roll+2*math.pi
  elseif (roll<-math.pi/2) then
    roll=roll+math.pi
  end
    
  pitch = (pitch % (2*math.pi))
  pitch = -pitch          --- Invert angle for horizon
  
  if (pitch>3*math.pi/2) then
    pitch = pitch - 2*math.pi
  elseif (pitch>math.pi/2) then
    pitch=pitch-math.pi
  elseif (pitch<-3*math.pi/2) then
    pitch=pitch+2*math.pi
  elseif (pitch<-math.pi/2) then
    pitch=pitch+math.pi
  end
    
  local pitchOffset = pitch*boxH/math.pi
    
  if (math.abs(roll)==math.pi/2) then
    P1X = 0
    P1Y = -boxH/2
    P2X = 0
    P2Y = boxH/2
  else
    local absRadians=math.abs(roll)
    if(roll>0) then
      -- P1 Calculations
      P1X = -boxW/2
      P1Y = math.tan(absRadians)*P1X + pitchOffset
    
      if (P1Y<-boxH/2) then
        -- Recalculate P1:
        P1Y = -boxH/2
        P1X = (P1Y - pitchOffset)/math.tan(absRadians)
      end
      
      -- P2 Calculations
      P2X = boxW/2
      P2Y = math.tan(absRadians)*P2X + pitchOffset
      
      if (P2Y>boxH/2) then
        -- Recalculate P1:
        P2Y = boxH/2
        P2X = (P2Y - pitchOffset)/math.tan(absRadians)
      end
      
      lcd.drawLine( P1X+boxOffX,  -P1Y+boxOffY,  P2X+boxOffX,  -P2Y+boxOffY, SOLID, 0 )
    else -- roll<0
      -- P1 Calculations
      P1X = -boxW/2
      P1Y = math.tan(-absRadians)*P1X + pitchOffset
    
      if (P1Y>boxH/2) then
        -- Recalculate P1:
        P1Y = boxH/2
        P1X = (P1Y - pitchOffset)/math.tan(-absRadians)
      end
      
      -- P2 Calculations
      P2X = boxW/2
      P2Y = math.tan(-absRadians)*P2X + pitchOffset
      
      if (P2Y<-boxH/2) then
        -- Recalculate P1:
        P2Y = -boxH/2
        P2X = (P2Y - pitchOffset)/math.tan(-absRadians)
      end
      
      lcd.drawLine( P1X+boxOffX,  -P1Y+boxOffY,  P2X+boxOffX,  -P2Y+boxOffY, SOLID, 0 )
      
    end
  end

  -- Draw pitch and roll numbers in degrees
  lcd.drawNumber( boxOffX-6, boxOffY-22, Pitch, SMLSIZE)
  lcd.drawPixmap(lcd.getLastPos(), boxOffY-22,"/SCRIPTS/BMP/deg.bmp")
  lcd.drawNumber( boxOffX-28, boxOffY-10, Roll, SMLSIZE)
  lcd.drawPixmap(lcd.getLastPos(),boxOffY-10,"/SCRIPTS/BMP/deg.bmp")

  local crossW = 15
  local crossH = 5
  local crossV = 4

  -- Draw center align cross
  lcd.drawPoint(boxOffX, boxOffY)
  lcd.drawLine(boxOffX-crossW/2, boxOffY, math.floor(boxOffX-crossV)-1, boxOffY, SOLID, FORCE )
  lcd.drawLine(math.floor(boxOffX-crossV), boxOffY, boxOffX, boxOffY+crossV, SOLID, FORCE )
  lcd.drawLine(boxOffX, boxOffY+crossV, math.floor(boxOffX+crossV), boxOffY, SOLID, FORCE )
  lcd.drawLine(boxOffX+crossW/2, boxOffY, math.floor(boxOffX+crossV)+1, boxOffY, SOLID, FORCE )
  
  -- Draw horizonal dotted lines
  lcd.drawLine(boxOffX-boxW/2, boxOffY, boxOffX-crossW/2, boxOffY, DOTTED, FORCE)
  lcd.drawLine(boxOffX+boxW/2, boxOffY, boxOffX+crossW/2, boxOffY, DOTTED, FORCE)
end


----------------------------------------------------------------------------------
-- Functions to draw certain areas of the screen when passthrough data is received
----------------------------------------------------------------------------------
local function drawLayout()
  -- Background title area
  lcd.drawFilledRectangle(-1, -1, 214, 8, GREY(12) + SOLID)

  -- Draw vertical separators
  lcd.drawFilledRectangle(94,7,2,50,GREY(12))
  lcd.drawFilledRectangle(145,7,2,50,GREY(12))

  -- Backaground footer area
  lcd.drawFilledRectangle(0,57,212,7,GREY(12))
end


local function draw5000()
  -- Page footer area (passthrough messages)
  lcd.drawFilledRectangle(0,57,212,7,INVERS)
  lcd.drawFilledRectangle(0,57,212,7)
  lcd.drawText(0,57,SeverityMeaning[MsgSeverity]..MsgLastReceived,SMLSIZE)
  lcd.drawFilledRectangle(0,57,212,7,GREY(12))

  drawSection[0]=0
end


local function draw5001()
  -- Title area. Left side: flight mode
  --  Verified: 0 Stabilise; 2 Alt Hold; 11 Drift; 7 Circle; 5 Loiter; 6 RTL
  local fmNumber = StatusFtMode
  local fmName = "Not received"
  local fmAttr = 0
  fmName = FlightModeName[fmNumber]
  if fmNumber == 7 then
    fmAttr = INVERS + BLINK
  end
  lcd.drawFilledRectangle(0,-1,88,8,INVERS)
  lcd.drawFilledRectangle(0,-1,88,8)
  lcd.drawText(1, 0, "FM: "..fmName,SMLSIZE + fmAttr)
  lcd.drawFilledRectangle(0, 0, 89, 7, GREY(12) + SOLID)

  -- Status flags
  if StatusArmed==1 then lcd.drawPixmap(150,36,"/SCRIPTS/BMP/statusarmed.bmp") end
  if StatusLandComp==1 then lcd.drawPixmap(150,47,"/SCRIPTS/BMP/statuslanded.bmp") end
  if StatusBatFS==1 then lcd.drawPixmap(161,36,"/SCRIPTS/BMP/statusbatfs.bmp") end
  if StatusEKFFS==1 then lcd.drawPixmap(161,47,"/SCRIPTS/BMP/statusekffs.bmp") end

  drawSection[1]=0
end


local function draw5002()
  --Satellites fix and number of satellites
  --GPS status. Leftmost digit encodes GPS state as follow:
  --  Passthrough:
  --  Max. num sats = 15
  --  0=NO_GPS, 1=NO_FIX, 2=GPS_OK_FIX_2D, 3=GPS_OK_FIX_3D, 4=3D Fix HD
  local gpsStatus = GPSFix
  local gpsCount = GPSNumSats
  local gpsTxtAttr = 0
  lcd.drawPixmap(150,8,"/SCRIPTS/BMP/gps01.bmp")
  if gpsStatus == 0 then
    lcd.drawPixmap(150,8,"/SCRIPTS/BMP/gps01_inv.bmp")
    lcd.drawPixmap(161,8,"/SCRIPTS/BMP/gps_nosat.bmp")
    gpsTxtAttr = INVERS + BLINK
  elseif gpsStatus == 1 then
    lcd.drawPixmap(150,8,"/SCRIPTS/BMP/gps01_inv.bmp")
    lcd.drawPixmap(161,8,"/SCRIPTS/BMP/gps_nofix.bmp")
    gpsTxtAttr = INVERS + BLINK
  elseif gpsStatus == 2 then
    lcd.drawPixmap(161,8,"/SCRIPTS/BMP/gps_2dfix.bmp")
    gpsTxtAttr = INVERS
  elseif gpsStatus == 3 then
    lcd.drawPixmap(161,8,"/SCRIPTS/BMP/gps_3dfix.bmp")
    gpsTxtAttr = BLINK
  elseif gpsStatus >= 4 then
    lcd.drawPixmap(161,8,"/SCRIPTS/BMP/gps_3dfixhd.bmp")
    gpsTxtAttr = 0
  end
  clearRectangle(170,8,25,10)
  lcd.drawText(171,9, gpsCount, SMLSIZE + gpsTxtAttr)

  -- Altitude from GPS data
  clearRectangle(75,7,19,50)
  drawAlt(round(GPSAlt/10))

  drawSection[2]=0
end


local function draw5003()
  clearRectangle(96,18,49,19)
  -- UAV battery voltage
  -- For 4S battery voltage is in between 14V (0%) and 16.8V (100%)
  local rxbtPor = (UAVBatVolt - 14.0)/2.8 * 100
  if rxbtPor<0 then rxbtPor=0 end
  lcd.drawText(98,20, "Bat: ", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(),20, rxbtPor, SMLSIZE)
  lcd.drawText(lcd.getLastPos(),20,"%",SMLSIZE)
  lcd.drawGauge(96,19,49,8,rxbtPor,100)
  -- Check if individual cell data is available

  -- UAV battery amperage draw
  local curr = UAVCurr/10  -- Data comes in dA
  lcd.drawText(98,29,"Bat: ", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(),29, curr*10, SMLSIZE + PREC1)
  lcd.drawText(lcd.getLastPos(),29,"A",SMLSIZE)
  lcd.drawGauge(96,28,49,8,curr,20)

  drawSection[3]=0
end


local function draw5004()
  -- GPS distance from home (from Flight Controller)
  lcd.drawPixmap(150,24,"/SCRIPTS/BMP/home01.bmp")
  lcd.drawNumber(161,26,HomeDist,SMLSIZE)
  lcd.drawPixmap(180,24,"/SCRIPTS/BMP/home02.bmp")
  lcd.drawNumber(191,26,HomeAlt,SMLSIZE)

  -- Heading from home location
  clearRectangle(193,7,18,18)
  drawArrow(203,16,(HomeAngle+90)*math.pi/180,16)  -- xCenter,yCenter,angle degrees, size

  drawSection[4]=0
end


local function draw5005()
  clearRectangle(0,7,17,50)
  drawSpeed(SpdHor)

  lcd.drawNumber(58,50,round(SpdVert),SMLSIZE + RIGHT)
  lcd.drawPixmap(58,50,"/SCRIPTS/BMP/dms.bmp")
 
  lcd.drawNumber(18,50, round(Yaw), SMLSIZE)
  lcd.drawPixmap(lcd.getLastPos(),50,"/SCRIPTS/BMP/deg.bmp")

  drawSection[5]=0
end


local function draw5006()
  -- Left panel: PFD (Primary Flight Display)
  clearRectangle(19,7,54,43)
  drawArtificialHorizon(Roll*0.01745, Pitch*0.01745)   -- Roll, pitch (rads)

  drawSection[6]=0
end


local function draw5007()
  -- UAV fuel remaining reported by the flight controller
  local fuel = UAVBattCapResFS / UAVBattCapacity * 100
  clearRectangle(96,36,49,10)
  lcd.drawText(98,38,"Fuel: ", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(),38, fuel, SMLSIZE)
  lcd.drawText(lcd.getLastPos(),38,"%",SMLSIZE)
  lcd.drawGauge(96,37,49,8,fuel,100)

  -- Battery remaining
  lcd.drawText(172,40,UAVBattVoltFS.."dV", SMLSIZE)
  lcd.drawText(172,49,UAVBattCapResFS.."mAh", SMLSIZE)

  drawSection[7]=0
end


local function drawUnder5000()
  -- Title areas. Right side
  lcd.drawFilledRectangle(90,-1,122,8,INVERS)
  lcd.drawFilledRectangle(90,-1,122,8)
  -- UAV
  lcd.drawText(90, 0, "UAV:", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(), 0, UAVBatVolt*10, SMLSIZE + PREC1)
  lcd.drawText(lcd.getLastPos(), 0, "V", SMLSIZE)

  -- Taranis battery voltage
  lcd.drawText(lcd.getLastPos(), 0, " TX:", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(), 0, TxVoltage*10, SMLSIZE + PREC1)
  lcd.drawText(lcd.getLastPos(), 0, "V", SMLSIZE)

  -- Timer
  lcd.drawText(lcd.getLastPos(), 0, " On:", SMLSIZE)
  lcd.drawTimer(lcd.getLastPos(), 0, Timer1, SMLSIZE)

  lcd.drawFilledRectangle(89, -1, 124, 8, GREY(12) + SOLID)


  -- Indicators middle panel: gauges
  -- Radio quality
  local rssi = RSSIPer
  clearRectangle(96,7,49,10)
  lcd.drawText(98,9, "RSSI: ", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(),9,rssi,SMLSIZE)
  lcd.drawText(lcd.getLastPos(),9,"%",SMLSIZE)
  lcd.drawGauge(96,8,49,8,rssi,101)
 
  -- Taranis battery voltage
  -- For 6xNi-MH battery voltage is in between 6.5 (0%) and 8.1V (100%)
  local txbtPor = (TxVoltage - 6.5)/1.6 * 100
  if txbtPor<0 then rxbtPor=0 end
  clearRectangle(96,47,49,10)
  lcd.drawText(98,49, "BtTx: ", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(),49, txbtPor, SMLSIZE)
  lcd.drawText(lcd.getLastPos(),49,"%",SMLSIZE)
  lcd.drawGauge(96,48,49,8,txbtPor,100)
  -- For individual cell data an external sensor is needed

  drawSection[8]=0
end

---------------------------------------------------------------
-- Init function global variables
---------------------------------------------------------------
local function init_func()
  -- (I) Means decoding is already implemented
  -- 0x0800         -- No need to implement. Directly accessible via normal sensors discovery
  --GLatitude=0     -- 32 bits. Degrees
  --GLongitude=0    -- (I) 32 bits. Degrees

  -- 0x5000         -- (I) 32 bits. Sending 4 characters with 7 bits at a time. Msg sent 3 times.
  MsgSeverity=8     -- (I) 3 bits. Severity is sent as the MSB of each of the last three bytes of the last chunk (bits 24, 16, and 8) since a character is on 7 bits.
  MsgText=""        -- (I) 28 bits. The 7 LSB bits of each byte.
  MsgLastReceived="Nothing"
  MsgLastChunk=0
  MsgPrevChunk=""
  MsgByte1=0        -- (I) For the LSB of the message, bits 0 to 7
  MsgByte2=0        -- (I)    bits 8 to 15
  MsgByte3=0        -- (I)    bits 16 to 23
  MsgByte4=0        -- (I) For the MSB of the message, bits 24 to 31

  -- 0x5001
  StatusFtMode=31   -- (I) 5 bits
  --StatusSimpleSS=0  -- 2 bits
  StatusLandComp=0  -- (I) 1 bit
  StatusArmed=0     -- (I) 1 bit
  StatusBatFS=0     -- (I) 1 bit
  StatusEKFFS=0     -- (I) 1 bit

  -- 0x5002
  GPSNumSats=0      -- (I) 4 bits
  GPSFix=0          -- (I) 2 bits. NO_GPS=0, NO_FIX=1, GPS_OK_FIX_2D=2, GPS_OK_FIX_3D>=3 - 4 3D Fix alta precisión
  --GPSHDOP=0       -- (I) 1+7 bits. 10^x + dm
  --GPSVDOP=0       -- (I) 1+7 bits. 10^x + dm
  GPSAlt=0          -- (I) 2+7+1 bits. 10^x + dm * sign

  -- 0x5003
  UAVBatVolt=0      -- (I) 9 bits. dV
  UAVCurr=0         -- (I) 1+7 bits. 10^x + dA
  UAVCurrTot=0      -- (I) 15 bits. mAh. Limit to 32767 = 15 bits

  -- 0x5004
  HomeDist=0        -- (I) 2+10 bits. 10^x + m.
  HomeAngle=0       -- (I) 7 bits. Multiply by 3 to get degrees
  HomeAlt=0         -- (I) 2+10+1 bit. 10^x + dm * sign

  -- 0x5005
  SpdVert=0         -- (I) 1+7+1 bits. 10^x + dm * sign
  SpdHor=0          -- (I) 1+7 bits. 10^x + dm
  Yaw=0             -- (I) 11 bits. 0.2 degrees.

  -- 0x5006
  Roll=0            -- (I) 11 bits. 0.2 egrees.
  Pitch=0           -- (I) 10 bits. 0.2 degrees.
  --RngFindDist=0     -- 1+10 bits. 10^x + cm.

  -- 0x5007         -- 8 bits. Reserve fist 8 bits for param ID
  MAVType=0         -- (I) 8 bits.
  UAVBattCapacity=5800   -- (I) 24 bits. mAh
  UAVBattCapResFS=0 -- (I) 24 bits. mAh
  UAVBattVoltFS=0   -- (I) 4 bits. dV

  -- Local Taranis variables getValue
  TxVoltageId=getFieldInfo("tx-voltage").id   -- (I) 
  TxVoltage = getValue(TxVoltageId)           -- (I) 
  Timer1Id=getFieldInfo("timer1").id          -- (I) 
  Timer1=getValue(Timer1Id)                   -- (I) 
  RSSIPerId=getFieldInfo("RSSI").id           -- (I) 
  RSSIPer=getValue(RSSIPerId)                 -- (I) 
end


---------------------------------------------------------------
-- Visible loop function
---------------------------------------------------------------
local function run(e)
  -- Record the time to print total exec time during debugging
  local runTime = getTime()
 
  -- Prepare to extract SPort data
  local sensorID,frameID,dataID,value = sportTelemetryPop()
--while dataID~=nil do
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

      -- Draw received data
      drawSection[0]=drawSection[0]+1
    end

    -- unpack 0x5001 packet
    if dataID == 0x5001 then
      StatusFtMode=bit32.extract(value,0,5)    -- 5 bits
      --StatusSimpleSS=bit32.extract(value,5,2)  -- 2 bits
      StatusLandComp=bit32.extract(value,7,1)    -- 1 bit
      StatusArmed=bit32.extract(value,8,1)     -- 1 bit
      StatusBatFS=bit32.extract(value,9,1)     -- 1 bit
      StatusEKFFS=bit32.extract(value,10,1)     -- 1 bit

      -- Draw received data
      drawSection[1]=drawSection[1]+1
    end

    -- unpack 0x5002 packet
    if dataID == 0x5002 then
      GPSNumSats = bit32.extract(value,0,4)
      GPSFix = bit32.extract(value,4,2)
      --GPSHDOP = bit32.extract(value,7,7)*(10^(bit32.extract(value,6,1)-1))
      --GPSVDOP = bit32.extract(value,15,7)*(10^(bit32.extract(value,14,1)-1))
      GPSAlt = bit32.extract(value,24,7)*(10^bit32.extract(value,22,2))  -- In dm
      --if (bit32.extract(value,31,1) == 1) then GPSAlt = -GPSAlt end

      -- Draw received data
      drawSection[2]=drawSection[2]+1
    end

    -- unpack 0x5003 packet
    if dataID == 0x5003 then
      UAVBatVolt=bit32.extract(value,0,9) -- 9 bits. dV
      UAVCurr=bit32.extract(value,10,7)*(10^bit32.extract(value,9,1)) -- 1+7 bits. 10^x + dA
      UAVCurrTot=bit32.extract(value,17,15) -- 15 bits. mAh. Limit to 32767 = 15 bits

      -- Draw received data
      drawSection[3]=drawSection[3]+1
    end

     -- unpack 0x5004 packet
    if dataID == 0x5004 then
      HomeDist=bit32.extract(value,2,10)*(10^bit32.extract(value,0,2)) -- 2+10 bits. 10^x + m.
      HomeAngle=bit32.extract(value,12,7)*3 -- 7 bits. By 3 to get up to 360 degrees.
      HomeAlt=bit32.extract(value,21,10)*(10^bit32.extract(value,19,2)) -- 2+10+1 bit. 10^x + dm * sign
      if (bit32.extract(value,31,1) == 1) then HomeAlt = -HomeAlt end

      -- Draw received data
      drawSection[4]=drawSection[4]+1
    end
   
    -- unpack 0x5005 packet
    if dataID == 0x5005 then
     SpdVert= bit32.extract(value,1,7)*(10^bit32.extract(value,0,1)) -- 1+7+1 bits. 10^x + dm * sign
     if (bit32.extract(value,8,1) == 1) then SpdVert = -SpdVert end
     SpdHor=bit32.extract(value,10,7)*(10^bit32.extract(value,9,1)) -- 1+7 bits. 10^x + dm (per second?)
     Yaw = bit32.extract(value,17,11) * 0.2

      -- Draw received data
      drawSection[5]=drawSection[5]+1
    end
    
    -- unpack 0x5006 packet
    if dataID == 0x5006 then
      Roll = (bit32.extract(value,0,11) - 900) * 0.2
      Pitch = (bit32.extract(value,11,10 ) - 450) * 0.2

      -- Draw received data
      drawSection[6]=drawSection[6]+1
      drawSection[5]=drawSection[5]+1
    end

    -- unpack 0x5007 packet
    if dataID == 0x5007 then
      -- 0x5007         -- 8 bits. Reserve fist 8 bits for param ID
      local ParamID=bit32.extract(value,24,8)
      --if ParamID==0x10 then MAVType=bit32.extract(value,0,8) end -- 8 bits.
      if ParamID==0x20 then UAVBattCapacity=bit32.extract(value,0,24) end -- 24 bits. mAh
      if ParamID==0x30 then UAVBattCapResFS=bit32.extract(value,0,24) end -- 24 bits. mAh
      if ParamID==0x40 then UAVBattVoltFS=bit32.extract(value,0,24) end -- 24 bits. dV

      -- Draw received data
      drawSection[7]=drawSection[7]+1
    end

    -- Update normal local telemetry data by its id (faster method)

    if runTime > (lastUpdtTelem+timeToTelemUpdt) then
      lastUpdtTelem=runTime
      TxVoltage = getValue(TxVoltageId)
      Timer1=getValue(Timer1Id)
      RSSIPer=getValue(RSSIPerId)

      -- Draw received data
      drawSection[8]=drawSection[8]+1

      -- Redraw all the screen
      screenCleared=0
    end

    -- Check if there are messages in the queue to avoid exit from the while-do loop
--    sensorID,frameID,dataID,value = sportTelemetryPop()
--  end
  queueTime = (queueTime*0.5)+((getTime()-runTime)*0.5)


  -- If first called, wipe out the lcd
  if screenCleared==0 then
   lcd.clear()
   drawLayout()
   screenCleared=1
   draw5006()
   draw5000()
   draw5001()
   draw5002()
   draw5003()
   draw5004()
   draw5005()
   draw5007()
   drawUnder5000()
  end

  -- Adjust here the drawing priority
  if drawSection[0]==drawPrio1 then draw5000() end
  if drawSection[1]==drawPrio1 then draw5001() end
  if drawSection[2]==drawPrio2 then draw5002() end
  if drawSection[3]==drawPrio2 then draw5003() end
  if drawSection[4]==drawPrio3 then draw5004() end
  if drawSection[5]==drawPrio1 then draw5005() end
  if drawSection[6]==drawPrio0 then draw5006() end
  if drawSection[7]==drawPrio2 then draw5007() end
  if drawSection[8]==drawPrio2 then drawUnder5000() end

  drawTime= (drawTime*0.5) + ((getTime()-runTime-queueTime)*0.5)

  -- Printing debugging info, use debugFeed() to move values in Companion simulator
  --Roll=debugFeed()%10 + 70
  --Pitch=debugFeed()
  --GPSAlt=debugFeed()*10
  --SpdHor=debugFeed()*15
  --HomeAngle=debugFeed()*6
  --draw5004()
  --draw5005()
  --draw5005()
  
  totalTime= (totalTime*0.9) + ((getTime()-runTime)*0.1)
  -- Print exec time (for debugging)
  lcd.drawNumber(212,30,queueTime,SMLSIZE+RIGHT)
  lcd.drawNumber(212,40,drawTime,SMLSIZE+RIGHT)
  lcd.drawNumber(212,50,totalTime,SMLSIZE+RIGHT)
end

return{run=run, init=init_func}
