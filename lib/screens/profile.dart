import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_scanner_app/screens/settings.dart';
import 'dart:io';
import '../models/pokemon_card.dart';

class ProfilePage extends StatefulWidget {
  final List<CardData> portfolio;

  const ProfilePage({super.key, required this.portfolio});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _username = 'Cole';
  String _bio = 'This is my bio.';
  File? _profileImage;
  int _totalCards = 0;
  double _totalValue = 0.0;
  final ImagePicker _picker = ImagePicker();
  bool _isLoadingImage = false;
  final String _profileImageKey = 'profile_image_path';
  final String _usernameKey = 'username';
  final String _bioKey = 'bio';

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _calculateStats();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString(_usernameKey) ?? 'Cole';
      _bio = prefs.getString(_bioKey) ?? 'This is my bio.';

      final imagePath = prefs.getString(_profileImageKey);
      if (imagePath != null) {
        _profileImage = File(imagePath);
      }
    });
  }

  void _calculateStats() {
    setState(() {
      _totalCards = widget.portfolio.length;
      _totalValue = widget.portfolio.fold(
        0.0,
            (double sum, CardData card) => sum + card.marketPrice,
      );
    });
  }

  Future<void> _saveProfileImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImageKey, path);
  }

  Future<void> _saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  Future<void> _saveBio(String bio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bioKey, bio);
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _bio = 'Bio last updated at ${TimeOfDay.now().format(context)}';
      _saveBio(_bio);
      _calculateStats();
    });
  }

  Future<void> _changeProfilePicture() async {
    try {
      setState(() => _isLoadingImage = true);

      final option = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) =>
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(
                        Icons.camera_alt, color: Colors.teal.shade600),
                    title: const Text('Take Photo'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: Icon(
                        Icons.photo_library, color: Colors.teal.shade600),
                    title: const Text('Choose from Gallery'),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
      );

      if (option != null) {
        final XFile? image = await _picker.pickImage(
          source: option,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );

        if (image != null) {
          setState(() => _profileImage = File(image.path));
          await _saveProfileImage(image.path);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoadingImage = false);
    }
  }

  void _editUsername() async {
    final newUsername = await showDialog<String>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(
              'Edit Username',
              style: TextStyle(
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [
                      Colors.blue.shade700,
                      Colors.green.shade700,
                    ],
                  ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
              ),
            ),
            content: TextFormField(
              initialValue: _username,
              decoration: InputDecoration(
                hintText: 'Enter new username',
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal.shade600),
                ),
              ),
              maxLength: 20,
              onFieldSubmitted: (value) => Navigator.pop(context, value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    'Cancel', style: TextStyle(color: Colors.teal.shade600)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _username),
                child: Text(
                    'Save', style: TextStyle(color: Colors.teal.shade600)),
              ),
            ],
          ),
    );

    if (newUsername != null && newUsername.isNotEmpty) {
      setState(() => _username = newUsername);
      await _saveUsername(newUsername);
    }
  }

  void _editBio() async {
    final newBio = await showDialog<String>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(
              'Edit Bio',
              style: TextStyle(
                foreground: Paint()
                  ..shader = LinearGradient(
                    colors: [
                      Colors.blue.shade700,
                      Colors.green.shade700,
                    ],
                  ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
              ),
            ),
            content: TextFormField(
              initialValue: _bio,
              decoration: InputDecoration(
                hintText: 'Tell us about yourself',
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal.shade600),
                ),
              ),
              maxLines: 5,
              maxLength: 500,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                    'Cancel', style: TextStyle(color: Colors.teal.shade600)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _bio),
                child: Text(
                    'Save', style: TextStyle(color: Colors.teal.shade600)),
              ),
            ],
          ),
    );

    if (newBio != null && newBio.isNotEmpty) {
      setState(() => _bio = newBio);
      await _saveBio(newBio);
    }
  }

  Widget _buildProfileHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.teal.shade600, width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade100,
                    Colors.green.shade100,
                  ],
                ),
              ),
              child: _isLoadingImage
                  ? CircularProgressIndicator(color: Colors.teal.shade600)
                  : ClipOval(
                child: _profileImage != null
                    ? Image.file(
                  _profileImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/images/user_avatar.png',
                      fit: BoxFit.cover,
                    );
                  },
                )
                    : Image.asset(
                  'assets/images/user_avatar.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _changeProfilePicture,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.shade700,
                        Colors.green.shade700,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Username text with gradient
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        LinearGradient(
                          colors: [
                            Colors.blue.shade700,
                            Colors.green.shade700,
                          ],
                        ).createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        ),
                    child: Text(
                      _username,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Edit username button moved right beside the name
                  IconButton(
                    icon: Icon(
                        Icons.edit, size: 20, color: Colors.teal.shade600),
                    onPressed: _editUsername,
                    constraints: const BoxConstraints(),
                    // Remove default padding
                    padding: const EdgeInsets.only(
                        left: 4), // Add small padding to the left
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _editBio,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _bio.isEmpty ? 'Add a bio...' : _bio,
                          style: TextStyle(
                            color: _bio.isEmpty ? Colors.grey : Colors.black87,
                          ),
                        ),
                      ),
                      Icon(Icons.edit, size: 16, color: Colors.teal.shade600),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.green.shade50,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('TOTAL CARDS', '$_totalCards', Icons.collections),
            Container(
              height: 40,
              width: 1,
              color: Colors.teal.shade200,
            ),
            _buildStatItem(
              'VALUE',
              '\$${_totalValue.toStringAsFixed(2)}',
              Icons.attach_money,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.teal.shade600),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            foreground: Paint()
              ..shader = LinearGradient(
                colors: [
                  Colors.blue.shade700,
                  Colors.green.shade700,
                ],
              ).createShader(const Rect.fromLTWH(0.0, 0.0, 100.0, 20.0)),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              LinearGradient(
                colors: [
                  Colors.blue.shade700,
                  Colors.green.shade700,
                ],
              ).createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
          child: const Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.green.shade50,
                ],
              ),
            ),
            child: Center(
              child: Text(
                'Your activity will appear here',
                style: TextStyle(color: Colors.teal.shade600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LiquidPullToRefresh(
      onRefresh: _handleRefresh,
      color: Colors.blue.shade100,
      backgroundColor: Colors.green.shade100,
      height: 100,
      animSpeedFactor: 1.5,
      showChildOpacityTransition: true,
      springAnimationDurationInMilliseconds: 500,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Main content
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16), // Reset padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    _buildStatsCard(),
                    const SizedBox(height: 24),
                    _buildActivitySection(),
                  ],
                ),
              ),

              // Settings button positioned at top right
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.settings, color: Colors.teal.shade600),
                  onPressed: _navigateToSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}