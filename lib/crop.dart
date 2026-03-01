import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class CropPage extends StatefulWidget {
  final Map<String, dynamic> filterCriteria;
  final VoidCallback? onUpdateSuccess;
  const CropPage({super.key, required this.filterCriteria, this.onUpdateSuccess});

  @override
  State<CropPage> createState() => _CropPageState();
}

enum CropViewState { initial, adding, results }

class _CropPageState extends State<CropPage> {
  CropViewState _viewState = CropViewState.initial;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  final ScreenshotController _screenshotController = ScreenshotController();
  
  // For adding/editing crops
  final List<TextEditingController> _cropNameControllers = [];
  final List<TextEditingController> _harvestDateControllers = [];
  final List<String> _qualitySelections = [];
  final List<Uint8List?> _cropImageBytes = [];
  final List<String?> _cropImageUrls = []; // Track existing image URLs
  
  List<Map<String, dynamic>> _fetchedFarmers = [];
  bool _isSearchLoading = false;

  late final Stream<List<Map<String, dynamic>>> _farmersStream;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _initFarmersStream();
  }

  void _initFarmersStream() {
    final user = Supabase.instance.client.auth.currentUser;
    _farmersStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .map((data) => data.where((f) => f['id'] != user?.id).toList());
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      // Fetch profile with its associated crops
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('*, crop_data(*)')
          .eq('id', user.id)
          .single();

      setState(() {
        _profile = profileData;
        // If the user already has crops, skip the initial "Add" screen and show results
        final userCrops = profileData['crop_data'] as List? ?? [];
        if (userCrops.isNotEmpty) {
          _viewState = CropViewState.results;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      setState(() => _isLoading = false);
    }
  }

  void _addCropEntry({String? name, String? url, String? harvestDate, String? quality}) {
    setState(() {
      _cropNameControllers.insert(0, TextEditingController(text: name));
      _harvestDateControllers.insert(0, TextEditingController(text: harvestDate ?? DateFormat('dd-MM-yyyy').format(DateTime.now())));
      _qualitySelections.insert(0, quality ?? 'Organic');
      _cropImageBytes.insert(0, null);
      _cropImageUrls.insert(0, url);
    });
  }

  void _removeCropEntry(int index) {
    setState(() {
      _cropNameControllers.removeAt(index);
      _harvestDateControllers.removeAt(index);
      _qualitySelections.removeAt(index);
      _cropImageBytes.removeAt(index);
      _cropImageUrls.removeAt(index);
    });
  }

  Future<void> _pickCropImage(int index) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _cropImageBytes[index] = bytes;
        _cropImageUrls[index] = null; // Clear URL if a new image is picked
      });
    }
  }

  Future<void> _updateCrops() async {
    if (_cropNameControllers.isEmpty) return;
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    try {
      for (int i = 0; i < _cropNameControllers.length; i++) {
        String? finalImageUrl = _cropImageUrls[i];
        
        if (_cropImageBytes[i] != null) {
          final fileName = '${user!.id}_${DateTime.now().millisecondsSinceEpoch}_$i.png';
          await Supabase.instance.client.storage
              .from('crop_images')
              .uploadBinary(fileName, _cropImageBytes[i]!, fileOptions: const FileOptions(contentType: 'image/png'));
          finalImageUrl = Supabase.instance.client.storage.from('crop_images').getPublicUrl(fileName);
        }

        await Supabase.instance.client.from('crop_data').insert({
          'profile_id': user!.id,
          'crop_name': _cropNameControllers[i].text.trim(),
          'crop_image_url': finalImageUrl,
          'harvest_date': _harvestDateControllers[i].text,
          'quality': _qualitySelections[i],
        });
      }
      
      // Refresh profile data to include new crops
      await _fetchProfile();
      
      setState(() {
        _viewState = CropViewState.results;
        _isLoading = false;
        _cropNameControllers.clear();
        _cropImageBytes.clear();
      });
    } catch (e) {
      debugPrint("Error updating crops: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> farmers) {
    final fc = widget.filterCriteria;
    
    // Only apply filters if field is 'All' or 'Crop Details'
    if (fc['field'] != 'All' && fc['field'] != 'Crop Details') {
      return farmers;
    }

    return farmers.where((f) {
      bool matches = true;
      if (fc['country'] != null && fc['country']!.isNotEmpty) {
        matches &= (f['country'] == fc['country']);
      }
      if (fc['country'] == 'India') {
        if (fc['state'] != null && fc['state']!.isNotEmpty) {
          matches &= (f['state'] == fc['state']);
        }
        if (fc['district'] != null && fc['district']!.isNotEmpty) {
          matches &= (f['district'] == fc['district']);
        }
        if (fc['taluk'] != null && fc['taluk']!.isNotEmpty) {
          matches &= (f['taluk'] == fc['taluk']);
        }
        if (fc['village'] != null && fc['village']!.isNotEmpty) {
          matches &= (f['village'] == fc['village']);
        }
      }
      return matches;
    }).toList();
  }

  Future<void> _confirmDeleteEntry(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Confirm Deletion", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to remove this crop entry?", style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("No", style: GoogleFonts.outfit(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Yes, Delete", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      _removeCropEntry(index);
    }
  }

  void _showCropPreview(int index) {
    final name = _cropNameControllers[index].text;
    final image = _cropImageBytes[index];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(name.isEmpty ? "Crop Details" : name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(image, fit: BoxFit.cover),
              )
            else
              Container(
                height: 100, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Close", style: GoogleFonts.outfit())),
        ],
      ),
    );
  }

  Future<void> _updateAvailability(bool value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'is_available': value})
          .eq('id', user.id);
      
      setState(() {
        _profile!['is_available'] = value;
      });
    } catch (e) {
      debugPrint("Error updating availability: $e");
    }
  }

  Future<void> _deleteCropFromDb(dynamic cropId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Confirm Deletion", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to remove this crop from your profile?", style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("No", style: GoogleFonts.outfit(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Yes, Delete", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('crop_data').delete().eq('id', cropId);
        await _fetchProfile(); // Refresh my state
      } catch (e) {
        debugPrint("Error deleting crop: $e");
      }
    }
  }

  void _viewSingleCrop(Map<String, dynamic> crop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(crop['crop_name'] ?? "Crop Details", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (crop['crop_image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(crop['crop_image_url'], fit: BoxFit.cover),
              )
            else
              Container(
                height: 140, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 60),
              ),
            const SizedBox(height: 16),
            _infoRow(Icons.calendar_month_rounded, "Harvest Date", crop['harvest_date'] ?? "Not set"),
            _infoRow(Icons.verified_rounded, "Quality", crop['quality'] ?? "Regular"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Close", style: GoogleFonts.outfit())),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF10B981)),
          const SizedBox(width: 8),
          Text("$label: ", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[600], fontSize: 13)),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }

  void _showAgroQR(Map<String, dynamic> crop, Map<String, dynamic> farmer) {
    final String qrData = "Agrovia Global Certified\n"
        "Farmer: ${farmer['full_name']}\n"
        "Origin: ${farmer['village']}, ${farmer['district']}\n"
        "Crop: ${crop['crop_name']}\n"
        "Quality: ${crop['quality'] ?? 'Organic'}";

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The shareable certificate part
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Premium Header Gradient
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: Colors.white, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                "AGROVIA GLOBAL",
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2),
                              ),
                              Text(
                                "DIGITAL BIRTH CERTIFICATE",
                                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          children: [
                            // The QR Code
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
                              ),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 180.0,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF1B5E20)),
                                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF2E7D32)),
                              ),
                            ),
                            
                            const SizedBox(height: 25),
                            
                            // Product Title
                            Text(
                              crop['crop_name']?.toUpperCase() ?? "HARVEST",
                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF064E3B)),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Data Grid
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  _certificateFeature(Icons.person_rounded, "Farmer Name", farmer['full_name']),
                                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                                  _certificateFeature(Icons.location_on_rounded, "Origin Village", farmer['village']),
                                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                                  _certificateFeature(Icons.calendar_month_rounded, "Harvest Date", crop['harvest_date']),
                                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                                  _certificateFeature(Icons.workspace_premium_rounded, "Quality Seal", crop['quality']),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Text(
                              "Certified by Agrovia Trust Network",
                              style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[400], fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Floating Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionBtn(Icons.close_rounded, "Close", Colors.white.withOpacity(0.2), () => Navigator.pop(context)),
                  const SizedBox(width: 15),
                  _actionBtn(Icons.share_rounded, "Share Certificate", const Color(0xFF10B981), () => _handleShare(crop['crop_name'] ?? "Harvest")),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100), border: Border.all(color: Colors.white24)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _certificateFeature(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF10B981)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.bold)),
            Text(value ?? "-", style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
          ],
        ),
      ],
    );
  }

  Future<void> _handleShare(String cropName) async {
    try {
      if (kIsWeb) {
        // Web doesn't support file sharing the same way, we provide a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sharing screenshot is not supported on Web. Use a mobile device."))
        );
        return;
      }

      final uint8list = await _screenshotController.capture();
      if (uint8list != null) {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/agro_certificate.png').create();
        await file.writeAsBytes(uint8list);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Check out my certified $cropName harvest on Agrovia Global! 🌾',
        );
      }
    } catch (e) {
      debugPrint("Sharing error: $e");
    }
  }

  void _showProfileDetails(Map<String, dynamic> data) {
    bool isMine = data['id'] == Supabase.instance.client.auth.currentUser?.id;
    
    if (isMine) {
      setState(() {
        _viewState = CropViewState.adding;
        _cropNameControllers.clear();
        _cropImageBytes.clear();
        _cropImageUrls.clear();
        
        final crops = data['crop_data'] as List? ?? [];
        if (crops.isNotEmpty) {
          // Reflect existing crops
          for (var crop in crops.reversed) {
            _addCropEntry(
              name: crop['crop_name'], 
              url: crop['crop_image_url'],
              harvestDate: crop['harvest_date'],
              quality: crop['quality']
            );
          }
        } else {
          _addCropEntry();
        }
      });
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(data['full_name'] ?? "Farmer Profile", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: data['avatar_url'] != null ? NetworkImage(data['avatar_url']) : null,
                child: data['avatar_url'] == null ? const Icon(Icons.person, size: 50) : null,
              ),
            ),
            const SizedBox(height: 20),
            _profileDetailRow("Phone", data['phone_number']),
            const Divider(height: 24),
            _profileDetailRow("Country", data['country']),
            _profileDetailRow("State", data['state']),
            _profileDetailRow("District", data['district']),
            _profileDetailRow("Taluk", data['taluk']),
            _profileDetailRow("Village", data['village']),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Close", style: GoogleFonts.outfit())),
        ],
      ),
    );
  }

  Widget _profileDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label:", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          Text((value == null || value.toString().trim().isEmpty) ? "n/a" : value.trim(), style: GoogleFonts.outfit(color: Colors.black)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.green));

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_viewState) {
      case CropViewState.initial:
        return _buildInitialView();
      case CropViewState.adding:
        return _buildAddingView();
      case CropViewState.results:
        return _buildResultsView();
    }
  }

  Widget _buildInitialView() {
    return Container(
      key: const ValueKey('initial'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, const Color(0xFFF0FDF4).withOpacity(0.5)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withOpacity(0.05),
                  ),
                ),
                Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withOpacity(0.1),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF064E3B).withOpacity(0.1), blurRadius: 40, spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.eco_rounded, size: 60, color: Color(0xFF10B981)),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              "Agrovia Global",
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF10B981), letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            Text(
              "Empower Your Harvest",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF064E3B), height: 1.1),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Connect with farmers and showcase your produce to the digital world.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 56),
            ElevatedButton(
              onPressed: () => setState(() => _viewState = CropViewState.adding),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF064E3B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 12,
                shadowColor: const Color(0xFF064E3B).withOpacity(0.4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Get Started", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddingView() {
    return SingleChildScrollView(
      key: const ValueKey('adding'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "DASHBOARD",
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF064E3B), letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Text("Profile Settings", style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: const Color(0xFF064E3B))),
          const SizedBox(height: 24),
          _buildReadOnlyProfileHeader(),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Your Produce", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF064E3B))),
                  Text("Manage what you grown", style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500])),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF064E3B).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: IconButton(onPressed: _addCropEntry, icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 16),
          ...List.generate(_cropNameControllers.length, (i) => _buildCropEntry(i)),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final hasCrops = (_profile?['crop_data'] as List? ?? []).isNotEmpty;
                    setState(() => _viewState = hasCrops ? CropViewState.results : CropViewState.initial);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18), 
                    side: BorderSide(color: Colors.red[200]!), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                  ),
                  child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.red[400], fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_cropNameControllers.isNotEmpty && 
                              _cropNameControllers.every((c) => c.text.trim().isNotEmpty) && 
                              List.generate(_cropNameControllers.length, (i) => _cropImageBytes[i] != null || _cropImageUrls[i] != null).every((hasImg) => hasImg)) 
                               ? _updateCrops : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF064E3B), 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 18), 
                    elevation: 8,
                    shadowColor: const Color(0xFF064E3B).withOpacity(0.4),
                    disabledBackgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                  ),
                  child: Text("Update Profile", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: const Color(0xFF064E3B).withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 15)),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF064E3B)]),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: _profile?['avatar_url'] != null ? NetworkImage(_profile!['avatar_url']) : null,
                  child: _profile?['avatar_url'] == null ? const Icon(Icons.person, size: 40, color: Color(0xFF064E3B)) : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_profile?['full_name'] ?? "", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF064E3B))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF064E3B)),
                          const SizedBox(width: 6),
                          Text(_profile?['phone_number'] ?? "", style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF064E3B), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          _buildReadOnlyGrid(),
        ],
      ),
    );
  }

  Widget _buildReadOnlyGrid() {
    return Wrap(
      spacing: 12, runSpacing: 12,
      children: ['Country', 'State', 'District', 'Taluk', 'Village'].map((key) {
        final val = _profile?[key.toLowerCase()];
        return SizedBox(
          width: MediaQuery.of(context).size.width / 2 - 40,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(key, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text((val == null || val.toString().isEmpty) ? "-" : val.toString(), style: GoogleFonts.outfit(fontSize: 13, color: Colors.black87)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildCropEntry(int index) {
    bool isLatest = index == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cropNameControllers[index],
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: "Enter crop name",
                    hintStyle: GoogleFonts.outfit(color: Colors.grey[400], fontWeight: FontWeight.normal),
                    prefixIcon: const Icon(Icons.grass_rounded, color: Color(0xFF10B981)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: isLatest ? null : () => _confirmDeleteEntry(index),
                icon: Icon(isLatest ? Icons.check_circle : Icons.remove_circle_outline, 
                     color: isLatest ? Colors.grey[300] : Colors.red[400]),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _harvestDateControllers[index],
                  readOnly: true,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF1B5E20))),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      _harvestDateControllers[index].text = DateFormat('dd-MM-yyyy').format(picked);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: "Harvest Date",
                    prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF10B981)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _qualitySelections[index],
                  items: ['Organic', 'Natural', 'Regular'].map((q) => DropdownMenuItem(value: q, child: Text(q, style: GoogleFonts.outfit(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _qualitySelections[index] = v!),
                  decoration: InputDecoration(
                    labelText: "Quality",
                    prefixIcon: const Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _pickCropImage(index),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!, style: BorderStyle.solid),
              ),
              child: _cropImageBytes[index] != null 
                ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(_cropImageBytes[index]!, fit: BoxFit.cover))
                : (_cropImageUrls[index] != null 
                    ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(_cropImageUrls[index]!, fit: BoxFit.cover))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, color: Colors.grey[400], size: 40),
                          const SizedBox(height: 8),
                          Text("Add Crop Image", style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _farmersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
        }
        
        final allFarmers = snapshot.data ?? [];
        final filteredFarmers = _applyFilters(allFarmers);

        return SingleChildScrollView(
          key: const ValueKey('results'),
          child: Column(
            children: [
              _buildFarmerCard(_profile!, isMine: true),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Divider(color: Color(0xFFF1F5F9)),
              ),
              if (filteredFarmers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No farmers found matching filters", style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 16)),
                    ],
                  ),
                )
              else
                ...filteredFarmers.map((f) => _buildFarmerCard(f)),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }


  Widget _buildFarmerCard(Map<String, dynamic> data, {bool isMine = false}) {
    bool isAvailable = data['is_available'] ?? true;
    
    // Check if crops are already fetched (isMine case)
    List crops = data['crop_data'] as List? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: const Color(0xFF064E3B).withOpacity(0.06), blurRadius: 40, offset: const Offset(0, 15)),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, const Color(0xFFF0FDF4).withOpacity(0.4)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: (isAvailable ? const Color(0xFF10B981) : Colors.red).withOpacity(0.4), width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: 38, 
                          backgroundColor: const Color(0xFFF1F5F9),
                          backgroundImage: data['avatar_url'] != null ? NetworkImage(data['avatar_url']) : null, 
                          child: data['avatar_url'] == null ? const Icon(Icons.person, size: 35, color: Color(0xFFCBD5E1)) : null
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['full_name'] ?? "", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF064E3B))),
                            const SizedBox(height: 8),
                            _buildToggle(isAvailable, isMine),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.1),
                        child: InkWell(
                          onTap: () => _showProfileDetails(data),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFF064E3B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 20),
                  if (isMine)
                    _buildCropPreviewList(crops, true, data)
                  else
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: Supabase.instance.client.from('crop_data').select().eq('profile_id', data['id']),
                      builder: (context, snapshot) {
                        final fetchedCrops = snapshot.data ?? [];
                        if (fetchedCrops.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                           return Text("No crops listed", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400]));
                        }
                        return _buildCropPreviewList(fetchedCrops, false, data);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropPreviewList(List crops, bool isMine, Map<String, dynamic> farmer) {
    if (crops.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: crops.length,
        itemBuilder: (context, idx) {
          final crop = crops[idx];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 16, bottom: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
              border: Border.all(color: const Color(0xFFE8F5E9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (crop['crop_image_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(crop['crop_image_url'], width: 35, height: 35, fit: BoxFit.cover),
                      )
                    else 
                      Container(
                        width: 35, height: 35, 
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.grass_rounded, size: 20, color: Colors.grey),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        crop['crop_name'] ?? "-", 
                        style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _viewSingleCrop(crop),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => _showAgroQR(crop, farmer),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.orange),
                        ),
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _deleteCropFromDb(crop['id']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggle(bool active, bool editable) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (editable)
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: active, 
              onChanged: (v) => _updateAvailability(v), 
              activeColor: const Color(0xFF10B981),
              activeTrackColor: const Color(0xFF10B981).withOpacity(0.2),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: (active ? const Color(0xFF10B981) : Colors.red).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active ? Icons.check_rounded : Icons.close_rounded, 
              color: active ? const Color(0xFF10B981) : Colors.red,
              size: 14,
            ),
          ),
        const SizedBox(width: 8),
        Text(
          active ? "Available" : "Not Available", 
          style: GoogleFonts.outfit(
            fontSize: 13, 
            fontWeight: FontWeight.w700, 
            color: active ? const Color(0xFF064E3B) : Colors.red[700]
          )
        ),
      ],
    );
  }
}
