import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _offline = false;
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  late final AnimationController _ctrl;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
    // Check initial state
    Connectivity().checkConnectivity().then(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (offline == _offline) return;
    setState(() => _offline = offline);
    if (offline) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizeTransition(
          sizeFactor: _slide,
          axisAlignment: -1,
          child: Material(
            color: AppTheme.red,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Δεν υπάρχει σύνδεση στο internet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
