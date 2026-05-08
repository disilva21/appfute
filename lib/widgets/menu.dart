import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:appfute/artilharia_page.dart';
import 'package:appfute/login.dart';
import 'package:appfute/main.dart';
import 'package:appfute/widgets/uppercase.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDrawer extends StatelessWidget {
  final String orgIdAtual;

  const CustomDrawer({super.key, required this.orgIdAtual});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: Colors.grey[900],
      child: Column(
        children: [
          // 1. Cabeçalho com dados do Usuário (da coleção raiz 'jogadores')
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('jogadores').doc(user?.uid).get(),
            builder: (context, snapshot) {
              String nome = "Jogador";
              String email = user?.email ?? "";

              if (snapshot.hasData && snapshot.data!.exists) {
                nome = snapshot.data!['nome'];
              }

              return UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Colors.green[900]),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.yellow[700],
                  child: Text(nome[0], style: const TextStyle(fontSize: 30, color: Colors.black)),
                ),
                accountName: Text(nome, style: GoogleFonts.bebasNeue(fontSize: 20)),
                accountEmail: Text(email),
              );
            },
          ),

          // 2. Título da seção de times
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text(
              "MEUS TIMES",
              style: TextStyle(color: Colors.yellow[700], fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),

          // 3. Lista de Organizações (do users_lookup)
          // 3. Lista de Organizações (do users_lookup)
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              // Buscamos o documento que contém a lista de IDs de times do usuário
              future: FirebaseFirestore.instance.collection('users_lookup').doc(user?.uid).get(),
              builder: (context, lookupSnap) {
                if (lookupSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!lookupSnap.hasData || !lookupSnap.data!.exists) {
                  return const Center(
                    child: Text("Nenhum time encontrado", style: TextStyle(color: Colors.white54)),
                  );
                }

                // Pegamos a lista de IDs (ex: ["ABC123", "XYZ456"])
                List<dynamic> orgsIds = lookupSnap.data!['organizacoes'] ?? [];

                // Agora usamos o ListView.builder para criar uma linha para cada ID da lista
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: orgsIds.length,
                  itemBuilder: (context, index) {
                    // AQUI CRIAMOS AS VARIÁVEIS PARA CADA ITEM DA LISTA
                    String idTime = orgsIds[index];
                    bool isAtual = idTime == orgIdAtual;

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('organizacoes').doc(idTime).get(),
                      builder: (context, orgSnap) {
                        if (!orgSnap.hasData) return const SizedBox();

                        String nomeTime = orgSnap.data!['nome'] ?? "Time sem nome";

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('organizacoes').doc(idTime).collection('jogadores').doc(user?.uid).get(),
                          builder: (context, statsSnap) {
                            int gols = 0;
                            String posicao = "Jogador";
                            if (statsSnap.hasData && statsSnap.data!.exists) {
                              gols = statsSnap.data!['gols_carreira'] ?? 0;
                              posicao = statsSnap.data!['posicao'] ?? "Jogador";
                            }

                            return ListTile(
                              leading: Icon(Icons.sports_soccer, color: isAtual ? Colors.yellow[700] : Colors.white54),
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
                                onPressed: () => _mostrarModalCompartilhar(context, nomeTime, idTime),
                              ),
                              onTap: isAtual ? null : () => _alternarTime(context, idTime),
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

          const Divider(color: Colors.white24),

          _buildMenuAction(
            icon: Icons.format_list_numbered_outlined,
            title: "Artilharia do Time",
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ArtilhariaPage(orgId: orgIdAtual)));
            },
          ),

          const Divider(color: Colors.white24),
          _buildMenuAction(icon: Icons.update_rounded, title: "Mudar Minha Posição", onTap: () => _abrirDialogoTrocarPosicao(context)),

          const Divider(color: Colors.white24),

          _buildMenuAction(
            icon: Icons.add,
            title: "Entrar em  novo Time",
            onTap: () {
              _mostrarDialogoEntrarTime(context);
            },
          ),

          // Menus de Ação
          const Divider(color: Colors.white24),

          const SizedBox(height: 60),

          // 4. Opções de Ação
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Sair do App", style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => LoginPage()), (route) => false);
              }

              // 2. Só então, deslogue do Firebase
              await FirebaseAuth.instance.signOut();
              // O AuthWrapper no main.dart cuidará do redirecionamento
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuAction({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: Colors.white70, size: 20),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: onTap,
    );
  }

  void _mostrarModalCompartilhar(BuildContext context, String nomeTime, String codigo) {
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
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check, color: Colors.black),
                  label: const Text(
                    "ENTENDIDO",
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

  void _mostrarDialogoEntrarTime(BuildContext context) {
    final TextEditingController _codigoController = TextEditingController();
    String? posicaoSelecionada;
    final List<String> posicoes = ['Goleiro', 'Zagueiro', 'Lateral', 'Meia', 'Atacante'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que a modal suba quando o teclado abrir
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Ajuste para o teclado
          ),
          decoration: BoxDecoration(
            color: Colors.green[900], // Identidade visual verde escuro
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de arraste
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 30),

                Text("NOVA CONVOCAÇÃO", style: GoogleFonts.bebasNeue(fontSize: 35, color: Colors.white)),
                const Text("Digite o código do time para entrar em campo", style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 30),

                // Campo de Código Estilizado
                _buildModalField(controller: _codigoController, hint: "CÓDIGO DO TIME", icon: Icons.qr_code, upperCase: true),
                const SizedBox(height: 20),

                // Dropdown de Posição Estilizado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: DropdownButtonFormField<String>(
                    dropdownColor: Colors.grey[850],
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    iconEnabledColor: Colors.white,

                    decoration: InputDecoration(
                      labelText: 'SUA POSIÇÃO',
                      labelStyle: const TextStyle(color: Colors.white70), // Cor da label quando parada
                      floatingLabelStyle: const TextStyle(color: Colors.white), // Cor da label quando sobe
                      border: InputBorder.none, // Remove a linha padrão para usar a do Container
                    ),

                    items: posicoes
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p, style: const TextStyle(color: Colors.white)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setDialogState(() => posicaoSelecionada = val),
                  ),
                ),
                const SizedBox(height: 40),

                // Botão de Ação Estilizado (Amarelo)
                GestureDetector(
                  onTap: () => _processarEntradaNoTime(context, _codigoController.text.trim(), posicaoSelecionada),
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(color: Colors.yellow[700], borderRadius: BorderRadius.circular(15)),
                    child: const Center(
                      child: Text(
                        "CONFIRMAR ENTRADA",
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalField({required TextEditingController controller, required String hint, required IconData icon, bool upperCase = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: controller,
        // Usamos formatters em vez de onChanged para manipular o texto
        inputFormatters: [if (upperCase) UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(6)],
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.yellow[700]),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Future<void> _processarEntradaNoTime(BuildContext context, String codigo, String? posicao) async {
    if (codigo.isEmpty || posicao == null) return;
    final user = FirebaseAuth.instance.currentUser;

    try {
      // 1. Verificar se o time existe
      var orgDoc = await FirebaseFirestore.instance.collection('organizacoes').doc(codigo).get();

      if (!orgDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código inválido!")));
        return;
      }

      // 2. Buscar dados globais do jogador (daquela nossa coleção raiz 'jogadores')
      var userGlobal = await FirebaseFirestore.instance.collection('jogadores').doc(user!.uid).get();

      // 3. Adicionar o jogador à SUBCOLEÇÃO do novo time
      await orgDoc.reference.collection('jogadores').doc(user.uid).set({
        'nome': userGlobal['nome'],
        'posicao': posicao,
        'gols_carreira': 0,
        'is_admin': false, // Novo membro não entra como admin por padrão
        'uid': user.uid,
      });

      // 4. ATUALIZAR O LOOKUP (O segredo do Multi-Tenant)
      // Aqui usamos arrayUnion para não apagar os times que ele já tinha!
      await FirebaseFirestore.instance.collection('users_lookup').doc(user.uid).set({
        'organizacoes': FieldValue.arrayUnion([codigo]),
        'ultima_org_acessada': codigo,
      }, SetOptions(merge: true));

      // 5. Resetar o app para a Home do novo time
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false);
      }
    } catch (e) {
      print("Erro ao entrar: $e");
    }
  }

  void _abrirDialogoTrocarPosicao(BuildContext context) {
    String? novaPosicao;
    final List<String> posicoes = ['Goleiro', 'Zagueiro', 'Lateral', 'Meia', 'Atacante'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("TROCAR POSIÇÃO", style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Selecione sua nova posição para este time:", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButton<String>(
                  value: novaPosicao,
                  hint: const Text("Escolher...", style: TextStyle(color: Colors.white54)),
                  dropdownColor: Colors.grey[850],
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: posicoes
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p, style: const TextStyle(color: Colors.white)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => novaPosicao = val),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCELAR", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
              onPressed: novaPosicao == null
                  ? null
                  : () async {
                      final uid = FirebaseAuth.instance.currentUser!.uid;

                      // Atualiza na subcoleção do time específico
                      await FirebaseFirestore.instance.collection('organizacoes').doc(orgIdAtual).collection('jogadores').doc(uid).update({'posicao': novaPosicao});

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Posição atualizada com sucesso!")));
                      }
                    },
              child: const Text(
                "CONFIRMAR",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
