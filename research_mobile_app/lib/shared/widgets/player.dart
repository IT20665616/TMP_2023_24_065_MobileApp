import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:spotify_sdk/models/crossfade_state.dart';
import 'package:spotify_sdk/models/image_uri.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

// Player widget responsible for displaying and controlling Spotify player
class Player extends StatefulWidget {
  // Properties
  final String trackId;
  final List<dynamic> playlist;
  final int currentIndex;
  final Function(int) onTrackChange;
  final Function onPlaylistEnd;

  // Constructor
  const Player({
    Key? key,
    required this.trackId,
    required this.playlist,
    required this.currentIndex,
    required this.onTrackChange,
    required this.onPlaylistEnd,
  }) : super(key: key);

  @override
  HomeState createState() => HomeState();
}

// State class for Player widget
class HomeState extends State<Player> with TickerProviderStateMixin {
  // State variables
  bool _loading = false;
  bool _connected = false;
  bool _isConnecting = false;
  bool _isLastSong = false;

  @override
  void initState() {
    super.initState();
    connectToSpotifyRemote(); // Attempt to connect right when the widget is initialized
  }

  // Logger instance for logging
  final Logger _logger = Logger(
    //filter: CustomLogFilter(), // custom logfilter can be used to have logs in release mode
    printer: PrettyPrinter(
      methodCount: 2, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      printTime: true,
    ),
  );

  CrossfadeState? crossfadeState;
  late ImageUri? currentTrackImageUri;

  @override
  void didUpdateWidget(Player oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the track when widget is updated
    if (widget.trackId != oldWidget.trackId) {
      play(widget.trackId);
    }
  }

