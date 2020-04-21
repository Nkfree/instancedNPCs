local scriptConfig = {}

scriptConfig.removeDeadActorIn = 10 -- seconds for testing (minutes later)
scriptConfig.respawnDeadActorIn = 20 -- same as above

local Methods = {}

Methods.nativeInstancedPairs = {} -- we gonna insert here all the loaded cells as well as native npc uniqueIndexes that will have instanced unique indexes as values
Methods.instancedNativePairs = {} -- we gonna skip adding cells here and flip the native npc unique indexes and instanced unique indexes for quicker access

Methods.removeDeadActorTimer = {}
	 
function Methods.ForceSaveActorsOnFirstLoad(pid, cellDescription)
	
	local cell = LoadedCells[cellDescription]
	
	if cell and Methods.nativeInstancedPairs[cellDescription] == nil then
		-- cell:SaveActorList(pid)
		cell:SaveActorPositions()
		cell:SaveActorStatsDynamic()
		-- cell:SaveActorEquipment(pid)

		Methods.MemorizeCell(cellDescription)
	end
end


function Methods.MemorizeCell(cellDescription)
	
	if Methods.nativeInstancedPairs[cellDescription] == nil then
		Methods.nativeInstancedPairs[cellDescription] = {}
	end
end

function Methods.MemorizeNativeInstancedUniqueIds(cellDescription, nativeUniqueIndex, instancedUniqueIndex)
	
	Methods.nativeInstancedPairs[cellDescription][nativeUniqueIndex] = instancedUniqueIndex
	Methods.instancedNativePairs[instancedUniqueIndex] = nativeUniqueIndex
end

function Methods.ForgetNativeInstancedPairs(uniqueIndex)
	
	local nativeUniqueIndex = Methods.GetNativeActorUniqueIndex(uniqueIndex)
	
	for _, cellData in pairs(Methods.nativeInstancedPairs) do

		if cellData[nativeUniqueIndex] ~= nil then
			cellData[nativeUniqueIndex] = nil
		end
	end
	
	Methods.instancedNativePairs[uniqueIndex] = nil
end

function Methods.GetPrintableNativeInstancedPairs(pid, cmd)
	local message = "--------NATIVE-INSTANCED-PAIRS--------\n"
	message = message .. tableHelper.getPrintableTable(Methods.nativeInstancedPairs)
	message = message .. "\n--------------------------------------\n"
	tes3mp.SendMessage(pid, message, false)
end

customCommandHooks.registerCommand("getnip", Methods.GetPrintableNativeInstancedPairs)

function Methods.GetPrintableInstancedNativePairs(pid, cmd)
	local message = "--------INSTANCED-NATIVE-PAIRS--------\n"
	message = message .. tableHelper.getPrintableTable(Methods.instancedNativePairs)
	message = message .. "\n--------------------------------------\n"
	tes3mp.SendMessage(pid, message, false)
end

customCommandHooks.registerCommand("getinp", Methods.GetPrintableInstancedNativePairs)

function Methods.SpawnInstancedCounterPart(pid, cellDescription)
	
	local cell = LoadedCells[cellDescription]
	local nativeInstancedPairs = Methods.nativeInstancedPairs
	local instancedUniqueIndex
	local reloadAtEnd = false
	
	if cell then
		for _, uniqueIndex in pairs(cell.data.packets.actorList) do
			
			local actor = cell.data.objectData[uniqueIndex]
			
			if Methods.IsNative(uniqueIndex) and actor.refId and actor.location then
			
				local state = cell.data.objectData[uniqueIndex].state
				
				if state ~= false or nativeInstancedPairs[cellDescription][uniqueIndex] == nil then
					
					instancedUniqueIndex = logicHandler.CreateObjectAtLocation(cellDescription, actor.location, actor.refId, "spawn")
					tes3mp.LogMessage(1, "Spawning counterpart for uniqueIndex .. " .. uniqueIndex .. " with uniqueIndex " .. instancedUniqueIndex)
					Methods.MemorizeNativeInstancedUniqueIds(cellDescription, uniqueIndex, instancedUniqueIndex)
					reloadAtEnd = true
				end
			end
		end
		
		if reloadAtEnd then
			cell:QuicksaveToDrive()
			cell:LoadObjectsSpawned(pid, cell.data.objectData, cell.data.packets.spawn)
		end
	end
end

