
_aptData = {}
_aptDataByRoomId = {}
_availableApartments = {}
_assignedApartments = {} 
_apartmentAssignments = {} 

if _raidedApartments then
	_raidedApartments = {}
end

function Startup()
	local aptConfigs = GetApartmentDataFromConfig()
	
	_aptData = {}
	_aptDataByRoomId = {}
	_availableApartments = {}
	_assignedApartments = {}
	_apartmentAssignments = {}
	local aptIds = {}

	for _, aptData in ipairs(aptConfigs) do
		local index = #_aptData + 1
		aptData.id = index
		
		if aptData.roomId then
			_aptDataByRoomId[aptData.roomId] = aptData
		end
		
		table.insert(_aptData, aptData)
		GlobalState[string.format("Apartment:%s", index)] = aptData
		table.insert(aptIds, index)
	end

	GlobalState["Apartments"] = aptIds
	
	LoadApartmentAssignments()

	Logger:Info("Apartments", string.format("Loaded ^2%d^7 apartment rooms", #aptIds))
end