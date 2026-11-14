import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager extends CacheManager {
  static const key = 'customCache';

  // Configuración personalizada
  static final CustomCacheManager _instance = CustomCacheManager._internal();

  factory CustomCacheManager() {
    return _instance;
  }

  CustomCacheManager._internal()
      : super(
          Config(
            key,
            stalePeriod: const Duration(
                days:
                    7), // Los archivos se consideran obsoletos después de 7 días
            maxNrOfCacheObjects: 100, // Número máximo de archivos en caché
            // 🔥 Tamaño máximo de la caché: 200 MB
            maxCacheSize: 200 * 1024 * 1024, // 200 MB
            // Repositorio de archivos
            fileService: HttpFileService(),
          ),
        );
}
