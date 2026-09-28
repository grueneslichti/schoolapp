import 'package:flutter/material.dart';
import '../../services/button_config_service.dart';

class ButtonEditorScreen extends StatefulWidget {
  final bool isTeacher;

  const ButtonEditorScreen({super.key, required this.isTeacher});

  @override
  State<ButtonEditorScreen> createState() => _ButtonEditorScreenState();
}
class _ButtonEditorScreenState extends State<ButtonEditorScreen> {
  List<ButtonConfig> _configs = [];
  bool _isLoading = true;
  final List<Color> _availableColors = [
    Colors.orange.shade400,
    Colors.green.shade400,
    Colors.blue.shade400,
    Colors.purple.shade400,
    Colors.red.shade400,
    Colors.teal.shade400,
    Colors.amber.shade600,
    Colors.pink.shade400,
    Colors.grey.shade600,
    Colors.brown.shade400,
    Colors.cyan.shade600,
    Colors.deepPurple.shade600,
    Colors.indigo.shade400,
    Colors.lime.shade600,
    Colors.blueGrey.shade600,
  ];

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }
  Future<void> _loadConfigs() async {
    var config = await ButtonConfigService().loadConfig(isTeacher: widget.isTeacher);
    if (!config.any((c) => c.id == 'logout')) {
      config.add(ButtonConfig(
        id: 'logout',
        label: 'Abmelden',
        iconKey: 'logout',
        color: Colors.grey.shade700,
        isVisible: true,
      ));
    }
    if (!widget.isTeacher && !config.any((c) => c.id == 'feedback')) {
      config.add(ButtonConfig(
        id: 'feedback',
        label: 'Kummerkasten',
        iconKey: 'feedback',
        color: Colors.teal.shade600,
        isVisible: true,
      ));
    }
    await ButtonConfigService().saveConfig(config, isTeacher: widget.isTeacher);
    setState(() {
      _configs = config;
      _isLoading = false;
    });
    if (widget.isTeacher && !config.any((c) => c.id == 'invitation')) {
      config.add(ButtonConfig(
      id: 'invitation',
      label: 'Einladungen',
      iconKey: 'invitation',
      color: Colors.indigo.shade600,
      isVisible: true,
    ));
    if (widget.isTeacher && !config.any((c) => c.id == 'schedule_editor')) {
      config.add(ButtonConfig(
      id: 'schedule_editor',
      label: 'Stundenplan',
      iconKey: 'schedule_editor',
      color: Colors.teal.shade700,
      isVisible: true,
  ));
}
  }
}
  Future<void> _saveConfigs() async {
    await ButtonConfigService().saveConfig(_configs, isTeacher: widget.isTeacher);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Einstellungen gespeichert!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  void _moveUp(int index) {
    if (index > 0) {
      setState(() {
        final item = _configs.removeAt(index);
        _configs.insert(index - 1, item);
      });
      _saveConfigs();
    }
  }
  void _moveDown(int index) {
    if (index < _configs.length - 1) {
      setState(() {
        final item = _configs.removeAt(index);
        _configs.insert(index + 1, item);
      });
      _saveConfigs();
    }
  }
  void _showColorPicker(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBorderColor = isDark ? Colors.white : Colors.black;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
        title: Text(
          'Farbe für "${_configs[index].label}"',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _availableColors.map((color) {
            final isSelected = _configs[index].color.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () {
                setState(() {
                  _configs[index] = ButtonConfig(
                    id: _configs[index].id,
                    label: _configs[index].label,
                    iconKey: _configs[index].iconKey,
                    color: color,
                    isVisible: _configs[index].isVisible,
                  );
                });
                _saveConfigs();
                Navigator.pop(context);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? selectedBorderColor : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                    width: isSelected ? 4 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: _getContrastColor(color),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  Color _getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
  void _toggleVisibility(int index) {
    setState(() {
      _configs[index].isVisible = !_configs[index].isVisible;
    });
    _saveConfigs();
  }
  Future<void> _resetToDefault() async {
    await ButtonConfigService().resetToDefault(isTeacher: widget.isTeacher);
    setState(() {
      _configs = widget.isTeacher
          ? ButtonConfigService().getDefaultTeacherConfig()
          : ButtonConfigService().getDefaultStudentConfig();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auf Standard zurückgesetzt'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTeacher ? 'Lehrer-Buttons anpassen' : 'Buttons anpassen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Zurücksetzen',
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _configs.length,
              itemBuilder: (context, index) {
                final config = _configs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  color: isDark ? Colors.grey.shade800 : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: config.color,
                      child: Icon(
                        ButtonConfigService().getIcon(config.iconKey),
                        color: _getContrastColor(config.color),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      config.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: config.isVisible
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.grey,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.isVisible ? 'Sichtbar' : 'Ausgeblendet',
                          style: TextStyle(
                            color: config.isVisible ? Colors.green : Colors.grey,
                          ),
                        ),
                        if (config.id == 'settings')
                          Text(
                            '🔒 Immer sichtbar (geschützt)',
                            style: TextStyle(
                              color: Colors.blue.shade300,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            config.isVisible ? Icons.visibility : Icons.visibility_off,
                            color: config.id == 'settings'
                                ? Colors.blue.shade300
                                : (config.isVisible ? Colors.green : Colors.grey),
                          ),
                          onPressed: config.id == 'settings'
                              ? null
                              : () => _toggleVisibility(index),
                          tooltip: config.id == 'settings'
                              ? 'Einstellungen können nicht ausgeblendet werden'
                              : (config.isVisible ? 'Ausblenden' : 'Einblenden'),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.palette,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          onPressed: () => _showColorPicker(index),
                          tooltip: 'Farbe ändern',
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_upward,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              onPressed: index > 0 ? () => _moveUp(index) : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Nach oben',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_downward,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              onPressed: index < _configs.length - 1 ? () => _moveDown(index) : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Nach unten',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}