import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MonitorScreen(),
    );
  }
}

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  late NoiseMeter noiseMeter;
  StreamSubscription<NoiseReading>? noiseSubscription;
  StreamSubscription<Position>? positionSubscription;
  VideoPlayerController? videoController;

  // Noise variables
  double orangeFrequency = 50.0;
  double redFrequency = 80.0;
  double currentFrequency = 0.0;
  bool isListening = false;

  // Speed variables
  double orangeSpeed = 5.0;
  double redSpeed = 10.0;
  double currentSpeed = 0.0;
  bool isTracking = false;

  // Shared variables
  String noiseFilePath = "No File Selected"; // For noise video
  String speedFilePath = "No File Selected"; // For speed video
  bool isVideoPlaying = false;
  DateTime? lastVideoCloseTime;
  static const int videoDelaySeconds = 3;

  // Drawer variables (New)
  String parentName = "Parent";
  String childName = "Child";

  @override
  void initState() {
    super.initState();
    noiseMeter = NoiseMeter();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) debugPrint("Microphone permission denied");
    }

    LocationPermission locPermission = await Geolocator.checkPermission();
    if (locPermission == LocationPermission.denied) {
      locPermission = await Geolocator.requestPermission();
      if (locPermission == LocationPermission.denied) debugPrint("Location permission denied");
    }
  }

  void startListening() async {
    if (isListening) return;
    stopTracking();
    bool hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) return;

    setState(() {
      isListening = true;
      currentFrequency = 0.0;
    });

    try {
      noiseSubscription = noiseMeter.noise.listen((NoiseReading noiseReading) {
        setState(() {
          currentFrequency = noiseReading.meanDecibel;
          if (currentFrequency >= redFrequency && noiseFilePath != "No File Selected" && !isVideoPlaying) {
            if (lastVideoCloseTime == null ||
                DateTime.now().difference(lastVideoCloseTime!).inSeconds >= videoDelaySeconds) {
              showVideoDialog(context, noiseFilePath);
            }
          }
        });
      }, onError: (e) => debugPrint("Noise error: $e"));
    } catch (e) {
      debugPrint("Error starting noise meter: $e");
      setState(() => isListening = false);
    }
  }

  void stopListening() {
    noiseSubscription?.cancel();
    setState(() {
      isListening = false;
      currentFrequency = 0.0;
    });
  }

  void startTracking() async {
    if (isTracking) return;
    stopListening();
    await _checkPermissions();

    setState(() {
      isTracking = true;
      currentSpeed = 0.0;
    });

    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1),
    ).listen((Position position) {
      setState(() {
        currentSpeed = position.speed;
        if (currentSpeed >= redSpeed && speedFilePath != "No File Selected" && !isVideoPlaying) {
          if (lastVideoCloseTime == null ||
              DateTime.now().difference(lastVideoCloseTime!).inSeconds >= videoDelaySeconds) {
            showVideoDialog(context, speedFilePath);
          }
        }
      });
    }, onError: (e) => debugPrint("Speed error: $e"));
  }

  void stopTracking() {
    positionSubscription?.cancel();
    setState(() {
      isTracking = false;
      currentSpeed = 0.0;
    });
  }

  Future<void> showVideoDialog(BuildContext context, String videoPath) async {
    if (isVideoPlaying) return;

    videoController?.dispose();
    videoController = VideoPlayerController.file(File(videoPath));

    try {
      await videoController!.initialize();
      if (!mounted) return;

      setState(() => isVideoPlaying = true);

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          videoController!.play();
          videoController!.setLooping(true);

          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: AspectRatio(
                aspectRatio: videoController!.value.aspectRatio,
                child: VideoPlayer(videoController!),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    videoController?.pause();
                    videoController?.dispose();
                    setState(() {
                      isVideoPlaying = false;
                      lastVideoCloseTime = DateTime.now();
                      videoController = null;
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Close"),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint("Video error: $e");
      setState(() {
        isVideoPlaying = false;
        lastVideoCloseTime = DateTime.now();
      });
      videoController?.dispose();
      videoController = null;
    }
  }

  Future<void> pickFile(bool isForNoise) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      setState(() {
        if (isForNoise) {
          noiseFilePath = result.files.single.path ?? "No File Selected";
        } else {
          speedFilePath = result.files.single.path ?? "No File Selected";
        }
      });
    }
  }

  @override
  void dispose() {
    stopListening();
    stopTracking();
    videoController?.dispose();
    super.dispose();
  }

  // New method to show dialog for editing names
  void _showEditNamesDialog() {
    TextEditingController parentController = TextEditingController(text: parentName);
    TextEditingController childController = TextEditingController(text: childName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Names"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: parentController,
              decoration: const InputDecoration(labelText: "Parent Name"),
            ),
            TextField(
              controller: childController,
              decoration: const InputDecoration(labelText: "Child Name"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                parentName = parentController.text.isNotEmpty ? parentController.text : "Parent";
                childName = childController.text.isNotEmpty ? childController.text : "Child";
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MITRA"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
              ),
              child: const Text(
                "Menu",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(parentName),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.child_care),
              title: Text(childName),
              onTap: () {
                Navigator.pop(context); // Close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Names"),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _showEditNamesDialog(); // Show edit dialog
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Noise Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "Noise Monitor",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Current Frequency: ${currentFrequency.toStringAsFixed(1)} dB",
                      style: TextStyle(
                        color: currentFrequency >= redFrequency
                            ? Colors.red
                            : currentFrequency >= orangeFrequency
                                ? Colors.orange
                                : Colors.green,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSlider(
                      "Orange Level",
                      orangeFrequency,
                      0,
                      20000,
                      (value) {
                        setState(() {
                          orangeFrequency = value;
                          if (orangeFrequency >= redFrequency) redFrequency = orangeFrequency + 1000;
                        });
                      },
                      "Hz",
                    ),
                    _buildSlider(
                      "Red Level",
                      redFrequency,
                      0,
                      20000,
                      (value) {
                        setState(() {
                          redFrequency = value;
                          if (redFrequency <= orangeFrequency) orangeFrequency = redFrequency - 1000;
                        });
                      },
                      "Hz",
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: startListening,
                          icon: const Icon(Icons.mic),
                          label: const Text("Start"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                        ElevatedButton.icon(
                          onPressed: stopListening,
                          icon: const Icon(Icons.stop),
                          label: const Text("Stop"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Speed Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "Speed Monitor",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blue),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Current Speed: ${currentSpeed.toStringAsFixed(1)} m/s",
                      style: TextStyle(
                        color: currentSpeed >= redSpeed
                            ? Colors.red
                            : currentSpeed >= orangeSpeed
                                ? Colors.orange
                                : Colors.green,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSlider(
                      "Orange Level",
                      orangeSpeed,
                      0,
                      50,
                      (value) {
                        setState(() {
                          orangeSpeed = value;
                          if (orangeSpeed >= redSpeed) redSpeed = orangeSpeed + 1;
                        });
                      },
                      "m/s",
                    ),
                    _buildSlider(
                      "Red Level",
                      redSpeed,
                      0,
                      50,
                      (value) {
                        setState(() {
                          redSpeed = value;
                          if (redSpeed <= orangeSpeed) orangeSpeed = redSpeed - 1;
                        });
                      },
                      "m/s",
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: startTracking,
                          icon: const Icon(Icons.speed),
                          label: const Text("Start"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                        ElevatedButton.icon(
                          onPressed: stopTracking,
                          icon: const Icon(Icons.stop),
                          label: const Text("Stop"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // File Picker Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => pickFile(true),
                          child: const Text("Noise Video"),
                        ),
                        ElevatedButton(
                          onPressed: () => pickFile(false),
                          child: const Text("Speed Video"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Noise Video: $noiseFilePath",
                            style: const TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "Speed Video: $speedFilePath",
                            style: const TextStyle(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String unit,
  ) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          label: "$label: ${value.toInt()} $unit",
          onChanged: onChanged,
          activeColor: Colors.blue,
          inactiveColor: Colors.grey,
        ),
      ],
    );
  }
}