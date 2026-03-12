# BTS ↔ BTS Interface

# Inter-Cell Coordination Protocol (ICCP)

Purpose:

```
neighbour discovery
handover coordination
UE context transfer
cell load awareness
```

Transport: Rednet (wired or wireless).

This protocol exists **only between towers**.

# 1. Cell identity exchange

Each BTS must announce itself to neighbouring BTS nodes.

Broadcast periodically:

```
CELL_HELLO
{
  cell_id
  tracking_area
  capabilities
}
```

Purpose:

```
build neighbour tables
detect new cells
remove dead cells
```

Neighbour timeout:

```
15 seconds
```

If no HELLO is received in that period, the neighbour is removed.

# 2. Neighbour table

Each BTS maintains a table like:

```
neighbours = {
  cell_id
  link_id
  last_seen
  load
}
```

This table enables fast coordination during handovers.

# 3. UE measurement propagation

UEs periodically send `MEASUREMENT_REPORT` to their serving BTS.

When a neighbouring cell appears strong enough, the serving BTS may notify the target BTS.

Serving BTS → target BTS:

```
MEASUREMENT_FORWARD
{
  imsi
  signal_at_target
  signal_at_serving
}
```

This allows the target cell to prepare for potential handover.

# 4. Handover preparation

If the serving BTS decides a handover should occur:

Serving BTS → target BTS

```
HANDOVER_PREPARE
{
  imsi
  bearer_id
}
```

Target BTS behaviour:

```
allocate UE context
reserve bearer resources
```

Response:

Target BTS → serving BTS

```
HANDOVER_READY
{
  imsi
}
```

# 5. Handover execution

Once preparation succeeds:

Serving BTS → UE

```
HANDOVER_COMMAND
{
  target_cell
}
```

UE detaches from the serving cell and attaches to the target.

# 6. UE context transfer

When the UE reaches the new BTS, the new BTS must already have the subscriber context.

Context sent earlier includes:

```
UE_CONTEXT
{
  imsi
  bearer_id
  auth_state
}
```

The target BTS installs the context immediately.

This avoids forcing a full re-authentication.

# 7. Handover completion

After successful attachment:

Target BTS → serving BTS

```
HANDOVER_COMPLETE
{
  imsi
}
```

Serving BTS behaviour:

```
delete UE context
```

# 8. Load awareness

Cells should advertise approximate load so handovers can avoid overloaded towers.

Broadcast to neighbours:

```
LOAD_STATUS
{
  cell_id
  active_ues
  capacity
}
```

Neighbouring BTS nodes may factor this into handover decisions.

Example rule:

```
avoid target cell if load > 80%
```

# 9. Failed handovers

If the UE does not appear at the target BTS within a timeout:

Target BTS → serving BTS

```
HANDOVER_TIMEOUT
{
  imsi
}
```

Serving BTS behaviour:

```
restore UE context
resume service
```

# 10. BTS state tables

Each BTS maintains two key structures.

### Neighbour table

```
cell_id → link
```

### UE context table

```
imsi → {
  bearer_id
  connection_state
  measurements
}
```

# 11. ICCP message envelope

All BTS coordination messages share:

```
{
  interface = ICCP
  src_cell
  type
  payload
}
```

Example:

```
type = HANDOVER_PREPARE
```

# Resulting mobility behaviour

With ICCP implemented, mobility works like this:

```
UE measures neighbouring cell
↓
UE sends measurement report
↓
serving BTS evaluates mobility
↓
serving BTS coordinates with neighbour
↓
UE is instructed to switch cell
↓
context already prepared
↓
handover completes seamlessly
```
