#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::Mutex;
use tauri::State;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone)]
struct V2RayConfig {
    id: String,
    name: String,
    server: String,
    config_json: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct AppState {
    configs: Vec<V2RayConfig>,
    active_connection: Option<String>,
    v2ray_process: Option<u32>,
}

type AppStateType = Mutex<AppState>;

fn get_config_dir() -> PathBuf {
    let mut config_dir = dirs::config_dir().unwrap_or_else(|| PathBuf::from("."));
    config_dir.push("v2ray-mvp");
    if !config_dir.exists() {
        fs::create_dir_all(&config_dir).unwrap();
    }
    config_dir
}

fn load_state() -> AppState {
    let config_file = get_config_dir().join("state.json");
    if config_file.exists() {
        let content = fs::read_to_string(config_file).unwrap_or_default();
        serde_json::from_str(&content).unwrap_or_else(|_| AppState {
            configs: Vec::new(),
            active_connection: None,
            v2ray_process: None,
        })
    } else {
        AppState {
            configs: Vec::new(),
            active_connection: None,
            v2ray_process: None,
        }
    }
}

fn save_state(state: &AppState) {
    let config_file = get_config_dir().join("state.json");
    let content = serde_json::to_string_pretty(state).unwrap();
    fs::write(config_file, content).unwrap();
}

fn convert_to_v2ray_config(config_str: &str) -> Result<String, String> {
    let config_str = config_str.trim();

    // If it's already JSON, return as-is
    if config_str.starts_with('{') {
        return Ok(config_str.to_string());
    }

    // Convert Shadowsocks to V2Ray config
    if config_str.starts_with("ss://") {
        let url_part = config_str.trim_start_matches("ss://");
        let parts: Vec<&str> = url_part.split('#').collect();
        let main_part = parts[0];

        let at_split: Vec<&str> = main_part.split('@').collect();
        if at_split.len() == 2 {
            let method_password = String::from_utf8(base64::decode(at_split[0]).unwrap_or_default()).unwrap_or_default();
            let method_pass_parts: Vec<&str> = method_password.split(':').collect();

            if method_pass_parts.len() >= 2 {
                let method = method_pass_parts[0];
                let password = method_pass_parts[1..].join(":");
                let server_port: Vec<&str> = at_split[1].split(':').collect();

                if server_port.len() == 2 {
                    let server = server_port[0];
                    let port: u16 = server_port[1].parse().unwrap_or(443);

                    let v2ray_config = serde_json::json!({
                        "inbounds": [{
                            "port": 1080,
                            "protocol": "socks",
                            "settings": { "auth": "noauth" }
                        }],
                        "outbounds": [{
                            "protocol": "shadowsocks",
                            "settings": {
                                "servers": [{
                                    "address": server,
                                    "port": port,
                                    "method": method,
                                    "password": password
                                }]
                            }
                        }]
                    });
                    return Ok(v2ray_config.to_string());
                }
            }
        }
    }

    // Convert VLESS to V2Ray config
    if config_str.starts_with("vless://") {
        let url_part = config_str.trim_start_matches("vless://");
        let parts: Vec<&str> = url_part.split('#').collect();
        let main_part = parts[0];

        let query_split: Vec<&str> = main_part.split('?').collect();
        let main_url = query_split[0];

        let at_split: Vec<&str> = main_url.split('@').collect();
        if at_split.len() == 2 {
            let uuid = at_split[0];
            let server_port: Vec<&str> = at_split[1].split(':').collect();

            if server_port.len() == 2 {
                let server = server_port[0];
                let port: u16 = server_port[1].parse().unwrap_or(443);

                // Parse query parameters
                let mut flow = "xtls-rprx-vision";
                let mut security = "reality";
                let mut sni = "tesla.com";

                if query_split.len() > 1 {
                    for param in query_split[1].split('&') {
                        let kv: Vec<&str> = param.split('=').collect();
                        if kv.len() == 2 {
                            match kv[0] {
                                "flow" => flow = kv[1],
                                "security" => security = kv[1],
                                "sni" => sni = kv[1],
                                _ => {}
                            }
                        }
                    }
                }

                let v2ray_config = serde_json::json!({
                    "inbounds": [{
                        "port": 1080,
                        "protocol": "socks",
                        "settings": { "auth": "noauth" }
                    }],
                    "outbounds": [{
                        "protocol": "vless",
                        "settings": {
                            "vnext": [{
                                "address": server,
                                "port": port,
                                "users": [{
                                    "id": uuid,
                                    "flow": flow,
                                    "encryption": "none"
                                }]
                            }]
                        },
                        "streamSettings": {
                            "network": "tcp",
                            "security": security,
                            "tlsSettings": {
                                "serverName": sni
                            }
                        }
                    }]
                });
                return Ok(v2ray_config.to_string());
            }
        }
    }

    // Convert VMess to V2Ray config
    if config_str.starts_with("vmess://") {
        let encoded = config_str.trim_start_matches("vmess://");
        if let Ok(decoded) = base64::decode(encoded) {
            if let Ok(json_str) = String::from_utf8(decoded) {
                if let Ok(vmess_config) = serde_json::from_str::<serde_json::Value>(&json_str) {
                    let address = vmess_config.get("add").and_then(|v| v.as_str()).unwrap_or("");
                    let port = vmess_config.get("port").and_then(|v| v.as_u64()).unwrap_or(443) as u16;
                    let uuid = vmess_config.get("id").and_then(|v| v.as_str()).unwrap_or("");
                    let net = vmess_config.get("net").and_then(|v| v.as_str()).unwrap_or("tcp");
                    let tls = vmess_config.get("tls").and_then(|v| v.as_str()).unwrap_or("");

                    let v2ray_config = serde_json::json!({
                        "inbounds": [{
                            "port": 1080,
                            "protocol": "socks",
                            "settings": { "auth": "noauth" }
                        }],
                        "outbounds": [{
                            "protocol": "vmess",
                            "settings": {
                                "vnext": [{
                                    "address": address,
                                    "port": port,
                                    "users": [{
                                        "id": uuid,
                                        "alterId": 0
                                    }]
                                }]
                            },
                            "streamSettings": {
                                "network": net,
                                "security": if tls == "tls" { "tls" } else { "none" }
                            }
                        }]
                    });
                    return Ok(v2ray_config.to_string());
                }
            }
        }
    }

    Err("Unsupported config format".to_string())
}

fn parse_v2ray_config(config_str: &str) -> Result<(String, String), String> {
    let config_str = config_str.trim();

    // Try to parse as JSON first
    if let Ok(json_value) = serde_json::from_str::<serde_json::Value>(config_str) {
        let name = json_value
            .get("ps")
            .or_else(|| json_value.get("name"))
            .and_then(|v| v.as_str())
            .unwrap_or("JSON Config")
            .to_string();

        let server = json_value
            .get("outbounds")
            .and_then(|v| v.as_array())
            .and_then(|arr| arr.first())
            .and_then(|v| v.get("settings"))
            .and_then(|v| v.get("vnext"))
            .and_then(|v| v.as_array())
            .and_then(|arr| arr.first())
            .and_then(|v| v.get("address"))
            .and_then(|v| v.as_str())
            .unwrap_or("Unknown")
            .to_string();

        return Ok((name, server));
    }

    // Parse Shadowsocks (ss://)
    if config_str.starts_with("ss://") {
        let url_part = config_str.trim_start_matches("ss://");
        let parts: Vec<&str> = url_part.split('#').collect();
        let name = if parts.len() > 1 {
            urlencoding::decode(parts[1]).unwrap_or_default().to_string()
        } else {
            "Shadowsocks Config".to_string()
        };

        let main_part = parts[0];
        let at_split: Vec<&str> = main_part.split('@').collect();
        if at_split.len() == 2 {
            let server_port: Vec<&str> = at_split[1].split(':').collect();
            let server = server_port[0].to_string();
            return Ok((name, server));
        }
    }

    // Parse VLESS (vless://)
    if config_str.starts_with("vless://") {
        let url_part = config_str.trim_start_matches("vless://");
        let parts: Vec<&str> = url_part.split('#').collect();
        let name = if parts.len() > 1 {
            urlencoding::decode(parts[1]).unwrap_or_default().to_string()
        } else {
            "VLESS Config".to_string()
        };

        let main_part = parts[0].split('?').next().unwrap_or("");
        let at_split: Vec<&str> = main_part.split('@').collect();
        if at_split.len() == 2 {
            let server_port: Vec<&str> = at_split[1].split(':').collect();
            let server = server_port[0].to_string();
            return Ok((name, server));
        }
    }

    // Parse VMess (vmess://)
    if config_str.starts_with("vmess://") {
        let encoded = config_str.trim_start_matches("vmess://");
        if let Ok(decoded) = base64::decode(encoded) {
            if let Ok(json_str) = String::from_utf8(decoded) {
                if let Ok(json_value) = serde_json::from_str::<serde_json::Value>(&json_str) {
                    let name = json_value.get("ps").and_then(|v| v.as_str()).unwrap_or("VMess Config").to_string();
                    let server = json_value.get("add").and_then(|v| v.as_str()).unwrap_or("Unknown").to_string();
                    return Ok((name, server));
                }
            }
        }
    }

    // Parse Trojan (trojan://)
    if config_str.starts_with("trojan://") {
        let url_part = config_str.trim_start_matches("trojan://");
        let parts: Vec<&str> = url_part.split('#').collect();
        let name = if parts.len() > 1 {
            urlencoding::decode(parts[1]).unwrap_or_default().to_string()
        } else {
            "Trojan Config".to_string()
        };

        let main_part = parts[0].split('?').next().unwrap_or("");
        let at_split: Vec<&str> = main_part.split('@').collect();
        if at_split.len() == 2 {
            let server_port: Vec<&str> = at_split[1].split(':').collect();
            let server = server_port[0].to_string();
            return Ok((name, server));
        }
    }

    Ok(("Custom Config".to_string(), "Unknown".to_string()))
}

#[tauri::command]
async fn get_configs(state: State<'_, AppStateType>) -> Result<Vec<V2RayConfig>, String> {
    let app_state = state.lock().unwrap();
    Ok(app_state.configs.clone())
}

#[tauri::command]
async fn add_config(config: String, state: State<'_, AppStateType>) -> Result<(), String> {
    let (name, server) = parse_v2ray_config(&config)?;
    let v2ray_json = convert_to_v2ray_config(&config)?;

    let new_config = V2RayConfig {
        id: Uuid::new_v4().to_string(),
        name,
        server,
        config_json: v2ray_json,
    };

    let mut app_state = state.lock().unwrap();
    app_state.configs.push(new_config);
    save_state(&app_state);

    Ok(())
}

#[tauri::command]
async fn remove_config(id: String, state: State<'_, AppStateType>) -> Result<(), String> {
    let mut app_state = state.lock().unwrap();
    app_state.configs.retain(|c| c.id != id);
    save_state(&app_state);

    Ok(())
}

#[tauri::command]
async fn connect(id: String, state: State<'_, AppStateType>) -> Result<(), String> {
    let mut app_state = state.lock().unwrap();

    // Find config
    let config = app_state.configs.iter().find(|c| c.id == id).ok_or("Config not found")?;

    // Stop existing connection
    if let Some(_) = app_state.active_connection {
        // Kill existing v2ray process
        #[cfg(target_os = "windows")]
        {
            Command::new("taskkill")
                .args(["/F", "/IM", "v2ray.exe"])
                .output()
                .ok();
        }
        #[cfg(not(target_os = "windows"))]
        {
            Command::new("pkill")
                .arg("v2ray")
                .output()
                .ok();
        }
    }

    // Write config to temporary file
    let config_dir = get_config_dir();
    let config_file = config_dir.join("current_config.json");
    fs::write(&config_file, &config.config_json).map_err(|e| e.to_string())?;

    // Start v2ray process
    let v2ray_cmd = if cfg!(target_os = "windows") {
        "v2ray.exe"
    } else {
        "v2ray"
    };

    let child = Command::new(v2ray_cmd)
        .arg("-config")
        .arg(&config_file)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("Failed to start v2ray: {}", e))?;

