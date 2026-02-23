import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class SubHomeDetailsIconPage extends StatefulWidget {
  final Map<String, dynamic> filterCriteria;
  const SubHomeDetailsIconPage({super.key, required this.filterCriteria});

  @override
  State<SubHomeDetailsIconPage> createState() => _SubHomeDetailsIconPageState();
}

class _SubHomeDetailsIconPageState extends State<SubHomeDetailsIconPage> {
  final List<Map<String, dynamic>> _directDealsCategories = [
    {'name': 'All', 'icon': Icons.all_inclusive_rounded},
    {'name': 'Fruits', 'icon': Icons.apple_rounded},
    {'name': 'Vegetable', 'icon': Icons.egg_alt_rounded},
    {'name': 'Trees', 'icon': Icons.park_rounded},
    {'name': 'Cow', 'icon': Icons.pets_rounded},
    {'name': 'Milk', 'icon': Icons.water_drop_rounded},
    {'name': 'Sheep', 'icon': Icons.cruelty_free_rounded},
    {'name': 'Honey', 'icon': Icons.hive_rounded},
    {'name': 'Oil', 'icon': Icons.opacity_rounded},
    {'name': 'Masala', 'icon': Icons.blender_rounded},
  ];

  final List<Map<String, dynamic>> _cropCareCategories = [
    {'name': 'Fertilizer', 'icon': Icons.science_rounded},
    {'name': 'Seeds', 'icon': Icons.grain_rounded},
    {'name': 'Pesticides', 'icon': Icons.bug_report_rounded},
  ];

  String _selectedCategory = 'All';
  bool _isLoading = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      setState(() => _userProfile = data);
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> _deleteDeal(String id) async {
    try {
      await Supabase.instance.client.from('direct_deals').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Listing deleted successfully"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Error deleting deal: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _buildCategoryDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("Marketplace", style: GoogleFonts.outfit(color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF1B5E20)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildQuickFilterBar(),
          Expanded(
            child: _buildDealsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDealDialog,
        backgroundColor: const Color(0xFF1B5E20),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text("Create your field", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildQuickFilterBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ..._directDealsCategories.map((c) => _filterChip(c)),
          ..._cropCareCategories.map((c) => _filterChip(c)),
        ],
      ),
    );
  }

