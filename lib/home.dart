import 'dart:io';
import 'dart:ui';

import 'package:appfute/placar_fixo.dart';
import 'package:appfute/pre_jogo.dart';
import 'package:appfute/util/enum_janela.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:appfute/login.dart';
import 'package:appfute/placar.dart';
import 'package:appfute/widgets/menu.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HomePage extends StatefulWidget {
  final String orgId;

  const HomePage({super.key, required this.orgId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? idAdversario;
  String? nomeAdversario;
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
  void _abrirJanelaConvocacao(BuildContext context, Map<String, dynamic>? dadosOrg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ajusta o tamanho ao conteúdo
            children: [
              // Barra de arraste
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),
              Text("CONFIRMAR PRESENÇA", style: GoogleFonts.bebasNeue(fontSize: 28, color: Colors.green[900])),
              const SizedBox(height: 10),
              Text(
                "A partida está confirmada! Você vai pro jogo?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  // Botão Desfalque
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "AGORA NÃO",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Botão Confirmar Presença
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;

                          // 1. Checagem de duplicidade (igual ao anterior)
                          final checkPresenca = await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('presencas').where('uid', isEqualTo: user.uid).get();

                          if (checkPresenca.docs.isNotEmpty) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.black),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "VOCÊ JÁ ESTÁ ESCALADO NESTA PARTIDA!",
                                        style: GoogleFonts.bebasNeue(
                                          color: Colors.black, // Texto preto para contrastar com o fundo amarelo
                                          fontSize: 16,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.yellow[700], // Amarelo [700] do seu novo tema
                                behavior: SnackBarBehavior.floating, // Faz o alerta "flutuar" acima do fundo verde
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            return;
                          }

                          // 2. BUSCAR O TOTAL ATUAL PARA DEFINIR O STATUS
                          int limiteVagasPartida = dadosOrg?['vagas_partida'] ?? 20;
                          final snapshotPresencas = await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('presencas').get();
                          int totalConfirmados = snapshotPresencas.docs.length;

                          // Se o total já atingiu o limite, ele entra como suplente
                          bool ehSuplente = totalConfirmados >= limiteVagasPartida;

                          final userData = await FirebaseFirestore.instance.collection('jogadores').doc(user.uid).get();

                          // 3. GRAVAR COM A FLAG DE SUPLENTE

                          await FirebaseFirestore.instance
                              .collection('organizacoes')
                              .doc(widget.orgId) // Usa o ID da organização atual
                              .collection('presencas')
                              .add({
                                'nome': userData.data()?['nome'] ?? "Jogador",
                                'uid': user.uid,
                                'posicao': userData.data()?['posicao'] ?? "Geral",
                                'data': FieldValue.serverTimestamp(),
                                'suplente': ehSuplente, // Campo fun
                              });

                          Navigator.pop(context);

                          // Feedback personalizado
                          String msg = ehSuplente ? "Vagas cheias! Você entrou como SUPLENTE. ⏱️" : "Convocado! Você é TITULAR. 🏃‍♂️";

                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ehSuplente ? Colors.orange : Colors.green));
                        } catch (e) {
                          print(e);
                        }
                      },
                      child: const Text(
                        "VOU PRO JOGO",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  StatusLista checarStatusRecorrente(Map<String, dynamic>? dadosOrg) {
    // 1. Verificação de segurança: se não houver configuração, a lista fica aberta por padrão
    if (dadosOrg == null || dadosOrg['abertura_dia'] == null || dadosOrg['abertura_hora'] == null || dadosOrg['fechamento_dia'] == null || dadosOrg['fechamento_hora'] == null) {
      return StatusLista.aberta;
    }

    try {
      DateTime agora = DateTime.now();

      // Pegamos o dia da semana (1 a 7) e transformamos em um número comparável
      // Exemplo: Segunda-feira 09:30 vira 10930
      int valorAgora = (agora.weekday * 10000) + (agora.hour * 100) + agora.minute;

      // 2. Processar Abertura (Convertendo para int garantido)
      int diaAb = int.parse(dadosOrg['abertura_dia'].toString());
      List<String> partesAb = dadosOrg['abertura_hora'].toString().split(':');
      int horaAb = int.parse(partesAb[0]);
      int minAb = int.parse(partesAb[1]);
      int valorAbertura = (diaAb * 10000) + (horaAb * 100) + minAb;

      // 3. Processar Fechamento
      int diaFe = int.parse(dadosOrg['fechamento_dia'].toString());
      List<String> partesFe = dadosOrg['fechamento_hora'].toString().split(':');
      int horaFe = int.parse(partesFe[0]);
      int minFe = int.parse(partesFe[1]);
      int valorFechamento = (diaFe * 10000) + (horaFe * 100) + minFe;

      // 4. Lógica de Comparação
      if (valorAbertura < valorFechamento) {
        // Caso comum: Abre e fecha na mesma semana (ex: Abre Terça, fecha Quinta)
        if (valorAgora < valorAbertura) return StatusLista.fechadaAinda;
        if (valorAgora > valorFechamento) return StatusLista.encerrada;
        return StatusLista.aberta;
      } else {
        // Caso que vira a semana: Abre Sábado e fecha Segunda
        // A lista está aberta se: agora for depois da abertura OU antes do fechamento
        if (valorAgora >= valorAbertura || valorAgora <= valorFechamento) {
          return StatusLista.aberta;
        }
        return StatusLista.fechadaAinda; // Ou encerrada, dependendo de como você visualiza o ciclo
      }
    } catch (e) {
      // Se der qualquer erro na conversão (ex: string mal formatada), mantém aberto para não travar o usuário
      debugPrint("Erro ao checar status recorrente: $e");
      return StatusLista.aberta;
    }
  }

  Widget _buildBannerStatus(Map<String, dynamic>? dadosOrg) {
    // 1. Verifica o status baseado no horário configurado (Regra Recorrente)
    StatusLista status = checarStatusRecorrente(dadosOrg);

    // Nomes dos dias para exibição amigável
    const List<String> diasNomes = ['', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

    // 2. Se a lista estiver FECHADA ou ENCERRADA, mostramos um banner estático
    if (status == StatusLista.fechadaAinda) {
      int diaIdx = int.tryParse(dadosOrg?['abertura_dia']?.toString() ?? '1') ?? 1;
      String hora = dadosOrg?['abertura_hora'] ?? "00:00";
      return _containerBanner(color: Colors.blueGrey[900]!, icon: Icons.lock_clock, textColor: Colors.white, texto: "PRÓXIMA LISTA: ${diasNomes[diaIdx].toUpperCase()} ÀS $hora");
    }

    if (status == StatusLista.encerrada) {
      return _containerBanner(color: Colors.red[900]!, icon: Icons.event_busy, textColor: Colors.white, texto: "CONVOCAÇÃO ENCERRADA");
    }

    // 3. Se a lista estiver ABERTA, usamos um StreamBuilder para monitorar as vagas/suplentes
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('presencas').snapshots(),
      builder: (context, snapshot) {
        // Dados básicos
        int totalConfirmados = snapshot.data?.docs.length ?? 0;
        int limiteTitulares = int.tryParse(dadosOrg?['vagas_partida']?.toString() ?? '20') ?? 20;

        Color bannerColor;
        IconData bannerIcon;
        String bannerTexto;
        Color textColor = Colors.black;

        if (totalConfirmados >= limiteTitulares) {
          // CASO: SUPLÊNCIA ATIVA
          int numSuplentes = totalConfirmados - limiteTitulares;
          bannerColor = Colors.orange[800]!;
          bannerIcon = Icons.hourglass_top;
          textColor = Colors.white;
          bannerTexto = numSuplentes == 0 ? "VAGAS CHEIAS! PRÓXIMOS ENTRARÃO COMO SUPLENTES" : "LISTA DE ESPERA ATIVA: $numSuplentes SUPLENTE(S)";
        } else {
          // CASO: VAGAS DISPONÍVEIS
          int restam = limiteTitulares - totalConfirmados;
          bannerColor = Colors.yellow[700]!;
          bannerIcon = Icons.sports_soccer;
          bannerTexto = "CONVOCAÇÃO ABERTA: RESTAM $restam VAGAS";
        }

        return _containerBanner(color: bannerColor, icon: bannerIcon, textColor: textColor, texto: bannerTexto);
      },
    );
  }

  // Widget auxiliar para manter a padronização visual do banner
  Widget _containerBanner({required Color color, required IconData icon, required Color textColor, required String texto}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      decoration: BoxDecoration(
        color: color,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: GoogleFonts.bebasNeue(color: textColor, fontSize: 16, letterSpacing: 1.1),
            ),
          ),
        ],
      ),
    );
  }

  void atualizarPosicoesJogadores() async {
    final colecao = FirebaseFirestore.instance.collection('presencas');
    final snapshot = await colecao.get();

    List<String> posicoes = ['Goleiro', 'Zagueiro', 'Lateral', 'Volante', 'Meia', 'Atacante'];

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

  Widget _buildCardConvocacao(BuildContext context, Map<String, dynamic>? dadosOrg) {
    // 1. Buscamos o limite de titulares (padrão 20)
    int limiteTitulares = int.tryParse(dadosOrg?['vagas_partida']?.toString() ?? '20') ?? 20;

    return StreamBuilder<QuerySnapshot>(
      // CORREÇÃO AQUI: Apontando para a subcoleção da organização atual
      stream: FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('presencas').snapshots(),
      builder: (context, snapshot) {
        // 2. Contagem em tempo real baseada nos documentos da subcoleção
        int totalConfirmados = snapshot.data?.docs.length ?? 0;
        bool jaLotou = totalConfirmados >= limiteTitulares;

        // Cálculo de vagas restantes (trava em 0 se já lotou)
        int vagasRestantes = limiteTitulares - totalConfirmados;
        if (vagasRestantes < 0) vagasRestantes = 0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: jaLotou ? Colors.orange.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: jaLotou ? Colors.orange[700]!.withOpacity(0.5) : Colors.yellow[700]!.withOpacity(0.5), width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(jaLotou ? Icons.hourglass_top : Icons.event_available, color: jaLotou ? Colors.orange[700] : Colors.yellow[700], size: 40),
                  const SizedBox(height: 10),
                  Text(jaLotou ? "VAGAS DE TITULARES CHEIAS" : "CONVOCAÇÃO ABERTA!", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24)),
                  Text(
                    jaLotou
                        ? "O limite de $limiteTitulares jogadores foi atingido.\nEntre na LISTA DE ESPERA como suplente!"
                        : "Garanta sua vaga entre os $limiteTitulares titulares!\nRestam apenas $vagasRestantes vagas.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // 3. Botão Dinâmico
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: jaLotou ? Colors.orange[800] : Colors.yellow[700],
                      foregroundColor: jaLotou ? Colors.white : Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _abrirJanelaConvocacao(context, dadosOrg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(jaLotou ? Icons.list_alt : Icons.check_circle_outline),
                        const SizedBox(width: 10),
                        Text(jaLotou ? "ENTRAR NA LISTA DE ESPERA" : "CONFIRMAR MINHA VAGA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),

                  // Texto de auxílio para suplentes
                  if (jaLotou)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        "${totalConfirmados - limiteTitulares} jogador(es) na sua frente na espera",
                        style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _realizarSorteio(BuildContext context, Map<String, dynamic>? dadosOrg) async {
    try {
      // 1. Definições iniciais e Limite de Vagas
      final String orgId = widget.orgId;
      int limiteTitulares = int.tryParse(dadosOrg?['vagas_partida']?.toString() ?? '6') ?? 6;

      // 2. Referência para a subcoleção de presenças da organização específica
      final presencasRef = FirebaseFirestore.instance.collection('organizacoes').doc(orgId).collection('presencas');

      // 3. Busca apenas os jogadores que estão dentro do limite (Titulares)
      // Ordenamos por data para garantir que quem confirmou primeiro tem a vaga
      final presencasSnap = await presencasRef.orderBy('data', descending: false).limit(limiteTitulares).get();

      if (presencasSnap.docs.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jogadores insuficientes para realizar o sorteio!")));
        return;
      }

      // 4. Mapeia os UIDs dos jogadores confirmados
      List<String> uidsConfirmados = presencasSnap.docs.map((doc) => doc['uid'].toString()).toList();

      // 5. Busca os dados de Perfil (Posição/Nível) na coleção raiz de jogadores
      final jogadoresSnap = await FirebaseFirestore.instance.collection('jogadores').get();

      List<DocumentSnapshot> listaParaSorteio = [];
      for (var docJogador in jogadoresSnap.docs) {
        if (uidsConfirmados.contains(docJogador.id)) {
          listaParaSorteio.add(docJogador);
        }
      }

      // 6. Lógica de Equilíbrio por Posição
      Map<String, List<DocumentSnapshot>> porPosicao = {};
      for (var doc in listaParaSorteio) {
        final data = doc.data() as Map<String, dynamic>?;
        String pos = data != null && data.containsKey('posicao') ? data['posicao'] : 'Meio';
        porPosicao.putIfAbsent(pos, () => []).add(doc);
      }

      List<DocumentSnapshot> timeAzul = [];
      List<DocumentSnapshot> timeVermelho = [];

      // Distribui os jogadores alternadamente entre os times
      porPosicao.forEach((posicao, jogadores) {
        jogadores.shuffle(); // Embaralha jogadores da mesma posição
        for (var i = 0; i < jogadores.length; i++) {
          if (timeAzul.length <= timeVermelho.length) {
            timeAzul.add(jogadores[i]);
          } else {
            timeVermelho.add(jogadores[i]);
          }
        }
      });

      // 7. Exibe o resultado (Modal ou nova tela)
      _mostrarTimesSorteados(context, timeAzul, timeVermelho);
    } catch (e) {
      debugPrint("ERRO NO SORTEIO: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao realizar sorteio: $e"), backgroundColor: Colors.red));
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
                  _buildColunaTimeA("TIME AZUL", Colors.blue, azul),
                  const VerticalDivider(color: Colors.white24),
                  _buildColunaTimeB("TIME VERMELHO", Colors.red, vermelho),
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
      'orgId': widget.orgId,
      'jogadores_azul': dadosAzul,
      'jogadores_vermelho': dadosVermelho,
      'gols_total_azul': 0,
      'gols_total_vermelho': 0,
      'data': FieldValue.serverTimestamp(),
      'nome_time_a': nomeTimeA.text,
      'nome_time_b': nomeTimeB.text,
      'status': 'em_andamento',
      'tipo_jogo': 'pelada',
    });

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlacarPage(partidaId: partidaRef.id, orgId: widget.orgId),
      ),
    );
  }

  TextEditingController nomeTimeA = TextEditingController(text: "SEU TIME");
  TextEditingController nomeTimeB = TextEditingController(text: "SEU TIME");

  Widget _buildColunaTimeA(String nome, Color cor, List<DocumentSnapshot> jogadores) {
    return Expanded(
      child: Column(
        children: [
          // Text(nome, style: GoogleFonts.bebasNeue(color: cor, fontSize: 20)),
          TextField(
            controller: nomeTimeA, // O controlador que guarda o nome
            textAlign: TextAlign.center, // Mantém o alinhamento central do "VS"
            style: GoogleFonts.bebasNeue(
              color: cor, // A cor Amarela [700] ou Branca que você já usa
              fontSize: 20,
            ),
            textCapitalization: TextCapitalization.characters,
            cursorColor: Colors.yellow[700],
            decoration: InputDecoration(
              isDense: true, // Diminui o espaço interno
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              border: InputBorder.none, // Tira a borda padrão para parecer um texto
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.yellow[700]!, width: 1)), // Mostra uma linha amarela apenas quando clica para editar
              hintText: "NOME DO TIME",
              hintStyle: TextStyle(color: cor.withOpacity(0.3)),
            ),
            onChanged: (val) {
              nomeTimeA.value = nomeTimeA.value.copyWith(
                text: val.toUpperCase(),
                selection: TextSelection.collapsed(offset: val.length),
              );
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: jogadores.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${i + 1}. ${jogadores[i]['nome']}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                    Text("${jogadores[i]['posicao'].toString().toUpperCase().substring(0, 3)}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColunaTimeB(String nome, Color cor, List<DocumentSnapshot> jogadores) {
    return Expanded(
      child: Column(
        children: [
          // Text(nome, style: GoogleFonts.bebasNeue(color: cor, fontSize: 20)),
          TextField(
            controller: nomeTimeB, // O controlador que guarda o nome
            textAlign: TextAlign.center, // Mantém o alinhamento central do "VS"
            style: GoogleFonts.bebasNeue(
              color: cor, // A cor Amarela [700] ou Branca que você já usa
              fontSize: 20,
            ),
            textCapitalization: TextCapitalization.characters,
            cursorColor: Colors.yellow[700],
            decoration: InputDecoration(
              isDense: true, // Diminui o espaço interno
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              border: InputBorder.none, // Tira a borda padrão para parecer um texto
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.yellow[700]!, width: 1)), // Mostra uma linha amarela apenas quando clica para editar
              hintText: "NOME DO TIME",
              hintStyle: TextStyle(color: cor.withOpacity(0.3)),
            ),
            onChanged: (val) {
              nomeTimeB.value = nomeTimeB.value.copyWith(
                text: val.toUpperCase(),
                selection: TextSelection.collapsed(offset: val.length),
              );
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: jogadores.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${i + 1}. ${jogadores[i]['nome']}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                    Text("${jogadores[i]['posicao'].toString().toUpperCase().substring(0, 3)}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CARD DE HISTÓRICO ADAPTADO PARA MOSTRAR STATUS
  Widget _buildCardHistorico(BuildContext context, StatusLista status, Map<String, dynamic>? dadosOrg) {
    String msg = status == StatusLista.fechadaAinda ? "LISTA EM BREVE" : "LISTA ENCERRADA";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: Colors.white30, size: 30),
          const SizedBox(height: 10),
          Text(msg, style: GoogleFonts.bebasNeue(color: Colors.white54, fontSize: 20)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic>? dadosOrg, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 15, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LADO ESQUERDO: Saudação e Nome do Jogador
          Expanded(
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
                      "Olá, ${formatarNome(nome)}!",
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
                Text("APPFUTE", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 28, letterSpacing: 1.5)),
              ],
            ),
          ),

          // Se não for admin, podemos mostrar um ícone de perfil ou notificações
          if (!isAdmin)
            const CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(Icons.person, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).snapshots(),
      builder: (context, orgSnapshot) {
        if (orgSnapshot.hasError) return const Scaffold(body: Center(child: Text("Erro ao carregar organização")));
        if (!orgSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final dadosOrg = orgSnapshot.data!.data() as Map<String, dynamic>?;
        final int limiteVagas = int.tryParse(dadosOrg?['vagas_partida']?.toString() ?? '20') ?? 20;
        // Pegamos o status uma única vez para usar no build
        final status = checarStatusRecorrente(dadosOrg);

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('jogadores').doc(user?.uid).get(),
          builder: (context, userSnapshot) {
            bool isAdmin = false;
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              isAdmin = (userSnapshot.data!.data() as Map<String, dynamic>?)?['is_admin'] == true;
            }

            return Scaffold(
              // backgroundColor: const Color(0xFF0D0D0D),
              backgroundColor: Colors.green[900],
              drawer: CustomDrawer(orgIdAtual: widget.orgId),
              appBar: AppBar(
                backgroundColor: Colors.green[900],
                iconTheme: const IconThemeData(color: Colors.white),
                elevation: 0,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((dadosOrg?['nome'] ?? "Carregando...").toString().toUpperCase(), style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.white, letterSpacing: 1.2)),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('jogadores').doc(user?.uid).get(),
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
                actions: [
                  if (isAdmin && dadosOrg?['tipo_jogo'] == 'pelada')
                    Padding(
                      padding: const EdgeInsets.only(right: 10, top: 5, bottom: 5),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () => _realizarSorteio(context, dadosOrg),
                        icon: const Icon(Icons.shuffle, size: 18),
                        label: Text("SORTEAR", style: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1)),
                      ),
                    ),
                  if (isAdmin && dadosOrg?['tipo_jogo'] == 'fixo')
                    Padding(
                      padding: const EdgeInsets.only(right: 10, top: 5, bottom: 5),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () => _abrirBuscaAdversario(context, dadosOrg),
                        icon: const Icon(Icons.shuffle, size: 18),
                        label: Text("IR PRO JOGO", style: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1)),
                      ),
                    ),
                ],
              ),
              body: Builder(
                builder: (context) {
                  // 1. Verificamos o status da lista
                  final status = checarStatusRecorrente(dadosOrg);

                  // ESTADO A: LISTA FECHADA OU ENCERRADA
                  if (status != StatusLista.aberta) {
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _buildBannerStatus(dadosOrg),
                              _buildBotaoPartidaAtiva(context), // Placar se houver jogo
                              const SizedBox(height: 20),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildCardHistorico(context, status, dadosOrg)),
                            ],
                          ),
                        ),
                        // Exibe o histórico de jogos finalizados abaixo do card
                        _buildSecaoHistoricoSliver(widget.orgId),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    );
                  }

                  // ESTADO B: LISTA ABERTA (CONVOCAÇÃO)
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('presencas').orderBy('data', descending: false).snapshots(),
                    builder: (context, presencasSnapshot) {
                      if (!presencasSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allDocs = presencasSnapshot.data!.docs;
                      final titulares = allDocs.take(limiteVagas).toList();
                      final suplentes = allDocs.skip(limiteVagas).toList();

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                _buildBannerStatus(dadosOrg),
                                const SizedBox(height: 15),
                                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildCardConvocacao(context, dadosOrg)),
                              ],
                            ),
                          ),

                          // SEÇÃO: TITULARES
                          _buildTituloSliver("TITULARES CONFIRMADOS", Icons.sports_soccer, Colors.green),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: _buildCardJogador(titulares[index], index, context, limiteVagas)),
                              childCount: titulares.length,
                            ),
                          ),

                          // SEÇÃO: SUPLENTES
                          if (suplentes.isNotEmpty) ...[
                            _buildTituloSliver("LISTA DE ESPERA / SUPLENTES", Icons.hourglass_top, Colors.orange),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: _buildCardJogador(suplentes[index], index + limiteVagas, context, limiteVagas)),
                                childCount: suplentes.length,
                              ),
                            ),
                          ],
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      );
                    },
                  );
                },
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _carregandoCompartilhamento
                    ? null // Desativa o clique enquanto processa
                    : () => _compartilharCodigo(context, widget.orgId, dadosOrg?['nome'], dadosOrg?['urlEscudo']),
                backgroundColor: Colors.yellow[700],
                foregroundColor: Colors.black,
                elevation: 6,
                // Se estiver carregando a imagem, mostra um spinner, se não, mostra o ícone e texto
                icon: _carregandoCompartilhamento ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.share_rounded),
                label: const Text("CONVIDAR JOGADOR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            );
          },
        );
      },
    );
  }

  bool _carregandoCompartilhamento = false;

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
    } finally {
      setState(() => _carregandoCompartilhamento = false);
    }
  }

  void _abrirBuscaAdversario(BuildContext context, Map<String, dynamic>? dadosOrg) {
    String filtroNome = ""; // Variável local para o filtro

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Importante para o teclado não cobrir o campo
      backgroundColor: const Color(0xFF1B5E20),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        // O StatefulBuilder permite atualizar o modal sem fechar ele
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // --- CAMPO DE BUSCA ---
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Nome do time adversário...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.search, color: Colors.yellow[700]),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.yellow[700]!)),
                    ),
                    onChanged: (val) {
                      // Atualiza o estado interno do modal
                      setModalState(() => filtroNome = val.trim().toUpperCase());
                    },
                  ),
                  const SizedBox(height: 20),

                  // --- LISTA DE RESULTADOS ---
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      // Query filtrando por tipo FIXO e pelo texto digitado
                      stream: FirebaseFirestore.instance.collection('organizacoes').where('tipo_jogo', isEqualTo: 'fixo').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        // Filtragem manual (mais rápida e permite nomes parciais)
                        final docs = snapshot.data!.docs.where((doc) {
                          final nome = doc['nome'].toString().toUpperCase();
                          return nome.contains(filtroNome);
                        }).toList();

                        // --- CASO NÃO ENCONTRE: OPÇÃO DE CONVIDAR ---
                        if (docs.isEmpty && filtroNome.isNotEmpty) {
                          return _buildOpcaoConvidar(filtroNome, dadosOrg?['nome']);
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            var org = docs[index];
                            if (org.id == widget.orgId) return const SizedBox();

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.yellow[700],
                                child: const Icon(Icons.shield, color: Colors.black),
                              ),
                              title: Text(org['nome'].toString().toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18)),
                              onTap: () {
                                Navigator.pop(context); // Fecha modal
                                // Navega para o Pré-Jogo com os dados encontrados
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PreJogoPage(orgIdA: widget.orgId, nomeA: dadosOrg?['nome'], orgIdB: org.id, nomeB: org['nome']),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // void _abrirBuscaAdversario(BuildContext context, Map<String, dynamic>? dadosOrg) {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: const Color(0xFF1B5E20), // Seu fundo Verde Gramado
  //     shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (BuildContext context, StateSetter setModalState) {
  //           return Column(
  //             children: [
  //               Padding(
  //                 padding: const EdgeInsets.all(20),
  //                 child: TextField(
  //                   controller: nomeDigitadoNoFiltro,
  //                   style: const TextStyle(color: Colors.white),
  //                   decoration: InputDecoration(
  //                     hintText: "Nome do time adversário...",
  //                     hintStyle: const TextStyle(color: Colors.white38),
  //                     prefixIcon: Icon(Icons.search, color: Colors.yellow[700]),
  //                     enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.yellow[700]!)),
  //                   ),
  //                   onChanged: (val) {
  //                     setModalState(() => filtroNome = val.trim().toUpperCase());
  //                   },
  //                 ),
  //               ),
  //               Expanded(
  //                 child: StreamBuilder<QuerySnapshot>(
  //                   stream: FirebaseFirestore.instance
  //                       .collection('organizacoes')
  //                       .where('tipo_jogo', isEqualTo: 'fixo') // Filtra apenas times fixos
  //                       .limit(100)
  //                       .snapshots(),
  //                   builder: (context, snapshot) {
  //                     if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

  //                     if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
  //                       return Column(
  //                         mainAxisAlignment: MainAxisAlignment.center,
  //                         children: [
  //                           Icon(Icons.person_add_alt_1, size: 50, color: Colors.yellow[700]?.withOpacity(0.5)),
  //                           const SizedBox(height: 10),
  //                           const Text("TIME NÃO ENCONTRADO", style: TextStyle(color: Colors.white70)),
  //                           const SizedBox(height: 20),
  //                           ElevatedButton.icon(
  //                             style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
  //                             icon: const Icon(Icons.share, color: Colors.black),
  //                             label: const Text("CONVIDAR E JOGAR", style: TextStyle(color: Colors.black)),
  //                             onPressed: () {
  //                               _convidarTimeExterno(context, filtroNome ?? '');

  //                               Navigator.push(
  //                                 context,
  //                                 MaterialPageRoute(
  //                                   builder: (context) => PreJogoPage(orgIdA: widget.orgId, nomeA: dadosOrg?['nome'], orgIdB: '00000', nomeB: filtroNome ?? 'TIME CONVIDADO'),
  //                                 ),
  //                               );
  //                             },
  //                           ),
  //                         ],
  //                       );
  //                     }

  //                     return ListView.builder(
  //                       itemCount: snapshot.data!.docs.length,
  //                       itemBuilder: (context, index) {
  //                         var org = snapshot.data!.docs[index];
  //                         if (org.id == widget.orgId) return const SizedBox(); // Não listar o próprio time

  //                         return ListTile(
  //                           leading: CircleAvatar(
  //                             backgroundColor: Colors.yellow[700],
  //                             child: const Icon(Icons.shield, color: Colors.black),
  //                           ),
  //                           title: Text(org['nome'].toString().toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white)),
  //                           onTap: () {
  //                             // Salva o ID e Nome do adversário para o placar
  //                             setState(() {
  //                               idAdversario = org.id;
  //                               nomeAdversario = org['nome'];
  //                             });
  //                             Navigator.push(
  //                               context,
  //                               MaterialPageRoute(
  //                                 builder: (context) => PreJogoPage(orgIdA: widget.orgId, nomeA: dadosOrg?['nome'], orgIdB: idAdversario!, nomeB: nomeAdversario!),
  //                               ),
  //                             );
  //                           },
  //                         );
  //                       },
  //                     );
  //                   },
  //                 ),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  void _convidarTimeExterno(BuildContext context, String nomeTime) {
    final String linkApp = "https://seulink.com.br/download"; // Link da sua PlayStore/AppStore
    final String mensagem =
        "E aí time do $nomeTime! ⚽\n"
        "Estamos acompanhando nosso jogo de hoje pelo APPFUTE.\n"
        "Baixe o app para acompanhar o placar ao vivo e ver quem está brocando: $linkApp";

    // Abre a aba de compartilhamento do celular
    // Share.share(mensagem);

    // Após compartilhar, você já pode chamar a função de iniciar o jogo com fictícios
    // _iniciarComTimeFicticio(nomeTime);
  }

  Widget _buildOpcaoConvidar(String nomeTime, String nomeTimeA) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off, size: 60, color: Colors.white24),
        const SizedBox(height: 10),
        Text(
          "TIME '$nomeTime' NÃO ENCONTRADO",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
          icon: const Icon(Icons.share, color: Colors.black),
          label: const Text(
            "CONVIDAR E JOGAR COM FICTÍCIOS",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            _convidarTimeExterno(context, nomeTime);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PreJogoPage(orgIdA: widget.orgId, nomeA: nomeTimeA, orgIdB: '00000', nomeB: nomeTime ?? 'TIME CONVIDADO'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSliverListasDePresenca(AsyncSnapshot<QuerySnapshot> snapshot, int limiteVagas) {
    if (!snapshot.hasData) {
      return const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    final allDocs = snapshot.data!.docs;

    // Lógica de separação
    final titulares = allDocs.take(limiteVagas).toList();
    final suplentes = allDocs.skip(limiteVagas).toList();

    if (allDocs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: Text("NENHUM ATLETA ESCALADO", style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 20)),
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        // SEÇÃO: TITULARES
        _buildTituloSliver("TITULARES CONFIRMADOS", Icons.sports_soccer, Colors.green),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4), child: _buildCardJogador(titulares[index], index, context, limiteVagas)),
            childCount: titulares.length,
          ),
        ),

        // SEÇÃO: SUPLENTES
        if (suplentes.isNotEmpty) ...[
          _buildTituloSliver("LISTA DE ESPERA / SUPLENTES", Icons.hourglass_top, Colors.orange),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: _buildCardJogador(
                  suplentes[index],
                  index + limiteVagas, // Soma o index para continuar a contagem (ex: 21, 22...)
                  context,
                  limiteVagas,
                ),
              ),
              childCount: suplentes.length,
            ),
          ),
        ],

        // Espaço extra no final da lista
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSecaoHistoricoSliver(String orgId) {
    return StreamBuilder<QuerySnapshot>(
      // Mudamos para buscar na raiz 'partidas_ativas' filtrando por orgId
      stream: FirebaseFirestore.instance
          .collection('partidas_ativas')
          .where('orgId', isEqualTo: orgId) // Filtro por time
          .where('status', isEqualTo: 'finalizado') // Filtro por encerrado
          .orderBy('data_fim', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print(snapshot.error);
          // Se der erro de índice (comum no Firebase), mostra o erro para você clicar no link
          // return SliverToBoxAdapter(
          //   child: Center(
          //     child: Text("Erro: ${snapshot.error}", style: TextStyle(color: Colors.red, fontSize: 10)),
          //   ),
          // );
        }

        if (!snapshot.hasData) return const SliverToBoxAdapter(child: SizedBox());

        final jogos = snapshot.data!.docs;

        // Se não encontrar jogos deste time, vamos tentar buscar jogos globais
        // (Apenas para garantir que o widget está funcionando)
        if (jogos.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off, color: Colors.white10, size: 40),
                  const SizedBox(height: 10),
                  Text("NENHUM JOGO FINALIZADO NESTE TIME", style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 18)),
                ],
              ),
            ),
          );
        }

        return SliverMainAxisGroup(
          slivers: [
            _buildTituloSliver("ÚLTIMOS RESULTADOS", Icons.history, Colors.white54),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                var jogo = jogos[index].data() as Map<String, dynamic>;
                return _buildCardPlacarHistorico(jogo);
              }, childCount: jogos.length),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCardPlacarHistorico(Map<String, dynamic> jogo) {
    // Ajuste os nomes dos campos aqui conforme o que você salva na tela de Placar
    int azul = jogo['gols_total_azul'] ?? jogo['gols_azul'] ?? 0;
    int vermelho = jogo['gols_total_vermelho'] ?? jogo['gols_vermelho'] ?? 0;

    String nomeA = jogo['nome_time_a'] ?? "TIME AZUL";
    String nomeB = jogo['nome_time_b'] ?? "TIME VERMELHO";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 12, 63, 14),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _colunaTime(nomeA, azul, Colors.blue),
          Text("VS", style: GoogleFonts.bebasNeue(fontSize: 20, color: Colors.white24)),
          _colunaTime(nomeB, vermelho, Colors.red),
        ],
      ),
    );
  }

  Widget _colunaTime(String nome, int gols, Color cor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(nome, style: GoogleFonts.bebasNeue(color: cor, fontSize: 16, letterSpacing: 1)),
        Text(
          "$gols",
          style: GoogleFonts.bebasNeue(
            color: Colors.white,
            fontSize: 38, // Destaque para o número de gols
            height: 1.1,
          ),
        ),
      ],
    );
  }

  // Widget auxiliar para os títulos das listas
  Widget _buildTituloSliver(String titulo, IconData icon, Color cor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
        child: Row(
          children: [
            Icon(icon, color: cor, size: 20),
            const SizedBox(width: 10),
            Text(titulo, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  // Widget _buildSecaoHistorico() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text("ÚLTIMOS RESULTADOS", style: GoogleFonts.bebasNeue(fontSize: 24, color: Colors.green[900])),
  //       const SizedBox(height: 15),
  //       Expanded(
  //         child: StreamBuilder<QuerySnapshot>(
  //           stream: FirebaseFirestore.instance
  //               .collection('partidas_ativas')
  //               .where('orgId', isEqualTo: widget.orgId)
  //               .where('status', isEqualTo: 'finalizado')
  //               .orderBy('data', descending: true)
  //               .snapshots(),

  //           builder: (context, snapshot) {
  //             // 1. Tratamento de Erro (Geralmente aqui avisa sobre o Índice)
  //             if (snapshot.hasError) {
  //               print("Erro Firestore: ${snapshot.error}");
  //               return Center(child: Text("Configure o índice no Firebase console"));
  //             }

  //             // 2. Carregando
  //             if (snapshot.connectionState == ConnectionState.waiting) {
  //               return const Center(child: CircularProgressIndicator());
  //             }

  //             final partidas = snapshot.data?.docs ?? [];

  //             // 3. Lista Vazia
  //             if (partidas.isEmpty) {
  //               return Center(
  //                 child: Column(
  //                   mainAxisAlignment: MainAxisAlignment.center,
  //                   children: [
  //                     Icon(Icons.sports_soccer, color: Colors.grey[300], size: 50),
  //                     const SizedBox(height: 10),
  //                     const Text("Nenhuma partida finalizada", style: TextStyle(color: Colors.grey)),
  //                   ],
  //                 ),
  //               );
  //             }

  //             return ListView.builder(
  //               itemCount: partidas.length,
  //               itemBuilder: (context, index) {
  //                 var jogo = partidas[index].data() as Map<String, dynamic>;

  //                 // Conversão segura de data
  //                 String dataFormatada = "--/--";
  //                 if (jogo['data'] != null) {
  //                   DateTime dt = (jogo['data'] as Timestamp).toDate();
  //                   dataFormatada = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
  //                 }

  //                 return Container(
  //                   margin: const EdgeInsets.only(bottom: 12),
  //                   padding: const EdgeInsets.all(15),
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey[50],
  //                     borderRadius: BorderRadius.circular(15),
  //                     border: Border.all(color: Colors.grey[200]!),
  //                   ),
  //                   child: Row(
  //                     mainAxisAlignment: MainAxisAlignment.spaceAround,
  //                     children: [
  //                       _timeHistorico("AZUL", jogo['gols_total_azul'] ?? 0, Colors.blue),
  //                       Column(
  //                         children: [
  //                           Text("VS", style: GoogleFonts.bebasNeue(color: Colors.grey[400], fontSize: 16)),
  //                           Text(dataFormatada, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  //                         ],
  //                       ),
  //                       _timeHistorico("VERM", jogo['gols_total_vermelho'] ?? 0, Colors.red),
  //                     ],
  //                   ),
  //                 );
  //               },
  //             );
  //           },
  //         ),
  //       ),
  //     ],
  //   );
  // }

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

  Widget _buildBotaoPartidaAtiva(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Busca partidas que ainda não foram finalizadas
      stream: FirebaseFirestore.instance
          .collection('partidas_ativas')
          .where('orgId', isEqualTo: widget.orgId) // Garante que é deste time
          .where('status', isEqualTo: 'em_andamento')
          .limit(1) // Só precisamos do jogo atual
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Se não tem jogo, não mostra nada
        }

        var partida = snapshot.data!.docs.first; // Pega a partida atual

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: InkWell(
            onTap: () {
              if (partida['tipo_jogo'] == 'fixo') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlacarFixoPage(partidaId: partida.id, orgId: widget.orgId),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlacarPage(partidaId: partida.id, orgId: widget.orgId),
                  ),
                );
              }
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

  Widget _buildCardJogador(DocumentSnapshot doc, int index, BuildContext context, int limiteVagas) {
    final user = FirebaseAuth.instance.currentUser;
    final dados = doc.data() as Map<String, dynamic>?;

    String nome = dados?['nome'] ?? "Jogador";
    String posicao = dados?['posicao'] ?? "Geral";
    String uidJogador = dados?['uid'] ?? "";

    bool isSuplente = index >= limiteVagas;
    // O botão de desistir aparece se for o próprio jogador logado
    bool ehDonoDaVaga = user != null && user.uid == uidJogador;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 12, 63, 14),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isSuplente ? Colors.orange.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: isSuplente ? Colors.orange[800] : Colors.green[700],
          child: Text(
            "${index + 1}",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(nome.toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 18, letterSpacing: 1.1)),
        subtitle: Text(posicao, style: TextStyle(color: isSuplente ? Colors.orange[200]?.withOpacity(0.5) : Colors.white38)),
        trailing: ehDonoDaVaga
            ? IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20),
                onPressed: () => _confirmarDesistencia(doc.id, context),
                tooltip: "Desistir da vaga",
              )
            : (isSuplente ? const Icon(Icons.hourglass_empty, color: Colors.orange, size: 18) : const Icon(Icons.check_circle, color: Colors.green, size: 18)),
      ),
    );
  }

  void _confirmarDesistencia(String docId, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("DESISTIR DA VAGA?", style: GoogleFonts.bebasNeue(color: Colors.white)),
        content: const Text("Tem certeza que deseja sair da lista de presença?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).collection('presencas').doc(docId).delete();

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você saiu da lista.")));
            },
            child: const Text(
              "SAIR DO JOGO",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
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
