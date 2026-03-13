## Network Architecture

Whilst there is no physical limitations in-game, the UE could theoretically connect to the CNG directly, however for the sake of realism and to provide a more immersive experience, the UE is designed to connect to the CNG via the BTS nodes. This allows for a more realistic representation of how cellular networks operate in the real world, where mobile devices connect to nearby cell towers (BTS) which then route traffic to the core network (CNG).

There are two protocols provided by CC: Tweaked that will be used extensively as a low-level transport layer for communications, this includes the [Modem API](https://tweaked.cc/peripheral/modem.html) for communication between the UE and BTS, and the [WebSocket API](https://tweaked.cc/module/http.html#v:websocket) for communication between the BTS and CNG.

For performance reasons, the core network will be implemented out-of-game as a standalone server application, which the in-game BTS nodes will connect to via WebSocket connections. This allows for more efficient handling of network traffic and reduces the load on the game server, while still providing a realistic and immersive experience for players. The Modem API is favored for communication instead of Rednet as the Modem API is more low-level and provides better performance for the types of data being transmitted between the UE and BTS.

### Core Network Gateway (CNG) *External*

Serves as the interface between the radio access network and the core network.

It is responsible for:
1. Managing and routing traffic between the BTS nodes and the core network. (BSC)
2. Handling authentication and security for the network. (HSS)
3. Providing various network services such as SMS, voice calls, and data connectivity. (SMSC, ...)
4. Handling mobility management for the UEs, including handovers between BTS nodes as the UE moves around. (MME)

### Base Transceiver Station (BTS) *In-Game*

Acts as a dumb bridge between the User Equipment (UE) and the CNG. This will be implemented as a computer with modem peripherals running the BTS software.

It is responsible for:
1. Transmitting and receiving modem signals to and from the UE.
2. Connecting to the NG via WebSocket connections.
3. Relaying data between the UE and the CNG.

[**BTS-CNG Protocol Reference**](./bts/BTS-CNG.md)

### User Equipment (UE) *In-Game*

Represents the mobile devices used by players to connect to the network. UEs can be pocket computers, turtles, or any other type of mobile device that is capable of connecting to a modem network. UEs communicate with the BTS nodes via modem signals, and are responsible for sending and receiving data to and from the network. Each UE is associated with a specific BTS node, which serves as its point of connection to the network.

[**UE-BTS Protocol Reference**](./ue/UE-BTS.md)
