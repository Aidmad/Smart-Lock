import 'package:flutter/material.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Lock',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SmartLockPage(),
    );
  }
}

class SmartLockPage extends StatefulWidget {
  const SmartLockPage({super.key});

  @override
  State<SmartLockPage> createState() => _SmartLockPageState();
}

class _SmartLockPageState extends State<SmartLockPage> {
  List<ScanResult> devices = [];

  bool isScanning = false;

  Set<String> whitelistedDevices = {}; // Store whitelisted device IDs

  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _checkBluetoothState();
    _loadWhitelistedDevices();
  }

  Future<void> _checkBluetoothState() async {
    if (await FlutterBluePlus.isSupported == false) {
      _showError('Bluetooth not supported on this device');

      return;
    }

    // Request permissions

    if (!await FlutterBluePlus.isOn) {
      await FlutterBluePlus.turnOn();
    }
  }

  Future<void> startScan() async {
    try {
      // Request permissions first

      await FlutterBluePlus.turnOn();

      setState(() {
        devices.clear();

        isScanning = true;
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        androidUsesFineLocation: false,
      );

      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          devices = results;
        });
      });

      FlutterBluePlus.isScanning.listen((scanning) {
        setState(() {
          isScanning = scanning;
        });
      });
    } catch (e) {
      _showError('Failed to scan: $e');
    }
  }

  Future<void> _loadWhitelistedDevices() async {
    // TODO: Implement loading from SharedPreferences
    // For demo, adding a test device ID
    setState(() {
      whitelistedDevices = {'TEST_DEVICE_ID'};
    });
  }

  Future<void> _saveWhitelistedDevices() async {
    // TODO: Implement saving to SharedPreferences
  }

  Future<void> _connectAndAuthenticate(
      BluetoothDevice device, String password) async {
    try {
      await device.connect();

      // TODO: Replace with actual smart lock password validation
      // This is a placeholder for demo purposes
      if (password == "1234") {
        // Add device to whitelist
        setState(() {
          whitelistedDevices.add(device.id.toString());
        });
        await _saveWhitelistedDevices();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device authenticated and whitelisted')),
        );
      } else {
        await device.disconnect();
        _showError('Invalid password');
        return;
      }
    } catch (e) {
      _showError('Failed to connect: $e');
    }
  }

  Future<void> _unlock(BluetoothDevice device) async {
    try {
      await device.connect();

      // TODO: Implement actual unlock command to smart lock
      // This would involve writing to a specific characteristic
      // Example: await device.writeCharacteristic(unlockCharacteristic, [1]);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Door unlocked successfully')),
      );

      await device.disconnect();
    } catch (e) {
      _showError('Failed to unlock: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showPasswordDialog(BluetoothDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Password'),
        content: TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Enter smart lock password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final password = _passwordController.text;
              _passwordController.clear();
              Navigator.pop(context);
              _connectAndAuthenticate(device, password);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If no devices found, show scanning message
    if (devices.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Smart Lock'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(isScanning ? 'Scanning...' : 'No devices found'),
              const SizedBox(height: 16),
              if (!isScanning)
                ElevatedButton(
                  onPressed: startScan,
                  child: const Text('Start Scan'),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Lock'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index].device;
          final isWhitelisted =
              whitelistedDevices.contains(device.id.toString());

          if (isWhitelisted) {
            // Show large unlock button for whitelisted devices
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      device.name.isEmpty ? 'Unknown Device' : device.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _unlock(device),
                      icon: const Icon(Icons.lock_open),
                      label: const Text('Unlock Door'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16.0),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show connect option for non-whitelisted devices
          return ListTile(
            title: Text(device.name.isEmpty ? 'Unknown Device' : device.name),
            subtitle: Text(device.id.toString()),
            trailing: ElevatedButton(
              onPressed: () => _showPasswordDialog(device),
              child: const Text('Connect'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? null : startScan,
        child: Icon(isScanning ? Icons.hourglass_empty : Icons.search),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();

    super.dispose();
  }
}







// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Smart Lock',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
//         useMaterial3: true,
//       ),
//       home: const SmartLockPage(),
//     );
//   }
// }

// class SmartLockPage extends StatefulWidget {
//   const SmartLockPage({super.key});

//   @override
//   State<SmartLockPage> createState() => _SmartLockPageState();
// }

// class _SmartLockPageState extends State<SmartLockPage> {
//   List<ScanResult> devices = [];
//   bool isScanning = false;
//   Set<String> authenticatedDevices = {}; // Store authenticated device IDs
//   final TextEditingController _passwordController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _checkBluetoothState();
//   }

//   Future<void> _checkBluetoothState() async {
//     if (await FlutterBluePlus.isSupported == false) {
//       _showError('Bluetooth not supported on this device');
//       return;
//     }

//     // Request permissions
//     if (!await FlutterBluePlus.isOn) {
//       await FlutterBluePlus.turnOn();
//     }
//   }

//   Future<void> startScan() async {
//     try {
//       // Request permissions first
//       await FlutterBluePlus.turnOn();
      
//       setState(() {
//         devices.clear();
//         isScanning = true;
//       });

//       await FlutterBluePlus.startScan(
//         timeout: const Duration(seconds: 4),
//         androidUsesFineLocation: false,
//       );

//       FlutterBluePlus.scanResults.listen((results) {
//         setState(() {
//           devices = results;
//         });
//       });

//       FlutterBluePlus.isScanning.listen((scanning) {
//         setState(() {
//           isScanning = scanning;
//         });
//       });
//     } catch (e) {
//       _showError('Failed to scan: $e');
//     }
//   }

//   Future<void> _connectWithPassword(
//       BluetoothDevice device, String password) async {
//     try {
//       await device.connect();
//       // Here you would validate password with the smart lock
//       // For now, simulating password check (replace with actual validation)
//       if (password == "Bakenty") {
//         // Replace with actual password validation
//         authenticatedDevices.add(device.id.toString());
//         setState(() {}); // Refresh UI to show unlock button
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text('Connected and authenticated successfully')),
//         );
//         Navigator.pop(context); // Close password dialog
//       } else {
//         await device.disconnect();
//         _showError('Invalid password');
//       }
//     } catch (e) {
//       _showError('Failed to connect: $e');
//     }
//   }

//   Future<void> _unlock(BluetoothDevice device) async {
//     try {
//       await device.connect();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Door unlocked successfully')),
//       );
//       // Optional: disconnect after successful unlock
//       await device.disconnect();
//     } catch (e) {
//       _showError('Failed to unlock: $e');
//     }
//   }

//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.red),
//     );
//   }

//   void _showPasswordDialog(BluetoothDevice device) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Enter Password'),
//         content: TextField(
//           controller: _passwordController,
//           obscureText: true,
//           decoration: const InputDecoration(
//             hintText: 'Enter smart lock password',
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () {
//               final password = _passwordController.text;
//               _passwordController.clear();
//               _connectWithPassword(device, password);
//             },
//             child: const Text('Connect'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Smart Lock'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       ),
//       body: ListView.builder(
//         itemCount: devices.length,
//         itemBuilder: (context, index) {
//           final device = devices[index].device;
//           return ListTile(
//             title: Text(device.name.isEmpty ? 'Unknown Device' : device.name),
//             subtitle: Text(device.id.toString()),
//             trailing: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 ElevatedButton(
//                   onPressed: () => _showPasswordDialog(device),
//                   child: const Text('Connect'),
//                 ),
//                 const SizedBox(width: 8),
//                 ElevatedButton(
//                   onPressed: () => _connectToDevice(device),
//                   child: const Text('Unlock'),
//                 ),
//               ],
//             ),
//             onTap: () => _showPasswordDialog(device),
//           );
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: isScanning ? null : startScan,
//         child: Icon(isScanning ? Icons.hourglass_empty : Icons.search),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _passwordController.dispose();
//     super.dispose();
//   }
// }
