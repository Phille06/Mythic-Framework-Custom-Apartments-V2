RegisterNetEvent("Characters:Client:Spawn")
AddEventHandler("Characters:Client:Spawn", function()
	local buildingBlips = {}

	for k, v in ipairs(GlobalState["Apartments"]) do
		local aptId = string.format("apt-%s", v)
		local apt   = GlobalState[string.format("Apartment:%s", v)]

		Polyzone.Create:Box(aptId, apt.coords, apt.length, apt.width, apt.options, {
			tier = k
		})

		if apt.buildingName and not buildingBlips[apt.buildingName] then
			local buildingLabel = apt.buildingLabel or apt.buildingName
			Blips:Add("apt-building-" .. apt.buildingName, buildingLabel, apt.coords, 475, 25)
			buildingBlips[apt.buildingName] = true
		end

		_pzs[aptId] = {
			name = apt.name,
			id   = apt.id,
		}
	end
end)