# CC: Tweaked Cellular Access Network Specification

## 1: Scope

**In Scope**:
- Defining the architecture and components of a cellular access network for CC: Tweaked
- Specifying the interfaces and protocols used for communication between components
- Outlining the security considerations for the network
- Defining protocols and procedures for authentication, authorisation, and data transmission

**Out of Scope**: 
- Real-world cellular network standards (e.g., 4G, 5G) and their specific implementations
- Implementations of specific Data Services (DS) beyond the general interface and requirements
- Implementation of a common transport layer abstraction such as IP layer semantics

## 2: Terminology

| Term | Description |
|---------|-------------|
| **Radio Access Network (RAN)** | Used for wireless communication between User Equipment and the core network |
| **Core Network** | Serves as the central hub for managing and routing data within the radio data network |
| **Data Network** | The overall grouping of network infrastructure that facilitates access to Data Services |
| **Access Point (AP)** | Allows UEs to bind to the network, enforce network policies through the HSS, and serves as a gateway for data transmission |
| **User Equipment (UE)** | Connects to the network to provide access to Data Services |
| **Home Subscriber Server (HSS)** | Tracks UE mobility information, manages authentication and authorization, and maintains a registry of Data Services |
| **Data Service (DS)** | Implements a service assessable over the data network |

## 3: Network Architecture

```mermaid
flowchart LR
    subgraph RAN
        direction LR
        UE((UE))
        AP[AP]

        UE <--> |"Uu (`modem`)"| AP
    end

    subgraph CORE["Core Network"]
        direction TB
        HSS[HSS]
        DS[DS]
    end

    AP <--> |"SUP (`rednet`)"| HSS
    AP <--> |"Dh (`rednet`)"| DS
    DS <--> ["SUP (`rednet`)"] HSS
```

1. The RAN consists of UEs and APs, where UEs connect to the network through APs using the Uu interface.
2. The AP serves as a gateway between the RAN and the Core Network, facilitating communication.
3. The AP communicates with the HSS using the SUP interface for authentication, authorization, and mobility management
4. The AP also communicates with DSs using the Dh interface for data transmission and service access.
4. The DS can communicate with the HSS using the SUP interface to query which AP a UE is currently connected to and to register itself as a service available to subscribers.

## 4: Transport and Trust

| Interface | Trust level | Transport | Responsibilities |
|-----------|-------------|-----------|------------------|
| **Uu** | Untrusted | `modem` | Provides wireless connectivity for UEs to access the network |
| **SUP** | Trusted | `rednet` | Allows subscriber location updates and authentication |
| **Dh** | Trusted | `rednet` | Facilitates registration of Data Services towards the HSS and allows a DS to query the HSS for subscriber information |

Trusted networks SHOULD make use of secure mediums like physical network cables or encrypted communication instead of transporting plain text over-the-air.

## 5: Common Packet Envelope

All messages sent over the Uu and SUP interfaces MUST be encapsulated in a common packet envelope with the following format:

```lua
{
    type = string, -- The type of message being sent
    timestamp = number, -- UTC timestamp of when the message was sent
    id = string, -- A unique identifier for the message, used for tracking and correlation
    elements = { -- A table of key-value pairs representing the message's payload
        [string] = { -- The key is a string representing the name of the element
            type = string, -- The element type
            value = any, -- The value as required by the element type
        },
    }
}
```

The DH interface MUST NOT use the common packet envelope.

## 6: Uu Interface

### 6.1: Message Formats

### 6.2: State Machines

#### 6.2.1: UE State Machine

#### 6.2.2: AP State Machine

## 7: Dh Interface

### 7.1: Message Formats

### 7.2: State Machines

#### 7.2.1: DS State Machine

#### 7.2.2: HSS State Machine

## 8: Subscriber Update Protocol (SUP) Interface

### 8.1: Message Formats

### 8.2: State Machines

#### 8.2.1: HSS State Machine

## 9. Common Element Types

### 9.1: Mobile Station International Subscriber Directory Number (MSISDN)

**Element Type**: `msisdn`
**Data Type**: String
**Value**: A string of digits representing the subscriber's phone number

### 9.2: Computer ID

**Element Type**: `computer_id`
**Data Type**: Number
**Value**: The unique identifier of a computer, as returned by `os.getComputerID()`

### 9.3: UE Registration State

**Element Type**: `registration_state`
**Data Type**: String (enum)
**Value**: The current registration state of the UE ("registered", "unregistered")
