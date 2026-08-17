# User Session Protocol `UAP/1.0`

## 1. Introduction

The User Session Protocol (USP) is a custom protocol designed for UEs to communicate with the MSC

## 2. Error types

| Status code | Description |
|-------------|-------------|
| `200` | The operation was successful |
| `204` | The response body is empty |
| `401` | Authorization is required |
| `404` | The requested object was not found |
| `500` | The responding party could not handle the request |

## 3. Methods

| Method | Description |
|--------|-------------|
| `CONNECT` | Used to establish a session with the server |
| `DISCONNECT` | The server wishes the client to disconnect; or the client is disconnecting from the server |
| `AUTH` | The server requires authentication |
| `SERVICES` | The client wants the server to provide a list of services |
| `SUBMIT` | Used to send a service payload from the client |
| `DELIVER` | Used by the server to send a payload to the client asynchronously |

## 3. Common Packet Envelope

All packets are UTF-8 encoded.

### 3.1 Request payload

```
<version> <method> "<parameters>"
<body>
```

### 3.2 Response payload

```
<status>
<body>
```

## 4. Packet Types

1. Connect and auth

```
S<C UAP/1.0 CONNECT "alice@example.com" 
S>C 401
"AUTH method=deviceKey"
S<C UAP/1.0 AUTH "<deviceKey>"
S>C 200
"AUTH SUCCESS"
OR
S>C 401
"Invalid device key"
S>C DISCONNECT
OR
S>C 401
"Timeout reached"
S>C DISCONNECT
```

2. Discover services

```
S<C UAP/1.0 SERVICES
S>C 200 
"SERVICES billing;sms;gps;..."
OR
S>C 204
```

3. Submit service payload

```
S<C UAP/1.0 SUBMIT "<service>"
<body>
S>C 200
<response>
OR
S>C 404
"Service <service> does not exist"
OR
S>C 500
"<error>"
```

4. Async service payload delivery

```
S>C UAP/1.0 DELIVER "<service>"
<body>
S<C 200
<response>
OR
S<C 500
"<error>"
```
