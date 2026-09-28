import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:schulapp/services/api_service.dart';

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({super.key});

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _avatarData;
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _sdForgeAvailable = false;
  String? _selectedImageBase64;
  String? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }
  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService().getMyAvatar(),
      ApiService().getMyAvatarItems(),
      ApiService().checkSdForgeAvailable(),
    ]);  
    if (mounted) {
      setState(() {
        _avatarData = results[0] as Map<String, dynamic>?;
        _inventoryItems = List<Map<String, dynamic>>.from(results[1] as List);
        _sdForgeAvailable = results[2] as bool;
        _isLoading = false;
      });
    }
  }
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBase64 = base64Encode(bytes);
      });
    }
  }
  Future<void> _uploadAvatar({required bool applyAnime}) async {
    if (_selectedImageBase64 == null) return;
    setState(() => _isProcessing = true);
    final result = await ApiService().uploadAvatar(
      imageBase64: _selectedImageBase64!,
      applyAnimeStyle: applyAnime,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (result != null && !result.containsKey('error')) {
      setState(() {
        _avatarData = result;
        _selectedImageBase64 = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(applyAnime ? '✨ Anime-Avatar erstellt!' : '📷 Foto hochgeladen!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['error'] ?? 'Fehler'), backgroundColor: Colors.red),
      );
    }
  }
  Future<void> _regenerateAvatar() async {
    setState(() => _isProcessing = true);
    final result = await ApiService().regenerateAvatar();
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (result != null && !result.containsKey('error')) {
      setState(() => _avatarData = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Neuer Anime-Avatar generiert!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?['error'] ?? 'Fehler'), backgroundColor: Colors.red),
      );
    }
  }
  Future<void> _toggleEquip(Map<String, dynamic> item) async {
    final result = await ApiService().toggleEquipItem(item['id']);
    if (result != null) {
      await _loadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['is_equipped'] == true ? '✅ Item angelegt' : 'Item abgelegt'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
  Future<void> _updatePosition(String itemId, double posX, double posY, double scale) async {
    await ApiService().updateItemPosition(
      itemId: itemId,
      posX: posX,
      posY: posY,
      scale: scale,
    );
  }
  List<Map<String, dynamic>> _getEquippedOfType(String type) {
    return _inventoryItems.where((i) => i['item_type'] == type && i['is_equipped'] == true).toList();
  }
  List<Map<String, dynamic>> get _equippedMovableItems {
    return _inventoryItems.where((i) {
      final type = i['item_type'] ?? '';
      return i['is_equipped'] == true && type != 'frame' && type != 'background';
    }).toList();
  }
  Map<String, dynamic>? get _activeFrame {
    final frames = _getEquippedOfType('frame');
    return frames.isNotEmpty ? frames.first : null;
  }
  Map<String, dynamic>? get _activeBackground {
    final bgs = _getEquippedOfType('background');
    return bgs.isNotEmpty ? bgs.first : null;
  }
  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = MediaQuery.of(context).size.width * 0.6;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatar-Editor'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Vorschau',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        _buildAvatarPreview(avatarSize),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isProcessing)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('KI arbeitet...'),
                        ],
                      ),
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Neues Foto auswählen'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_selectedImageBase64 != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _uploadAvatar(applyAnime: false),
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Original'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_sdForgeAvailable)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _uploadAvatar(applyAnime: true),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Anime'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade600,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],

                    if (_avatarData != null && _avatarData!['has_original'] == true && _sdForgeAvailable && _selectedImageBase64 == null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _regenerateAvatar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Neuen Anime-Avatar generieren'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purple.shade700,
                            side: BorderSide(color: Colors.purple.shade300),
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Mein Inventar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tippe auf ein Item, um es anzulegen/abzulegen. Verschiebbare Items kannst du in der Vorschau bewegen.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  _inventoryItems.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Noch keine Items gekauft.\nBesuche den Avatar-Shop!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _inventoryItems.length,
                          itemBuilder: (context, index) {
                            final item = _inventoryItems[index];
                            final isEquipped = item['is_equipped'] == true;
                            final itemType = item['item_type'] ?? '';
                            final isFixed = itemType == 'frame' || itemType == 'background';
                            final isSelected = _selectedItemId == item['id'];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isEquipped ? 3 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? Colors.purple.shade400 : (isEquipped ? Colors.green.shade300 : Colors.transparent),
                                  width: 2,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _hexToColor(item['color'] ?? '#333333').withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(item['icon'] ?? '❓', style: const TextStyle(fontSize: 28)),
                                  ),
                                ),
                                title: Text(
                                  item['name'] ?? 'Unbekannt',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isEquipped ? Colors.green.shade800 : null,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(itemType),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: _hexToColor(item['color'] ?? '#333333'),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.grey),
                                      ),
                                    ),
                                    if (isFixed) ...[
                                      const SizedBox(width: 8),
                                      Chip(
                                        label: const Text('Fix', style: TextStyle(fontSize: 10)),
                                        backgroundColor: Colors.orange.shade50,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isEquipped)
                                      IconButton(
                                        icon: const Icon(Icons.check_circle),
                                        color: Colors.green,
                                        onPressed: () => _toggleEquip(item),
                                        tooltip: 'Ablegen',
                                      )
                                    else
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline),
                                        color: Colors.blue,
                                        onPressed: () => _toggleEquip(item),
                                        tooltip: 'Anlegen',
                                      ),
                                    if (!isFixed && isEquipped)
                                      IconButton(
                                        icon: const Icon(Icons.open_with),
                                        color: isSelected ? Colors.purple : Colors.grey,
                                        onPressed: () {
                                          setState(() {
                                            _selectedItemId = isSelected ? null : item['id'];
                                          });
                                        },
                                        tooltip: 'Verschieben',
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
  Widget _buildAvatarPreview(double avatarSize) {
    final frame = _activeFrame;
    final background = _activeBackground;
    final movableItems = _equippedMovableItems;
    final isSelectingItem = _selectedItemId != null;
    return GestureDetector(
      onPanUpdate: isSelectingItem
          ? (details) {
              final itemIndex = _inventoryItems.indexWhere((i) => i['id'] == _selectedItemId);
              if (itemIndex == -1) return;
              setState(() {
                final currentX = (_inventoryItems[itemIndex]['pos_x'] as num?)?.toDouble() ?? 0.5;
                final currentY = (_inventoryItems[itemIndex]['pos_y'] as num?)?.toDouble() ?? 0.3;
                final deltaX = details.delta.dx / avatarSize;
                final deltaY = details.delta.dy / avatarSize;
                _inventoryItems[itemIndex]['pos_x'] = (currentX + deltaX).clamp(0.0, 1.0);
                _inventoryItems[itemIndex]['pos_y'] = (currentY + deltaY).clamp(0.0, 1.0);
              });
            }
          : null,
      onPanEnd: isSelectingItem
          ? (details) async {
              if (_selectedItemId != null) {
                final item = _inventoryItems.firstWhere((i) => i['id'] == _selectedItemId);
                await _updatePosition(
                  _selectedItemId!,
                  (item['pos_x'] as num).toDouble(),
                  (item['pos_y'] as num).toDouble(),
                  (item['scale'] as num?)?.toDouble() ?? 1.0,
                );
                setState(() {
                  _selectedItemId = null;
                });
              }
            }
          : null,
      child: Container(
        width: avatarSize * 1.4,
        height: avatarSize * 1.4,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (background != null)
              Container(
                width: avatarSize * 1.3,
                height: avatarSize * 1.3,
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
                      style: TextStyle(fontSize: avatarSize * 0.5),
                    ),
                  ),
                ),
              ),
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: frame != null
                      ? _hexToColor(frame['color'] ?? '#FFD700')
                      : Colors.blue.shade700,
                  width: avatarSize * 0.07,
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
                child: _buildAvatarImage(avatarSize),
              ),
            ),
            ...movableItems.map((item) {
              final posX = (item['pos_x'] as num?)?.toDouble() ?? 0.5;
              final posY = (item['pos_y'] as num?)?.toDouble() ?? 0.3;
              final scale = (item['scale'] as num?)?.toDouble() ?? 1.0;
              final itemSize = avatarSize * 0.25 * scale;
              final isSelected = _selectedItemId == item['id'];
              return Positioned(
                left: (posX * avatarSize * 1.4) - (itemSize / 2),
                top: (posY * avatarSize * 1.4) - (itemSize / 2),
                child: Container(
                  width: itemSize,
                  height: itemSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(itemSize / 2),
                    border: isSelected
                        ? Border.all(color: Colors.purple, width: 3)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item['icon'] ?? '❓',
                    style: TextStyle(fontSize: itemSize * 0.8),
                  ),
                ),
              );
            }),
            if (isSelectingItem)
              Positioned(
                bottom: -30,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '↔️ Bewege das Item',
                    style: TextStyle(fontSize: 12, color: Colors.purple),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildAvatarImage(double size) {
    if (_selectedImageBase64 != null) {
      return Image.memory(
        base64Decode(_selectedImageBase64!),
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    }
    if (_avatarData != null && _avatarData!['image_base64'] != null) {
      return Image.memory(
        base64Decode(_avatarData!['image_base64']),
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (ctx, err, stack) => Icon(Icons.person, size: size * 0.5, color: Colors.grey),
      );
    }
    return Icon(Icons.person, size: size * 0.5, color: Colors.grey);
  }
}