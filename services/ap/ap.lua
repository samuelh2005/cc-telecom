local tArgs = { ... }

local function printUsage()
    local programName = arg[0] or (shell and shell.getRunningProgram and fs.getName(shell.getRunningProgram())) or "program"

    print("Usage:")
    print(programName .. " <apc_url> <apc_region> [ap_tx_channel] [ap_rx_channel]")
    print("Definitions:")
    print("apc_url: A valid APC URL, e.g. http://1.2.3.4:8080")
    print("apc_region: The region ID within the APC")
    print("ap_tx_channel: The channel to use for transmitting messages (default: 65123)")
    print("ap_rx_channel: The channel to use for receiving messages (default: 65124)")
    print("Example:")
    print(programName .. " http://127.0.0.1:8080 1 65123 65124")
end

if #tArgs < 2 then
    printUsage()
    return
end

local APC_URL = tostring(tArgs[1])
local APC_REGION = tostring(tArgs[2])

local CHANNEL_AP_TX = 65123
if tArgs[3] ~= nil then
    CHANNEL_AP_TX = tonumber(tArgs[3])
    if not CHANNEL_AP_TX then
        printError("Invalid ap_tx_channel.")
        printUsage()
        return
    end
end

local CHANNEL_AP_RX = 65124
if tArgs[4] ~= nil then
    CHANNEL_AP_RX = tonumber(tArgs[4])
    if not CHANNEL_AP_RX then
        printError("Invalid ap_rx_channel.")
        printUsage()
        return
    end
end

local CHANNEL_AP_ANNOUNCE = 65125

local RECONNECT_DELAY = 3
local ANNOUNCE_INTERVAL = 15
local MESSAGE_TTL = 30
local MAX_ATTEMPTS_PER_USG = 3

local reconnectTimer = nil
local wsHandle = nil
local wsConnected = false
local wsConnecting = false

local USG_URLS = {}
local currentUSGIndex = 1
local currentUSG = nil
local usgAttempts = 0

local function scheduleReconnect()
    if not reconnectTimer then
        reconnectTimer = os.startTimer(RECONNECT_DELAY)
    end
end

-- Find modems.
local tModems = {}
for _, sModem in ipairs(peripheral.getNames()) do
    if peripheral.getType(sModem) == "modem" then
        table.insert(tModems, sModem)
    end
end

if #tModems == 0 then
    error("No modems found.", 0)
end

local function lookupAPC()
    local response = http.get(APC_URL .. "/regions/" .. APC_REGION .. "?serviceType=usg")
    if not response then
        return false, "Failed to contact APC"
    end

    local body = response.readAll()
    response.close()

    local tResponse, err = textutils.unserializeJSON(body)
    if not tResponse then
        return false, "Failed to parse JSON response: " .. tostring(err)
    end

    local tURLs = {}
    if type(tResponse) == "table" then
        for _, entry in ipairs(tResponse) do
            if type(entry) == "table" and type(entry.address) == "string" then
                table.insert(tURLs, entry.address)
            end
        end
    end

    if #tURLs == 0 then
        return false, "No USG endpoints found"
    end

    USG_URLS = tURLs
    currentUSGIndex = 1
    currentUSG = USG_URLS[currentUSGIndex]
    usgAttempts = 0

    return true
end

local function openChannel(nChannel)
    for _, sModem in ipairs(tModems) do
        peripheral.call(sModem, "open", nChannel)
    end
end

local function closeChannel(nChannel)
    for _, sModem in ipairs(tModems) do
        peripheral.call(sModem, "close", nChannel)
    end
end

local function isValidPayload(tMessage)
    return type(tMessage) == "table"
        and type(tMessage.sPacketType) == "string"
        and type(tMessage.nMessageID) == "number"
        and type(tMessage.nUE) == "number"
        and tMessage.tMessage ~= nil
end

local function transmitToAllModems(channel, tMessage)
    for _, sModem in ipairs(tModems) do
        peripheral.call(sModem, "transmit", channel, 0, tMessage)
    end
end

-- De-duplication only, so we do not echo the same packet forever.
local seenMessages = {}
local seenTimeouts = {}

local function rememberMessage(nMessageID)
    if seenMessages[nMessageID] then
        print("Already seen message ID " .. tostring(nMessageID) .. ", ignoring.")
        return false
    end

    seenMessages[nMessageID] = true
    seenTimeouts[os.startTimer(MESSAGE_TTL)] = nMessageID
    return true
end

local function clearTimedMessage(nTimer)
    local nMessageID = seenTimeouts[nTimer]
    if nMessageID then
        seenTimeouts[nTimer] = nil
        seenMessages[nMessageID] = nil
    end
end

local function connectWebSocket()
    if wsConnected or wsConnecting or not currentUSG then
        return
    end

    wsConnecting = true
    print("Connecting to " .. currentUSG .. " (attempt " .. tostring(usgAttempts + 1) .. "/" .. tostring(MAX_ATTEMPTS_PER_USG) .. ")")
    http.websocketAsync(currentUSG)
