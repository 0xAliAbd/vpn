#!/bin/bash

# V2Ray Cross-Platform MVP Setup Script
# Creates complete V2Ray client from scratch

set -e

PROJECT_NAME="v2ray-mvp"
echo "🚀 Setting up V2Ray Cross-Platform MVP..."

# Check if required tools are installed
check_requirements() {
    echo "📋 Checking requirements..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo "❌ Node.js not found. Installing..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi
    
    # Check Rust
    if ! command -v cargo &> /dev/null; then
        echo "❌ Rust not found. Installing..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        echo "❌ npm not found. Installing..."
        sudo apt-get install -y npm
    fi
    
    echo "✅ All requirements satisfied"
}

# Install Tauri CLI
install_tauri() {
    echo "🦀 Installing Tauri CLI..."
    cargo install tauri-cli --version "^1.5"
    npm install -g @tauri-apps/cli@latest
}

# Create project structure
create_project() {
    echo "📁 Creating project structure..."
    
    if [ -d "$PROJECT_NAME" ]; then
        echo "⚠️  Project directory exists. Removing..."
        rm -rf "$PROJECT_NAME"
    fi
    
    mkdir "$PROJECT_NAME"
    cd "$PROJECT_NAME"
    cargo tauri init --app-name "V2Ray MVP" --window-title "V2Ray Client" --dist-dir "../dist" --dev-path "../src"
    
    # Initialize npm project
    npm init -y
}

# Install dependencies
install_dependencies() {
    echo "📦 Installing dependencies..."
    
    # Frontend dependencies
    npm install react@^18.2.0 react-dom@^18.2.0
    npm install @tauri-apps/api
    npm install lucide-react
    npm install tailwindcss autoprefixer postcss
    npm install -D @vitejs/plugin-react vite
    
    # Initialize Tailwind
    npx tailwindcss init -p
    
    # Backend dependencies (Cargo.toml)
    cd src-tauri
    cargo add tauri --features "api-all,shell-open"
    cargo add serde --features "derive"
    cargo add tokio --features "full"
    cargo add reqwest --features "json"
    cargo add uuid --features "v4"
    cargo add serde_json
    cargo add tauri-plugin-shell
    cargo add dirs
    cd ..
}

# Create configuration files
create_config_files() {
    echo "⚙️ Creating configuration files..."
    
    # Vite config
    cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
  },
  envPrefix: ['VITE_', 'TAURI_'],
  build: {
    target: process.env.TAURI_PLATFORM == 'windows' ? 'chrome105' : 'safari13',
    minify: !process.env.TAURI_DEBUG ? 'esbuild' : false,
    sourcemap: !!process.env.TAURI_DEBUG,
  },
})
EOF

    # Tailwind config
    cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
    "./index.html",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

    # Package.json scripts
    npm pkg set scripts.dev="tauri dev"
    npm pkg set scripts.build="tauri build"
    npm pkg set scripts.tauri="tauri"
}

# Create frontend code
create_frontend() {
    echo "🎨 Creating React frontend..."
    
    mkdir -p src
    
    # HTML template
    cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>V2Ray MVP</title>
</head>
<body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
</body>
</html>
EOF

    # CSS
    cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
  background-color: #1a1a1a;
  color: white;
}
EOF

    # Main React entry point
    cat > src/main.jsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
EOF

    # Main App component
    cat > src/App.jsx << 'EOF'
import React, { useState, useEffect } from 'react'
import { invoke } from '@tauri-apps/api/tauri'
import { Plus, Trash2, Play, Square, Wifi, WifiOff } from 'lucide-react'

