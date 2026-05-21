import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlacarFixoPage extends StatefulWidget {
  final String partidaId;
  final String orgId;

  const PlacarFixoPage({super.key, required this.partidaId, required this.orgId});

  @override
  State<PlacarFixoPage> createState() => _PlacarFixoPageState();
}

class _PlacarFixoPageState extends State<PlacarFixoPage> {
  // Cores do Tema
  final Color verdeGramado = const Color(0xFF1B5E20);
  final Color verdeCard = const Color(0xFF2E7D32);
  final Color amareloAcao = const Color(0xFFFBC02D); // Amarelo [700]

  // Função para incrementar gols no Firebase
  void _registrarGol(bool isTimeA, String uidJogador, String orgIdAtual, String nomeJogador) async {
    final campoGol = isTimeA ? 'gols_azul' : 'gols_vermelho';

    // Atualiza o placar geral da partida
    await FirebaseFirestore.instance.collection('partidas_ativas').doc(widget.partidaId).update({campoGol: FieldValue.increment(1)});

    // Agora apontamos para o jogador dentro da subcoleção da organização
    await FirebaseFirestore.instance
        .collection('organizacoes')
        .doc(orgIdAtual) // ID da organização atual
        .collection('jogadores')
        .doc(uidJogador)
        .update({'gols_carreira': FieldValue.increment(1)});

    await FirebaseFirestore.instance.collection('jogadores').doc(uidJogador).update({'gols_carreira': FieldValue.increment(1)});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: verdeGramado,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("SÚMULA AO VIVO", style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.white)),
        centerTitle: true,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.redAccent),
            onPressed: () => _encerrarPartida(), // Sua lógica de encerrar
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('partidas_ativas').doc(widget.partidaId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var jogo = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              // --- CABEÇALHO DO PLACAR ---
              _buildPlacarHeader(jogo),

              const SizedBox(height: 10),

              // --- LISTA DE JOGADORES (CONTRONTO) ---
              Expanded(
                child: Row(
                  children: [
                    // TIME A (Sua Organização)
                    Expanded(
                      child: _buildColunaTime(nome: jogo['nome_time_a'] ?? "CASA", jogadores: List.from(jogo['jogadores_time_a'] ?? []), isTimeA: true, orgId: jogo['orgId'] ?? ''),
                    ),

                    // LINHA DIVISORA ESTILO CAMPO
                    Container(width: 2, color: Colors.white12, margin: const EdgeInsets.symmetric(vertical: 20)),

                    // TIME B (Adversário Fixo)
                    Expanded(
                      child: _buildColunaTime(nome: jogo['nome_time_b'] ?? "VISITANTE", jogadores: List.from(jogo['jogadores_time_b'] ?? []), isTimeA: false, orgId: jogo['orgId_adversaria'] ?? ''),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlacarHeader(Map<String, dynamic> jogo) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border(bottom: BorderSide(color: amareloAcao.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _scoreDisplay(jogo['gols_azul'].toString()),
          Text("VS", style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.white24)),
          _scoreDisplay(jogo['gols_vermelho'].toString()),
        ],
      ),
    );
  }

  Widget _scoreDisplay(String score) {
    return Text(
      score,
      style: GoogleFonts.bebasNeue(fontSize: 80, color: amareloAcao, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildColunaTime({required String nome, required List<dynamic> jogadores, required bool isTimeA, required String orgId}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            nome.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.bebasNeue(color: isTimeA ? Colors.blue[300] : Colors.red[300], fontSize: 18),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: jogadores.length,
            itemBuilder: (context, index) {
              var jogador = jogadores[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: verdeCard.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  dense: true,
                  title: Text(
                    jogador['nome'].toString().split(' ')[0], // Apenas primeiro nome
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  trailing: InkWell(
                    onTap: () => _registrarGol(isTimeA, jogador['uid'] ?? '', orgId, jogador['nome']),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: amareloAcao, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.black, size: 16),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _carregando = false;
  void _encerrarPartida() async {
    // 1. Pedir confirmação para evitar encerramento acidental
    bool confirmar =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text("FINALIZAR JOGO", style: GoogleFonts.bebasNeue(color: Colors.yellow[700])),
            content: const Text("Deseja apitar o fim de jogo e salvar os resultados?", style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("AINDA NÃO", style: TextStyle(color: Colors.white38)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "SIM, FINALIZAR",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmar) return;

    setState(() => _carregando = true); // Adicione um bool no State para feedback visual

    try {
      // 2. Buscar os dados atuais da partida ativa
      DocumentSnapshot partidaSnap = await FirebaseFirestore.instance.collection('partidas_ativas').doc(widget.partidaId).get();

      if (partidaSnap.exists) {
        // 1. Atualiza o status para sair da Home
        await FirebaseFirestore.instance.collection('partidas_ativas').doc(widget.partidaId).update({'status': 'finalizado', 'data_fim': FieldValue.serverTimestamp()});

        // 2. Limpa a lista de presença para o próximo jogo
        // (Opcional: Se você quiser que a galera tenha que confirmar de novo no próximo dia)
        var presencasA = await FirebaseFirestore.instance.collection('organizacoes').doc(partidaSnap['orgId']).collection('presencas').get();
        for (var doc in presencasA.docs) {
          await doc.reference.delete();
        }

        var presencasB = await FirebaseFirestore.instance.collection('organizacoes').doc(partidaSnap['orgId_adversaria']).collection('presencas').get();
        for (var doc in presencasB.docs) {
          await doc.reference.delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Partida finalizada!")));
          // Volta para a Home ou para a tela de resumo
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      debugPrint("Erro ao encerrar jogo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao finalizar partida."), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }
}
