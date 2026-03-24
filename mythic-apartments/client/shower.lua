local _isShowering = false
local _showerParticle = nil
local _showerParticles = {}

local function LoadPtfxAsset(assetName)
	if not HasNamedPtfxAssetLoaded(assetName) then
		RequestNamedPtfxAsset(assetName)
		while not HasNamedPtfxAssetLoaded(assetName) do
			Wait(1)
		end
	end
end

local function StartShowerParticle(showerHeadPos, aptId)
	LoadPtfxAsset("core")

	UseParticleFxAssetNextCall("core")
	_showerParticle = StartParticleFxLoopedAtCoord(
		"ent_sht_steam",
		showerHeadPos.x,
		showerHeadPos.y,
		showerHeadPos.z,
		-180.0, 0.0, 0.0,
		1.0,
		false, false, false
	)

	TriggerServerEvent("Apartment:Server:StartShowerParticle", showerHeadPos, aptId)
end

local function StopShowerParticle()
	if _showerParticle then
		StopParticleFxLooped(_showerParticle, false)
		_showerParticle = nil
	end
	TriggerServerEvent("Apartment:Server:StopShowerParticle")
end

RegisterNetEvent("Apartment:Client:StartShowerParticle", function(source, showerHeadPos, aptId)
	if source == LocalPlayer.state.ID then
		return
	end

	LoadPtfxAsset("core")
	UseParticleFxAssetNextCall("core")
	local particle = StartParticleFxLoopedAtCoord(
		"ent_sht_steam",
		showerHeadPos.x,
		showerHeadPos.y,
		showerHeadPos.z,
		-180.0, 0.0, 0.0,
		1.0,
		false, false, false
	)

	_showerParticles[source] = particle
end)

RegisterNetEvent("Apartment:Client:StopShowerParticle", function(source)
	if _showerParticles[source] then
		StopParticleFxLooped(_showerParticles[source], false)
		_showerParticles[source] = nil
	end
end)

local function PlayShowerAnimation()
	local playerPed = LocalPlayer.state.ped
	local animDict  = "anim@mp_yacht@shower@male@"

	if not HasAnimDictLoaded(animDict) then
		RequestAnimDict(animDict)
		while not HasAnimDictLoaded(animDict) do
			Wait(1)
		end
	end

	CreateThread(function()
		while _isShowering do
			TaskPlayAnim(playerPed, animDict, "male_shower_idle_d", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
			Wait(GetAnimDuration(animDict, "male_shower_idle_d") * 1000)
			if not _isShowering then break end

			TaskPlayAnim(playerPed, animDict, "male_shower_idle_a", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
			Wait(GetAnimDuration(animDict, "male_shower_idle_a") * 1000)
			if not _isShowering then break end

			TaskPlayAnim(playerPed, animDict, "male_shower_idle_c", 8.0, -8.0, 5.0, 0, 0.0, 0, 0, 0)
			Wait(GetAnimDuration(animDict, "male_shower_idle_c") * 1000)
		end

		RemoveAnimDict(animDict)
	end)
end

local function TakeShower(aptId, showerHeadPos, showerTime)
	if not showerHeadPos then
		showerHeadPos = GetEntityCoords(LocalPlayer.state.ped) + vector3(0.0, 0.0, 1.0)
	end

	if not aptId then
		Notification:Error("Can't start showering without an apartment ID")
		return
	end

	_isShowering = true
	StartShowerParticle(showerHeadPos, aptId)
	PlayShowerAnimation()

	local defaultShowerTime = (showerTime or 2) * 60 * 1000

	Progress:Progress({
		name     = "apartment_shower_" .. aptId,
		duration = defaultShowerTime,
		label    = "Showering",
		useWhileDead = false,
		canCancel    = true,
		vehicle      = false,
		controlDisables = {
			disableMovement    = true,
			disableCarMovement = true,
			disableCombat      = true,
		},
		animation = {
			animDict = "anim@mp_yacht@shower@male@",
			anim     = "male_shower_idle_d",
			flags    = 1,
		},
	}, function(success)
		_isShowering = false
		StopShowerParticle()
		ClearPedTasks(LocalPlayer.state.ped)

		if success then
			ClearPedBloodDamage(LocalPlayer.state.ped)
			ClearPedEnvDirt(LocalPlayer.state.ped)

			if LocalPlayer.state.GSR then
				LocalPlayer.state:set("GSR", nil, true)
			end

			Notification:Success("You feel clean and refreshed!", 5000)
		else
			Notification:Info("Shower cancelled", 3000)
		end
	end)
end

AddEventHandler("Apartment:Client:Shower", function(unit)
	if not LocalPlayer.state.Character or LocalPlayer.state.Character:GetData("SID") ~= unit then
		return
	end

	if _isShowering then
		Notification:Error("You are already showering", 3000)
		return
	end

	local aptId = LocalPlayer.state.inApartment and LocalPlayer.state.inApartment.type
	if not aptId then
		Notification:Error("You must be in your apartment to shower", 3000)
		return
	end

	local p = GlobalState[string.format("Apartment:%s", aptId)]
	if not p or not p.interior or not p.interior.locations or not p.interior.locations.shower then
		Notification:Error("Shower location not found", 3000)
		return
	end

	local showerPos     = p.interior.locations.shower.coords
	local showerHeadPos = vector3(showerPos.x, showerPos.y, showerPos.z + 1.0)

	TakeShower(aptId, showerHeadPos, 2)
end)
