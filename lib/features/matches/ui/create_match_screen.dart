import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/club_model.dart';

class CreateMatchScreen extends StatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _venueCtrl = TextEditingController();
  ClubModel? _homeClub;
  ClubModel? _awayClub;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 15, minute: 0);
  bool _loading = false;
  List<ClubModel> _clubs = [];

  @override
  void initState() {
    super.initState();
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    final user = context.read<AppProvider>().user;
    final snap = await FirebaseFirestore.instance.collection('clubs').get();
    if (!mounted) return;
    final clubs = snap.docs.map((d) => ClubModel.fromMap(d.data(), d.id)).toList();
    setState(() {
      _clubs = clubs;
      if (user?.clubId != null) {
        _homeClub = clubs.where((c) => c.id == user!.clubId).firstOrNull;
      }
    });
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    if (_homeClub == null || _awayClub == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both clubs')),
      );
      return;
    }
    if (_homeClub!.id == _awayClub!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Home and away club must be different')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      await FirebaseFirestore.instance.collection('matches').add({
        'homeClubId': _homeClub!.id,
        'homeClubName': _homeClub!.name,
        'homeClubLogo': _homeClub!.logoUrl,
        'awayClubId': _awayClub!.id,
        'awayClubName': _awayClub!.name,
        'awayClubLogo': _awayClub!.logoUrl,
        'homeScore': 0,
        'awayScore': 0,
        'status': 'upcoming',
        'minute': null,
        'scheduledAt': Timestamp.fromDate(dt),
        'league': _homeClub!.league,
        'venue': _venueCtrl.text.trim().isEmpty ? _homeClub!.city : _venueCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match created!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
        title: const Text('Create Match'),
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
              _clubPicker('Home Club', _homeClub, (c) => setState(() => _homeClub = c)),
              const SizedBox(height: 12),
              const Center(child: Text('vs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              _clubPicker('Away Club', _awayClub, (c) => setState(() => _awayClub = c)),
              const SizedBox(height: 24),
              const Text('Date & Time', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('${_date.day}/${_date.month}/${_date.year}'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (ctx, child) => Theme(
                            data: ThemeData.dark(),
                            child: child!,
                          ),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(_time.format(context)),
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: _time,
                          builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
                        );
                        if (t != null) setState(() => _time = t);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _venueCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Venue (optional)',
                  prefixIcon: Icon(Icons.stadium_outlined, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _create,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Match'),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _clubPicker(String label, ClubModel? selected, ValueChanged<ClubModel> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.cardBg2, borderRadius: BorderRadius.circular(12)),
      child: DropdownButton<ClubModel>(
        value: selected,
        isExpanded: true,
        hint: Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        dropdownColor: AppTheme.cardBg,
        style: const TextStyle(color: Colors.white),
        underline: const SizedBox(),
        items: _clubs.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}
