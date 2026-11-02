// Clubera's own icon set (design «2β»): filled shapes with the glossy green
// of the shield, drawn as SVG so they stay sharp at every size.
//
//   ClIconView(ClIcon.home)                 – the icon alone
//   ClIconView(ClIcon.home, muted: true)    – grey-blue, for inactive tabs
//   ClIconTile(ClIcon.players)              – on the raised navy tile

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum ClIcon { home, matches, clubs, profile, players, transfers, stadium, sponsors, vote, support, rewards, news }

const _defs = '<defs>'
    '<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#BBF7D0"/><stop offset="0.45" stop-color="#4ADE80"/><stop offset="1" stop-color="#15803D"/></linearGradient>'
    '<linearGradient id="w" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#B9C6EE"/></linearGradient>'
    '<linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8EA2FF"/><stop offset="1" stop-color="#4361EE"/></linearGradient>'
    '</defs>';

// G = green fill, W = white fill, B = blue fill, N = navy detail,
// H = highlight stroke. Muted icons replace them with flat colors.
const _body = <ClIcon, String>{
  ClIcon.home:
      '<path d="M2.8 11.2 L12 3.6 L21.2 11.2 L19.6 12.6 L19.6 20.4 L4.4 20.4 L4.4 12.6 Z" fill="G"/><path d="M10 20.4 V15.2 A2 2 0 0 1 14 15.2 V20.4 Z" fill="N"/><path d="M5.6 11.6 L12 6.4 L15 8.8" fill="none" stroke="H" stroke-opacity="0.7" stroke-width="1.1" stroke-linecap="round"/>',
  ClIcon.matches:
      '<circle cx="12" cy="12" r="9.4" fill="W"/><path d="M12 7.6 L15.6 10.2 L14.2 14.4 H9.8 L8.4 10.2 Z" fill="N"/><path d="M12 2.6 V7.6 M15.6 10.2 L21 9.2 M14.2 14.4 L17.2 19.4 M9.8 14.4 L6.8 19.4 M8.4 10.2 L3 9.2" stroke="N" stroke-width="1.3" stroke-linecap="round"/>',
  ClIcon.clubs:
      '<path d="M12 2.4 L20.6 5.6 V11.2 C20.6 16.4 16.8 20.2 12 21.8 C7.2 20.2 3.4 16.4 3.4 11.2 V5.6 Z" fill="W"/><path d="M12 4 L19 6.6 V11.2 C19 15.6 15.9 18.8 12 20.2 C8.1 18.8 5 15.6 5 11.2 V6.6 Z" fill="G"/><path d="M14.8 9.4 A3.6 3.6 0 1 0 14.8 14.6" fill="none" stroke="H" stroke-width="2.3" stroke-linecap="round"/>',
  ClIcon.profile:
      '<path d="M3.6 21 C4.4 16 8 14 12 14 C16 14 19.6 16 20.4 21 Z" fill="W"/><circle cx="12" cy="8" r="4.6" fill="G"/>',
  ClIcon.players:
      '<path d="M8 2.8 L3 6 L5.4 11 L7.8 10 V21.2 H16.2 V10 L18.6 11 L21 6 L16 2.8 C15 5.4 9 5.4 8 2.8 Z" fill="G"/><path d="M10.6 12.6 L12.2 11.6 V17.4" fill="none" stroke="H" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  ClIcon.transfers:
      '<path d="M3 6.6 H15.4 V3.4 L21 8 L15.4 12.6 V9.4 H3 Z" fill="W"/><path d="M21 14.6 H8.6 V11.4 L3 16 L8.6 20.6 V17.4 H21 Z" fill="G"/>',
  ClIcon.stadium:
      '<rect x="2" y="5" width="20" height="14" rx="2.4" fill="G"/><rect x="3.2" y="6.2" width="17.6" height="11.6" rx="1.4" fill="none" stroke="H" stroke-width="1.1"/><path d="M12 6.2 V17.8" stroke="H" stroke-width="1.1"/><circle cx="12" cy="12" r="2.6" fill="none" stroke="H" stroke-width="1.1"/>',
  ClIcon.sponsors:
      '<path d="M8.4 13 L6.6 21.6 L12 19 L17.4 21.6 L15.6 13 Z" fill="B"/><circle cx="12" cy="9" r="6.2" fill="G"/><path d="M12 6 L12.9 8 L15 8.2 L13.4 9.6 L13.9 11.7 L12 10.6 L10.1 11.7 L10.6 9.6 L9 8.2 L11.1 8 Z" fill="H"/>',
  ClIcon.vote:
      '<path d="M8.4 3 H15.6 V12.4 H8.4 Z" fill="G"/><path d="M10.2 7.6 L11.6 9 L14 6.4" fill="none" stroke="H" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/><path d="M3 11.6 H21 V20.6 A1.4 1.4 0 0 1 19.6 22 H4.4 A1.4 1.4 0 0 1 3 20.6 Z" fill="W"/><path d="M7.4 13.8 H16.6" stroke="N" stroke-width="1.6" stroke-linecap="round"/>',
  ClIcon.support:
      '<path d="M12 21 C4.6 15.8 2.4 12 2.4 8.6 A5 5 0 0 1 12 6.2 A5 5 0 0 1 21.6 8.6 C21.6 12 19.4 15.8 12 21 Z" fill="G"/><path d="M5.2 8.4 A2.6 2.6 0 0 1 8 5.8" fill="none" stroke="H" stroke-opacity="0.8" stroke-width="1.3" stroke-linecap="round"/>',
  ClIcon.rewards:
      '<path d="M8 5.6 H4.6 A3.2 3.2 0 0 0 8 10.6 M16 5.6 H19.4 A3.2 3.2 0 0 1 16 10.6" fill="none" stroke="W" stroke-width="1.6"/><path d="M7.4 3 H16.6 V9.4 A4.6 4.6 0 0 1 7.4 9.4 Z" fill="G"/><path d="M10.8 13.8 H13.2 V17 H10.8 Z" fill="W"/><path d="M7.6 17.4 H16.4 V21 H7.6 Z" fill="W"/>',
  ClIcon.news:
      '<rect x="3" y="3.6" width="18" height="16.8" rx="2.4" fill="W"/><path d="M3 6 A2.4 2.4 0 0 1 5.4 3.6 H18.6 A2.4 2.4 0 0 1 21 6 V8.6 H3 Z" fill="G"/><path d="M6.4 12 H17.6 M6.4 15 H17.6 M6.4 18 H12.6" stroke="N" stroke-width="1.4" stroke-linecap="round"/>',
};