end

local ok, err = pcall(function()
    openChannel(CHANNEL_AP_TX)
    openChannel(CHANNEL_AP_ANNOUNCE)

    print("0 packets proxied.")
    print("Looking up USGs...")

    local okLookup, lookupErr = lookupAPC()
    if not okLookup then
        printError(lookupErr)
        scheduleReconnect()
    else
        print("Connecting to WebSocket...")
        connectWebSocket()
    end

    local nPacketsForwarded = 0
    local announceTimer = os.startTimer(ANNOUNCE_INTERVAL)

    while true do
        local sEvent, p1, p2, p3, p4 = os.pullEvent()

        if sEvent == "modem_message" then
            local nChannel = p2
            local payload = p4

            if nChannel == CHANNEL_AP_TX and isValidPayload(payload) then
                if rememberMessage(payload.nMessageID) then
                    if wsConnected and wsHandle then
                        local sent, sendErr = pcall(function()
                            wsHandle.send(textutils.serializeJSON(payload))
                        end)

                        if not sent then
                            printError("WebSocket send failed: " .. tostring(sendErr))
                            wsConnected = false
                            wsHandle = nil
                            scheduleReconnect()
                        else
                            nPacketsForwarded = nPacketsForwarded + 1
                            local _, y = term.getCursorPos()
                            term.setCursorPos(1, y)
                            term.clearLine()
                            if nPacketsForwarded == 1 then
                                print("1 packet proxied.")
                            else
                                print(nPacketsForwarded .. " packets proxied.")
                            end
                        end
                    else
                        scheduleReconnect()
                    end
                end
            end

        elseif sEvent == "websocket_success" then
            local sURL = p1
            local handle = p2

            if sURL == currentUSG then
                wsConnecting = false
                wsConnected = true
                wsHandle = handle
                usgAttempts = 0

                if reconnectTimer then
                    os.cancelTimer(reconnectTimer)
                    reconnectTimer = nil
                end

                print("WebSocket connected.")
            end

        elseif sEvent == "websocket_failure" then
            local sURL = p1
            local sErr = p2

            if sURL == currentUSG then
                wsConnecting = false
                wsConnected = false
                wsHandle = nil

                printError("WebSocket connection failed: " .. tostring(sErr))

                usgAttempts = usgAttempts + 1

                if usgAttempts >= MAX_ATTEMPTS_PER_USG then
                    currentUSGIndex = currentUSGIndex + 1
                    usgAttempts = 0

                    if currentUSGIndex <= #USG_URLS then
                        currentUSG = USG_URLS[currentUSGIndex]
                    else
                        local okRefresh, refreshErr = lookupAPC()
                        if not okRefresh then
                            printError(refreshErr)
                            currentUSG = nil
                        end
                    end
                end

                scheduleReconnect()
            end

        elseif sEvent == "websocket_closed" then
            local sURL = p1

            if sURL == currentUSG then
                wsConnecting = false
                wsConnected = false
                wsHandle = nil

                printError("WebSocket disconnected; refreshing USG list.")

                local okRefresh, refreshErr = lookupAPC()
                if not okRefresh then
                    printError(refreshErr)
                    currentUSG = nil
                end

                scheduleReconnect()
            end

        elseif sEvent == "websocket_message" then
            local sURL = p1
            local sMessage = p2
            local bBinary = p3

            if sURL == currentUSG and not bBinary then
                local tMessage, jsonErr = textutils.unserializeJSON(sMessage)
                if not tMessage then
                    printError("Bad WebSocket JSON: " .. tostring(jsonErr))
                elseif isValidPayload(tMessage) and rememberMessage(tMessage.nMessageID) then
                    transmitToAllModems(CHANNEL_AP_RX, tMessage)
                end
            end

        elseif sEvent == "timer" then
            local nTimer = p1

            if seenTimeouts[nTimer] then
                clearTimedMessage(nTimer)

            elseif reconnectTimer and nTimer == reconnectTimer then
                reconnectTimer = nil

                if not currentUSG then
                    local okRefresh, refreshErr = lookupAPC()
                    if not okRefresh then
                        printError(refreshErr)
                        scheduleReconnect()
                    else
                        connectWebSocket()
                    end
                else
                    connectWebSocket()
                end

            elseif nTimer == announceTimer then
                local announcePacket = {
                    sPacketType = "announce",
                    nApID = os.getComputerID(),
                    nTXChannel = CHANNEL_AP_TX,
                    nRXChannel = CHANNEL_AP_RX,
                }
                transmitToAllModems(CHANNEL_AP_ANNOUNCE, announcePacket)
                announceTimer = os.startTimer(ANNOUNCE_INTERVAL)
            end

        elseif sEvent == "terminate" then
            break
        end
    end
end)

if wsHandle then
    pcall(function()
        wsHandle.close()
    end)
end

closeChannel(CHANNEL_AP_TX)
closeChannel(CHANNEL_AP_ANNOUNCE)

if not ok then
    printError(err)
end
