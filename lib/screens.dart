import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kNavy = Color(0xFF0F1B2D);
const kOrange = Color(0xFFF97D1F);
const kBg = Color(0xFFF5F3EF);
const kRed = Color(0xFFE53935);

final _supabase = Supabase.instance.client;

String f(double v) => v.toString().replaceAll('.', ',');
String kg(num v) => v
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

// ---------- widgets partilhados ----------
class Header extends StatelessWidget {
  final String title;
  const Header(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: kNavy,
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Row(
              children: List.generate(
                  10,
                  (_) => Expanded(
                      child: Container(height: 4, margin: const EdgeInsets.only(right: 6), color: kOrange)))),
        ]),
      );
}

class Box extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? border;
  final EdgeInsets pad;
  const Box({super.key, required this.child, this.color = Colors.white, this.border, this.pad = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => Container(
        padding: pad,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: border == null ? null : Border.all(color: border!, width: 1.5),
        ),
        child: child,
      );
}

class OsmMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<LatLng> line;
  const OsmMap({super.key, required this.center, required this.zoom, this.line = const []});

  @override
  Widget build(BuildContext context) {
    final cameraFit = line.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(line),
            padding: const EdgeInsets.all(28),
          )
        : null;

    return FlutterMap(
      key: ValueKey('${line.length}_${center.latitude}_${center.longitude}'),
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        initialCameraFit: cameraFit,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'pt.truckway.app',
        ),
        if (line.isNotEmpty) ...[
          PolylineLayer(polylines: [Polyline(points: line, strokeWidth: 5, color: kOrange)]),
          MarkerLayer(markers: [
            Marker(
              point: line.first,
              width: 24,
              height: 24,
              child: const Icon(Icons.trip_origin, color: Colors.green, size: 20),
            ),
            Marker(
              point: line.last,
              width: 28,
              height: 28,
              child: const Icon(Icons.location_on, color: kRed, size: 26),
            ),
          ]),
        ],
      ],
    );
  }
}

// ---------- Mapa ----------
class MapaScreen extends StatelessWidget {
  final VoidCallback onPlan;
  const MapaScreen({super.key, required this.onPlan});
  @override
  Widget build(BuildContext context) => Stack(children: [
        const OsmMap(center: LatLng(38.9, -9.0), zoom: 9),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: onPlan,
              child: const Box(
                  pad: EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.search),
                    SizedBox(width: 10),
                    Text('Para onde vai hoje?', style: TextStyle(fontSize: 16)),
                  ])),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Box(
            color: kNavy,
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pronto para a estrada',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Planeie a próxima viagem', style: TextStyle(color: Colors.white70)),
              ])),
              FloatingActionButton.small(
                  onPressed: onPlan, backgroundColor: kOrange, child: const Icon(Icons.navigation, color: Colors.white)),
            ]),
          ),
        ),
      ]);
}

// ---------- Planear viagem ----------
class PlanearScreen extends StatefulWidget {
  const PlanearScreen({super.key});
  @override
  State<PlanearScreen> createState() => _PlanearScreenState();
}

class _PlanearScreenState extends State<PlanearScreen> {
  final _origem = TextEditingController(text: 'Lisboa');
  final _dest = TextEditingController(text: 'Madrid, Espanha');
  final _camiao = TextEditingController(text: '12000');
  final _carga = TextEditingController(text: '0');
  final _alt = TextEditingController(text: '4,3');
  final _larg = TextEditingController(text: '2,55');
  final _comp = TextEditingController(text: '16,5');

  double _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  void initState() {
    super.initState();
    App.reuse.addListener(_aplicar);
  }

  @override
  void dispose() {
    App.reuse.removeListener(_aplicar);
    super.dispose();
  }

  void _aplicar() {
    final v = App.reuse.value;
    if (v == null) return;
    setState(() {
      _origem.text = v.origem;
      _dest.text = v.destino;
      _camiao.text = g(v.camiao);
      _carga.text = g(v.carga);
      _alt.text = g(v.altura);
      _larg.text = g(v.largura);
      _comp.text = g(v.comp);
    });
    App.reuse.value = null;
  }