String clIconSvg(ClIcon icon, {bool muted = false}) {
  var s = _body[icon]!;
  // Replace color tokens inside attributes only ("G", "W", ...).
  String col(String token) {
    if (muted) {
      return switch (token) {
        'N' => '#141D52',
        'H' => '#141D52',
        _ => '#AFBEE6',
      };
    }
    return switch (token) {
      'G' => 'url(#g)',
      'W' => 'url(#w)',
      'B' => 'url(#b)',
      'N' => '#141D52',
      _ => '#FFFFFF',
    };
  }

  s = s.replaceAllMapped(RegExp(r'(fill|stroke)="([GWBNH])"'), (m) => '${m[1]}="${col(m[2]!)}"');
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">${muted ? '' : _defs}$s</svg>';
}

class ClIconView extends StatelessWidget {
  final ClIcon icon;
  final double size;
  final bool muted;
  final String? semanticLabel;
  const ClIconView(this.icon, {super.key, this.size = 24, this.muted = false, this.semanticLabel});

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        clIconSvg(icon, muted: muted),
        width: size,
        height: size,
        semanticsLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      );
}

/// The icon on the raised navy tile with the soft green glow.
class ClIconTile extends StatelessWidget {
  final ClIcon icon;
  final double size;
  const ClIconTile(this.icon, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.3),
          gradient: const LinearGradient(
            begin: Alignment(-0.4, -1),
            end: Alignment(0.4, 1),
            colors: [Color(0xFF2D3E9A), Color(0xFF141D52), Color(0xFF0C1238)],
            stops: [0, 0.6, 1],
          ),
          border: Border.all(color: const Color(0x24FFFFFF)),
          boxShadow: const [
            BoxShadow(color: Color(0x73000000), blurRadius: 18, offset: Offset(0, 8)),
            BoxShadow(color: Color(0x2E4ADE80), blurRadius: 18),
          ],
        ),
        alignment: Alignment.center,
        child: ClIconView(icon, size: size * 0.54),
      );
}

/// Bottom-bar icon: glowing green pill when selected, grey-blue otherwise.
class ClNavIcon extends StatelessWidget {
  final ClIcon icon;
  final bool active;
  const ClNavIcon(this.icon, {super.key, this.active = false});

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ClIconView(icon, size: 24, muted: true),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x294ADE80),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x594ADE80), blurRadius: 16)],
      ),
      child: ClIconView(icon, size: 24),
    );
  }
}
