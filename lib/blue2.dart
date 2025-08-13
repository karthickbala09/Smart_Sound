import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothEarbudsConnector extends StatefulWidget {
  @override
  _BluetoothEarbudsConnectorState createState() =>
      _BluetoothEarbudsConnectorState();
}

class _BluetoothEarbudsConnectorState extends State<BluetoothEarbudsConnector> {
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnecting = false;
  bool _connected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getPairedDevices();
  }

  Future<void> _getPairedDevices() async {
    setState(() => _isLoading = true);
    List<BluetoothDevice> devices = [];
    try {
      devices = await _bluetooth.getBondedDevices();
    } catch (e) {
      print("Error getting devices: $e");
    }
    setState(() {
      _devicesList = devices;
      _isLoading = false;
    });
  }

  void _connect() async {
    if (_selectedDevice == null) return;
    setState(() => _isConnecting = true);
    try {
      BluetoothConnection connection =
      await BluetoothConnection.toAddress(_selectedDevice!.address);
      setState(() {
        _connected = true;
        _isConnecting = false;
      });
      connection.input?.listen((data) {}).onDone(() {
        setState(() => _connected = false);
      });
    } catch (e) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to connect: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bluetooth Earbuds Connector")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              child: Text("Refresh Devices"),
              onPressed: _getPairedDevices,
            ),
            SizedBox(height: 16),
            _isLoading
                ? CircularProgressIndicator()
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
            SizedBox(height: 16),
            ElevatedButton(
              child: _isConnecting
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(_connected ? "Connected" : "Connect"),
              onPressed: _isConnecting || _connected ? null : _connect,
            ),
            if (_connected) ...[
              SizedBox(height: 16),
              Text("Connected to ${_selectedDevice?.name ?? _selectedDevice?.address}!"),
            ]
          ],
        ),
      ),
    );
  }
}