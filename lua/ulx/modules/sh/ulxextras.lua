-- Revives a dead player
function ulx.revive(callingPly, targetPly)
    if targetPly:Alive() then
        ULib.tsayError(callingPly, targetPly:Nick() .. " is already alive!", true)

        return
    end

    local pos = targetPly:GetPos()
    local ang = targetPly:EyeAngles()

    targetPly:Spawn()
    targetPly:SetPos(pos)
    targetPly:SetEyeAngles(ang)

    ulx.fancyLogAdmin(callingPly, "#A revived #T", targetPly)
end

local revive = ulx.command("Utility", "ulx revive", ulx.revive, "!revive")
revive:addParam({type = ULib.cmds.PlayerArg, ULib.cmds.optional})
revive:defaultAccess(ULib.ACCESS_ALL)
revive:help("Revives a player")


-- Cleans up a player's props
function ulx.cleanup(callingPly, targetPly)
    if not NADMOD then
        ULib.tsayError(callingPly, "NADMOD is not installed!", true)

        return
    end

    NADMOD.CleanupPlayerProps(targetPly:SteamID())

    ulx.fancyLogAdmin(callingPly, "#A cleaned up #T's props", targetPly)
end

local clean = ulx.command("Utility", "ulx cleanup", ulx.cleanup, "!cleanup")
clean:addParam({type = ULib.cmds.PlayerArg})
clean:defaultAccess(ULib.ACCESS_ADMIN)
clean:help("Cleans up a player's props")


-- Sets a player's spawn position
function ulx.setspawn(callingPly, targetPly, shouldReset)
    if not IsValid(callingPly) then
        ULib.tsayError(callingPly, "Cannot run this command from the console!", true)

        return
    end

    if not targetPly:IsValid() then
        ULib.tsayError(callingPly, "Invalid target!", true)

        return
    end

    if shouldReset then
        targetPly.ulxSpawnPos = nil
        ulx.fancyLogAdmin(callingPly, "#A reset #T's spawn position", targetPly)
    else
        targetPly.ulxSpawnPos = callingPly:GetPos()
        ulx.fancyLogAdmin(callingPly, "#A set #T's spawn position", targetPly)
    end
end

local setspawn = ulx.command("Utility", "ulx setspawn", ulx.setspawn, "!setspawn")
setspawn:addParam({type = ULib.cmds.PlayerArg, ULib.cmds.optional})
setspawn:addParam({type = ULib.cmds.BoolArg, invisible = true})
setspawn:defaultAccess(ULib.ACCESS_ALL)
setspawn:help("Sets a player's spawn position")
setspawn:setOpposite("ulx resetspawn", {_, _, true}, "!resetspawn")

hook.Add("PlayerSpawn", "ULX_AvtoExtras_SetSpawn", function(ply)
    if ply.ulxSpawnPos then
        ply:SetPos(ply.ulxSpawnPos)
    end
end)


-- Clears all decals
function ulx.decals(callingPly)
    for _, ply in player.Iterator() do
        ply:ConCommand("r_cleardecals")
    end

    ulx.fancyLogAdmin(callingPly, "#A cleared decals")
end

local decals = ulx.command("Utility", "ulx decals", ulx.decals, "!decals")
decals:defaultAccess(ULib.ACCESS_ADMIN)
decals:help("Clears all decals")


-- Freezes all props, optionally a target's props instead of all props
local function freezeProps(target)
    for _, ent in ents.Iterator() do
        if not target or (target and ent:CPPIGetOwner() == target) then
            local phys = ent:GetPhysicsObject()

            if IsValid(phys) then
                phys:EnableMotion(false)
            end
        end
    end
end

-- Freeze all entities on the map
function ulx.freezemap(callingPly)
    freezeProps()

    ulx.fancyLogAdmin(callingPly, "#A froze everything")
end

local freezemap = ulx.command("Utility", "ulx freezemap", ulx.freezemap, "!freezemap")
freezemap:defaultAccess(ULib.ACCESS_ADMIN)
freezemap:help("Freezes all entities on the map")


-- Freeze a specific player's props
function ulx.freezeallof(callingPly, targetPly)
    if not CPPI then
        ULib.tsayError(callingPly, "This command requires a CPPI-compatible prop protection addon!", true)

        return
    end

    freezeProps(targetPly)

    ulx.fancyLogAdmin(callingPly, "#A froze #T's props", targetPly)
end

local freezeallof = ulx.command("Utility", "ulx freezeallof", ulx.freezeallof, "!freezeallof")
freezeallof:addParam({type = ULib.cmds.PlayerArg})
freezeallof:defaultAccess(ULib.ACCESS_ADMIN)
freezeallof:help("Freezes all of a specific player's props")


