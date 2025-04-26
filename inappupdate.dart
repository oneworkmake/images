import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Made Culture',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: const UpdateChecker(),
    );
  }
}

class UpdateChecker extends StatefulWidget {
  const UpdateChecker({Key? key}) : super(key: key);

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  String _currentVersion = 'Unknown';
  String _latestVersion = '';
  String _downloadUrl = '';
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForUpdate();
    });
  }

  Future<void> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _currentVersion = info.version;
      });

      final response = await http.get(
        Uri.parse(
            'https://raw.githubusercontent.com/oneworkmake/images/main/update.json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _latestVersion = data['apk']['version'];
        _downloadUrl = data['apk']['download_url'];

        debugPrint('Current version: $_currentVersion');
        debugPrint('Latest version: $_latestVersion');

        if (_isNewVersionAvailable(_currentVersion, _latestVersion)) {
          _showUpdateDialog();
        }
      } else {
        debugPrint(
            "Failed to fetch update info. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error during update check: $e");
    }
  }

  bool _isNewVersionAvailable(String current, String latest) {
    return latest.compareTo(current) > 0;
  }

  void _showUpdateDialog() {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Available"),
        content: Text("New version $_latestVersion is available."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Later"),
          ),
          ElevatedButton(
            onPressed: () async {
             
               _startDownload();
                  Navigator.of(context).pop();
            },
            child: const Text("Update Now"),
          ),
        ],
      ),
    );
  }

  void _startDownload() {
    setState(() {
      _downloadProgress = 0.01;
    });
    _downloadAndInstallApk(_downloadUrl);
  }

  Future<void> _downloadAndInstallApk(String url) async {
    try {
      final dir = await getTemporaryDirectory();
      if (dir == null) {
        debugPrint('Could not get external storage directory');
        return;
      }

      final filePath = '${dir.path}/update.apk';

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _downloadProgress = 0.0;
      });

      await OpenFilex.open(filePath);
    } catch (e) {
      debugPrint('Error downloading APK: $e');
      setState(() {
        _downloadProgress = 0.0;
      });
    }
  }
Future<void> _handlePermissionAndDownload() async {
  Navigator.of(context).pop(); // Close the dialog
await Permission.contacts.request();
  var status = await Permission.storage.status;
 
  if (status.isGranted) {
    // Permission already granted, proceed with download
    _startDownload();
  } else if (status.isDenied) {
    // Request permission only if not already requested
    try {
      // final permissionStatus = await Permission.storage.request();
      // if (permissionStatus.isGranted) {
      //   _startDownload();
      // } else {
      //   debugPrint("Storage permission denied.");
      // }
    } catch (e) {
      debugPrint("Error requesting permission: $e");
    }
  } else {
    debugPrint("Permission status: $status");
  }
} 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Update Checker")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Current App Version: $_currentVersion"),
            ElevatedButton(
              onPressed: _handlePermissionAndDownload,
              child: const Text("Check for Updates"),
            ),
            
            if (_downloadProgress > 0 && _downloadProgress < 1)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text("Downloading update..."),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _downloadProgress),
                    const SizedBox(height: 8),
                    Text("${(_downloadProgress * 100).toStringAsFixed(0)}%"),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
