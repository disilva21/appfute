import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlacarPage extends StatelessWidget {
  final String partidaId;
  const PlacarPage({super.key, required this.partidaId});

  void _registrarGol(String uidJogador, String campoTime, int golsAtuais) async {
    // Atualiza o placar coletivo e a artilharia individual
    await FirebaseFirestore.instance.collection('partidas_ativas').doc(partidaId).update({campoTime: golsAtuais + 1});

    await FirebaseFirestore.instance.collection('jogadores').doc(uidJogador).update({'gols_carreira': FieldValue.increment(1)});
  }

  void _finalizarJogo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("ENCERRAR PARTIDA?", style: GoogleFonts.bebasNeue()),
        content: const Text("O placar será salvo e o jogo sairá da tela principal."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              // 1. Atualiza o status para sair da Home
              await FirebaseFirestore.instance.collection('partidas_ativas').doc(partidaId).update({'status': 'finalizado'});

              // 2. Limpa a lista de presença para o próximo jogo
              // (Opcional: Se você quiser que a galera tenha que confirmar de novo no próximo dia)
              var presencas = await FirebaseFirestore.instance.collection('presencas').get();
              for (var doc in presencas.docs) {
                await doc.reference.delete();
              }

              Navigator.pop(context); // Fecha o alerta
              Navigator.pop(context); // Volta para a Home

              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Partida finalizada com sucesso!")));
            },
            child: const Text("FINALIZAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text("PLACAR AO VIVO", style: GoogleFonts.bebasNeue()),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () => _finalizarJogo(context),
            tooltip: "Finalizar Partida",
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('partidas_ativas').doc(partidaId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Text("Erro ao carregar dados", style: TextStyle(color: Colors.white)),
            );
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());

          // CONVERSÃO SEGURA PARA MAPA
          Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;

          // LÓGICA DEFENSIVA PARA OS CAMPOS
          // Se 'gols_total_azul' não existir, tenta 'gols_azul', se não for nenhum, assume 0.
          int golsAzul = data['gols_total_azul'] ?? data['gols_azul'] ?? 0;
          int golsVermelho = data['gols_total_vermelho'] ?? data['gols_vermelho'] ?? 0;

          List jogadoresAzul = data['jogadores_azul'] ?? [];
          List jogadoresVermelho = data['jogadores_vermelho'] ?? [];

          return Column(
            children: [
              // Placar Superior
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBoxPlacar("AZUL", golsAzul, Colors.blue),
                    Text("VS", style: GoogleFonts.bebasNeue(fontSize: 30, color: Colors.white24)),
                    _buildBoxPlacar("VERM", golsVermelho, Colors.red),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, thickness: 2),

              // Listas para marcar gols
              Expanded(
                child: Row(
                  children: [
                    _buildListaTime("TIME AZUL", jogadoresAzul, 'gols_total_azul', golsAzul),
                    const VerticalDivider(color: Colors.white10),
                    _buildListaTime("TIME VERMELHO", jogadoresVermelho, 'gols_total_vermelho', golsVermelho),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoxPlacar(String label, int gols, Color cor) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.bebasNeue(color: cor, fontSize: 20)),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(10)),
          child: Text(
            "$gols",
            style: TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // Função para diminuir gol (opcional mas recomendada)
  void _removerGol(String uidJogador, String campoTime, int golsAtuais) async {
    if (golsAtuais <= 0) return;

    await FirebaseFirestore.instance.collection('partidas_ativas').doc(partidaId).update({campoTime: golsAtuais - 1});

    await FirebaseFirestore.instance.collection('jogadores').doc(uidJogador).update({'gols_carreira': FieldValue.increment(-1)});
  }

  Widget _buildListaTime(String titulo, List jogadores, String campoFirestore, int golsAtuais) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(titulo, style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: jogadores.length,
              itemBuilder: (context, index) {
                var j = jogadores[index];
                return ListTile(
                  leading: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                    onPressed: () => _removerGol(j['uid'], campoFirestore, golsAtuais),
                  ),
                  title: Text(j['nome'].toString().toUpperCase(), style: TextStyle(color: Colors.white, fontSize: 11)),
                  trailing: Icon(Icons.add_circle, color: Colors.green, size: 20),
                  onTap: () => _registrarGol(j['uid'], campoFirestore, golsAtuais),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
