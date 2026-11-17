import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  // Controladores para o utilizador escrever a origem e o destino
  final TextEditingController origemController = TextEditingController(text: 'Lisboa');
  final TextEditingController destinoController = TextEditingController(text: 'Porto');

  // Coordenadas padrão (exemplo: Lisboa -> Porto)
  // No futuro podes usar um serviço de Geocoding, mas para já podes testar com estas ou coordenadas dinâmicas
  LatLng origemCoords = const LatLng(38.7223, -9.1393);
  LatLng destinoCoords = const LatLng(41.1579, -8.6291);

  List<LatLng> routePoints = [];
  double? distanciaKm;
  double? duracaoMin;
  bool aCarregar = false;

  // Função que chama o OSRM com base no que o utilizador quer
  Future<void> procurarNavegacaoOSRM() async {
    setState(() {
      aCarregar = true;
    });

    // Aqui podes ajustar as coordenadas conforme os inputs se quiseres ligar a cidades reais
    // Por enquanto, usamos o endpoint do OSRM para calcular entre os pontos definidos
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${origemCoords.longitude},${origemCoords.latitude};${destinoCoords.longitude},${destinoCoords.latitude}?overview=full&geometries=geojson'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Verifica se o OSRM encontrou rotas
        if ((data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          
          final distancia = route['distance'] / 1000; // de metros para km
          final duracao = route['duration'] / 60; // de segundos para minutos

          // Extrai os pontos reais da estrada devolvidos pelo OSRM
          final List coordinates = route['geometry']['coordinates'];
          final List<LatLng> pontosMapeados = coordinates.map((coord) {
            return LatLng(coord[1], coord[0]); // OSRM devolve [lon, lat], o Flutter Map quer [lat, lon]
          }).toList();

          setState(() {
            distanciaKm = distancia;
            duracaoMin = duracao;
            routePoints = pontosMapeados;
            aCarregar = false;
          });
        }
      } else {
        setState(() => aCarregar = false);
        _mostrarErro('Erro ao comunicar com o servidor de rotas.');
      }
    } catch (e) {
      setState(() => aCarregar = false);
      _mostrarErro('Erro de ligação: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  // Função para guardar esta viagem específica no Histórico do Supabase
  Future<void> guardarViagemNoHistorico() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _mostrarErro('Tens de ter sessão iniciada para guardar o histórico!');
      return;
    }

    try {
      await Supabase.instance.client.from('viagens').insert({
        'user_id': user.id,
        'origem': origemController.text,
        'destino': destinoController.text,
        'data_viagem': DateTime.now().toIso8601String().split('T')[0],
        'km': distanciaKm?.round() ?? 0,
        'carga': 24.0, // Podes ligar a um input de peso da carga do camião se tiveres
        'peso_camiao': 40.0,
        'altura': 4.0,
        'largura': 2.5,
        'comprimento': 16.5,
        'estado': 'Concluída',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viagem guardada no histórico com sucesso! 🦾'), backgroundColor: Colors.green),
      );
    } catch (e) {
      _mostrarErro('Erro ao guardar na base de dados: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TruckWay - Navegação OSRM')),
      body: Column(
        children: [
          // Caixa de Inputs para o utilizador escrever a origem e o destino
          Container(
            padding: const EdgeInsets.all(12.0),
            color: Colors.grey[200],
            child: Column(
              children: [
                TextField(
                  controller: origemController,
                  decoration: const InputDecoration(
                    labelText: 'Origem',
                    prefixIcon: Icon(Icons.trip_origin),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: destinoController,
                  decoration: const InputDecoration(
                    labelText: 'Destino',
                    prefixIcon: Icon(Icons.location_on, color: Colors.red),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: aCarregar ? null : procurarNavegacaoOSRM,
                  icon: const Icon(Icons.search),
                  label: Text(aCarregar ? 'A calcular rota...' : 'Procurar Navegação'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(45),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Se já houver resultados da rota, mostra os detalhes e o botão de guardar
          if (distanciaKm != null)
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.blue[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Distância: ${distanciaKm!.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Tempo estimado: ${duracaoMin!.toStringAsFixed(0)} min'),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: guardarViagemNoHistorico,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),

          // O Mapa Real com o OpenStreetMap e a linha dinâmica do OSRM
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: origemCoords,
                initialZoom: 7.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.truckway',
                ),
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        color: Colors.blueAccent,
                        strokeWidth: 6.0,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}