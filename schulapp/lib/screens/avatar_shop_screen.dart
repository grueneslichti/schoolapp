import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AvatarShopScreen extends StatefulWidget {
  const AvatarShopScreen({super.key});

  @override
  State<AvatarShopScreen> createState() => _AvatarShopScreenState();
}

class _AvatarShopScreenState extends State<AvatarShopScreen> {
  List<Map<String, dynamic>> _shopItems = [];
  int _currentXp = 0;
  bool _isLoading = true;
  String _selectedCategory = 'all';
  final Map<String, String> _categoryLabels = {
    'all': 'Alle',
    'hat': '🧢 Hüte',
    'glasses': '👓 Brillen',
    'background': '🌈 Hintergründe',
    'frame': '🖼️ Rahmen',
    'sticker': '⭐ Sticker',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await ApiService().getShopItems();
    final xp = await ApiService().getMyXp();
    if (mounted) {
      setState(() {
        _shopItems = List<Map<String, dynamic>>.from(items);
        _currentXp = xp;
        _isLoading = false;
      });
    }
  }
  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedCategory == 'all') return _shopItems;
    return _shopItems.where((i) => i['item_type'] == _selectedCategory).toList();
  }
  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'common': return Colors.grey.shade600;
      case 'rare': return Colors.blue.shade700;
      case 'epic': return Colors.purple.shade700;
      default: return Colors.grey;
    }
  }
  String _getRarityLabel(String rarity) {
    switch (rarity) {
      case 'common': return 'Normal';
      case 'rare': return 'Selten';
      case 'epic': return 'Episch';
      default: return rarity;
    }
  }
  void _showBuyDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => _BuyItemDialog(
        item: item,
        currentXp: _currentXp,
        onPurchased: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatar-Shop'),
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text('$_currentXp XP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: _categoryLabels.entries.map((entry) {
                      final isSelected = _selectedCategory == entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: isSelected,
                          selectedColor: Colors.amber.shade600,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => setState(() => _selectedCategory = entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? const Center(child: Text('Keine Items in dieser Kategorie'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final rarityColor = _getRarityColor(item['rarity']);                   
                            return Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: rarityColor.withValues(alpha: 0.5), width: 2),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showBuyDialog(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item['icon'] ?? '❓',
                                        style: const TextStyle(fontSize: 48),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item['name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: rarityColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _getRarityLabel(item['rarity']),
                                          style: TextStyle(fontSize: 10, color: rarityColor, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${item['cost_xp']} XP',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _currentXp >= item['cost_xp'] ? Colors.green : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
class _BuyItemDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final int currentXp;
  final VoidCallback onPurchased;
  const _BuyItemDialog({
    required this.item,
    required this.currentXp,
    required this.onPurchased,
  });

  @override
  State<_BuyItemDialog> createState() => _BuyItemDialogState();
}
class _BuyItemDialogState extends State<_BuyItemDialog> {
  String? _selectedColor;
  bool _isBuying = false;

  @override
  void initState() {
    super.initState();
    final colors = List<String>.from(widget.item['available_colors'] ?? []);
    if (colors.isNotEmpty) _selectedColor = colors[0];
  }
  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
  Future<void> _buy() async {
    if (_selectedColor == null) return; 
    setState(() => _isBuying = true); 
    final result = await ApiService().buyShopItem(
      shopItemId: widget.item['id'],
      color: _selectedColor!,
    );  
    if (!mounted) return;
    setState(() => _isBuying = false); 
    if (result != null) {
      if (result['success'] == true) {
        widget.onPurchased();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = List<String>.from(widget.item['available_colors'] ?? []);
    final canAfford = widget.currentXp >= widget.item['cost_xp'];
    return AlertDialog(
      title: Row(
        children: [
          Text(widget.item['icon'] ?? '', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.item['name'])),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Text(
                '${widget.item['cost_xp']} XP',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: canAfford ? Colors.green : Colors.red,
                ),
              ),
              const Spacer(),
              Text(
                'Dein Guthaben: ${widget.currentXp} XP',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Farbe wählen:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colors.map((hex) {
              final isSelected = _selectedColor == hex;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _hexToColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey.shade300,
                      width: isSelected ? 4 : 2,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(color: _hexToColor(hex).withValues(alpha: 0.5), blurRadius: 8),
                    ],
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          if (!canAfford) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nicht genug XP! Verdiene mehr durch Bewertungen und Geschenke.',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        ElevatedButton.icon(
          onPressed: canAfford && !_isBuying ? _buy : null,
          icon: _isBuying
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.shopping_cart),
          label: Text('${widget.item['cost_xp']} XP ausgeben'),
          style: ElevatedButton.styleFrom(
            backgroundColor: canAfford ? Colors.amber.shade700 : Colors.grey,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}