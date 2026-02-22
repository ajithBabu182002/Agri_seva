import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class CropPage extends StatefulWidget {
  final VoidCallback? onUpdateSuccess;
  const CropPage({super.key, this.onUpdateSuccess});

  @override
  State<CropPage> createState() => _CropPageState();
}

enum CropViewState { initial, adding, results }

class _CropPageState extends State<CropPage> {
  CropViewState _viewState = CropViewState.initial;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  
  // For adding/editing crops
  final List<TextEditingController> _cropNameControllers = [];
  final List<Uint8List?> _cropImageBytes = [];
  final List<String?> _cropImageUrls = []; // Track existing image URLs
  
  // For searching/results
  final TextEditingController _searchCountry = TextEditingController();
  final TextEditingController _searchState = TextEditingController();
  final TextEditingController _searchDistrict = TextEditingController();
  final TextEditingController _searchTaluk = TextEditingController();
  final TextEditingController _searchVillage = TextEditingController();
  List<Map<String, dynamic>> _fetchedFarmers = [];
  bool _isSearchLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
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

  void _addCropEntry({String? name, String? url}) {
    setState(() {
      _cropNameControllers.insert(0, TextEditingController(text: name));
      _cropImageBytes.insert(0, null);
      _cropImageUrls.insert(0, url);
    });
  }

  void _removeCropEntry(int index) {
    setState(() {
      _cropNameControllers.removeAt(index);
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

  Future<void> _searchFarmers() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    setState(() => _isSearchLoading = true);
    try {
      var query = Supabase.instance.client
          .from('profiles')
          .select('*, crop_data(*)')
          .neq('id', user.id); // Exclude self
          
      if (_searchCountry.text.isNotEmpty) query = query.eq('country', _searchCountry.text.trim());
      if (_searchState.text.isNotEmpty) query = query.eq('state', _searchState.text.trim());
      if (_searchDistrict.text.isNotEmpty) query = query.eq('district', _searchDistrict.text.trim());
      if (_searchTaluk.text.isNotEmpty) query = query.eq('taluk', _searchTaluk.text.trim());
      if (_searchVillage.text.isNotEmpty) query = query.eq('village', _searchVillage.text.trim());

      final data = await query;
      final filtered = (data as List).where((f) => (f['crop_data'] as List).isNotEmpty).toList();
      setState(() {
        _fetchedFarmers = List<Map<String, dynamic>>.from(filtered);
        _isSearchLoading = false;
      });
    } catch (e) {
      debugPrint("Search error: $e");
      setState(() => _isSearchLoading = false);
    }
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
        title: Text(crop['crop_name'] ?? "Crop Details", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (crop['crop_image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(crop['crop_image_url'], fit: BoxFit.cover),
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
            _addCropEntry(name: crop['crop_name'], url: crop['crop_image_url']);
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

  void _clearFilters() {
    setState(() {
      _searchCountry.clear();
      _searchState.clear();
      _searchDistrict.clear();
      _searchTaluk.clear();
      _searchVillage.clear();
      _fetchedFarmers.clear();
    });
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
    return Center(
      key: const ValueKey('initial'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8F5E9),
              boxShadow: [
                BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: const Icon(Icons.eco_rounded, size: 80, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 32),
          Text(
            "Empower Your Harvest",
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF1B5E20)),
          ),
          const SizedBox(height: 8),
          Text(
            "Share your crop details with the community",
            style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => setState(() => _viewState = CropViewState.adding),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 8,
              shadowColor: const Color(0xFF2E7D32).withOpacity(0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Start Adding", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddingView() {
    return SingleChildScrollView(
      key: const ValueKey('adding'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Profile Settings", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
          const SizedBox(height: 24),
          _buildReadOnlyProfileHeader(),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Your Crops", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("Add images and names of your produce", style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(onPressed: _addCropEntry, icon: const Icon(Icons.add_rounded, color: Color(0xFF2E7D32), size: 28)),
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
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    side: const BorderSide(color: Colors.red), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
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
                    backgroundColor: const Color(0xFF2E7D32), 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  child: Text("Update", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.2), width: 3),
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFFE8F5E9),
                  backgroundImage: _profile?['avatar_url'] != null ? NetworkImage(_profile!['avatar_url']) : null,
                  child: _profile?['avatar_url'] == null ? const Icon(Icons.person, size: 40, color: Color(0xFF2E7D32)) : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_profile?['full_name'] ?? "", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(_profile?['phone_number'] ?? "", style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1),
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
                    prefixIcon: const Icon(Icons.grass_rounded, color: Color(0xFF2E7D32)),
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
    return SingleChildScrollView(
      key: const ValueKey('results'),
      child: Column(
        children: [
          _buildFarmerCard(_profile!, isMine: true),
          _buildFilterSection(),
          if (_isSearchLoading) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.green))
          else ..._fetchedFarmers.map((f) => _buildFarmerCard(f)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    bool isEnterDisabled = _searchCountry.text.isEmpty && _searchState.text.isEmpty && _searchDistrict.text.isEmpty && _searchTaluk.text.isEmpty && _searchVillage.text.isEmpty;
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 10),
              Text("Browse by Location", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
            ],
          ),
          const SizedBox(height: 24),
          _buildFilterInput(_searchCountry, "Country", Icons.public_rounded),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildFilterInput(_searchState, "State", Icons.map_rounded)), 
            const SizedBox(width: 12), 
            Expanded(child: _buildFilterInput(_searchDistrict, "District", Icons.location_city_rounded))
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildFilterInput(_searchTaluk, "Taluk", Icons.corporate_fare_rounded)), 
            const SizedBox(width: 12), 
            Expanded(child: _buildFilterInput(_searchVillage, "Village", Icons.holiday_village_rounded))
          ]),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isEnterDisabled ? null : _searchFarmers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32), 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  child: Text("Apply Filter", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _clearFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600], 
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                child: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterInput(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint, 
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF2E7D32).withOpacity(0.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5)),
      ),
    );
  }

  Widget _buildFarmerCard(Map<String, dynamic> data, {bool isMine = false}) {
    bool isAvailable = data['is_available'] ?? true;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 2, spreadRadius: 0),
        ],
        border: Border.all(color: Colors.grey[50]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, const Color(0xFFF1F8E9).withOpacity(0.3)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: (isAvailable ? Colors.green : Colors.red).withOpacity(0.3), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 35, 
                          backgroundColor: Colors.white,
                          backgroundImage: data['avatar_url'] != null ? NetworkImage(data['avatar_url']) : null, 
                          child: data['avatar_url'] == null ? Icon(Icons.person, size: 30, color: Colors.grey[400]) : null
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['full_name'] ?? "", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
                            const SizedBox(height: 6),
                            _buildToggle(isAvailable, isMine),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showProfileDetails(data),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2E7D32),
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.2),
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildCropPreviewList(data['crop_data'] as List? ?? [], isMine),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropPreviewList(List crops, bool isMine) {
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
      children: [
        if (editable)
          Switch(
            value: active, 
            onChanged: (v) => _updateAvailability(v), 
            activeColor: Colors.green
          )
        else
          Icon(
            active ? Icons.check_circle : Icons.cancel, 
            color: active ? Colors.green : Colors.red,
            size: 20,
          ),
        const SizedBox(width: 8),
        Text(
          active ? "Available" : "Not Available", 
          style: GoogleFonts.outfit(
            fontSize: 12, 
            fontWeight: FontWeight.bold, 
            color: active ? Colors.green : Colors.red
          )
        ),
      ],
    );
  }
}
