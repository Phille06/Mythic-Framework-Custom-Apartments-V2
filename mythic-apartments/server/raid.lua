function StartPendingRaid(apartmentId, characterSID)
	if not apartmentId or not characterSID then
		return false
	end
	_pendingRaids[apartmentId] = {
		characterSID = characterSID,
		expiresAt    = os.time() + 600,
	}
	GlobalState[string.format("Apartment:RaidPending:%s", apartmentId)] = true
	TriggerClientEvent("Apartment:Client:RaidPendingChanged", -1, apartmentId, true)
	return true
end

function IsPendingRaid(apartmentId)
	if not _pendingRaids or not _pendingRaids[apartmentId] then
		return false
	end
	if _pendingRaids[apartmentId].expiresAt <= os.time() then
		_pendingRaids[apartmentId] = nil
		GlobalState[string.format("Apartment:RaidPending:%s", apartmentId)] = nil
		TriggerClientEvent("Apartment:Client:RaidPendingChanged", -1, apartmentId, false)
		return false
	end
	return true
end

function StartApartmentRaid(apartmentId, characterSID)
	if not apartmentId or not characterSID then
		return false
	end

	local apt = _aptData[apartmentId]
	if not apt or not apt.doorId or apt.doorId == nil then
		return false
	end

	if Doors:Exists(apt.doorId) then
		Doors:SetLock(apt.doorId, false)
	end

	if not _raidedApartments then
		_raidedApartments = {}
	end
	_raidedApartments[apartmentId] = {
		characterSID = characterSID,
		raidedAt     = os.time(),
		doorId       = apt.doorId
	}

	GlobalState[string.format("Apartment:Raid:%s", apartmentId)] = true
	_pendingRaids[apartmentId] = nil
	GlobalState[string.format("Apartment:RaidPending:%s", apartmentId)] = nil
	TriggerClientEvent("Apartment:Client:RaidPendingChanged", -1, apartmentId, false)
	TriggerClientEvent("Apartment:Client:RaidStateChanged", -1, apartmentId, true, characterSID)

	local targetPlayer = Fetch:CharacterData("SID", characterSID)
	if targetPlayer then
		Logger:Info("Apartments", string.format("Apartment %s is now being raided - %s %s (%s) door unlocked", apartmentId, targetPlayer:GetData("Character"):GetData("First"), targetPlayer:GetData("Character"):GetData("Last"), characterSID))
	else
		Logger:Info("Apartments", string.format("Apartment %s is now being raided - (character %s) door unlocked", apartmentId, characterSID))
	end

	return true
end

function EndApartmentRaid(apartmentId)
	if not apartmentId or not _raidedApartments or not _raidedApartments[apartmentId] then
		return false
	end

	local raidData = _raidedApartments[apartmentId]
	local doorId   = raidData.doorId

	_raidedApartments[apartmentId] = nil
	GlobalState[string.format("Apartment:Raid:%s", apartmentId)] = nil

	if doorId then
		if Doors:Exists(doorId) then
			Doors:SetLock(doorId, true)
		end
	end

	TriggerClientEvent("Apartment:Client:RaidStateChanged", -1, apartmentId, false)

	local targetPlayer = Fetch:CharacterData("SID", raidData.characterSID)
	if targetPlayer then
		Logger:Info("Apartments", string.format("Apartment %s raid ended - %s %s (%s) door locked", apartmentId, targetPlayer:GetData("Character"):GetData("First"), targetPlayer:GetData("Character"):GetData("Last"), raidData.characterSID))
	else
		Logger:Info("Apartments", string.format("Apartment %s raid ended - (character %s) door locked", apartmentId, raidData.characterSID))
	end

	return true
end

function IsApartmentRaided(apartmentId)
	return _raidedApartments and _raidedApartments[apartmentId] ~= nil
end
