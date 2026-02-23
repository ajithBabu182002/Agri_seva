import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class LabourPage extends StatefulWidget {
  final Map<String, dynamic> filterCriteria;
  const LabourPage({super.key, required this.filterCriteria});

  @override
  State<LabourPage> createState() => _LabourPageState();
}

enum LabourViewState { initial, adding, results }

class _LabourPageState extends State<LabourPage> {
  LabourViewState _viewState = LabourViewState.initial;
  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  // For adding/editing labour fields
  final List<TextEditingController> _labourTypeControllers = [];
  final List<DateTime?> _selectedDates = [];
  final List<TextEditingController> _priceHourControllers = [];
  final List<TextEditingController> _priceDayControllers = [];
  final List<TextEditingController> _priceLoadControllers = [];
  final List<bool> _isOtherType = [];

  late final Stream<List<Map<String, dynamic>>> _labourStream;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _initLabourStream();
  }

  void _initLabourStream() {
    final user = Supabase.instance.client.auth.currentUser;
    // Only stream profiles where is_labourer is true
    _labourStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('is_labourer', true)
        .map((data) => data.where((f) => f['id'] != user?.id).toList());
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('*, labour_data(*)')
          .eq('id', user.id)
          .single();

      setState(() {
        _profile = profileData;
        final userLabour = profileData['labour_data'] as List? ?? [];
        if (userLabour.isNotEmpty) {
          _viewState = LabourViewState.results;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      setState(() => _isLoading = false);
    }
  }

  void _addLabourEntry({String? type, DateTime? date, double? h, double? d, double? l}) {
    List<String> defaults = ['Agriculture Labour', 'Construction Labour', 'Loading/Unloading'];
    bool isOther = type != null && !defaults.contains(type);
    
    setState(() {
      _labourTypeControllers.insert(0, TextEditingController(text: type ?? 'Agriculture Labour'));
      _selectedDates.insert(0, date ?? DateTime.now());
      _priceHourControllers.insert(0, TextEditingController(text: h?.toString() ?? ''));
      _priceDayControllers.insert(0, TextEditingController(text: d?.toString() ?? ''));
      _priceLoadControllers.insert(0, TextEditingController(text: l?.toString() ?? ''));
      _isOtherType.insert(0, isOther);
    });
  }

  void _removeLabourEntry(int index) {
    setState(() {
      _labourTypeControllers.removeAt(index);
      _selectedDates.removeAt(index);
      _priceHourControllers.removeAt(index);
      _priceDayControllers.removeAt(index);
      _priceLoadControllers.removeAt(index);
      _isOtherType.removeAt(index);
    });
  }

  Future<void> _updateLabour() async {
    if (_labourTypeControllers.isEmpty) return;
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    try {
      // Clear existing labour data first to "replace" with new list
      await Supabase.instance.client.from('labour_data').delete().eq('profile_id', user!.id);

      for (int i = 0; i < _labourTypeControllers.length; i++) {
        await Supabase.instance.client.from('labour_data').insert({
          'profile_id': user.id,
          'labour_field_type': _labourTypeControllers[i].text.trim(),
          'availability_date': _selectedDates[i]!.toIso8601String().split('T')[0],
          'price_per_hour': double.tryParse(_priceHourControllers[i].text),
          'price_per_day': double.tryParse(_priceDayControllers[i].text),
          'price_per_load': double.tryParse(_priceLoadControllers[i].text),
        });
      }

      // Mark user as a labourer in profiles
      await Supabase.instance.client
          .from('profiles')
          .update({'is_labourer': true})
          .eq('id', user.id);

      await _fetchProfile();
      setState(() {
        _viewState = LabourViewState.results;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error updating labour: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> labourList) {
    final fc = widget.filterCriteria;
    if (fc['field'] != 'All' && fc['field'] != 'Labour') return [];

    return labourList.where((f) {
      bool matches = true;
      if (fc['country'] != null && fc['country']!.isNotEmpty) matches &= (f['country'] == fc['country']);
      if (fc['country'] == 'India') {
        if (fc['state'] != null && fc['state']!.isNotEmpty) matches &= (f['state'] == fc['state']);
        if (fc['district'] != null && fc['district']!.isNotEmpty) matches &= (f['district'] == fc['district']);
        if (fc['taluk'] != null && fc['taluk']!.isNotEmpty) matches &= (f['taluk'] == fc['taluk']);
        if (fc['village'] != null && fc['village']!.isNotEmpty) matches &= (f['village'] == fc['village']);
      }
      return matches;
    }).toList();
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
      case LabourViewState.initial: return _buildInitialView();
      case LabourViewState.adding: return _buildAddingView();
      case LabourViewState.results: return _buildResultsView();
    }
  }

  Widget _buildInitialView() {
    return Center(
      key: const ValueKey('initial'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_rounded, size: 80, color: const Color(0xFF1B5E20).withOpacity(0.2)),
          const SizedBox(height: 24),
          Text("No labour field created yet", style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 32),
          _buildActionCard(),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewState = LabourViewState.adding;
          _labourTypeControllers.clear();
          _selectedDates.clear();
          _priceHourControllers.clear();
          _priceDayControllers.clear();
          _priceLoadControllers.clear();
          
          final existing = _profile?['labour_data'] as List? ?? [];
          if (existing.isNotEmpty) {
            for (var l in existing) {
              _addLabourEntry(
                type: l['labour_field_type'],
                date: DateTime.tryParse(l['availability_date']),
                h: (l['price_per_hour'] as num?)?.toDouble(),
                d: (l['price_per_day'] as num?)?.toDouble(),
                l: (l['price_per_load'] as num?)?.toDouble(),
              );
            }
          } else {
            _addLabourEntry();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF1B5E20).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.add_rounded, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(child: Text("Create your labour field", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
          ],
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
          Text("Labour Registration", style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E20))),
          const SizedBox(height: 8),
          Text("Details reflect in public search", style: GoogleFonts.outfit(color: Colors.grey)),
          const SizedBox(height: 24),
          _buildReadOnlyProfileHeader(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Service Fields", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => _addLabourEntry(), icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF1B5E20), size: 30)),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_labourTypeControllers.length, (i) => _buildLabourFieldEntry(i)),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _viewState = (_profile?['labour_data'] as List? ?? []).isEmpty ? LabourViewState.initial : LabourViewState.results),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: Text("Clear", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _updateLabour,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text("Update Details", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: _profile?['avatar_url'] != null ? NetworkImage(_profile!['avatar_url']) : null,
                child: _profile?['avatar_url'] == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_profile?['full_name'] ?? "", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(_profile?['phone_number'] ?? "", style: GoogleFonts.outfit(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 16, runSpacing: 8,
            children: ['Country', 'State', 'District', 'Taluk', 'Village'].map((k) => Text("$k: ${_profile?[k.toLowerCase()] ?? '-'}", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[700]))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLabourFieldEntry(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _isOtherType[index] ? 'Other' : _labourTypeControllers[index].text,
                      decoration: InputDecoration(
                        labelText: "Labour Field Type",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: ['Agriculture Labour', 'Construction Labour', 'Loading/Unloading', 'Other']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.outfit()))).toList(),
                      onChanged: (v) {
                        setState(() {
                          if (v == 'Other') {
                            _isOtherType[index] = true;
                            _labourTypeControllers[index].clear();
                          } else {
                            _isOtherType[index] = false;
                            _labourTypeControllers[index].text = v!;
                          }
                        });
                      },
                    ),
                    if (_isOtherType[index])
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                          controller: _labourTypeControllers[index],
                          decoration: InputDecoration(
                            hintText: "Enter custom labour type",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          style: GoogleFonts.outfit(),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(onPressed: () => _removeLabourEntry(index), icon: const Icon(Icons.remove_circle_outline, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _selectedDates[index]!, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _selectedDates[index] = d);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF1B5E20)),
                  const SizedBox(width: 12),
                  Text(DateFormat('yMMMd').format(_selectedDates[index]!), style: GoogleFonts.outfit()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPriceField(_priceHourControllers[index], "Price / Hr")),
              const SizedBox(width: 8),
              Expanded(child: _buildPriceField(_priceDayControllers[index], "Price / Day")),
              const SizedBox(width: 8),
              Expanded(child: _buildPriceField(_priceLoadControllers[index], "Price / Load")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixText: "₹ ",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: GoogleFonts.outfit(fontSize: 13),
    );
  }

  Widget _buildResultsView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _labourStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final filteredData = _applyFilters(snapshot.data ?? []);
        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              _buildActionCard(), // The "Create/Edit" box at the top
              const SizedBox(height: 16),
              _buildFarmerCard(_profile!, isMine: true),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Divider()),
              if (filteredData.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(children: [Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]), const SizedBox(height: 16), Text("No labourers found", style: GoogleFonts.outfit(color: Colors.grey))]),
                )
              else
                ...filteredData.map((f) => _buildFarmerCard(f)),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFarmerCard(Map<String, dynamic> data, {bool isMine = false}) {
    bool isAvailable = data['is_available'] ?? true;
    final labourEntries = data['labour_data'] as List? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: CircleAvatar(
              radius: 35,
              backgroundImage: data['avatar_url'] != null ? NetworkImage(data['avatar_url']) : null,
              child: data['avatar_url'] == null ? const Icon(Icons.person) : null,
            ),
            title: Text(data['full_name'] ?? "", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['phone_number'] ?? "", style: GoogleFonts.outfit(color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: (isAvailable ? Colors.green : Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text(isAvailable ? "Available" : "Busy", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: isAvailable ? Colors.green : Colors.red)),
                    ),
                    if (isMine)
                      Switch(
                        value: isAvailable,
                        onChanged: (v) async {
                           await Supabase.instance.client.from('profiles').update({'is_available': v}).eq('id', data['id']);
                           setState(() => data['is_available'] = v);
                        },
                        activeColor: Colors.green,
                      ),
                  ],
                ),
              ],
            ),
            trailing: InkWell(
              onTap: () => _viewProfile(data),
              child: const CircleAvatar(backgroundColor: Color(0xFFF8FAFC), child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black)),
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client.from('labour_data').select().eq('profile_id', data['id']),
            builder: (context, snapshot) {
              final labourEntries = snapshot.data ?? (isMine ? (data['labour_data'] as List? ?? []) : []);
              if (labourEntries.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                return const SizedBox();
              }
              return Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    Text("Labour Fields:", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    ...labourEntries.take(2).map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF1B5E20)),
                          const SizedBox(width: 8),
                          Text("${l['labour_field_type']} (${l['availability_date']})", style: GoogleFonts.outfit(fontSize: 13)),
                        ],
                      ),
                    )),
                    if (labourEntries.length > 2) Text("+ ${labourEntries.length - 2} more", style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _viewProfile(Map<String, dynamic> data) {
    final labour = data['labour_data'] as List? ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            CircleAvatar(radius: 50, backgroundImage: data['avatar_url'] != null ? NetworkImage(data['avatar_url']) : null),
            const SizedBox(height: 16),
            Text(data['full_name'] ?? "", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(data['phone_number'] ?? "", style: GoogleFonts.outfit(color: Colors.grey)),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: Supabase.instance.client.from('labour_data').select().eq('profile_id', data['id']),
                builder: (context, snapshot) {
                  final labour = snapshot.data ?? [];
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  return ListView(
                    children: [
                      Text("Availability Details", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (labour.isEmpty) Text("No specific labour field data found", style: GoogleFonts.outfit(color: Colors.grey)),
                      ...labour.map((l) => Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[100]!)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l['labour_field_type'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(l['availability_date'], style: GoogleFonts.outfit(color: const Color(0xFF1B5E20), fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                if (l['price_per_hour'] != null) _priceLabel("Hr", l['price_per_hour']),
                                if (l['price_per_day'] != null) _priceLabel("Day", l['price_per_day']),
                                if (l['price_per_load'] != null) _priceLabel("Load", l['price_per_load']),
                              ],
                            ),
                          ],
                        ),
                      )),
                    ],
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                label: const Text("Close"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceLabel(String type, dynamic price) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
          Text("₹$price", style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