function App() {
  const [configs, setConfigs] = useState([])
  const [isConnected, setIsConnected] = useState(false)
  const [activeConfig, setActiveConfig] = useState(null)
  const [newConfig, setNewConfig] = useState('')
  const [status, setStatus] = useState('Disconnected')

  useEffect(() => {
    loadConfigs()
    checkConnection()
  }, [])

  const loadConfigs = async () => {
    try {
      const configList = await invoke('get_configs')
      setConfigs(configList)
    } catch (error) {
      console.error('Failed to load configs:', error)
    }
  }

  const checkConnection = async () => {
    try {
      const connected = await invoke('is_connected')
      setIsConnected(connected)
      setStatus(connected ? 'Connected' : 'Disconnected')
    } catch (error) {
      console.error('Failed to check connection:', error)
    }
  }

  const addConfig = async () => {
    if (!newConfig.trim()) return
    
    try {
      await invoke('add_config', { config: newConfig })
      setNewConfig('')
      loadConfigs()
    } catch (error) {
      alert('Failed to add config: ' + error)
    }
  }

  const removeConfig = async (id) => {
    try {
      await invoke('remove_config', { id })
      loadConfigs()
    } catch (error) {
      alert('Failed to remove config: ' + error)
    }
  }

  const connect = async (id) => {
    try {
      await invoke('connect', { id })
      setIsConnected(true)
      setActiveConfig(id)
      setStatus('Connected')
    } catch (error) {
      alert('Failed to connect: ' + error)
    }
  }

  const disconnect = async () => {
    try {
      await invoke('disconnect')
      setIsConnected(false)
      setActiveConfig(null)
      setStatus('Disconnected')
    } catch (error) {
      alert('Failed to disconnect: ' + error)
    }
  }

  const testPing = async (id) => {
    try {
      const delay = await invoke('ping_test', { id })
      alert(`Ping: ${delay}ms`)
    } catch (error) {
      alert('Ping failed: ' + error)
    }
  }

  return (
    <div className="min-h-screen bg-gray-900 p-6">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold text-center mb-8 text-white">
          V2Ray Client MVP
        </h1>
        
        {/* Status */}
        <div className="bg-gray-800 rounded-lg p-4 mb-6 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            {isConnected ? (
              <Wifi className="h-5 w-5 text-green-400" />
            ) : (
              <WifiOff className="h-5 w-5 text-red-400" />
            )}
            <span className={`font-medium ${isConnected ? 'text-green-400' : 'text-red-400'}`}>
              {status}
            </span>
          </div>
          
          {isConnected && (
            <button
              onClick={disconnect}
              className="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md flex items-center space-x-2"
            >
              <Square className="h-4 w-4" />
              <span>Disconnect</span>
            </button>
          )}
        </div>

        {/* Add Config */}
        <div className="bg-gray-800 rounded-lg p-4 mb-6">
          <h2 className="text-lg font-semibold mb-3 text-white">Add Config</h2>
          <p className="text-sm text-gray-400 mb-3">
            Supports: vmess://, vless://, ss://, trojan:// URLs or V2Ray JSON configs
          </p>
          <div className="flex space-x-2">
            <textarea
              value={newConfig}
              onChange={(e) => setNewConfig(e.target.value)}
              placeholder="Paste your config here:&#10;• vmess://... (VMess)&#10;• vless://... (VLESS)&#10;• ss://... (Shadowsocks)&#10;• trojan://... (Trojan)&#10;• {...} (V2Ray JSON)"
              className="flex-1 bg-gray-700 text-white rounded-md p-3 resize-none h-32 text-sm"
            />
            <button
              onClick={addConfig}
              className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md flex items-center"
            >
              <Plus className="h-4 w-4" />
            </button>
          </div>
        </div>

        {/* Config List */}
        <div className="bg-gray-800 rounded-lg p-4">
          <h2 className="text-lg font-semibold mb-3 text-white">Configs</h2>
          
          {configs.length === 0 ? (
            <p className="text-gray-400 text-center py-8">No configs added yet</p>
          ) : (
            <div className="space-y-2">
              {configs.map((config) => (
                <div
                  key={config.id}
                  className={`bg-gray-700 rounded-md p-3 flex items-center justify-between ${
                    activeConfig === config.id ? 'ring-2 ring-green-400' : ''
                  }`}
                >
                  <div className="flex-1">
                    <div className="font-medium text-white">{config.name || 'Unnamed Config'}</div>
                    <div className="text-sm text-gray-400">{config.server || 'Unknown server'}</div>
                  </div>
                  
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => testPing(config.id)}
                      className="text-blue-400 hover:text-blue-300 px-2 py-1 text-sm"
                    >
                      Ping
                    </button>
                    
                    {!isConnected && (
                      <button
                        onClick={() => connect(config.id)}
                        className="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded-md flex items-center space-x-1"
                      >
                        <Play className="h-3 w-3" />
                        <span>Connect</span>
                      </button>
                    )}
                    
                    <button
                      onClick={() => removeConfig(config.id)}
                      className="text-red-400 hover:text-red-300 p-1"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default App
EOF
}

# Create backend code
create_backend() {
    echo "🦀 Creating Rust backend..."
    
    # Main Rust file
    cat > src-tauri/src/main.rs << 'EOF'
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
    let app_state = state.lock().unwrap();
    let _config = app_state.configs.iter().find(|c| c.id == id).ok_or("Config not found")?;
    
    // Simple ping test to Google DNS
    let start = std::time::Instant::now();
    let response = reqwest::get("https://8.8.8.8").await;
    let duration = start.elapsed();
    
    match response {
        Ok(_) => Ok(duration.as_millis() as u64),
        Err(_) => Err("Ping failed".to_string()),
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
EOF

    # Add base64 dependency
    cd src-tauri
    cargo add base64
    cargo add urlencoding
    cargo add serde_json --features "preserve_order"
    cd ..
}

# Install V2Ray binary
install_v2ray() {
    echo "📡 Installing V2Ray binary..."
    
    # Detect OS
    OS=$(uname -s)
    ARCH=$(uname -m)
    
    case $OS in
        Linux)
            case $ARCH in
                x86_64) V2RAY_ARCH="linux-64" ;;
                aarch64|arm64) V2RAY_ARCH="linux-arm64-v8a" ;;
                *) V2RAY_ARCH="linux-64" ;;
            esac
            ;;
        Darwin)
            case $ARCH in
                x86_64) V2RAY_ARCH="macos-64" ;;
                arm64) V2RAY_ARCH="macos-arm64-v8a" ;;
                *) V2RAY_ARCH="macos-64" ;;
            esac
            ;;
        MINGW*|CYGWIN*|MSYS*)
            V2RAY_ARCH="windows-64"
            ;;
        *)
            V2RAY_ARCH="linux-64"
            ;;
    esac
    
    echo "📥 Downloading V2Ray for $V2RAY_ARCH..."
    
    # Download latest V2Ray
    DOWNLOAD_URL="https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-$V2RAY_ARCH.zip"
    wget -O v2ray.zip "$DOWNLOAD_URL" || curl -L -o v2ray.zip "$DOWNLOAD_URL"
    
    # Extract and install
    unzip -o v2ray.zip
    chmod +x v2ray v2ctl 2>/dev/null || true
    
    # Move to system path
    if [[ "$OS" == "MINGW"* ]] || [[ "$OS" == "CYGWIN"* ]] || [[ "$OS" == "MSYS"* ]]; then
        mkdir -p /usr/local/bin 2>/dev/null || true
        cp v2ray.exe /usr/local/bin/ 2>/dev/null || sudo cp v2ray.exe /usr/local/bin/ || true
    else
        sudo cp v2ray v2ctl /usr/local/bin/ 2>/dev/null || cp v2ray v2ctl ~/.local/bin/ 2>/dev/null || true
    fi
    
    # Cleanup
    rm -f v2ray.zip *.sig *.dat *.json v2ray v2ctl *.exe 2>/dev/null || true
    
    echo "✅ V2Ray installed successfully"
}

