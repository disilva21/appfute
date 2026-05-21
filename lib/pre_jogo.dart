import 'package:appfute/placar_fixo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PreJogoPage extends StatefulWidget {
  final String orgIdA;
  final String nomeA;
  final String orgIdB;
  final String nomeB;

  const PreJogoPage({super.key, required this.orgIdA, required this.nomeA, required this.orgIdB, required this.nomeB});

  @override
  State<PreJogoPage> createState() => _PreJogoPageState();
}

class _PreJogoPageState extends State<PreJogoPage> {
  bool carregando = false;

  // Função mestre que une os dados e cria a partida
  Future<void> _confirmarEComecar() async {
    setState(() => carregando = true);

    try {
      // Função auxiliar para buscar com fallback
      Future<List<Map<String, dynamic>>> buscarAtletas(String orgId) async {
        // 1. Tenta buscar em presencas
        var snap = await FirebaseFirestore.instance.collection('organizacoes').doc(orgId).collection('presencas').get();

        // 2. Se estiver vazio, busca na subcoleção jogadores
        if (snap.docs.isEmpty) {
          print("Presenças vazias para $orgId, buscando em jogadores...");
          snap = await FirebaseFirestore.instance.collection('organizacoes').doc(orgId).collection('jogadores').get();
        }

        // Mapeia os dados garantindo que campos essenciais existam
        return snap.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          return {'uid': data['uid'] ?? doc.id, 'nome': data['nome'] ?? 'Jogador s/ Nome', 'posicao': data['posicao'] ?? 'N/A'};
        }).toList();
      }

      // Executa a busca para ambos os times
      List<Map<String, dynamic>> jogadoresA = await buscarAtletas(widget.orgIdA);
      List<Map<String, dynamic>> jogadoresB = await buscarAtletas(widget.orgIdB);

      // Validação mínima: se nem na lista de jogadores houver ninguém
      if (jogadoresA.isEmpty) {
        jogadoresA = List.generate(11, (index) {
          return {'uid': 'ficticio_${index + 1}', 'nome': 'Atleta_${index + 1}', 'posicao': 'EXTERNO'};
        });
        // throw "Nenhum jogador encontrado em ambas as organizações.";
      }

      if (jogadoresB.isEmpty) {
        jogadoresB = List.generate(11, (index) {
          return {'uid': 'ficticio_${index + 1}', 'nome': 'Atleta_${index + 1}', 'posicao': 'EXTERNO'};
        });
        // throw "Nenhum jogador encontrado em ambas as organizações.";
      }

      // 3. Grava na collection 'partidas_ativas'
      DocumentReference partidaRef = await FirebaseFirestore.instance.collection('partidas_ativas').add({
        'orgId': widget.orgIdA,
        'orgId_adversaria': widget.orgIdB,
        'nome_time_a': widget.nomeA,
        'nome_time_b': widget.nomeB,
        'jogadores_time_a': jogadoresA,
        'jogadores_time_b': jogadoresB,
        'gols_azul': 0,
        'gols_vermelho': 0,
        'status': 'em_andamento',
        'tipo_jogo': 'fixo',
        'data_inicio': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlacarFixoPage(partidaId: partidaRef.id, orgId: widget.orgIdA),
          ),
        );
      }
    } catch (e) {
      print("ERRO AO INICIAR: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
    } finally {
      setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("CONFRONTO DIRETO", style: GoogleFonts.bebasNeue(color: Colors.white)),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // --- BOX DO CONFRONTO ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildEscudoConfirmacao(widget.nomeA, Icons.shield),
                Text("VS", style: GoogleFonts.bebasNeue(fontSize: 40, color: Colors.yellow[700])),
                _buildEscudoConfirmacao(widget.nomeB, Icons.shield_outlined),
              ],
            ),

            const SizedBox(height: 40),

            // --- AVISO DE SINCRONIZAÇÃO ---
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.sync, color: Colors.yellow[700]),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Text("Ao começar, o placar ficará disponível para os dois times em tempo real.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // --- BOTÃO COMEÇAR (AMARELO 700) ---
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: carregando ? null : _confirmarEComecar,
                child: carregando ? const CircularProgressIndicator(color: Colors.black) : Text("AUTORIZAR INÍCIO", style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.black)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEscudoConfirmacao(String nome, IconData icone) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.white10,
          child: Icon(icone, size: 40, color: Colors.yellow[700]),
        ),
        const SizedBox(height: 10),
        Text(nome.toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18)),
      ],
    );
  }
}
