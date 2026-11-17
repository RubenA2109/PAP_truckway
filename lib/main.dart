import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

await Supabase.initialize(
  url: 'https://wufviqxudwydfjqwhjei.supabase.co',
  publishableKey: 'sb_publishable_zjK4LmqG3Ce7PzlW9tfeJA_sHyNWqqJ',
);

  // Se o utilizador já tiver sessão iniciada, carrega os dados da BD antes de abrir a app
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser != null) {
    App.user.value = currentUser.email;
    App.nome = currentUser.userMetadata?['nome'] ??
        (currentUser.email?.split('@').first ?? '');
    await App.carregarDadosBD();
  }

  runApp(const TruckWayApp());
}

class TruckWayApp extends StatelessWidget {
  const TruckWayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TruckWay',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: kBg,
          colorScheme: ColorScheme.fromSeed(seedColor: kOrange, primary: kOrange),
        ),
        home: ValueListenableBuilder<String?>(
          valueListenable: App.user,
          builder: (_, u, __) => u == null ? const LoginScreen() : const Shell(),
        ),
      );
}

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: App.tab,
        builder: (_, i, __) => Scaffold(
          body: IndexedStack(index: i, children: [
            MapaScreen(onPlan: () => App.tab.value = 1),
            const PlanearScreen(),
            const HistoricoScreen(),
            const PerfilScreen(),
          ]),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: i,
            onTap: (v) => App.tab.value = v,
            type: BottomNavigationBarType.fixed,
            backgroundColor: kNavy,
            selectedItemColor: kOrange,
            unselectedItemColor: Colors.white54,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Mapa'),
              BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Viagem'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histórico'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
            ],
          ),
        ),
      );
}