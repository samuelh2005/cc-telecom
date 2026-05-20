local expect = dofile("rom/modules/main/cc/expect.lua").expect

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

local function send(message, protocol)
    local message_wrapper = {
        nMessageID = math.random(1, 2147483647),
        nUE = os.getComputerID(),
        tMessage = message,
        sProtocol = protocol,
    }

    for _, sModem in ipairs(tModems) do
        peripheral.call(sModem, "transmit", CHANNEL_WSG_TX, CHANNEL_WSG_RX, message_wrapper)
    end
end

local ok, err = pcall(function()
    openChannel(CHANNEL_WSG_RX)

    print("Sending message...")
    send("Hello, World!", "my_protocol")

    while true do
        local sEvent, p1, p2, p3, p4 = os.pullEvent()

        if sEvent == "modem_message" then
            local nChannel = p2
            local tMessage = p4

            if nChannel == CHANNEL_WSG_RX
                and type(tMessage) == "table"
                and tMessage.nUE == os.getComputerID()
            then
                print(textutils.serialize(tMessage))
                break
            end
        end
    end
end)

closeChannel(CHANNEL_WSG_RX)

if not ok then
    printError(err)
end