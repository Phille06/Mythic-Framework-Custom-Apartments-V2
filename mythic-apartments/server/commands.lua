function RegisterAdminCommands()
	Chat:RegisterAdminCommand("resetraids", function(source, args, rawCommand)
		local toReset = {}

		for aptId, _ in pairs(_raidedApartments) do
			table.insert(toReset, aptId)
		end
		for aptId, _ in pairs(_pendingRaids) do
			table.insert(toReset, aptId)
		end

		for _, aptId in ipairs(toReset) do
			local apt = _aptData[aptId]
			if apt and apt.doorId and Doors:Exists(apt.doorId) then
				Doors:SetLock(apt.doorId, true)
			end
			_raidedApartments[aptId] = nil
			_pendingRaids[aptId]     = nil
			GlobalState[string.format("Apartment:Raid:%s",        aptId)] = nil
			GlobalState[string.format("Apartment:RaidPending:%s", aptId)] = nil
			TriggerClientEvent("Apartment:Client:RaidStateChanged",   -1, aptId, false)
			TriggerClientEvent("Apartment:Client:RaidPendingChanged", -1, aptId, false)
		end

		local msg = string.format("Reset all raids (%d cleared)", #toReset)
		Logger:Info("Apartments", string.format("Admin %s %s", tostring(source), msg))
		Execute:Client(source, "Notification", "Success", msg)
	end, {
		help = "Reset all active and pending apartment raids",
		params = {},
	}, -1)

	Chat:RegisterAdminCommand("checkraids", function(source, args, rawCommand)
		local activeCount = 0
		local pendingCount = 0

		for aptId, data in pairs(_raidedApartments) do
			local apt = _aptData[aptId]
			local roomLabel = apt and apt.roomLabel or tostring(aptId)
			local msg = string.format("[ACTIVE] Apt %s (%s) - charSID: %s, since: %s", tostring(aptId), roomLabel, tostring(data.characterSID), os.date("%H:%M:%S", data.raidedAt))
			Logger:Info("Apartments", msg)
			Execute:Client(source, "Notification", "Info", msg)
			activeCount = activeCount + 1
		end

		for aptId, data in pairs(_pendingRaids) do
			local apt = _aptData[aptId]
			local roomLabel = apt and apt.roomLabel or tostring(aptId)
			local remaining = data.expiresAt - os.time()
			local msg = string.format("[PENDING] Apt %s (%s) - charSID: %s, expires in: %ds", tostring(aptId), roomLabel, tostring(data.characterSID), remaining)
			Logger:Info("Apartments", msg)
			Execute:Client(source, "Notification", "Info", msg)
			pendingCount = pendingCount + 1
		end

		local line
		if activeCount == 0 and pendingCount == 0 then
			line = "No active or pending raids."
		else
			line = string.format("Raids: %d active, %d pending", activeCount, pendingCount)
		end
		Logger:Info("Apartments", line)
		Execute:Client(source, "Notification", "Success", line)
	end, {
		help = "List all active and pending apartment raids",
		params = {},
	}, -1)
end
