# The S1 Interface (Layer 1)

The S1 interface defines communication between the User Equipment (UE) and the Base Transceiver Station (BTS).

**Transport Layer**: [Modem API](https://tweaked.cc/peripheral/modem.html)

All S1 packets use the common Layer 1 packet structure below and are encoded with `textutils.serializeJSON` and `textutils.unserializeJSON`.

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `type` | string | Packet type identifier. |
| `sequenceNumber` | number | Incremental sequence number for tracking packet order and retransmissions. Responses should include the same sequence number as the original request. |
| `timestamp` | number | UNIX timestamp when the packet was created; used for latency and timeout tracking. |
| `payload` | object | Packet-specific data object; structure depends on `type`. |

S1 uses two packet encodings:
- Initial registration packets are sent as plain JSON because the UE does not yet have a verification token.
- After registration, every UE-to-BTS packet is serialized as JSON using the same logical structure, then encrypted and protected as a single opaque value using the verification token issued in `Attachment_Accept`. The BTS validates this protected value and derives the UE identity from the verified token.

The S1 interface uses 40 modem channels:
- `45001-45020` are reserved for UE-to-BTS communication.
- `46001-46020` are reserved for BTS-to-UE communication.

Each BTS should listen on a chosen 5 channels in each range to reduce conflicts by neighbouring BTS choosing different channels.

## Part 1: Towards UE (from BTS)

Packet types:
- [**`Data_Downlink`**](#111-data_downlink-payload-structure)
- [**`Paging`**](#112-paging-payload-structure)
- [**`BTS_Announcement`**](#113-bts_announcement-payload-structure)
- [**`Attachment_Accept`**](#114-attachment_accept-payload-structure)

### 1.1.1: `Data_Downlink` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `service` | string | Layer 2 Service Identifier |
| `data` | string | Payload data encoded as a Base64 string for safe transmission over the modem. |

### 1.1.2: `Paging` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| (none) | null | This payload is `null` - there are no fields for `Paging`. |

### 1.1.3: `BTS_Announcement` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `txChannels` | array<number> | Array of modem channels the BTS is transmitting on. |
| `rxChannels` | array<number> | Array of modem channels the BTS is receiving on. |
| `distance` | number | Estimated distance from the UE to this BTS in blocks. |

### 1.1.4: `Attachment_Accept` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `verificationToken` | string | Verification token issued by the CNG for the UE to include in Layer 2 data links. |
| `expiresAt` | number | UNIX timestamp when the verification token expires. |

## Part 2: Towards BTS (from UE)

Packet types:
- [**`Data_Uplink`**](#211-data_uplink-payload-structure)
- [**`Attachment`**](#212-attachment-payload-structure)
- [**`Detachment`**](#213-detachment-payload-structure)
- [**`Paging_Response`**](#214-paging_response-payload-structure)

### 2.1.1: `Data_Uplink` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| `service` | string | Layer 2 Service Identifier |
| `data` | string | Payload data encoded as a Base64 string for safe transmission over the modem. |

### 2.1.2: `Attachment` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| (none) | null | This payload is `null` - there are no fields for `Attachment`. |

### 2.1.3: `Detachment` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| (none) | null | This payload is `null` - there are no fields for `Detachment`. |

### 2.1.4: `Paging_Response` payload structure

| **Field name** | **Type** | **Description** |
|---|---:|---|
| (none) | null | This payload is `null` - there are no fields for `Paging_Response`. |