  Widget _campo(String label, TextEditingController c, String un) => Expanded(
        child: Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
            TextField(
              controller: c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              decoration: InputDecoration(border: InputBorder.none, isDense: true, suffixText: un),
            ),
          ]),
        ),
      );

  Widget _titulo(IconData i, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
        child: Row(children: [
          Icon(i, color: kOrange, size: 18),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final total = _n(_camiao) + _n(_carga);
    return Column(children: [
      const Header('Planear viagem'),
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Box(
            child: Column(children: [
              Row(children: [
                const Icon(Icons.circle, color: Colors.green, size: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _origem,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Origem (ex: Porto, Lisboa...)',
                    ),
                  ),
                ),
              ]),
              const Divider(height: 24),
              Row(children: [
                const Icon(Icons.location_on, color: kRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dest,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Destino',
                    ),
                  ),
                ),
              ]),
            ]),
          ),
          _titulo(Icons.scale, 'PESO'),
          Row(children: [_campo('Camião', _camiao, 'kg'), const SizedBox(width: 10), _campo('Carga (0 = vazio)', _carga, 'kg')]),
          _titulo(Icons.straighten, 'DIMENSÕES'),
          Row(children: [
            _campo('Altura', _alt, 'm'),
            const SizedBox(width: 10),
            _campo('Largura', _larg, 'm'),
            const SizedBox(width: 10),
            _campo('Compr.', _comp, 'm'),
          ]),
          const SizedBox(height: 16),
          Box(
            color: kNavy,
            child: Row(children: [
              const Icon(Icons.inventory_2_outlined, color: kOrange),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Peso total', style: TextStyle(color: Colors.white70)),
                Text('${kg(total)} kg', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                if (_origem.text.trim().isEmpty || _dest.text.trim().isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultadosScreen(
                      origem: _origem.text.trim(),
                      destino: _dest.text.trim(),
                      carga: _n(_carga),
                      total: total,
                      altura: _n(_alt),
                      largura: _n(_larg),
                      comp: _n(_comp),
                    ),
                  ),
                );
              },
              child: const Text('CALCULAR ROTAS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ---------- Ligação Real ao Supabase ----------
String g(double v) => v == v.roundToDouble() ? v.round().toString() : f(v);

class Viagem {
  final String? id;
  final String origem, destino, data;
  final int km;
  final double carga, camiao, altura, largura, comp;
  bool favorita;
  String? favoritoId;

  Viagem(
    this.origem,
    this.destino,
    this.data,
    this.km,
    this.carga, {
    this.id,
    this.camiao = 12000,
    this.altura = 4.3,
    this.largura = 2.55,
    this.comp = 16.5,
    this.favorita = false,
    this.favoritoId,
  });
}

class App {
  static final user = ValueNotifier<String?>(_supabase.auth.currentUser?.email);
  static String nome = _supabase.auth.currentUser?.userMetadata?['nome'] ??
      (_supabase.auth.currentUser?.email?.split('@').first ?? '');
  static final reuse = ValueNotifier<Viagem?>(null);
  static final tab = ValueNotifier<int>(0);
  static final viagens = ValueNotifier<List<Viagem>>([]);

  static String hojeIso() => DateTime.now().toIso8601String().split('T')[0];

  static String formatarDataPt(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }

  // Carrega perfil, viagens e favoritos da BD do utilizador atual
  static Future<void> carregarDadosBD() async {
    final u = _supabase.auth.currentUser;
    if (u == null) return;

    try {
      // 1. Buscar nome do perfil
      final prof = await _supabase.from('profiles').select('nome').eq('id', u.id).maybeSingle();
      if (prof != null && prof['nome'] != null) {
        nome = prof['nome'];
      }

      // 2. Buscar viagens e favoritos do utilizador
      final resViagens = await _supabase
          .from('viagens')
          .select()
          .eq('user_id', u.id)
          .order('created_at', ascending: false);

      final resFavs = await _supabase
          .from('favoritos')
          .select()
          .eq('user_id', u.id);

      final lista = <Viagem>[];
      for (final row in resViagens) {
        final favMatch = (resFavs as List).cast<Map<String, dynamic>>().where((f) => f['viagem_id'] == row['id']).toList();
        final isFav = favMatch.isNotEmpty;
        final favId = isFav ? favMatch.first['id'].toString() : null;

        final cargaVal = (row['carga'] as num?)?.toDouble() ?? 0;
        final totalVal = (row['peso_camiao'] as num?)?.toDouble() ?? 12000;
        final camiaoVal = (totalVal - cargaVal) > 0 ? (totalVal - cargaVal) : 12000.0;

        lista.add(Viagem(
          row['origem'] ?? '',
          row['destino'] ?? '',
          formatarDataPt(row['data_viagem'] ?? hojeIso()),
          (row['km'] as num?)?.toInt() ?? 0,
          cargaVal,
          id: row['id'].toString(),
          camiao: camiaoVal,
          altura: (row['altura'] as num?)?.toDouble() ?? 4.3,
          largura: (row['largura'] as num?)?.toDouble() ?? 2.55,
          comp: (row['comprimento'] as num?)?.toDouble() ?? 16.5,
          favorita: isFav,
          favoritoId: favId,
        ));
      }
      viagens.value = lista;
    } catch (e) {
      debugPrint('Erro ao carregar dados do Supabase: $e');
    }
  }

  // Guarda uma nova viagem na tabela `viagens`
  static Future<void> guardarViagemBD({
    required String origem,
    required String destino,
    required String dataIso,
    required int km,
    required double carga,
    required double camiao,
    required double altura,
    required double largura,
    required double comp,
  }) async {
    final u = _supabase.auth.currentUser;
    if (u == null) return;

    await _supabase.from('viagens').insert({
      'user_id': u.id,
      'origem': origem,
      'destino': destino,
      'data_viagem': dataIso,
      'km': km,
      'carga': carga,
      'peso_camiao': camiao + carga,
      'altura': altura,
      'largura': largura,
      'comprimento': comp,
      'estado': 'Concluída',
    });

    await carregarDadosBD();
  }

  // Alterna favorito na tabela `favoritos`
  static Future<void> toggleFavoritoBD(Viagem v) async {
    final u = _supabase.auth.currentUser;
    if (u == null || v.id == null) return;

    if (v.favorita && v.favoritoId != null) {
      await _supabase.from('favoritos').delete().eq('id', v.favoritoId!);
    } else {
      await _supabase.from('favoritos').insert({
        'user_id': u.id,
        'viagem_id': v.id,
        'origem': v.origem,
        'destino': v.destino,
      });
    }
    await carregarDadosBD();
  }

  // Apaga viagem da tabela `viagens`
  static Future<void> apagarViagemBD(Viagem v) async {
    if (v.id == null) return;
    await _supabase.from('viagens').delete().eq('id', v.id!);
    await carregarDadosBD();
  }
}

// ---------- Login / Registo (Visual renovado + Supabase Auth + login_historico) ----------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _registo = false;
  bool _aCarregar = false;
  bool _esconderPass = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Se já houver sessão ativa guardada pelo Supabase, carrega os dados
    if (_supabase.auth.currentUser != null) {
      App.carregarDadosBD();
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final email = _email.text.trim();
    final password = _pass.text;

    if (email.isEmpty || password.length < 6 || (_registo && _nome.text.trim().isEmpty)) {
      setState(() => _erro = 'Preencha tudo (password com 6 ou mais caracteres).');
      return;
    }

    setState(() {
      _aCarregar = true;
      _erro = null;
    });

    try {
      AuthResponse res;
      if (_registo) {
        res = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {'nome': _nome.text.trim()},
        );
      } else {
        res = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      final u = res.user;
      if (u != null) {
        // Regista o login no histórico de sessões
        await _supabase.from('login_historico').insert({
          'user_id': u.id,
          'dispositivo': 'TruckWay App',
        });

        App.nome = _registo ? _nome.text.trim() : (u.userMetadata?['nome'] ?? email.split('@').first);
        await App.carregarDadosBD();
        App.user.value = u.email;
      } else {
        setState(() => _erro = 'Verifique o seu email para confirmar o registo.');
      }
    } on AuthException catch (e) {
      setState(() => _erro = e.message);
    } catch (e) {
      setState(() => _erro = 'Erro de ligação ao Supabase: $e');
    } finally {
      if (mounted) setState(() => _aCarregar = false);
    }
  }

  Widget _f(String label, TextEditingController c, {bool pass = false, IconData? icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          obscureText: pass ? _esconderPass : false,
          keyboardType: pass ? TextInputType.visiblePassword : TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon != null ? Icon(icon, color: kNavy.withValues(alpha: 0.7)) : null,
            filled: true,
            fillColor: kBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kOrange, width: 2),
            ),
            suffixIcon: pass
                ? IconButton(
                    icon: Icon(_esconderPass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _esconderPass = !_esconderPass),
                  )
                : null,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fundo com degradê moderno em tons azul-marinho
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kNavy, Color(0xFF172A45), Color(0xFF09111E)],
                ),
              ),
            ),
            // Detalhe decorativo laranja no canto superior
            Positioned(
              top: -110,
              right: -110,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kOrange.withValues(alpha: 0.12),
                ),
              ),
            ),
            // Detalhe decorativo no canto inferior
            Positioned(
              bottom: -130,
              left: -90,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kOrange.withValues(alpha: 0.07),
                ),
              ),
            ),
            // Conteúdo centrado e responsivo (tipo plataforma/site)
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logótipo personalizado em destaque
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/logo.png',
                              width: 96,
                              height: 96,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                width: 96,
                                height: 96,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'TRUCKWAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Planeamento de rotas e gabaritos para pesados',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13.5),
                        ),
                        const SizedBox(height: 24),
                        // Cartão do formulário
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.30),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _registo ? 'Criar nova conta' : 'Iniciar sessão',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: kNavy,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (_registo) _f('Nome', _nome, icon: Icons.person_outline),
                              _f('Email', _email, icon: Icons.email_outlined),
                              _f('Password', _pass, pass: true, icon: Icons.lock_outline),
                              if (_erro != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    _erro!,
                                    style: const TextStyle(color: kRed, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kOrange,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _aCarregar ? null : _entrar,
                                  child: _aCarregar
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : Text(
                                          _registo ? 'CRIAR CONTA' : 'ENTRAR',
                                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: kOrange),
                                onPressed: () => setState(() {
                                  _registo = !_registo;
                                  _erro = null;
                                }),
                                child: Text(
                                  _registo ? 'Já tenho conta' : 'Criar conta nova',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

// ---------- Resultados com OSRM Real ----------
class Rota {
  final String nome, tempo, aviso;
  final int km;
  final double? maxAltura;
  final List<LatLng> linha;
  const Rota(this.nome, this.km, this.tempo, this.aviso, this.linha, {this.maxAltura});
}

class ResultadosScreen extends StatefulWidget {
  final String origem, destino;
  final double carga, total, altura, largura, comp;
  const ResultadosScreen({
    super.key,
    required this.origem,
    required this.destino,
    required this.carga,
    required this.total,
    required this.altura,
    required this.largura,
    required this.comp,
  });
  @override
  State<ResultadosScreen> createState() => _ResultadosState();
}

class _ResultadosState extends State<ResultadosScreen> {
  LatLng _origemCoords = const LatLng(38.7223, -9.1393);

  List<Rota> _rotas = [];
  bool _aCarregar = true;
  String? _erro;

  late double carga, camiao, altura, largura, comp;
  int sel = 0;

  @override
  void initState() {
    super.initState();
    carga = widget.carga;
    camiao = widget.total - widget.carga;
    altura = widget.altura;
    largura = widget.largura;
    comp = widget.comp;
    _calcularRotasOSRM();
  }

  String _formatarTempo(num segundos) {
    final totalMin = (segundos / 60).round();
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return h > 0 ? '$h h $m min' : '$m min';
  }

  Future<LatLng> _obterCoordenadas(String local, String tipo) async {
    final geoUrl = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(local)}&format=json&limit=1',
    );
    final geoRes = await http.get(geoUrl, headers: {'User-Agent': 'pt.truckway.app'});

    if (geoRes.statusCode != 200) {
      throw Exception('Falha ao pesquisar $tipo.');
    }

    final geoData = json.decode(geoRes.body) as List;
    if (geoData.isEmpty) {
      throw Exception('$tipo "$local" não encontrado no mapa.');
    }

    return LatLng(double.parse(geoData[0]['lat']), double.parse(geoData[0]['lon']));
  }

  Future<void> _calcularRotasOSRM() async {
    setState(() {
      _aCarregar = true;
      _erro = null;
    });

    try {
      final orig = await _obterCoordenadas(widget.origem, 'Origem');
      final dest = await _obterCoordenadas(widget.destino, 'Destino');
      _origemCoords = orig;

      final osrmUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${orig.longitude},${orig.latitude};${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson&alternatives=true&steps=true',
      );

      final osrmRes = await http.get(osrmUrl);
      if (osrmRes.statusCode != 200) {
        throw Exception('Erro ao calcular rota no OSRM.');
      }

      final osrmData = json.decode(osrmRes.body);
      final routesList = osrmData['routes'] as List;

      if (routesList.isEmpty) {
        throw Exception('Nenhuma estrada encontrada entre estes locais.');
      }

      final List<Rota> rotasCalculadas = [];

      for (int i = 0; i < routesList.length; i++) {
        final r = routesList[i];
        final km = ((r['distance'] as num) / 1000).round();
        final tempo = _formatarTempo(r['duration'] as num);

        final coords = r['geometry']['coordinates'] as List;
        final linha = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();

        String viaNome = i == 0 ? 'Rota Principal (Autoestrada)' : 'Alternativa ${i + 1}';
        final legs = r['legs'] as List;
        if (legs.isNotEmpty) {
          final steps = legs[0]['steps'] as List;
          final estradas = <String>{};
          for (final s in steps) {
            final ref = s['ref']?.toString();
            if (ref != null && ref.isNotEmpty) {
              estradas.add(ref.split(';').first.trim());
              if (estradas.length >= 2) break;
            }
          }
          if (estradas.isNotEmpty) {
            viaNome = 'VIA ${estradas.join(' / ')}';
          }
        }

        String aviso = i == 0
            ? 'Portagens para classe 4 · Via adequada a pesados'
            : (i == 1 ? 'Troço secundário com limite de altura 4,2 m' : 'Estrada nacional mais estreita');
        double? maxAlt = i == 1 ? 4.2 : null;

        rotasCalculadas.add(Rota(viaNome, km, tempo, aviso, linha, maxAltura: maxAlt));
      }

      setState(() {
        _rotas = rotasCalculadas;
        sel = _livre();
        _aCarregar = false;
      });
    } catch (e) {
      setState(() {
        _erro = e.toString().replaceAll('Exception: ', '');
        _aCarregar = false;
      });
    }
  }

  bool _bloq(Rota r) => r.maxAltura != null && altura > r.maxAltura!;
  int _livre() {
    final idx = _rotas.indexWhere((r) => !_bloq(r));
    return idx < 0 ? 0 : idx;
  }

  void _editar() {
    final cs = [camiao, carga, altura, largura, comp].map((v) => TextEditingController(text: g(v))).toList();
    const nomes = ['Peso do camião (kg)', 'Carga (kg)', 'Altura (m)', 'Largura (m)', 'Comprimento (m)'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: cs[i],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: nomes[i], border: const OutlineInputBorder(), isDense: true),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
              onPressed: () {
                double n(int i) => double.tryParse(cs[i].text.replaceAll(',', '.')) ?? 0;
                setState(() {
                  camiao = n(0);
                  carga = n(1);
                  altura = n(2);
                  largura = n(3);
                  comp = n(4);
                  sel = _livre();
                });
                Navigator.pop(ctx);
              },
              child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _aviso(String t, bool erro) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: erro ? Colors.red.shade50 : Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(erro ? Icons.block : Icons.warning_amber, size: 18, color: erro ? kRed : Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: TextStyle(fontSize: 13, color: erro ? kRed : Colors.brown.shade700))),
        ]),
      );

  Widget _card(int i, int rec) {
    final r = _rotas[i];
    final b = _bloq(r);
    final s = i == sel && !b;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: b ? null : () => setState(() => sel = i),
        child: Opacity(
          opacity: b ? 0.75 : 1,
          child: Box(
            border: b ? kRed : (s ? kOrange : null),
            pad: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(r.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                if (b) _tag('Bloqueada', kRed) else if (i == rec) _tag('Recomendada', kOrange),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.straighten, size: 16),
                Text(' ${r.km} km    '),
                const Icon(Icons.schedule, size: 16),
                Text(' ${r.tempo}'),
              ]),
              if (b) _aviso('Não passa: altura ${f(altura)} m acima do máximo ${f(r.maxAltura!)} m neste troço', true),
              _aviso(r.aviso, false),
              if (s)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
                      onPressed: () async {
                        // Grava a viagem diretamente na tabela `viagens` do Supabase
                        await App.guardarViagemBD(
                          origem: widget.origem,
                          destino: widget.destino,
                          dataIso: App.hojeIso(),
                          km: r.km,
                          carga: carga,
                          camiao: camiao,
                          altura: altura,
                          largura: largura,
                          comp: comp,
                        );
                        if (!context.mounted) return;
                        Navigator.push(context, MaterialPageRoute(builder: (_) => NavegacaoScreen(rota: r, destino: widget.destino)));
                      },
                      child: const Text('INICIAR NAVEGAÇÃO', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: Text('${widget.origem} → ${widget.destino}', maxLines: 2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ),
      body: _aCarregar
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: kOrange),
                SizedBox(height: 16),
                Text('A calcular rotas reais no OSRM...', style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
            )
          : _erro != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, color: kRed, size: 48),
                      const SizedBox(height: 12),
                      Text(_erro!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
                        onPressed: _calcularRotasOSRM,
                        child: const Text('TENTAR NOVAMENTE'),
                      ),
                    ]),
                  ),
                )
              : ListView(padding: const EdgeInsets.all(16), children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 200,
                      child: OsmMap(
                        center: _origemCoords,
                        zoom: 6.5,
                        line: _rotas[sel].linha,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    _chip('Carga ${kg(carga)} kg'),
                    _chip('Total ${kg(camiao + carga)} kg'),
                    _chip('Altura ${f(altura)} m'),
                    _chip('Largura ${f(largura)} m'),
                    _chip('Comp. ${f(comp)} m'),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: kOrange, side: const BorderSide(color: kOrange)),
                      onPressed: _editar,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Alterar'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _rotas.length; i++) _card(i, _livre()),
                ]),
    );
  }
}

