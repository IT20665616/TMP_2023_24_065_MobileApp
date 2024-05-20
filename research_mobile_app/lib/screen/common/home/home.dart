import 'dart:io';

// Import necessary Dart and Flutter packages
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:melowave1/core/utils/app_bar.dart';
import 'package:melowave1/core/constants/colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:melowave1/core/services/sign_in_provider.dart';
import 'package:melowave1/screen/function_2/age_gender_predictions.dart';
import 'package:melowave1/screen/function_4/post_questionnaire/post_questionnaire.dart';
import 'package:melowave1/screen/function_3/emotions_predictions.dart';
import 'package:melowave1/screen/common/stepper/stepper.dart';
import 'package:melowave1/screen/function_1/weather_predictions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import '../../../shared/widgets/player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';

// Class representing the main home screen
class Home extends StatefulWidget {
  static String routeName = '/home';
  final String emotionPredictionResponse;
  final String recommendationHubResponse;
  final String agePredictionResponse;
  final String genderPredictionResponse;
  final String weatherPredictionResponse;

  // Constructor for the Home class
  const Home({
    Key? key,
    required this.emotionPredictionResponse,
    required this.recommendationHubResponse,
    required this.agePredictionResponse,
    required this.genderPredictionResponse,
    required this.weatherPredictionResponse,
  }) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

// State class associated with the Home widget
class _HomeState extends State<Home> {
  // Variables to store selected track and playlist status
  String? selectedTrackId;
  bool _isGeneratingPlaylist = false;
  List<dynamic> _songs = [];
  AudioPlayer audioPlayer = AudioPlayer();
  int _currentPlayingIndex = 0;
  FlutterTts flutterTts = FlutterTts();
  final FlutterSoundRecorder _myRecorder = FlutterSoundRecorder();
  int currentQuestionIndex = 0;
  final List<String> questions = [
    'How did the playlist make you feel overall?',
    'Did the playlist match the mood or atmosphere you were looking for when you started listening?',
    'Did the playlist evoke any specific imagery or scenarios in your mind?'
  ];
  List<String> userAnswers = [
    '',
    '',
    ''
  ]; // This will store the paths of the selected files
  String _emotion = '';
  bool _isLoading = false;
  String? mlIP = dotenv.env['MLIP']?.isEmpty ?? true
      ? dotenv.env['DEFAULT_IP']
      : dotenv.env['MLIP'];

