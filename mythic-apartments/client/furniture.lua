local _roomPolyZones = {}

local function _safe_tonumber(v)
	return tonumber(v)
end

local function BuildRoomsReadyFromConfig()
	if not Config then return false end
	Config.RoomsReady = Config.RoomsReady or {}

	if type(Config.RoomsReady) == "table" and next(Config.RoomsReady) ~= nil then
		return true
	end

	if type(GetApartmentDataFromConfig) ~= "function" then
		return false
	end

	local ok, apartments = pcall(GetApartmentDataFromConfig)
	if not ok or type(apartments) ~= "table" then
		return false
	end

	for _, apt in ipairs(apartments) do
		if type(apt) == "table" and apt.buildingName ~= nil and apt.floor ~= nil then
			local buildingName = tostring(apt.buildingName)
			local floor = _safe_tonumber(apt.floor)

			if floor ~= nil then
				Config.RoomsReady[buildingName] = Config.RoomsReady[buildingName] or {}
				Config.RoomsReady[buildingName][floor] = Config.RoomsReady[buildingName][floor] or {}

				local aptId = apt.roomIndex or apt.id or apt.aptId or apt.apartmentId
				aptId = _safe_tonumber(aptId) or aptId

				local roomLabel = apt.roomLabel or apt.name or apt.label or (aptId and tostring(aptId) or "Room")

				local poly = nil
				if apt.coords and apt.length and apt.width and apt.options then
					poly = {
						center  = apt.coords,
						length  = apt.length,
						width   = apt.width,
						options = apt.options,
					}
				end

				table.insert(Config.RoomsReady[buildingName][floor], {
					aptId     = aptId,
					roomLabel = roomLabel,
					furniture = apt.furniture or {},
					poly      = poly,
				})
			end
		end
	end

	return true
end

local function BuildRoomsIndexes()
	_RoomsIndexByBuildingFloor = {}
	_RoomMetaByAptId = {}

	if not Config or type(Config.RoomsReady) ~= "table" then
		return false
	end

	for buildingName, floors in pairs(Config.RoomsReady) do
		if type(floors) == "table" then
			_RoomsIndexByBuildingFloor[buildingName] = _RoomsIndexByBuildingFloor[buildingName] or {}

			for floor, rooms in pairs(floors) do
				local f = _safe_tonumber(floor) or floor
				if type(rooms) == "table" then
					_RoomsIndexByBuildingFloor[buildingName][f] = {}

					for _, room in ipairs(rooms) do
						if type(room) == "table" then
							local aptId = room.aptId or room.id or room.roomIndex
							aptId = _safe_tonumber(aptId) or aptId

							table.insert(_RoomsIndexByBuildingFloor[buildingName][f], room)

							if aptId ~= nil then
								_RoomMetaByAptId[aptId] = {
									buildingName = buildingName,
									floor        = f,
									roomLabel    = room.roomLabel or room.name or tostring(aptId),
								}
							end
						end
					end
				end
			end
		end
	end

	return true
end

function EnsureRoomsReady(timeoutMs)
	timeoutMs = timeoutMs or 8000
	local start = GetGameTimer()

	while GetGameTimer() - start < timeoutMs do
		local ok = BuildRoomsReadyFromConfig()
		if ok then
			BuildRoomsIndexes()
			_RoomsReadyBuilt = true
			return true
		end
		Wait(250)
	end

	return false
end

local function GetFloorRooms(buildingName, floor)
	if not _RoomsReadyBuilt then
		EnsureRoomsReady(1000)
	end

	if _RoomsIndexByBuildingFloor[buildingName] and _RoomsIndexByBuildingFloor[buildingName][floor] then
		return _RoomsIndexByBuildingFloor[buildingName][floor]
	end

	if Config and Config.RoomsReady and Config.RoomsReady[buildingName] and Config.RoomsReady[buildingName][floor] then
		return Config.RoomsReady[buildingName][floor]
	end

	return {}
end

local function SpawnFurnitureProp(data)
	if type(data) ~= "table" or not data.model or data.x == nil or data.y == nil or data.z == nil then
		return nil
	end

	local model = joaat(data.model)
	RequestModel(model)
	while not HasModelLoaded(model) do
		Wait(0)
	end

	local obj = CreateObjectNoOffset(model, data.x, data.y, data.z, false, false, false)

	SetEntityHeading(obj, data.h or 0.0)
	FreezeEntityPosition(obj, true)
	SetEntityInvincible(obj, true)
	SetEntityCollision(obj, true, true)
	SetEntityAsMissionEntity(obj, true, true)

	return obj
end

function ClearFloorFurniture()
	if not CurrentFloorKey then
		_FurnitureSpawned = false
		return
	end

	local objs = SpawnedFloorFurniture[CurrentFloorKey]
	if objs then
		for _, ent in ipairs(objs) do
			if DoesEntityExist(ent) then
				DeleteEntity(ent)
			end
		end
	end

	SpawnedFloorFurniture[CurrentFloorKey] = nil
	CurrentFloorKey = nil
	_FurnitureSpawned = false
end

local function CreateFloorFurniture(buildingName, floor, floordata)
	if not buildingName or floor == nil then return end

	local floorKey = string.format("%s:%s", buildingName, floor)

	if _FurnitureSpawned and CurrentFloorKey == floorKey and SpawnedFloorFurniture[floorKey] and #SpawnedFloorFurniture[floorKey] > 0 then
		return
	end

	if CurrentFloorKey ~= nil and CurrentFloorKey ~= floorKey then
		ClearFloorFurniture()
	end

	CurrentFloorKey = floorKey
	SpawnedFloorFurniture[floorKey] = SpawnedFloorFurniture[floorKey] or {}

	if not floordata or type(floordata) ~= "table" then
		floordata = GetFloorRooms(buildingName, floor)
	end
	if not floordata or type(floordata) ~= "table" then
		return
	end

	for _, room in ipairs(floordata) do
		local furniture = room.furniture
		if furniture and type(furniture) == "table" then
			for _, furn in ipairs(furniture) do
				local obj = SpawnFurnitureProp(furn)
				if obj then
					table.insert(SpawnedFloorFurniture[floorKey], obj)
				end
			end
		end
	end

	_FurnitureSpawned = true
end

function QueueSpawnFloorFurniture(buildingName, floor)
	CreateThread(function()
		EnsureRoomsReady(8000)
		CreateFloorFurniture(buildingName, floor, nil)
	end)
end

function CreateRoomPolyzonesFromConfig()
	if not _RoomsReadyBuilt then
		EnsureRoomsReady(8000)
	end

	if not _RoomsReadyBuilt then
		return
	end

	for buildingName, floors in pairs(_RoomsIndexByBuildingFloor) do
		for floor, rooms in pairs(floors) do
			for _, room in ipairs(rooms) do
				local aptId = room.aptId or room.id or room.roomIndex
				aptId = tonumber(aptId) or aptId

				if room.poly and room.poly.center and room.poly.length and room.poly.width and room.poly.options then
					local zoneId = string.format("room-%s-%s", buildingName, tostring(aptId))
					if not _roomPolyZones[zoneId] then
						Polyzone.Create:Box(zoneId, room.poly.center, room.poly.length, room.poly.width, room.poly.options, {
							_roomPoly    = true,
							buildingName = buildingName,
							floor        = floor,
							aptId        = aptId,
						})
						_roomPolyZones[zoneId] = true
					end
				end
			end
		end
	end
end

RegisterNetEvent("Apartment:Client:spawnFk", function(buildingName, floor, floordata)
	CreateFloorFurniture(buildingName, floor, floordata)
end)
