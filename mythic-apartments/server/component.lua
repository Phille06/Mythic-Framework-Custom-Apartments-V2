_requests = {}
_requestors = {}
_raidedApartments = {}
_pendingRaids = {}

AddEventHandler("Apartment:Shared:DependencyUpdate", RetrieveComponents)
function RetrieveComponents()
	Fetch = exports["mythic-base"]:FetchComponent("Fetch")
	Middleware = exports["mythic-base"]:FetchComponent("Middleware")
	Callbacks = exports["mythic-base"]:FetchComponent("Callbacks")
	Logger = exports["mythic-base"]:FetchComponent("Logger")
	Routing = exports["mythic-base"]:FetchComponent("Routing")
	Inventory = exports["mythic-base"]:FetchComponent("Inventory")
	Apartment = exports["mythic-base"]:FetchComponent("Apartment")
	Police = exports["mythic-base"]:FetchComponent("Police")
	Pwnzor = exports["mythic-base"]:FetchComponent("Pwnzor")
	Doors = exports["mythic-base"]:FetchComponent("Doors")
	Phone = exports["mythic-base"]:FetchComponent("Phone")
	Database = exports["mythic-base"]:FetchComponent("Database")
	Chat = exports["mythic-base"]:FetchComponent("Chat")
	Execute = exports["mythic-base"]:FetchComponent("Execute")
	Jobs    = exports["mythic-base"]:FetchComponent("Jobs")
	Banking = exports["mythic-base"]:FetchComponent("Banking")
end

AddEventHandler("Core:Shared:Ready", function()
	exports["mythic-base"]:RequestDependencies("Apartment", {
		"Fetch",
		"Middleware",
		"Callbacks",
		"Logger",
		"Routing",
		"Inventory",
		"Apartment",
		"Police",
		"Pwnzor",
		"Phone",
		"Database",
		"Chat",
		"Execute",
		"Jobs",
		"Banking",
	}, function(error)
		if #error > 0 then
			return
		end
		RetrieveComponents()
		RegisterMiddleware()
		RegisterCallbacks()
		Startup()
		RegisterAdminCommands()
		AddEventHandler('mythic-doors:stateChanged', function(source, doorId, isLocked)
			if not isLocked or not _aptData then return end
			for aptId, apt in ipairs(_aptData) do
				if apt and Doors and Doors:ResolveId(apt.doorId) == doorId then
					if IsApartmentRaided(aptId) then
						EndApartmentRaid(aptId)
					end
					break
				end
			end
		end)
	end)
end)

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["mythic-base"]:RegisterComponent("Apartment", _APTS)
end)

