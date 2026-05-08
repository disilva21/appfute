import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:appfute/login.dart';
import 'package:appfute/placar.dart';
import 'package:appfute/widgets/menu.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  final String orgId;
  const HomePage({super.key, required this.orgId});

  void _confirmarSaida(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("PEDIR DESFALQUE?", style: GoogleFonts.bebasNeue()),
        content: const Text("Tem certeza que não poderá comparecer à partida?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('presencas').doc(docId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você foi removido da lista.")));
            },
            child: const Text("SAIR DO JOGO", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Função para abrir a "Janela de Convocação"
  void _abrirJanelaConvocacao(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                SizedBox(height: 20),
                Text("CONFIRMAR PRESENÇA", style: GoogleFonts.bebasNeue(fontSize: 28, color: Colors.green[900])),
                SizedBox(height: 10),
                Text(
                  "A partida começa às 19h. Você vai pro jogo?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "DESFALQUE",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;

                            // 1. Verificar se o jogador já está na lista (pelo UID)
                            final checkPresenca = await FirebaseFirestore.instance.collection('presencas').where('uid', isEqualTo: user.uid).get();

                            if (checkPresenca.docs.isNotEmpty) {
                              // Se a lista não estiver vazia, ele já confirmou
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você já está escalado para esta partida! 🏃‍♂️"), backgroundColor: Colors.orange));
                              return; // Interrompe a execução aqui
                            }

                            // 2. Se não estiver, buscar o nome do jogador
                            final userData = await FirebaseFirestore.instance.collection('jogadores').doc(user.uid).get();

                            String nomeJogador = userData.data()?['nome'] ?? "Jogador Desconhecido";

                            // 3. Gravar a presença única
                            await FirebaseFirestore.instance.collection('presencas').add({
                              'nome': nomeJogador,
                              'uid': user.uid,
                              'posicao': userData.data()?['posicao'] ?? "Posição não especificada",
                              'data': FieldValue.serverTimestamp(),
                            });

                            // Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Convocação aceita! Bom jogo, $nomeJogador!"), backgroundColor: Colors.green));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro na conexão: $e")));
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Convocação aceita! Bom jogo, craque!")));
                        },
                        child: Text(
                          "VOU PRO JOGO",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isJanelaAberta() {
    DateTime agora = DateTime.now();
    // 3 = Quarta-feira, e checamos se a hora é >= 7h
    // Como você disse "o dia todo", não precisamos travar o horário final,
    // mas se quiser fechar às 23:59, a checagem de dia já resolve.
    if (agora.weekday == DateTime.wednesday && agora.hour >= 7) return true;
    if (agora.weekday == DateTime.wednesday && agora.hour < 19) return true;
    return false;
  }

  void atualizarPosicoesJogadores() async {
    final colecao = FirebaseFirestore.instance.collection('presencas');
    final snapshot = await colecao.get();

    List<String> posicoes = ['Goleiro', 'Zagueiro', 'Meia', 'Atacante'];

    int contador = 0;

    for (var doc in snapshot.docs) {
      // Distribui as posições: os primeiros 5 são goleiros, depois zagueiros...
      // Ou usa o resto da divisão para distribuir 1 de cada por vez:
      String posicaoAtribuida = posicoes[(contador / 5).floor() % posicoes.length];

      await colecao.doc(doc.id).update({'posicao': posicaoAtribuida});

      contador++;
    }
    print("✅ Atualização concluída! $contador jogadores atualizados.");
  }

  Widget _buildCardConvocacao(BuildContext context) {
    return ClipRRect(
      // Para o desfoque não vazar
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.yellow[700]!.withOpacity(0.5), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(Icons.event_available, color: Colors.yellow[700], size: 40),
              const SizedBox(height: 10),
              Text("CONVOCAÇÃO ABERTA!", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24)),
              const Text(
                "A partida é hoje! Confirme sua presença até as 19h.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700], foregroundColor: Colors.black),
                onPressed: () => _abrirJanelaConvocacao(context),
                //  onPressed: () {
                //    atualizarPosicoesJogadores();
                //  },
                child: const Text("RESPONDER AGORA"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _realizarSorteio(BuildContext context) async {
    try {
      // 1. Buscar as presenças ORDENADAS por data (quem marcou primeiro)
      // Limitamos a 20 para ignorar os suplentes no sorteio
      final presencasSnap = await FirebaseFirestore.instance
          .collection('presencas')
          .orderBy('data', descending: false) // Garante a ordem de chegada
          .limit(20) // Pega apenas os 20 primeiros
          .get();

      if (presencasSnap.docs.length < 2) {
        // Mínimo de 2 para sortear
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Poucos jogadores confirmados para sortear!")));
        return;
      }

      // Criamos um Map com os 20 UIDs que ganharam a vaga
      Map<String, String> uidsDosVinte = {};
      for (var doc in presencasSnap.docs) {
        uidsDosVinte[doc['uid']] = doc['nome'] ?? "Jogador";
      }

      // 2. Buscar os dados de posição na coleção 'jogadores'
      final jogadoresSnap = await FirebaseFirestore.instance.collection('jogadores').get();

      List<DocumentSnapshot> listaSorteio = [];

      for (var docJogador in jogadoresSnap.docs) {
        Map<String, dynamic> data = docJogador.data() as Map<String, dynamic>;
        String idDoJogador = docJogador.id;
        String? campoUid = data.containsKey('uid') ? data['uid'] : null;

        // Só adiciona se o jogador for um dos 20 primeiros da lista de presença
        if (uidsDosVinte.containsKey(idDoJogador) || (campoUid != null && uidsDosVinte.containsKey(campoUid))) {
          listaSorteio.add(docJogador);
        }
      }

      // 3. Agrupar por posição para equilibrar os times
      Map<String, List<DocumentSnapshot>> porPosicao = {};
      for (var doc in listaSorteio) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String pos = (data.containsKey('posicao') && data['posicao'] != null) ? data['posicao'] : 'Meio';
        porPosicao.putIfAbsent(pos, () => []).add(doc);
      }

      List<DocumentSnapshot> timeAzul = [];
      List<DocumentSnapshot> timeVermelho = [];

      // 4. Distribuir entre Azul e Vermelho (Balanceado por posição)
      porPosicao.forEach((posicao, jogadores) {
        jogadores.shuffle(); // Embaralha jogadores da mesma posição
        for (var i = 0; i < jogadores.length; i++) {
          // Distribui alternadamente para os times ficarem com o mesmo número de jogadores
          if (timeAzul.length <= timeVermelho.length) {
            timeAzul.add(jogadores[i]);
          } else {
            timeVermelho.add(jogadores[i]);
          }
        }
      });

      // 5. Mostrar o modal com o resultado
      _mostrarTimesSorteados(context, timeAzul, timeVermelho);
    } catch (e) {
      print("ERRO NO SORTEIO: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  void _mostrarTimesSorteados(BuildContext context, List<DocumentSnapshot> azul, List<DocumentSnapshot> vermelho) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("CONVOCAÇÃO DEFINIDA", style: GoogleFonts.bebasNeue(fontSize: 32, color: Colors.white)),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                children: [
                  _buildColunaTime("TIME AZUL", Colors.blue, azul),
                  const VerticalDivider(color: Colors.white24),
                  _buildColunaTime("TIME VERMELHO", Colors.red, vermelho),
                ],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _salvarEIniciarJogo(context, azul, vermelho),
              child: Text(
                "INICIAR PARTIDA E PLACAR",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _salvarEIniciarJogo(BuildContext context, List<DocumentSnapshot> azul, List<DocumentSnapshot> vermelho) async {
    // Criamos listas de Mapas com UID e Nome para facilitar a recuperação
    List<Map<String, dynamic>> dadosAzul = azul
        .map(
          (d) => {
            'uid': d.id, // ou d['uid'] se preferir
            'nome': d['nome'],
          },
        )
        .toList();

    List<Map<String, dynamic>> dadosVermelho = vermelho.map((d) => {'uid': d.id, 'nome': d['nome']}).toList();

    DocumentReference partidaRef = await FirebaseFirestore.instance.collection('partidas_ativas').add({
      'jogadores_azul': dadosAzul,
      'jogadores_vermelho': dadosVermelho,
      'gols_total_azul': 0,
      'gols_total_vermelho': 0,
      'data': FieldValue.serverTimestamp(),
      'status': 'em_andamento',
    });

    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => PlacarPage(partidaId: partidaRef.id)));
  }

  Widget _buildColunaTime(String nome, Color cor, List<DocumentSnapshot> jogadores) {
    return Expanded(
      child: Column(
        children: [
          Text(nome, style: GoogleFonts.bebasNeue(color: cor, fontSize: 20)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: jogadores.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text("${i + 1}. ${jogadores[i]['nome']}", style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHistorico(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.history_edu, color: Colors.white54, size: 40),
          const SizedBox(height: 10),
          Text("JANELA FECHADA", style: GoogleFonts.bebasNeue(color: Colors.white54, fontSize: 24)),
          const Text(
            "Novas convocações toda quarta às 07:00.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38),
          ),
          const SizedBox(height: 20),
          // TextButton.icon(
          //   onPressed: () {
          //     // Navegar para sua página de histórico
          //     print("Indo para o histórico...");
          //   },
          //   icon: const Icon(Icons.leaderboard, color: Colors.green),
          //   label: const Text(
          //     "VER HISTÓRICO DE JOGOS",
          //     style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          //   ),
          // ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(orgIdAtual: orgId),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FutureBuilder para o Nome da Organização
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('organizacoes').doc(orgId).get(),
              builder: (context, snapshot) {
                String nomeOrg = snapshot.hasData && snapshot.data!.exists ? snapshot.data!['nome'] : "Carregando...";

                return Text(nomeOrg.toUpperCase(), style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.white, letterSpacing: 1.2));
              },
            ),

            // 2. FutureBuilder para o Nome do Jogador Logado
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('jogadores') // Nome da sua coleção raiz de perfis
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                String nomeJogador = snapshot.hasData && snapshot.data!.exists ? snapshot.data!['nome'] : "...";

                return Text(
                  "Atleta: $nomeJogador",
                  style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w400),
                );
              },
            ),
          ],
        ),
        // title: _buildHeader(context),
        // title: FutureBuilder<DocumentSnapshot>(
        //   future: FirebaseFirestore.instance.collection('organizacoes').doc(orgId).get(),
        //   builder: (context, snapshot) {
        //     if (snapshot.connectionState == ConnectionState.waiting) {
        //       return const Text("Carregando...", style: TextStyle(color: Colors.white70, fontSize: 16));
        //     }

        //     if (snapshot.hasData && snapshot.data!.exists) {
        //       // Pegamos o campo 'nome' do documento da organização
        //       String nomeOrg = snapshot.data!['nome'];
        //       return Text(nomeOrg.toUpperCase(), style: GoogleFonts.bebasNeue(fontSize: 24, letterSpacing: 1.5, color: Colors.white));
        //     }

        //     return const Text("Time não encontrado");
        //   },
        // ),
        backgroundColor: Colors.green[900],
        iconTheme: const IconThemeData(color: Colors.white),
        // O ícone de menu (3 risquinhos) aparecerá automaticamente aqui à esquerda
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, colors: [Colors.green[900]!, Colors.green[800]!]),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildBotaoPartidaAtiva(context),

              // Card de Próxima Partida
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _isJanelaAberta()
                    ? _buildCardConvocacao(context) // Janela Aberta: Card de Jogo
                    : _buildCardHistorico(context), // Janela Fechada: Card de Histórico
              ),

              // Adicione este widget dentro da Column da sua HomePage
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 30),
                  padding: EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                  ),
                  child: _isJanelaAberta()
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("LISTA DE RELACIONADOS", style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.green[900])),
                                // Badge com contador (exemplo estático, pode ser dinâmico)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                    "Confirmados",
                                    style: TextStyle(color: Colors.green[900], fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                // Escuta a coleção de presenças em tempo real
                                stream: FirebaseFirestore.instance.collection('presencas').orderBy('data', descending: false).snapshots(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) return Text("Erro ao carregar lista");
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Center(child: CircularProgressIndicator(color: Colors.green));
                                  }

                                  final docs = snapshot.data!.docs;

                                  if (docs.isEmpty) {
                                    return Center(
                                      child: Text("Ninguém escalado ainda. Seja o primeiro!", style: TextStyle(color: Colors.grey)),
                                    );
                                  }

                                  // DIVISÃO TÁTICA
                                  final titulares = docs.take(20).toList();
                                  final suplentes = docs.skip(20).toList();

                                  return ListView(
                                    children: [
                                      // SEÇÃO DE TITULARES
                                      _buildSubHeader("RELACIONADOS", titulares.length, 20),
                                      ...titulares.asMap().entries.map((entry) => _buildCardJogador(entry.value, entry.key, context, isSuplente: false)).toList(),

                                      // SEÇÃO DE SUPLENTES (Só exibe se houver alguém)
                                      if (suplentes.isNotEmpty) ...[
                                        const SizedBox(height: 30),
                                        _buildSubHeader("LISTA DE SUPLENTES", suplentes.length, null),
                                        ...suplentes.asMap().entries.map((entry) => _buildCardJogador(entry.value, entry.key + 20, context, isSuplente: true)).toList(),
                                      ],
                                      const SizedBox(height: 50), // Espaço final
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      : _buildSecaoHistorico(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecaoHistorico() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("ÚLTIMOS RESULTADOS", style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.green[900])),
        const SizedBox(height: 15),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('partidas_ativas').where('status', isEqualTo: 'finalizado').orderBy('data', descending: true).limit(10).snapshots(),
            builder: (context, snapshot) {
              // 1. Tratamento de Erro (Geralmente aqui avisa sobre o Índice)
              if (snapshot.hasError) {
                print("Erro Firestore: ${snapshot.error}");
                return Center(child: Text("Configure o índice no Firebase console"));
              }

              // 2. Carregando
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final partidas = snapshot.data?.docs ?? [];

              // 3. Lista Vazia
              if (partidas.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_soccer, color: Colors.grey[300], size: 50),
                      const SizedBox(height: 10),
                      const Text("Nenhuma partida finalizada", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: partidas.length,
                itemBuilder: (context, index) {
                  var jogo = partidas[index].data() as Map<String, dynamic>;

                  // Conversão segura de data
                  String dataFormatada = "--/--";
                  if (jogo['data'] != null) {
                    DateTime dt = (jogo['data'] as Timestamp).toDate();
                    dataFormatada = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _timeHistorico("AZUL", jogo['gols_total_azul'] ?? 0, Colors.blue),
                        Column(
                          children: [
                            Text("VS", style: GoogleFonts.bebasNeue(color: Colors.grey[400], fontSize: 16)),
                            Text(dataFormatada, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        _timeHistorico("VERM", jogo['gols_total_vermelho'] ?? 0, Colors.red),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _timeHistorico(String nome, int gols, Color cor) {
    return Column(
      children: [
        Text(
          nome,
          style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Text("$gols", style: GoogleFonts.bebasNeue(fontSize: 32, color: Colors.black87)),
      ],
    );
  }

  Widget _colunaTimeHistorico(String nome, dynamic gols, Color cor) {
    return Column(
      children: [
        Text(
          nome,
          style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Text("${gols ?? 0}", style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.black)),
      ],
    );
  }

  Padding _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 10, 20), // Ajuste nos paddings
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center, // Alinha verticalmente ao centro
        children: [
          // 1. Lado Esquerdo: Saudação e Título
          Expanded(
            // Ocupa o espaço disponível sem empurrar o resto
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('jogadores').doc(FirebaseAuth.instance.currentUser?.uid).get(),
                  builder: (context, snapshot) {
                    String nome = "Jogador";
                    if (snapshot.hasData && snapshot.data!.exists) {
                      nome = snapshot.data?['nome'] ?? "Jogador";
                    }
                    return Text(
                      "Olá, $nome!",
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      overflow: TextOverflow.ellipsis, // Evita que nomes longos quebrem o layout
                    );
                  },
                ),
                Text("AppFute", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24)),
              ],
            ),
          ),
          //  _buildBotaoPartidaAtiva(context),
          // 2. Lado Direito: Botão Sorteio e Logout
          Row(
            children: [
              if (_isJanelaAberta())
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[700],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => _realizarSorteio(context), // Chame sua função aqui
                  icon: const Icon(Icons.shuffle, size: 16),
                  label: const Text("SORTEIO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              const SizedBox(width: 5),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                onPressed: () => _logoutDefinitivo(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _logoutDefinitivo(BuildContext context) async {
    // 1. Primeiro, navegue para uma tela "vazia" ou de Splash/Login
    // Isso remove os widgets que estão tentando ler o Firestore

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => LoginPage()), (route) => false);
    }

    // 2. Só então, deslogue do Firebase
    await FirebaseAuth.instance.signOut();
  }

  Widget _buildBotaoPartidaAtiva(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Busca partidas que ainda não foram finalizadas
      stream: FirebaseFirestore.instance.collection('partidas_ativas').where('status', isEqualTo: 'em_andamento').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Se não tem jogo, não mostra nada
        }

        var partida = snapshot.data!.docs.first; // Pega a partida atual

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PlacarPage(partidaId: partida.id)));
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade400]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.white),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("JOGO EM ANDAMENTO", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18)),
                        Builder(
                          builder: (context) {
                            // Usamos uma lógica segura para pegar os dados
                            var dados = partida.data() as Map<String, dynamic>;

                            // Tenta pegar com 'total', se não existir tenta sem, se não 0
                            var azul = dados['gols_total_azul'] ?? dados['gols_azul'] ?? 0;
                            var vermelho = dados['gols_total_vermelho'] ?? dados['gols_vermelho'] ?? 0;

                            return Text(
                              "Placar: $azul x $vermelho",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubHeader(String titulo, int atual, int? limite) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.green[900])),
          if (limite != null)
            Text(
              "$atual / $limite",
              style: TextStyle(fontWeight: FontWeight.bold, color: atual >= limite ? Colors.red : Colors.green),
            ),
        ],
      ),
    );
  }

  Widget _buildCardJogador(DocumentSnapshot doc, int index, BuildContext context, {required bool isSuplente}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    bool ehOMeuNome = doc['uid'] == currentUser?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuplente ? Colors.orange[50] : (ehOMeuNome ? Colors.green[50] : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSuplente ? Colors.orange[200]! : (ehOMeuNome ? Colors.green[200]! : Colors.transparent)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: isSuplente ? Colors.orange[800] : Colors.green[800],
            child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 15),
          Text(formatarNome(doc['nome'].toString()), style: TextStyle(fontWeight: ehOMeuNome ? FontWeight.bold : FontWeight.normal)),
          const Spacer(),
          Text(doc['posicao'].toString().toUpperCase().substring(0, 3), style: TextStyle(fontWeight: ehOMeuNome ? FontWeight.bold : FontWeight.normal)),
          SizedBox(width: 10),
          //  const Spacer(),
          if (ehOMeuNome)
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Colors.red),
              onPressed: () => _confirmarSaida(context, doc.id),
            )
          else
            Icon(isSuplente ? Icons.timer_outlined : Icons.check_circle, color: isSuplente ? Colors.orange : Colors.green, size: 20),
        ],
      ),
    );
  }

  String formatarNome(String nomeCompleto) {
    // Remove espaços extras no início e fim e divide por espaços
    List<String> partes = nomeCompleto.trim().split(' ');

    if (partes.length <= 1) {
      return nomeCompleto; // Retorna o único nome disponível
    }

    // Pega o primeiro e o último item da lista
    return "${partes.first} ${partes.last}";
  }
}
