# Service-Based Interface Design Specification

## 1. Scope and Architectural Model

The Service-Based Interface defines communication between independently deployable services. Each service SHALL expose one or more APIs representing capabilities over explicitly modeled resources.

All service interactions SHALL be request–response based and SHALL be carried over HTTP.

## 2. Protocol and Interaction Model

All SBI communication SHALL use HTTP (or HTTP/2 where supported).

Each request SHALL be self-contained. The system SHALL NOT require server-side session state between requests.

Any stateful behavior SHALL be explicitly represented as a resource exposed via the API.

## 3. API Design Style

APIs SHALL be resource-oriented by default. Resources SHALL be manipulated using standard HTTP methods:

* GET for retrieval
* POST for creation or non-idempotent operations
* PUT for full replacement
* PATCH for partial modification (if supported)
* DELETE for removal

REST principles SHALL be followed where applicable.

RPC-style operations MAY be used only where a resource-oriented model is not sufficient. Such operations SHALL be bound to a specific resource context and SHALL be invoked using HTTP POST.

## 4. URI Structure

All API endpoints SHALL follow the structure:

`{apiRoot}/{apiName}/{apiVersion}/{resourcePath}`

The components SHALL have the following meaning:

* `apiRoot` SHALL identify the deployment-specific base URL
* `apiName` SHALL identify the service capability
* `apiVersion` SHALL identify the API version
* `resourcePath` SHALL identify the addressed resource

URIs SHALL be stable for a given API version.

## 5. Resource Model

All domain entities SHALL be modeled as resources.

Each resource SHALL have a unique identifier.

Resources MAY represent:

* individual entities
* collections of entities
* hierarchical sub-resources

Resources SHALL NOT be modeled as procedural endpoints unless explicitly required via controlled RPC-style design.

## 6. Data Representation

All request and response payloads SHALL use JSON as the mandatory data format.

Each payload structure SHALL be defined by a formal schema (e.g., OpenAPI definition).

Schema compliance SHALL be strictly enforced.

## 7. Operation Semantics

HTTP method semantics SHALL be preserved.

Where operations represent domain actions that do not map cleanly to CRUD semantics, the operation SHALL be exposed as a POST-based action bound to a resource.

Actions SHALL NOT exist outside the context of a resource.

## 8. Error Handling

All error responses SHALL use standard HTTP status codes.

All error responses with a body SHALL include a structured JSON object under the following format:

```json
{
  "error": string,
  "message": string,
}
```

where:

* `error` SHALL be a machine-readable error code
* `message` SHALL be a human-readable description of the error

Additional diagnostic fields MAY be included using the following format:

```json
{
  "error": string,
  "message": string,
  "details": {
    "<fieldName>": any
  }
}
```

where:
* `error` and `message` SHALL follow the same rules as above
* `details` SHALL be an optional object containing additional diagnostic information about the error

HTTP status codes SHALL NOT be the sole source of error interpretation.

## 9. Versioning

All APIs SHALL be versioned using the URI path.

The version SHALL be explicitly encoded in the URI.

Breaking changes SHALL require a new API version.

Existing versions SHALL NOT be modified in a non-backward-compatible manner.

## 10. Statelessness

All SBI interactions SHALL be stateless.

No server SHALL rely on stored session context to process a request.

Any required state SHALL be explicitly modeled as a resource and SHALL be accessible via the API.

## 11. Consistency Requirements

All APIs within a system SHALL use consistent:

* naming conventions
* resource modeling patterns
* field naming rules

A single semantic concept SHALL NOT be represented using multiple inconsistent terms.

## 12. Specification Requirement

All SBI APIs SHALL be defined using a machine-readable specification (e.g., OpenAPI).

The specification SHALL be the authoritative definition of API behavior.

Implementations SHALL conform to the specification.
