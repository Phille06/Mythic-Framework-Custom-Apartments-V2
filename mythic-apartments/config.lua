Config = {}

Config.Location = "wiwang" -- Location of the apartments, make sure to add the doors to mythic-doors

Config.ReceptionPoliceActions = true -- Enable police apartment lookup option at the reception ped

Config.RaidDoorSkillbar = {
    enabled = true, -- Enable the skillbar for raiding doors
    difficulty = 1.0, -- Base difficulty for the skillbar, higher is harder
    time = 1, -- Base time for the skillbar, higher is harder
    amount = 5 -- Amount of successful stages needed to raid the door, higher is harder
}

Config.RaidStashSkillbar = {
    enabled = true, -- Enable the skillbar for raiding stashes
    difficulty = 1.0, -- Base difficulty for the skillbar, higher is harder
    time = 1, -- Base time for the skillbar, higher is harder
    amount = 5 -- Amount of successful stages needed to raid the stash, higher is harder
}

Config.StashUpgradeCosts = { -- The storage amounts are defined in the inventory, change the invType to change the capacity and slots amount
    [13] = 5000,  -- Cost to upgrade Tier 1 → Tier 2 (20 slots / 400 capacity → 25 slots / 450 capacity)
    [14] = 15000, -- Cost to upgrade Tier 2 → Tier 3 (25 slots / 450 capacity → 30 slots / 500 capacity)
}

function GetApartmentDataFromConfig()
    local apartments = {}

    local sortedBuildings = {}
    for buildingName, rooms in pairs(Config.HotelRooms) do
        table.insert(sortedBuildings, {
            name = buildingName,
            rooms = rooms
        })
    end

    table.sort(sortedBuildings, function(a, b)
        return a.name < b.name
    end)

    for _, building in ipairs(sortedBuildings) do
        local buildingName = building.name
        local rooms = building.rooms

        local sortedRooms = {}
        for roomIndex, roomData in pairs(rooms) do
            if type(roomIndex) == "number" then
                table.insert(sortedRooms, {
                    index = roomIndex,
                    data = roomData
                })
            end
        end

        table.sort(sortedRooms, function(a, b)
            return a.index < b.index
        end)

        for _, roomEntry in ipairs(sortedRooms) do
            local roomData = roomEntry.data
            local doorEntry = roomData.zones.doorEntry

            if not doorEntry then
                goto continue
            end

            local roomId = string.format("%s_%s", buildingName, roomData.roomLabel)
            local interiorLength = 8.0
            local interiorWidth = 8.0

            local wakeupCoords =
                roomData.zones.logout or
                (roomData.zones.wardrobe and roomData.zones.wardrobe or doorEntry)

            local buildingLabel = rooms.label or buildingName

            table.insert(apartments, {
                name = string.format("%s - Room %s", buildingLabel, roomData.roomLabel),

                buildingName = buildingName,
                buildingLabel = buildingLabel,
                roomLabel = roomData.roomLabel,

                roomId = roomId,
                roomIndex = roomEntry.index,
                floor = roomData.floor,
                doorId = roomData.doorId or roomEntry.index,

                invEntity = 13,

                coords = vector3(doorEntry.x, doorEntry.y, doorEntry.z),
                heading = 0,
                length = 1.0,
                width = 1.0,

                options = {
                    heading = 0,
                    minZ = doorEntry.z - 1.0,
                    maxZ = doorEntry.z + 2.0
                },

                furniture = roomData.furniture,

                interior = {
                    zone = {
                        center = doorEntry,
                        length = interiorLength,
                        width = interiorWidth,
                        options = {
                            heading = 0,
                            minZ = doorEntry.z - 2.0,
                            maxZ = doorEntry.z + 3.0
                        }
                    },

                    wakeup = {
                        x = wakeupCoords.x,
                        y = wakeupCoords.y,
                        z = wakeupCoords.z,
                        h = 0.0
                    },

                    spawn = {
                        x = doorEntry.x,
                        y = doorEntry.y,
                        z = doorEntry.z,
                        h = 0.0
                    },

                    locations = {
                        exit = {
                            coords = doorEntry,
                            length = 0.6,
                            width = 1.2,
                            options = {
                                heading = 0,
                                minZ = doorEntry.z - 0.5,
                                maxZ = doorEntry.z + 2.0
                            }
                        },

                        wardrobe = roomData.zones.wardrobe and {
                            coords = roomData.zones.wardrobe,
                            length = 0.6,
                            width = 1.2,
                            options = {
                                heading = 0,
                                minZ = roomData.zones.wardrobe.z - 0.5,
                                maxZ = roomData.zones.wardrobe.z + 2.0
                            }
                        } or nil,

                        shower = roomData.zones.shower and {
                            coords = roomData.zones.shower,
                            length = 0.6,
                            width = 1.2,
                            options = {
                                heading = 0,
                                minZ = roomData.zones.shower.z - 0.5,
                                maxZ = roomData.zones.shower.z + 2.0
                            }
                        } or nil,

                        stash = roomData.zones.stash and {
                            coords = roomData.zones.stash,
                            length = 1.0,
                            width = 1.0,
                            options = {
                                heading = 0,
                                minZ = roomData.zones.stash.z - 0.5,
                                maxZ = roomData.zones.stash.z + 2.0
                            }
                        } or nil,

                        logout = (roomData.zones.logout or roomData.zones.wardrobe) and {
                            coords = roomData.zones.logout or roomData.zones.wardrobe,
                            length = 2.0,
                            width = 2.8,
                            options = {
                                heading = 0,
                                minZ = (roomData.zones.logout or roomData.zones.wardrobe).z - 0.5,
                                maxZ = (roomData.zones.logout or roomData.zones.wardrobe).z + 2.0
                            }
                        } or nil,
                    }
                }
            })

            ::continue::
        end
    end

    return apartments
end