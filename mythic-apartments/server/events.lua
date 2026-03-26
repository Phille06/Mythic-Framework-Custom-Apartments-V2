RegisterNetEvent("Apartment:Server:StartShowerParticle", function(showerHeadPos, aptId)
	local source = source
	TriggerClientEvent("Apartment:Client:StartShowerParticle", -1, source, showerHeadPos, aptId)
end)

RegisterNetEvent("Apartment:Server:StopShowerParticle", function()
	local source = source
	TriggerClientEvent("Apartment:Client:StopShowerParticle", -1, source)
end)

RegisterNetEvent("Apartment:Server:LeavePoly", function()
    local src = source
    local targetSID = _requestors[src]
    if targetSID ~= nil then
        local reqs = _requests[targetSID]
        if reqs then
            for k, v in ipairs(reqs) do
                if v.source == src then
                    table.remove(reqs, k)
                    _requestors[src] = nil
                    return
                end
            end
        end
    end
end)

AddEventHandler("Characters:Server:CharacterDeleted", function(characterID)
	Database.Game:findOne({
		collection = "characters",
		query = {
			_id = characterID
		},
		options = {
			projection = {
				SID = 1,
				Apartment = 1
			}
		}
	}, function(success, results)
		if success and results and results[1] then
			local charData = results[1]
			local characterSID = charData.SID
			local aptId = GetCharacterApartment(characterSID)
			
			if aptId and aptId > 0 then
				Logger:Info("Apartments", string.format("Releasing apartment %s from deleted character %s", aptId, characterSID))
				ReleaseApartmentAssignment(aptId, characterSID, false)
			end
		end
	end)
end)

RegisterNetEvent("Apartment:Server:ElevatorFloorChanged", function(buildingName, floor)
	local source = source
	
	if not buildingName or floor == nil then
		return
	end
	
	local player = Fetch:Source(source)
	if not player then
		return
	end
	
	local char = player:GetData("Character")
	if not char then
		return
	end
	
	local characterSID = char:GetData("SID")
	local aptId = GetCharacterApartment(characterSID)
	
	
	local elevatorFloors = Config.HotelElevators and Config.HotelElevators[buildingName]
	if not elevatorFloors or not elevatorFloors[floor] then
		return
	end

	local floorConfig = elevatorFloors[floor]
	local bucketReset = floorConfig.bucketReset
	local isApartmentFloor = floorConfig.isApartmentFloor
	
	local playerRoute = Routing:GetPlayerRoute(source)
	local currentApartment = GlobalState[string.format("%s:Apartment", source)]
	
	if bucketReset then
		Routing:RoutePlayerToGlobalRoute(source)
		GlobalState[string.format("%s:Apartment", source)] = nil
		Pwnzor.Players:TempPosIgnore(source)
		Player(source).state.inApartment = nil
		Player(source).state.tpLocation = nil
		
		
		TriggerClientEvent("Apartment:Client:ExitElevator", source)
	elseif isApartmentFloor and aptId and aptId > 0 then
		
		local expectedRouteName = string.format("Apartment:Floor:%s:%s", buildingName, floor)
		local expectedRouteId = Routing:RequestRouteId(expectedRouteName, false)
		
		local currentApartmentState = Player(source).state.inApartment
		local alreadyInApartment = currentApartmentState and currentApartmentState.type == aptId and currentApartmentState.id == characterSID
		
		if playerRoute.route ~= expectedRouteId then
			Player(source).state.inApartment = {
				type = aptId,
				id = characterSID
			}
			Pwnzor.Players:TempPosIgnore(source)
			Routing:AddPlayerToRoute(source, expectedRouteId)
			GlobalState[string.format("%s:Apartment", source)] = characterSID
		end
		
		if not alreadyInApartment then
			TriggerClientEvent("Apartment:Client:InnerStuff", source, aptId, characterSID, false)
		end
	end
end)

RegisterNetEvent("Apartment:Server:LogoutCleanup", function()
	local source = source
	Player(source).state.inApartment = nil
	Player(source).state.tpLocation = nil
	GlobalState[string.format("%s:Apartment", source)] = nil
	local playerRoute = Routing:GetPlayerRoute(source)
	if playerRoute and playerRoute.route then
		Routing:RoutePlayerToGlobalRoute(source)
	end
end)

AddEventHandler("Characters:Created", function(source, charData)
	print("[Apartment] Characters:Created fired for SID:", charData.SID, "ID:", charData.ID)
	if not _aptData or #_aptData == 0 then
		Logger:Warn("Apartments", "Characters:Created called but _aptData is not loaded yet")
		return
	end
	local aptId = GetRandomAvailableApartment()
	print("[Apartment] Random available apartment:", aptId)

	if aptId then
		local assignResult = AssignApartmentToCharacter(aptId, charData.ID, charData.SID)
		print("[Apartment] AssignApartmentToCharacter result:", assignResult)

		if assignResult then
			if Database then
				Database.Game:updateOne({
					collection = "characters",
					query = {
						_id = charData.ID
					},
					update = {
						["$set"] = {
							Apartment = aptId
						}
					}
				}, function(success)
					if success then
						if EnsureCharacterDoorAccess then
							EnsureCharacterDoorAccess(charData.SID, aptId)
						end
						if source and source > 0 then
							if SendApartmentAssignmentEmail then
								SendApartmentAssignmentEmail(source, aptId, charData.SID)
							end
						end
						
						Logger:Info("Apartments", string.format("Assigned apartment %s to new character %s (%s)", aptId, charData.SID, charData.First .. " " .. charData.Last))
					end
				end)
			end
		end
	else
		Logger:Warn("Apartments", string.format("No apartments available for new character %s (%s) - character is homeless", charData.SID, charData.First .. " " .. charData.Last))
	end
end)
