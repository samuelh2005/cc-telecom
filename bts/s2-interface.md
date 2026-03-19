# The S2 Interface (Layer 1)

The S2 interface defines communication between the Base Transceiver Station (BTS) and the Core Network Gateway (CNG).

**Transport Layer**: [WebSocket API](https://tweaked.cc/module/http.html#v:websocket)

All S2 packets use the common Layer 1 packet structure below and are sent as plain JSON because the BTS is already trusted by the CNG.

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `type` | string | Packet type identifier. |
| `sequenceNumber` | number | Incremental sequence number for tracking packet order and retransmissions. Responses should include the same sequence number as the original request. |
| `timestamp` | number | UNIX timestamp when the packet was created; used for latency and timeout tracking. |
| `payload` | object | Packet-specific data object; structure depends on `type`. |

## Part 1: Towards BTS (from CNG)

Packet types:
- [**`Data_Downlink`**](#111-data_downlink-payload-structure)
- [**`Attachment_Result`**](#112-attachment_result-payload-structure)

### 1.1.1: `Data_Downlink` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `service` | string | Layer 2 Service Identifier |
| `data` | string | Payload data encoded as a Base64 string for safe transmission over the WebSocket. |
| `ueId` | number | UE identifier for the intended recipient of this downlink data. |

### 1.1.2: `Attachment_Result` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `ueId` | number | UE identifier. |
| `accepted` | boolean | Indicates whether the CNG accepted the UE on this BTS. |
| `verificationToken` | string\|null | Verification token for the UE to use when encrypting and protecting all later UE-to-BTS packets and Layer 2 data links when `accepted` is `true`. |
| `expiresAt` | number\|null | UNIX timestamp when the verification token expires. |

## Part 2: Towards CNG (from BTS)

Packet types:
- [**`Data_Uplink`**](#211-data_uplink-payload-structure)
- [**`Session_Update`**](#212-session_update-payload-structure)

### 2.1.1: `Data_Uplink` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `service` | string | Layer 2 Service Identifier |
| `data` | string | Payload data encoded as a Base64 string for safe transmission over the WebSocket. |
| `ueId` | number | UE identifier for the source of this uplink data. |

### 2.1.2: `Session_Update` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `ueId` | number | UE identifier. |
| `state` | string | Session state, `"Attached"`, `"Idle"`, `"Detached"`. |
| `btsId` | number | BTS currently serving the UE. |
