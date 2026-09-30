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
import '../../teams/ui/teams_screen.dart' show kDefaultAssociations, kDefaultCompetitions;

String generateInviteCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

const kCountryToCode = <String, String>{
  'Greece': 'GR',
  'Germany': 'DE',
  'England': 'GB',
  'Spain': 'ES',
  'Italy': 'IT',
  'France': 'FR',
  'Netherlands': 'NL',
  'Portugal': 'PT',
  'Turkey': 'TR',
  'Cyprus': 'CY',
  'Belgium': 'BE',
  'Austria': 'AT',
  'Switzerland': 'CH',
  'Poland': 'PL',
  'Romania': 'RO',
  'Serbia': 'RS',
  'Croatia': 'HR',
  'Ukraine': 'UA',
  'Sweden': 'SE',
  'Norway': 'NO',
  'Denmark': 'DK',
  'Czech Republic': 'CZ',
  'Slovakia': 'SK',
  'Hungary': 'HU',
  'Bulgaria': 'BG',
  'Albania': 'AL',
  'Kosovo': 'XK',
  'North Macedonia': 'MK',
  'Slovenia': 'SI',
  'Bosnia': 'BA',
  'Montenegro': 'ME',
};

const kCountryList = [
  'Greece', 'Germany', 'England', 'Spain', 'Italy', 'France', 'Portugal',
  'Netherlands', 'Belgium', 'Austria', 'Switzerland', 'Poland', 'Romania',
  'Serbia', 'Croatia', 'Turkey', 'Ukraine', 'Sweden', 'Norway', 'Denmark',
  'Czech Republic', 'Slovakia', 'Hungary', 'Bulgaria', 'Albania', 'Kosovo',
  'North Macedonia', 'Slovenia', 'Bosnia', 'Montenegro', 'Cyprus',
];

const kLeaguesByCountry = <String, List<String>>{
  'Greece': ["Α' Κατηγορία", "Β'1 Κατηγορία", "Β'2 Κατηγορία", "Γ'1 Κατηγορία", "Γ'2 Κατηγορία", 'Τοπικό', 'Other'],
  'Germany': ['Kreisliga A', 'Kreisliga B', 'Kreisliga C', 'Bezirksliga', 'Landesliga', 'Verbandsliga', 'Other'],
  'England': ['Step 7', 'Step 6', 'Step 5', 'Step 4', 'Step 3', 'County League', 'Other'],
  'Spain': ['Tercera Federación', 'Regional Preferente', 'Primera Regional', 'Segunda Regional', 'Other'],
  'Italy': ['Eccellenza', 'Promozione', 'Prima Categoria', 'Seconda Categoria', 'Terza Categoria', 'Other'],
  'France': ['Régional 1', 'Régional 2', 'Régional 3', 'Départemental 1', 'Départemental 2', 'Other'],
  'Netherlands': ['Hoofdklasse', 'Eerste Klasse', 'Tweede Klasse', 'Derde Klasse', 'Vierde Klasse', 'Other'],
  'Portugal': ['Campeonato de Portugal', 'Divisão de Honra', 'Primeira Divisão', 'Segunda Divisão', 'Other'],
  'Turkey': ['TFF 3. Lig', 'Bölgesel Amatör Lig', 'İl Amatör Ligi 1', 'İl Amatör Ligi 2', 'Other'],
  'Cyprus': ["Α' Κατηγορία", "Β' Κατηγορία", "Γ' Κατηγορία", 'Επαρχιακό', 'Other'],
};

List<String> leaguesForCountry(String country) =>
    kLeaguesByCountry[country] ?? ['Division 1', 'Division 2', 'Division 3', 'Regional League', 'District League', 'Other'];

