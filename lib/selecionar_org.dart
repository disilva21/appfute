import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:appfute/cadastro/cadastro_org.dart';
import 'package:appfute/home.dart';
import 'package:google_fonts/google_fonts.dart';

class SelecionarTimePage extends StatelessWidget {
  final List<dynamic> orgIds;

  SelecionarTimePage({required this.orgIds});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[900],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Text("SELECIONE SEU TIME", style: GoogleFonts.bebasNeue(fontSize: 32, color: Colors.white)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: orgIds.length,
                itemBuilder: (context, index) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('organizacoes').doc(orgIds[index]).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      var org = snapshot.data!;

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: ListTile(
                          leading: Icon(Icons.sports_soccer, color: Colors.green),
                          title: Text(org['nome'], style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Jogo: ${org['dia_semana']}"),
                          onTap: () {
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage(orgId: org.id)));
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CadastroOrganizacaoPage())),
              child: Text("CRIAR NOVO GRUPO", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
