import 'package:pocketbase/pocketbase.dart';

class ReportesService {
  final PocketBase pb;

  ReportesService(this.pb);

  // Función para crear el reporte en PocketBase
  Future<bool> crearReporte({
    required String videoId,
    required String motivo,
  }) async {
    try {
      // Obtenemos el ID del usuario que está logueado actualmente
      final usuarioId = pb.authStore.model?.id;

      if (usuarioId == null) {
        print("Error: No hay ningún usuario logueado.");
        return false;
      }

      // Hacemos el create en la colección que acabas de hacer en la web
      await pb.collection('Reportes').create(body: {
        'video_id': videoId,
        'motivo': motivo,
        'usuario_reportador':
            usuarioId, // El campo que acabamos de crear apuntando a users
      });

      return true; // Reporte creado con éxito
    } catch (e) {
      print("Error al crear el reporte en PocketBase: $e");
      return false;
    }
  }
}
