import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/logo_picker.dart';
import '../../../core/utils/storage_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../models/club_model.dart' show kCategories;

String generateInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

const kLeagues = [
  'Kreisliga A', 'Kreisliga B', 'Kreisliga C',
  'Bezirksliga', 'Landesliga', 'Verbandsliga',
  'Kreisklasse', 'Other',
];

const kCountryList = [
  'Greece', 'Germany', 'England', 'Spain', 'Italy', 'France', 'Portugal',
  'Netherlands', 'Belgium', 'Austria', 'Switzerland', 'Poland', 'Romania',
  'Serbia', 'Croatia', 'Turkey', 'Ukraine', 'Sweden', 'Norway', 'Denmark',
  'Czech Republic', 'Slovakia', 'Hungary', 'Bulgaria', 'Albania', 'Kosovo',
  'North Macedonia', 'Slovenia', 'Bosnia', 'Montenegro',
];

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  String _league = kLeagues.first;
  String _country = kCountryList.first;
  String _category = kCategories.first;
  bool _loading = false;
  File? _logoFile;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final prov = context.read<AppProvider>();
      final user = prov.user!;
      final ref = await FirebaseFirestore.instance.collection('clubs').add({
        'name': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _country,
        'league': _league,
        'category': _category,
        'description': _descCtrl.text.trim(),
        'venue': _venueCtrl.text.trim(),
        'adminUid': user.uid,
        'followers': 0,
        'votes': 0,
        'wins': 0,
        'draws': 0,
        'losses': 0,
        'goalsFor': 0,
        'goalsAgainst': 0,
        'logoUrl': null,
        'coverUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'inviteCode': generateInviteCode(),
        'staffUids': [],
      });

      String? logoUrl;
      if (_logoFile != null) {
        logoUrl = await StorageUtils.uploadClubLogo(_logoFile!, ref.id);
        await ref.update({'logoUrl': logoUrl});
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'clubId': ref.id,
      });

      prov.updateUser(user.copyWith(clubId: ref.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Club created successfully!'),
            backgroundColor: AppTheme.supportGreen,
          ),
        );
        Navigator.pop(context, ref.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Create Club'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Club Details', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),

              // Logo picker
              Center(
                child: LogoPicker(
                  initialUrl: null,
                  onPicked: (f) => setState(() => _logoFile = f),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Tap to add club logo (optional)',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Club name
              TextFormField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Club Name',
                  prefixIcon: Icon(Icons.shield_outlined, color: AppTheme.textSecondary),
                ),
                validator: Validators.clubName,
              ),
              const SizedBox(height: 16),

              // City
              TextFormField(
                controller: _cityCtrl,
                style: const TextStyle(color: Colors.white),
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city_outlined, color: AppTheme.textSecondary),
                ),
                validator: Validators.city,
              ),
              const SizedBox(height: 16),

              // Country
              const Text('Country', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppTheme.cardBg2, borderRadius: BorderRadius.circular(12)),
                child: DropdownButton<String>(
                  value: _country,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardBg,
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  items: kCountryList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _country = v!),
                ),
              ),
              const SizedBox(height: 16),

              // Venue
              TextFormField(
                controller: _venueCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Home Stadium / Venue',
                  prefixIcon: Icon(Icons.stadium_outlined, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),

              // League
              const Text('League', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppTheme.cardBg2, borderRadius: BorderRadius.circular(12)),
                child: DropdownButton<String>(
                  value: _league,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardBg,
                  style: const TextStyle(color: Colors.white),
                  underline: const SizedBox(),
                  items: kLeagues.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (v) => setState(() => _league = v!),
                ),
              ),
              const SizedBox(height: 16),

              // Category
              const Text('Category', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kCategories.map((cat) => ChoiceChip(
                  label: Text(cat),
                  selected: _category == cat,
                  selectedColor: AppTheme.primaryLight,
                  labelStyle: TextStyle(
                    color: _category == cat ? Colors.white : AppTheme.textSecondary,
                    fontWeight: _category == cat ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _category = cat),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description / History (optional)',
                  alignLabelWithHint: true,
                ),
                validator: Validators.description,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _create,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Club'),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
