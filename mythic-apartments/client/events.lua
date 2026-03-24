AddEventHandler("Apartment:SpawnInside", function()
	Callbacks:ServerCallback("Apartment:SpawnInside", {}, function(success)
	end)
end)

RegisterNetEvent("Apartment:Client:InnerStuff", function(aptId, unit, wakeUp)
	while GlobalState[string.format("%s:Apartment", LocalPlayer.state.ID)] == nil do
		Wait(10)
	end

	local p = GlobalState[string.format("Apartment:%s", aptId)]
	if not p or not p.interior then
		return
	end

	if p.floor ~= nil and p.buildingName ~= nil then
		_currentElevatorBuilding = p.buildingName
		_currentElevatorFloor    = p.floor
		_currentFloor            = p.floor

		QueueSpawnFloorFurniture(p.buildingName, p.floor)
	end

	TriggerEvent("Interiors:Enter", vector3(p.interior.spawn.x, p.interior.spawn.y, p.interior.spawn.z))

	if wakeUp then
		SetTimeout(250, function()
			Animations.Emotes:WakeUp(p.interior.wakeup)
		end)
	end

	SetupApartmentTargets(aptId, unit)

	Targeting.Zones:Refresh()
	Wait(1000)
	Sync:Stop(1)
end)

AddEventHandler("Characters:Client:Spawn", function()
	if not LocalPlayer.state.Character then
		return
	end

	local char  = LocalPlayer.state.Character
	local mySID = char:GetData("SID")
	local aptId = char:GetData("Apartment") or 0

	if aptId > 0 then
		CreateThread(function()
			local timeout = GetGameTimer() + 8000
			while GetGameTimer() < timeout do
				if LocalPlayer.state.inApartment and LocalPlayer.state.inApartment.type and LocalPlayer.state.inApartment.id then
					break
				end
				Wait(100)
			end

			local aptState = LocalPlayer.state.inApartment

			if not aptState or not aptState.type then
				return
			end

			if aptState.id == mySID then
				local actualAptId = aptState.type
				SetupApartmentTargets(actualAptId, mySID)

				local p = GlobalState[string.format("Apartment:%s", actualAptId)]
				if p and p.buildingName and p.floor ~= nil then
					_currentElevatorBuilding = p.buildingName
					_currentElevatorFloor    = p.floor
					_currentFloor            = p.floor

					QueueSpawnFloorFurniture(p.buildingName, p.floor)
				end
			end
		end)
	end
end)

RegisterNetEvent("Characters:Client:Logout")
AddEventHandler("Characters:Client:Logout", function()
	_currentFloor            = nil
	_currentElevator         = nil
	_currentElevatorBuilding = nil
	_currentElevatorFloor    = nil

	ClearFloorFurniture()

	if LocalPlayer.state.inApartment then
		local aptId = LocalPlayer.state.inApartment.type
		local unit  = LocalPlayer.state.inApartment.id

		if aptId then
			local p = GlobalState[string.format("Apartment:%s", aptId)]
			if p and p.interior then
				for k, v in pairs(p.interior.locations) do
					Targeting.Zones:RemoveZone(string.format("apt-%s-%s", k, aptId))
				end
				Targeting.Zones:RemoveZone(string.format("apt-%s-raid", aptId))

				if p.interior.locations.wardrobe then
					Polyzone:Remove(string.format("apt-%s-wardrobe", aptId))
				end
				if p.interior.locations.shower then
					Polyzone:Remove(string.format("apt-%s-shower", aptId))
				end

				if unit then
					local exitKey = string.format("%s_%s", aptId, unit)
					_apartmentTargetsSetup[exitKey]   = nil
					_apartmentPolyzonesSetup[exitKey] = nil
				end

				Targeting.Zones:Refresh()
			end
		end

		for buildingName, buildingData in pairs(_floorRaidTargets) do
			for floor, aptIds in pairs(buildingData) do
				for _, floorAptId in ipairs(aptIds) do
					Targeting.Zones:RemoveZone(string.format("apt-%s-raid-floor", floorAptId))
				end
			end
		end
		_floorRaidTargets = {}
	end

	_currentWardrobe = nil
	_currentShower   = nil
	Action:Hide()
	TriggerServerEvent("Apartment:Server:LogoutCleanup")
end)