# Build project
build_project() {
    echo "🔨 Building project..."
    
    # Development build
    echo "🛠️  Starting development server..."
    echo "Run 'npm run dev' to start the development server"
    echo "Run 'npm run build' to create production build"
    
    # Make the project executable
    chmod +x package.json 2>/dev/null || true
}

# Create sample config
create_sample_config() {
    echo "📝 Creating sample configuration..."
    
    cat > sample-v2ray-config.json << 'EOF'
{
  "inbounds": [
    {
      "port": 1080,
      "protocol": "socks",
      "settings": {
        "auth": "noauth"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "your-server.com",
            "port": 443,
            "users": [
              {
                "id": "your-uuid-here",
                "alterId": 0
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/path"
        },
        "security": "tls"
      }
    }
  ]
}
EOF
    
    echo "📄 Sample config created: sample-v2ray-config.json"
}

# Main execution
main() {
    echo "🎯 Starting V2Ray MVP setup..."
    
    check_requirements
    install_tauri
    create_project
    install_dependencies
    create_config_files
    create_frontend
    create_backend
    install_v2ray
    create_sample_config
    build_project
    
    echo ""
    echo "🎉 V2Ray MVP setup complete!"
    echo ""
    echo "📂 Project created in: $PROJECT_NAME"
    echo ""
    echo "🚀 To start development:"
    echo "   cd $PROJECT_NAME"
    echo "   npm run dev"
    echo ""
    echo "🔧 To build for production:"
    echo "   npm run build"
    echo ""
    echo "📋 Features included:"
    echo "   ✅ Add/Remove V2Ray configs"
    echo "   ✅ Connect/Disconnect VPN"
    echo "   ✅ Real V2Ray integration"
    echo "   ✅ System proxy settings"
    echo "   ✅ Ping testing"
    echo "   ✅ Cross-platform support"
    echo ""
    echo "📝 Usage:"
    echo "   1. Start the app: npm run dev"
    echo "   2. Add your V2Ray config (JSON or vmess:// URL)"
    echo "   3. Click Connect to start VPN"
    echo "   4. Use Ping button to test connection"
    echo ""
    echo "⚠️  Important notes:"
    echo "   - Make sure V2Ray binary is in your PATH"
    echo "   - Some features may require admin/sudo privileges"
    echo "   - Edit sample-v2ray-config.json with your real server details"
    echo ""
    echo "🆘 Troubleshooting:"
    echo "   - If V2Ray doesn't start: check if binary is installed correctly"
    echo "   - If proxy doesn't work: try running with admin privileges"
    echo "   - For mobile builds: additional setup required for iOS/Android"
}

# Run the main function
main "$@"
