import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:melowave1/core/utils/app_bar.dart';
import 'package:melowave1/core/constants/colors.dart';
import 'package:melowave1/screen/screen.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

// Main widget for the voice recording and emotion analysis
class SeperateEmotionsPre extends StatefulWidget {
  @override
  _RecommendationHubScreenState createState() =>
      _RecommendationHubScreenState();
}

// State class for the voice recording and emotion analysis widget
class _RecommendationHubScreenState extends State<SeperateEmotionsPre> {
  CameraController? _controller;
  String? imagePath;
  String emotionPredictionResponse = "";
  String? selectedTrackId;
  IconData? emotionIcon;
  late FlutterSoundRecorder _recorder;
  late FlutterSoundPlayer _player;

  int currentStep = 0;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  bool _isRecording = false;
  String? _path;

  // Variables for Recommendation Hub
  String? recommendationHubImagePath;
  String recommendationHubResponse = "";

  // Variables for Profile Predictor
  String? profilePredictorImagePath;
  String profilePredictorResponse = "";

  final String emotionalAnalysisText =
      "Let’s capture your current mood. Please read the following text aloud for emotional mood analysis:";
  final String emotionalAnalysisText2 =
      "Sometimes it's the smallest decisions that can change your life forever.";
  String? mlIP = dotenv.env['MLIP']?.isEmpty ?? true
      ? dotenv.env['DEFAULT_IP']
      : dotenv.env['MLIP'];

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _initializeRecorder();
    _initializePlayer();
  }

  // Initialize the voice recorder
  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    setState(() => _isRecorderInitialized = true);
  }

  // Initialize the audio player
  Future<void> _initializePlayer() async {
    await _player.openPlayer();
    setState(() => _isPlayerInitialized = true);
  }

  // Save emotion prediction response to SharedPreferences
  Future<void> saveResponsesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'emotionPredictionResponse', emotionPredictionResponse);
  }

  // Send recorded audio for emotion prediction to the server
  Future<void> sendAudioForEmotionPrediction(BuildContext context) async {
    if (_path == null) {
      print('No Audio selected');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('No Audio selected.'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    final String serverUrl =
        'http://$mlIP:8000/emotion-prediction'; // Update to your endpoint

    try {
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath('file', _path!));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          emotionPredictionResponse = response.body; // Store the response
        });
      } else {
        // Handle API Error
        setState(() {
          emotionPredictionResponse =
              'Error in emotion prediction: ${response.statusCode}';
        });
        print('API Error: ${response.statusCode}');
        print('Error details: ${response.body}');
      }
    } catch (e) {
      // Handle Request Error
      setState(() {
        emotionPredictionResponse =
            'Error sending emotion prediction request: $e';
      });
    }
  }

  // Function to show result in a dialog
  void showResultDialog(BuildContext context, String result) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Prediction Result"),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  // Navigate to the next screen and save responses to SharedPreferences
  void navigateToNav() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Nav(),
      ),
    );
    saveResponsesToPrefs();
  }

  // Start recording audio
  void _startRecording() async {
    if (!_isRecorderInitialized || _isRecording) return;

    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/flutter_sound_record_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.pcm16WAV, // Use WAV codec
    );
    setState(() {
      _path = filePath;
      _isRecording = true;
    });
  }

  // Stop recording audio
  void _stopRecording() async {
    if (!_isRecorderInitialized || !_isRecording) return;

    await _recorder.stopRecorder();
    setState(() => _isRecording = false);
  }

  // Play the recorded audio
  void _playRecording() async {
    if (!_isRecording &&
        _path != null &&
        _isPlayerInitialized &&
        !_player.isPlaying) {
      try {
        // Check if the file exists
        var file = File(_path!);
        if (await file.exists()) {
          await _player.startPlayer(
            fromURI: _path,
            codec: Codec.pcm16WAV, // Ensure the player uses the WAV codec
          );
        } else {
          print('Recording file does not exist: $_path');
        }
      } catch (e) {
        // Handle the error
        print('Error starting player: $e');
      }
    }
  }

  // Custom button widget
  Widget _customButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(text),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        primary: AppColors.colorPrimary,
        onPrimary: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }

  Future<void> pickAudioFromFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        // Assuming you have a variable to hold the path of the picked audio
        _path = file.path; // Update your state or variable accordingly
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Voice Tunes",
        leadingImage: 'assets/Back.png', // Pass the user's photo URL
        actionImage: null,
        onLeadingPressed: () {
          Navigator.of(context).pop();
        },
        onActionPressed: () {
          print("Action icon pressed");
        },
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.colorPrimary,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                emotionalAnalysisText,
                style: Theme.of(context).textTheme.headline6,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                emotionalAnalysisText2,
                style: Theme.of(context).textTheme.headline6,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              GestureDetector(
                onLongPress: _startRecording,
                onLongPressUp: _stopRecording,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.colorPrimary,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRecording ? 'Release to Stop' : 'Hold to Record',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _customButton('Play Recording', Icons.play_arrow, _playRecording),
              const SizedBox(height: 20),
              _customButton(
                  'Pick Audio File', Icons.audiotrack, pickAudioFromFile),
              const SizedBox(height: 20),
              _customButton('Analyze Voice', Icons.cloud_upload,
                  () => sendAudioForEmotionPrediction(context)),
              const SizedBox(height: 20),
              Text(
                ('Voice Emotion: ${emotionPredictionResponse}'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueAccent),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: navigateToNav,
        child: Icon(Icons.playlist_play),
        backgroundColor: AppColors.colorPrimary,
      ),
    );
  }
}
