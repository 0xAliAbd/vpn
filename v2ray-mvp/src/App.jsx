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
