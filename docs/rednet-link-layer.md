# Rednet Link Layer (RLL)

## 1. Introduction

The Rednet Link Layer (RLL) is a custom protocol designed for communication between in-game User Equipment (UE) and Access Points (AP) over the Rednet network.

## 2.1. Encoding

The Rednet Link Layer (RLL) uses `textutils.serialiseJSON` to encode messages into JSON format.

## 2.2. Request Message Structure

The following packet structure is used for all UE requests:

```lua
{
    ueId: string,   -- Unique identifier for the UE
    seq: number,    -- Sequence number for message ordering
    method: string, -- Method name indicating the type of message
    body: any,      -- The actual message payload
    mac: string,    -- HMAC for message integrity and authenticity
}
```

## 2.3. Reply Message Structure

The following packet structure is used for all AP replies:

```lua
{
    apId: string,   -- Unique identifier for the AP
    seq: number,    -- Sequence number matching the request
    status: number, -- Status code indicating success or failure
    body: any,      -- The actual message payload
    mac: string,    -- HMAC for message integrity and authenticity
}
```

## 2.4. Request Methods

