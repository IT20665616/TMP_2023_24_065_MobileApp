import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:melowave1/core/utils/app_bar.dart';
import 'package:melowave1/core/constants/colors.dart';
import 'package:melowave1/screen/common/nav/nav.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QuestionnaireScreen extends StatefulWidget {
  @override
  _QuestionnaireScreenState createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  late FlutterSoundRecorder _recorder;
  late FlutterTts flutterTts;
  bool _isRecording = false;
  int _currentStep = 0;
  List<String> questions = [
    'How did the playlist make you feel overall?'
  ];
  List<String> userAnswers = ['', '', ''];
  String? mlIP = dotenv.env['MLIP']?.isEmpty ?? true
      ? dotenv.env['DEFAULT_IP']
      : dotenv.env['MLIP'];

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    flutterTts = FlutterTts();
    _initializeRecorder();
    if (questions.isNotEmpty) {
      _speak(questions[0]); // Speak the first question
    }
  }

  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
  }

  Future<void> _speak(String message) async {
    await flutterTts.speak(message);
  }

  void _continue() async {
    if (_currentStep < questions.length - 1) {
      setState(() {
        _currentStep++;
      });
      _speak(questions[_currentStep]); // Speak the current question
    } else {
    }
  }

  void _cancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _speak(questions[_currentStep]); // Speak the current question
    }
  }

  void _startRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    String filePath =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.startRecorder(toFile: filePath);

    setState(() {
      _isRecording = true;
      userAnswers[_currentStep] = filePath;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recording started')),
    );
  }

  void _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() => _isRecording = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recording stopped')),
    );
  }

  List<Step> _buildSteps() {
    return List.generate(questions.length, (index) {
      return Step(
        title: Text('Question ${index + 1}'),
        content: Column(
          children: [
            Text(questions[index]),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onLongPress: _startRecording,
                  onLongPressUp: () => _stopRecording(),
                  child: Icon(_isRecording ? Icons.stop : Icons.mic,
                      size: 50, color: AppColors.colorPrimary),
                ),
                SizedBox(width: 20),
                Text("Or"),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => _pickFile(index),
                  style: ElevatedButton.styleFrom(
                    primary: AppColors.colorPrimary, // Button background color
                    onPrimary: Colors.white, // Text color
                  ),
                  child: Text('Upload Answer'),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (userAnswers[index].isNotEmpty) Text('Answer recorded.'),
          ],
        ),
        isActive: _currentStep >= index,
        state: _currentStep > index ? StepState.complete : StepState.indexed,
      );
    });
  }

  Future<Map<String, dynamic>?> _sendRecordingsToServer() async {
    var uri = Uri.parse('http://$mlIP:8000/predict-emotion-from-audio');
    var request = http.MultipartRequest('POST', uri);

    // Add each audio file to the request
    for (int i = 0; i < userAnswers.length; i++) {
      if (userAnswers[i].isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'audiofile${i + 1}',
          userAnswers[i],
        ));
      }
    }

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        print(jsonResponse);
        return jsonResponse; // Return the JSON response
      } else {
        print('Server Error: ${response.statusCode}');
        showErrorDialog('Server error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error sending files: $e');
      showErrorDialog('Error sending files: $e');
      return null;
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _pickFile(int questionIndex) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        userAnswers[questionIndex] = file.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File selected: ${file.path}')),
      );
    } else {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Questionnaire",
        leadingImage: 'assets/Back.png',
        actionImage: null,
        onLeadingPressed: () {
          Navigator.of(context).pop();
        },
        onActionPressed: () {
        },
      ),
      body: Column(
        children: [
          const CircleAvatar(
            backgroundImage: AssetImage('assets/images/girl.png'),
            radius: 80,
          ),
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.colorPrimary, // Change this to your desired color
              ),
            ),
            child: Stepper(
              steps: _buildSteps(),
              currentStep: _currentStep,
              onStepContinue: _continue,
              onStepCancel: _cancel,
              controlsBuilder: (BuildContext context, ControlsDetails details) {
                return Row(
                  children: <Widget>[
                    if (_currentStep < questions.length - 1)
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          primary:
                              AppColors.colorPrimary, // Button background color
                          onPrimary: Colors.white, // Text color
                        ),
                        child: const Text('Next'),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generatePlaylistAndNavigate,
        child: Icon(Icons.playlist_play),
        tooltip: 'Generate Playlist',
        backgroundColor: AppColors.colorPrimary,
      ),
    );
  }

  Future<void> _generatePlaylistAndNavigate() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    Map<String, dynamic>? playlistData = await _sendRecordingsToServer();
    Navigator.pop(context); // Close the progress indicator dialog
    if (playlistData != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('emotion', playlistData['emotion']);
      await prefs.setString('playlist', json.encode(playlistData['playlist']));
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Nav(),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    flutterTts.stop();
    super.dispose();
  }
}