function Methods.RemoveInstancedActors(cellDescription)

	local cell = LoadedCells[cellDescription]
	
	for _, uniqueIndex in pairs(cell.data.packets.actorList) do
		
		if not Methods.IsNative(uniqueIndex) then
			local nativeActorCounterPart = Methods.GetNativeActorUniqueIndex(uniqueIndex)
			
			if nativeActorCounterPart then
				tableHelper.removeValue(cell.data.packets.actorList, uniqueIndex)
				tableHelper.removeValue(cell.data.packets.death, uniqueIndex)
				tableHelper.removeValue(cell.data.packets.container, uniqueIndex)
				tableHelper.removeValue(cell.data.packets.equipment, uniqueIndex)
				tableHelper.removeValue(cell.data.packets.position, uniqueIndex)
				tableHelper.removeValue(cell.data.packets.spawn, uniqueIndex)
				tableHelper.removeValue(cell.data.packets.statsDynamic, uniqueIndex)
				cell.data.objectData[uniqueIndex] = nil
				Methods.ForgetNativeInstancedPairs(uniqueIndex)
			end
		end
	end
end

function Methods.EnableNativeActors(cellDescription)

	local cell = LoadedCells[cellDescription]
	
	for _, uniqueIndex in pairs(cell.data.packets.actorList) do
		
		if Methods.IsNative(uniqueIndex) then
		
			local actor = cell.data.objectData[uniqueIndex]
			
			if actor.state == false then
				actor.state = true
			end
		end
	end
end
		
function Methods.IsNative(uniqueIndex)

	local split = uniqueIndex:split("-")
	
	return split[2] == "0"
end

function Methods.GetNativeActorUniqueIndex(uniqueIndex) -- we will use uniqueIndex of the dead (instanced) actor to find out the native actor counterpart's uniqueIndex
	
	if Methods.instancedNativePairs[uniqueIndex] ~= nil then
		return Methods.instancedNativePairs[uniqueIndex]
	end
	
	return nil
end

function Methods.GetNativeActorCell(cellDescription, nativeUniqueIndex)

	if Methods.nativeInstancedPairs[cellDescription][nativeUniqueIndex] ~= nil then
		return cellDescription
	end
	
	for cellDescToSearch, cellData in pairs(Methods.nativeInstancedPairs) do
	
		for uniqueIndex, _ in pairs(cellData) do
			if uniqueIndex == nativeUniqueIndex then
				return cellDescToSearch
			end
		end
	end
	
	return nil
end

function Methods.RemoveActorOnDeath(cellDescription, uniqueIndex)
	
	local cell = LoadedCells[cellDescription]
	
	logicHandler.DeleteObjectForEveryone(cellDescription, uniqueIndex)
	tableHelper.removeValue(cell.data.packets.actorList, uniqueIndex)
	tableHelper.removeValue(cell.data.packets.death, uniqueIndex)
	tableHelper.removeValue(cell.data.packets.container, uniqueIndex)
	tableHelper.removeValue(cell.data.packets.equipment, uniqueIndex)
	tableHelper.removeValue(cell.data.packets.position, uniqueIndex)
	tableHelper.removeValue(cell.data.packets.spawn, uniqueIndex)
	tableHelper.removeValue(cell.data.packets.statsDynamic, uniqueIndex)
	cell.data.objectData[uniqueIndex] = nil
	Methods.ForgetNativeInstancedPairs(uniqueIndex)
	Methods.removeDeadActorTimer[uniqueIndex] = nil
end

function Methods.RespawnActorOnDeath(nativeCellDescription, nativeUniqueIndex)
	
	if nativeCellDescription and nativeUniqueIndex then
		
		local cell = LoadedCells[nativeCellDescription]
		
		if cell == nil then
			return
		end
		
		local instancedUniqueIndex
		local nativeActor
		
		nativeActor = cell.data.objectData[nativeUniqueIndex]
		instancedUniqueIndex = logicHandler.CreateObjectAtLocation(nativeCellDescription, nativeActor.location, nativeActor.refId, "spawn")
		Methods.MemorizeNativeInstancedUniqueIds(nativeCellDescription, nativeUniqueIndex, instancedUniqueIndex)
	end
end
	

