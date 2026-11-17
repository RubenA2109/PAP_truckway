import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmService {
  // Exemplo: coordenadas de origem e destino (longitude, latitude)
  Future<Map<String, dynamic>> obterRota(LatLng origem, LatLng destino) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${origem.longitude},${origem.latitude};${destino.longitude},${destino.latitude}?overview=full&geometries=geojson'
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Retorna a distância (metros), duração (segundos) e os pontos para desenhar no mapa
      final route = data['routes'][0];
      return {
        'distancia_km': route['distance'] / 1000,
        'duracao_min': route['duration'] / 60,
        'geometria': route['geometry']['coordinates'], // Lista de pontos [lon, lat]
      };
    } else {
      throw Exception('Falha ao calcular a rota no OSRM');
    }
  }
}