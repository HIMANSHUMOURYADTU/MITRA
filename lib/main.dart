import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart'; // Add this
import 'dart:async';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SoundMeterScreen(),
    );
  }
}

class SoundMeterScreen extends StatefulWidget {
  const SoundMeterScreen({super.key});

  @override
  State<SoundMeterScreen> createState() => _SoundMeterScreenState();
}

class _SoundMeterScreenState extends State<SoundMeterScreen> {
  late NoiseMeter noiseMeter;
  StreamSubscription<NoiseReading>? noiseSubscription;
  VideoPlayerController? videoController;

  double orangeFrequency = 500.0;
  double redFrequency = 1000.0;
  double currentFrequency = 0.0;

  String filePath = "No File Selected";
  bool isListening = false;
  bool isVideoPlaying = false;
  DateTime? lastVideoCloseTime;

  String parentMenu = "Parent";
  String childMenu1 = "Child";

  static const int videoDelaySeconds = 3;

  @override
  void initState() {
    super.initState();
    noiseMeter = NoiseMeter();
    _checkPermissions(); // Check permissions on init
  }

  Future<bool> _checkPermissions() async {
    // Check and request microphone permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint("Microphone permission denied");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission is required to measure noise.")),
        );
        return false;
      }
    }
    debugPrint("Microphone permission granted");
    return true;
  }

  void startListening() async {
    if (isListening) return;

    // Ensure permissions are granted before starting
    bool hasPermission = await _checkPermissions();
    if (!hasPermission) return;

    setState(() {
      isListening = true;
      currentFrequency = 0.0;
    });

    try {
      noiseSubscription = NoiseMeter().noise.listen((NoiseReading noiseReading) {
        setState(() {
          currentFrequency = noiseReading.meanDecibel;
          debugPrint("Current frequency: $currentFrequency dB"); // Debug output
          if (currentFrequency >= redFrequency &&
              filePath != "No File Selected" &&
              !isVideoPlaying) {
            if (lastVideoCloseTime == null ||
                DateTime.now().difference(lastVideoCloseTime!).inSeconds >= videoDelaySeconds) {
              showVideoDialog(context);
            }
          }
        });
      }, onError: onError);
    } catch (e) {
      debugPrint("Error starting noise meter: $e");
      setState(() {
        isListening = false;
      });
    }
  }

  void stopListening() {
    noiseSubscription?.cancel();
    setState(() {
      isListening = false;
      currentFrequency = 0.0;
    });
    if (!isVideoPlaying) {
      videoController?.dispose();
      videoController = null;
    }
    debugPrint("Stopped listening");
  }

  Future<void> showVideoDialog(BuildContext context) async {
    if (isVideoPlaying) return;

    videoController?.dispose();
    videoController = VideoPlayerController.file(File(filePath));

    try {
      await videoController!.initialize();
      if (!mounted) return;

      setState(() {
        isVideoPlaying = true;
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          videoController!.play();
          videoController!.setLooping(true);

          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: videoController!.value.aspectRatio,
                    child: VideoPlayer(videoController!),
                  ),
                ],
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
      debugPrint("Video player error: $e");
      setState(() {
        isVideoPlaying = false;
        lastVideoCloseTime = DateTime.now();
      });
      videoController?.dispose();
      videoController = null;
    }
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      setState(() {
        filePath = result.files.single.path ?? "No File Selected";
      });
    }
  }

  void onError(Object error) {
    debugPrint("Noise meter error: $error");
    setState(() {
      isListening = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error with noise meter: $error")),
    );
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  void showEditMenuDialog() {
    TextEditingController parentController = TextEditingController(text: parentMenu);
    TextEditingController childController = TextEditingController(text: childMenu1);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Menu Items"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: parentController,
              decoration: const InputDecoration(labelText: "Parent"),
            ),
            TextField(
              controller: childController,
              decoration: const InputDecoration(labelText: "Child"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                parentMenu = parentController.text;
                childMenu1 = childController.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MITRA")),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text("Menu", style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              title: Text(parentMenu),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: Text(childMenu1),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text("Edit Menu"),
              onTap: () {
                Navigator.pop(context);
                showEditMenuDialog();
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Current Frequency: ${currentFrequency.toStringAsFixed(1)} dB",
              style: TextStyle(
                color: currentFrequency >= redFrequency
                    ? Colors.red
                    : currentFrequency >= orangeFrequency
                        ? Colors.orange
                        : Colors.green,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Orange Level",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: orangeFrequency,
              min: 0,
              max: 20000,
              divisions: 10,
              label: "Orange: ${orangeFrequency.toInt()} Hz",
              onChanged: (value) {
                setState(() {
                  orangeFrequency = value;
                  if (orangeFrequency >= redFrequency) redFrequency = orangeFrequency + 1;
                });
              },
            ),
            const Text(
              "Red Level",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: redFrequency,
              min: 0,
              max: 20000,
              divisions: 10,
              label: "Red: ${redFrequency.toInt()} Hz",
              onChanged: (value) {
                setState(() {
                  redFrequency = value;
                  if (redFrequency <= orangeFrequency) orangeFrequency = redFrequency - 1;
                });
              },
            ),
            ElevatedButton(
              onPressed: startListening,
              child: const Text("Start Listening"),
            ),
            ElevatedButton(
              onPressed: stopListening,
              child: const Text("Stop Listening"),
            ),
            ElevatedButton(
              onPressed: pickFile,
              child: const Text("Select File"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SpeedScreen()),
                );
              },
              child: const Text("Speed"),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                "Selected File: $filePath",
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SpeedScreen (unchanged for brevity, assume it remains as is)
class SpeedScreen extends StatefulWidget {
  const SpeedScreen({super.key});

  @override
  State<SpeedScreen> createState() => _SpeedScreenState();
}

class _SpeedScreenState extends State<SpeedScreen> {
  StreamSubscription<Position>? positionSubscription;
  VideoPlayerController? videoController;

  double orangeSpeed = 5.0;
  double redSpeed = 10.0;
  double currentSpeed = 0.0;

  String filePath = "No File Selected";
  bool isTracking = false;
  bool isVideoPlaying = false;
  DateTime? lastVideoCloseTime;

  static const int videoDelaySeconds = 3;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Location permissions denied");
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint("Location permissions denied forever");
      return;
    }
  }

  void startTracking() async {
    if (isTracking) return;
    await _checkPermissions();
    setState(() {
      isTracking = true;
      currentSpeed = 0.0;
    });

    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position position) {
      setState(() {
        currentSpeed = position.speed;
        if (currentSpeed >= redSpeed &&
            filePath != "No File Selected" &&
            !isVideoPlaying) {
          if (lastVideoCloseTime == null ||
              DateTime.now().difference(lastVideoCloseTime!).inSeconds >= videoDelaySeconds) {
            showVideoDialog(context);
          }
        }
      });
    }, onError: (e) => debugPrint("Speed tracking error: $e"));
  }

  void stopTracking() {
    positionSubscription?.cancel();
    setState(() {
      isTracking = false;
      currentSpeed = 0.0;
    });
    if (!isVideoPlaying) {
      videoController?.dispose();
      videoController = null;
    }
  }

  Future<void> showVideoDialog(BuildContext context) async {
    if (isVideoPlaying) return;

    videoController?.dispose();
    videoController = VideoPlayerController.file(File(filePath));

    try {
      await videoController!.initialize();
      if (!mounted) return;

      setState(() {
        isVideoPlaying = true;
      });

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          videoController!.play();
          videoController!.setLooping(true);

          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: videoController!.value.aspectRatio,
                    child: VideoPlayer(videoController!),
                  ),
                ],
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
      debugPrint("Video player error: $e");
      setState(() {
        isVideoPlaying = false;
        lastVideoCloseTime = DateTime.now();
      });
      videoController?.dispose();
      videoController = null;
    }
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null) {
      setState(() {
        filePath = result.files.single.path ?? "No File Selected";
      });
    }
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Speed Monitor")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Current Speed: ${currentSpeed.toStringAsFixed(1)} m/s",
              style: TextStyle(
                color: currentSpeed >= redSpeed
                    ? Colors.red
                    : currentSpeed >= orangeSpeed
                        ? Colors.orange
                        : Colors.green,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Orange Level",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: orangeSpeed,
              min: 0,
              max: 50,
              divisions: 50,
              label: "Orange: ${orangeSpeed.toInt()} m/s",
              onChanged: (value) {
                setState(() {
                  orangeSpeed = value;
                  if (orangeSpeed >= redSpeed) redSpeed = orangeSpeed + 1;
                });
              },
            ),
            const Text(
              "Red Level",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: redSpeed,
              min: 0,
              max: 50,
              divisions: 50,
              label: "Red: ${redSpeed.toInt()} m/s",
              onChanged: (value) {
                setState(() {
                  redSpeed = value;
                  if (redSpeed <= orangeSpeed) orangeSpeed = redSpeed - 1;
                });
              },
            ),
            ElevatedButton(
              onPressed: startTracking,
              child: const Text("Start Tracking"),
            ),
            ElevatedButton(
              onPressed: stopTracking,
              child: const Text("Stop Tracking"),
            ),
            ElevatedButton(
              onPressed: pickFile,
              child: const Text("Select File"),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Text(
                "Selected File: $filePath",
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}