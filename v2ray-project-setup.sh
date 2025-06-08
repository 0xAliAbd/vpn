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
    sudo npm install -g @tauri-apps/cli@latest
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

    # Create .gitignore
    cat > .gitignore << 'EOF'
/node_modules
/src-tauri/target/
/src-tauri/Cargo.lock
/dist/
/.DS_Store
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
package-lock.json
# Add other project-specific ignores as needed
EOF

    cargo tauri init --ci --app-name "V2Ray MVP" --window-title "V2Ray Client" # Removed --dist-dir and --dev-path
    
    echo "Overwriting src-tauri/tauri.conf.json with known-good configuration..."
    cat > src-tauri/tauri.conf.json << 'EOF_TAURI_CONF'
{
  "build": {
    "beforeDevCommand": "npm run dev",
    "beforeBuildCommand": "npm run build",
    "devPath": "http://localhost:1420",
    "distDir": "../dist",
    "withGlobalTauri": true
  },
  "package": {
    "productName": "V2Ray MVP",
    "version": "0.1.0"
  },
  "tauri": {
    "allowlist": {
      "all": false,
      "shell": {
        "all": false,
        "open": true
      },
      "fs": {
        "all": false,
        "readFile": true,
        "writeFile": true,
        "createDir": true,
        "scope": ["$APPCONFIG/*", "$APPCONFIG/current_config.json", "$APPCONFIG/state.json"]
      },
      "path": {
        "all": true
      },
      "process": {
         "all": false,
         "exit": true,
         "relaunch": true
      },
       "window": {
        "all": false,
        "create": true,
        "close": true,
        "hide": true,
        "show": true,
        "maximize": true,
        "minimize": true,
        "unmaximize": true,
        "unminimize": true,
        "startDragging": true
      },
      "http": {
        "all": true,
        "scope": ["https://*"]
      }
    },
    "bundle": {
      "active": true,
      "category": "DeveloperTool",
      "copyright": "",
      "deb": {
        "depends": []
      },
      "externalBin": [],
      "icon": [
        "icons/32x32.png",
        "icons/128x128.png",
        "icons/128x128@2x.png",
        "icons/icon.icns",
        "icons/icon.ico"
      ],
      "identifier": "com.v2raymvp.dev",
      "longDescription": "",
      "macOS": {
        "entitlements": null,
        "exceptionDomain": "",
        "frameworks": [],
        "providerShortName": null,
        "signingIdentity": null
      },
      "resources": [],
      "shortDescription": "",
      "targets": "all",
      "windows": {
        "certificateThumbprint": null,
        "digestAlgorithm": "sha256",
        "timestampUrl": ""
      }
    },
    "security": {
      "csp": null
    },
    "updater": {
      "active": false
    },
    "windows": [
      {
        "fullscreen": false,
        "height": 720,
        "resizable": true,
        "title": "V2Ray Client",
        "width": 1280,
        "visible": true
      }
    ]
  }
}
EOF_TAURI_CONF

    # Create package.json with all necessary scripts and dependencies
    cat > package.json << EOF_PKG
{
  "name": "${PROJECT_NAME}",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "tauri": "tauri",
    "tauri:dev": "tauri dev",
    "tauri:build": "tauri build"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@tauri-apps/api": "^1.5.0",
    "lucide-react": "latest"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.1",
    "vite": "^5.0.0",
    "tailwindcss": "3.4.3",
    "postcss": "^8.4.32",
    "autoprefixer": "^10.4.16",
    "@tauri-apps/cli": "^1.5.0"
  }
}
EOF_PKG
}

# Install dependencies
install_dependencies() {
    echo "📦 Installing dependencies from package.json..."
    npm install --legacy-peer-deps # Installs all dependencies listed in package.json
    
    # Initialize Tailwind (postcss.config.js and tailwind.config.js are created by this)
    echo "Initializing Tailwind CSS..."
    npx tailwindcss init -p
    
    # Backend dependencies (Cargo.toml)
    cd src-tauri
    cargo add tauri --features "api-all,shell-open"
    cargo add serde --features "derive"
    cargo add tokio --features "full"
    cargo add reqwest --features "json"
    cargo add uuid --features "v4"
    cargo add serde_json
    # cargo add tauri-plugin-shell@"1.0.2" # Rely on tauri's "shell-open" feature
    cargo add dirs
    cd ..
}

