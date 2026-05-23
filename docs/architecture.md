# CC: Tweaked Cellular Network Architecture

## 1: Aims and Objectives

The architecture of the CC: Tweaked cellular network is designed to provide a robust and scalable framework for in-game communication. The primary objectives of this architecture are:

1. **Modularity**: To allow for easy integration of new components and services without disrupting existing functionality.
2. **Scalability**: To support a growing number of users and devices without degradation in performance.
3. **Interoperability**: To ensure seamless communication between different components of the network, both in-game and external.
4. **Standardisation**: Use of existing protocols where possible to facilitate interoperability and extensibility.

There are objectives which are outside the scope of this architecture, such as:
- **Bulletproof security**: While security is a consideration, the architecture does not aim to provide comprehensive security measures against all potential threats.
- **Extensive custom protocol development**: The architecture focuses on using existing protocols where possible, and only developing custom protocols when necessary for specific use cases.
- **Full 3GPP feature support**: The architecture is designed to provide basic cellular network functionality, but does not aim to implement all features of modern cellular standards.

## 2: Network Topology

```mermaid
flowchart LR
    UE((UE))

    subgraph "Radio Access Network"
        AP[AP]
        APC[APC]

        AP --> |"APC SBI"| APC
    end

    subgraph "Core Network"
        MSC[MSC]
        STP[STP]
        HLR[HLR]
        SMSC[SMSC]
  
        HLR --- |"SS7"| STP
        SMSC --- |"SS7"| STP
        MSC --- |"SS7"| STP
    end
    
    UE === |"USP/A"| AP
    AP === |"USP/B"| MSC
```

## 3. Network Components

| Component | Location | Description | Implementation |
|-----------|----------|-------------|----------------|
| **UE (User Equipment)** | In-Game | The in-game device that connects to the cellular network. It can be a computer, pocket computer, or a turtle. | Custom [../services/ue/](../services/ue/) |
| **AP (Access Point)** | In-Game | The in-game component that provides wireless connectivity to the UE. It acts as a bridge between the UE and the core network. | Custom [../services/ap/](../services/ap/) |
| **APC (Access Point Controller)** | External | Facilitates remote configuration and management of APs, allowing for dynamic network adjustments and optimisations. | Custom |
| **MSC (Mobile Switching Center)** | External | Manages message setup, routing, and termination for the cellular network. | Custom |
| **HLR (Home Location Register)** | External | Manages subscriber information and authentication. | Custom |
| **SMSC (Short Message Service Center)** | External | Handles the routing and delivery of SMS messages. | Custom |
| **STP (Signalling Transfer Point)** | External | Routes signalling messages between components of the SS7 network. | [OsmoSTP](https://osmocom.org/projects/osmo-stp/wiki) |

## 4. Communication Protocols

| Protocol | Description | Transport Layer |
|----------|-------------|-----------------|
| **USP/A (User Session Protocol / Profile A)** | A custom protocol used to tunnel control and data traffic between the UE and AP. | CC:T's Modem API |
| **USP/B (User Session Protocol / Profile B)** | A custom protocol used to tunnel user data traffic between the AP and MSC. | JSON over CC:T WebSockets |
| **APC SBI (Service-Based Interface)** | Provides remote configuration and management capabilities for APs. | JSON over HTTP |
| **SS7 (Signalling System No. 7)** | A standard protocol used for signalling and control in telecommunication networks. | Standard SIGTRAN over SCTP/IP |
