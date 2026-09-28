import 'dart:convert';
import 'package:flutter/material.dart';

class AvatarWithItems extends StatelessWidget {
  final String? avatarBase64;
  final List<Map<String, dynamic>> equippedItems;
  final double size;
  final VoidCallback? onTap;
  final bool showFrameIcon;
  const AvatarWithItems({
    super.key,
    required this.avatarBase64,
    required this.equippedItems,
    required this.size,
    this.onTap,
    this.showFrameIcon = true,
  });

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
  Map<String, dynamic>? get _activeFrame {
    final frames = equippedItems.where((i) => i['item_type'] == 'frame' && i['is_equipped'] == true).toList();
    return frames.isNotEmpty ? frames.first : null;
  }
  Map<String, dynamic>? get _activeBackground {
    final bgs = equippedItems.where((i) => i['item_type'] == 'background' && i['is_equipped'] == true).toList();
    return bgs.isNotEmpty ? bgs.first : null;
  }
  List<Map<String, dynamic>> get _movableItems {
    return equippedItems.where((i) {
      final type = i['item_type'] ?? '';
      return i['is_equipped'] == true && type != 'frame' && type != 'background';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _activeFrame;
    final background = _activeBackground;
    final movable = _movableItems;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size * 1.4,
        height: size * 1.4,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (background != null)
              Container(
                width: size * 1.3,
                height: size * 1.3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _hexToColor(background['color'] ?? '#FFD700').withValues(alpha: 0.5),
                      _hexToColor(background['color'] ?? '#FFD700').withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Center(
                  child: Opacity(
                    opacity: 0.3,
                    child: Text(
                      background['icon'] ?? '✨',
                      style: TextStyle(fontSize: size * 0.5),
                    ),
                  ),
                ),
              ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: frame != null
                      ? _hexToColor(frame['color'] ?? '#FFD700')
                      : Colors.blue.shade700,
                  width: frame != null ? size * 0.07 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                color: Colors.white,
              ),
              child: ClipOval(
                child: avatarBase64 != null
                    ? Image.memory(
                        base64Decode(avatarBase64!),
                        fit: BoxFit.cover,
                        width: size,
                        height: size,
                        errorBuilder: (ctx, err, stack) => Icon(
                          Icons.person,
                          size: size * 0.5,
                          color: Colors.grey,
                        ),
                      )
                    : Icon(Icons.person, size: size * 0.5, color: Colors.grey),
              ),
            ),
            if (frame != null && showFrameIcon)
              Positioned(
                top: size * 0.05,
                right: size * 0.05,
                child: Container(
                  padding: EdgeInsets.all(size * 0.04),
                  decoration: BoxDecoration(
                    color: _hexToColor(frame['color'] ?? '#FFD700'),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    frame['icon'] ?? '🖼️',
                    style: TextStyle(fontSize: size * 0.15),
                  ),
                ),
              ),
            ...movable.map((item) {
              final posX = (item['pos_x'] as num?)?.toDouble() ?? 0.5;
              final posY = (item['pos_y'] as num?)?.toDouble() ?? 0.3;
              final scale = (item['scale'] as num?)?.toDouble() ?? 1.0;
              final itemSize = size * 0.25 * scale;
              return Positioned(
                left: (posX * size * 1.4) - (itemSize / 2),
                top: (posY * size * 1.4) - (itemSize / 2),
                child: SizedBox(
                  width: itemSize,
                  height: itemSize,
                  child: Center(
                    child: Text(
                      item['icon'] ?? '❓',
                      style: TextStyle(fontSize: itemSize * 0.8),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}