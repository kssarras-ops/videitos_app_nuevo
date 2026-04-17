import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/pocketbase_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final pb = PocketBaseService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF00D4FF),
              child: Text(
                auth.userEmail?.substring(0, 1).toUpperCase() ?? 'U',
                style:
                    const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              auth.userEmail ?? 'Usuario',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              pb.isAuthenticated ? 'Cuenta verificada' : 'Sesión activa',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Estadísticas', style: TextStyle(fontSize: 18)),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Videos', '12'),
                        _buildStat('Seguidores', '45'),
                        _buildStat('Likes', '89'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Mis videos'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // TODO: navegar a pantalla de videos del usuario
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Reportes'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // TODO: navegar a pantalla de reportes
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
