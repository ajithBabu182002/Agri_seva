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
      child: GestureDetector(
        onTap: () => setState(() => _viewState = CropViewState.adding),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Add Your Crop Details",
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20)),
              ),
              const SizedBox(height: 8),
              Text("Tap to start", style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
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
          _buildReadOnlyProfileHeader(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Add Crop", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: _addCropEntry, icon: const Icon(Icons.add_circle, color: Color(0xFF2E7D32), size: 30)),
            ],
          ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 35, backgroundImage: _profile?['avatar_url'] != null ? NetworkImage(_profile!['avatar_url']) : null, child: _profile?['avatar_url'] == null ? const Icon(Icons.person) : null),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_profile?['full_name'] ?? "", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_profile?['phone_number'] ?? "", style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
                ]),
              ),
            ],
          ),
          const Divider(height: 32),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cropNameControllers[index],
                  decoration: InputDecoration(hintText: "Crop Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              IconButton(
                onPressed: isLatest ? _addCropEntry : () => _confirmDeleteEntry(index),
                icon: Icon(isLatest ? Icons.add_circle : Icons.remove_circle, color: isLatest ? Colors.green : Colors.red),
              ),
              if (!isLatest)
                IconButton(
                  onPressed: () => _showCropPreview(index),
                  icon: const Icon(Icons.visibility_rounded, color: Color(0xFF2E7D32)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pickCropImage(index),
            child: Container(
              height: 100, width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)),
              child: _cropImageBytes[index] != null 
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_cropImageBytes[index]!, fit: BoxFit.cover))
                : (_cropImageUrls[index] != null 
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(_cropImageUrls[index]!, fit: BoxFit.cover))
                    : const Icon(Icons.camera_alt, color: Colors.grey)),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text("Location Filter", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildFilterInput(_searchCountry, "Country"),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _buildFilterInput(_searchState, "State")), const SizedBox(width: 12), Expanded(child: _buildFilterInput(_searchDistrict, "District"))]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _buildFilterInput(_searchTaluk, "Taluk")), const SizedBox(width: 12), Expanded(child: _buildFilterInput(_searchVillage, "Village"))]),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isEnterDisabled ? null : _searchFarmers,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text("Enter", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: Text("Clear", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterInput(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  Widget _buildFarmerCard(Map<String, dynamic> data, {bool isMine = false}) {
    bool isAvailable = data['is_available'] ?? true;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: Colors.grey[100]!)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['full_name'] ?? "", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    _buildToggle(isAvailable, isMine),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _showProfileDetails(data),
                      child: Text(
                        isMine ? "View Profile" : "View Details", 
                        style: GoogleFonts.outfit(
                          fontSize: 12, 
                          color: const Color(0xFF2E7D32), 
                          fontWeight: FontWeight.bold, 
                          decoration: TextDecoration.underline
                        )
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(radius: 35, backgroundImage: data['avatar_url'] != null ? NetworkImage(data['avatar_url']) : null, child: data['avatar_url'] == null ? const Icon(Icons.person) : null),
            ],
          ),
          const Divider(height: 24),
          _buildCropPreviewList(data['crop_data'] as List? ?? [], isMine),
        ],
      ),
    );
  }

  Widget _buildCropPreviewList(List crops, bool isMine) {
    if (crops.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: crops.length,
        itemBuilder: (context, idx) {
          final crop = crops[idx];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green[100]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (crop['crop_image_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(crop['crop_image_url'], width: 30, height: 30, fit: BoxFit.cover),
                      ),
                    const SizedBox(width: 8),
                    Text(crop['crop_name'] ?? "-", style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _viewSingleCrop(crop), 
                      icon: const Icon(Icons.visibility_rounded, size: 16, color: Colors.green)
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _deleteCropFromDb(crop['id']), 
                        icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red)
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
