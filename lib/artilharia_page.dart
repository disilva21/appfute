import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ArtilhariaPage extends StatelessWidget {
  final String orgId;

  const ArtilhariaPage({super.key, required this.orgId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text("ARTILHARIA DO TIME", style: GoogleFonts.bebasNeue(letterSpacing: 1.5).copyWith(color: Colors.white)),
        backgroundColor: Colors.green[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // A MÁGICA ESTÁ AQUI: Query com ordenação (orderBy)
        stream: FirebaseFirestore.instance.collection('organizacoes').doc(orgId).collection('jogadores').orderBy('gols_carreira', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Nenhum gol registrado ainda.", style: TextStyle(color: Colors.white54)),
            );
          }

          final jogadores = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: jogadores.length,
            itemBuilder: (context, index) {
              var jogador = jogadores[index];
              int posicao = index + 1;

              // Estilo especial para os 3 primeiros (Pódio)
              Color corPosicao = Colors.white24;
              if (posicao == 1) corPosicao = Colors.yellow[700]!;
              if (posicao == 2) corPosicao = Colors.grey[400]!;
              if (posicao == 3) corPosicao = Colors.orange[800]!;

              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: corPosicao,
                    child: Text(
                      "$posicaoº",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    jogador['nome'].toString().toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(jogador['posicao'] ?? "Jogador", style: const TextStyle(color: Colors.white54)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("${jogador['gols_carreira']}", style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.yellow[700])),
                      const Text("GOLS", style: TextStyle(color: Colors.white, fontSize: 8)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
