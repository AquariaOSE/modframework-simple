-- don't put code here!
-- this is loaded by many scripts, possibly multiple times.
-- it's only purpose is to define some global constants that are used in many places
----------------------------

-- Couple globals needed for various scripts (extends the EVT_* enum with new custom types).
-- The IDs here are arbitary but should not collide with the existing EVT_* constants.
EVT_ORB = 100 -- entity is an orb (active on STATE_CHARGED)
EVT_DOOR = 101 -- entity is a door (uses STATE_OPEN, STATE_CLOSE, STATE_OPENED, STATE_CLOSED; also see aqmodlib/doorhelper.lua)
EVT_ACTIVATOR = 102 -- entity is a switch (uses STATE_ON, STATE_OFF)
EVT_HUMANOID = 103 -- entitiy is NPC (not really used; intended for switch activation, see proximityswitch.lua)

