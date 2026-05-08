# Network Element Protocol

## 1: Introduction

The Network Element Protocol (NEP) defines structured communication between two parties using a common packet envelope composed of a header and a list of network elements. This protocol is designed to be flexible and extensible, allowing for a wide range of message types and payloads while maintaining a consistent structure for parsing and processing.

The NEP is very flexible in a number of ways, including:
- being transport-agnostic, meaning it can be used over various communication mediums such as Rednet, Modems, or WebSockets *or even be used outside of CC: Tweaked entirely*
- supporting a wide range of message types and payloads through the use of network elements and registries
- allowing for extensibility by enabling the addition of new message types and network elements without breaking existing functionality

## 2. Scope

Scope is an important aspect of any protocol, as it defines the boundaries and limitations of what the protocol is intended to do. The NEP is designed to be a flexible and extensible protocol data shape that can be used in a variety of contexts, but it is not intended to be a complete solution for all communication needs. Specifically, the NEP is not intended to be a transport protocol, security protocol, state machine, or on-the-wire encoding definition. Instead, it focuses on defining a common message format and providing registries for message types and network elements to ensure consistency and interoperability.

The NEP is not intended to be:
- a transport protocol, as it does not define how messages are transmitted between parties
- a security protocol, as it does not provide mechanisms for authentication, encryption, or integrity protection
- a state machine, as it does not define specific states or transitions for parties communicating using the protocol
- a definition for on-the-wire encoding or serialisation

Instead, the NEP focuses on:
- defining a common message format for communication between parties
- providing a registry for message types and network elements to ensure consistency and interoperability
- allowing for extensibility and flexibility in message design and payloads

## 3: Common Types

## 3.1: Common Packet Envelope

All messages sent over the NEP MUST be encapsulated in a common packet envelope with the following format:

| Field | Type | Value |
|-------|------|-------|
| `type` | string | The type of message being sent, MUST be defined in the Packet Registry |
| `timestamp` | number | MUST be a valid UTC timestamp |
| `id` | number | A unique identifier for the message, used for tracking and correlation |
| `elements` | table | MUST be a valid Network Element |

The `elements` field in the packet envelope MUST be a table of key-value pairs representing a list of network elements. Each key in the table MUST be a string representing the name of the element, and each value MUST follow the format defined for Network Elements in [Section 3.2](#32-network-elements).

## 3.2: Network Elements

A Network Element is a structured data type that represents a specific piece of information or functionality within the NEP. Each Network Element MUST have the following format:

| Field | Type | Value |
|-------|------|-------|
| type | string | The element type, MUST be defined in the Element Registry |
| value | any | The value as required by the element type |