AddEventHandler("Polyzone:Enter", function(id, testedPoint, insideZones, data)
	if data and data._isElevator and data.buildingName and data.floor ~= nil then
		_currentElevator = {
			buildingName  = data.buildingName,
			floor         = data.floor,
			elevatorIndex = data.elevatorIndex
		}
		_currentElevatorBuilding = data.buildingName
		_currentElevatorFloor    = data.floor

		Action:Show("{keybind}primary_action{/keybind} Use Elevator")
		CreateFloorRaidTargets(data.buildingName, data.floor)

	elseif data and data._roomPoly and data.aptId ~= nil then
		local buildingName = data.buildingName
		local floor        = data.floor

		if (buildingName == nil or floor == nil) and _RoomMetaByAptId[data.aptId] then
			buildingName = _RoomMetaByAptId[data.aptId].buildingName
			floor        = _RoomMetaByAptId[data.aptId].floor
		end

		if buildingName ~= nil and floor ~= nil then
			_currentElevatorBuilding = buildingName
			_currentElevatorFloor    = floor
			_currentFloor            = floor

			QueueSpawnFloorFurniture(buildingName, floor)
		end

	elseif data and data.type == "wardrobe" then
		local char = LocalPlayer.state.Character
		if char and data.unit == char:GetData("SID") then
			_currentWardrobe = { aptId = data.aptId, unit = data.unit }
			Action:Show("{keybind}primary_action{/keybind} Use Wardrobe")
		end

	elseif data and data.type == "shower" then
		local char = LocalPlayer.state.Character
		if char and data.unit == char:GetData("SID") then
			_currentShower = { aptId = data.aptId, unit = data.unit }
			Action:Show("{keybind}primary_action{/keybind} Use Shower")
		end

	elseif _pzs[id] and string.format("apt-%s", LocalPlayer.state.Character:GetData("Apartment") or 1) == id then
		while GetVehiclePedIsIn(LocalPlayer.state.ped) ~= 0 do
			Wait(10)
		end

		_inPoly = {
			id   = id,
			data = data.tier
		}
	end
end)

AddEventHandler("Polyzone:Exit", function(id, testedPoint, insideZones, data)
	if data and data._isElevator and _currentElevator
	   and _currentElevator.buildingName == data.buildingName
	   and _currentElevator.floor == data.floor
	   and _currentElevator.elevatorIndex == data.elevatorIndex then
		_currentElevator = nil
		Action:Hide()

	elseif data and data.type == "wardrobe" and _currentWardrobe and _currentWardrobe.aptId == data.aptId then
		_currentWardrobe = nil
		Action:Hide()

	elseif data and data.type == "shower" and _currentShower and _currentShower.aptId == data.aptId then
		_currentShower = nil
		Action:Hide()

	elseif _inPoly and id == _inPoly.id then
		_inPoly = nil
		Action:Hide()
	end
end)

AddEventHandler("Keybinds:Client:KeyUp:primary_action", function()
	if _currentElevator and _currentElevator.buildingName and Config.HotelElevators and Config.HotelElevators[_currentElevator.buildingName] then
		OpenElevatorMenu(_currentElevator.buildingName)
	elseif _currentWardrobe then
		Apartment.Extras:Wardrobe()
	elseif _currentShower then
		TriggerEvent("Apartment:Client:Shower", _currentShower.unit)
	end
end)

AddEventHandler("Apartment:Client:Enter", function(data)
	Apartment:Enter(data)
end)

AddEventHandler("Apartment:Client:Stash", function(t, data)
	Apartment.Extras:Stash()
end)

AddEventHandler("Apartment:Client:Wardrobe", function(t, data)
	Apartment.Extras:Wardrobe()
end)

AddEventHandler("Apartment:Client:Logout", function(t, data)
	Apartment.Extras:Logout()
end)

AddEventHandler("Apartment:Reception:RequestApartment", function()
	Apartment.Reception:RequestApartment()
end)

AddEventHandler("Apartment:Reception:GetMyRoom", function()
	Apartment.Reception:GetMyRoom()
end)

AddEventHandler("Apartment:Reception:PoliceLookup", function()
	Apartment.Police:RoomLookup()
end)

AddEventHandler("Apartment:Reception:DoPoliceLookup", function(values, data)
	Apartment.Police:DoRoomLookup(values)
end)

AddEventHandler("Apartment:Client:UpgradeStash", function(t, data)
	Apartment.Stash:Upgrade()
end)

AddEventHandler("Apartment:Stash:ConfirmUpgrade", function()
	Apartment.Stash:ConfirmUpgrade()
end)