  // Initialize state when the widget is created
  @override
  void initState() {
    super.initState();
    _initTts();
    _initRecorder();
    _showSpotifyInstallDialogIfNeeded();
    _loadData();
    flutterTts = FlutterTts();
    _checkEmotionAndShowPopup();
    // Print the responses to the console
    print("Emotion Prediction Response: ${widget.emotionPredictionResponse}");
    print("Recommendation Hub Response: ${widget.recommendationHubResponse}");
    print("AgePredictionResponse Response: ${widget.agePredictionResponse}");
    print(
        "GenderPredictionResponse Response: ${widget.genderPredictionResponse}");
    print("WeatherPrediction Response: ${widget.weatherPredictionResponse}");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print(
          "Playlist data: ${_songs.map((song) => song.toString()).join(', ')}");
    });
  }

  void _checkEmotionAndShowPopup() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? emotion = prefs.getString('emotion');

    // if (emotion != null && emotion.isNotEmpty) {
    //   _showEmotionPopup(emotion);
    // }
  }

  // Function to request storage permissions
  Future<bool> requestPermissions() async {
    var status = await Permission.storage.request();
    return status.isGranted;
  }

  // Function to request storage permissions and print status
  Future<void> requestStoragePermission() async {
    var status = await Permission.storage.request();

    if (status.isGranted) {
      print("Storage permission granted.");
      // Proceed with your storage-related task
    } else {
      print("Storage permission not granted.");
    }
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? emotion = prefs.getString('emotion');
    String? playlistStr = prefs.getString('playlist');

    print("Emotion from SharedPreferences: $emotion");
    print("Playlist from SharedPreferences: $playlistStr");

    if (emotion != null && playlistStr != null && playlistStr.isNotEmpty) {
      // Both emotion and playlistStr are not null and playlistStr is not empty
      Map<String, dynamic> playlistMap = json.decode(playlistStr);
      List<dynamic> playlist = playlistMap.entries.map((entry) {
        return {'title': entry.key, 'id': entry.value};
      }).toList();
      print("Converted playlist: $playlist");
      setState(() {
        _songs = playlist;
      });
    } else {
      // One or both of emotion and playlistStr are null, or playlistStr is empty
      if (widget.emotionPredictionResponse.isNotEmpty ||
          widget.recommendationHubResponse.isNotEmpty ||
          widget.agePredictionResponse.isNotEmpty ||
          widget.genderPredictionResponse.isNotEmpty) {
        fetchSongList(
            widget.emotionPredictionResponse,
            widget.recommendationHubResponse,
            widget.agePredictionResponse,
            widget.genderPredictionResponse,
            widget.weatherPredictionResponse);
      }
    }
  }

  // Function to initialize the recorder
  Future<void> _initRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _myRecorder.openRecorder();
  }

  // Function to start recording audio
  Future<void> _startRecording() async {
    if (!await requestPermissions()) {
      print('Storage permission not granted');
      requestStoragePermission();
      return;
    }

    // Get the external storage directory and create a custom directory
    final externalDir = await getExternalStorageDirectory();
    final customDirPath = '${externalDir?.path}/MelowaveRecord';
    final customDir = Directory(customDirPath);

    // Create the directory if it doesn't exist
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }

    // Generate a unique filename based on the current timestamp
    String fileName = 'response_${DateTime.now().millisecondsSinceEpoch}.wav';
    String fullPath = '$customDirPath/$fileName';

    print("Starting recording: $fullPath"); // Log the full path

    // Start recording to the specified file path
    await _myRecorder.startRecorder(toFile: fullPath);
  }

  // Function to stop recording audio
  Future<void> _stopRecording() async {
    final path = await _myRecorder.stopRecorder();

    if (path == null) {
      print("Recording error: File path not found.");
    } else {
      if (File(path).existsSync()) {
        print("Recording saved to: $path");
        setState(() {
          userAnswers[currentQuestionIndex] = path;
        });
      } else {
        print("File does not exist: $path");
      }
    }
  }

  // Function to initialize text-to-speech (TTS)
  void _initTts() async {
    // Initialize TTS
    await flutterTts.setLanguage("en-US");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.5);
  }

  // Function to speak a message using TTS
  Future _speak(String message) async {
    await flutterTts.speak(message);
  }

  // Callback for handling track change in the playlist
  void onTrackChange(int newIndex) {
    setState(() {
      _currentPlayingIndex = newIndex;
      selectedTrackId = _songs[newIndex]['id'];
    });
  }

  // Callback for handling track tap in the playlist
  void onTrackTap(int index) {
    setState(() {
      _currentPlayingIndex = index;
      selectedTrackId = _songs[index]['id'];
    });
  }

  // Function to show a dialog prompting to install Spotify if not installed
  void _showSpotifyInstallDialogIfNeeded() async {
    if (await canLaunchUrl(Uri.parse("spotify://"))) {
      // Spotify app is installed
    } else {
      // Spotify app is not installed, show dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Install Spotify'),
            content: Text('This app requires Spotify to be installed.'),
            actions: <Widget>[
              TextButton(
                child: Text('Install'),
                onPressed: () {
                  _launchURL();
                },
              ),
            ],
          );
        },
      );
    }
  }

  // Function to launch the Spotify installation URL
  void _launchURL() async {
    const urlAndroid =
        'https://play.google.com/store/apps/details?id=com.spotify.music';
    const urlIOS = 'https://apps.apple.com/app/spotify-music/id324684580';
    String url =
        Theme.of(context).platform == TargetPlatform.iOS ? urlIOS : urlAndroid;

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      // Cannot launch the URL
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch the app store')),
      );
    }
  }

  // Function to fetch the song list based on emotion and weather
  void fetchSongList(String emotion, String recommend, String age,
      String gender, String attire) async {
    setState(() {
      _isGeneratingPlaylist = true; // Start loading
    });
    String cleanedEmotion = emotion.replaceAll('"', '');
    String cleanedRecommendation = recommend.replaceAll('"', '');
    String cleanedage = age.replaceAll('"', '');
    String cleanedgender = gender.replaceAll('"', '');
    String cleanedweatherPredictionResponse = attire.replaceAll('"', '');

    var url = Uri.parse(
        'http://$mlIP:8000/songlist?emotion=$cleanedEmotion&weather=$cleanedRecommendation&age_group=$cleanedage&gender=$cleanedgender&indoor_outdoor=$cleanedweatherPredictionResponse');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      List<dynamic> newSongs = [];
      data.forEach((songName, songId) {
        newSongs.add({
          'title': songName, // Song name
          'id': songId // Spotify song ID
        });
      });

      setState(() {
        _songs = newSongs; // Update the _songs list
      });
    } else {
      print('Failed to fetch song list');
    }
    setState(() {
      _isGeneratingPlaylist = false; // Stop loading once done
    });
  }

  // Function to handle the navigation to the stepper screen
  void navigateToStepper(int step) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StepperScreen(),
      ),
    );
  }

  // Build the main content of the home screen
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      backgroundColor: AppColors.homebg,
      appBar: CustomAppBar(
        title: "MeloWave",
        leadingImage: user.photoURL ?? '',
        actionImage: null,
        onLeadingPressed: () {
          print("Leading icon pressed");
        },
        onActionPressed: () {
          print("Action icon pressed");
        },
      ),
      body: _isLoading || _isGeneratingPlaylist
          ? Center(child: CircularProgressIndicator())
          : _buildMainContent(context),
      //  bottomNavigationBar: HomeState.buildBottomBar(context),

      floatingActionButton: Stack(
        alignment: Alignment.bottomRight,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(
                bottom: 80.0), // Adjust the position for the first button
            child: FloatingActionButton(
              onPressed: () {
                if (!_isGeneratingPlaylist) {
                  fetchSongList(
                      widget.emotionPredictionResponse,
                      widget.recommendationHubResponse,
                      widget.agePredictionResponse,
                      widget.genderPredictionResponse,
                      widget.weatherPredictionResponse);
                }
              },
              child: Icon(FontAwesomeIcons
                  .arrowsRotate), // Customize with your own icon for the first button
              tooltip: 'Add',
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
                bottom: 10.0), // Adjust the position for the second button
            child: FloatingActionButton(
              onPressed: () {
                _lisBot(); // The original button's action
              },
              child: Image.asset(
                  'assets/images/girl.png'), // The original button's icon
              tooltip:
                  'Lisa MeloWave Assistant', // The original button's tooltip
            ),
          ),
        ],
      ),
    );
  }

  // Build the main content of the home screen
  Widget _buildMainContent(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Changed to center
          children: [
            Text(
              "Sentiment Analysis Tools",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10.h),
            _buildIconGrid(context),
            if (selectedTrackId != null) ...[
              SizedBox(height: 20.h),
              _buildPlayer(),
            ],
            SizedBox(height: 20.h),
            _buildRecommendedMusicSection(),
          ],
        ),
      ),
    );
  }

  // Build the icon grid for quick actions
  Widget _buildIconGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: [
        _iconCard(FontAwesomeIcons.cameraRetro, 'Weather', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SeperateWeatherPre()),
          );
        }),
        _iconCard(FontAwesomeIcons.solidFaceLaughBeam, 'Voice', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SeperateEmotionsPre()),
          );
        }),
        _iconCard(FontAwesomeIcons.person, 'Profile', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SeperateGenderAgePre()),
          );
        }),
        _iconCard(FontAwesomeIcons.checkDouble, '360 Mix', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => StepperScreen()),
          );
        }),
      ],
    );
  }

  // Build the player widget for controlling the playlist
  Widget _buildPlayer() {
    return Player(
      trackId: selectedTrackId!,
      playlist: _songs,
      currentIndex: _currentPlayingIndex,
      onTrackChange: (int newIndex) {
        setState(() {
          _currentPlayingIndex = newIndex;
          selectedTrackId = _songs[newIndex]['id'];
        });
      },
      onPlaylistEnd: () {
        print("Playlist has ended.");
        // Handle the end of playlist, e.g., by resetting the player or loading a new playlist
      },
    );
  }

  // Build the section displaying recommended music
  Widget _buildRecommendedMusicSection() {
    // Firestore instance
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser!;

    // Toggle favorite status of a track
    void _toggleFavorite(String trackId, String trackTitle) async {
      DocumentReference favoritesRef =
          firestore.doc('users/${user.uid}/favorite/$trackId');
      DocumentSnapshot snapshot = await favoritesRef.get();
      if (snapshot.exists) {
        await favoritesRef.delete();
      } else {
        await favoritesRef.set({'title': trackTitle, 'id': trackId});
      }
    }

    return Column(
      children: [
        Text(
          "Recommended Music Playlist",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 20.h),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _songs.length,
          itemBuilder: (context, index) {
            var song = _songs[index];
            return StreamBuilder<DocumentSnapshot>(
              stream: firestore
                  .doc('users/${user.uid}/favorite/${song['id']}')
                  .snapshots(),
              builder: (context, snapshot) {
                bool isFavorite = snapshot.data?.exists ?? false;
                return Card(
                  elevation: 4,
                  child: ListTile(
                    leading:
                        Icon(Icons.music_note, color: AppColors.colorPrimary),
                    title: Text(song['title']),
                    subtitle: Text('${song['id']}'),
                    onTap: () => onTrackTap(index),
                    trailing: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color:
                            isFavorite ? AppColors.colorPrimary : Colors.grey,
                      ),
                      onPressed: () =>
                          _toggleFavorite(song['id'], song['title']),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // Custom card for icon buttons
  Widget _iconCard(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: AppColors.colorPrimary),
            SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // Pick an audio file for a specific index in the questionnaire
  Future<void> pickAudioFile(int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );

    if (result != null) {
      String? path = result.files.single.path;
      if (path != null) {
        setState(() {
          userAnswers[index] = path;
        });
      }
    } else {
      // User canceled the picker
    }
  }

  // Trigger the Lisa bot interaction
  void _lisBot() {
    var message =
        "Hey there! Loved the tunes? Let's create a playlist from your voice's emotions. Ready for a few questions?";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        _speak(message); // Speak out the message

        return AlertDialog(
          title: Text("Hello I'm Lisa!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundImage: AssetImage('assets/images/girl.png'),
                radius: 60,
              ),
              SizedBox(height: 10),
              Text(
                  "Hey there! 👋 Loved the tunes? Let's create a playlist from your voice's emotions. Ready for a few questions? 🎶✨"),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => QuestionnaireScreen()),
                );
              },
              child: Text('Start Questionnaire'),
            ),
            TextButton(
              child: Text('No. Thanks!'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Show the questionnaire questions
  void _showQuestionDialog() {
    flutterTts
        .speak(questions[currentQuestionIndex]); // Speak the current question

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
              'Question ${currentQuestionIndex + 1} of ${questions.length}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(questions[currentQuestionIndex]),
              SizedBox(height: 20),
              GestureDetector(
                onLongPress: _startRecording,
                onLongPressUp: _stopRecording,
                child: Icon(Icons.mic),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => pickAudioFile(currentQuestionIndex),
                child: Text(
                    'Pick Audio File for Question ${currentQuestionIndex + 1}'),
              ),
            ],
          ),
          actions: <Widget>[
            if (currentQuestionIndex > 0)
              TextButton(
                child: Text('Back'),
                onPressed: () {
                  setState(() {
                    currentQuestionIndex--;
                  });
                  Navigator.of(context).pop();
                  _showQuestionDialog();
                },
              ),
            TextButton(
              child: Text(currentQuestionIndex < questions.length - 1
                  ? 'Next'
                  : 'Finish'),
              onPressed: () {
                if (currentQuestionIndex < questions.length - 1) {
                  _stopRecording(); // Stop recording the current answer
                  setState(() => currentQuestionIndex++);
                  Navigator.of(context).pop();
                  _showQuestionDialog(); // Show next question
                } else {
                  _stopRecording(); // Stop recording the last answer
                  Navigator.of(context).pop();
                  submitRecordings();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Submit the recorded answers to the server
  Future<void> submitRecordings() async {
    setState(() => _isLoading = true); // Start loading

    try {
      var uri = Uri.parse('http://$mlIP:8000/predict-emotion-from-audio');
      var request = http.MultipartRequest('POST', uri);

      for (int i = 0; i < userAnswers.length; i++) {
        String path = userAnswers[i];
        if (path.isNotEmpty) {
          request.files.add(
              await http.MultipartFile.fromPath('audiofile${i + 1}', path));
        }
      }

      try {
        var response = await request.send();
        if (response.statusCode == 200) {
          String responseData = await response.stream.bytesToString();
          print('Response from server: $responseData');

          // Parse the response
          var decodedResponse = json.decode(responseData);
          String emotion = decodedResponse['emotion'];
          Map<String, dynamic> playlist = decodedResponse['playlist'];

          // Convert playlist to a list of songs
          List<Map<String, String>> songs = [];
          playlist.forEach((title, id) {
            songs.add({'title': title, 'id': id});
          });

          setState(() {
            _emotion =
                emotion; // Assuming _emotion is a state variable for emotion
            _songs = songs; // Update the _songs list
          });

          // Show the popup with the emotion
          _showEmotionPopup(emotion);
        } else {
          print('Server Error: ${response.statusCode}');
          print('Error details: ${response.stream.bytesToString()}');
        }
      } catch (e) {
        print('Error sending files: $e');
      }
    } finally {
      setState(() =>
          _isLoading = false); // Ensure loading is stopped in case of error too
    }
  }

  // Show a popup with the predicted emotion
  void _showEmotionPopup(String emotion) {
    var messagelisa =
        "You're in a $emotion mood! I've crafted a playlist just for you. Tap 'Fix Me' to explore your tunes! ";
    flutterTts.speak(messagelisa);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Your Personalized Playlist Awaits!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundImage: AssetImage('assets/images/girl.png'),
                radius: 60,
              ),
              SizedBox(height: 10),
              Text(
                  "You're in a $emotion mood! 🎵 I've crafted a playlist just for you. Tap 'Fix Me' to explore your tunes! 🌟"),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Fix Me!'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Callback for handling the end of the playlist
  void onPlaylistEnd() {
    var message =
        "Hi there! You've reached the end of your playlist. I hope you enjoyed the music. Would you like to awnser my questions?";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        _speak(message); // Speak out the message

        return AlertDialog(
          title: Text('Message from Lisa!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                backgroundImage: AssetImage('assets/images/girl.png'),
                radius: 60,
              ),
              SizedBox(height: 10),
              Text(
                  "Hi there! 👋 You've reached the end of your playlist. I hope you enjoyed the music. Would you like to awnser my questions?"),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                currentQuestionIndex = 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => QuestionnaireScreen()),
                );
              },
              child: Text('Start Questionnaire'),
            ),
            TextButton(
              child: Text('Generate New Playlist'),
              onPressed: () {
                // Add logic to generate a new playlist
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('No. Thanks!'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Dispose of resources when the widget is removed from the tree
  @override
  void dispose() {
    _myRecorder.closeRecorder();
    SpotifySdk.pause();
    flutterTts.stop();
    super.dispose();
  }
}
