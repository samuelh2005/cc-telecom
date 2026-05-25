local lib_cellular = {}

local tModems = {}

local tSeenAPs = {}
local nCurrentAP = nil

local nChannelApTX = nil
local nChannelApRX = nil

local CHANNEL_AP_ANNOUNCE = 65125

local MSG_SEND_TIMEOUT = 15

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

local function transmit(nMsg_id, tMessage, sPacketType)
    local message_wrapper = {
        nMessageID = nMsg_id,
        nUE = os.getComputerID(),
        tMessage = tMessage,
        sPacketType = sPacketType,
    }

    for _, sModem in ipairs(tModems) do
        peripheral.call(sModem, "transmit", nChannelApTX, nChannelApRX, message_wrapper)
    end
end

local function ue_loop()
    while true do
        local sEvent, p1, p2, p3, p4, p5 = os.pullEvent()

        if sEvent == "modem_message" then
            local nChannel = p2
            local payload = p4
            local distance = p5

            if type(payload) == "table"
                and type(payload.sPacketType) == "string"
            then
                local sPacketType = payload.sPacketType

                if (nChannel == nChannelApRX) and sPacketType == "adp" then
                    local nMessageID = payload.nMessageID
                    local tMessage = payload.tMessage
                    local nReplyTo = payload.nReplyTo
                    local nUE = payload.nUE

                    if type(nMessageID) == "number"
                        and type(nUE) == "number"
                        and type(tMessage) == "table"
                        and (nReplyTo == nil or type(nReplyTo) == "number")
                        and nUE == os.getComputerID()
                        and type(tMessage.sDataService) == "string"
                        and type(tMessage.tPayload) == "table"
                    then
                        os.queueEvent("usp_b_message", payload)
                    end
                elseif (nChannel == CHANNEL_AP_ANNOUNCE) and sPacketType == "announce" then
                    local nApID = payload.nApID
                    local nTXChannel = payload.nTXChannel
                    local nRXChannel = payload.nRXChannel

                    if type(nApID) == "number"
                        and type(nTXChannel) == "number"
                        and type(nRXChannel) == "number"
                    then
                        tSeenAPs[nApID] = {nTXChannel, nRXChannel, distance}

                        if nCurrentAP and tSeenAPs[nCurrentAP] then
                            -- If we already have an AP, only switch if this one is closer
                            local current_distance = tSeenAPs[nCurrentAP][3]
                            if distance < current_distance then
                                closeChannel(nChannelApRX)
                                openChannel(nRXChannel)
                                nChannelApTX = nTXChannel
                                nChannelApRX = nRXChannel
                                nCurrentAP = nApID
                                print("Switched to closer AP " .. nApID .. " at distance " .. distance)
                            end
                        else
                            -- If we don't have an AP yet, connect to this one
                            openChannel(nRXChannel)
                            nChannelApTX = nTXChannel
                            nChannelApRX = nRXChannel
                            nCurrentAP = nApID
                            print("Connected to AP " .. nApID .. " at distance " .. distance)
                        end
                    end
                end
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

    openChannel(CHANNEL_AP_ANNOUNCE)

    local ok, err = pcall(function()
        parallel.waitForAny(ue_loop, user_func)
    end)

    closeChannel(CHANNEL_AP_ANNOUNCE)
    if nChannelApRX then
        closeChannel(nChannelApRX)
    end

    if not ok then
        error(err, 0)
    end
end

function lib_cellular.send(message, dataService)
    if type(message) ~= "table" then
        error("Message must be a table.", 2)
    end

    if type(dataService) ~= "string" then
        error("Data service must be a string.", 2)
    end

    local usp_b_wrapper = {
        sDataService = dataService,
        tPayload = message,
    }

    if nCurrentAP == nil then
        local timer_id = os.startTimer(MSG_SEND_TIMEOUT)
        while true do
            local sEvent, p1, p2, p3, p4 = os.pullEvent()
            if sEvent == "timer" and p1 == timer_id then
                if nCurrentAP == nil then
                    error("No AP in range. Cannot send message.", 0)
                else
                    break
                end
            end
        end
    end

    local msg_id = math.random(1, 2147483647)
    transmit(msg_id, usp_b_wrapper, "adp")
    return msg_id
end

function lib_cellular.receive(timeout)
    local timer_id
    if timeout then
        timer_id = os.startTimer(timeout)
    end

    while true do
        local sEvent, p1, p2, p3, p4 = os.pullEvent()

        if sEvent == "usp_b_message" then
            local nMessageID = p1.nMessageID
            local tMessage = p1.tMessage
            local nReplyTo = p1.nReplyTo

            local tPayload = tMessage.tPayload
            local sDataService = tMessage.sDataService

            return nMessageID, tPayload, sDataService, nReplyTo
        elseif sEvent == "timer" and p1 == timer_id then
            return nil
        end
    end
end

return lib_cellular