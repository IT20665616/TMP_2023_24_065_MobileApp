import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:melowave1/config/theme/app_bar.dart';
import 'package:melowave1/config/theme/theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:melowave1/util/player.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

// Main Search class, extends StatefulWidget
class Search extends StatefulWidget {
  static String routeName = '/home';

  const Search({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

// State class for the Search widget
class _HomeState extends State<Search> {
  String? selectedTrackId;
  bool _isGeneratingPlaylist = false;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _songs = [];
  AudioPlayer audioPlayer = AudioPlayer();
  final String _apiKey = dotenv.env['RAPID_API'].toString();
  String? mlIP = dotenv.env['MLIP']?.isEmpty ?? true
      ? dotenv.env['DEFAULT_IP']
      : dotenv.env['MLIP'];

  @override
  void initState() {
    super.initState();
  }

  // Function to search songs based on query
  void searchSongs(String query) async {
    var url = Uri.parse('https://spotify23.p.rapidapi.com/search/?q=$query');
    var response = await http.get(url, headers: {
      'x-rapidapi-host': 'spotify23.p.rapidapi.com',
      'x-rapidapi-key': _apiKey
    });

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      print(data); // Print the JSON to examine its structure

      if (data != null && data.containsKey('tracks')) {
        var tracks = data['tracks'];
        if (tracks != null && tracks.containsKey('items')) {
          setState(() {
            _songs = tracks['items'].map((item) {
              var trackData = item['data'] ?? {};
              return {
                'title': trackData['name'], // Track name
                'id': trackData['id'] // Track ID
              };
            }).toList();
          });
        }
      }
    } else {
      print('Failed to fetch data');
    }
  }

  // Function to fetch song list based on emotion and recommendation
  void fetchSongList(String emotion, String recommend) async {
    setState(() {
      _isGeneratingPlaylist = true; // Start loading
    });
    String cleanedEmotion = emotion.replaceAll('"', '');
    String cleanedRecommendation = recommend.replaceAll('"', '');

    var url = Uri.parse(
        'http://$mlIP:8000/songlist?emotion=$cleanedEmotion&weather=$cleanedRecommendation');
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

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser!;

    // Function to toggle favorite status of a track
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

    return Scaffold(
      backgroundColor: AppColors.homebg,
      appBar: CustomAppBar(
        title: "Search",
        leadingImage: null, // Pass the user's photo URL directly
        actionImage: null,
        onLeadingPressed: () {
          print("Leading icon pressed");
        },
        onActionPressed: () {
          print("Action icon pressed");
        },
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: "What do you want to listen to?",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () {
                      searchSongs(_searchController.text);
                    },
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // Conditionally display Player widget
              // if (selectedTrackId != null) Player(trackId: selectedTrackId!),
              // SizedBox(height: 20.h),
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
                          leading: Icon(Icons.music_note,
                              color: AppColors.colorPrimary),
                          title: Text(song['title']),
                          subtitle: Text('${song['id']}'),
                          onTap: () => onTrackTap(song['id']),
                          trailing: IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isFavorite ? Colors.red : Colors.grey,
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
          ),
        ),
      ),
    );
  }

  // Function to handle track tap event
  void onTrackTap(String trackId) async {
    try {
      await SpotifySdk.play(spotifyUri: 'spotify:track:$trackId');

      setState(() {
        selectedTrackId = trackId;
        // Implement the logic to play the selected track using audioPlayer
      });
    } on PlatformException catch (e) {
      // Handle any exceptions here
      print("Error playing track: ${e.message}");
    }
  }
}
