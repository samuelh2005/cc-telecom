local tArgs = { ... }

local function printUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " <ws_url> [ap_tx_channel] [ap_rx_channel]")
    print("Definitions:")
    print("ws_url: A valid WebSocket URL, e.g., ws://1.2.3.4:80/ws")
    print("ap_tx_channel: The channel to use for transmitting messages (default: 65123)")
    print("ap_rx_channel: The channel to use for receiving messages (default: 65124)")
    print("Example:")
    print(programName .. " ws://127.0.0.1:8080/ws 65123 65124")
end

if #tArgs == 0 then
    printUsage()
    return
end

local WS_URL = tArgs[1]
local RECONNECT_DELAY = 5
local ANNOUNCE_INTERVAL = 15
local MESSAGE_TTL = 30

local CHANNEL_AP_TX = tArgs[2] or 65123
local CHANNEL_AP_RX =  tArgs[3] or 65124
local CHANNEL_AP_ANNOUNCE = 65125

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

local wsHandle = nil
local wsConnected = false
local wsConnecting = false
local reconnectTimer = nil

local function scheduleReconnect()
    if not reconnectTimer then
        reconnectTimer = os.startTimer(RECONNECT_DELAY)
    end
end

local function connectWebSocket()
    if wsConnected or wsConnecting then
        return
    end
    wsConnecting = true
    http.websocketAsync(WS_URL)
end

local function sendWrapperToWebSocket(tMessage)
    if not wsConnected or not wsHandle then
        return false, "WebSocket not connected"
    end

    local ok, err = pcall(function()
        wsHandle.send(textutils.serializeJSON(tMessage))
    end)

    if not ok then
        return false, err
    end

    return true
end

local function handleWebSocketMessage(sMessage, bBinary)
    if bBinary then
        return
    end

    local tMessage, err = textutils.unserializeJSON(sMessage)
    if not tMessage then
        printError("Bad WebSocket JSON: " .. tostring(err))
        return
    end

    if not isValidPayload(tMessage) then
        return
    end

    if not rememberMessage(tMessage.nMessageID) then
        return
    end

    transmitToAllModems(CHANNEL_AP_RX, tMessage)
end

local ok, err = pcall(function()
    openChannel(CHANNEL_AP_TX)
    openChannel(CHANNEL_AP_ANNOUNCE)

    print("0 packets proxied.")
    print("Connecting to WebSocket...")
    connectWebSocket()

    local nPacketsForwarded = 0
    local announceTimer = os.startTimer(ANNOUNCE_INTERVAL)

    while true do
        local sEvent, p1, p2, p3, p4 = os.pullEvent()

        if sEvent == "modem_message" then
            local nChannel = p2
            local payload = p4

            if nChannel == CHANNEL_AP_TX and isValidPayload(payload) then
                if rememberMessage(payload.nMessageID) then
                    local sent, sendErr = sendWrapperToWebSocket(payload)
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
                end
            end

        elseif sEvent == "websocket_success" then
            local sURL = p1
            local handle = p2

            if sURL == WS_URL then
                wsConnecting = false
                wsConnected = true
                wsHandle = handle
                if reconnectTimer then
                    os.cancelTimer(reconnectTimer)
                    reconnectTimer = nil
                end
                print("WebSocket connected.")
            end

        elseif sEvent == "websocket_failure" then
            local sURL = p1
            local sErr = p2

            if sURL == WS_URL then
                wsConnecting = false
                wsConnected = false
                wsHandle = nil
                printError("WebSocket connection failed: " .. tostring(sErr))
                scheduleReconnect()
            end

        elseif sEvent == "websocket_closed" then
            local sURL = p1

            if sURL == WS_URL then
                wsConnecting = false
                wsConnected = false
                wsHandle = nil
                scheduleReconnect()
            end

        elseif sEvent == "websocket_message" then
            local sURL = p1
            local sMessage = p2
            local bBinary = p3

            if sURL == WS_URL then
                handleWebSocketMessage(sMessage, bBinary)
            end

        elseif sEvent == "timer" then
            local nTimer = p1

            if seenTimeouts[nTimer] then
                clearTimedMessage(nTimer)

            elseif reconnectTimer and nTimer == reconnectTimer then
                reconnectTimer = nil
                connectWebSocket()

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
    pcall(function() wsHandle.close() end)
end

closeChannel(CHANNEL_AP_TX)
closeChannel(CHANNEL_AP_ANNOUNCE)

if not ok then
    printError(err)
end