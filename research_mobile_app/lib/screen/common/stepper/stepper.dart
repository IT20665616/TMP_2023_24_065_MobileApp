import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:melowave1/core/constants/colors.dart';
import 'package:melowave1/screen/screen.dart';
import 'package:camera/camera.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

// Defining a StatefulWidget for the StepperScreen
class StepperScreen extends StatefulWidget {
  const StepperScreen({super.key});

  @override
  State<StepperScreen> createState() => _HomeScreenState();
}

// The state class for the StepperScreen widget
class _HomeScreenState extends State<StepperScreen> {
  // Declaring necessary variables
  int currentStep = 0;
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  late FlutterSoundRecorder _recorder;
  late FlutterSoundPlayer _player;
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  bool _isRecording = false;
  String? _path;
  String? imagePath;

  String? selectedTrackId;

  // Variables for Recommendation Hub
  String? recommendationHubImagePath;
  String recommendationHubResponse = "";
  String emotionPredictionResponse = "";
  String agePredictionResponse = "";
  String genderPredictionResponse = "";
  String weatherPredictionResponse = "";

  // Variables for Profile Predictor
  String? profilePredictorImagePath;
  String profilePredictorResponse = "";
  String profileAgeResponse = "";
  String profileGenderResponse = "";

  final String emotionalAnalysisText =
      "Sometimes it's the smallest decisions that can change your life forever.";
  String? mlIP = dotenv.env['MLIP']?.isEmpty ?? true
      ? dotenv.env['DEFAULT_IP']
      : dotenv.env['MLIP'];

  // initState method for initializing state variables
  @override
  void initState() {
    super.initState();
    initializeCamera(); // Initialize with back camera by default

    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _initializeRecorder();
    _initializePlayer();
  }

  // Method to initialize the audio recorder
  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    setState(() => _isRecorderInitialized = true);
  }

  // Method to initialize the audio player
  Future<void> _initializePlayer() async {
    await _player.openPlayer();
    setState(() => _isPlayerInitialized = true);
  }

  // Function to capture image from the back camera
  Future<void> backcameracaptureImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      // Process the image to standardize it for the model.
      String processedImagePath = await prepareImageForModel(photo.path);
      setState(() {
        recommendationHubImagePath = processedImagePath;
        print("Image captured and processed: $recommendationHubImagePath");
      });
    }
  }

  Future<String> prepareImageForModel(String imagePath) async {
    File imageFile = File(imagePath);

    // Read a jpeg image from file.
    img.Image image = img.decodeImage(imageFile.readAsBytesSync())!;

    // Correct orientation based on EXIF data.
    img.bakeOrientation(image);

    // Resize the image to a specific size (e.g., 224x224 for typical ML models).
    img.Image resized = img.copyResize(image, width: 800, height: 800);

    // Save or overwrite the image file.
    File processedFile = await imageFile.writeAsBytes(img.encodeJpg(resized));

    return processedFile.path;
  }

  // Function to capture image from the front camera
  Future<void> selficameracaptureImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      // Process the image to standardize it for the model.
      String processedImagePath = await prepareImageForModel(photo.path);
      setState(() {
        profilePredictorImagePath = processedImagePath;
        print("Image captured and processed: $profilePredictorImagePath");
      });
    }
  }

  // Method to save responses to SharedPreferences
  Future<void> saveResponsesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'recommendationHubResponse', recommendationHubResponse);
    await prefs.setString(
        'emotionPredictionResponse', emotionPredictionResponse);
    await prefs.setString('agePredictionResponse', agePredictionResponse);
    await prefs.setString('genderPredictionResponse', genderPredictionResponse);
    await prefs.setString(
        'weatherPredictionResponse', weatherPredictionResponse);
  }

  // Method to send captured image to model for prediction
  Future<void> sendImageToModel(BuildContext context) async {
    if (recommendationHubImagePath == null) {
      print('No image selected');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('No image selected.'),
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
        'http://$mlIP:8000/weather-predict'; // Update this URL

    try {
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath(
          'file', recommendationHubImagePath!));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          recommendationHubResponse = response.body; // Store the response
        });

        if (responseData.containsKey('predicted_class')) {
          final result = responseData['predicted_class'];
          // print('API Response: $result');
          showResultDialog(context, '$result');
        } else {
          print('Invalid API Response Format');
        }
      } else {
        print('API Error: ${response.statusCode}');
        print('Error details: ${response.body}');
      }
    } catch (e) {
      print('Error sending request: $e');
    }
  }

