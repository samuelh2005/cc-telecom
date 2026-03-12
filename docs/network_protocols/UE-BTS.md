# UE ↔ BTS Interface

# Radio Access Protocol (RAP)

Transport medium: **Rednet**

RAP is responsible only for **radio access and bearer transport**.

# 1. Identities

## UE identity

Each device contains:

```
IMSI
Ki
```

The subscriber identifier follows the idea of the
International Mobile Subscriber Identity.

## BTS identity

Each base station broadcasts:

```
network_id
cell_id
tracking_area
```

# 2. UE State Machine

The UE must behave according to a strict state model.

```
NO_SIGNAL
CELL_SEARCH
CAMPED
ATTACHING
IDLE
CONNECTED
```

### State meanings

| State       | Meaning                        |
| ----------- | ------------------------------ |
| NO_SIGNAL   | no cells detected              |
| CELL_SEARCH | scanning for towers            |
| CAMPED      | cell selected but not attached |
| ATTACHING   | authentication ongoing         |
| IDLE        | registered but inactive        |
| CONNECTED   | active user-plane traffic      |

# 3. Cell Discovery

## BTS broadcast

Each BTS periodically broadcasts:

```
CELL_SYNC
{
  network_id
  cell_id
  tracking_area
  timestamp
}
```

Broadcast interval:

```
1–3 seconds
```

Purpose:

* advertise the cell
* allow UE discovery
* maintain synchronization

No signal strength field is transmitted.

# 4. Signal Measurement

UE derives signal quality locally using Rednet distance.

Approximation:

```
signal_quality ≈ 1 / distance²
```

This mimics measurements similar to
Received Signal Strength Indicator.

UE maintains a local table:

```
cell_table = {
  cell_id
  last_seen
  signal_quality
}
```

# 5. Cell Selection

UE selects a serving cell using the rule:

```
highest signal_quality
```

Stability rules:

```
ignore cells unseen for >5s
apply hysteresis margin
```

Example:

```
switch only if new_cell > serving_cell + margin
```

UE then enters **CAMPED** state.

# 6. Attach Procedure

When camped, the UE may attach to the network.

### UE → BTS

```
ATTACH_REQUEST
{
  imsi
}
```

The BTS forwards authentication to the core network.

### BTS → UE

```
AUTH_CHALLENGE
{
  rand
}
```

### UE → BTS

```
AUTH_RESPONSE
{
  response
}
```

Response calculation:

```
hash(rand + Ki)
```

### BTS → UE

```
ATTACH_ACCEPT
{
  bearer_id
}
```

The UE now enters **IDLE** state.

The assigned bearer represents the logical transport channel.

This concept is analogous to the
EPS bearer.

# 7. Idle Behaviour

In IDLE state the UE:

```
listens for paging
monitors serving cell signal
periodically scans neighbours
```

UE also sends measurement reports.

# 8. Measurement Reporting

UE → BTS:

```
MEASUREMENT_REPORT
{
  serving_cell
  serving_signal
  neighbours = [
    {cell_id, signal},
    ...
  ]
}
```

Typical reporting interval:

```
10–20 seconds
```

These reports allow the network to make mobility decisions.

# 9. Handover

When the network detects a stronger neighbouring cell:

Condition:

```
neighbour_signal > serving_signal + margin
```

BTS → UE:

```
HANDOVER_COMMAND
{
  target_cell
}
```

UE behaviour:

```
disconnect from current cell
attach to target cell
```

# 10. Paging

Idle UEs are contacted using paging.

### BTS broadcast

```
PAGE
{
  imsi
}
```

### UE response

```
PAGE_RESPONSE
{
  imsi
}
```

After responding, the UE enters **CONNECTED** state.

# 11. User-Plane Data Transport

The radio layer provides **bearer transport only**.

It does **not interpret payloads**.

## Uplink

UE → BTS

```
UPLINK_DATA
{
  bearer_id
  payload
}
```

The BTS forwards this payload to the core network.

## Downlink

BTS → UE

```
DOWNLINK_DATA
{
  bearer_id
  payload
}
```

The UE processes the payload in higher layers.

# 12. Loss of Coverage

If the UE stops receiving `CELL_SYNC`:

Timeout:

```
5 seconds
```

Behaviour:

```
exit IDLE/CONNECTED
enter CELL_SEARCH
```

The UE begins scanning again.

# 13. Re-entry into Coverage

When a new cell appears:

```
evaluate signal
select cell
camp
attach
```

This is treated as a new attach.

No handover occurs because the original cell is unreachable.

# 14. BTS Responsibilities

Each base station must:

```
broadcast CELL_SYNC
relay authentication
track attached UEs
forward user-plane packets
perform paging
trigger handover decisions
```

Local state table:

```
IMSI → bearer_id
```

# 15. RAP Packet Envelope

All messages share a common structure:

```
{
  interface = RAP
  type
  src
  payload
}
```

Example:

```
type = ATTACH_REQUEST
src = UE
```
