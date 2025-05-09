print("\nNew Server Joined")

if request then request = request end
assert(typeof(request) and typeof(isfile) and typeof(makefolder) and typeof(isfolder) and typeof(readfile) and typeof(writefile) == 'function', "Missing functions")

local game = game
local PlaceId = game.PlaceId
local JobId = game.JobId
local folderpath = "RiftSniperV3"
local JobIdStorage = folderpath .. "\\JobIdStorage.json"
local Players = game:FindService("Players")
local http = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- Configurable time wait for clearing servers from blacklist (in seconds)
local BLACKLIST_CLEAR_INTERVAL = 600

local function jsone(str) return http:JSONEncode(str) end
local function jsond(str) return http:JSONDecode(str) end

-- Safe JSON decode function
local function safeJsond(str, context)
    local success, result = pcall(function()
        return http:JSONDecode(str)
    end)
    if success then
        return result
    else
        warn("JSON decode error in", context, "Error:", result, "Input:", str)
        return nil
    end
end

-- Initialize folder and JobId storage
if not isfolder(folderpath) then
    makefolder(folderpath)
    print("Created Folder", folderpath)
end

local data
if isfile(JobIdStorage) then
    local content = readfile(JobIdStorage)
    data = safeJsond(content, "JobIdStorage read")
    if not data or not data.JobIds then
        warn("Failed to parse JobIdStorage or invalid format, resetting to default")
        data = { JobIds = {} }
        pcall(function()
            writefile(JobIdStorage, jsone(data))
        end)
    end
else
    data = { JobIds = {} }
    pcall(function()
        writefile(JobIdStorage, jsone(data))
    end)
    print("Created File", JobIdStorage)
end

-- Function to clean old JobIDs
local function cleanOldJobIds()
    local currentTime = os.time()
    local tenMinutesAgo = currentTime - BLACKLIST_CLEAR_INTERVAL
    local newJobIds = {}
    for _, entry in ipairs(data.JobIds) do
        if entry.Time > tenMinutesAgo then
            table.insert(newJobIds, entry)
        end
    end
    data.JobIds = newJobIds
    pcall(function()
        writefile(JobIdStorage, jsone(data))
    end)
end

-- Add current JobId to the blacklist
cleanOldJobIds()
local currentTime = os.time()
local function hasJobId(jobId)
    for _, entry in ipairs(data.JobIds) do
        if entry.JobID == jobId then
            return true
        end
    end
    return false
end
if not hasJobId(JobId) then
    table.insert(data.JobIds, { Time = currentTime, JobID = JobId })
    pcall(function()
        writefile(JobIdStorage, jsone(data))
    end)
end

-- Wait for game to load
repeat task.wait() until game:IsLoaded() and Players.LocalPlayer
local lp = Players.LocalPlayer

-- Load script
loadstring(game:HttpGet("https://raw.githubusercontent.com/rift-sniper/Rift-Sniper-V3/refs/heads/main/code.lua"))()

-- Server hopping logic
local servers = {}
local cursor = ''
while cursor and #servers <= 0 do
    local req = request({Url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&cursor%s"):format(PlaceId, cursor)})
    local body = jsond(req.Body)
    if body and body.data then
        coroutine.wrap(function()
            for i, v in next, body.data do
                if typeof(v) == 'table' and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and not table.find(data['JobIds'], v.id) then
                    table.insert(servers, 1, v.id)
                end
            end
        end)()
        if body.nextPageCursor then
            cursor = body.nextPageCursor
        else
            cursor = nil
        end
    end
    task.wait(1)
end

-- Teleport to a random server
if #servers > 0 then
    local randomJobId = servers[math.random(1, #servers)]
    local success, errorMsg = pcall(function()
        game:GetService('TeleportService'):TeleportToPlaceInstance(PlaceId, randomJobId, lp)
    end)
    if not success then
        warn("Teleport failed:", errorMsg)
    end
end