// Method to send captured image to "analyze-attire" model for prediction
  Future<void> sendImageToAttireModel(BuildContext context) async {
    if (recommendationHubImagePath == null) {
      print('No image selected');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('No image selected.'),
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

    final String serverUrl = 'http://$mlIP:8001/prediction'; // New endpoint

    try {

      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath(
          'file', recommendationHubImagePath!));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          weatherPredictionResponse = responseData['indoor_outdoor']; // Store the response
          if(weatherPredictionResponse == "indoor"){
            weatherPredictionResponse = "Indoor";
          }
          else {
            weatherPredictionResponse = "Outdoor";
          }
        });

        if (responseData.containsKey('predicted_class')) {
          final result = responseData['predicted_class'];
          // print('API Response: $result');
          showResultDialog(context, '$result');
        } else {
          print('Invalid API Response Format');
        }
        // Save the response to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'weatherPredictionResponse', weatherPredictionResponse);
        // showResultDialog(context, weatherPredictionResponse); // Show result in dialog
      } else {
        print('API Error: ${response.statusCode}');
        print('Error details: ${response.body}');
      }
    } catch (e) {
      print('Error sending request: $e');
    }
  }

  // Method to send captured image for age prediction
  Future<String> sendImageForAgePrediction(BuildContext context) async {
    if (profilePredictorImagePath == null) {
      print('No image selected');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('No image selected.'),
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
      return 'No image selected for age prediction';
    }

    final String serverUrl =
        'http://$mlIP:8000/age-predict'; // Update to your endpoint

    try {
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath(
          'file', profilePredictorImagePath!));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          agePredictionResponse = response.body; // Store the response
          profilePredictorResponse = response.body; // Store the response
        });
        return response.body; // Return the response
      } else {
        // Handle API Error
        print('API Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        return 'Error in age prediction: ${response.statusCode}';
      }
    } catch (e) {
      // Handle Request Error
      print('Error sending request: $e');
      return 'Error sending age prediction request: $e';
    }
  }

  // Method to send captured image for gender prediction
  Future<String> sendImageForGenderPrediction(BuildContext context) async {
    if (profilePredictorImagePath == null) {
      // Handle error: No image selected
      return 'No image selected for gender prediction';
    }

    final String serverUrl =
        'http://$mlIP:8000/gender-predict'; // Update to your endpoint

    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://$mlIP:8000/gender-predict'));
      request.files.add(await http.MultipartFile.fromPath(
          'file', profilePredictorImagePath!));
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() {
          genderPredictionResponse = response.body; // Store the response
        });
        return response.body; // Return the response
      } else {
        // Handle API Error
        print('API Error: ${response.statusCode}');
        print('Error details: ${response.body}');
        return 'Error in age prediction: ${response.statusCode}';
      }
    } catch (e) {
      // Handle Request Error
      print('Error sending request: $e');
      return 'Error sending age prediction request: $e';
    }
  }

  // Method to send recorded audio for emotion prediction
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
        print('API Error: ${response.statusCode}');
        print('Error details: ${response.body}');
      }
    } catch (e) {
      print('Error sending request: $e');
    }
  }

  // Method to show a dialog with the prediction result
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

  // Method to start recording audio
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

  // Method to stop recording audio
  void _stopRecording() async {
    if (!_isRecorderInitialized || !_isRecording) return;

    await _recorder.stopRecorder();
    setState(() => _isRecording = false);
  }

  // Method to play recorded audio
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

  // Method to initialize the camera
  Future<void> initializeCamera({bool useFrontCamera = false}) async {
    final cameras = await availableCameras();

    final desiredLensDirection =
        useFrontCamera ? CameraLensDirection.front : CameraLensDirection.back;

    if (_controller != null &&
        _controller!.value.isInitialized &&
        _controller!.description.lensDirection == desiredLensDirection) {
      return; // Camera is already initialized with the correct type, no need to reinitialize
    }

    final selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == desiredLensDirection,
      orElse: () => cameras.first, // Fallback to the first available camera
    );
    await _controller?.dispose();

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
    );

    _initializeControllerFuture = _controller!.initialize();
  }

  // Dispose method to release resources
  @override
  void dispose() {
    _controller?.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  // Method to proceed to the next step
  continueStep() async {
    if (currentStep < 4) {
      if (currentStep == 0) {
        await initializeCamera(useFrontCamera: false);
      } else if (currentStep == 1) {
        await initializeCamera(useFrontCamera: true);
      }
      setState(() {
        currentStep++;
      });
    }
  }

  // Method to go back to the previous step
  cancelStep() async {
    if (currentStep > 0) {
      if (currentStep == 2) {
        await initializeCamera(useFrontCamera: false);
      } else if (currentStep == 3) {
        await initializeCamera(useFrontCamera: true);
      }
      setState(() {
        currentStep--;
      });
    }
  }

  // Method to handle step tap
  onStepTapped(int value) {
    setState(() {
      currentStep = value;
    });
  }

  // Method to navigate to the next screen
  void navigateToNav() {
    saveResponsesToPrefs();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Nav(),
      ),
    );
  }

  // Method to build the camera widget
  Widget buildCameraWidget() {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CameraPreview(_controller!);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  // Method to build control buttons for the steps
  Widget controlBuilders(BuildContext context, ControlsDetails details) {
    if (currentStep == 0) {
      // For steps 0 to 2
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ElevatedButton(
              onPressed: details.onStepContinue,
              child: const Text('Accept'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: navigateToNav,
              child: const Text('Home'),
              style: OutlinedButton.styleFrom(
                primary:
                    AppColors.colorPrimary, // Replace with your desired color
                // You can also add more styling attributes if needed
              ),
            ),
          ],
        ),
      );
    } else if (currentStep < 4) {
      // For the final step
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ElevatedButton(
              onPressed: details.onStepContinue,
              child: const Text('Next'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: details.onStepCancel,
              child: const Text('Back'),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ElevatedButton(
              onPressed: navigateToNav,
              child: const Text('Generate Playlist'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: details.onStepCancel,
              child: const Text('Back'),
            ),
          ],
        ),
      );
    }
  }

