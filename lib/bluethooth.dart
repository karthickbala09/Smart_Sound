import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:volume_controller/volume_controller.dart';

class SmartSoundConnector extends StatefulWidget {
  const SmartSoundConnector({Key? key}) : super(key: key);

  @override
  State<SmartSoundConnector> createState() => _SmartSoundConnectorState();
}

class _SmartSoundConnectorState extends State<SmartSoundConnector> {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _selectedDevice;
  BluetoothConnection? _connection;

  bool _isConnecting = false;
  bool _connected = false;
  bool _isLoading = true;

  int _listeningSeconds = 0;
  Timer? _sessionTimer;
  double _currentVolume = 0.0;

  int _timeLimitMinutes = 0;
  Timer? _disconnectTimer;
  @override
  void initState() {
    super.initState();
    _fetchPairedDevices();
    VolumeController.instance.getVolume().then((v) {
      setState(() => _currentVolume = v * 100);
    });
    VolumeController.instance.addListener(_volumeListener);
  }

  void _volumeListener(double v) {
    setState(() => _currentVolume = v * 100);
  }
  @override
  void dispose() {
    _stopAllTimers();
    VolumeController.instance.removeListener();
    super.dispose();
  }

  Future<void> _fetchPairedDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await _bluetooth.getBondedDevices();
      setState(() {
        _devicesList = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching devices: $e")),
        );
      }
    }
  }

  Future<void> _connect() async {
    if (_selectedDevice == null) return;
    setState(() => _isConnecting = true);
    try {
      final connection = await BluetoothConnection.toAddress(_selectedDevice!.address);

      setState(() {
        _connection = connection;
        _connected = true;
        _isConnecting = false;
      });

      _startListeningTimer();

      if (_timeLimitMinutes > 0) {
        _startAutoDisconnectTimer();
      }

      connection.input?.listen((data) {
        // Handle incoming data if needed
      }).onDone(() {
        _stopAllTimers();
        setState(() => _connected = false);
      });
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }

  void _disconnect() {
    _connection?.dispose();
    _stopAllTimers();
    setState(() => _connected = false);
  }

  void _startListeningTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _listeningSeconds++;
      });
    });
  }

  void _startAutoDisconnectTimer() {
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(Duration(minutes: _timeLimitMinutes), () {
      _disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Time limit reached. Disconnected.")),
        );
      }
    });
  }

  void _stopAllTimers() {
    _sessionTimer?.cancel();
    _disconnectTimer?.cancel();
    setState(() {
      _listeningSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String listeningTime =
        "${(_listeningSeconds ~/ 60).toString().padLeft(2, '0')}:${(_listeningSeconds % 60).toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text("SMART SOUND – Earbuds Connector"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh Devices"),
              onPressed: _fetchPairedDevices,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : DropdownButton<BluetoothDevice>(
              hint: Text(_devicesList.isEmpty
                  ? "No paired devices found"
                  : "Select your earbuds"),
              value: _selectedDevice,
              onChanged: _devicesList.isEmpty
                  ? null
                  : (BluetoothDevice? value) {
                setState(() => _selectedDevice = value);
              },
              items: _devicesList.map((device) {
                return DropdownMenuItem(
                  value: device,
                  child: Text(device.name ?? device.address),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Set Time Limit (minutes)",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _timeLimitMinutes = int.tryParse(value) ?? 0;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: _isConnecting
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Text(_connected ? "Disconnect" : "Connect"),
              onPressed: _isConnecting
                  ? null
                  : _connected
                  ? _disconnect
                  : _connect,
            ),
            if (_connected) ...[
              const SizedBox(height: 24),
              Text("Connected to: ${_selectedDevice?.name ?? _selectedDevice?.address}"),
              const SizedBox(height: 8),
              Text("Listening Time: $listeningTime"),
              const SizedBox(height: 8),
              Text("Current Volume: ${_currentVolume.toStringAsFixed(1)}%"),
            ]
          ],
        ),
      ),
    );
  }
}