const kLeagues = ["Α' Κατηγορία", "Β'1 Κατηγορία", "Β'2 Κατηγορία", "Γ'1 Κατηγορία", "Γ'2 Κατηγορία", 'Division 1', 'Division 2', 'Regional League', 'Other'];

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

  String _country = kCountryList.first;
  String get _countryCode => kCountryToCode[_country] ?? '';
  List<Map<String, String>> get _associations => kDefaultAssociations[_countryCode] ?? [];
  bool get _hasAssociations => _associations.isNotEmpty;

  Map<String, String>? _selectedAssoc;
  List<Map<String, String>> get _competitions =>
      _selectedAssoc != null ? (kDefaultCompetitions[_selectedAssoc!['id']] ?? []) : [];
  bool get _hasCompetitions => _competitions.isNotEmpty;

  Map<String, String>? _selectedComp;
  String get _defaultLeague => leaguesForCountry(_country).first;
  late String _league = _defaultLeague;
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

  void _onCountryChanged(String country) {
    setState(() {
      _country = country;
      _selectedAssoc = null;
      _selectedComp = null;
      _league = leaguesForCountry(country).first;
    });
  }

  void _onAssocChanged(Map<String, String>? assoc) {
    setState(() {
      _selectedAssoc = assoc;
      _selectedComp = null;
    });
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final prov = context.read<AppProvider>();
      final user = prov.user!;

      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _country,
        'league': _selectedComp?['name'] ?? _league,
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
        if (_selectedAssoc != null) ...{
          'assocId': _selectedAssoc!['id'],
          'assocName': _selectedAssoc!['name'],
        },
        if (_selectedComp != null) ...{
          'competitionId': _selectedComp!['id'],
          'competitionName': _selectedComp!['name'],
        },
      };

      final ref = await FirebaseFirestore.instance.collection('clubs').add(data);

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
            content: Text('Η ομάδα δημιουργήθηκε επιτυχώς!'),
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
        title: const Text('Δημιουργία Ομάδας'),
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
                Text('Στοιχεία Ομάδας', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),

                // Logo
                Center(
                  child: LogoPicker(
                    initialUrl: null,
                    onPicked: (f) => setState(() => _logoFile = f),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Πάτα για να προσθέσεις λογότυπο ομάδας (προαιρετικό)',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),

                // Club name
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Όνομα Ομάδας',
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
                    labelText: 'Πόλη',
                    prefixIcon: Icon(Icons.location_city_outlined, color: AppTheme.textSecondary),
                  ),
                  validator: Validators.city,
                ),
                const SizedBox(height: 16),

                // Country
                _SectionLabel('Χώρα'),
                _DropdownField<String>(
                  value: _country,
                  items: kCountryList,
                  itemLabel: (c) => c,
                  onChanged: _onCountryChanged,
                ),
                const SizedBox(height: 16),

                // Association (ΕΠΣ) — only if available for country
                if (_hasAssociations) ...[
                  _SectionLabel('ΕΠΣ / Ομοσπονδία'),
                  _DropdownField<Map<String, String>?>(
                    value: _selectedAssoc,
                    items: [null, ..._associations],
                    itemLabel: (a) => a == null ? '— Δεν ανήκει σε ΕΠΣ —' : a['name']!,
                    onChanged: _onAssocChanged,
                  ),
                  const SizedBox(height: 16),
                ],

                // Competition — only if association selected and has competitions
                if (_selectedAssoc != null && _hasCompetitions) ...[
                  _SectionLabel('Κατηγορία Πρωταθλήματος'),
                  _DropdownField<Map<String, String>?>(
                    value: _selectedComp,
                    items: [null, ..._competitions],
                    itemLabel: (c) => c == null ? '— Επίλεξε κατηγορία —' : c['name']!,
                    onChanged: (c) => setState(() => _selectedComp = c),
                  ),
                  const SizedBox(height: 16),
                ],

                // Venue
                TextFormField(
                  controller: _venueCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Γήπεδο / Έδρα',
                    prefixIcon: Icon(Icons.stadium_outlined, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),

                // League — show only if no competition selected
                if (_selectedComp == null) ...[
                  _SectionLabel('Κατηγορία / Πρωτάθλημα'),
                  _DropdownField<String>(
                    value: _league,
                    items: leaguesForCountry(_country),
                    itemLabel: (l) => l,
                    onChanged: (v) => setState(() => _league = v),
                  ),
                  const SizedBox(height: 16),
                ],

                // Category
                _SectionLabel('Τμήμα'),
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
                    labelText: 'Περιγραφή / Ιστορία (προαιρετικό)',
                    alignLabelWithHint: true,
                  ),
                  validator: Validators.description,
                ),
                const SizedBox(height: 8),

                // Summary card
                if (_selectedAssoc != null || _selectedComp != null)
                  _SummaryCard(
                    assocName: _selectedAssoc?['name'],
                    compName: _selectedComp?['name'],
                  ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _create,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Δημιουργία Ομάδας'),
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
  );
}

class _DropdownField<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T) onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: AppTheme.cardBg,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        underline: const SizedBox(),
        items: items.map((item) => DropdownMenuItem<T>(
          value: item,
          child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: (v) { if (v != null || null is T) onChanged(v as T); },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String? assocName;
  final String? compName;
  const _SummaryCard({this.assocName, this.compName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A6FE8).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Κατηγοριοποίηση', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          if (assocName != null)
            Row(children: [
              const Icon(Icons.account_balance_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(assocName!, style: const TextStyle(color: Colors.white, fontSize: 13))),
            ]),
          if (compName != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.emoji_events_outlined, size: 14, color: AppTheme.primaryLight),
              const SizedBox(width: 6),
              Expanded(child: Text(compName!, style: const TextStyle(color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.w500))),
            ]),
          ],
        ],
      ),
    );
  }
}
