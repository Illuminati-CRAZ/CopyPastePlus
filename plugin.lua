--this is probably all jank idk
memory = {}

MEMORY_INCREMENT = 0

--maybe i should change "offset" to "index"
function memory.write(offset, data, step, mirror)
    if type(data) != "number" and type(data) != "table" then
        return(offset) --return same offset to use since nothing is written
    end

    step = step or 1 --non-int step will be fine when utils.CreateScrollVelocity() accepts floats for StartTime
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

function tableToString(table)
    local result = ""

    for i,value in pairs(table) do
        result = result .. "[" .. i .. "]: " .. value .. ", "
    end
    result = result:sub(1,-3)

    return(result)
end

function hitObjectsToString(notes)
    result = ""

    for _, note in pairs(notes) do
        result = result .. note.StartTime .. "|" .. note.Lane .. ", "
    end
    result = result:sub(1,-3)

    return(result)
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------

function initialize()
    memory.write(INITIALIZE_OFFSET, 1)

    memory.correctDisplacement(MEMORY_LIMIT) --this only gives the correct multiplier now because there's no displacement
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
        if (start <= sv.StartTime) and (tp.StartTime <= stop) then
            table.insert(selection, sv)
        elseif sv.StartTime > stop then
            return(selection)
        end
    end
    return(selection)
end

function recordHitObjectGroup(layer)
    if retrieveHitObjectGroupData(layer)[1] then
        return(false)
    end

    local notes = getHitObjectsOnLayer(layer)

    local start = notes[1].StartTime
    local stop = notes[#notes].StartTime

    local data = {layer, start, stop} --there's actually not that much point in storing start and stop
    local offset = MEMORY_OFFSET + (layer - 1)

    memory.write(offset, data, DATA_INCREMENT)
end

function recordTimingPointGroup(group, start, stop)
end

function recordScrollVelocityGroup(group, start, stop)
end

function retrieveHitObjectGroupData(layer)
    local start = MEMORY_OFFSET + (layer - 1)
    local stop = MEMORY_OFFSET + layer - DATA_INCREMENT

    local data = memory.read(start, stop, DATA_INCREMENT)

    return(data)
end

function retrieveTimingPointGroupData(group)
end

function retrieveScrollVelocityGroupData(group)
end

--[[function retrieveHitObjects(layer)
    local notes = getHitObjectsOnLayer(layer)
end]]--

function retrieveTimingPoints(group)
end

function retrieveScrollVelocities(group)
end

function registerHitObjectPaste(layer, time)
    local data = retrieveHitObjectGroupData(layer)
    memory.write(MEMORY_OFFSET + (layer - 1) + #data * DATA_INCREMENT, time)
end

function registerTimingPointPaste(group, time)
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

function unregisterTimingPointPaste()
end

function unregisterScrollVelocityPaste()
end

function unpasteHitObjectGroup(layer, time)
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

function unpasteTimingPointGroup()
end

function unpasteScrollVelocityGroup()
end

function updateHitObjectGroup(layer, time)
    unpasteHitObjectGroup(layer, time)
    pasteHitObjectGroup(layer, time)
end

function updateTimingPointGroup()
end

function updateScrollVelocityGroup()
end

function updateAllHitObjectGroups(layer)
    local data = retrieveHitObjectGroupData(layer)
    for i = 4, #data do
        updateHitObjectGroup(layer, data[4]) --the stored pastes cycle
    end
end

function updateAllTimingPointGroups()
end

function updateAllScrollVelocityGroups()
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

function draw()
    imgui.Begin("CopyPaste+")

    state.IsWindowHovered = imgui.IsWindowHovered()

    if memory.read(INITIALIZE_OFFSET) != 1 then
        imgui.TextWrapped("Please do not manually undo any action this plugin makes.")

        if imgui.Button("Initialize") then
            initialize()
        end

        return(0)
    end

    local layer = state.GetValue("layer") or 1
    if layer < 1 then layer = 1 end

    debug = state.GetValue("debug") or "hi"

    _, layer = imgui.InputInt("Layer", layer)

    if imgui.Button("Register Layer") then
        recordHitObjectGroup(layer)
    end

    if imgui.Button("Go to Layer") then
        local notes = hitObjectsToString(getHitObjectsOnLayer(layer))
        actions.GoToObjects(notes)
    end

    if imgui.Button("Paste Layer at Current Timestamp") then
        --need to implement check to make sure paste is able to be registered
        pasteHitObjectGroup(layer, state.SongTime)
    end

    if imgui.Button("Remove Copy at Current Timestamp") then
        unpasteHitObjectGroup(layer, state.SongTime)
    end

    if imgui.Button("Update Copy") then
        updateHitObjectGroup(layer, state.SongTime)
    end

    if imgui.Button("Update All Copies") then
        updateAllHitObjectGroups(layer)
    end

    if imgui.Button("Correct Displacement") then
        memory.correctDisplacement(MEMORY_LIMIT)
    end

    imgui.TextWrapped(debug)

    state.SetValue("layer", layer)

    state.SetValue("debug", debug)

    imgui.End()
end
