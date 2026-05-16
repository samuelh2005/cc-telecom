//! Tracks per-connection session state (bound / unbound, bind mode).

use std::fmt;

/// Which kind of bind the ESME performed.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BindMode {
    Transmitter,
    Receiver,
    Transceiver,
}

impl fmt::Display for BindMode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            BindMode::Transmitter => write!(f, "transmitter"),
            BindMode::Receiver => write!(f, "receiver"),
            BindMode::Transceiver => write!(f, "transceiver"),
        }
    }
}

/// Simple state machine for an SMPP session.
#[derive(Debug, Default)]
pub enum SessionState {
    /// No bind has been performed yet.
    #[default]
    Open,
    /// The ESME is bound.
    Bound { system_id: String, mode: BindMode },
    /// An unbind handshake is in progress (we sent unbind_resp, waiting to close).
    Unbound,
}

impl SessionState {
    pub fn bind(&mut self, system_id: String, mode: BindMode) -> Result<(), &'static str> {
        if !self.is_open() {
            return Err("cannot bind: session is not in Open state");
        }
        *self = SessionState::Bound { system_id, mode };
        Ok(())
    }

    pub fn unbind(&mut self) -> Result<(), &'static str> {
        if !self.is_bound() {
            return Err("cannot unbind: session is not bound");
        }
        *self = SessionState::Unbound;
        Ok(())
    }

    pub fn is_bound(&self) -> bool {
        matches!(self, SessionState::Bound { .. })
    }

    pub fn is_open(&self) -> bool {
        matches!(self, SessionState::Open)
    }
}

impl fmt::Display for SessionState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            SessionState::Open => write!(f, "open"),
            SessionState::Bound { system_id, mode } => {
                write!(f, "bound({mode}) as {system_id:?}")
            }
            SessionState::Unbound => write!(f, "unbound"),
        }
    }
}