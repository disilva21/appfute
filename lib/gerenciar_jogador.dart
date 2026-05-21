import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GerenciarJogadoresPage extends StatefulWidget {
  final String orgId;
  const GerenciarJogadoresPage({super.key, required this.orgId});

  @override
  State<GerenciarJogadoresPage> createState() => _GerenciarJogadoresPageState();
}

class _GerenciarJogadoresPageState extends State<GerenciarJogadoresPage> {
  void _excluirJogadorDaOrganizacao(String docId, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("REMOVER DA EQUIPE", style: GoogleFonts.bebasNeue(color: Colors.yellow[700], fontSize: 24)),
        content: Text("Tem certeza que deseja remover $nome desta organização? O perfil global do atleta não será afetado.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                // 1. Buscamos o documento para pegar o UID do jogador
                var docSnapshot = await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('jogadores').doc(docId).get();

                if (docSnapshot.exists) {
                  String? uidJogador = docSnapshot.data()?['uid'];

                  // 2. Removemos o ID desta organização do array no users_lookup
                  if (uidJogador != null) {
                    await FirebaseFirestore.instance
                        .collection('users_lookup')
                        .doc(uidJogador) // Ou o email, dependendo do seu ID de lookup
                        .update({
                          'organizacoes': FieldValue.arrayRemove([widget.orgId]),
                        });
                  }

                  // 3. Deletamos o documento do jogador dentro da organização
                  await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('jogadores').doc(docId).delete();
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Atleta removido e vínculo encerrado.")));
                }
              } catch (e) {
                debugPrint("Erro: $e");
                // Se der erro de permissão aqui, verifique se o Admin tem
                // permissão de 'update' na collection users_lookup
              }
            },
            child: const Text(
              "REMOVER",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20), // Fundo Verde
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        title: Text("GERENCIAR ATLETAS", style: GoogleFonts.bebasNeue(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('jogadores').orderBy('nome').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.yellow));

          final jogadores = snapshot.data!.docs;

          if (jogadores.isEmpty) {
            return Center(
              child: Text("NENHUM JOGADOR CADASTRADO", style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 20)),
            );
          }

          return ListView.builder(
            itemCount: jogadores.length,
            itemBuilder: (context, index) {
              var jogador = jogadores[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32), // Verde mais claro para o card
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.yellow[700],
                    child: const Icon(Icons.person, color: Colors.black),
                  ),
                  title: Text(jogador['nome'].toString().toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18)),
                  subtitle: Text(jogador['posicao'] ?? 'Sem posição', style: const TextStyle(color: Colors.white60)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    onPressed: () => _excluirJogadorDaOrganizacao(jogador.id, jogador['nome']),
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
