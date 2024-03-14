import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:melowave1/config/theme/theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../provider/internet_provider.dart';
import '../../../provider/sign_in_provider.dart';
import '../../../util/next_screen.dart';
import '../../../util/snack_bar.dart';
import '../../login/login_screen.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Body extends StatefulWidget {
  final User? user;

  const Body({super.key, this.user});

  @override
  State<Body> createState() => _Bodystate();
}

class _Bodystate extends State<Body> {
  final RoundedLoadingButtonController googleController =
      RoundedLoadingButtonController();
  final RoundedLoadingButtonController facebookController =
      RoundedLoadingButtonController();
  final RoundedLoadingButtonController twitterController =
      RoundedLoadingButtonController();

  // Fetch user data from SharedPreferences
  Future<void> getData() async {
    final sp = context.read<SignInProvider>();
    await sp.getDataFromSharedPreferences();
  }

  DateTime? selectedTime;

  @override
  void initState() {
    super.initState();
    getData();
  }

  // Function to fetch the latest data from Firestore and update the state
  Future<void> _refreshData() async {
    final sp = context.read<SignInProvider>();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Fetch the latest user data from Firestore
      await sp.getUserDataFromFirestore(user.uid);
    }

    // Set the state to trigger a rebuild with the latest data
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SignInProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // const SizedBox(height: 20),
              buildProfilePicture('${sp.imageUrl}'),
              const SizedBox(height: 10),
              buildUserName('${sp.name}'),
              const SizedBox(height: 30),

