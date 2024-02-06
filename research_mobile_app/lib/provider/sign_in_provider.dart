import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInProvider extends ChangeNotifier {
  // instance of firebaseauth, facebook and google
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn();

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  //hasError, errorCode, provider,uid, email, name, imageUrl
  bool _hasError = false;
  bool get hasError => _hasError;

  String? _errorCode;
  String? get errorCode => _errorCode;

  String? _provider;
  String? get provider => _provider;

  String? _uid;
  String? get uid => _uid;

  String? _name;
  String? get name => _name;

  String? _email;
  String? get email => _email;

  String? _age;
  String? get age => _age;

  String? _address;
  String? get address => _address;

  String? _gender;
  String? get gender => _gender;

  String? get imageUrl => _imageUrl;
  String? _imageUrl;

  String? _tankName;
  String? get newReminderTitle => _tankName;

  String? _tankID;
  String? get newTankId => _tankID;

  String? _fname;
  String? get ftank_name => _fname;

  String? _fid;
  String? get ftank_id => _fid;

  SignInProvider() {
    checkSignInUser();
  }

  Future checkSignInUser() async {
    final SharedPreferences s = await SharedPreferences.getInstance();
    _isSignedIn = s.getBool("signed_in") ?? false;
    notifyListeners();
  }

  Future setSignIn() async {
    final SharedPreferences s = await SharedPreferences.getInstance();
    s.setBool("signed_in", true);
    _isSignedIn = true;
    notifyListeners();
  }

  set name(String? newName) {
    _name = newName;
    notifyListeners();
  }

  // Function to update the age in Firestore
  Future<void> updateAge(String newAge) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({"age": newAge});
        _age = newAge.toString();
        notifyListeners();
      } catch (e) {
        // Handle errors if any
      }
    }
  }

  // Function to update the address in Firestore
  Future<void> updateAddress(String newAddress) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({"address": newAddress});
        _address = newAddress.toString();
        notifyListeners();
      } catch (e) {
        // Handle errors if any
      }
    }
  }

  // Function to update the gender in Firestore
  Future<void> updateGender(String newGender) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({"gender": newGender});
        _gender = newGender;
        notifyListeners();
      } catch (e) {
        // Handle errors if any
      }
    }
  }

  Future<void> getTankDataFromFirestore(uid) async {
    final DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("tankids")
        .doc(
            "22") // Replace "your_document_id" with the actual document ID you want to retrieve
        .get();

    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      _fname = data['tank_name'];
      _fid = data['tank_id'];
    } else {
      _fname = null;
      _fid = null;
    }
  }

  Future<void> addNewTank(String newTankName, String newTankID,
      String newTankType, String newTankAge) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Reference the user's document
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        // Reference the "tanks" subcollection under the user's document
        final tanksCollectionRef = userDocRef.collection('tankids');

        // Add a new tank document using the specified newTankID as the document ID
        await tanksCollectionRef.doc(newTankID).set({
          "tank_name": newTankName,
          "tank_id": newTankID,
          "tank_type": newTankType,
          "tank_age": newTankAge,
        });

        // Notify listeners or perform other actions as needed
        // ...
      } catch (e) {
        // Handle errors if any
        print("Error adding a new tank: $e");
      }
    }
  }

  Future<void> updateProfilePicture(String imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    // Update the profile picture URL in Firestore (replace 'users' with your user collection path)
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'image_url': imageUrl});

    // Update the profile picture URL in the provider
    _imageUrl = imageUrl;
    notifyListeners();
  }

  // Update the name in Firestore
  // Update the name in Firestore
  Future<void> updateName(String newName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.updateDisplayName(newName);
        name =
            newName; // Use the setter to update the name in the SignInProvider state
        await saveDataToFirestore(); // Save the updated data to Firestore
      } catch (e) {
        // Handle errors if any
      }
    }
  }

