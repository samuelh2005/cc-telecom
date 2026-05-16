//! Per-connection PDU handler.
//!
//! A single `run()` task owns the framed TCP stream and drives the session
//! state machine. Every received PDU is dispatched to a dedicated `handle_*`
//! helper that produces zero or one response command.

use std::{net::SocketAddr, sync::Arc};

use futures::{SinkExt, StreamExt};
use rusmpp::{
    Command, CommandId, CommandStatus, Pdu,
    pdus::{BindReceiverResp, BindTransceiverResp, BindTransmitterResp, SubmitSmResp},
    tokio_codec::{CommandCodec, EncodeError},
    types::COctetString,
};
use tokio::net::TcpStream;
use tokio_util::codec::Framed;
use tracing::{debug, info, warn};

use crate::session::{BindMode, SessionState};

// ---------------------------------------------------------------------------
// Public entry-point
// ---------------------------------------------------------------------------

pub async fn run(
    stream: TcpStream,
    peer_addr: SocketAddr,
    server_system_id: Arc<String>,
) -> Result<(), EncodeError> {
    let mut framed = Framed::new(stream, CommandCodec::new());
    let mut session = SessionState::default();

    info!(%peer_addr, "session started");

    while let Some(result) = framed.next().await {
        let command = match result {
            Ok(cmd) => cmd,
            Err(err) => {
                let nack = Command::builder()
                    .status(CommandStatus::EsmeRinvcmdlen)
                    .sequence_number(0) // no valid header, so no sequence number to copy
                    .pdu(Pdu::GenericNack);
                framed.send(nack).await?;

                warn!(%peer_addr, %err, "decode error - dropping connection");
                break;
            }
        };

        let cmd_id = command.id();
        let seq = command.sequence_number();

        debug!(%peer_addr, ?cmd_id, seq, state = %session, "received PDU");

        // Dispatch -----------------------------------------------------------
        let response = match cmd_id {
            // ── Bind operations ─────────────────────────────────────────────
            CommandId::BindTransmitter => {
                handle_bind(&command, &mut session, BindMode::Transmitter, &server_system_id)
            }
            CommandId::BindReceiver => {
                handle_bind(&command, &mut session, BindMode::Receiver, &server_system_id)
            }
            CommandId::BindTransceiver => {
                handle_bind(&command, &mut session, BindMode::Transceiver, &server_system_id)
            }

            // ── Session keep-alive ───────────────────────────────────────────
            CommandId::EnquireLink => handle_enquire_link(&command),

            // ── Unbind ───────────────────────────────────────────────────────
            CommandId::Unbind => {
                let resp = handle_unbind(&command, &mut session);
                // Send the response, then terminate the loop.
                framed.send(resp).await?;
                info!(%peer_addr, "unbound - closing connection");
                break;
            }

            // ── Message submission (stub) ────────────────────────────────────
            CommandId::SubmitSm => handle_submit_sm(&command, &session),
            CommandId::SubmitMulti => {
                handle_generic_nack(&command, CommandStatus::EsmeRprohibited)
            }

            // ── Query / replace / cancel (stubs) ────────────────────────────
            CommandId::QuerySm
            | CommandId::CancelSm
            | CommandId::ReplaceSm
            | CommandId::BroadcastSm
            | CommandId::QueryBroadcastSm
            | CommandId::CancelBroadcastSm => {
                info!(%peer_addr, ?cmd_id, "stub PDU - returning ESME_RPROHIBITED");
                handle_generic_nack(&command, CommandStatus::EsmeRprohibited)
            }

            // ── Data SM (stub) ───────────────────────────────────────────────
            CommandId::DataSm => {
                info!(%peer_addr, "data_sm stub - returning ESME_RPROHIBITED");
                Command::builder()
                    .status(CommandStatus::EsmeRprohibited)
                    .sequence_number(seq)
                    .pdu(Pdu::GenericNack)
            }

            // ── Anything else ────────────────────────────────────────────────
            other => {
                warn!(%peer_addr, ?other, "unknown / unexpected PDU");
                handle_generic_nack(&command, CommandStatus::EsmeRinvcmdid)
            }
        };

        framed.send(response).await?;
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// Bind helpers
// ---------------------------------------------------------------------------

fn handle_bind(
    command: &Command,
    session: &mut SessionState,
    mode: BindMode,
    server_system_id: &str,
) -> Command {
    // Reject a second bind on an already-bound session.
    if !session.is_open() {
        warn!(state = %session, "bind rejected - session already bound or unbound");
        return handle_generic_nack(command, CommandStatus::EsmeRalybnd);
    }

    // Pull the ESME's system_id out of the PDU for logging.
    // command.pdu() returns Option<&Pdu>; the bind variants always carry a body.
    let esme_system_id = match command.pdu() {
        Some(Pdu::BindTransmitter(b)) => b.system_id.as_str().to_owned(),
        Some(Pdu::BindReceiver(b)) => b.system_id.as_str().to_owned(),
        Some(Pdu::BindTransceiver(b)) => b.system_id.as_str().to_owned(),
        _ => "?".to_owned(),
    };

    info!(esme = %esme_system_id, %mode, "bind accepted");
    let res = session.bind(esme_system_id, mode);
    if let Err(err) = res {
        warn!(%err, "bind rejected");
        return handle_generic_nack(command, CommandStatus::EsmeRinvcmdid);
    }

    // Build the C-octet-string for the server system-id.
    // COctetString<1,16> - null-terminated, 1-15 printable ASCII chars.
    let system_id = cow_to_coctet::<1, 16>(server_system_id);

    let resp_pdu = match mode {
        BindMode::Transmitter => {
            Pdu::BindTransmitterResp(BindTransmitterResp::new(system_id, None))
        }
        BindMode::Receiver => {
            Pdu::BindReceiverResp(BindReceiverResp::new(system_id, None))
        }
        BindMode::Transceiver => {
            Pdu::BindTransceiverResp(BindTransceiverResp::new(system_id, None))
        }
    };

    Command::builder()
        .status(CommandStatus::EsmeRok)
        .sequence_number(command.sequence_number())
        .pdu(resp_pdu)
}

// ---------------------------------------------------------------------------
// Unbind
// ---------------------------------------------------------------------------

fn handle_unbind(command: &Command, session: &mut SessionState) -> Command {
    info!(state = %session, "unbind received");
    let res = session.unbind();
    if let Err(err) = res {
        warn!(%err, "unbind rejected");
        return handle_generic_nack(command, CommandStatus::EsmeRinvcmdid);
    }
    Command::builder()
        .status(CommandStatus::EsmeRok)
        .sequence_number(command.sequence_number())
        .pdu(Pdu::UnbindResp)
}

// ---------------------------------------------------------------------------
// Enquire-link keep-alive
// ---------------------------------------------------------------------------

fn handle_enquire_link(command: &Command) -> Command {
    debug!("enquire_link - replying");
    Command::builder()
        .status(CommandStatus::EsmeRok)
        .sequence_number(command.sequence_number())
        .pdu(Pdu::EnquireLinkResp)
}

// ---------------------------------------------------------------------------
// Submit-SM stub
// ---------------------------------------------------------------------------

fn handle_submit_sm(command: &Command, session: &SessionState) -> Command {
    if !session.is_bound() {
        warn!("submit_sm on unbound session");
        return handle_generic_nack(command, CommandStatus::EsmeRinvbndsts);
    }

    // Stub: generate a fake message-id and acknowledge immediately.
    let message_id = cow_to_coctet::<1, 65>("stub-msg-0001");

    info!("submit_sm accepted (stub) - message_id=stub-msg-0001");

    let resp = SubmitSmResp::new(message_id, vec![]);
    Command::builder()
        .status(CommandStatus::EsmeRok)
        .sequence_number(command.sequence_number())
        .pdu(Pdu::SubmitSmResp(resp))
}

// ---------------------------------------------------------------------------
// Generic-NACK catch-all
// ---------------------------------------------------------------------------

fn handle_generic_nack(command: &Command, status: CommandStatus) -> Command {
    Command::builder()
        .status(status)
        .sequence_number(command.sequence_number())
        .pdu(Pdu::GenericNack)
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

/// Convert a plain `&str` into a `COctetString<MIN, MAX>`.
/// Truncates to `MAX - 1` bytes if necessary and panics only on internal
/// encoding errors (which cannot happen with valid ASCII).
fn cow_to_coctet<const MIN: usize, const MAX: usize>(s: &str) -> COctetString<MIN, MAX> {
    // Silently truncate to fit within the field's max length (leaves room for NUL).
    let max_len = MAX.saturating_sub(1);
    let mut end = s.len().min(max_len);
    while end > 0 && !s.is_char_boundary(end) {
        end -= 1;
    }
    let truncated = &s[..end];
    let mut bytes = truncated.as_bytes().to_vec();
    bytes.push(0);
    COctetString::from_vec(bytes)
        .expect("COctetString construction failed - internal constraint violated")
}