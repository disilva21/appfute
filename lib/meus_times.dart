import 'dart:io';

import 'package:appfute/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class MeusTimesPage extends StatelessWidget {
  final String orgIdAtual;
  const MeusTimesPage({super.key, required this.orgIdAtual});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20), // Seu Verde Gramado
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("MEUS TIMES", style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.white)),
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users_lookup').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.yellow));

          final dados = snapshot.data!.data() as Map<String, dynamic>?;
          final List<dynamic> idsTimes = dados?['organizacoes'] ?? [];

          if (idsTimes.isEmpty) {
            return Center(
              child: Text("VOCÊ NÃO ESTÁ EM NENHUM TIME", style: GoogleFonts.bebasNeue(color: Colors.white54)),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: idsTimes.length,
            itemBuilder: (context, index) {
              // AQUI CRIAMOS AS VARIÁVEIS PARA CADA ITEM DA LISTA
              String idTime = idsTimes[index];
              bool isAtual = idTime == orgIdAtual;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('organizacoes').doc(idTime).get(),
                builder: (context, orgSnap) {
                  if (!orgSnap.hasData) return const SizedBox();

                  String nomeTime = orgSnap.data!['nome'] ?? "Time sem nome";
                  String? urlEscudo = orgSnap.data!['urlEscudo'] ?? "";

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('organizacoes').doc(idTime).collection('jogadores').doc(user?.uid).get(),
                    builder: (context, statsSnap) {
                      int gols = 0;
                      String posicao = "Jogador";
                      if (statsSnap.hasData && statsSnap.data!.exists) {
                        gols = statsSnap.data!['gols_carreira'] ?? 0;
                        posicao = statsSnap.data!['posicao'] ?? "Jogador";
                      }

                      return Card(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: urlEscudo != null ? NetworkImage(urlEscudo) : null,
                            child: urlEscudo == null ? const Icon(Icons.shield, size: 50, color: Colors.grey) : null,
                          ),
                          title: Text(
                            nomeTime,
                            style: TextStyle(color: isAtual ? Colors.white : Colors.white54, fontWeight: isAtual ? FontWeight.bold : FontWeight.normal),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person, size: 12, color: isAtual ? Colors.yellow[700] : Colors.white38),
                                  const SizedBox(width: 4),
                                  Text(posicao, style: TextStyle(color: isAtual ? Colors.white70 : Colors.white38, fontSize: 12)),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.star, size: 12, color: Colors.yellow[700]),
                                  const SizedBox(width: 4),
                                  Text("$gols Gols", style: TextStyle(color: isAtual ? Colors.yellow[700] : Colors.white38, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.share, color: Colors.yellow[700], size: 20),
                            onPressed: () => _mostrarModalCompartilhar(context, nomeTime, idTime, urlEscudo),
                          ),
                          onTap: isAtual ? null : () => _alternarTime(context, idTime),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Função que dispara o compartilhamento nativo
  void _compartilharCodigo(BuildContext context, String codigo, String nomeTime, String? urlEscudo) async {
    // Texto bem estruturado que o destinatário vai receber
    final String mensagem =
        "⚽ *CONVITE APPFUTE* ⚽\n\n"
        "Você foi convidado para entrar no time *${nomeTime}*!\n\n"
        "👉 Código de Acesso: *${codigo}*\n\n"
        "Instale o app e junte-se ao elenco:\n"
        "🔗 Android: https://play.google.com/store/apps/details?id=com.ebeltec.appfute";
    // "🔗 iOS: https://apps.apple.com/br/app/appfute/id000000000";

    try {
      // Abre a janela nativa do sistema operacional
      if (urlEscudo != null && urlEscudo.isNotEmpty) {
        final response = await http.get(Uri.parse(urlEscudo));

        // Pega a pasta temporária do sistema operacional
        final directory = await getTemporaryDirectory();
        final pathDoArquivo = '${directory.path}/escudo_compartilhado.jpg';

        // Salva os bytes da imagem no arquivo temporário
        final arquivoTemporario = File(pathDoArquivo);
        await arquivoTemporario.writeAsBytes(response.bodyBytes);

        // 3. Compartilha o Arquivo + Texto juntos
        await Share.shareXFiles([XFile(pathDoArquivo)], text: mensagem, subject: 'Convite para o time ${nomeTime}');
      } else {
        // Se não houver escudo, compartilha apenas o texto de forma simples
        await Share.share(mensagem, subject: 'Convite para o time ${nomeTime}');
      }
    } catch (e) {
      print("Erro ao compartilhar: $e");
    }
  }

  // Lógica para trocar de organização sem deslogar
  void _alternarTime(BuildContext context, String novoOrgId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Atualiza a última acessada para que, ao abrir o app de novo, ele lembre desse time
    await FirebaseFirestore.instance.collection('users_lookup').doc(uid).update({'ultima_org_acessada': novoOrgId});

    if (context.mounted) {
      // Reinicia para o AuthWrapper reconfigurar a Home com o novo ID
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false);
    }
  }

  void _mostrarModalCompartilhar(BuildContext context, String nomeTime, String codigo, String? urlEscudo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              Text("Convidar para o Time", style: GoogleFonts.bebasNeue(fontSize: 25, color: Colors.white)),
              const SizedBox(height: 10),
              Text(
                "Compartilhe o código abaixo com seus amigos para eles entrarem no $nomeTime",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 30),

              // Container do Código
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.yellow[700]!, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      codigo,
                      style: GoogleFonts.sourceCodePro(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.yellow[700], letterSpacing: 5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Botão de fechar ou copiar (Opcional)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _compartilharCodigo(context, codigo, nomeTime, urlEscudo),
                  icon: const Icon(Icons.check, color: Colors.black),
                  label: const Text(
                    "CONVIDAR AMIGOS",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700], padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
