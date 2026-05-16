//! Minimal SMPP server built on top of Rusmpp (git HEAD).
//!
//! Usage:
//!   smpp-server [OPTIONS]
//!
//! Options:
//!   --host <HOST>        Bind address            [default: 0.0.0.0]
//!   --port <PORT>        Listen port             [default: 2775]
//!   --system-id <ID>     System-ID sent in bind responses [default: SMPP-SRV]
//!   --log-level <LEVEL>  Log level filter        [default: info]

mod handler;
mod session;

use clap::Parser;
use std::{net::SocketAddr, sync::Arc};
use tokio::net::TcpListener;
use tokio::sync::Semaphore;
use tokio::time::{sleep, Duration};
use tracing::{error, info, warn};
use tracing_subscriber::EnvFilter;

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

#[derive(Debug, Parser)]
#[command(author, version, about = "Minimal SMPP v5 server")]
struct Args {
    /// IP address to listen on.
    #[arg(long, default_value = "0.0.0.0")]
    host: String,

    /// TCP port to listen on.
    #[arg(long, default_value_t = 2775)]
    port: u16,

    /// System-ID returned in bind responses (max 15 ASCII chars).
    #[arg(long, default_value = "SMPP-SRV")]
    system_id: String,

    /// Tracing log-level filter (e.g. "debug", "smpp_server=trace,rusmpp=off").
    #[arg(long, default_value = "info")]
    log_level: String,
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

const MAX_CONNECTIONS: usize = 256;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    // Initialise structured logging.
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new(&args.log_level)),
        )
        .init();

    let addr: SocketAddr = format!("{}:{}", args.host, args.port)
        .parse()
        .expect("invalid bind address");

    let listener = TcpListener::bind(addr).await?;
    info!("SMPP server listening on {addr}");

    // Wrap the system-id in an Arc so every handler task can share it cheaply.
    let system_id = Arc::new(args.system_id);
    let connection_semaphore = Arc::new(Semaphore::new(MAX_CONNECTIONS));

    loop {
        let (stream, peer_addr) = match listener.accept().await {
            Ok((stream, peer_addr)) => (stream, peer_addr),
            Err(err) => {
                if is_transient_accept_error(&err) {
                    warn!(%err, "accept error - retrying");
                    sleep(Duration::from_millis(200)).await;
                    continue;
                }
                error!(%err, "accept error - shutting down");
                return Err(err.into());
            }
        };

        let permit = match connection_semaphore.clone().acquire_owned().await {
            Ok(permit) => permit,
            Err(_) => {
                warn!(%peer_addr, "connection limit unavailable - dropping connection");
                continue;
            }
        };

        let system_id = system_id.clone();

        info!(%peer_addr, "accepted connection");

        tokio::spawn(async move {
            let _permit = permit;
            if let Err(err) = handler::run(stream, peer_addr, system_id).await {
                error!(%peer_addr, %err, "connection error");
            }
            info!(%peer_addr, "connection closed");
        });
    }
}

fn is_transient_accept_error(err: &std::io::Error) -> bool {
    use std::io::ErrorKind;

    if matches!(err.kind(), ErrorKind::WouldBlock | ErrorKind::Interrupted) {
        return true;
    }

    matches!(err.raw_os_error(), Some(23 | 24 | 10024))
}