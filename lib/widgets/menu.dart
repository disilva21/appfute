import 'package:appfute/gerenciar_jogador.dart';
import 'package:appfute/meus_times.dart';
import 'package:appfute/upgrade_page.dart';
import 'package:appfute/upload_service.dart';
import 'package:appfute/widgets/version_app.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:appfute/artilharia_page.dart';
import 'package:appfute/login.dart';
import 'package:appfute/main.dart';
import 'package:appfute/widgets/uppercase.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDrawer extends StatefulWidget {
  final String orgIdAtual;

  const CustomDrawer({super.key, required this.orgIdAtual});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool _carregandoImagem = false;
  final UploadService _uploadService = UploadService();

  void _atualizarEscudo() async {
    setState(() => _carregandoImagem = true);

    // Geramos um ID temporário ou usamos o ID do time se já existir
    String idTemporarioTime = DateTime.now().millisecondsSinceEpoch.toString();

    await _uploadService.selecionarEUpload(pasta: 'perfil', idDocumento: idTemporarioTime);

    setState(() => _carregandoImagem = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    bool isAdmin = false;

    return Drawer(
      backgroundColor: const Color.fromARGB(255, 22, 66, 24),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('jogadores').doc(user?.uid).get(),
        builder: (context, snapshot) {
          // Enquanto carrega, podemos mostrar um loading ou o header vazio
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // 1. Pegamos os dados como um Mapa
          final dados = snapshot.data!.data() as Map<String, dynamic>?;

          // 2. Verificamos se o mapa contém a chave e se o valor é true
          if (dados != null && dados.containsKey('is_admin')) {
            isAdmin = dados['is_admin'] == true;
          } else {
            isAdmin = false; // Se o campo não existe, ele definitivamente não é admin
          }
          final nome = dados!['nome'] ?? "Jogador";
          final email = dados['email'] ?? "Sem email";
          String? urlFotoPerfil = dados['urlFotoPerfil'] ?? null;

          return Column(
            children: [
              // 1. Cabeçalho com dados do Usuário (da coleção raiz 'jogadores')
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: Colors.green[900]),
                currentAccountPicture: GestureDetector(
                  onTap: _carregandoImagem ? null : _atualizarEscudo,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: urlFotoPerfil != null ? NetworkImage(urlFotoPerfil) : null,
                        child: urlFotoPerfil == null ? const Icon(Icons.shield, size: 50, color: Colors.grey) : null,
                      ),
                      if (_carregandoImagem)
                        const CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.black45,
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      if (!_carregandoImagem)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),

                accountName: Text(nome, style: GoogleFonts.bebasNeue(fontSize: 16)),
                accountEmail: Text(email),
              ),

              _buildMenuAction(
                icon: Icons.shield_rounded,
                title: "Meus Times",
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MeusTimesPage(orgIdAtual: widget.orgIdAtual)));
                },
              ),

              const Divider(color: Colors.white24),

              _buildMenuAction(
                icon: Icons.sports_soccer_rounded,
                title: "Artilharia do Time",
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ArtilhariaPage(orgId: widget.orgIdAtual)));
                },
              ),

              const Divider(color: Colors.white24),
              _buildMenuAction(icon: Icons.update_rounded, title: "Mudar Minha Posição", onTap: () => _abrirDialogoTrocarPosicao(context)),

              if (isAdmin == true) const Divider(color: Colors.white24),
              if (isAdmin == true) _buildMenuAction(icon: Icons.calendar_month_outlined, title: "Agendar Janela da Lista", onTap: () => _configurarJanelaRecorrente(context)),

              if (isAdmin == true) const Divider(color: Colors.white24),
              if (isAdmin == true) _buildMenuAction(icon: Icons.confirmation_number_outlined, title: "Definir Vagas da Partida", onTap: () => _mostrarAjusteVagas(context)),

              if (isAdmin == true) const Divider(color: Colors.white24),
              if (isAdmin == true)
                _buildMenuAction(
                  icon: Icons.rocket_launch,
                  title: "Fazer Upgrade do Time",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => UpgradePage(orgId: widget.orgIdAtual)));
                  },
                ),

              if (isAdmin == true) const Divider(color: Colors.white24),
              if (isAdmin == true)
                _buildMenuAction(
                  icon: Icons.group_remove,
                  title: "Gerenciar Atletas",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => GerenciarJogadoresPage(orgId: widget.orgIdAtual)));
                  },
                ),
              // Dentro da Column do seu CustomDrawer
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

              // 4. Opções de Ação
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Sair do App", style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => LoginPage()), (route) => false);
                  }
                },
              ),

              const Divider(color: Colors.white24),
              const Padding(padding: EdgeInsets.only(bottom: 5.0), child: VersaoDoAppWidget()),
            ],
          );
        },
      ),
    );
  }

  void _mostrarAjusteVagas(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text("VAGAS DA LISTA", style: GoogleFonts.bebasNeue(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Ex: 20",
            hintStyle: TextStyle(color: Colors.white30),
            labelText: "Máximo de Confirmados",
            labelStyle: TextStyle(color: Colors.yellow),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () async {
              int novasVagas = int.tryParse(controller.text) ?? 20;
              await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgIdAtual).update({'vagas_partida': novasVagas});
              Navigator.pop(context);
            },
            child: const Text("SALVAR"),
          ),
        ],
      ),
    );
  }

  Future<void> _configurarJanelaRecorrente(BuildContext context) async {
    int? diaAbertura;
    int? diaFechamento;

    final List<String> dias = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

    // 1. Selecionar Dia de Abertura (Pode usar um SimpleDialog ou Dropdown)
    diaAbertura = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("DIA DE ABERTURA"),
        children: dias.asMap().entries.map((e) => SimpleDialogOption(onPressed: () => Navigator.pop(context, e.key + 1), child: Text(e.value))).toList(),
      ),
    );

    if (diaAbertura == null) return;

    // 2. Selecionar Hora de Abertura
    TimeOfDay? horaAbertura = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (horaAbertura == null) return;

    // 3. Repetir para Fechamento...
    diaFechamento = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("DIA DE FECHAMENTO"),
        children: dias.asMap().entries.map((e) => SimpleDialogOption(onPressed: () => Navigator.pop(context, e.key + 1), child: Text(e.value))).toList(),
      ),
    );

    if (diaFechamento == null) return;

    TimeOfDay? horaFechamento = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (horaFechamento == null) return;

    // 4. Salvar no Firebase
    await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgIdAtual).update({
      'abertura_dia': diaAbertura,
      'abertura_hora': "${horaAbertura.hour}:${horaAbertura.minute.toString().padLeft(2, '0')}",
      'fechamento_dia': diaFechamento,
      'fechamento_hora': "${horaFechamento.hour}:${horaFechamento.minute.toString().padLeft(2, '0')}",
    });
  }

  Widget _buildMenuAction({required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: Colors.yellow[700], size: 20),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: onTap,
    );
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
      int limite = orgDoc['limite_jogadores'] ?? 6;

      // 2. Contar quantos jogadores já existem na subcoleção
      var jogadoresSnapshot = await orgDoc.reference.collection('jogadores').get();
      int totalAtual = jogadoresSnapshot.docs.length;

      if (totalAtual >= limite) {
        // Bloqueia a entrada e avisa
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Este time atingiu o limite de jogadores. Fale com o organizador!")));
        return;
      }

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
                      await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgIdAtual).collection('jogadores').doc(uid).update({'posicao': novaPosicao});

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Posição atualizada com sucesso!")));
                      }
                    },
              child: const Text(
                "CONFIRMAR",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
