import 'dart:io';

import 'package:appfute/main.dart';
import 'package:appfute/upload_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: StreamBuilder<DocumentSnapshot>(
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
                        String posicao = "Atacante";
                        bool isCriador = false;
                        bool isAdmin = false;
                        if (statsSnap.hasData && statsSnap.data!.exists) {
                          gols = statsSnap.data!['gols_carreira'] ?? 0;
                          posicao = statsSnap.data!['posicao'] ?? "Atacante";
                          isCriador = statsSnap.data!['criador'] ?? false;
                          isAdmin = statsSnap.data!['is_admin'] ?? false;
                        }

                        if (!statsSnap.hasData) return const SizedBox();

                        return Card(
                          color: Colors.white.withOpacity(0.05),
                          elevation: 1, // Controle da sombra do card
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // O raio dos cantos (Radius)
                            side: BorderSide(
                              color: isAtual ? Colors.amberAccent.withOpacity(0.6) : Colors.transparent, // Cor da borda
                              width: 2.0, // Espessura da borda
                            ),
                          ),

                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 50,
                              height: 50,
                              margin: const EdgeInsets.only(left: 10),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[300]!, width: 2),
                              ),
                              child: ClipOval(
                                child: urlEscudo != null && urlEscudo != ""
                                    ? Image.network(
                                        urlEscudo,
                                        width: 50, // ⚽ Passa o tamanho certinho do container
                                      )
                                    : const Icon(Icons.shield, size: 30, color: Colors.grey),
                              ),
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
                            trailing: isAdmin == true && isCriador == true
                                ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.white),
                                    color: Colors.grey[900], // Fundo combinando com o tema escuro
                                    onSelected: (String acao) async {
                                      if (acao == 'editar_time') {
                                        if (orgSnap.hasData && orgSnap.data!.exists) {
                                          if (!context.mounted) return;

                                          Future.delayed(Duration.zero, () {
                                            // 🚀 A CORREÇÃO: Passa o DocumentSnapshot puro do time (sem o [0])
                                            _abrirModalEditarTime(context, orgSnap.data!);
                                          });
                                        }
                                      } else if (acao == 'compartilhar') {
                                        _mostrarModalCompartilhar(context, nomeTime, idTime, urlEscudo);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                      // OPÇÃO 1: PROMOVER OU REBAIXAR ADMIN
                                      PopupMenuItem<String>(
                                        value: 'editar_time',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, color: Colors.yellow[700], size: 20),
                                            SizedBox(width: 10),
                                            Text("Editar time", style: TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                      ),

                                      const PopupMenuDivider(), // Linha divisória fina
                                      // OPÇÃO 2: REMOVER DO TIME
                                      PopupMenuItem<String>(
                                        value: 'compartilhar',
                                        child: Row(
                                          children: [
                                            Icon(Icons.share, color: Colors.yellow[700], size: 20),
                                            SizedBox(width: 10),
                                            Text("Compartilhar", style: TextStyle(color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : IconButton(
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
      ),
    );
  }

  void _abrirModalEditarTime(BuildContext context, dynamic timeSnapshot) {
    String nomeAtual = '';
    String tipoJogoAtual = 'fixo';
    String? urlEscudoAtual;

    try {
      if (timeSnapshot is DocumentSnapshot && timeSnapshot.exists) {
        final dados = timeSnapshot.data() as Map<String, dynamic>?;
        if (dados != null) {
          nomeAtual = dados['nome']?.toString() ?? '';
          urlEscudoAtual = dados['urlEscudo']?.toString();

          String bancoTipo = dados['tipo_jogo']?.toString() ?? 'fixo';
          if (bancoTipo == 'Pelada/Sorteio' || bancoTipo == 'pelada') {
            tipoJogoAtual = 'pelada';
          } else {
            tipoJogoAtual = 'fixo';
          }
        }
      }
    } catch (e) {
      print("Erro ao mapear dados na entrada da modal: $e");
    }

    final TextEditingController nomeController = TextEditingController(text: nomeAtual);
    String? tipoJogoSelecionado = tipoJogoAtual;
    String? urlEscudoTemporario = urlEscudoAtual;
    bool carregandoNovaImagem = false;

    final UploadService uploadService = UploadService();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.green[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            // 🚀 Função simplificada e focada 100% no Android Nativo
            Future<void> alterarLogo() async {
              setModalState(() => carregandoNovaImagem = true);

              String idDoTime = (timeSnapshot is DocumentSnapshot) ? timeSnapshot.id : 'time_upload';

              try {
                // Chamada direta do seu UploadService baseado em File (sem código web)
                String? novaUrl = await uploadService.selecionarEUpload(pasta: 'escudos', idDocumento: idDoTime);

                if (novaUrl != null && novaUrl.isNotEmpty) {
                  setModalState(() {
                    urlEscudoTemporario = novaUrl;
                  });
                }
              } catch (e) {
                print("Erro ao usar UploadService na modal: $e");
              } finally {
                setModalState(() => carregandoNovaImagem = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "EDITAR DADOS DO TIME",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 15),

                    // Área do Escudo com Clique Nativo
                    Center(
                      child: GestureDetector(
                        onTap: carregandoNovaImagem ? null : alterarLogo,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipOval(
                              child: Container(
                                width: 100,
                                height: 100,
                                color: Colors.white.withOpacity(0.05),
                                child: urlEscudoTemporario != null && urlEscudoTemporario!.isNotEmpty
                                    ? Image.network(
                                        urlEscudoTemporario!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, size: 50, color: Colors.white38),
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(child: CircularProgressIndicator(color: Colors.white24));
                                        },
                                      )
                                    : const Icon(Icons.shield, size: 50, color: Colors.white38),
                              ),
                            ),
                            if (carregandoNovaImagem)
                              const CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.black54,
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            if (!carregandoNovaImagem)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.yellow[700],
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Campo de Texto: Nome
                    TextField(
                      controller: nomeController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nome do Time',
                        labelStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.yellow[700]!),
                        ),
                        prefixIcon: const Icon(Icons.shield_outlined, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Combo Seletor: Tipo de Jogo
                    DropdownButtonFormField<String>(
                      value: tipoJogoSelecionado,
                      dropdownColor: Colors.grey[900],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Tipo de Jogo',
                        labelStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.yellow[700]!),
                        ),
                        prefixIcon: const Icon(Icons.sports_soccer, color: Colors.white54),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'fixo', child: Text('Time Fixo (Elenco)')),
                        DropdownMenuItem(value: 'pelada', child: Text('Pelada / Sorteio')),
                      ],
                      onChanged: (String? novoValor) {
                        setModalState(() {
                          tipoJogoSelecionado = novoValor;
                        });
                      },
                    ),
                    const SizedBox(height: 30),

                    // Botão de Confirmação
                    ElevatedButton(
                      onPressed: () async {
                        if (nomeController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O nome do time não pode ficar vazio!')));
                          return;
                        }

                        String idDoTime = (timeSnapshot is DocumentSnapshot) ? timeSnapshot.id : '';

                        await FirebaseFirestore.instance.collection('organizacoes').doc(idDoTime).update({
                          'nome': nomeController.text.trim(),
                          'tipo_jogo': tipoJogoSelecionado,
                          'urlEscudo': urlEscudoTemporario,
                        });

                        if (!context.mounted) return;
                        Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados do time atualizados com sucesso!'), backgroundColor: Colors.green));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[700],
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        "SALVAR ALTERAÇÕES",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
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
