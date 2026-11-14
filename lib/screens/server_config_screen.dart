import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/pocketbase_service.dart';
import 'login_screen.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final TextEditingController _ipController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Recupera la IP previamente guardada si existe, o coloca el segmento inicial de pruebas
    final savedIp = ApiService.instance.baseUrl;
    _ipController.text = savedIp.isNotEmpty ? savedIp : "http://192.168.1.";
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  /// Limpia y formatea la IP ingresada para asegurar que PocketBase la entienda
  String _sanitizeIp(String ip) {
    String formatted = ip.trim();
    if (formatted.isEmpty) return "";

    // Asegura el protocolo HTTP si no fue especificado por el usuario
    if (!formatted.startsWith("http://") && !formatted.startsWith("https://")) {
      formatted = "http://$formatted";
    }

    // Remueve barras diagonales residuales al final
    if (formatted.endsWith("/")) {
      formatted = formatted.substring(0, formatted.length - 1);
    }

    return formatted;
  }

  /// Inicia el proceso asíncrono de conexión con control defensivo de timeouts
  Future<void> _handleConnect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String sanitizedIp = _sanitizeIp(_ipController.text);

    try {
      debugPrint("📡 Intentando conectar al búnker en: $sanitizedIp");

      // Intentamos validar la conexión mediante el servicio de API con timeout estricto de 5 segundos
      final bool isConnected = await ApiService.instance
          .connectToServer(sanitizedIp)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException(
                "Tiempo de respuesta del búnker agotado (Timeout de 5s).",
              );
            },
          );

      if (isConnected) {
        // Inicializamos de forma segura el servicio cliente de PocketBase
        final pbService = PocketBaseService();
        await pbService.refreshAuth();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Text("¡Búnker Conectado Exitosamente! ⚡"),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );

          // Transición suave hacia la pantalla de Login sin retorno
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage =
              "El servidor no respondió. Verifica que PocketBase esté encendido en tu PC.";
        });
      }
    } on TimeoutException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage =
            "Error de red: Asegúrate de estar conectado al mismo Wi-Fi de tu PC.";
      });
      debugPrint("❌ Error de conexión en pantalla: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF121212,
      ), // Fondo oscuro premium para cuidar la pantalla del ZTE
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 28.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icono animado/visual del servidor
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent.withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.settings_input_antenna_rounded,
                      size: 72,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Título principal
                  const Text(
                    "Conexión al Búnker",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Ingresa la IP local de tu computadora para enlazar los sistemas distribuidos de VideitosApp.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Campo de texto para la IP
                  TextFormField(
                    controller: _ipController,
                    enabled: !_isLoading,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleConnect(),
                    decoration: InputDecoration(
                      labelText: "IP de tu PC (Búnker)",
                      labelStyle: const TextStyle(color: Colors.grey),
                      hintText: "http://192.168.1.15:8090",
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(
                        Icons.lan_rounded,
                        color: Colors.blueAccent,
                      ),
                      suffixIcon: _ipController.text.isNotEmpty && !_isLoading
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () =>
                                  setState(() => _ipController.clear()),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.blueAccent,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "La dirección IP es obligatoria";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Visualización dinámica de errores
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Botón de conexión
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleConnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.blueAccent.withOpacity(
                        0.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: Colors.blueAccent.withOpacity(0.3),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            "Establecer Conexión",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