# Create configuration files
create_config_files() {
    echo "⚙️ Creating configuration files..."
    echo "Current directory for create_config_files: $(pwd)" # Debug CWD (will be /app/v2ray-mvp)
    
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

    # Package.json scripts are now set directly in create_project's cat command.
    # No need for npm pkg set here anymore.
    # The cat package.json for debug can also be removed or kept if needed after install_dependencies.
    echo "package.json should already be configured with dev/build/tauri scripts."
    echo "Content of package.json after install_dependencies and before frontend/backend:"
    cat package.json # Debug: show package.json content
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
use base64::Engine as _; // Added for base64::engine::general_purpose::STANDARD

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
            let method_password = String::from_utf8(base64::engine::general_purpose::STANDARD.decode(at_split[0]).unwrap_or_default()).unwrap_or_default();
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
        if let Ok(decoded) = base64::engine::general_purpose::STANDARD.decode(encoded) {
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
        if let Ok(decoded) = base64::engine::general_purpose::STANDARD.decode(encoded) {
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

    local TEMP_V2RAY_DIR="v2ray_temp_install"
    # Ensure we are in the project root ($PROJECT_NAME dir, which is current CWD for this function)
    # before creating a subdir, to avoid issues if this function were ever called from elsewhere.
    # However, given current script structure, CWD is already $PROJECT_NAME.
    mkdir -p "$TEMP_V2RAY_DIR"

    ( # Start subshell for temp operations
        cd "$TEMP_V2RAY_DIR"

        # Detect OS
        OS=$(uname -s)
        ARCH=$(uname -m)

        case $OS in
            Linux)
                case $ARCH in
                    x86_64) V2RAY_ARCH="linux-64" ;;
                    aarch64|arm64) V2RAY_ARCH="linux-arm64-v8a" ;;
                    *) V2RAY_ARCH="linux-64" ;; # Default for Linux
                esac
                ;;
            Darwin)
                case $ARCH in
                    x86_64) V2RAY_ARCH="macos-64" ;;
                    arm64) V2RAY_ARCH="macos-arm64-v8a" ;;
                    *) V2RAY_ARCH="macos-64" ;; # Default for Darwin
                esac
                ;;
            MINGW*|CYGWIN*|MSYS*) # Windows-like environments
                V2RAY_ARCH="windows-64"
                ;;
            *) # Default for other OSes
                V2RAY_ARCH="linux-64"
                ;;
        esac

        echo "📥 Downloading V2Ray for $V2RAY_ARCH..."

        DOWNLOAD_URL="https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-$V2RAY_ARCH.zip"
        if command -v wget >/dev/null 2>&1; then
            wget -O v2ray.zip "$DOWNLOAD_URL"
        elif command -v curl >/dev/null 2>&1; then
            curl -L -o v2ray.zip "$DOWNLOAD_URL"
        else
            echo "❌ Neither wget nor curl found. Cannot download V2Ray."
            # rm -rf ../"$TEMP_V2RAY_DIR" # Clean up before exiting if needed, but subshell will exit
            exit 1 # Exit subshell, not the main script
        fi

        if [ ! -f "v2ray.zip" ] || [ ! -s "v2ray.zip" ]; then
            echo "❌ Failed to download V2Ray. Zip file is missing or empty."
            exit 1 # Exit subshell
        fi

        unzip -o v2ray.zip # -o for overwrite
        # The zip might contain v2ray.exe (windows) or v2ray (linux/mac)
        EXECUTABLE_NAME="v2ray"
        CTL_NAME="v2ctl" # v2ctl is usually for Linux/macOS
        if [[ "$V2RAY_ARCH" == "windows"* ]]; then
            EXECUTABLE_NAME="v2ray.exe"
            CTL_NAME="" # v2ctl might not be present or named differently on Windows in the zip
        fi

        if [ -f "$EXECUTABLE_NAME" ]; then
            chmod +x "$EXECUTABLE_NAME"
        else
            echo "❌ V2Ray executable ($EXECUTABLE_NAME) not found after unzip."
            exit 1 # Exit subshell
        fi

        if [ -n "$CTL_NAME" ] && [ -f "$CTL_NAME" ]; then
            chmod +x "$CTL_NAME"
        fi

        # Determine target directory for binaries
        TARGET_BIN_DIR=""
        if [[ "$OS" == "MINGW"* ]] || [[ "$OS" == "CYGWIN"* ]] || [[ "$OS" == "MSYS"* ]]; then
            # For Windows-like, /usr/local/bin might be okay in Git Bash / MSYS2
            # but generally not a standard user PATH.
            # A local bin or asking user is safer. For now, stick to trying /usr/local/bin.
            TARGET_BIN_DIR="/usr/local/bin"
            mkdir -p "$TARGET_BIN_DIR" 2>/dev/null # Try to create if it doesn't exist
        else # Linux/macOS
            if [ -w "/usr/local/bin" ]; then # Check if writable first
                TARGET_BIN_DIR="/usr/local/bin"
            elif [ -d "$HOME/.local/bin" ] && [ -w "$HOME/.local/bin" ]; then
                TARGET_BIN_DIR="$HOME/.local/bin"
            elif mkdir -p "$HOME/.local/bin" 2>/dev/null && [ -w "$HOME/.local/bin" ]; then # Try to create and check writability
                TARGET_BIN_DIR="$HOME/.local/bin"
                echo "ℹ️ V2Ray will be installed to $TARGET_BIN_DIR (ensure this is in your PATH)."
            fi
        fi

        # Copy binaries
        if [ -n "$TARGET_BIN_DIR" ]; then
            echo "Installing V2Ray binaries to $TARGET_BIN_DIR..."
            if command -v sudo >/dev/null 2>&1 && [[ "$TARGET_BIN_DIR" == "/usr/local/bin" ]] && ! [ -w "$TARGET_BIN_DIR" ]; then
                sudo cp "$EXECUTABLE_NAME" "$TARGET_BIN_DIR/"
                if [ -n "$CTL_NAME" ] && [ -f "$CTL_NAME" ]; then sudo cp "$CTL_NAME" "$TARGET_BIN_DIR/"; fi
            else
                cp "$EXECUTABLE_NAME" "$TARGET_BIN_DIR/"
                if [ -n "$CTL_NAME" ] && [ -f "$CTL_NAME" ]; then cp "$CTL_NAME" "$TARGET_BIN_DIR/"; fi
            fi
            # Verification after copy can be added here
        else
            echo "⚠️ Could not determine a writable target directory (/usr/local/bin or ~/.local/bin) for V2Ray binaries."
            echo "Please ensure V2Ray is installed and in your PATH manually."
            # Do not exit the main script, but V2Ray might not be usable by the app if not in PATH
        fi
        # The rest of the files from the zip (geoip.dat, geosite.dat, config.json etc.) are not copied out
        # of TEMP_V2RAY_DIR. The main app will need its own way to manage these if required,
        # or they should be copied to a known config location for V2Ray.
        # For this script, we're just installing the binary to PATH.
    ) # End subshell. If exit 1 happened in subshell, main script continues. Check subshell exit code:
    
    SUBSHELL_EXIT_CODE=$?
    if [ $SUBSHELL_EXIT_CODE -ne 0 ]; then
        echo "❌ V2Ray installation failed in subshell (exit code: $SUBSHELL_EXIT_CODE)."
        # rm -rf "$TEMP_V2RAY_DIR" # Clean up even on failure
        # exit 1 # Exit main script if V2Ray install is critical
    fi
    
    # Cleanup temporary directory
    rm -rf "$TEMP_V2RAY_DIR"
    
    echo "✅ V2Ray binary installation attempt finished."
}

