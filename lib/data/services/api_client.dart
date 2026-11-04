import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';

/// Cliente HTTP que solo permite conexiones HTTPS/TLS (RNF2 - Seguridad) y
/// traduce cualquier fallo de red en un [NetworkException] con mensaje amable.
class ApiClient {
  ApiClient({http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Future<Map<String, dynamic>> getJson(Uri uri) async {
    if (uri.scheme != 'https') {
      throw const NetworkException('Solo se permiten conexiones seguras (HTTPS).');
    }
    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        throw NetworkException(
          'El servidor respondió con un error (${response.statusCode}).',
        );
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on TimeoutException catch (e) {
      throw NetworkException('La conexión tardó demasiado.', cause: e);
    } on SocketException catch (e) {
      throw NetworkException('Sin conexión a internet.', cause: e);
    } on HandshakeException catch (e) {
      throw NetworkException('No se pudo establecer una conexión segura.', cause: e);
    } on FormatException catch (e) {
      throw NetworkException('Respuesta inválida del servidor.', cause: e);
    } on http.ClientException catch (e) {
      throw NetworkException('No se pudo conectar con el servidor.', cause: e);
    }
  }

  void close() => _client.close();
}
