function CreateElevatorPolyzones()
	if not Config.HotelElevators then
		return
	end

	for buildingName, elevatorFloors in pairs(Config.HotelElevators) do
		for floor, floorElevators in pairs(elevatorFloors) do
			for elevatorIndex, elevatorData in pairs(floorElevators) do
				if type(elevatorData) ~= "table" then
					goto continue
				end
				if elevatorData.poly then
					local zoneId = string.format("elevator-%s-%s-%s", buildingName, floor, elevatorIndex)
					Polyzone.Create:Box(zoneId, elevatorData.poly.center, elevatorData.poly.length, elevatorData.poly.width, elevatorData.poly.options, {
						buildingName  = buildingName,
						floor         = floor,
						elevatorIndex = elevatorIndex,
						_isElevator   = true,
					})
				end
				::continue::
			end
		end
	end
end

function OpenElevatorMenu(buildingName)
	local elevatorFloors    = Config.HotelElevators[buildingName]
	local floorDescriptions = Config.HotelElevatorsDesc and Config.HotelElevatorsDesc[buildingName] or {}

	if not elevatorFloors then
		return
	end

	local buildingLabel = buildingName
	if Config.HotelRooms and Config.HotelRooms[buildingName] and Config.HotelRooms[buildingName].label then
		buildingLabel = Config.HotelRooms[buildingName].label
	end

	local menu = {
		main = { label = buildingLabel, items = {} }
	}

	local sortedFloors = {}
	for floorId, _ in pairs(elevatorFloors) do
		table.insert(sortedFloors, floorId)
	end
	table.sort(sortedFloors, function(a, b) return a < b end)

	for _, floorId in ipairs(sortedFloors) do
		local isDisabled  = false
		local description = nil

		if _currentElevatorBuilding == buildingName and _currentElevatorFloor ~= nil and floorId == _currentElevatorFloor then
			isDisabled  = true
			description = "You are currently on this floor"
		end

		local floorLabel = floorDescriptions[floorId] or ("Floor " .. floorId)
		if floorId == 0 then
			floorLabel = floorDescriptions[0] or "Lobby"
		end

		table.insert(menu.main.items, {
			level       = floorId,
			label       = floorLabel,
			disabled    = isDisabled,
			description = description,
			event       = "Apartment:Client:UseElevator",
			data        = { buildingName = buildingName, floor = floorId }
		})
	end

	ListMenu:Show(menu)
end

AddEventHandler("Apartment:Client:UseElevator", function(data)
	if not data or not data.buildingName or not data.floor then
		return
	end

	local elevatorFloors = Config.HotelElevators[data.buildingName]
	if not elevatorFloors or not elevatorFloors[data.floor] then
		return
	end

	local floorElevators = elevatorFloors[data.floor]
	local targetElevator = floorElevators[1]

	if not targetElevator or not targetElevator.pos then
		return
	end

	ListMenu:Close()

	CreateThread(function()
		local shakeDuration = 800
		local startTime     = GetGameTimer()
		while GetGameTimer() - startTime < shakeDuration do
			ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.015)
			Wait(100)
		end
	end)

	Wait(800)

	QueueSpawnFloorFurniture(data.buildingName, data.floor)

	DoScreenFadeOut(1200)
	while not IsScreenFadedOut() do Wait(10) end

	Wait(300)

	SetEntityCoords(LocalPlayer.state.ped, targetElevator.pos.x, targetElevator.pos.y, targetElevator.pos.z)
	SetEntityHeading(LocalPlayer.state.ped, targetElevator.pos.w or 0.0)

	Sounds.Play:Distance(5.0, "elevator-bell.ogg", 0.4)

	Wait(200)

	DoScreenFadeIn(1200)

	_currentElevatorBuilding = data.buildingName
	_currentElevatorFloor    = data.floor
	_currentFloor            = data.floor

	TriggerServerEvent("Apartment:Server:ElevatorFloorChanged", data.buildingName, data.floor)
	TriggerEvent("Apartment:Client:spawnFk", data.buildingName, data.floor, nil)

	CreateFloorRaidTargets(data.buildingName, data.floor)

	if LocalPlayer.state.Character then
		local char  = LocalPlayer.state.Character
		local mySID = char:GetData("SID")
		local aptId = char:GetData("Apartment") or 0

		if aptId > 0 then
			local apt = GlobalState[string.format("Apartment:%s", aptId)]
			if apt and apt.buildingName == data.buildingName and apt.floor == data.floor then
				local inApartmentState = LocalPlayer.state.inApartment
				if inApartmentState and inApartmentState.type == aptId and inApartmentState.id == mySID then
					TriggerEvent("Apartment:Client:InnerStuff", aptId, mySID, false)
				end
			end
		end
	end
end)

RegisterNetEvent("Apartment:Client:ExitElevator", function()
	ClearFloorFurniture()
	TriggerEvent("Interiors:Exit")
	Sync:Start()
end)
