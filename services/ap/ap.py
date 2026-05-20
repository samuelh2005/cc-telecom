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

            reply = {
                "nMessageID": new_message_id(),
                "nUE": t["nUE"],
                "nReplyTo": t["nMessageID"],
                "tMessage": f"Server got: {t['tMessage']}",
                "sProtocol": t["sProtocol"]
            }

            await websocket.send(json.dumps(reply))

    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    async with websockets.serve(handler, "0.0.0.0", 80):
        print("WebSocket server running on ws://0.0.0.0:80")
        await asyncio.Future()

asyncio.run(main())