  Widget _filterChip(Map<String, dynamic> cat) {
    bool isSelected = _selectedCategory == cat['name'];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(cat['name'], style: GoogleFonts.outfit(color: isSelected ? Colors.white : Colors.black87, fontSize: 13)),
        selected: isSelected,
        onSelected: (v) => setState(() => _selectedCategory = cat['name']),
        backgroundColor: Colors.grey[100],
        selectedColor: const Color(0xFF1B5E20),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildDealsList() {
    final query = Supabase.instance.client.from('direct_deals').stream(primaryKey: ['id']);
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: query,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No deals found", style: GoogleFonts.outfit(color: Colors.grey)));
        }

        final filtered = snapshot.data!.where((d) {
          if (_selectedCategory == 'All') return true;
          return d['category'] == _selectedCategory;
        }).toList();

        if (filtered.isEmpty) {
          return Center(child: Text("No items in $_selectedCategory", style: GoogleFonts.outfit(color: Colors.grey)));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final deal = filtered[index];
            return _buildDealCard(deal);
          },
        );
      },
    );
  }

  Widget _buildDealCard(Map<String, dynamic> deal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: deal['image_url'] != null
                  ? Image.network(deal['image_url'], fit: BoxFit.cover, width: double.infinity)
                  : Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deal['item_name'] ?? "", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text("₹${deal['price']}", style: GoogleFonts.outfit(color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(deal['farmer_name'] ?? "", style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded, size: 10, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text(deal['farmer_phone'] ?? "", style: GoogleFonts.outfit(fontSize: 11, color: Colors.blueGrey))),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(child: Text("${deal['village']}, ${deal['district']}", style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
                if (deal['profile_id'] == _userProfile?['id'])
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => _showDeleteConfirmation(deal['id']),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Listing", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete this product listing?", style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.grey))),
          TextButton(onPressed: () {Navigator.pop(context); _deleteDeal(id);}, child: Text("Delete", style: GoogleFonts.outfit(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildCategoryDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF388E3C)]),
            ),
            child: Center(
              child: Text("Categories", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildDrawerSection("Direct Deals", _directDealsCategories),
                const Divider(),
                _buildDrawerSection("Crop Care", _cropCareCategories),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
        ),
        ...items.map((i) => ListTile(
          leading: Icon(i['icon'], color: const Color(0xFF1B5E20)),
          title: Text(i['name'], style: GoogleFonts.outfit()),
          onTap: () {
            setState(() => _selectedCategory = i['name']);
            Navigator.pop(context);
          },
        )),
      ],
    );
  }

  void _showCreateDealDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    String? selectedCat = 'Fruits';
    Uint8List? imageBytes;
    String? imageName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Text("Create your field", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
                const SizedBox(height: 16),
                
                // Pre-filled Profile Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      _profileRow(Icons.person, _userProfile?['full_name'] ?? "-"),
                      _profileRow(Icons.phone, _userProfile?['phone_number'] ?? "-"),
                      _profileRow(Icons.location_on, "${_userProfile?['village']}, ${_userProfile?['taluk']}, ${_userProfile?['district']}, ${_userProfile?['state']}"),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Image Upload
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.gallery);
                    if (img != null) {
                      final bytes = await img.readAsBytes();
                      setModalState(() {
                        imageBytes = bytes;
                        imageName = img.name;
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                    ),
                    child: imageBytes == null
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo_rounded, size: 40, color: Colors.grey), const SizedBox(height: 8), Text("Add Product Image", style: GoogleFonts.outfit(color: Colors.grey))])
                        : ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(imageBytes!, fit: BoxFit.cover)),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                DropdownButtonFormField<String>(
                  value: selectedCat,
                  decoration: InputDecoration(
                    labelText: "Select Category",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  items: [..._directDealsCategories.skip(1), ..._cropCareCategories]
                      .map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(
                        value: c['name'] as String,
                        child: Text(c['name'] as String, style: GoogleFonts.outfit()),
                      )).toList(),
                  onChanged: (v) => setModalState(() => selectedCat = v),
                ),
                
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: "Product Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                  style: GoogleFonts.outfit(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: "Price (₹)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), prefixText: "₹ "),
                  style: GoogleFonts.outfit(),
                ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      if (nameController.text.isEmpty || priceController.text.isEmpty || imageBytes == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields and add an image")));
                        return;
                      }
                      
                      setModalState(() => _isLoading = true);
                      try {
                        String? imageUrl;
                        if (imageBytes != null) {
                          final user = Supabase.instance.client.auth.currentUser!;
                          final path = 'deals/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          await Supabase.instance.client.storage.from('avatars').uploadBinary(path, imageBytes!);
                          imageUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
                        }
                        
                        await Supabase.instance.client.from('direct_deals').insert({
                          'profile_id': _userProfile!['id'],
                          'category': selectedCat,
                          'item_name': nameController.text.trim(),
                          'price': double.parse(priceController.text),
                          'image_url': imageUrl,
                          'farmer_name': _userProfile!['full_name'],
                          'farmer_phone': _userProfile!['phone_number'],
                          'country': _userProfile!['country'],
                          'state': _userProfile!['state'],
                          'district': _userProfile!['district'],
                          'taluk': _userProfile!['taluk'],
                          'village': _userProfile!['village'],
                          'pincode': _userProfile!['pin_code'],
                        });
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deal posted successfully!"), backgroundColor: Colors.green));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                      } finally {
                        setModalState(() => _isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text("Post Deal", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[700]))),
        ],
      ),
    );
  }
}
