function SetupApartmentTargets(aptId, unit)
	local p = GlobalState[string.format("Apartment:%s", aptId)]
	if not p or not p.interior then
		return
	end

	local key = string.format("%s_%s", aptId, unit)

	local needPolyzones = not _apartmentPolyzonesSetup[key]
	local needTargets   = not _apartmentTargetsSetup[key]

	if not needTargets and not needPolyzones then
		return
	end

	if p.interior.locations.logout then
		Targeting.Zones:AddBox(
			string.format("apt-%s-logout", aptId),
			"bed",
			p.interior.locations.logout.coords,
			p.interior.locations.logout.length,
			p.interior.locations.logout.width,
			p.interior.locations.logout.options,
			{
				{
					icon      = "bed",
					text      = "Switch Characters",
					event     = "Apartment:Client:Logout",
					data      = unit,
					isEnabled = function(data)
						return unit == LocalPlayer.state.Character:GetData("SID")
					end,
				},
			},
			3.0,
			true
		)
	end

	if needPolyzones and p.interior.locations.wardrobe then
		Polyzone.Create:Box(
			string.format("apt-%s-wardrobe", aptId),
			p.interior.locations.wardrobe.coords,
			p.interior.locations.wardrobe.length,
			p.interior.locations.wardrobe.width,
			p.interior.locations.wardrobe.options,
			{ aptId = aptId, unit = unit, type = "wardrobe" }
		)
	end

	if needPolyzones and p.interior.locations.shower then
		Polyzone.Create:Box(
			string.format("apt-%s-shower", aptId),
			p.interior.locations.shower.coords,
			p.interior.locations.shower.length,
			p.interior.locations.shower.width,
			p.interior.locations.shower.options,
			{ aptId = aptId, unit = unit, type = "shower" }
		)
	end

	if p.interior.locations.stash then
		Targeting.Zones:AddBox(
			string.format("apt-%s-stash", aptId),
			"toolbox",
			p.interior.locations.stash.coords,
			p.interior.locations.stash.length,
			p.interior.locations.stash.width,
			p.interior.locations.stash.options,
			{
				{
					icon      = "toolbox",
					text      = "Stash",
					event     = "Apartment:Client:Stash",
					data      = unit,
					isEnabled = function(data)
						local char = LocalPlayer.state.Character
						if not char then return false end
						return unit == char:GetData("SID")
					end,
				},
				{
					icon      = "arrow-up",
					text      = "Upgrade Stash",
					event     = "Apartment:Client:UpgradeStash",
					data      = unit,
					isEnabled = function(data)
						local char = LocalPlayer.state.Character
						if not char then return false end
						return unit == char:GetData("SID")
					end,
				},
				{
					icon      = "shield-halved",
					text      = "Raid Stash",
					event     = "Apartment:Client:RaidStash",
					data      = { aptId = aptId, unit = unit },
					isEnabled = function(data)
						if LocalPlayer.state.onDuty ~= "police" then return false end
						if not Jobs.Permissions:HasPermissionInJob('police', 'PD_RAID') then return false end
						return GlobalState[string.format("Apartment:Raid:%s", aptId)] == true
					end,
				},
			},
			3.0,
			true
		)
	end

	if needTargets   then _apartmentTargetsSetup[key]   = true end
	if needPolyzones then _apartmentPolyzonesSetup[key] = true end

	Targeting.Zones:Refresh()
end
