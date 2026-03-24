_pzs = {}
_inPoly = false
_menu = false
_currentElevator = nil
_currentFloor = nil
_currentWardrobe = nil
_currentShower = nil
_currentElevatorBuilding = nil
_currentElevatorFloor = nil
_floorRaidTargets = {}
_apartmentTargetsSetup  = {}
_apartmentPolyzonesSetup = {}
SpawnedFloorFurniture = {}
CurrentFloorKey = nil
_FurnitureSpawned = false
_RoomsReadyBuilt = false
_RoomsIndexByBuildingFloor = {}
_RoomMetaByAptId = {}

AddEventHandler("Apartment:Shared:DependencyUpdate", RetrieveComponents)
function RetrieveComponents()
	Callbacks    = exports["mythic-base"]:FetchComponent("Callbacks")
	Utils        = exports["mythic-base"]:FetchComponent("Utils")
	Blips        = exports["mythic-base"]:FetchComponent("Blips")
	Notification = exports["mythic-base"]:FetchComponent("Notification")
	Action       = exports["mythic-base"]:FetchComponent("Action")
	Polyzone     = exports["mythic-base"]:FetchComponent("Polyzone")
	Ped          = exports["mythic-base"]:FetchComponent("Ped")
	Sounds       = exports["mythic-base"]:FetchComponent("Sounds")
	Targeting    = exports["mythic-base"]:FetchComponent("Targeting")
	Interaction  = exports["mythic-base"]:FetchComponent("Interaction")
	Action       = exports["mythic-base"]:FetchComponent("Action")
	ListMenu     = exports["mythic-base"]:FetchComponent("ListMenu")
	Input        = exports["mythic-base"]:FetchComponent("Input")
	Apartment    = exports["mythic-base"]:FetchComponent("Apartment")
	Characters   = exports["mythic-base"]:FetchComponent("Characters")
	Wardrobe     = exports["mythic-base"]:FetchComponent("Wardrobe")
	Sync         = exports["mythic-base"]:FetchComponent("Sync")
	Animations   = exports["mythic-base"]:FetchComponent("Animations")
	Progress     = exports["mythic-base"]:FetchComponent("Progress")
	Minigame     = exports["mythic-base"]:FetchComponent("Minigame")
	PedInteraction = exports["mythic-base"]:FetchComponent("PedInteraction")
	Jobs        = exports["mythic-base"]:FetchComponent("Jobs")
	Confirm     = exports["mythic-base"]:FetchComponent("Confirm")
end
 
AddEventHandler("Core:Shared:Ready", function()
	exports["mythic-base"]:RequestDependencies("Apartment", {
		"Callbacks",
		"Utils",
		"Blips",
		"Notification",
		"Action",
		"Polyzone",
		"Ped",
		"Sounds",
		"Targeting",
		"Interaction",
		"Action",
		"ListMenu",
		"Input",
		"Apartment",
		"Characters",
		"Wardrobe",
		"Sync",
		"Animations",
		"Progress",
		"Minigame",
		"PedInteraction",
		"Jobs",
		"Confirm",
	}, function(error)
		if #error > 0 then
			return
		end
		RetrieveComponents()
		CreateElevatorPolyzones()
		SetupWorldZones()
		SetupReceptionPed()
		CreateThread(function()
			Wait(5000)
			EnsureRoomsReady(8000)
			CreateRoomPolyzonesFromConfig()
		end)
	end)
end)

AddEventHandler("Proxy:Shared:RegisterReady", function()
	exports["mythic-base"]:RegisterComponent("Apartment", _APTS)
end)