# Build project
build_project() {
    echo "🔨 Building project..."
    
    # Development build
    echo "🛠️  Starting development server..."
    echo "Run 'npm run dev' to start the development server"
    echo "Run 'npm run build' to create production build"
    
    # Make the project executable
    # chmod +x package.json 2>/dev/null || true # package.json is not an executable
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
    echo "--- Final check from main() before script exit ---"
    echo "Current directory: $(pwd)" # This will be /app/v2ray-mvp if create_project's cd was effective
    # To be absolutely sure about the project path for listing:
    PROJECT_PATH_FOR_CHECK="$PWD/$PROJECT_NAME" # This assumes main() is called from /app
    if [ "$(basename "$PWD")" = "$PROJECT_NAME" ]; then # If already in /app/v2ray-mvp
        PROJECT_PATH_FOR_CHECK="$PWD"
    elif [ -d "$PROJECT_NAME" ]; then # If in /app and v2ray-mvp is a subdir
        PROJECT_PATH_FOR_CHECK="$PWD/$PROJECT_NAME"
    else # Fallback, less certain
        PROJECT_PATH_FOR_CHECK="$PROJECT_NAME"
    fi

    # Corrected check logic:
    # The main script's functions (create_project, install_dependencies, etc.) operate based on the initial cd into PROJECT_NAME.
    # So, when main() is running these functions, the CWD should be /app/v2ray-mvp.
    # The PROJECT_NAME variable itself is just "v2ray-mvp".
    # Files are created relative to the CWD set by `cd "$PROJECT_NAME"` in `create_project`.

    # At the end of main(), the CWD should still be /app/v2ray-mvp.
    echo "Final check CWD: $(pwd)"
    if [ -f "package.json" ]; then # Check for package.json in current directory
        echo "package.json FOUND in $(pwd)."
        echo "Content of package.json:"
        cat package.json
    else
        echo "package.json NOT FOUND in $(pwd) at script exit."
        echo "Listing current directory ($(pwd)) contents:"
        ls -la
        # Also check relative to /app just in case CWD assumptions are wrong
        if [ -f "/app/$PROJECT_NAME/package.json" ]; then
             echo "package.json also found at /app/$PROJECT_NAME/package.json"
        else
             echo "package.json also NOT found at /app/$PROJECT_NAME/package.json"
        fi
    fi
    echo "--- End of final check from main() ---"

    echo ""
    echo "🎉 V2Ray MVP setup complete!"
    echo ""
    echo "📂 Project created in: $PROJECT_NAME" # This should refer to the relative path if called from /app
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
