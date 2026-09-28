import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/mascot_chat_screen.dart';

class MascotFab extends StatelessWidget {
  const MascotFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'mascot_fab',
      backgroundColor: Colors.white,
      elevation: 4,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MascotChatScreen()),
        );
      },
      child: ClipOval(
        child: Image.network(
          '${ApiService.baseUrl}/mascot/image',
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Icon(Icons.pets, color: Colors.orange.shade400),
        ),
      ),
    );
  }
}