// ---------- Navegacao ----------
class NavegacaoScreen extends StatefulWidget {
  final Rota rota;
  final String destino;
  const NavegacaoScreen({super.key, required this.rota, required this.destino});
  @override
  State<NavegacaoScreen> createState() => _NavState();
}

class _NavState extends State<NavegacaoScreen> {
  int _p = 0;
  List<String> get _passos => [
        'Siga pela ${widget.rota.nome}',
        'Continue durante ${widget.rota.km ~/ 2} km',
        'Atenção: ${widget.rota.aviso}',
        'Aproxime-se de ${widget.destino}',
        'Chegou ao destino',
      ];

  @override
  Widget build(BuildContext context) {
    final ultimo = _p >= _passos.length - 1;
    return Scaffold(
      body: Stack(children: [
        OsmMap(center: widget.rota.linha.first, zoom: 7, line: widget.rota.linha),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Box(
              color: kNavy,
              child: Row(children: [
                const Icon(Icons.turn_right, color: kOrange, size: 36),
                const SizedBox(width: 12),
                Expanded(child: Text(_passos[_p], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
              ]),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('TERMINAR', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kOrange, foregroundColor: Colors.white),
                  onPressed: () => ultimo ? Navigator.pop(context) : setState(() => _p++),
                  child: Text(ultimo ? 'CONCLUIR' : 'PRÓXIMA', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ---------- Historico (Sincronizado com Supabase) ----------
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});
  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  @override
  void initState() {
    super.initState();
    App.carregarDadosBD();
  }

  Widget _tf(TextEditingController c, String label, {bool num = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        ),
      );

  void _adicionar(BuildContext context) {
    final o = TextEditingController();
    final d = TextEditingController();
    final dt = TextEditingController(text: App.hojeIso());
    final k = TextEditingController();
    final c = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar viagem'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _tf(o, 'Origem'),
            _tf(d, 'Destino'),
            _tf(dt, 'Data (AAAA-MM-DD)'),
            _tf(k, 'Distância (km)', num: true),
            _tf(c, 'Carga (kg)', num: true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (o.text.trim().isEmpty || d.text.trim().isEmpty) return;
              await App.guardarViagemBD(
                origem: o.text.trim(),
                destino: d.text.trim(),
                dataIso: dt.text.trim().isEmpty ? App.hojeIso() : dt.text.trim(),
                km: int.tryParse(k.text) ?? 0,
                carga: double.tryParse(c.text.replaceAll(',', '.')) ?? 0,
                camiao: 12000,
                altura: 4.3,
                largura: 2.55,
                comp: 16.5,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, Viagem v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Box(
          pad: EdgeInsets.zero,
          child: ListTile(
            onTap: () {
              App.reuse.value = v;
              App.tab.value = 1;
            },
            leading: Icon(v.favorita ? Icons.star : Icons.location_on_outlined, color: kOrange),
            title: Text('${v.origem} → ${v.destino}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${v.data} · ${v.km} km · carga ${kg(v.carga)} kg'),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (op) async {
                if (op == 'fav') {
                  await App.toggleFavoritoBD(v);
                } else {
                  await App.apagarViagemBD(v);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'fav', child: Text(v.favorita ? 'Remover dos favoritos' : 'Favoritar')),
                const PopupMenuItem(value: 'del', child: Text('Retirar')),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(children: [
        const Header('Histórico'),
        Expanded(
          child: ValueListenableBuilder<List<Viagem>>(
            valueListenable: App.viagens,
            builder: (_, lista, __) {
              final ord = [...lista.where((v) => v.favorita), ...lista.where((v) => !v.favorita)];
              return ListView(padding: const EdgeInsets.all(16), children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: kOrange, side: const BorderSide(color: kOrange)),
                  onPressed: () => _adicionar(context),
                  icon: const Icon(Icons.add),
                  label: const Text('ADICIONAR VIAGEM'),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Toque numa viagem para a repetir.', style: TextStyle(color: Colors.black54)),
                ),
                if (ord.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: Text('Ainda não tem viagens registadas.', style: TextStyle(color: Colors.black54))),
                  ),
                for (final v in ord) _item(context, v),
              ]);
            },
          ),
        ),
      ]);
}

// ---------- Perfil ----------
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        const Header('Perfil'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            SizedBox(
              width: double.infinity,
              child: Box(
                pad: const EdgeInsets.all(24),
                child: Column(children: [
                  const CircleAvatar(radius: 40, backgroundColor: kNavy, child: Icon(Icons.person_outline, color: kOrange, size: 40)),
                  const SizedBox(height: 12),
                  Text(App.nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(App.user.value ?? '', style: const TextStyle(color: Colors.black54)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed, width: 1.5)),
                onPressed: () async {
                  await _supabase.auth.signOut();
                  App.viagens.value = [];
                  App.tab.value = 0;
                  App.user.value = null;
                },
                icon: const Icon(Icons.logout),
                label: const Text('TERMINAR SESSÃO', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
      ]);
}