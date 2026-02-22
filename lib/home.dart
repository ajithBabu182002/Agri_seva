import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_state_city_picker/country_state_city_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();
  
  String? _selectedCountry;
  String? _selectedState;
  String? _avatarUrl;
  String _countryCode = '';
  bool _isLoading = true;
  bool _isSaving = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        _nameController.text = data['full_name'] ?? '';
        _countryCode = data['country_code'] ?? '';
        _phoneController.text = data['phone_number'] ?? '';
        _addressController.text = data['address'] ?? '';
        _pinController.text = data['pin_code'] ?? '';
        _selectedCountry = data['country'];
        _selectedState = data['state'];
        _avatarUrl = data['avatar_url'];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    // Show a square "crop" preview dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Adjust Profile Picture", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Preview in square format", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: AspectRatio(
                    aspectRatio: 1, // Forced square aspect ratio for "crop" feel
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performUpload(bytes, image.name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Save", style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  Future<void> _performUpload(Uint8List bytes, String imageName) async {
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final fileExt = imageName.split('.').last;
      final fileName = '${user.id}.$fileExt';
      final filePath = fileName;

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            filePath, 
            bytes, 
            fileOptions: const FileOptions(upsert: true, contentType: 'image/*')
          );

      final avatarUrl = '${Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath)}?t=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client.from('profiles').update({
        'avatar_url': avatarUrl,
      }).eq('id', user.id);

      setState(() => _avatarUrl = avatarUrl);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture updated!', style: GoogleFonts.outfit()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    final user = Supabase.instance.client.auth.currentUser;

    try {
      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'country_code': _countryCode,
        'phone_number': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'country': _selectedCountry,
        'state': _selectedState,
        'pin_code': _pinController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!', style: GoogleFonts.outfit()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
        _fetchProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmEmailController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Account", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("This action is permanent. Enter details to confirm.", style: GoogleFonts.outfit(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: confirmEmailController, 
              decoration: InputDecoration(
                labelText: 'Confirm Email',
                labelStyle: GoogleFonts.outfit(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController, 
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: GoogleFonts.outfit(),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              try {
                await Supabase.instance.client.auth.signInWithPassword(
                  email: confirmEmailController.text.trim(),
                  password: confirmPasswordController.text.trim(),
                );
                
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verification Failed: $e")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text("Delete Permanently", style: GoogleFonts.outfit()),
          )
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            backgroundColor: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Icon & Title
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _avatarUrl == null ? const Icon(Icons.person, size: 40, color: Colors.green) : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("Edit Profile", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
                    Text("Update your personal information", style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[500])),
                    const SizedBox(height: 30),

                    // Input Form
                    _buildEditField(_nameController, "Full Name", Icons.person_outline_rounded),
                    _buildEditField(_phoneController, "Phone Number", Icons.phone_android_rounded, type: TextInputType.phone),
                    
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: SelectState(
                        onCountryChanged: (v) => setDialogState(() => _selectedCountry = v),
                        onStateChanged: (v) => setDialogState(() => _selectedState = v),
                        onCityChanged: (v) {},
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildEditField(_addressController, "Home Address", Icons.location_on_outlined),
                    _buildEditField(_pinController, "Pin Code", Icons.pin_drop_outlined, type: TextInputType.number),
                    
                    const SizedBox(height: 24),
                    
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: Text("Save Changes", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          ),
          TextField(
            controller: controller,
            keyboardType: type,
            style: GoogleFonts.outfit(fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey[200]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey[200]!)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text("Agrovia Global", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1, color: const Color(0xFF1B5E20))),
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: _buildHomeContent(),
    );
  }

  Widget _buildHomeContent() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', height: 100),
          const SizedBox(height: 16),
          Text(
            "Welcome to Agrovia Global",
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          Text(
            "Tap the menu to explore",
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Clean home page with only core drawer navigation

  Widget _buildDrawer() {
    final user = Supabase.instance.client.auth.currentUser;
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24, right: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _avatarUrl == null ? const Icon(Icons.person, size: 45, color: Colors.green) : null,
                      ),
                    ),
                    // View Icon on top of profile icon (Top Right)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () {
                          if (_avatarUrl != null) {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.network(_avatarUrl!, fit: BoxFit.contain),
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.visibility, size: 16, color: Colors.green),
                        ),
                      ),
                    ),
                    // Camera Icon (Bottom Right)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _uploadAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.green, width: 2)),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(_nameController.text.toUpperCase(), 
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(user?.email ?? "", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          _drawerItem(Icons.settings_outlined, "Profile Settings", _showEditProfileDialog),
          _drawerItem(Icons.history_outlined, "Service History", () {}),
          _drawerItem(Icons.help_outline, "Help & Support", () {}),
          const Divider(indent: 24, endIndent: 24),
          _drawerItem(Icons.logout_rounded, "Sign Out", () async {
            await Supabase.instance.client.auth.signOut();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          }, color: Colors.orange),
          _drawerItem(Icons.lock_reset_rounded, "Update Password", _showUpdatePasswordDialog, color: const Color(0xFF2E7D32)),
          _drawerItem(Icons.delete_forever_outlined, "Delete Account", _deleteAccount, color: Colors.red),
        ],
      ),
    );
  }

  void _showUpdatePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isOldVerified = false;
    bool isVerifyingOld = false;
    bool passwordsMatch = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Update Password", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
                  const SizedBox(height: 8),
                  Text("Verify your old password to set a new one.", style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 24),

                  // Old Password Field
                  _buildEditField(oldPasswordController, "Old Password", Icons.lock_outline, type: TextInputType.visiblePassword),
                  
                  if (!isOldVerified)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isVerifyingOld ? null : () async {
                          setDialogState(() => isVerifyingOld = true);
                          try {
                            final user = Supabase.instance.client.auth.currentUser;
                            await Supabase.instance.client.auth.signInWithPassword(
                              email: user!.email!,
                              password: oldPasswordController.text,
                            );
                            setDialogState(() => isOldVerified = true);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Incorrect old password"), backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setDialogState(() => isVerifyingOld = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: isVerifyingOld 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Verify Old Password", style: GoogleFonts.outfit()),
                      ),
                    ),

                  const Divider(height: 40),

                  // New Password Fields (Enabled only after verification)
                  Opacity(
                    opacity: isOldVerified ? 1.0 : 0.4,
                    child: Column(
                      children: [
                        _buildEditField(
                          newPasswordController, 
                          "New Password", 
                          Icons.vpn_key_outlined, 
                          type: TextInputType.visiblePassword,
                        ),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          enabled: isOldVerified,
                          onChanged: (v) {
                            setDialogState(() {
                              passwordsMatch = v.isNotEmpty && v == newPasswordController.text;
                            });
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)),
                            labelText: "Confirm New Password",
                            labelStyle: GoogleFonts.outfit(fontSize: 14),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (isOldVerified && confirmPasswordController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        passwordsMatch ? "✅ Passwords match" : "❌ Passwords don't match",
                        style: GoogleFonts.outfit(fontSize: 12, color: passwordsMatch ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),

                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.grey[600])),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (isOldVerified && passwordsMatch) ? () async {
                            try {
                              await Supabase.instance.client.auth.updateUser(
                                UserAttributes(password: newPasswordController.text),
                              );
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Password updated successfully!"), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                            }
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          child: Text("Update", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color color = Colors.black87}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: GoogleFonts.outfit(fontSize: 15, color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