_APTS = {
	Enter = function(self, tier, id)
		Callbacks:ServerCallback("Apartment:Enter", {
			id   = id or -1,
			tier = tier,
		}, function(s)
			if s then
				Sounds.Play:One("door_open.ogg", 0.15)
			end
		end)
	end,

	Exit = function(self)
		local apartmentId = GlobalState[string.format("%s:Apartment", LocalPlayer.state.ID)]
		local p = GlobalState[string.format("Apartment:%s", LocalPlayer.state.inApartment.type)]

		if not p then return end

		Callbacks:ServerCallback("Apartment:Exit", {}, function()
			TriggerEvent("Interiors:Exit")
			Sync:Start()

			Sounds.Play:One("door_close.ogg", 0.3)

			for k, v in pairs(p.interior.locations) do
				Targeting.Zones:RemoveZone(string.format("apt-%s-%s", k, LocalPlayer.state.inApartment.type))
			end
			Targeting.Zones:RemoveZone(string.format("apt-%s-raid", LocalPlayer.state.inApartment.type))

			if p.interior.locations.wardrobe then
				Polyzone:Remove(string.format("apt-%s-wardrobe", LocalPlayer.state.inApartment.type))
			end
			if p.interior.locations.shower then
				Polyzone:Remove(string.format("apt-%s-shower", LocalPlayer.state.inApartment.type))
			end

			local exitAptId = LocalPlayer.state.inApartment.type
			local exitUnit  = LocalPlayer.state.inApartment.id
			if exitAptId and exitUnit then
				local exitKey = string.format("%s_%s", exitAptId, exitUnit)
				_apartmentTargetsSetup[exitKey]   = nil
				_apartmentPolyzonesSetup[exitKey] = nil
			end

			_currentWardrobe         = nil
			_currentShower           = nil
			_currentFloor            = nil
			_currentElevator         = nil
			_currentElevatorBuilding = nil
			_currentElevatorFloor    = nil
			Action:Hide()

			ClearFloorFurniture()

			Targeting.Zones:Refresh()
		end)
	end,

	GetNearApartment = function(self)
		if _inPoly and _inPoly.id and _pzs[_inPoly.id] and _pzs[_inPoly.id].id then
			return GlobalState[string.format("Apartment:%s", _pzs[_inPoly.id].id)]
		end
		return nil
	end,

	Extras = {
		Stash = function(self)
			Callbacks:ServerCallback("Apartment:Validate", {
				id   = GlobalState[string.format("%s:Apartment", LocalPlayer.state.ID)],
				type = "stash",
			})
		end,

		Wardrobe = function(self)
			Callbacks:ServerCallback("Apartment:Validate", {
				id   = GlobalState[string.format("%s:Apartment", LocalPlayer.state.ID)],
				type = "wardrobe",
			}, function(state)
				if state then
					Wardrobe:Show()
				end
			end)
		end,

		Logout = function(self)
			Callbacks:ServerCallback("Apartment:Validate", {
				id   = GlobalState[string.format("%s:Apartment", LocalPlayer.state.ID)],
				type = "logout",
			}, function(state)
				if state then
					Characters:Logout()
				end
			end)
		end,
	},

	Stash = {
		Upgrade = function(self)
			Callbacks:ServerCallback("Apartment:GetStashTier", {}, function(info)
				if not info then
					Notification:Error("You don't have an apartment")
					return
				end

				local nextTier = info.tier + 1
				if nextTier > 3 then
					Notification:Error("Your stash is already at maximum tier")
					return
				end

				local cost = Config.StashUpgradeCosts[info.invEntity]

				Confirm:Show(
					"Confirm Stash Upgrade",
					{
						yes = "Apartment:Stash:ConfirmUpgrade",
						no  = "Apartment:Stash:CancelUpgrade",
					},
					string.format("Are you sure you want to upgrade your stash to Tier %d for $%s? This will be charged to your bank account.", nextTier, cost)
				)
			end)
		end,

		ConfirmUpgrade = function(self)
			Callbacks:ServerCallback("Apartment:UpgradeStash", {}, function(result)
				if result.success then
					Notification:Success(string.format("Stash upgraded to Tier %d", result.tier))
				else
					Notification:Error(result.message or "Failed to upgrade stash")
				end
			end)
		end,
	},

	Reception = {
		RequestApartment = function(self)
			if not LocalPlayer.state.Character then return end
			local char  = LocalPlayer.state.Character
			local aptId = char:GetData("Apartment") or 0
			if aptId > 0 then
				Notification:Error("You already have an apartment assigned")
				return
			end
			Callbacks:ServerCallback("Apartment:RequestApartment", {}, function(result)
				if result.success then
					local displayLabel = result.roomLabel or result.apartmentId
					local buildingName = result.buildingName or "Apartment Building"
					Notification:Success(string.format("You have been assigned Room %s at %s", displayLabel, buildingName))
					char:SetData("Apartment", result.apartmentId)
				else
					Notification:Error(result.message or "Failed to request apartment")
				end
			end)
		end,

		GetMyRoom = function(self)
			if not LocalPlayer.state.Character then return end
			Callbacks:ServerCallback("Apartment:GetMyRoom", {}, function(result)
				if result.success then
					Notification:Info(string.format("Your room is %s, Room %s on Floor %s", result.buildingName, result.roomLabel, result.floor))
				else
					Notification:Error(result.message or "Unable to find your room information")
				end
			end)
		end,
	},

	Police = {
		RoomLookup = function(self)
			Input:Show("Police Lookup", "Suspect State ID", {
				{
					id      = "sid",
					type    = "number",
					options = {
						inputProps = { maxLength = 6 },
					},
				},
			}, "Apartment:Reception:DoPoliceLookup", nil)
		end,

		DoRoomLookup = function(self, values)
			if not values or not values.sid then return end
			Callbacks:ServerCallback("Apartment:ReceptionLookup", { sid = values.sid }, function(result)
				if result.success then
					Notification:Info(string.format("SID %s: %s, Room %s on Floor %s", values.sid, result.buildingName, result.roomLabel, result.floor))
				else
					Notification:Error(result.message or "No apartment found")
				end
			end)
		end,
	},
}