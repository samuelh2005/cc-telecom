local tArgs = { ... }

local function printUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " <ws_url>")
    print("Example:")
    print(programName .. " ws://1.2.3.4:80/ws")
end

if #tArgs == 0 then
    printUsage()
    return
end

local WS_URL = tArgs[1]
local RECONNECT_DELAY = 5
local MESSAGE_TTL = 30

local CHANNEL_WSG_TX = 65123
local CHANNEL_WSG_RX = 65124

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

local function isValidRednetWrapper(tMessage)
    return type(tMessage) == "table"
        and type(tMessage.sProtocol) == "string"
        and type(tMessage.nMessageID) == "number"
        and type(tMessage.nUE) == "number"
        and tMessage.tMessage ~= nil
end

local function transmitToAllModems(nChannel, tMessage)
    for _, sModem in ipairs(tModems) do
        peripheral.call(sModem, "transmit", nChannel, 0, tMessage)
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

    print("Received message from WebSocket: " .. tostring(sMessage))

    if not isValidRednetWrapper(tMessage) then
        return
    end

    if not rememberMessage(tMessage.nMessageID) then
        return
    end

    transmitToAllModems(CHANNEL_WSG_RX, tMessage)
end

local ok, err = pcall(function()
    openChannel(CHANNEL_WSG_TX)

    print("0 packets proxied.")
    print("Connecting to WebSocket...")
    connectWebSocket()

    local nPacketsForwarded = 0

    while true do
        local sEvent, p1, p2, p3, p4 = os.pullEvent()

        if sEvent == "modem_message" then
            local nChannel = p2
            local tMessage = p4

            if nChannel == CHANNEL_WSG_TX and isValidRednetWrapper(tMessage) then
                if rememberMessage(tMessage.nMessageID) then
                    local sent, sendErr = sendWrapperToWebSocket(tMessage)
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
            end

        elseif sEvent == "terminate" then
            break
        end
    end
end)

if wsHandle then
    pcall(function() wsHandle.close() end)
end

closeChannel(CHANNEL_WSG_TX)

if not ok then
    printError(err)
end