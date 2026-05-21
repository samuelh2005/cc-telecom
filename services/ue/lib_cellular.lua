local lib_cellular = {}

local tModems = {}

local CHANNEL_AP_TX = 65123
local CHANNEL_AP_RX = 65124

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

local function ue_loop()
    while true do
        local sEvent, p1, p2, p3, p4 = os.pullEvent()

        if sEvent == "modem_message" then
            local nChannel = p2
            local payload = p4

            if nChannel == CHANNEL_AP_RX
                and type(payload) == "table"
                and type(payload.nMessageID) == "number"
                and type(payload.nUE) == "number"
                and type(payload.tMessage) ~= "nil"
                and type(payload.sProtocol) == "string"
                and (payload.nReplyTo == nil or type(payload.nReplyTo) == "number")
                and payload.nUE == os.getComputerID()
            then
                os.queueEvent("cellular_message", payload)
            end
        end
    end
end

function lib_cellular.init(user_func)
    for _, sModem in ipairs(peripheral.getNames()) do
        if peripheral.getType(sModem) == "modem" then
            table.insert(tModems, sModem)
        end
    end

    if #tModems == 0 then
        error("No modems found.", 0)
    end

    openChannel(CHANNEL_AP_RX)

    local ok, err = pcall(function()
        parallel.waitForAny(user_func, ue_loop)
    end)

    closeChannel(CHANNEL_AP_RX)

    if not ok then
        error(err, 0)
    end
end

function lib_cellular.send(message, protocol)
    local msg_id = math.random(1, 2147483647)
    local message_wrapper = {
        nMessageID = msg_id,
        nUE = os.getComputerID(),
        tMessage = message,
        sProtocol = protocol,
    }

    for _, sModem in ipairs(tModems) do
        peripheral.call(sModem, "transmit", CHANNEL_AP_TX, CHANNEL_AP_RX, message_wrapper)
    end

    return msg_id
end

function lib_cellular.receive(timeout)
    local timer_id
    if timeout then
        timer_id = os.startTimer(timeout)
    end

    while true do
        local sEvent, p1, p2, p3, p4 = os.pullEvent()

        if sEvent == "cellular_message" then
            local nMessageID = p1.nMessageID
            local tMessage = p1.tMessage
            local sProtocol = p1.sProtocol
            local nReplyTo = p1.nReplyTo

            return nMessageID, tMessage, sProtocol, nReplyTo
        elseif sEvent == "timer" and p1 == timer_id then
            return nil
        end
    end
end

return lib_cellular