              // User Information Section
              buildSectionTitle("Owner Info"),
              buildProfileCard(context, FontAwesomeIcons.fileSignature, "Name"),
              buildProfileCard(context, Icons.email, "Email"),
              buildProfileCard(context, FontAwesomeIcons.person, "Age"),
              buildProfileCard(context, Icons.contact_page_rounded, "Gender"),
              buildProfileCard(context, Icons.location_city, "Address"),
              buildProfileCard(
                  context, FontAwesomeIcons.rightToBracket, "SignOut"),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Function to build the profile picture widget
  Widget buildProfilePicture(String? imageUrl) {
    return GestureDetector(
      onTap: () async {
        await _updateProfilePictureFromGallery();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 155,
            height: 155,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.colorPrimary,
            ),
          ),
          (imageUrl != null && imageUrl.isNotEmpty && imageUrl != "null")
              ? CircleAvatar(
                  radius: 70,
                  backgroundImage: NetworkImage(imageUrl),
                )
              : const Icon(
                  Icons.account_circle,
                  size: 140,
                  color: Colors.white,
                ),
        ],
      ),
    );
  }

  // Function to update the profile picture from the gallery
  Future<void> _updateProfilePictureFromGallery() async {
    final sp = context.read<SignInProvider>();
    // ignore: deprecated_member_use
    final pickedImage =
        await ImagePicker().getImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      Reference ref = FirebaseStorage.instance
          .ref()
          .child('profilePicture')
          .child('${sp.uid}.jpg');
      UploadTask uploadTask = ref.putFile(File(pickedImage.path));

      await uploadTask.then((res) async {
        String downloadURL = await res.ref.getDownloadURL();

        // Call the method to update the profile picture in the provider
        await sp.updateProfilePicture(downloadURL);
      });
    }
  }

    // Function to build the user name widget
  Widget buildUserName(String? displayName) {
    return Align(
      alignment: Alignment.center,
      child: Text(
        displayName ?? "",
        style: const TextStyle(
          fontSize: 26,
          // color: AppColors.colorcolorPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

    // Function to build the user name widget
Widget buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            // color: AppColors.colorcolorPrimary,
          ),
        ),
      ),
    );
  }

  // Function to show a dialog for editing the name
  void _showEditNameDialog(BuildContext context) {
    final sp = context.read<SignInProvider>();

    // TextEditingController to get the user's input
    TextEditingController _nameController =
        TextEditingController(text: sp.name);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.isNotEmpty) {
                  // Update the name in Firestore
                  await sp.updateName(_nameController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Function to show a dialog for editing Email
  void _showEditEmailDialog(BuildContext context) {
    final sp = context.read<SignInProvider>();
    TextEditingController _emailController =
        TextEditingController(text: sp.email);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Email'),
          content: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await sp.updateEmail(_emailController.text);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

    // Function to show a dialog for editing Address
void _showEditAddressDialog(BuildContext context) {
    final sp = context.read<SignInProvider>();
    TextEditingController _addressController =
        TextEditingController(text: sp.address);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Address'),
          content: TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String newAddress = _addressController.text;
                await sp.updateAddress(newAddress);

                // Save the age to SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                int? addressInt = int.tryParse(newAddress);
                if (addressInt != null) {
                  prefs.setInt('userAddress', addressInt);
                } else {
                  // Handle the case where the address is not a valid integer.
                  // For example, show an error message to the user.
                }

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

    // Function to generate subtitle based on field value
String _generateSubtitleForNull(dynamic fieldValue, String message) {
    if (fieldValue == null) {
      return message;
    } else if (fieldValue is String && fieldValue.isNotEmpty) {
      return fieldValue;
    } else if (fieldValue is DateTime) {
      return DateFormat.jm().format(fieldValue);
    } else {
      return message;
    }
  }

  // Function to show a dialog for editing Age
  void _showEditAgeDialog(BuildContext context) {
    final sp = context.read<SignInProvider>();
    TextEditingController _ageController = TextEditingController(text: sp.age);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Age'),
          content: TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String newAge = _ageController.text;
                await sp.updateAge(newAge);

                // Save the age to SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                prefs.setInt('userAge', int.parse(newAge));

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Function to show a dialog for editing Gender
  void _showEditGenderDialog(BuildContext context) {
    final sp = context.read<SignInProvider>();
    TextEditingController _genderController =
        TextEditingController(text: sp.gender);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Gender'),
          content: DropdownButtonFormField<String>(
            value: _genderController.text.isNotEmpty
                ? _genderController.text
                : 'Male', // Set 'Male' as the default value
            items: ['Male', 'Female', 'Other'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              _genderController.text = newValue!;
            },
            decoration: const InputDecoration(labelText: 'Gender'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await sp.updateGender(_genderController.text);

                // Save the gender to SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                prefs.setString('userGender', _genderController.text);

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

    // Function to build a profile card widget
Widget buildProfileCard(BuildContext context, IconData icon, String title) {
    final sp = context.watch<SignInProvider>();
    bool isConnected = false;
    String subtitle = "";

    if (title == "Google" && sp.provider == "GOOGLE") {
      isConnected = true;
      subtitle = "Connected";
    } else {
      if (title == "Name") {
        subtitle = "${sp.name}";
      } else if (title == "Age") {
        subtitle = _generateSubtitleForNull(sp.age, "Add your age");
      } else if (title == "Gender") {
        subtitle = _generateSubtitleForNull(sp.gender, "Add your gender");
      } else if (title == "Email") {
        subtitle = "${sp.email}";
      } else if (title == "Address") {
        subtitle = _generateSubtitleForNull(sp.address, "Add your address");
      }
    }

    return GestureDetector(
      onTap: () {
        if (title == "Name") {
          // Show the dialog to edit the name
          _showEditNameDialog(context);
        } else if (title == "Email") {
          // Show the dialog to edit the name
          _showEditEmailDialog(context);
        } else if (title == "Age") {
          // Show the dialog to edit the name
          _showEditAgeDialog(context);
        } else if (title == "Gender") {
          // Show the dialog to edit the name
          _showEditGenderDialog(context);
        } else if (title == "Address") {
          // Show the dialog to edit the name
          _showEditAddressDialog(context);
        } else if (title == "SignOut") {
          // Show the dialog to edit the name
          sp.userSignOut();
          nextScreenReplace(context, const LoginScreen());
        }
      },
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // Rounded corners
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: AppColors.colorPrimary,
            size: 32,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              // color: AppColors.colorcolorPrimary,
              fontSize: 18,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isConnected
                  ? Colors.black
                  : Colors.black, // Use green color when connected
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: AppColors.colorPrimary,
          ),
        ),
      ),
    );
  }

  // handling google sigin in
  Future handleGoogleSignIn() async {
    final sp = context.read<SignInProvider>();
    final ip = context.read<InternetProvider>();
    await ip.checkInternetConnection();

    if (ip.hasInternet == false) {
      openSnackbar(context, "Check your Internet connection", Colors.red);
      googleController.reset();
    } else {
      await sp.signInWithGoogle().then((value) {
        if (sp.hasError == true) {
          openSnackbar(context, sp.errorCode.toString(), Colors.red);
          googleController.reset();
        } else {
          // checking whether user exists or not
          sp.checkUserExists().then((value) async {
            if (value == true) {
              // user exists
              await sp.getUserDataFromFirestore(sp.uid).then((value) => sp
                  .saveDataToSharedPreferences()
                  .then((value) => sp.setSignIn().then((value) {
                        googleController.success();
                        //handleAfterSignIn();
                      })));
            } else {
              // user does not exist
              sp.saveDataToFirestore(selectedTime).then((value) => sp
                  .saveDataToSharedPreferences()
                  .then((value) => sp.setSignIn().then((value) {
                        googleController.success();
                        // handleAfterSignIn();
                      })));
            }
          });
        }
      });
    }
  }
}
