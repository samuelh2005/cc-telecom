# BTS ↔ Network Gateway Interface

## Network Gateway Protocol (NGP)

**Purpose:**

* Forward UE attach/authentication requests to the external WebSocket HSS.
* Route user-plane traffic to and from applications/services.
* Provide mobility context for handovers between BTS nodes.
* Maintain lightweight UE state locally for fast response.

**Transport:** WebSocket (JSON over TCP).

**Scope:** Only between BTS nodes and the Network Gateway.

## 1. BTS Identity

Each BTS must announce itself to the Network Gateway:

```
BTS_HELLO
{
  cell_id
  network_id
  capabilities
}
```

Purpose:

* Allow the Network Gateway to track active BTS nodes.
* Inform the gateway of supported features (e.g., bearer types, max UE count).

Timeout:

```
30 seconds
```

If no HELLO is received, the BTS is marked offline.

## 2. UE Authentication & Attach

When a UE attempts to attach:

### BTS → Gateway:

```
AUTH_REQUEST
{
  imsi
  rand
  serving_cell
}
```

The Network Gateway (HSS) responds with:

```
AUTH_CHALLENGE
{
  rand
}
```

### UE → BTS → Gateway:

```
AUTH_RESPONSE
{
  imsi
  response
}
```

The gateway validates the response against stored keys (Ki).

### Gateway → BTS:

```
ATTACH_ACCEPT
{
  imsi
  bearer_id
  assigned_qos
}
```

The BTS can now transition the UE to **IDLE** state and record the UE context locally.

## 3. UE Context Synchronization

The Network Gateway maintains a master UE context database.

BTS keeps a local copy:

```
UE_CONTEXT
{
  imsi
  bearer_id
  connection_state
  serving_cell
  qos
}
```

BTS updates the Network Gateway on changes:

```
CONTEXT_UPDATE
{
  imsi
  connection_state
  serving_cell
}
```

Purpose:

* Ensures smooth handovers.
* Keeps gateway aware of UE location and load.

## 4. Mobility Coordination

When handover is initiated:

### BTS → Gateway:

```
HANDOVER_PREPARE
{
  imsi
  target_cell
  current_cell
}
```

Gateway responds with:

```
HANDOVER_READY
{
  imsi
}
```

After UE attaches to the new BTS, the new BTS informs the gateway:

```
HANDOVER_COMPLETE
{
  imsi
  target_cell
}
```

The gateway updates UE context tables for routing and authentication purposes.

## 5. Load Awareness

BTS nodes report approximate load to the gateway:

```
LOAD_STATUS
{
  cell_id
  active_ues
  capacity
}
```

The Network Gateway can:

* Make load-based handover suggestions.
* Balance traffic for high-density deployments.

Example rule:

```
prefer BTS with load < 80%
```

## 6. User-Plane Traffic Routing

The BTS forwards application-layer data via the gateway.

### Uplink (UE → BTS → Gateway → Service):

```
UPLINK_DATA
{
  imsi
  bearer_id
  payload
}
```

### Downlink (Service → Gateway → BTS → UE):

```
DOWNLINK_DATA
{
  imsi
  bearer_id
  payload
}
```

The gateway is **agnostic** to payload contents; it only ensures delivery to the correct BTS/UE.

## 7. Paging Support

Network Gateway initiates paging for idle UEs:

```
PAGE
{
  imsi
}
```

BTS broadcasts to UE:

```
PAGE
{
  imsi
}
```

UE responds with:

```
PAGE_RESPONSE
{
  imsi
}
```

Gateway updates UE state to **CONNECTED**.

## 8. Error Handling

### Authentication Failure

```
AUTH_FAIL
{
  imsi
  reason
}
```

BTS drops the attach attempt.

### Handover Failure

```
HANDOVER_TIMEOUT
{
  imsi
}
```

BTS restores UE context locally, gateway updates master database.

### UE Detach

```
DETACH_NOTIFY
{
  imsi
  reason
}
```

BTS removes UE from local tables, gateway updates master context.

## 9. Message Envelope

All BTS ↔ Gateway messages share a common structure:

```
{
  interface: "NGP",
  type: <message_type>,
  src: <bts_id>,
  payload: { ... }
}
```

Example:

```
type = AUTH_REQUEST
src = BTS_42
```

## 10. Resulting Behaviour

1. UE attaches via BTS.
2. BTS forwards authentication to gateway.
3. Gateway validates and returns bearer info.
4. BTS enters IDLE state, UE context stored locally.
5. UE measurement reports are sent to BTS.
6. BTS and gateway coordinate handovers.
7. Uplink/downlink traffic routed via gateway.
8. Paging and mobility handled seamlessly.
