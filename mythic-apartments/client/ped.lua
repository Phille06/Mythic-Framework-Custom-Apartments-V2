function SetupReceptionPed()
	if not Config.ReceptionPed then return end

	local receptionMenu = {
		{
			text  = "Request Apartment",
			event = "Apartment:Reception:RequestApartment",
			icon  = "house",
			data  = {}
		},
		{
			text  = "Where's My Room?",
			event = "Apartment:Reception:GetMyRoom",
			icon  = "map-location-dot",
			data  = {}
		},
	}

	if Config.ReceptionPoliceActions then
		receptionMenu[#receptionMenu + 1] = {
			text      = "Lookup Apartment",
			event     = "Apartment:Reception:PoliceLookup",
			icon      = "magnifying-glass",
			data      = {},
			isEnabled = function(data)
				if LocalPlayer.state.onDuty ~= "police" then return false end
				if not Jobs.Permissions:HasPermissionInJob('police', 'PD_RAID') then return false end
				return true
			end,
		}
	end

	PedInteraction:Add(
		"apartment_reception",
		Config.ReceptionPed.model,
		vector3(Config.ReceptionPed.coords.x, Config.ReceptionPed.coords.y, Config.ReceptionPed.coords.z),
		Config.ReceptionPed.coords.w or Config.ReceptionPed.coords[4] or 0.0,
		50.0,
		receptionMenu,
		"user",
		Config.ReceptionPed.scenario,
		true,
		nil,
		nil
	)
end
