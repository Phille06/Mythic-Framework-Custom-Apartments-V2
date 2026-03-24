local stageComplete = 0

local function SkillCheckRaid(diff)
	local p = promise.new()
	Minigame.Play:RoundSkillbar((diff.timer + 1.0), diff.difficulty - stageComplete, {
		onSuccess = function()
			Wait(400)
			if stageComplete >= Config.RaidDoorSkillbar.amount then
				stageComplete = 0
				p:resolve(true)
			else
				stageComplete = stageComplete + 1
				p:resolve(SkillCheckRaid(diff))
			end
		end,
		onFail = function()
			stageComplete = 0
			p:resolve(false)
		end,
	}, {
		useWhileDead = false,
		vehicle = false,
		animation = {
			animDict = "veh@break_in@0h@p_m_one@",
			anim = "low_force_entry_ds",
			flags = 16,
		},
	})
	return Citizen.Await(p)
end

function CreateFloorRaidTargets(buildingName, floor)
	if not buildingName or floor == nil then
		return
	end

	if _floorRaidTargets[buildingName] and _floorRaidTargets[buildingName][floor] then
		for _, aptId in ipairs(_floorRaidTargets[buildingName][floor]) do
			Targeting.Zones:RemoveZone(string.format("apt-%s-raid-floor", aptId))
		end
	end

	Callbacks:ServerCallback("Apartment:GetFloorApartments", {
		buildingName = buildingName,
		floor        = floor
	}, function(floorApartments)
		if not floorApartments or #floorApartments == 0 then
			return
		end

		_floorRaidTargets[buildingName]        = _floorRaidTargets[buildingName] or {}
		_floorRaidTargets[buildingName][floor] = {}

		for _, aptData in ipairs(floorApartments) do
			local aptId = aptData.aptId
			local apt   = GlobalState[string.format("Apartment:%s", aptId)]
			if apt then
				local doorEntry = nil
				if apt.zones and apt.zones.doorEntry then
					doorEntry = apt.zones.doorEntry
				elseif apt.doorEntry then
					doorEntry = apt.doorEntry
				elseif apt.coords then
					doorEntry = apt.coords
				end

				if doorEntry then
					Targeting.Zones:AddBox(
						string.format("apt-%s-raid-floor", aptId),
						"shield-halved",
						doorEntry,
						1.5,
						1.5,
						{
							heading = 0,
							minZ    = doorEntry.z - 1.0,
							maxZ    = doorEntry.z + 2.0
						},
						{
							{
								icon      = "shield-halved",
								text      = "Start Raid",
								event     = "Apartment:Client:StartRaid",
								data      = { aptId = aptId, unit = aptData.unit },
								isEnabled = function(data)
									if LocalPlayer.state.onDuty ~= "police" then return false end
									if not Jobs.Permissions:HasPermissionInJob('police', 'PD_RAID') then return false end
									return GlobalState[string.format("Apartment:RaidPending:%s", aptId)] ~= true
										and GlobalState[string.format("Apartment:Raid:%s", aptId)] ~= true
								end,
							},
							{
								icon      = "door-open",
								text      = "Open Door",
								event     = "Apartment:Client:Raid",
								data      = { aptId = aptId, unit = aptData.unit },
								isEnabled = function(data)
									if LocalPlayer.state.onDuty ~= "police" then return false end
									if not Jobs.Permissions:HasPermissionInJob('police', 'PD_RAID') then return false end
									return GlobalState[string.format("Apartment:RaidPending:%s", aptId)] == true
										and GlobalState[string.format("Apartment:Raid:%s", aptId)] ~= true
								end,
							},
							{
								icon      = "shield-halved",
								text      = "Stop Raid",
								event     = "Apartment:Client:StopRaid",
								data      = { aptId = aptId, unit = aptData.unit },
								isEnabled = function(data)
									if LocalPlayer.state.onDuty ~= "police" then return false end
									if not Jobs.Permissions:HasPermissionInJob('police', 'PD_RAID') then return false end
									return GlobalState[string.format("Apartment:Raid:%s", aptId)] == true
								end,
							},
						},
						3.0,
						true
					)
					table.insert(_floorRaidTargets[buildingName][floor], aptId)
				end
			end
		end

		Targeting.Zones:Refresh()
	end)
end

AddEventHandler("Apartment:Client:Raid", function(t, data)
	if not data or not data.aptId or not data.unit then
		return
	end
	if Config.RaidDoorSkillbar.enabled then
		local skillcheck = SkillCheckRaid({ timer = Config.RaidDoorSkillbar.time, difficulty = Config.RaidDoorSkillbar.difficulty }, data, cb)
		if not skillcheck then
			Notification:Error("Raid failed! You couldn't breach the door.")
			return
		end
	end
	Callbacks:ServerCallback("Apartment:Validate", {
		id   = data.aptId,
		type = "raid",
		unit = data.unit
	})
end)

AddEventHandler("Apartment:Client:StartRaid", function(t, data)
	if not data or not data.aptId or not data.unit then
		return
	end

	Callbacks:ServerCallback("Apartment:Validate", {
		id   = data.aptId,
		type = "startraid",
		unit = data.unit
	})
end)

RegisterNetEvent("Apartment:Client:RaidPendingChanged", function(aptId, isPending)
	Targeting.Zones:Refresh()
end)

RegisterNetEvent("Apartment:Client:RaidStateChanged", function(aptId, isRaided, unit)
	if isRaided and unit and LocalPlayer.state.onDuty == "police" then
		SetupApartmentTargets(aptId, unit)
	end
	Targeting.Zones:Refresh()
end)

AddEventHandler("Apartment:Client:StopRaid", function(t, data)
	if not data or not data.aptId then
		return
	end

	Callbacks:ServerCallback("Apartment:Validate", {
		id   = data.aptId,
		type = "stopraid",
		unit = data.unit
	})
end)

AddEventHandler("Apartment:Client:RaidStash", function(t, data)
	if not data or not data.aptId or not data.unit then
		return
	end

	if Config.RaidStashSkillbar.enabled then
		local skillcheck = SkillCheckRaid({ timer = Config.RaidStashSkillbar.time, difficulty = Config.RaidStashSkillbar.difficulty }, data, cb)
		if not skillcheck then
			Notification:Error("Raid failed! You couldn't breach the stash.")
			return
		end
	end

	if Config.RaidStashSkillbar.enabled then
		Wait(1000)
	end
	
	Callbacks:ServerCallback("Apartment:Validate", {
		id   = data.aptId,
		type = "stash",
		unit = data.unit,
	})
end)
