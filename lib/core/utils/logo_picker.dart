import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'image_utils.dart';
import 'storage_utils.dart';

class LogoPicker extends StatefulWidget {
  final String? initialUrl;
  final void Function(File? file) onPicked;
  final double size;
  const LogoPicker({
    super.key,
    required this.initialUrl,
    required this.onPicked,
    this.size = 80,
  });

  @override
  State<LogoPicker> createState() => _LogoPickerState();
}

class _LogoPickerState extends State<LogoPicker> {
  File? _file;
  String? _error;

  Future<void> _pick() async {
    try {
      final f = await StorageUtils.pickImage();
      if (f == null) return;
      setState(() {
        _file = f;
        _error = null;
      });
      widget.onPicked(f);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    if (_file != null) {
      provider = FileImage(_file!);
    } else {
      provider = safeNetworkImage(widget.initialUrl);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pick,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: AppTheme.cardBg2,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.divider, width: 2),
              image: provider != null
                  ? DecorationImage(image: provider, fit: BoxFit.cover)
                  : null,
            ),
            child: provider == null
                ? const Center(
                    child: Icon(Icons.add_a_photo_outlined,
                        color: AppTheme.textSecondary, size: 28),
                  )
                : Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 14),
                    ),
                  ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!,
              style: const TextStyle(color: AppTheme.red, fontSize: 11)),
        ],
      ],
    );
  }
}
