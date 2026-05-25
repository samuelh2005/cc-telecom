# User Session Protocol

## 1. Introduction

The User Session Protocol (USP) is a custom protocol designed to bridge in-game communication between the User Equipment (UE) and the Access Point (AP) with out of game services like the User Session Gateway (USG).

This protocol is designed with two separate profiles, Profile A and Profile B, which serve different purposes:
1. Profile A which focuses on the communication between the UE and AP.
2. Profile B which handles the communication between the AP and USG.

## 2. Common Packet Types

### 2.1. Common Message Format

- `sPacketType` (string): The type of the packet.
- ... Packet specific fields depending on the `sPacketType` value.

### 2.2. ADP Packet Structure

- `nMessageID` (number): A unique identifier for the message, used for matching requests and responses.
- `nUE` (number): The unique identifier of the UE associated with the message.
- `tMessage` (table): The payload of the message, containing protocol-specific data.
- `nReplyTo` (number, optional): The `nMessageID` of the message this is replying to, if applicable.

`sPacketType` SHALL be set to "adp" for all Application Data Protocol (ADP) messages.

The `tMessage` for ADP messages SHALL contain the following fields:

- `sDataService` (string): The name of the data service being accessed.
- `tPayload` (table): The payload specific to the data service, containing the necessary information for processing the request.

## 3. Profile A

### 3.1. Purpose

Profile A represents the connection between the UE and AP, this profile facilitates the lookup of APs and the establishment of a session between the UE and AP. It is responsible for handling the initial connection setup and traffic tunneling.

### 3.2. Transport Layer

Profile A SHALL use CC:T's Modem API for communication between the UE and AP using the following channels:

- **Announcement Channel**: Used by APs to broadcast their presence and capabilities to nearby UEs. This channel allows UEs to discover available APs and their supported features. **This SHALL use channel 65125**
- **AP Data TX Channel**: Used by the AP to send all Common Packet Types to the UE. **This SHALL be determined by the administrator and configured on the AP**
- **AP Data RX Channel**: Used by the AP to receive all Common Packet Types from the UE. **This SHALL be determined by the administrator and configured on the AP**

No specific serialisation should be performed, instead serialisation SHALL be delegated to `modem.transmit` and `modem.receive`.

### 3.3. Announcement Packet

The announcement packet SHALL use an `sPacketType` of "announcement" and contain the following fields:

- `nApID` (number): A unique identifier for the AP, used by UEs to identify and connect to the AP. This ID SHALL use the value from `os.getComputerID()` of the AP.
- `nTXChannel` (number): The channel number that UEs should use to send packets to the AP.
- `nRXChannel` (number): The channel number that UEs should listen to for packets from the AP.

There SHALL NOT be a `tMessage` or other ADP fields in the announcement packet, as it is only used for broadcasting the AP's presence and connection information.

## 4. Profile B

### 4.1. Purpose

Profile B provides a bridge between the in-game AP and outside-game USG, it is a dumb transport pipe that relays any AP packet to the USG and vice versa.

### 4.2. Transport Layer

A WebSocket connection SHALL be established between the AP and USG. The AP SHALL connect to the USG at a configurable URL, and the USG SHALL listen for incoming WebSocket connections on a configurable port.

Serialisation shall be performed using `textutils.unserializeJSON` and `textutils.serializeJSON`. 

The AP SHALL relay all Common Packet Types over this connection to the USG, and the USG SHALL respond using Common Packet Types where applicable.

The AP SHALL NOT relay announcement packets over this connection, and instead SHALL focus on relaying RX/TX data packets between the UE and USG.
