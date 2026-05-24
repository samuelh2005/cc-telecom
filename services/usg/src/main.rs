use axum::{
    extract::ws::{Message, WebSocket, WebSocketUpgrade},
    response::IntoResponse,
    routing::get,
    Router,
};
use rand::RngExt;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
struct IncomingPacket {
    #[serde(rename = "sPacketType")]
    s_packet_type: String,
    #[serde(rename = "nMessageID")]
    n_message_id: i64,
    #[serde(rename = "nUE")]
    n_ue: Value,
    #[serde(rename = "tMessage")]
    t_message: Option<IncomingMessage>,
}

#[derive(Debug, Deserialize)]
struct IncomingMessage {
    #[serde(rename = "sDataService")]
    s_data_service: Option<String>,
    #[serde(rename = "tPayload")]
    t_payload: Option<HashMap<String, Value>>,
}

#[derive(Debug, Serialize)]
struct OutgoingPacket {
    #[serde(rename = "nMessageID")]
    n_message_id: i32,
    #[serde(rename = "nUE")]
    n_ue: Value,
    #[serde(rename = "nReplyTo")]
    n_reply_to: i64,
    #[serde(rename = "tMessage")]
    t_message: OutgoingMessage,
    #[serde(rename = "sPacketType")]
    s_packet_type: String,
}

#[derive(Debug, Serialize)]
struct OutgoingMessage {
    #[serde(rename = "sDataService")]
    s_data_service: String,
    #[serde(rename = "tPayload")]
    t_payload: HashMap<String, Value>,
}

fn new_message_id() -> i32 {
    rand::rng().random_range(1..=2_147_483_647)
}

async fn ws_handler(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(mut socket: WebSocket) {
    println!("Client connected");

    while let Some(Ok(msg)) = socket.recv().await {
        let text = match msg {
            Message::Text(t) => t,
            Message::Close(_) => break,
            _ => continue,
        };

        println!("Received: {text}");

        let packet: IncomingPacket = match serde_json::from_str(&text) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("Failed to parse message: {e}");
                continue;
            }
        };

        if packet.s_packet_type != "usp_b" {
            println!("Invalid packet type, ignoring");
            continue;
        }

        let t_message = match packet.t_message {
            Some(m) => m,
            None => {
                println!("Invalid tMessage format, ignoring");
                continue;
            }
        };

        let s_data_service = match t_message.s_data_service {
            Some(s) => s,
            None => {
                println!("Invalid sDataService format, ignoring");
                continue;
            }
        };

        let t_payload = t_message.t_payload.unwrap_or_default();

        let reply = OutgoingPacket {
            n_message_id: new_message_id(),
            n_ue: packet.n_ue,
            n_reply_to: packet.n_message_id,
            t_message: OutgoingMessage {
                s_data_service,
                t_payload,
            },
            s_packet_type: packet.s_packet_type,
        };

        let reply_json = match serde_json::to_string(&reply) {
            Ok(j) => j,
            Err(e) => {
                eprintln!("Failed to serialize reply: {e}");
                continue;
            }
        };

        if socket.send(Message::Text(reply_json.into())).await.is_err() {
            println!("Client disconnected");
            break;
        }
    }

    println!("Client disconnected");
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(ws_handler));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:80").await.unwrap();
    println!("WebSocket server running on ws://0.0.0.0:80");

    axum::serve(listener, app).await.unwrap();
}