function LoadApartmentAssignments()
	local thirtyDaysAgo = os.time() * 1000 - (30 * 24 * 60 * 60 * 1000) 
	
	Database.Game:find({
		collection = "apartment_assignments",
		query = {}
	}, function(success, assignments)
		if not success then
			Logger:Warn("Apartments", "Failed to load apartment assignments")
			UpdateAvailableApartments()
			return
		end
		
		_assignedApartments = {}
		_apartmentAssignments = {}
		
		if not assignments or #assignments == 0 then
			UpdateAvailableApartments()
			local availableCount = #_availableApartments
			Logger:Info("Apartments", string.format("Loaded assignments: ^2%d^7 available, ^3%d^7 assigned", availableCount, 0))
			return
		end
		
		for _, assignment in ipairs(assignments) do
			local p = promise.new()
			Database.Game:findOne({
				collection = "characters",
				query = {
					SID = assignment.characterSID
				},
				options = {
					projection = {
						LastPlayed = 1,
						SID = 1
					}
				}
			}, function(charSuccess, charResults)
				if charSuccess and charResults then
					local lastPlayed = charResults.LastPlayed
					if lastPlayed and lastPlayed ~= -1 and lastPlayed < thirtyDaysAgo then
						ReleaseApartmentAssignment(assignment.apartmentId, assignment.characterSID, true)
						p:resolve(false)
					else
						
					_assignedApartments[assignment.apartmentId] = {
						characterSID = assignment.characterSID,
						characterID = assignment.characterID,
						assignedAt = assignment.assignedAt,
						invEntity = assignment.invEntity or 13
					}
					
					local charSID = assignment.characterSID
					_apartmentAssignments[charSID] = assignment.apartmentId
					_apartmentAssignments[tostring(charSID)] = assignment.apartmentId
					if tonumber(charSID) then
						_apartmentAssignments[tonumber(charSID)] = assignment.apartmentId
					end

					p:resolve(true)
					end
				else
					
					ReleaseApartmentAssignment(assignment.apartmentId, assignment.characterSID, true)
					p:resolve(false)
				end
			end)
			Citizen.Await(p)
		end
		
		UpdateAvailableApartments()
		
		local availableCount = #_availableApartments
		local assignedCount = 0
		for _ in pairs(_assignedApartments) do
			assignedCount = assignedCount + 1
		end
		Logger:Info("Apartments", string.format("Loaded assignments: ^2%d^7 available, ^3%d^7 assigned", availableCount, assignedCount))
	end)
end

function UpdateAvailableApartments(showDebug)
	_availableApartments = {}
	
	if not _aptData then
		return
	end
	
	if not _assignedApartments then
		_assignedApartments = {}
	end
	
	
	local localAssignedCount = 0
	for _ in pairs(_assignedApartments) do
		localAssignedCount = localAssignedCount + 1
	end
	
	local dbAssignedAptIds = {}
	if showDebug then
		local p = promise.new()
		Database.Game:find({
			collection = "apartment_assignments",
			query = {}
		}, function(success, assignments)
			if success and assignments then
				local dbAssignedCount = #assignments
				
				for _, assignment in ipairs(assignments) do
					if assignment.apartmentId then
						dbAssignedAptIds[assignment.apartmentId] = true
					end
				end
			end
			p:resolve(true)
		end)
		Citizen.Await(p)
	end
	
	local assignedAptIds = {}
	if showDebug and next(dbAssignedAptIds) ~= nil then
		
		local dbCount = 0
		for _ in pairs(dbAssignedAptIds) do
			dbCount = dbCount + 1
		end
		if dbCount ~= localAssignedCount then
			
			_assignedApartments = {}
			_apartmentAssignments = {}
			
			local p2 = promise.new()
			Database.Game:find({
				collection = "apartment_assignments",
				query = {}
			}, function(success, assignments)
				if success and assignments then
					for _, assignment in ipairs(assignments) do
						if assignment.apartmentId and assignment.characterSID then
							_assignedApartments[assignment.apartmentId] = {
								characterSID = assignment.characterSID,
								characterID = assignment.characterID,
								assignedAt = assignment.assignedAt or (os.time() * 1000),
								invEntity = assignment.invEntity or 13
							}
							local charSID = assignment.characterSID
							_apartmentAssignments[charSID] = assignment.apartmentId
							_apartmentAssignments[tostring(charSID)] = assignment.apartmentId
							if tonumber(charSID) then
								_apartmentAssignments[tonumber(charSID)] = assignment.apartmentId
							end
						end
					end
				end
				p2:resolve(true)
			end)
			Citizen.Await(p2)
			
			assignedAptIds = dbAssignedAptIds
		else
			for aptId, _ in pairs(_assignedApartments) do
				assignedAptIds[aptId] = true
			end
		end
	else
		for aptId, _ in pairs(_assignedApartments) do
			assignedAptIds[aptId] = true
		end
	end
	
	for _, aptData in ipairs(_aptData) do
		if aptData and aptData.id then
			if not assignedAptIds[aptData.id] then
			table.insert(_availableApartments, aptData.id)
			end
		end
	end
	
	GlobalState["AvailableApartments"] = _availableApartments
end

function AssignApartmentToCharacter(apartmentId, characterID, characterSID)
	if _assignedApartments[apartmentId] then
		return false 
	end
	
	if _apartmentAssignments[characterSID] then
		return false 
	end
	
	local p = promise.new()
	Database.Game:insertOne({
		collection = "apartment_assignments",
		document = {
			apartmentId = apartmentId,
			characterID = characterID,
			characterSID = characterSID,
			assignedAt = os.time() * 1000,
			invEntity = 13
		}
	}, function(success)
		if success then
			_assignedApartments[apartmentId] = {
				characterSID = characterSID,
				characterID = characterID,
				assignedAt = os.time() * 1000,
				invEntity = 13
			}
			_apartmentAssignments[characterSID] = apartmentId
			UpdateAvailableApartments()
			p:resolve(true)
		else
			p:resolve(false)
		end
	end)
	
	return Citizen.Await(p)
