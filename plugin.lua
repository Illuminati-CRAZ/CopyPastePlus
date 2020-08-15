--this is probably all jank idk
memory = {}

MEMORY_INCREMENT = 0

--maybe i should change "offset" to "index"
function memory.write(offset, data, step, mirror)
    if type(data) != "number" and type(data) != "table" then
        return(offset) --return same offset to use since nothing is written
    end

    step = step or 1
    mirror = mirror or false --setting mirror to true causes effect of sv to be (mostly) negated by an equal and opposite sv and then a 1x sv is placed

    if type(data) == "number" then
        if mirror then
            local svs = {}
            table.insert(svs, utils.CreateScrollVelocity(offset, data))
            table.insert(svs, utils.CreateScrollVelocity(offset + MEMORY_INCREMENT, -data))
            table.insert(svs, utils.CreateScrollVelocity(offset + 2 * MEMORY_INCREMENT, 1))
            actions.PlaceScrollVelocityBatch(svs)
        else
            actions.PlaceScrollVelocity(utils.CreateScrollVelocity(offset, data))
        end
        return(offset + step) --one sv placed, so increment offset by 1 step
    else --data is a table
        local svs = {}
        for i, value in pairs(data) do
            table.insert(svs, utils.CreateScrollVelocity(offset + step * (i-1), value))
            if mirror then
                table.insert(svs, utils.CreateScrollVelocity(offset + step * (i-1) + MEMORY_INCREMENT, -value))
                table.insert(svs, utils.CreateScrollVelocity(offset + step * (i-1) + 2 * MEMORY_INCREMENT, 1))
            end
        end
        actions.PlaceScrollVelocityBatch(svs)
        return(offset + #data * step) --increment offset by number of elements in data times step
    end
end

function memory.search(start, stop)
    local svs = map.ScrollVelocities --I'm assuming this returns the svs in order so I'm not sorting them
    local selection = {}
    for _, sv in pairs(svs) do
        if (start <= sv.StartTime) and (sv.StartTime <= stop) then
            table.insert(selection, sv)
        elseif sv.StartTime > stop then --since they're in order, I should be able to return once StartTime exceeds stop
            break
        end
    end
    return(selection) --returns table of svs
end

function memory.read(start, stop, step)
    if not start then
        return(false)
    end

    step = step or 1 --step indicated which svs are for data and which are for mirroring
    stop = stop or start --stop defaults to start, so without a stop provided, function returns one item

    local selection = {}
    for _, sv in pairs(memory.search(start, stop)) do
        if sv.StartTime % step == 0 then --by default, anything without integer starttime is not included
            table.insert(selection, sv.Multiplier)
        end
    end
    if #selection == 1 then --if table of only one element
        return(selection[1]) --return element
    else --otherwise
        return(selection) --return table of elements
    end
end

function memory.delete(start, stop, step)
    if not start then
        return(false)
    end

    step = step or 1
    stop = stop or start

    local svs = memory.search(start, stop)
    local selection = {}

    for _, sv in pairs(svs) do
        if sv.StartTime % step == 0 then
            table.insert(selection, sv.Multiplier)
        end
    end

    actions.RemoveScrollVelocityBatch(svs)
    if #selection == 1 then --if table of only one element
        return(selection[1]) --return element
    else --otherwise
        return(selection) --return table of elements
    end
end

function memory.generateCorrectionSVs(limit, offset) --because there's going to be a 1293252348328x SV that fucks the game up
    local svs = map.ScrollVelocities --if these don't come in order i'm going to hurt someone

    local totaldisplacement = 0

    for i, sv in pairs(svs) do
        if (sv.StartTime < limit) and not (sv.StartTime == offset or sv.StartTime == offset + 1) then
            length = svs[i+1].StartTime - sv.StartTime
            displacement = length * (sv.Multiplier - 1) --displacement in ms as a distance
            totaldisplacement = totaldisplacement + displacement --total displacement in ms as a distance
        else
            break
        end
    end

    corrections = {}
    table.insert(corrections, utils.CreateScrollVelocity(offset, -totaldisplacement + 1)) --i think this is correct?
    table.insert(corrections, utils.CreateScrollVelocity(offset + 1, 1))

    return(corrections)
end

function memory.correctDisplacement(limit, offset) --will not work if there's an ultra large number at the end
    local limit = limit or 0 --where the memory ends
    local offset = offset or -10000002 --SVs will return with StartTime = offset and offset + 1

    local currentsvs = {}
    table.insert(currentsvs, getScrollVelocityAtExactly(offset))
    table.insert(currentsvs, getScrollVelocityAtExactly(offset + 1))
    actions.RemoveScrollVelocityBatch(currentsvs)

    actions.PlaceScrollVelocityBatch(memory.generateCorrectionSVs(limit, offset))
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

function getScrollVelocityAtExactly(time)
    local currentsv = map.GetScrollVelocityAt(time)
    if currentsv.StartTime == time then
        return(currentsv)
    end
end

function tableToString(thing) --I have sinned

    local results = {}

    for k, v in pairs(thing) do
        table.insert(results, "[" .. k .. "]: " .. v)
    end
    return(table.concat(results, ", "))
end

function hitObjectsToString(notes)

    local results = {}

    for _, note in pairs(notes) do
        table.insert(results, note.StartTime .. "|" .. note.Lane)
    end
    return(table.concat(results, ", "))
end

function has(thing, val) --sinned again
    for _, value in pairs(thing) do
        if value == val then
            return(true)
        end
    end

    return(false)
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

function initialize()
    memory.write(INITIALIZE_OFFSET, 1)

    memory.correctDisplacement(MEMORY_LIMIT) --for some reason doesn't do anything unless by itself?
end

function getHitObjectsOnLayer(layer)
    local notes = map.HitObjects

    local selection = {}
    for _, note in pairs(notes) do
        if note.EditorLayer == layer then
            table.insert(selection, note)
        end
    end

    return(selection)
end

function getTimingPointsInGroup(group)
    local data = retrieveTimingPointGroupData(group)

    local tps = getTimingPoints(data[2], data[3])
    return(tps)
end

function getScrollVelocitiesInGroup(group)
end

function getTimingPoints(start, stop)
    local tps = map.TimingPoints

    local selection = {}
    for _, tp in pairs(tps) do
        if (start <= tp.StartTime) and (tp.StartTime <= stop) then
            table.insert(selection, tp)
        elseif tp.StartTime > stop then
            return(selection)
        end
    end
    return(selection)
end

function getScrollVelocities(start, stop)
    local svs = map.ScrollVelocities

    local selection = {}
    for _, sv in pairs(svs) do
        if (start <= sv.StartTime) and (sv.StartTime <= stop) then
            table.insert(selection, sv)
        elseif sv.StartTime > stop then
            return(selection)
        end
    end
    return(selection)
end

function registerHitObjectGroup(layer)
    local groupdata = retrieveHitObjectGroupData(layer)
    if type(groupdata) == "table" and groupdata[1] == layer then
        return(false)
    end

    local notes = getHitObjectsOnLayer(layer)

    local start = notes[1].StartTime
    local stop = notes[#notes].StartTime

    local data = {layer, start, stop} --there's actually not that much point in storing start and stop
    local offset = MEMORY_OFFSET + (layer - 1)

    memory.write(offset, data, DATA_INCREMENT)
end

function registerTimingPointGroup(group, start, stop)
    local groupdata = retrieveTimingPointGroupData(group)
    if type(groupdata) == "table" and (groupdata[1] == -1 or groupdata[1] == -2) then
        return(false)
    end

    local tps = getTimingPoints(start, stop)
    local start = tps[1].StartTime
    local stop = tps[#tps].StartTime

    local data = {-1, start, stop}
    local offset = MEMORY_OFFSET_2 + (group - 1)

    memory.write(offset, data, DATA_INCREMENT)
end

function registerScrollVelocityGroup(group, start, stop)
end

function retrieveHitObjectGroupData(layer)
    local start = MEMORY_OFFSET + (layer - 1)
    local stop = MEMORY_OFFSET + layer - DATA_INCREMENT

    local data = memory.read(start, stop, DATA_INCREMENT)

    return(data)
end

function retrieveTimingPointGroupData(group)
    local start = MEMORY_OFFSET_2 + (group - 1)
    local stop = MEMORY_OFFSET_2 + group - DATA_INCREMENT

    local data = memory.read(start, stop, DATA_INCREMENT)

    return(data)
end

function retrieveScrollVelocityGroupData(group)
end

function retrieveHitObjectPasteData(layer)
    local start = MEMORY_OFFSET + (layer - 1) + 3 * DATA_INCREMENT
    local stop = MEMORY_OFFSET + layer - DATA_INCREMENT

    local times = memory.read(start, stop, DATA_INCREMENT)
    return(times)
end

function retrieveTimingPointPasteData(group)
    local start = MEMORY_OFFSET_2 + (group - 1) + 3 * DATA_INCREMENT
    local stop = MEMORY_OFFSET_2 + group - DATA_INCREMENT

    local times = memory.read(start, stop, DATA_INCREMENT)
    return(times)
end

function retrieveScrollVelocityPasteData(group)
end

function registerHitObjectPaste(layer, time)
    local data = retrieveHitObjectGroupData(layer)
    memory.write(MEMORY_OFFSET + (layer - 1) + #data * DATA_INCREMENT, time)
end

function registerTimingPointPaste(group, time)
    local data = retrieveTimingPointGroupData(group)
    memory.write(MEMORY_OFFSET_2 + (group - 1) + #data * DATA_INCREMENT, time)
end

function registerScrollVelocityPaste(group, time)
end

function pasteHitObjectGroup(layer, time)
    local notes = getHitObjectsOnLayer(layer)
    local difference = time - retrieveHitObjectGroupData(layer)[2]

    local pastenotes = {}
    for _, note in pairs(notes) do
        if note.EndTime == 0 then
            table.insert(pastenotes, utils.CreateHitObject(note.StartTime + difference, note.Lane, note.EndTime, note.HitSound))
        else
            table.insert(pastenotes, utils.CreateHitObject(note.StartTime + difference, note.Lane, note.EndTime + difference, note.HitSound))
        end
    end

    actions.PlaceHitObjectBatch(pastenotes)

    registerHitObjectPaste(layer, time)
end

function pasteTimingPointGroup(group, time)
    local tps = getTimingPointsInGroup(group)
    local difference = time - retrieveTimingPointGroupData(group)[2]

    local pastetps = {}
    for _, tp in pairs(tps) do
        table.insert(pastetps, utils.CreateTimingPoint(tp.StartTime + difference, tp.Bpm, tp.Signature))
    end

    actions.PlaceTimingPointBatch(pastetps)

    registerTimingPointPaste(group, time)
end

function pasteScrollVelocityGroup(group, time)
end

function unregisterHitObjectPaste(layer, time)
    local start = MEMORY_OFFSET + (layer - 1) + 3 * DATA_INCREMENT
    local stop = MEMORY_OFFSET + layer - DATA_INCREMENT

    local data = memory.delete(start, stop, DATA_INCREMENT)
    local newtimes = {}
    if type(data) == "number" then
        if data != time then
            table.insert(newtimes, data)
        end
    else
        for _, pastetime in pairs(data) do
            if pastetime != time then
                table.insert(newtimes, pastetime)
            end
        end
    end

    memory.write(start, newtimes, DATA_INCREMENT)
end

function unregisterTimingPointPaste(group, time)
    local start = MEMORY_OFFSET_2 + (group - 1) + 3 * DATA_INCREMENT
    local stop = MEMORY_OFFSET_2 + group - DATA_INCREMENT

    local data = memory.delete(start, stop, DATA_INCREMENT)
    local newtimes = {}
    if type(data) == "number" then
        if data != time then
            table.insert(newtimes, data)
        end
    else
        for _, pastetime in pairs(data) do
            if pastetime != time then
                table.insert(newtimes, pastetime)
            end
        end
    end

    memory.write(start, newtimes, DATA_INCREMENT)
end

function unregisterScrollVelocityPaste()
end

function unpasteHitObjectPaste(layer, time)
    local data = retrieveHitObjectGroupData(layer)
    local length = data[3] - data[2]

    local pasteexists = false
    for i=4, #data do
        if data[i] == time then
            pasteexists = true
        end
    end

    if pasteexists then
        local notes = map.HitObjects

        local pastenotes = {}
        for _, note in pairs(notes) do
            if (time <= note.StartTime) and (note.StartTime <= time + length) then
                table.insert(pastenotes, note)
            elseif note.StartTime > time + length then
                break
            end
        end

        actions.RemoveHitObjectBatch(pastenotes)
        unregisterHitObjectPaste(layer, time)
    end
end

function unpasteTimingPointPaste(group, time)
    local data = retrieveTimingPointGroupData(group)

    local pasteexists = false
    for i=4, #data do
        if data[i] == time then
            pasteexists = true
        end
    end

    if pasteexists then
        local tps = getTimingPoints(time, time + data[3] - data[2])

        actions.RemoveTimingPointBatch(tps)
        unregisterTimingPointPaste(group, time)
    end
end

function unpasteScrollVelocityPaste()
end

function unpasteAllHitObjectPastes(layer)
    local times = retrieveHitObjectPasteData(layer)

    for i = 1, #times do
        unpasteHitObjectPaste(layer, times[i])
    end
end

function unpasteAllTimingPointPastes(group)
    local times = retrieveTimingPointPasteData(group)
    debug = #times
    for _, time in pairs(times) do
        unpasteTimingPointPaste(group, time)
    end
end

function unpasteAllScrollVelocityPastes()
end

function updateHitObjectPaste(layer, time)
    local times = retrieveHitObjectPasteData(layer)
    if type(times) == "number" then
        if times == time then
            unpasteHitObjectPaste(layer, time)
            pasteHitObjectGroup(layer, time)
        end
    else
        if has(times, time) then
            unpasteHitObjectPaste(layer, time)
            pasteHitObjectGroup(layer, time)
        end
    end
end

function updateTimingPointPaste(group, time)
    local times = retrieveTimingPointPasteData(group)
    if type(times) == "number" then
        if times == time then
            unpasteTimingPointPaste(group, time)
            pasteTimingPointGroup(group, time)
        end
    else
        if has(times, time) then
            unpasteTimingPointPaste(group, time)
            pasteTimingPointGroup(group, time)
        end
    end
end

function updateScrollVelocityPaste()
end

function updateAllHitObjectPastes(layer)
    --buggy, causes weird undo history desync with game
    local times = retrieveHitObjectPasteData(layer)

    for i = 1, #times do
        updateHitObjectPaste(layer, times[i])
    end
end

function updateAllTimingPointPastes(group)
    local times = retrieveTimingPointPasteData(group)

    for _, time in pairs(times) do
        updateTimingPointPaste(group, time)
    end
end

function updateAllScrollVelocityPastes()
end

function unregisterAllHitObjectPastes(layer)
    local start = MEMORY_OFFSET + (layer - 1) + 3 * DATA_INCREMENT
    local stop = MEMORY_OFFSET + layer - DATA_INCREMENT

    memory.delete(start, stop, DATA_INCREMENT)
end

function unregisterAllTimingPointPastes(group)
    local start = MEMORY_OFFSET_2 + (group - 1) + 3 * DATA_INCREMENT
    local stop = MEMORY_OFFSET_2 + group - DATA_INCREMENT

    memory.delete(start, stop, DATA_INCREMENT)
end

function unregisterAllScrollVelocityPastes()
end

function unregisterHitObjectGroup(layer)
    local start = MEMORY_OFFSET + (layer - 1)
    local stop = start + 2 * DATA_INCREMENT

    memory.delete(start, stop, DATA_INCREMENT)
end

function unregisterTimingPointGroup(group)
    local start = MEMORY_OFFSET_2 + (group - 1)
    local stop = start + 2 * DATA_INCREMENT

    memory.delete(start, stop, DATA_INCREMENT)
end

function unregisterScrollVelocityGroup()
end

function updateHitObjectGroup(layer)
    unregisterHitObjectGroup(layer)
    registerHitObjectGroup(layer)
end

function updateTimingPointGroup(group, start, stop)
    unregisterTimingPointGroup(group)
    registerTimingPointGroup(group, start, stop)
end

function updateScrollVelocityGroup(group)
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

--[[
    Proposed structure of saving data:
    Integer offset (-10000, -9999, -9998): Type of object (HitObject, TimingPoint, SV) to copy.
        HitObject = layer, this actually isn't needed but whatever
        TimingPoint = -1
        SV = -2
    Int + Increment: Start
    Int + 2 Increments: End

    Int + 3-127 Increments: Locations to paste objects to.
]]

INITIALIZE_OFFSET = -100001
MEMORY_OFFSET = -100000 --hitobjects
MEMORY_OFFSET_2 = -50000 --nonhitobjects
MEMORY_LIMIT = -5000 --prevent SVs from being placed in the area that preceds start of map that player sees

DATA_INCREMENT = 2^-7 --smallest increment possible is 2^-7 (.0078125 ms), up to 128 entries per ms

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

menu = {}

function menu.HitObjects()
    --this is a mess
    if imgui.BeginTabItem("Hit Objects") then
        local layer = state.GetValue("layer") or 1

        _, layer = imgui.InputInt("Layer", layer)
        if layer < 1 then layer = 1 end

        if not retrieveHitObjectGroupData(layer)[1] then
            if imgui.Button("Register Layer") then
                registerHitObjectGroup(layer)
            end
        else
            if advanced then
                if imgui.Button("Unregister Layer") then
                    unregisterHitObjectGroup(layer)
                    unregisterAllHitObjectPastes(layer)
                end
            end

            if imgui.Button("Update Layer") then
                updateHitObjectGroup(layer)
            end

            if imgui.Button("Go to Layer") then
                local notes = getHitObjectsOnLayer(layer)
                actions.GoToObjects(hitObjectsToString(notes))
            end

            imgui.Separator()

            if imgui.Button("Paste Layer at Current Timestamp") then
                --need to implement check to make sure paste is able to be registered
                pasteHitObjectGroup(layer, state.SongTime)
            end

            if imgui.Button("Update Copy at Current Timestamp") then
                updateHitObjectPaste(layer, state.SongTime)
            end

            if imgui.Button("Remove Copy at Current Timestamp") then
                unpasteHitObjectPaste(layer, state.SongTime)
            end

            if advanced then
                if imgui.Button("Unregister Copy at Current Timestamp") then
                    unregisterHitObjectPaste(layer, state.SongTime)
                end
            end

            imgui.Separator()

            if imgui.Button("Update All Copies") then
                updateAllHitObjectPastes(layer)
            end
            imgui.SameLine(0, 4) imgui.TextWrapped("bugged")

            if imgui.Button("Remove All Copies") then
                unpasteAllHitObjectPastes(layer)
            end
            imgui.SameLine(0, 4) imgui.TextWrapped("bugged")

            if advanced then
                if imgui.Button("Unregister All Copies") then
                    unregisterAllHitObjectPastes(layer)
                end
            end
        end

        state.SetValue("layer", layer)
        imgui.EndTabItem()
    end
end

function menu.TimingPoints()
    if imgui.BeginTabItem("Timing Points") then
        local group = state.GetValue("group") or 1
        local start = state.GetValue("start") or 0
        local stop = state.GetValue("stop") or 0

        if imgui.Button("Current", {60, 20}) then start = state.SongTime end imgui.SameLine(0,4) _, start = imgui.InputFloat("Start", start, 1)
        if imgui.Button(" Current ", {60, 20}) then stop = state.SongTime end imgui.SameLine(0,4) _, stop = imgui.InputFloat("Stop", stop, 1)

        _, group = imgui.InputInt("Group", group)
        if group < 1 then group = 1 end

        if not retrieveTimingPointGroupData(group)[1] then
            if imgui.Button("Register Group") then
                registerTimingPointGroup(group, start, stop)
            end
        else
            if advanced then
                if imgui.Button("Unregister Group") then
                    unregisterTimingPointGroup(group)
                    unregisterAllTimingPointPastes(group)
                end
            end

            if imgui.Button("Update Group") then
                updateTimingPointGroup(group, start, stop)
            end

            if imgui.Button("Go to Group") then
            end

            imgui.Separator()

            if imgui.Button("Paste Group at Current Timestamp") then
                --need to implement check to make sure paste is able to be registered
                pasteTimingPointGroup(group, state.SongTime)
            end

            if imgui.Button("Update Copy at Current Timestamp") then
                updateTimingPointPaste(group, state.SongTime)
            end

            if imgui.Button("Remove Copy at Current Timestamp") then
                unpasteTimingPointPaste(group, state.SongTime)
            end

            if advanced then
                if imgui.Button("Unregister Copy at Current Timestamp") then
                    unregisterTimingPointPaste(group, state.SongTime)
                end
            end

            imgui.Separator()

            if imgui.Button("Update All Copies") then
                updateAllTimingPointPastes(group)
            end
            imgui.SameLine(0, 4) imgui.TextWrapped("bugged")

            if imgui.Button("Remove All Copies") then
                unpasteAllTimingPointPastes(group)
            end
            imgui.SameLine(0, 4) imgui.TextWrapped("bugged")

            if advanced then
                if imgui.Button("Unregister All Copies") then
                    unregisterAllTimingPointPastes(group)
                end
            end
        end

        state.SetValue("group", group)
        state.SetValue("start", start)
        state.SetValue("stop", stop)
        imgui.EndTabItem()
    end
end

function menu.ScrollVelocities()
    if imgui.BeginTabItem("SVs") then
        imgui.EndTabItem()
    end
end

function menu.Other()
    if imgui.BeginTabItem("Other") then
        imgui.EndTabItem()
    end
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

function draw()
    imgui.Begin("CopyPaste+", true, imgui_window_flags.AlwaysAutoResize)

    if memory.read(INITIALIZE_OFFSET) != 1 then
        imgui.TextWrapped("Please do not manually undo any action this plugin makes.")

        if imgui.Button("Initialize") then
            initialize()
        end

        return(0)
    end

    advanced = state.GetValue("advanced") or false

    debug = state.GetValue("debug") or "hi"

    imgui.BeginTabBar("Object Type")
    menu.HitObjects()
    menu.TimingPoints()
    menu.ScrollVelocities()
    menu.Other()
    imgui.EndTabBar()

    imgui.separator()

    if imgui.Button("Correct Displacement") then
        memory.correctDisplacement(MEMORY_LIMIT)
    end
    imgui.SameLine(0, 4) imgui.TextWrapped("For some reason seems to only work manually.")

    _, advanced = imgui.Checkbox("Advanced", advanced)

    state.IsWindowHovered = imgui.IsWindowHovered()

    imgui.TextWrapped(debug)

    state.SetValue("advanced", advanced)

    state.SetValue("debug", debug)

    imgui.End()
end