// Function to pick image from the gallery
  Future<void> pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      // Process the image to standardize it for the model.
      String processedImagePath = await prepareImageForModel(photo.path);
      setState(() {
        profilePredictorImagePath = processedImagePath;
        print("Image selected and processed: $profilePredictorImagePath");
      });
    }
  }

  Future<void> pickImageFromGalleryForRecommendationHub() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      // Process the image to standardize it for the model.
      String processedImagePath = await prepareImageForModel(photo.path);
      setState(() {
        recommendationHubImagePath = processedImagePath;
        print("Image selected and processed: $recommendationHubImagePath");
      });
    }
  }

  Future<void> pickAudioFromStorage() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      final file = result.files.first;
      setState(() {
        _path = file
            .path; // Assuming _path is used for storing the selected audio file path
      });
    }
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevents the dialog from closing on tap outside
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Analyzing... Please wait"),
              ],
            ),
          ),
        );
      },
    );
  }

// Function to handle combined model requests
  Future<void> analyzeImage(BuildContext context) async {
    showLoadingDialog(context);
    try {
      // First send image to the original model
      await sendImageToModel(context);
      // Then send image to the new weather model
      await sendImageToAttireModel(context);
    } catch (e) {
      print("An error occurred during image analysis: $e");
    } finally {
      // Ensures that the dialog is always closed, regardless of whether an error occurred
      Navigator.of(context, rootNavigator: true).pop();

      // showCombinedResultDialog(context);
    }
  }

// Updated function to show combined results in a dialog
  // void showCombinedResultDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: Text("Prediction Results"),
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text("Current Weather: $recommendationHubResponse"),
  //             SizedBox(height: 10),
  //             Text("Current Surrounding Type: $weatherPredictionResponse"),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               Navigator.of(context, rootNavigator: true).pop();
  //             },
  //             child: Text("OK"),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

