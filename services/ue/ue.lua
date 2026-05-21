local lib_cellular = require("lib_cellular")

local function ue_loop()
    print("Sending message...")
    lib_cellular.send("Hello, World!")

    while true do
        local nMessageID, tMessage, nReplyTo = lib_cellular.receive()
        if tMessage then
            if not nReplyTo then
                print("Received message (ID: " .. nMessageID .. "):")
            else
                print("Received reply (ID: " .. nMessageID .. ", ReplyTo: " .. nReplyTo .. "):")
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