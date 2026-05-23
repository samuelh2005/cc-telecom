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
- **Full 3GPP feature support**: The architecture is designed to provide basic cellular network functionality, but does not aim to be 3GPP compliant or implement all features of modern cellular standards.

## 2: Network Topology

```mermaid
flowchart BT
    UE((UE))

    subgraph "Radio Access Network"
        AP[AP]
        APC[APC]

        AP --> |"APC SBI"| APC
    end

    subgraph "Core Network"
        RS["Radius Server"]
        PBX[PBX]
        MSC[MSC]
        
        RS --- |"Radius"| MSC
        RS --- |"Radius"| PBX
        PBX --- |"SIP"| MSC
    end
    
    AP === |"USP/B"| MSC
    UE === |"USP/A"| AP
```

## 3. Network Components

| Component | Location | Description | Implementation |
|-----------|----------|-------------|----------------|
| **UE (User Equipment)** | In-Game | The in-game device that connects to the cellular network. It can be a computer, pocket computer, or a turtle. | Custom [../services/ue/](../services/ue/) |
| **AP (Access Point)** | In-Game | The in-game component that provides wireless connectivity to the UE. It acts as a bridge between the UE and the core network. | Custom [../services/ap/](../services/ap/) |
| **APC (Access Point Controller)** | External | Facilitates remote configuration and management of APs, allowing for dynamic network adjustments and optimisations. | Custom |
| **MSC (Mobile Switching Center)** | External | Manages message setup, routing, DFPWM audio transcoding and termination for the cellular network. | Custom |
| **Radius Server** | External | Manages subscriber information and authentication. | [FreeRADIUS](https://freeradius.org/) |
| **PBX (Private Branch Exchange)** | External | Handles media control functions such as messaging, call setup and teardown. | TBC |

## 4. Communication Protocols

| Protocol | Description | Transport Layer |
|----------|-------------|-----------------|
| **USP/A (User Session Protocol / Profile A)** | A custom protocol used to tunnel SIP packets between the UE and AP. | CC:T's Modem API |
| **USP/B (User Session Protocol / Profile B)** | A custom protocol used to tunnel SIP packets between the AP and MSC. | JSON over CC:T WebSockets |
| **APC SBI (Service-Based Interface)** | Provides remote configuration and management capabilities for APs. | JSON over HTTP |
| **Radius** | A standard protocol for authentication, authorization, and accounting (AAA) used between the PBX,MSC and Radius Server. | UDP |
| **SIP (Session Initiation Protocol)** | A standard protocol for initiating, maintaining, and terminating real-time sessions used between the PBX and MSC. | TCP |
