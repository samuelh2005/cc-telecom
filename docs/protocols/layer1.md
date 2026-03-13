# Layer 1: UE-BTS <> BTS-CNG Protocol

Responsibilities of this layer:
- Define the communication protocols between the UE and BTS, and between the BTS and CNG.
- Handle the transmission of data between the UE and CNG via the BTS nodes.
- UE session tracking within the BTS nodes, to ensure that data is correctly routed to the appropriate UE as sent to the BTS from the CNG.
- Attachment and detachment of UEs to the network, excluding authentication, security, and mobility management which is handled by the CNG.
- Packet state tracking and retransmission between the UE, BTS, and CNG to ensure reliable data transmission.

All packets are encoded as JSON serialized strings using `textutils.serializeJSON` and `textutils.unserializeJSON` functions.

## Part 1: Packet Structure

All packets sent between the UE, BTS, and CNG will follow a common structure to ensure consistency and ease of parsing. The general structure of a packet is as follows:

```json
{
  "type": "PacketType",
  "sourceUE": 1, // ID of the source UE, as reported by os.getComputerID() on the UE side, or null if the packet is from the BTS or CNG
  "sequenceNumber": 1, // Incremental sequence number for tracking packet order and retransmissions, every response to a packet should include the same sequence number as the original request packet
  "timestamp": 1234567890,
  "payload": {
    // Packet-specific data goes here
  }
}
```

## Part 2: UE-BTS

**Transport Layer**: [Modem API](https://tweaked.cc/peripheral/modem.html)

### 2.1: Towards UE (from BTS)

Packet types:
- [**`Acknowledgement`**](#211-acknowledgement-packet)
- [**`Data_Downlink`**](#212-data_downlink-packet)
- [**`UE_Handover`**](#213-ue_handover-packet)

#### 2.1.1: `Acknowledgement` packet

#### 2.1.2: `Data_Downlink` packet

#### 2.1.3: `UE_Handover` packet

### 2.2: Towards BTS (from UE)

Packet types:
- [**`Acknowledgement`**](#221-acknowledgement-packet)
- [**`Data_Uplink`**](#222-data_uplink-packet)
- [**`UE_Attachment`**](#223-ue_attachment-packet)
- [**`UE_Detachment`**](#224-ue_detachment-packet)
- [**`UE_Measurement_Report`**](#225-ue_measurement_report-packet)

#### 2.2.1: `Acknowledgement` packet

#### 2.2.2: `Data_Uplink` packet

#### 2.2.3: `UE_Attachment` packet

#### 2.2.4: `UE_Detachment` packet

#### 2.2.5: `UE_Measurement_Report` packet

## Part 3: BTS-CNG

**Transport Layer**: [WebSocket API](https://tweaked.cc/module/http.html#v:websocket)

### 3.1: Towards BTS (from CNG)

Packet types:
- **`Data_Downlink`**
- **`UE_Handover`**

#### 3.1.1: `Data_Downlink` packet

#### 3.1.2: `UE_Handover` packet

### 3.2: Towards CNG (from BTS)

Packet types:
- [**`Data_Uplink`**](#321-data_uplink-packet)
- [**`UE_Session_Update`**](#322-ue_session_update-packet)
- [**`UE_Measurement_Report`**](#323-ue_measurement_report-packet)

#### 3.2.1: `Data_Uplink` packet

#### 3.2.2: `UE_Session_Update` packet

#### 3.2.3: `UE_Measurement_Report` packet

