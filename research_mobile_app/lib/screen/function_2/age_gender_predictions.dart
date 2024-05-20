import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:melowave1/core/utils/app_bar.dart';
import 'package:melowave1/core/constants/colors.dart';
import 'package:melowave1/screen/screen.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class SeperateGenderAgePre extends StatefulWidget {
  @override
  _SeperateGenderAgePreState createState() =>
      _SeperateGenderAgePreState();
}

class _SeperateGenderAgePreState extends State<SeperateGenderAgePre> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? imagePath;

  String emotionPredictionResponse = "";
  String? selectedTrackId;
  IconData? emotionIcon;

  // Variables for Profile Predictor
  String? profilePredictorImagePath;
  String agePredictionResponse = "";
  String genderPredictionResponse = "";

  final String emotionalAnalysisText =
      "Sometimes it's the smallest decisions that can change your life forever.";
  XFile? _image;
  String? mlIP = dotenv.env['MLIP']?.isEmpty ?? true
      ? dotenv.env['DEFAULT_IP']
      : dotenv.env['MLIP'];

  @override
  void initState() {
    super.initState();
  }

  Future<void> backcameracaptureImage() async {
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

  // Function to save responses to SharedPreferences
  Future<void> saveResponsesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agePredictionResponse', agePredictionResponse);
    await prefs.setString('genderPredictionResponse', genderPredictionResponse);
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

  // Function to initialize and show camera
  Future<void> initializeAndShowCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
    );

    _initializeControllerFuture = _controller!.initialize();

    // Once the controller is initialized, update the state to show the camera
    _initializeControllerFuture!.then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Function to navigate to Nav screen
  void navigateToNav() {
    // Player(trackId: selectedTrackId ?? '');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Nav(),
      ),
    );
    saveResponsesToPrefs();
  }

  // Widget to build camera preview or button to open camera
  Widget buildCameraWidget() {
    if (_controller != null && _controller!.value.isInitialized) {
      // Camera is initialized, show the preview
      return CameraPreview(_controller!);
    } else {
      // Camera is not initialized, show a button to start the camera
      return Center(
        child: ElevatedButton.icon(
          icon: Icon(Icons.camera_alt),
          label: Text("Open Camera"),
          onPressed: initializeAndShowCamera,
        ),
      );
    }
  }

  // Widget to create custom elevated button
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

  Future<void> analyzeImage(BuildContext context) async {
    // Show loading dialog
    showLoadingDialog(context);

    // First send image to the original model
    await sendImageForAgePrediction(context);
    // Then send image to the new weather model
    await sendImageForGenderPrediction(context);

    // Close the loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    // Show the result dialog with responses from both models
    showCombinedResultDialog(context);
  }

// Updated function to show combined results in a dialog
  void showCombinedResultDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Prediction Results"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Age is : $agePredictionResponse"),
              SizedBox(height: 10),
              Text("Gender is : $genderPredictionResponse"),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Age & Gender Prediction",
        leadingImage: 'assets/Back.png', // Pass the user's photo URL
        actionImage: null,
        onLeadingPressed: () {
          Navigator.of(context).pop();
        },
        onActionPressed: () {
          print("Action icon pressed");
        },
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                emotionalAnalysisText,
                style: Theme.of(context).textTheme.headline6,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_image != null) Image.file(File(_image!.path)),
              _customButton(
                  'Open Camera', Icons.camera_alt, backcameracaptureImage),
              const SizedBox(height: 20),
              _customButton('Pick from Gallery', Icons.photo_library,
                  pickImageFromGallery),
              const SizedBox(height: 20),
              if (profilePredictorImagePath != null)
                Image.file(File(profilePredictorImagePath!)),
              const SizedBox(height: 8),
              _customButton('Analyze Image', Icons.cloud_upload,
                  () => analyzeImage(context)),
              const SizedBox(height: 20),
              Text(
                ('Age is : ${agePredictionResponse}'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueAccent),
              ),
              Text(
                ('Gender is : ${genderPredictionResponse}'),
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