-- Freezes the caller's props
function ulx.freezeall(callingPly)
    if not CPPI then
        ULib.tsayError(callingPly, "This command requires a CPPI-compatible prop protection addon!", true)

        return
    end

    freezeProps(callingPly)

    ulx.fancyLogAdmin(callingPly, "#A froze all of their props")
end

local freezeall = ulx.command("Utility", "ulx freezeall", ulx.freezeall, "!freezeall")
freezeall:defaultAccess(ULib.ACCESS_ALL)
freezeall:help("Freezes all of your own props")


-- Enters the last vehicle the player was in
local lastVehicles = {}

hook.Add("PlayerEnteredVehicle", "ULX_AvtoExtras_SaveVehicle", function(ply, vehicle)
    lastVehicles[ply] = vehicle
end)

hook.Add("PlayerDisconnected", "ULX_AvtoExtras_SaveVehicleCleanup", function(ply)
    lastVehicles[ply] = nil
end)

function ulx.backseat(callingPly)
    local vehicle = lastVehicles[callingPly]

    if not IsValid(vehicle) then
        ULib.tsayError(callingPly, "No previous seat available to enter!", true)

        return
    end

    callingPly:EnterVehicle(vehicle)
end

local backseat = ulx.command("Utility", "ulx backseat", ulx.backseat, "!backseat")
backseat:defaultAccess(ULib.ACCESS_ALL)
backseat:help("Enters the last vehicle you were in")


-- Save locations and allow players to teleport to them
local locations = {}
local map = game.GetMap()

if not file.Exists("ulx_extras/locations.txt", "DATA") then
    file.CreateDir("ulx_extras")
    file.Write("ulx_extras/locations.txt", util.TableToJSON({}))
else
    locations = util.JSONToTable(file.Read("ulx_extras/locations.txt", "DATA") or "") or {}
end

-- Adds a location for the current map
function ulx.locadd(callingPly, name)
    name = string.lower(name)

    if not IsValid(callingPly) then
        ULib.tsayError(callingPly, "You cannot add locations from the console!", true)

        return
    end

    if not name:match("^%w+$") then
        ULib.tsayError(callingPly, "Location name can only contain letters, numbers, and underscores!", true)

        return
    end

    locations[map] = locations[map] or {}
    locations[map][name] = callingPly:GetPos()

    file.Write("ulx_extras/locations.txt", util.TableToJSON(locations, true))

    ulx.fancyLogAdmin(callingPly, "#A added location #s", name)
end

local locadd = ulx.command("Teleport", "ulx locadd", ulx.locadd, "!locadd")
locadd:addParam({type = ULib.cmds.StringArg, hint = "Location Name"})
locadd:defaultAccess(ULib.ACCESS_ADMIN)

-- Deletes a location for the current map
function ulx.locdel(callingPly, name)
    name = string.lower(name)

    if not locations[map] or not locations[map][name] then
        ULib.tsayError(callingPly, "Location not found!", true)

        return
    end

    locations[map][name] = nil

    if not next(locations[map]) then
        locations[map] = nil
    end

    file.Write("ulx_extras/locations.txt", util.TableToJSON(locations, true))

    ulx.fancyLogAdmin(callingPly, "#A deleted location #s", name)
end

local locdel = ulx.command("Teleport", "ulx locdel", ulx.locdel, "!locdel")
locdel:addParam({type = ULib.cmds.StringArg, hint = "Location Name"})
locdel:defaultAccess(ULib.ACCESS_ADMIN)

-- Lists all locations for the current map
function ulx.loclist(callingPly)
    if not locations[map] or not next(locations[map]) then
        ULib.tsay(callingPly, "No locations have been added for this map yet!")

        return
    end

    local locationNames = {}

    for name in pairs(locations[map]) do
        table.insert(locationNames, name)
    end

    ULib.tsay(callingPly, "Locations for this map:\n" .. table.concat(locationNames, "\n"))
end

local loclist = ulx.command("Teleport", "ulx loclist", ulx.loclist, "!loclist")
loclist:defaultAccess(ULib.ACCESS_ALL)

-- Teleports to a saved location
function ulx.lgo(callingPly, name)
    name = string.lower(name)

    if not locations[map] or not locations[map][name] then
        ULib.tsayError(callingPly, "Location not found!", true)

        return
    end

    callingPly:SetPos(locations[map][name])

    ulx.fancyLogAdmin(callingPly, "#A teleported to location #s", name)
end

local lgo = ulx.command("Teleport", "ulx lgo", ulx.lgo, "!lgo")
lgo:addParam({type = ULib.cmds.StringArg, hint = "Location Name"})
lgo:defaultAccess(ULib.ACCESS_ALL)