function Methods.DisableNativeNPCs(pid, cellDescription)
	
	local cell = LoadedCells[cellDescription]
	local unloadAtEnd = false
	
	if cell == nil then
		return
	end
	
	for _, uniqueIndex in pairs(cell.data.packets.actorList) do
		
		if Methods.IsNative(uniqueIndex) then
			local actor = cell.data.objectData[uniqueIndex]
			
			if actor.state == nil or actor.state == true then
				actor.state = false
				tableHelper.insertValueIfMissing(cell.data.packets.state, uniqueIndex)
			end
		end
	end
	
	cell:QuicksaveToDrive()
	cell:LoadObjectStates(pid, cell.data.objectData, cell.data.packets.state)
end

function t_OnCellLoadHandler(pid, cellDescription)
	Methods.ForceSaveActorsOnFirstLoad(pid, cellDescription)
	Methods.SpawnInstancedCounterPart(pid, cellDescription)
	Methods.DisableNativeNPCs(pid, cellDescription)
end
		
function t_OnActorDeath_removeActor(cellDescription, uniqueIndex)
	Methods.RemoveActorOnDeath(cellDescription, uniqueIndex)
end

function t_OnActorDeath_respawnActor(nativeCellDescription, nativeUniqueIndex)
	Methods.RespawnActorOnDeath(nativeCellDescription, nativeUniqueIndex)
end
	
		
        
		
customEventHooks.registerHandler("OnCellLoad", function(eventStatus, pid, cellDescription)

tes3mp.StartTimer(
	tes3mp.CreateTimerEx(
						"t_OnCellLoadHandler", 
						time.seconds(1), 
						"is", 
						pid, 
						cellDescription
						)
					)
end)

customEventHooks.registerValidator("OnCellDeletion", function(eventStatus, cellDescription)
	if logicHandler.GetConnectedPlayerCount() < 1 then
		Methods.RemoveInstancedActors(cellDescription)
		Methods.EnableNativeActors(cellDescription)
		LoadedCells[cellDescription]:QuicksaveToDrive()
	end
end)

customEventHooks.registerHandler("OnContainer", function(eventStatus, pid, cellDescription, objects)
	
	local cell = LoadedCells[cellDescription]
	
	for _, object in pairs(objects) do
		local uniqueIndex = object.uniqueIndex
		
		if tableHelper.containsValue(cell.data.packets.actorList, uniqueIndex) then
			
			if next(cell.data.objectData[uniqueIndex].inventory) == nil then
			
				if Methods.removeDeadActorTimer[uniqueIndex] ~= nil then
					tes3mp.StopTimer(Methods.removeDeadActorTimer[uniqueIndex])
					
					local nativeUniqueIndex = Methods.GetNativeActorUniqueIndex(uniqueIndex)
					local nativeCellDescription = Methods.GetNativeActorCell(cellDescription, nativeUniqueIndex)
					
					Methods.removeDeadActorTimer[uniqueIndex] = tes3mp.CreateTimerEx(
							"t_OnActorDeath_removeActor", 
							time.seconds(1), 
							"ss", 
							cellDescription,
							uniqueIndex
							)
					tes3mp.StartTimer(Methods.removeDeadActorTimer[uniqueIndex])
				end
			end
		end
	end
end)
				

customEventHooks.registerHandler("OnActorDeath", function(eventStatus, pid, cellDescription)
	
	tes3mp.ReadReceivedActorList()
	
    local actorListSize = tes3mp.GetActorListSize()

    for actorIndex = 0, actorListSize - 1 do
		
		local uniqueIndex = tes3mp.GetActorRefNum(actorIndex) .. "-" .. tes3mp.GetActorMpNum(actorIndex)
		local nativeUniqueIndex = Methods.GetNativeActorUniqueIndex(uniqueIndex)
		local nativeCellDescription = Methods.GetNativeActorCell(cellDescription, nativeUniqueIndex)
		
		Methods.removeDeadActorTimer[uniqueIndex] = tes3mp.CreateTimerEx(
							"t_OnActorDeath_removeActor", 
							time.seconds(scriptConfig.removeDeadActorIn), 
							"ss", 
							cellDescription,
							uniqueIndex
							)
						
		tes3mp.StartTimer(Methods.removeDeadActorTimer[uniqueIndex])

		tes3mp.StartTimer(tes3mp.CreateTimerEx(
							"t_OnActorDeath_respawnActor", 
							time.seconds(scriptConfig.respawnDeadActorIn),
							"ss", 
							nativeCellDescription,
							nativeUniqueIndex
							)
						)
	end
end)