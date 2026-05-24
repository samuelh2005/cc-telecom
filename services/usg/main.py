import asyncio
import json
import random
import websockets

def new_message_id():
    return random.randint(1, 2147483647)

async def handler(websocket):
    print("Client connected")

    try:
        async for message in websocket:
            print(f"Received: {message}")

            t = json.loads(message)

            if not t["sPacketType"] == "usp_b":
                print("Invalid packet type, ignoring")
                continue

            tMessage = t.get("tMessage", {})
            if not isinstance(tMessage, dict):
                print("Invalid tMessage format, ignoring")
                continue

            tPayload = tMessage.get("tPayload", {})

            if not isinstance(tPayload, dict):
                print("Invalid tPayload format, ignoring")
                continue

            sDataService = tMessage.get("sDataService", None)

            if not isinstance(sDataService, str):
                print("Invalid sDataService format, ignoring")
                continue

            reply = {
                "nMessageID": new_message_id(),
                "nUE": t["nUE"],
                "nReplyTo": t["nMessageID"],
                "tMessage": {
                    "sDataService": sDataService,
                    "tPayload": tPayload
                },
                "sPacketType": t["sPacketType"]
            }

            await websocket.send(json.dumps(reply))

    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    async with websockets.serve(handler, "0.0.0.0", 80):
        print("WebSocket server running on ws://0.0.0.0:80")
        await asyncio.Future()

asyncio.run(main())