_APTS = {
	Enter = function(self, source, targetType, target, wakeUp)
		local f = false
		local rTarget = target
		if rTarget == -1 then
			local char = Fetch:Source(source):GetData("Character")
			rTarget = char:GetData("SID")
			f = true
		end
		if not f then
			if _requestors[source] ~= nil then
				for k, v in ipairs(_requests[_requestors[source]]) do
					if v.source == source then
						f = true
					end
				end
			end
			if Police:IsInBreach(source, "apartment", rTarget) then
				f = true
			end
		end
		if f then
			Player(source).state.inApartment = {
				type = targetType,
				id = rTarget
			}

			local apt = _aptData[targetType or 1]
			if not apt then
				return false
			end

			local buildingName = apt.buildingName or apt.buildingLabel
			local floor = apt.floor

			if not buildingName or not floor then
				return false
			end

			local routeId = Routing:RequestRouteId(string.format("Apartment:Floor:%s:%s", buildingName, floor), false)

			Pwnzor.Players:TempPosIgnore(source)
			Routing:AddPlayerToRoute(source, routeId)

			GlobalState[string.format("%s:Apartment", source)] = rTarget
			TriggerClientEvent("Apartment:Client:InnerStuff", source, targetType or 1, rTarget, wakeUp)

			local apartment = GlobalState[string.format("Apartment:%s", targetType or 1)]
			if apartment?.coords then
				Player(source).state.tpLocation = {
					x = apartment.coords.x,
					y = apartment.coords.y,
					z = apartment.coords.z,
				}
			end

			return targetType
		end

		return false
	end,

	Exit = function(self, source)
		Routing:RoutePlayerToGlobalRoute(source)
		GlobalState[string.format("%s:Apartment", source)] = nil
		Pwnzor.Players:TempPosIgnore(source)
		Player(source).state.inApartment = nil
		Player(source).state.tpLocation = nil

		return true
	end,

	GetInteriorLocation = function(self, apartment)
		local aptData = GlobalState[string.format("Apartment:%s", apartment or 1)]
		return aptData?.interior?.spawn
	end,

	SpawnInside = function(self, source, cb)
		local char = Fetch:Source(source):GetData("Character")
		if not char then cb(false) return end

		local characterSID = char:GetData("SID")
		local aptId        = GetCharacterApartment(characterSID)

		if not aptId or aptId == 0 then
			UpdateAvailableApartments(true)

			local characterID = char:GetData("ID")
			aptId = GetRandomAvailableApartment()

			if aptId then
				if AssignApartmentToCharacter(aptId, characterID, characterSID) then
					Database.Game:updateOne({
						collection = "characters",
						query  = { _id = characterID },
						update = { ["$set"] = { Apartment = aptId } }
					}, function(success)
						if success then
							char:SetData("Apartment", aptId)
							EnsureCharacterDoorAccess(characterSID, aptId)
							if SendApartmentAssignmentEmail then
								SendApartmentAssignmentEmail(source, aptId, characterSID)
							end
						end
					end)
				else
					aptId = nil
				end
			end
		end

		if aptId and aptId > 0 then
			UpdateAvailableApartments(true)
			cb(Apartment:Enter(source, aptId, -1, true))
		else
			cb(false)
		end
	end,

	Reception = {
		RequestApartment = function(self, source, cb)
			local char = Fetch:Source(source):GetData("Character")
			if not char then
				cb({ success = false, message = "Character not found" })
				return
			end

			local characterSID = char:GetData("SID")
			local characterID  = char:GetData("ID")

			local existingApt = GetCharacterApartment(characterSID)
			local charAptId   = char:GetData("Apartment") or 0

			if existingApt or charAptId > 0 then
				cb({ success = false, message = "You already have an apartment assigned" })
				return
			end

			local aptId = GetRandomAvailableApartment()
			if not aptId then
				cb({ success = false, message = "No apartments available at this time" })
				return
			end

			if not AssignApartmentToCharacter(aptId, characterID, characterSID) then
				cb({ success = false, message = "Failed to assign apartment" })
				return
			end

			Database.Game:updateOne({
				collection = "characters",
				query      = { _id = characterID },
				update     = { ["$set"] = { Apartment = aptId } }
			}, function(success)
				if not success then
					cb({ success = false, message = "Failed to update character" })
					return
				end

				char:SetData("Apartment", aptId)

				local apt          = _aptData[aptId]
				local roomLabel    = apt and apt.roomLabel or aptId
				local buildingLabel = apt and (apt.buildingLabel or apt.buildingName) or "Apartment Building"
				local floor        = apt and apt.floor or "Unknown"

				if EnsureCharacterDoorAccess then
					EnsureCharacterDoorAccess(characterSID, aptId)
				end
				if SendApartmentAssignmentEmail then
					SendApartmentAssignmentEmail(source, aptId, characterSID)
				end

				Logger:Info("Apartments", string.format("Assigned apartment %s (Room %s) to %s %s (%s) via reception", aptId, roomLabel, char:GetData("First"), char:GetData("Last"), characterSID))
				cb({ success = true, apartmentId = aptId, roomLabel = roomLabel, buildingName = buildingLabel, floor = floor })
			end)
		end,

		GetMyRoom = function(self, source)
			local char = Fetch:Source(source):GetData("Character")
			if not char then
				return { success = false, message = "Character not found" }
			end

			local characterSID = char:GetData("SID")
			local aptId        = GetCharacterApartment(characterSID)

			if not aptId and char:GetData("Apartment") and char:GetData("Apartment") > 0 then
				aptId = char:GetData("Apartment")
			end

			if not aptId or aptId == 0 then
				return { success = false, message = "You don't have an apartment assigned" }
			end

			local apt = GlobalState[string.format("Apartment:%s", aptId)]
			if not apt then
				return { success = false, message = "Apartment data not found" }
			end

			return {
				success      = true,
				buildingName = apt.buildingLabel or apt.buildingName or "Apartment Building",
				roomLabel    = apt.roomLabel or aptId,
				floor        = apt.floor or "Unknown",
			}
		end,
	},

	Police = {
		RoomLookup = function(self, source, data)
			local isPolice = (Player(source).state.onDuty == "police")
			if not isPolice or not Jobs.Permissions:HasPermissionInJob(source, 'police', 'PD_RAID') then
				return { success = false, message = "Unauthorized" }
			end

			local targetSID = tonumber(data.sid)
			if not targetSID then
				return { success = false, message = "Invalid State ID" }
			end

			local targetAptId = GetCharacterApartment(targetSID)
			if not targetAptId then
				local targetPlayer = Fetch:CharacterData("SID", targetSID)
				if targetPlayer then
					local targetChar = targetPlayer:GetData("Character")
					if targetChar then
						targetAptId = targetChar:GetData("Apartment")
					end
				end
			end

			if not targetAptId or targetAptId == 0 then
				return { success = false, message = "No apartment found for that State ID" }
			end

			local apt = GlobalState[string.format("Apartment:%s", targetAptId)]
			if not apt then
				return { success = false, message = "Apartment data not found" }
			end

			local char = Fetch:Source(source):GetData("Character")
			Logger:Info("Apartments", string.format("%s %s (%s) performed a police apartment lookup for SID %s - found %s Room %s Floor %s", char:GetData("First"), char:GetData("Last"), char:GetData("SID"), targetSID, apt.buildingLabel or apt.buildingName or "Unknown", apt.roomLabel or targetAptId, apt.floor or "Unknown"))

			return {
				success      = true,
				buildingName = apt.buildingLabel or apt.buildingName or "Apartment Building",
				roomLabel    = apt.roomLabel or targetAptId,
				floor        = apt.floor or "Unknown",
			}
		end,
	},

	GetFloorApartments = function(self, data)
		if not data or not data.buildingName or data.floor == nil then
			return {}
		end

		local floorApartments = {}
		for _, aptId in ipairs(GlobalState["Apartments"] or {}) do
			local apt = GlobalState[string.format("Apartment:%s", aptId)]
			if apt and apt.buildingName == data.buildingName and apt.floor == data.floor then
				local charSID = nil
				for sid, assignedAptId in pairs(_apartmentAssignments or {}) do
					if assignedAptId == aptId then
						charSID = tonumber(sid) or sid
						break
					end
				end
				table.insert(floorApartments, {
					aptId     = aptId,
					unit      = charSID,
					roomLabel = apt.roomLabel or aptId,
				})
			end
		end
		return floorApartments
	end,

	Validate = {
		_ResolveTargetApartment = function(self, targetCharSID)
			local aptId = GetCharacterApartment(targetCharSID)
			if not aptId then
				local targetPlayer = Fetch:CharacterData("SID", targetCharSID)
				if targetPlayer then
					local targetChar = targetPlayer:GetData("Character")
					if targetChar then
						aptId = targetChar:GetData("Apartment")
					end
				end
			end
			return aptId
		end,

		_IsPolicWithRaid = function(self, source)
			return Player(source).state.onDuty == "police"
				and Jobs.Permissions:HasPermissionInJob(source, 'police', 'PD_RAID')
		end,

		Wardrobe = function(self, source, char)
			return char:GetData("SID") == GlobalState[string.format("%s:Apartment", source)]
		end,

		Logout = function(self, source, char)
			return char:GetData("SID") == GlobalState[string.format("%s:Apartment", source)]
		end,

		StartRaid = function(self, source, data, char, cb)
			if not self:_IsPolicWithRaid(source) then cb(false) return end

			local targetCharSID = tonumber(data.unit)
			local targetAptId   = self:_ResolveTargetApartment(targetCharSID)

			if not targetAptId or not _aptData[targetAptId] then cb(false) return end

			if IsPendingRaid(targetAptId) then cb(true) return end

			Logger:Info("Apartments", string.format("%s %s (%s) is requesting a raid on apartment %s (character %s)",
				char:GetData("First"), char:GetData("Last"), char:GetData("SID"), targetAptId, targetCharSID))

			Callbacks:ClientCallback(source, "Police:Breach", {}, function(breached)
				if not breached then
					Logger:Info("Apartments", string.format("%s %s (%s) failed the breach check for apartment %s (character %s)",
						char:GetData("First"), char:GetData("Last"), char:GetData("SID"), targetAptId, targetCharSID))
					cb(false)
					return
				end
				Logger:Info("Apartments", string.format("%s %s (%s) breached apartment %s (character %s) - raid pending",
					char:GetData("First"), char:GetData("Last"), char:GetData("SID"), targetAptId, targetCharSID))
				StartPendingRaid(targetAptId, targetCharSID)
				cb(true)
			end)
		end,

		StopRaid = function(self, source, data)
			if not self:_IsPolicWithRaid(source) then return false end
			if not IsApartmentRaided(data.id) then return false end
			EndApartmentRaid(data.id)
			return true
		end,

		Raid = function(self, source, data)
			if not self:_IsPolicWithRaid(source) then return false end

			local targetCharSID = tonumber(data.unit)
			local targetAptId   = self:_ResolveTargetApartment(targetCharSID)

			if not targetAptId or not _aptData[targetAptId] then return false end
			if _raidedApartments and _raidedApartments[targetAptId] then return true end
			if not IsPendingRaid(targetAptId) then return false end

			StartApartmentRaid(targetAptId, targetCharSID)
			return true
		end,

		Stash = function(self, source, data, char, pState, isMyApartment, cb)
			local isRaid   = false
			local invOwner = char:GetData("SID")
			local invType  = 13

			if data.unit then
				local targetCharSID = tonumber(data.unit)
				local targetAptId   = self:_ResolveTargetApartment(targetCharSID)

				if targetAptId and _raidedApartments and _raidedApartments[targetAptId] then
					if not _aptData[targetAptId] then cb(false) return end
					invType  = (_assignedApartments[targetAptId] and _assignedApartments[targetAptId].invEntity) or (_aptData[targetAptId] and _aptData[targetAptId].invEntity) or 13
					invOwner = targetCharSID
					isRaid   = true
				else
					if Player(source).state.onDuty ~= "police" then cb(false) return end

					local breachOk = not Config.PoliceRaidRequiresBreach
						or (Police and Police.IsInBreach and Police:IsInBreach(source, "apartment", targetCharSID, true))

					if not breachOk or not targetAptId or not _aptData[targetAptId] then cb(false) return end

					StartApartmentRaid(targetAptId, targetCharSID)
					invType  = (_assignedApartments[targetAptId] and _assignedApartments[targetAptId].invEntity) or (_aptData[targetAptId] and _aptData[targetAptId].invEntity) or 13
					invOwner = targetCharSID
					isRaid   = true
				end

			elseif isMyApartment then
				local aptId = char:GetData("Apartment") or 1
				invType = (_assignedApartments[aptId] and _assignedApartments[aptId].invEntity) or (_aptData[aptId] and _aptData[aptId].invEntity) or 13

				if pState.inApartment ~= nil and pState.inApartment.id ~= char:GetData("SID") then
					cb(false)
					return
				end

				invOwner = char:GetData("SID")
			else
				cb(false)
				return
			end

			Callbacks:ClientCallback(source, "Inventory:Compartment:Open", {
				invType = invType,
				owner   = invOwner,
			}, function()
				Inventory:OpenSecondary(source, invType, invOwner, false, false, isRaid)
			end)

			cb(true)
		end,
	},

	Stash = {
		GetTier = function(self, source, cb)
			local char = Fetch:Source(source):GetData("Character")
			if not char then cb(nil) return end

			local characterSID = char:GetData("SID")
			local aptId = GetCharacterApartment(characterSID) or char:GetData("Apartment")

			if not aptId or aptId == 0 then cb(nil) return end

			local invEntity = (_assignedApartments[aptId] and _assignedApartments[aptId].invEntity) or 13
			cb({ invEntity = invEntity, tier = invEntity - 12 })
		end,

		Upgrade = function(self, source, cb)
			local char = Fetch:Source(source):GetData("Character")
			if not char then cb({ success = false, message = "Character not found" }) return end

			local characterSID = char:GetData("SID")
			local aptId = GetCharacterApartment(characterSID) or char:GetData("Apartment")

			if not aptId or aptId == 0 then
				cb({ success = false, message = "You don't have an apartment" })
				return
			end

			local currentInvEntity = (_assignedApartments[aptId] and _assignedApartments[aptId].invEntity) or 13
			local newInvEntity     = currentInvEntity + 1

			if newInvEntity > 15 then
				cb({ success = false, message = "Your stash is already at maximum tier" })
				return
			end

			local cost    = Config.StashUpgradeCosts[currentInvEntity]
			local account = Banking.Accounts:GetPersonal(characterSID)

			if not account then
				cb({ success = false, message = "Bank account not found" })
				return
			end

			if not Banking.Balance:Has(account.Account, cost) then
				cb({ success = false, message = string.format("Insufficient funds ($%s required)", cost) })
				return
			end

			local oldStashName = string.format("%s-%s", characterSID, currentInvEntity)
			local newStashName = string.format("%s-%s", characterSID, newInvEntity)

			-- Close any cached open stash before renaming to prevent ghost items
			if Inventory.ForceClose then
				Inventory:ForceClose(currentInvEntity, characterSID)
			end

			-- MySQL rename must complete before MongoDB update or client notification.
			-- Using update_async (fire-and-forget) caused a race: MongoDB could update
			-- and the client could open the new stash before the row was renamed,
			-- producing an empty stash or ghost items when moving items.
			exports.oxmysql:update("UPDATE inventory SET name = ? WHERE name = ?", { newStashName, oldStashName }, function()
				Database.Game:updateOne({
					collection = "apartment_assignments",
					query  = { apartmentId = aptId, characterSID = characterSID },
					update = { ["$set"] = { invEntity = newInvEntity } }
				}, function(success)
					if not success then
						-- Roll back the MySQL rename
						exports.oxmysql:update("UPDATE inventory SET name = ? WHERE name = ?", { oldStashName, newStashName }, function() end)
						cb({ success = false, message = "Failed to upgrade stash" })
						return
					end

					Banking.Balance:Charge(account.Account, cost, {
						type        = "purchase",
						title       = "Stash Upgrade",
						description = string.format("Upgraded apartment stash to Tier %d", newInvEntity - 12),
					})

					_assignedApartments[aptId].invEntity = newInvEntity

					Logger:Info("Apartments", string.format(
						"%s %s (%s) upgraded apartment %s stash to Tier %d",
						char:GetData("First"), char:GetData("Last"), characterSID, aptId, newInvEntity - 12
					))

					cb({ success = true, tier = newInvEntity - 12 })
				end)
			end)
		end,
	},

	Requests = {
		Get = function(self, source)
			if GlobalState[string.format("%s:Apartment", source)] ~= nil then
				return _requests[GlobalState[string.format("%s:Apartment", source)]]
			else
				return {}
			end
		end,
		Create = function(self, source, target, inZone)
			if source == target then return end

			local char = Fetch:Source(source):GetData("Character")
			local tPlyr = Fetch:CharacterData("SID", target)

			if tPlyr ~= nil then
				local tChar = tPlyr:GetData("Character")

				if tChar ~= nil and string.format("apt-%s", tChar:GetData("Apartment") or 1) == inZone then
					_requests[target] = _requests[target] or {}
					for k, v in ipairs(_requests[target]) do
						if v.source == source then
							return
						end
					end

					_requestors[source] = target
					table.insert(_requests[target], {
						source = source,
						SID = char:GetData("SID"),
						First = char:GetData("First"),
						Last = char:GetData("Last"),
					})
				end
			end
		end,
	},
}
