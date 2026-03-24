function RegisterCallbacks()
	Callbacks:RegisterServerCallback("Apartment:Validate", function(source, data, cb)
		local char          = Fetch:Source(source):GetData("Character")
		local pState        = Player(source).state
		local isMyApartment = data.id == GlobalState[string.format("%s:Apartment", source)]

		if not data.id then cb(false) return end

		if data.type == "wardrobe" and isMyApartment then
			cb(Apartment.Validate:Wardrobe(source, char))
		elseif data.type == "logout" and isMyApartment then
			cb(Apartment.Validate:Logout(source, char))
		elseif data.type == "startraid" then
			Apartment.Validate:StartRaid(source, data, char, cb)
		elseif data.type == "stopraid" then
			cb(Apartment.Validate:StopRaid(source, data))
		elseif data.type == "raid" then
			cb(Apartment.Validate:Raid(source, data))
		elseif data.type == "stash" then
			Apartment.Validate:Stash(source, data, char, pState, isMyApartment, cb)
		else
			cb(false)
		end
	end)

	Callbacks:RegisterServerCallback("Apartment:SpawnInside", function(source, data, cb)
		Apartment:SpawnInside(source, cb)
	end)

	Callbacks:RegisterServerCallback("Apartment:Enter", function(source, data, cb)
		cb(Apartment:Enter(source, data.tier, data.id))
	end)

	Callbacks:RegisterServerCallback("Apartment:Exit", function(source, data, cb)
		cb(Apartment:Exit(source))
	end)

	Callbacks:RegisterServerCallback("Apartment:GetVisitRequests", function(source, data, cb)
		cb(Apartment.Requests:Get(source))
	end)

	Callbacks:RegisterServerCallback("Apartment:Visit", function(source, data, cb)
		cb(Apartment:Enter(source, data.tier, data.id))
	end)

	
	Callbacks:RegisterServerCallback("Apartment:RequestApartment", function(source, data, cb)
		Apartment.Reception:RequestApartment(source, cb)
	end)

	Callbacks:RegisterServerCallback("Apartment:GetMyRoom", function(source, data, cb)
		cb(Apartment.Reception:GetMyRoom(source))
	end)

	Callbacks:RegisterServerCallback("Apartment:ReceptionLookup", function(source, data, cb)
		cb(Apartment.Police:RoomLookup(source, data))
	end)

	Callbacks:RegisterServerCallback("Apartment:GetStashTier", function(source, data, cb)
		Apartment.Stash:GetTier(source, cb)
	end)

	Callbacks:RegisterServerCallback("Apartment:UpgradeStash", function(source, data, cb)
		Apartment.Stash:Upgrade(source, cb)
	end)

	Callbacks:RegisterServerCallback("Apartment:GetFloorApartments", function(source, data, cb)
		cb(Apartment:GetFloorApartments(data))
	end)
end