end

function ReleaseApartmentAssignment(apartmentId, characterSID, silent)
	if not _assignedApartments[apartmentId] then
		return false
	end

	local assignment = _assignedApartments[apartmentId]
	local characterID = assignment and assignment.characterID
	
	if RemoveCharacterDoorAccess then
		RemoveCharacterDoorAccess(characterSID, apartmentId)
	end
	
	local invType = (_assignedApartments[apartmentId] and _assignedApartments[apartmentId].invEntity) or (_aptData[apartmentId] and _aptData[apartmentId].invEntity) or 13
	
	local stashName = string.format("%s-%s", characterSID, invType)
	exports.oxmysql:update_async("DELETE FROM inventory WHERE name = ?", { stashName })
	Logger:Info("Apartments", string.format("Stash cleared for apartment %s (character %s)", apartmentId, characterSID))
	
	Database.Game:delete({
		collection = "apartment_assignments",
		query = {
			apartmentId = apartmentId,
			characterSID = characterSID
		}
	}, function(success)
		if success then
			_assignedApartments[apartmentId] = nil
			_apartmentAssignments[characterSID] = nil
			_apartmentAssignments[tostring(characterSID)] = nil
			if tonumber(characterSID) then
				_apartmentAssignments[tonumber(characterSID)] = nil
			end
			
			if characterID then
				Database.Game:updateOne({
					collection = "characters",
					query = {
						_id = characterID
					},
					update = {
						["$set"] = {
							Apartment = 0
						}
					}
				}, function(charUpdateSuccess)
					if charUpdateSuccess then
						Logger:Info("Apartments", string.format("Cleared apartment %s from character %s (ID: %s) database record", apartmentId, characterSID, tostring(characterID)))
					end
				end)
			end
			
			
			UpdateAvailableApartments()
			
			if not silent then
				Logger:Info("Apartments", string.format("Released apartment %s from character %s - now available for assignment", apartmentId, characterSID))
			end
		end
	end)
	
	return true
end

function GetCharacterApartment(characterSID)
	if _apartmentAssignments then
		return _apartmentAssignments[characterSID]
			or _apartmentAssignments[tonumber(characterSID)]
			or _apartmentAssignments[tostring(characterSID)]
	end
	return nil
end

function EnsureCharacterDoorAccess(characterSID, apartmentId)
	if not characterSID or not apartmentId then
		return false
	end

	local apt = _aptData[apartmentId]
	if not apt or not apt.doorId or apt.doorId == nil then
		return false
	end

	if not Doors or not Doors:Exists(apt.doorId) then
		return false
	end

	Doors:AddCharacterAccess(apt.doorId, characterSID)

	local char = Fetch:CharacterData("SID", characterSID):GetData("Character")
	Logger:Info("Apartments", string.format("Ensured door access for %s %s (%s) on apartment %s (door %s)", char:GetData("First"), char:GetData("Last"), characterSID, apartmentId, tostring(apt.doorId)))

	return true
end

function RemoveCharacterDoorAccess(characterSID, apartmentId)
	if not characterSID or not apartmentId then
		return false
	end

	local apt = _aptData[apartmentId]
	if not apt or not apt.doorId or apt.doorId == nil then
		return false
	end

	if not Doors or not Doors:Exists(apt.doorId) then
		return false
	end

	Doors:RemoveCharacterAccess(apt.doorId, characterSID)

	Logger:Info("Apartments", string.format("Removed door access for character %s on apartment %s (door %s)", characterSID, apartmentId, tostring(apt.doorId)))

	return true
end

function SendApartmentAssignmentEmail(source, apartmentId, characterSID)
	if not source or source <= 0 or not apartmentId then
		return false
	end

	local apt = _aptData[apartmentId]
	if not apt then
		return false
	end

	local roomLabel    = apt.roomLabel or apartmentId
	local buildingLabel = apt.buildingLabel or apt.buildingName or "Apartment Building"
	local floor        = apt.floor or "Unknown"

	local subject = "Apartment Assignment Confirmation"
	local body = string.format(
		"Dear Resident,\n\n" ..
		"We are pleased to inform you that your apartment has been assigned.\n\n" ..
		"Apartment Details:\n" ..
		"Building: %s\n" ..
		"Room Number: %s\n" ..
		"Floor: %s\n\n" ..
		"Your apartment is now ready for you to move in. You can access your apartment using the elevator system.\n\n" ..
		"If you have any questions or concerns, please contact the building management.\n\n" ..
		"Thank you for choosing our apartments.\n\n" ..
		"Best regards,\n" ..
		"Apartment Management",
		buildingLabel,
		roomLabel,
		floor
	)

	Phone.Email:Send(source, "apartments@management.gov", os.time() * 1000, subject, body)
	return true
end

function GetApartmentByRoomId(roomId)
	return _aptDataByRoomId[roomId]
end

function GetRandomAvailableApartment()
	if _availableApartments and #_availableApartments > 0 then
		local randomIndex = math.random(1, #_availableApartments)
		local aptId = _availableApartments[randomIndex]
		return aptId
	end
	return nil 
end

function IsApartmentAvailable(apartmentId)
	return not _assignedApartments[apartmentId]
end