    app_state.active_connection = Some(id);
    app_state.v2ray_process = Some(child.id());
    save_state(&app_state);

    // Set system proxy
    set_system_proxy(true)?;

    Ok(())
}

#[tauri::command]
async fn disconnect(state: State<'_, AppStateType>) -> Result<(), String> {
    let mut app_state = state.lock().unwrap();

    // Kill v2ray process
    #[cfg(target_os = "windows")]
    {
        Command::new("taskkill")
            .args(["/F", "/IM", "v2ray.exe"])
            .output()
            .ok();
    }
    #[cfg(not(target_os = "windows"))]
    {
        Command::new("pkill")
            .arg("v2ray")
            .output()
            .ok();
    }

    app_state.active_connection = None;
    app_state.v2ray_process = None;
    save_state(&app_state);

    // Unset system proxy
    set_system_proxy(false)?;

    Ok(())
}

#[tauri::command]
async fn is_connected(state: State<'_, AppStateType>) -> Result<bool, String> {
    let app_state = state.lock().unwrap();
    Ok(app_state.active_connection.is_some())
}

#[tauri::command]
async fn ping_test(id: String, state: State<'_, AppStateType>) -> Result<u64, String> {
    // Scope for the MutexGuard
    {
        let app_state = state.lock().unwrap();
        // Check if config exists, but don't hold the lock longer than necessary.
        if !app_state.configs.iter().any(|c| c.id == id) {
            return Err("Config not found".to_string());
        }
    } // MutexGuard (`app_state`) is dropped here

    // Simple ping test to Google DNS
    let start = std::time::Instant::now();
    // Create a new client for this request to ensure Send safety if client isn't inherently Send
    let client = reqwest::Client::new();
    let response = client.get("https://8.8.8.8").send().await;
    let duration = start.elapsed();

    match response {
        Ok(res) if res.status().is_success() => Ok(duration.as_millis() as u64),
        Ok(res) => Err(format!("Ping request returned non-OK status: {}", res.status())),
        Err(e) => Err(format!("Ping failed: {}", e)),
    }
}