// Function to update the email in Firestore
  Future<void> updateEmail(String newEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.updateEmail(newEmail);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({"email": newEmail});
        _email = newEmail;
        notifyListeners();
      } catch (e) {
        // Handle errors if any
      }
    }
  }

  Future<void> signInWithGoogle() async {
    // Reset error code before proceeding
    _errorCode = '';

    final GoogleSignInAccount? googleSignInAccount =
        await googleSignIn.signIn();

    if (googleSignInAccount != null) {
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleSignInAuthentication.accessToken,
        idToken: googleSignInAuthentication.idToken,
      );

      try {
        final UserCredential? userCredential =
            await firebaseAuth.signInWithCredential(credential);

        if (userCredential != null) {
          final User userDetails = userCredential.user!;

          // Save user details
          _name = userDetails.displayName;
          _email = userDetails.email;
          _imageUrl = userDetails.photoURL;
          _provider = "GOOGLE";
          _uid = userDetails.uid;
          _hasError = false;
          notifyListeners();
        } else {
          // Handle null userCredential (error case)
          _hasError = true;
          _errorCode = "Failed to sign in with Google";
          notifyListeners();
        }
      } on FirebaseAuthException catch (e) {
        switch (e.code) {
          case "account-exists-with-different-credential":
            _errorCode =
                "You already have an account with us. Use correct provider";
            _hasError = true;
            notifyListeners();
            break;

          case "null":
            _errorCode = "Some unexpected error while trying to sign in";
            _hasError = true;
            notifyListeners();
            break;

          default:
            _errorCode = e.toString();
            _hasError = true;
            notifyListeners();
        }
      }
    } else {
      _hasError = true;
      notifyListeners();
    }
  }

  // ENTRY FOR CLOUDFIRESTORE
  Future<void> getUserDataFromFirestore(uid) async {
    final DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection("users").doc(uid).get();

    if (snapshot.exists) {
      final data = snapshot.data() as Map<String, dynamic>;
      _uid = data['uid'];
      _name = data['name'];
      _email = data['email'];
      _age = data['age'];
      _gender = data['gender'];
      _address = data['address'];
      _imageUrl = data['image_url'];
      _provider = data['provider'];

      // ... (other fields if available)
    } else {
      // Handle the case when the document doesn't exist
      // You might want to initialize the fields to default values here
      _uid = null;
      _name = null;
      _email = null;
      _age = null;
      _gender = null;
      _address = null;
      _imageUrl = null;
      _provider = null;

      // ... (initialize other fields if available)
    }
  }

  Future<void> saveDataToFirestore([DateTime? selectedTime]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = {
        "name": name,
        "uid": uid,
        "age": age,
        "gender": gender,
        "address": address,
        "image_url": imageUrl,
        "email": email,
        "provider": provider,
        // Add the 'selectedTime' to the userData map only if it's not null
        if (selectedTime != null) "sleep_timer": selectedTime.toUtc(),
      };
      // Save the user data to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(userData, SetOptions(merge: true));
      } catch (e) {
        // Handle errors if any
      }
    }
  }

  Future<void> saveDataToSharedPreferences() async {
    final SharedPreferences s = await SharedPreferences.getInstance();
    if (_name != null) await s.setString('name', _name!);
    if (_email != null) await s.setString('email', _email!);
    if (_uid != null) await s.setString('uid', _uid!);
    if (_provider != null) await s.setString('provider', _provider!);
    if (_imageUrl != null) await s.setString('image_url', _imageUrl!);

    notifyListeners();
  }

  Future getDataFromSharedPreferences() async {
    final SharedPreferences s = await SharedPreferences.getInstance();
    _name = s.getString('name');
    _email = s.getString('email');
    _imageUrl = s.getString('image_url');
    _uid = s.getString('uid');
    _provider = s.getString('provider');
    _age = s.getString('age');
    _gender = s.getString('gender');
    _address = s.getString('address');
    // _sleepTimer = s.getString('sleep_timer') as DateTime?;
    notifyListeners();
  }

  // checkUser exists or not in cloudfirestore
  Future<bool> checkUserExists() async {
    DocumentSnapshot snap =
        await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (snap.exists) {
      // ignore: avoid_print
      print("EXISTING USER");
      return true;
    } else {
      // ignore: avoid_print
      print("NEW USER");
      return false;
    }
  }

  // signout
  Future userSignOut() async {
    firebaseAuth.signOut;
    await googleSignIn.signOut();

    _isSignedIn = false;
    notifyListeners();
    // clear all storage information
    clearStoredData();
  }

  Future clearStoredData() async {
    final SharedPreferences s = await SharedPreferences.getInstance();
    s.clear();
  }

  selectProfilePictureFromGallery() {}
}
