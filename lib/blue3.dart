import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:volume_controller/volume_controller.dart';

class SmartBLEConnector extends StatefulWidget {
  const SmartBLEConnector({Key? key}) : super(key: key);

  @override
  State<SmartBLEConnector> createState() => _SmartBLEConnectorState();
}

class _SmartBLEConnectorState extends State<SmartBLEConnector> {
  final FlutterBluePlus _flutterBlue = FlutterBluePlus();

  List<ScanResult> _scanResults = [];
  BluetoothDevice? _selectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _connected = false;

  int _listeningSeconds = 0;
  Timer? _sessionTimer;
  Timer? _disconnectTimer;
  int _timeLimitMinutes = 0;
  double _currentVolume = 0.0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    VolumeController.instance.getVolume().then((v) {
      setState(() => _currentVolume = v * 100);
    });
    VolumeController.instance.addListener(_volumeListener);
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      _startScan();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bluetooth & Location permissions required.")),
      );
    }
  }

  void _volumeListener(double v) {
    setState(() => _currentVolume = v * 100);
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5)).then((_) {
      setState(() => _isScanning = false);
    });
    FlutterBluePlus.scanResults.listen((results) {
      setState(() => _scanResults = results);
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() => _isConnecting = true);

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      setState(() {
        _selectedDevice = device;
        _connected = true;
        _isConnecting = false;
      });

      _startListeningTimer();

      if (_timeLimitMinutes > 0) {
        _startAutoDisconnectTimer();
      }

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _stopAllTimers();
          setState(() => _connected = false);
        }
      });
    } catch (e) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed: $e")),
      );
    }
  }

  void _disconnect() {
    _selectedDevice?.disconnect();
    _stopAllTimers();
    setState(() => _connected = false);
  }

  void _startListeningTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _listeningSeconds++);
    });
  }

  void _startAutoDisconnectTimer() {
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer(Duration(minutes: _timeLimitMinutes), () {
      _disconnect();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Time limit reached. Disconnected.")),
      );
    });
  }

  void _stopAllTimers() {
    _sessionTimer?.cancel();
    _disconnectTimer?.cancel();
    setState(() => _listeningSeconds = 0);
  }

  @override
  void dispose() {
    _stopAllTimers();
    VolumeController.instance.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String listeningTime =
        "${(_listeningSeconds ~/ 60).toString().padLeft(2, '0')}:${(_listeningSeconds % 60).toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(title: const Text("SMART SOUND – BLE Earbuds Connector")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Scan Devices"),
              onPressed: _isScanning ? null : _startScan,
            ),
            const SizedBox(height: 16),
            DropdownButton<BluetoothDevice>(
              hint: const Text("Select your earbuds"),
              value: _selectedDevice,
              onChanged: _connected
                  ? null
                  : (BluetoothDevice? device) {
                if (device != null) _connectToDevice(device);
              },
              items: _scanResults.map((result) {
                return DropdownMenuItem(
                  value: result.device,
                  child: Text(result.device.name.isNotEmpty
                      ? result.device.name
                      : result.device.remoteId.toString()),
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
                  : () {
                if (_selectedDevice != null) {
                  _connectToDevice(_selectedDevice!);
                }
              },
            ),
            if (_connected) ...[
              const SizedBox(height: 24),
              Text("Connected to: ${_selectedDevice?.name ?? _selectedDevice?.remoteId}"),
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