fn set_system_proxy(enable: bool) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        if enable {
            Command::new("reg")
                .args([
                    "add",
                    "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
                    "/v", "ProxyEnable",
                    "/t", "REG_DWORD",
                    "/d", "1",
                    "/f"
                ])
                .output()
                .map_err(|e| e.to_string())?;

            Command::new("reg")
                .args([
                    "add",
                    "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
                    "/v", "ProxyServer",
                    "/t", "REG_SZ",
                    "/d", "127.0.0.1:1080",
                    "/f"
                ])
                .output()
                .map_err(|e| e.to_string())?;
        } else {
            Command::new("reg")
                .args([
                    "add",
                    "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
                    "/v", "ProxyEnable",
                    "/t", "REG_DWORD",
                    "/d", "0",
                    "/f"
                ])
                .output()
                .map_err(|e| e.to_string())?;
        }
    }

    #[cfg(target_os = "macos")]
    {
        if enable {
            Command::new("networksetup")
                .args(["-setsocksfirewallproxy", "Wi-Fi", "127.0.0.1", "1080"])
                .output()
                .map_err(|e| e.to_string())?;
        } else {
            Command::new("networksetup")
                .args(["-setsocksfirewallproxystate", "Wi-Fi", "off"])
                .output()
                .map_err(|e| e.to_string())?;
        }
    }

    #[cfg(target_os = "linux")]
    {
        // Linux proxy settings vary by desktop environment
        // This is a simplified approach using gsettings for GNOME
        if enable {
            Command::new("gsettings")
                .args(["set", "org.gnome.system.proxy.socks", "host", "127.0.0.1"])
                .output()
                .ok();
            Command::new("gsettings")
                .args(["set", "org.gnome.system.proxy.socks", "port", "1080"])
                .output()
                .ok();
            Command::new("gsettings")
                .args(["set", "org.gnome.system.proxy", "mode", "manual"])
                .output()
                .ok();
        } else {
            Command::new("gsettings")
                .args(["set", "org.gnome.system.proxy", "mode", "none"])
                .output()
                .ok();
        }
    }

    Ok(())
}

fn main() {
    let initial_state = load_state();

    tauri::Builder::default()
        .manage(AppStateType::new(initial_state))
        .invoke_handler(tauri::generate_handler![
            get_configs,
            add_config,
            remove_config,
            connect,
            disconnect,
            is_connected,
            ping_test
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
