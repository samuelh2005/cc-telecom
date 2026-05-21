local lib_cellular = require("lib_cellular")

local function ue_loop()
    print("Sending message...")
    lib_cellular.send("Hello, World!", "my_protocol")

    while true do
        local nMessageID, tMessage, sProtocol, nReplyTo = lib_cellular.receive()
        if tMessage then
            if not nReplyTo then
                print("Received message (ID: " .. nMessageID .. ", Protocol: " .. sProtocol .. "):")
            else
                print("Received reply (ID: " .. nMessageID .. ", Protocol: " .. sProtocol .. ", ReplyTo: " .. nReplyTo .. "):")
            end
            print(textutils.serialize(tMessage))
            break
        end
    end
end

local ok, err = pcall(function()
    lib_cellular.init(ue_loop)
end)

if not ok then
    printError(err)
end