import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:appfute/boas_vindas.dart';
import 'package:appfute/cadastro/cadastro_org.dart';
import 'package:appfute/home.dart';
import 'package:appfute/login.dart';
import 'package:appfute/selecionar_org.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const AuthWrapper());
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arena App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        // Configuração opcional para manter o estilo visual
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // 1. Se NÃO estiver logado, vai para o Login
          if (!snapshot.hasData) {
            return LoginPage();
          }

          final user = snapshot.data!;

          // 2. Se ESTIVER logado, verifica se ele já tem um time
          return FutureBuilder<DocumentSnapshot>(
            key: ValueKey(user.uid),
            future: FirebaseFirestore.instance.collection('users_lookup').doc(snapshot.data!.uid).get(),
            builder: (context, lookupSnapshot) {
              if (lookupSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              if (lookupSnapshot.hasError || lookupSnapshot.data == null || !lookupSnapshot.data!.exists) {
                return const BoasVindasPage(); // <--- Manda para cá!
              }

              // Se o documento existe, pegamos a lista de organizações
              final data = lookupSnapshot.data!.data() as Map<String, dynamic>;
              final List orgs = data['organizacoes'] ?? [];
              final String? ultimaOrg = data['ultima_org_acessada'];
              // Se a lista de times estiver vazia por algum motivo
              if (orgs.isEmpty || ultimaOrg == null) {
                return const BoasVindasPage();
              }

              // Se tem time, vai para a Home
              return HomePage(orgId: data['ultima_org_acessada']);
            },
          );
        },
      ),
    );
  }

  verificarAcesso(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    var lookup = await FirebaseFirestore.instance.collection('users_lookup').doc(user.uid).get();

    if (!lookup.exists || (lookup['organizacoes'] as List).isEmpty) {
      // Não tem time? Vai criar um ou entrar em um.
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => CadastroOrganizacaoPage()));
    } else {
      List orgs = lookup['organizacoes'];
      if (orgs.length == 1) {
        // Só tem um time? Vai direto para a Home dele.
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage(orgId: orgs[0])));
      } else {
        // Tem vários? Deixa ele escolher.
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SelecionarTimePage(orgIds: orgs)));
      }
    }
  }
}
