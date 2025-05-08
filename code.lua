if syn and syn.request then request = syn.request end
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

-- Initialize folder and JobId storage
if not isfolder(folderpath) then
    makefolder(folderpath)
    print("Created Folder", folderpath)
end

local data
if isfile(JobIdStorage) then
    data = jsond(readfile(JobIdStorage))
else
    data = { JobIds = {} }
    writefile(JobIdStorage, jsone(data))
    print("Created File", JobIdStorage)
end

-- Function to pretty-print
local function prettyPrintArray(arr)
    if #arr == 0 then
        return "[]"
    end

    local lines = { "[" }
    for i, entry in ipairs(arr) do
        local formattedLine = "    { Time: " .. entry.Time .. ", JobID: " .. entry.JobID .. " }," .. (i == #arr and "" or ",")
        table.insert(lines, formattedLine)
    end
    table.insert(lines, "]")
    return table.concat(lines, "\n")
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
    writefile(JobIdStorage, jsone(data))
end

-- Add current JobId to the blacklist
cleanOldJobIds()
local currentTime = os.time()
if not table.find(data.JobIds, function(entry) return entry.JobID == JobId end) then
    table.insert(data.JobIds, { Time = currentTime, JobID = JobId })
    writefile(JobIdStorage, prettyPrintArray(data.JobIds))
end

-- Wait for game to load
repeat task.wait() until game:IsLoaded() and Players.LocalPlayer
local lp = Players.LocalPlayer

-- Load script
local success, errorMsg = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/rift-sniper/Rift-Sniper-V3/refs/heads/main/code.lua"))()
end)

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
    task.wait()
end

-- Teleport to a random server
while #servers > 0 do
    local random = servers[math.random(1, #servers)]
    print("Joining New Server...\n")
    TeleportService:TeleportToPlaceInstance(PlaceId, random, lp)
    task.wait(1)
end
