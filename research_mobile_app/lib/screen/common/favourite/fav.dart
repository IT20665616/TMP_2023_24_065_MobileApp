import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:melowave1/core/utils/app_bar.dart';
import 'package:melowave1/core/constants/colors.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import '../../../shared/widgets/player.dart'; // Import the Player widget
import 'package:audioplayers/audioplayers.dart'; // Import AudioPlayer

// fav class, a StatefulWidget to display favorite music
class fav extends StatefulWidget {
  final String userId;
  // Constructor to receive the userId
  const fav({Key? key, required this.userId}) : super(key: key);

  @override
  State<fav> createState() => _favState();
}

// State class for the fav widget
class _favState extends State<fav> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  AudioPlayer audioPlayer = AudioPlayer();
  String? selectedTrackId;
  List<dynamic> favoriteSongs = []; // Add a list to hold favorite songs

  // Function to remove a track from favorites
  void _removeFromFavorite(String trackId) async {
    await firestore.doc('users/${widget.userId}/favorite/$trackId').delete();
  }

  // Function to play a track on tap
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

  // Build method to create the widget tree for the fav widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Favourite Music",
        leadingImage: null, // Pass the user's photo URL directly
        actionImage: null,
        onLeadingPressed: () {
          print("Leading icon pressed");
        },
        onActionPressed: () {
          print("Action icon pressed");
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            firestore.collection('users/${widget.userId}/favorite').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          }

          favoriteSongs =
              snapshot.data!.docs.map((doc) => doc.data() as Map).toList();

          return SingleChildScrollView(
              // Wrap with SingleChildScrollView
              child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(height: 10),
                Column(
                  children: [
                    Text(
                      "You Favourited Music List",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 20),
                    ListView.builder(
                      physics:
                          NeverScrollableScrollPhysics(), // Disable scrolling for ListView
                      shrinkWrap:
                          true, // Needed to make ListView work inside SingleChildScrollView
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var song = snapshot.data!.docs[index].data() as Map;

                        return Card(
                          elevation: 4,
                          child: ListTile(
                            leading: Icon(Icons.music_note,
                                color: AppColors.colorPrimary),
                            title: Text(song['title']),
                            subtitle: Text('${song['id']}'),
                            onTap: () => onTrackTap(song['id']),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: AppColors.colorPrimary),
                              onPressed: () => _removeFromFavorite(song['id']),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                )
              ],
            ),
          ));
        },
      ),
    );
  }
}