// **************************************************** //

  // Build method to create the stepper UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.colorPrimary,
        ),
      ),
      child: Stepper(
        elevation: 0, //Horizontal Impact
        // margin: const EdgeInsets.all(20), //vertical impact
        controlsBuilder: controlBuilders,
        type: StepperType.vertical,
        physics: const ScrollPhysics(),
        onStepTapped: onStepTapped,
        onStepContinue: continueStep,
        onStepCancel: cancelStep,
        currentStep: currentStep, //0, 1, 2
        steps: [
          Step(
            title: const Text('Terms and Conditions'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Please read these terms and conditions carefully before using MeloWave:'),
                  const SizedBox(height: 10),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black, fontSize: 13),
                      children: [
                        TextSpan(text: '1. '),
                        TextSpan(
                            text: 'Device Access: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                            text:
                                'By using MeloWave, you consent to the use of your device’s camera and microphone for mood tracking and functionality purposes.\n'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black, fontSize: 13),
                      children: [
                        TextSpan(text: '2. '),
                        TextSpan(
                            text: 'Data Use: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                            text:
                                'You agree to our data use and privacy practices, including the collection, processing, and sharing of your data as described in our Privacy Policy.\n'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Add more points as needed
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.black, fontSize: 13),
                      children: [
                        TextSpan(text: '3. '),
                        TextSpan(
                            text: 'Content Policy: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                            text:
                                'You agree to abide by our content guidelines and not to upload harmful or illegal content.\n'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ... More terms and conditions ...
                ],
              ),
            ),
            isActive: currentStep >= 0,
            state: currentStep >= 0 ? StepState.complete : StepState.disabled,
          ),
          Step(
            title: const Text('User Surroundings Predictor'),
            content: Column(
              children: [
                const Text('Capture your current surrounding for the prediction'),
                const SizedBox(height: 8),
                if (currentStep == 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.camera_alt_rounded,
                            size: 40, color: Colors.blue),
                        onPressed: backcameracaptureImage,
                      ),
                      IconButton(
                        icon: Icon(Icons.photo_library,
                            size: 40, color: Colors.purple),
                        onPressed: pickImageFromGalleryForRecommendationHub,
                      ),
                    ],
                  ),
                if (recommendationHubImagePath != null)
                  Image.file(File(recommendationHubImagePath!)),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(Icons.check_circle, size: 40, color: Colors.green),
                  onPressed: () => analyzeImage(context),
                ),
                const SizedBox(height: 20),
                Text(
                  ('Current Weather: ${recommendationHubResponse}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueAccent),
                ),
                Text(
                  ('Current Surrounting Type: "${weatherPredictionResponse}"'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),
              ],
            ),
            isActive: currentStep >= 1,
            state: currentStep >= 1 ? StepState.complete : StepState.disabled,
          ),
          Step(
            title: const Text('Profile Predictor'),
            content: Column(
              children: [
                const Text('All you have is to capture a selfie...'),
                const SizedBox(height: 8),
                if (currentStep == 2)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(Icons.camera_alt_rounded,
                            size: 40, color: Colors.blue),
                        onPressed: selficameracaptureImage,
                      ),
                      IconButton(
                        icon: Icon(Icons.photo_library,
                            size: 40, color: Colors.purple),
                        onPressed: pickImageFromGallery,
                      ),
                    ],
                  ),
                if (profilePredictorImagePath != null)
                  Image.file(File(profilePredictorImagePath!)),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(Icons.check_circle, size: 40, color: Colors.green),
                  onPressed: () async {
                    String ageResult = await sendImageForAgePrediction(context);
                    String genderResult =
                        await sendImageForGenderPrediction(context);

                    setState(() {
                      profileAgeResponse = '$ageResult';
                      profileGenderResponse = '$genderResult';
                    });
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  ('Predicted Age: ${profileAgeResponse}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueAccent),
                ),
                Text(
                  ('Predicted Gender: ${profileGenderResponse}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),
              ],
            ),
            isActive: currentStep >= 2,
            state: currentStep >= 2 ? StepState.complete : StepState.disabled,
          ),
          Step(
            title: const Text('EmoVoice Analyzer'),
            content: Column(
              children: [
                const Text(
                    'Let’s capture your current mood. Please read the following text aloud for emotional mood analysis:'),
                const SizedBox(height: 8),
                Text(emotionalAnalysisText,
                    style: TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 20),
                IconButton(
                  icon: Icon(Icons.folder_open,
                      size: 40, color: Colors.orange), // Pick Audio File
                  onPressed: pickAudioFromStorage,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onLongPress: _startRecording,
                  onLongPressUp: _stopRecording,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.colorPrimary,
                      borderRadius: BorderRadius.circular(8),
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
                IconButton(
                  icon: Icon(Icons.play_arrow,
                      size: 40, color: Colors.blue), // Play Recording
                  onPressed: _playRecording,
                ),
                IconButton(
                  icon: Icon(Icons.check_circle,
                      size: 40, color: Colors.green), // Analyze Emotion
                  onPressed: () => sendAudioForEmotionPrediction(context),
                ),
                const SizedBox(height: 20),
                Text(
                  ('Voice Emotion: ${emotionPredictionResponse}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),
              ],
            ),
            isActive: currentStep >= 3,
            state: currentStep >= 3 ? StepState.complete : StepState.disabled,
          ),
          Step(
            title: const Text('Complete'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(Icons.check_circle_outline,
                              color: Colors.green),
                          title: Text('Recommendation Hub Response'),
                          subtitle: Text(recommendationHubResponse),
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.cloud, color: Colors.blue),
                          title: Text('Weather Prediction Hub Response'),
                          subtitle: Text(weatherPredictionResponse),
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.face, color: Colors.orange),
                          title: Text('Profile Predictor Response'),
                          subtitle: Text(profilePredictorResponse),
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.record_voice_over,
                              color: AppColors.colorPrimary),
                          title: Text('EmoVoice Analyzer Response'),
                          subtitle: Text(emotionPredictionResponse),
                        ),
                        // Add more responses here if you have any
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Add more interactive elements if needed
              ],
            ),
            isActive: currentStep >= 4,
            state: currentStep >= 4 ? StepState.complete : StepState.disabled,
          )
        ],
      ),
    ));
  }
}
