import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReportScreen extends StatelessWidget {
  final String videoId;
  const ReportScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar video'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Por qué reportas este video?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _buildReasonTile(context, 'Pornografía', reasonController),
                  _buildReasonTile(context, 'Violencia', reasonController),
                  _buildReasonTile(
                      context, 'Contenido ofensivo', reasonController),
                  _buildReasonTile(context, 'Spam', reasonController),
                  _buildReasonTile(context, 'Otro', reasonController),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Especifica el motivo (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Por favor ingresa un motivo')),
                  );
                  return;
                }

                try {
                  await ApiService.reportVideo(
                      videoId, reasonController.text.trim());
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Reporte enviado. Gracias por tu ayuda.')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error al enviar reporte: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Enviar reporte'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonTile(
      BuildContext context, String reason, TextEditingController controller) {
    return ListTile(
      title: Text(reason),
      leading: const Icon(Icons.flag),
      onTap: () {
        controller.text = reason;
        Navigator.pop(context);
      },
    );
  }
}