  // Method to show connect to Spotify dialog
  void _showConnectToSpotifyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connect to Spotify'),
          content: _isConnecting
              ? const CircularProgressIndicator()
              : const Text('Please connect to Spotify to continue.'),
          actions: <Widget>[
            if (!_isConnecting)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                  setState(() {
                    _isConnecting = true;
                  });
                  connectToSpotifyRemote(); // Call your method to connect to Spotify
                },
                child: const Text('Connect'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: SpotifySdk.subscribePlayerState(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final playerState = snapshot.data!;
        final isPlaying = !playerState.isPaused;
        final track = playerState.track;

        Widget albumImage = SizedBox(
          width: ImageDimension.large.value.toDouble(),
          height: ImageDimension.large.value.toDouble(),
          child: const Center(child: Text('No image available')),
        );

        // Assume track provides an imageUri directly or through a method
        if (track != null && track.imageUri != null) {
          albumImage = spotifyImageWidget(track.imageUri);
        }
        if (track != null) {
          print("Track details: ${track.toString()}");
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Text(
                "MeloWave Player",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(height: 10),
            _buildPlayerStateWidget(),
          ],
        );
      },
    );
  }

  int _findIndexOfTrack(String trackUri) {
    final id = trackUri.split(':').last;
    return widget.playlist.indexWhere((track) => track['id'] == id);
  }

  // Method to build the player state widget
  Widget _buildPlayerStateWidget() {
    return StreamBuilder<PlayerState>(
      stream: SpotifySdk.subscribePlayerState(),
      builder: (BuildContext context, AsyncSnapshot<PlayerState> snapshot) {
        var track = snapshot.data?.track;
        currentTrackImageUri = track?.imageUri;
        var playerState = snapshot.data;

        if (playerState == null || track == null) {
          return Center(
            child: Container(),
          );
        }

        // Check if the current track has finished playing
        if (_isLastSong && playerState != null && playerState.isPaused) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPlaylistFinishedDialog();
          });
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _connected
                ? Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: spotifyImageWidget(track.imageUri),
                  )
                : const Text('Connect to see an image...'),
            SizedBox(height: 20), // Add some spacing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.skip_previous, size: 30),
                  onPressed: skipPrevious,
                ),
                IconButton(
                  icon: Icon(Icons.repeat, size: 30),
                  onPressed: toggleRepeat,
                ),
                playerState.isPaused
                    ? IconButton(
                        icon: Icon(Icons.play_circle_filled, size: 50),
                        onPressed: resume,
                      )
                    : IconButton(
                        icon: Icon(Icons.pause_circle_filled, size: 50),
                        onPressed: pause,
                      ),
                IconButton(
                  icon: Icon(Icons.info, size: 30),
                  onPressed: () => checkIfAppIsActive(context),
                ),
                IconButton(
                  icon: Icon(Icons.skip_next, size: 30),
                  onPressed: skipNext,
                ),
              ],
            ),
            SizedBox(height: 20), // Add some spacing
            Text(
              '${track.name} by ${track.artist.name}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'from the album ${track.album.name}',
              style: TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20), // Add some spacing
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Playback',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // Method to show playlist finished dialog
  void _showPlaylistFinishedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Playlist Finished'),
          content: Text('All tracks in the playlist have been played.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Method to build Spotify image widget
  Widget spotifyImageWidget(ImageUri image) {
    return FutureBuilder(
        future: SpotifySdk.getImage(
          imageUri: image,
          dimension: ImageDimension.large,
        ),
        builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!);
          } else if (snapshot.hasError) {
            setStatus(snapshot.error.toString());
            return SizedBox(
              width: ImageDimension.large.value.toDouble(),
              height: ImageDimension.large.value.toDouble(),
              child: const Center(child: Text('Error getting image')),
            );
          } else {
            return SizedBox(
              width: ImageDimension.large.value.toDouble(),
              height: ImageDimension.large.value.toDouble(),
              child: const Center(child: Text('Getting image...')),
            );
          }
        });
  }

  // Method to connect to Spotify remote
  Future<void> connectToSpotifyRemote() async {
    try {
      setState(() {
        _loading = true;
      });
      var result = await SpotifySdk.connectToSpotifyRemote(
          clientId: dotenv.env['CLIENT_ID'].toString(),
          redirectUrl: dotenv.env['REDIRECT_URL'].toString());
      setStatus(result
          ? 'connect to spotify successful'
          : 'connect to spotify failed');
      setState(() {
        _loading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _loading = false;
      });
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setState(() {
        _loading = false;
      });
      setStatus('not implemented');
    }
    setState(() {
      _isConnecting = false;
      _connected = true;
    });
  }

  // Method to get player state
  Future getPlayerState() async {
    try {
      return await SpotifySdk.getPlayerState();
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setStatus('not implemented');
    }
  }


  // Method to toggle repeat
  Future<void> toggleRepeat() async {
    try {
      await SpotifySdk.toggleRepeat();
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setStatus('not implemented');
    }
  }



  // Method to play track
  Future<void> play(String trackId) async {
    try {
      // Reset the flag when a new song starts playing
      _isLastSong = widget.currentIndex == widget.playlist.length - 1;
      await SpotifySdk.play(
          spotifyUri: 'spotify:track:$trackId'); // Modify this line
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setStatus('not implemented');
    }
  }

  // Method to pause
  Future<void> pause() async {
    try {
      await SpotifySdk.pause();
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setStatus('not implemented');
    }
  }

  // Method to resume
  Future<void> resume() async {
    try {
      await SpotifySdk.resume();
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setStatus('not implemented');
    }
  }

  // Method to skip next track
  Future<void> skipNext() async {
    try {
      int nextIndex = widget.currentIndex + 1;

      if (nextIndex >= widget.playlist.length) {
        // Last song finished, inform Home widget
        widget.onPlaylistEnd();
      } else {
        widget.onTrackChange(
            nextIndex); // Notify the Home widget about the change
        String nextTrackId = widget.playlist[nextIndex]['id'];
        await play(nextTrackId);
      }
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setStatus('not implemented');
    }
  }

  // Method to skip previous track
  Future<void> skipPrevious() async {
    try {
      int previousIndex = widget.currentIndex - 1;
      if (previousIndex < 0) {
        previousIndex = widget.playlist.length -
            1; // Loop back to the last track if at the beginning
      }
      widget.onTrackChange(
          previousIndex); // Notify the Home widget about the change
      String previousTrackId = widget.playlist[previousIndex]['id'];
      await play(previousTrackId);
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setStatus('not implemented');
    }
  }


  // Method to check if app is active
  Future<void> checkIfAppIsActive(BuildContext context) async {
    try {
      await SpotifySdk.isSpotifyAppActive.then((isActive) {
        final snackBar = SnackBar(
            content: Text(isActive
                ? 'Spotify app connection is active (currently playing)'
                : 'Spotify currently not playing)'));

        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      });
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setStatus('not implemented');
    }
  }

  // Method to set status
  void setStatus(String code, {String? message}) {
    var text = message ?? '';
    _logger.i('$code$text');
  }
}
