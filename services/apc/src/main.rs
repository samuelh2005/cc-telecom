use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::{IntoResponse, Json, Response},
    routing::get,
    Router,
};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, sync::Arc};

// ── Config types ─────────────────────────────────────────────────────────────

#[derive(Deserialize, Clone)]
struct Config {
    regions: HashMap<String, HashMap<String, Vec<Service>>>,
}

#[derive(Deserialize, Serialize, Clone)]
struct Service {
    name: String,
    address: String,
}

// ── App state ─────────────────────────────────────────────────────────────────

#[derive(Clone)]
struct AppState {
    config: Arc<Config>,
}

// ── Request / response types ──────────────────────────────────────────────────

#[derive(Deserialize)]
struct RegionQuery {
    #[serde(rename = "serviceType")]
    service_type: Option<String>,
}

#[derive(Serialize)]
#[serde(untagged)]
enum RegionResponse {
    Region(HashMap<String, Vec<Service>>),
    Services(Vec<Service>),
    Error { error: String },
}

struct AppError(StatusCode, String);

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let body = Json(RegionResponse::Error { error: self.1 });
        (self.0, body).into_response()
    }
}

// ── Handler ───────────────────────────────────────────────────────────────────

async fn read_region(
    Path(region_id): Path<String>,
    Query(params): Query<RegionQuery>,
    State(state): State<AppState>,
) -> Result<Json<RegionResponse>, AppError> {
    let region = state
        .config
        .regions
        .get(&region_id)
        .ok_or_else(|| AppError(StatusCode::NOT_FOUND, "Region not found".into()))?;

    match params.service_type {
        None => Ok(Json(RegionResponse::Region(region.clone()))),
        Some(svc_type) => {
            let services = region.get(&svc_type).ok_or_else(|| {
                AppError(StatusCode::NOT_FOUND, "Service type not found".into())
            })?;
            Ok(Json(RegionResponse::Services(services.clone())))
        }
    }
}

// ── Startup validation ────────────────────────────────────────────────────────

/// Mirrors the Python validation logic. With serde, structural shape is already
/// guaranteed (wrong types/missing keys won't deserialise), so this only needs
/// to catch semantic rules you want to enforce at startup.
fn validate_config(config: &Config) -> Result<(), String> {
    if config.regions.is_empty() {
        return Err("'regions' must not be empty".into());
    }
    for (region_id, region) in &config.regions {
        for (svc_type, services) in region {
            if services.is_empty() {
                return Err(format!(
                    "Service list for '{svc_type}' in region '{region_id}' must not be empty"
                ));
            }
            for svc in services {
                if svc.name.is_empty() || svc.address.is_empty() {
                    return Err(format!(
                        "'name' and 'address' must be non-empty strings \
                         in region '{region_id}', service type '{svc_type}'"
                    ));
                }
            }
        }
    }
    Ok(())
}

// ── Entry point ───────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() {
    let raw = std::fs::read_to_string("apc.toml").expect("Failed to read apc.toml");
    let config: Config = toml::from_str(&raw).expect("Failed to parse TOML config");
    validate_config(&config).expect("Invalid config");

    let state = AppState {
        config: Arc::new(config),
    };

    let app = Router::new()
        .route("/regions/{region_id}", get(read_region))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:8000")
        .await
        .unwrap();

    println!("Listening on http://0.0.0.0:8000");
    axum::serve(listener, app).await.unwrap();
}
