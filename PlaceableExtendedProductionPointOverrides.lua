--
-- Realistic Livestock compatibility hooks for ExtendedProductionPoint
-- J.Connor, the weird guy down the street with all the chickens.

local currentModName = g_currentModName or "GLOBAL"
g_PEPPExtendedProductionOverridesApplied = g_PEPPExtendedProductionOverridesApplied or {}

local function debugLog(message, ...)
    if Logging ~= nil and Logging.info ~= nil then
        Logging.info(message, ...)
    else
        print(string.format(message, ...))
    end
end

local function initializeOverrides()
    if PlaceableExtendedProductionPoint == nil or ExtendedProductionPoint == nil then
        return false
    end

    if g_PEPPExtendedProductionOverridesApplied[currentModName] then
        return true
    end

    debugLog("[PlaceableExtendedProductionPointOverrides] RL override initialised")

    local placeableClass = PlaceableExtendedProductionPoint
    local productionClass = ExtendedProductionPoint

    if placeableClass == nil or productionClass == nil then
        if Logging ~= nil then
            Logging.warning("[PlaceableExtendedProductionPointOverrides] Base classes not available, aborting override initialisation")
        else
            print("[PlaceableExtendedProductionPointOverrides] Base classes not available, aborting override initialisation")
        end
        return false
    end

    local specEntryName = placeableClass.SPEC
    local DEBUG_EXTENDED_PRODUCTION = rawget(_G, "DEBUG_EXTENDED_PRODUCTION") ~= nil and _G.DEBUG_EXTENDED_PRODUCTION or false

    local function resolveRLFillType(factory, animal)
        if animal == nil then
            return nil
        end

        if factory.animalTypeToFillType ~= nil then
            local mapped = factory.animalTypeToFillType[animal.animalTypeIndex]
            if mapped ~= nil then
                return mapped
            end
        end

        if factory.animalSubTypeToFillType ~= nil and animal.subTypeIndex ~= nil then
            local mapped = factory.animalSubTypeToFillType[animal.subTypeIndex]
            if mapped ~= nil then
                return mapped
            end
        end

        return nil
    end

    local function ensurePlaceableBridges(placeable)
        if placeable == nil then
            return
        end

        placeable.isRLHusbandry = true

        if placeable.addRLMessage == nil then
            function placeable:addRLMessage(id, animal, args, date, uniqueId, ...)
                local spec = self[specEntryName]
                if spec ~= nil and spec.productionPoint ~= nil and spec.productionPoint.addRLMessage ~= nil then
                    return spec.productionPoint:addRLMessage(id, animal, args, date, uniqueId, ...)
                end
            end
        end

        if placeable.getRLMessages == nil then
            function placeable:getRLMessages()
                local spec = self[specEntryName]
                if spec ~= nil and spec.productionPoint ~= nil and spec.productionPoint.getRLMessages ~= nil then
                    return spec.productionPoint:getRLMessages()
                end
                return {}
            end
        end

        if placeable.setHasUnreadRLMessages == nil then
            function placeable:setHasUnreadRLMessages(hasUnread)
                local spec = self[specEntryName]
                if spec ~= nil and spec.productionPoint ~= nil and spec.productionPoint.setHasUnreadRLMessages ~= nil then
                    spec.productionPoint:setHasUnreadRLMessages(hasUnread)
                end
            end
        end

        if placeable.getHasUnreadRLMessages == nil then
            function placeable:getHasUnreadRLMessages()
                local spec = self[specEntryName]
                if spec ~= nil and spec.productionPoint ~= nil and spec.productionPoint.getHasUnreadRLMessages ~= nil then
                    return spec.productionPoint:getHasUnreadRLMessages()
                end
                return false
            end
        end
    end

    local function computeRLDateString()
        local env = g_currentMission ~= nil and g_currentMission.environment or nil
        if env ~= nil then
            if _G.RealisticLivestock ~= nil then
                local month = env.currentPeriod and (env.currentPeriod + 2) or 1
                if month > 12 then
                    month = month - 12
                end
                local currentDayInPeriod = env.currentDayInPeriod or 1
                local daysPerPeriod = env.daysPerPeriod or 30
                local day = 1 + math.floor((currentDayInPeriod - 1) * ((_G.RealisticLivestock.DAYS_PER_MONTH[month] or daysPerPeriod) / daysPerPeriod))
                local year = env.currentYear or 0
                local startYear = (_G.RealisticLivestock.START_YEAR and _G.RealisticLivestock.START_YEAR.FULL) or 2000
                return string.format("%d/%d/%d", day, month, year + startYear)
            end
            return string.format("%d/%d/%d", env.currentDay, env.currentPeriod or 1, env.currentYear or 0)
        end

        return ""
    end

    if productionClass.getIsRLHusbandry == nil then
        function productionClass:getIsRLHusbandry()
            return true
        end
    end

    if productionClass.getRLMessages == nil then
        function productionClass:getRLMessages()
            self._rlMessages = self._rlMessages or {}
            return self._rlMessages
        end
    end

    if productionClass.setHasUnreadRLMessages == nil then
        function productionClass:setHasUnreadRLMessages(hasUnread)
            self._rlUnreadMessages = hasUnread and true or false
        end
    end

    if productionClass.getHasUnreadRLMessages == nil then
        function productionClass:getHasUnreadRLMessages()
            return self._rlUnreadMessages or false
        end
    end

    if productionClass.addRLMessage == nil then
        function productionClass:addRLMessage(id, animal, args, date, uniqueId, _)
            self._rlMessages = self._rlMessages or {}
            table.insert(self._rlMessages, {
                id = id,
                animal = animal,
                args = args or {},
                date = type(date) == "string" and date or computeRLDateString(),
                uniqueId = uniqueId or (#self._rlMessages + 1)
            })
            self._rlUnreadMessages = true
        end
    end

    local function applyInstanceExtensions(factory)
        if factory._PPEPExtendedProductionApplied then
            return
        end

        factory._PPEPExtendedProductionApplied = true
        factory._rlMessages = factory._rlMessages or {}
        factory._rlUnreadMessages = factory._rlUnreadMessages or false
        factory.isRLHusbandry = true

        if factory.rlHusbandry == nil and factory.owningPlaceable ~= nil then
            if factory.owningPlaceable.getRLHusbandry ~= nil then
                factory.rlHusbandry = factory.owningPlaceable:getRLHusbandry()
            elseif factory.owningPlaceable.spec_husbandryAnimals ~= nil then
                factory.rlHusbandry = factory.owningPlaceable
            end
        end

        ensurePlaceableBridges(factory.owningPlaceable)
        ensurePlaceableBridges(factory.rlHusbandry)

        if factory.isServer and factory.clusterSystem ~= nil and not factory.clusterSystem._PPEPAddClusterHooked then
            local originalAddCluster = factory.clusterSystem.addCluster

            function factory.clusterSystem:addCluster(cluster, ...)
                local result = originalAddCluster(self, cluster, ...)

                local owner = self.owner or factory
                if owner ~= nil and owner.syncRLAnimalsFromHusbandry ~= nil then
                    owner:syncRLAnimalsFromHusbandry()
                end

                return result
            end

            factory.clusterSystem._PPEPAddClusterHooked = true
        end

        if factory.syncRLAnimalsFromHusbandry == nil then
            function factory:syncRLAnimalsFromHusbandry()
                local clusterSystem = self.clusterSystem
                if clusterSystem == nil or clusterSystem.animals == nil then
                    return
                end

                local animals = clusterSystem.animals
                if #animals == 0 then
                    return
                end

                local converted = 0
                for i = #animals, 1, -1 do
                    local animal = animals[i]
                    local fillType = resolveRLFillType(self, animal)

                    if fillType ~= nil then
                        local quality = (animal.genetics and animal.genetics.quality) or 1
                        local amount = quality
                        local current = self.storage:getFillLevel(fillType) or 0
                        self.storage:setFillLevel(current + amount, fillType)

                        animal.isDead = true
                        animal.isSold = true
                        animal.numAnimals = 0
                        clusterSystem:removeCluster(i)
                        converted = converted + 1
                    end
                end

                if converted > 0 and self.addRLMessage ~= nil then
                    if converted == 1 then
                        self:addRLMessage("MOVED_ANIMALS_TARGET_SINGLE", nil, { self:getName() })
                    else
                        self:addRLMessage("MOVED_ANIMALS_TARGET_MULTIPLE", nil, { converted, self:getName() })
                    end
                end
            end
        end

        if factory._PPEPOriginalGetNumOfAnimals == nil then
            factory._PPEPOriginalGetNumOfAnimals = factory.getNumOfAnimals

            function factory:getNumOfAnimals(...)
                if self.clusterSystem ~= nil and self.clusterSystem.animals ~= nil then
                    return #self.clusterSystem.animals
                end

                if self._rlAnimals ~= nil then
                    return #self._rlAnimals
                end

                return self._PPEPOriginalGetNumOfAnimals(self, ...)
            end
        end

        if DEBUG_EXTENDED_PRODUCTION and factory.isClient and not factory._PPEPUpdateProductionPatched and factory.updateProduction ~= nil then
            local originalUpdateProduction = factory.updateProduction
            factory._ppepDebugLevels = factory._ppepDebugLevels or {}

            local function getFillTypeName(index)
                if g_fillTypeManager ~= nil then
                    return g_fillTypeManager:getFillTypeNameByIndex(index) or g_fillTypeManager:getFillTypeTitleByIndex(index) or tostring(index)
                end
                return tostring(index)
            end

            function factory:updateProduction(...)
                self.updatingProduction = true

                if self.productions ~= nil then
                    for _, production in ipairs(self.productions) do
                        local productionId = production.id or tostring(_)
                        local record = self._ppepDebugLevels[productionId]
                        if record == nil then
                            record = { inputs = {}, outputs = {} }
                            self._ppepDebugLevels[productionId] = record
                        end

                        if production.inputs ~= nil then
                            for _, input in ipairs(production.inputs) do
                                local fillType = input.type
                                if fillType ~= nil then
                                    local currentLevel = ExtendedProductionPoint.superClass().getFillLevel(self, fillType)
                                    local lastLevel = record.inputs[fillType]
                                    if lastLevel ~= nil and math.abs(currentLevel - lastLevel) > 0.0001 then
                                        debugLog("[PPEP DEBUG] Production '%s' input '%s' changed: %.3f -> %.3f", production.name or productionId, getFillTypeName(fillType), lastLevel, currentLevel)
                                    end
                                    record.inputs[fillType] = currentLevel
                                end
                            end
                        end

                        if production.outputs ~= nil then
                            for _, output in ipairs(production.outputs) do
                                local fillType = output.type
                                if fillType ~= nil then
                                    local currentLevel = self:getFillLevel(fillType)
                                    local lastLevel = record.outputs[fillType]
                                    if lastLevel ~= nil and math.abs(currentLevel - lastLevel) > 0.0001 then
                                        debugLog("[PPEP DEBUG] Production '%s' output '%s' changed: %.3f -> %.3f", production.name or productionId, getFillTypeName(fillType), lastLevel, currentLevel)
                                    end
                                    record.outputs[fillType] = currentLevel
                                end
                            end
                        end
                    end
                end

                originalUpdateProduction(self, ...)
                self.updatingProduction = false
            end

            factory._PPEPUpdateProductionPatched = true
        end

        if factory.syncRLAnimalsFromHusbandry ~= nil then
            factory:syncRLAnimalsFromHusbandry()
        end
    end

    if not productionClass._PPEPNewWrapped then
        local originalNew = productionClass.new

        function productionClass.new(isServer, isClient, baseDirectory, customMt)
            local instance = originalNew(isServer, isClient, baseDirectory, customMt)

            if instance ~= nil then
                instance._rlMessages = instance._rlMessages or {}
                instance._rlUnreadMessages = instance._rlUnreadMessages or false
                instance.isRLHusbandry = true
            end

            return instance
        end

        productionClass._PPEPNewWrapped = true
    end

    if not productionClass._PPEPLoadOverwritten then
        local function PPEPExtendedProductionLoad(self, superFunc, components, xmlFile, key, customEnvironment, i3dMappings)
            if self.rlHusbandry == nil and self.owningPlaceable ~= nil then
                if self.owningPlaceable.getRLHusbandry ~= nil then
                    self.rlHusbandry = self.owningPlaceable:getRLHusbandry()
                elseif self.owningPlaceable.spec_husbandryAnimals ~= nil then
                    self.rlHusbandry = self.owningPlaceable
                end
            end

            local success = superFunc(self, components, xmlFile, key, customEnvironment, i3dMappings)

            if success then
                applyInstanceExtensions(self)
            end

            return success
        end

        productionClass.load = Utils.overwrittenFunction(productionClass.load, PPEPExtendedProductionLoad)
        productionClass._PPEPLoadOverwritten = true
    end

    g_PEPPExtendedProductionOverridesApplied[currentModName] = true
    return true
end

if not initializeOverrides() and Mission00 ~= nil then
    Mission00.loadMapFinished = Utils.appendedFunction(Mission00.loadMapFinished, function(mission, node)
        initializeOverrides()
    end)
end
