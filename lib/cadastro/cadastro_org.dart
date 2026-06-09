import 'dart:convert';
import 'dart:math';

import 'package:appfute/pagamento/open_pix_service.dart';
import 'package:appfute/pagamento/pagamento.dart';
import 'package:appfute/pagamento/pagamento_page.dart';
import 'package:appfute/upload_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:appfute/home.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CadastroOrganizacaoPage extends StatefulWidget {
  @override
  _CadastroOrganizacaoPageState createState() => _CadastroOrganizacaoPageState();
}

class _CadastroOrganizacaoPageState extends State<CadastroOrganizacaoPage> {
  final _nomeController = TextEditingController();
  final _diaJogoController = TextEditingController();
  // Ex: Quarta-feira
  bool _isLoading = false;
  String? posicaoSelecionada;
  final List<String> dias = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
  String _tipoJogo = 'fixo'; // Valor padrão

  bool _carregandoImagem = false;
  final UploadService _uploadService = UploadService();
  String? _urlEscudo;

  void _atualizarEscudo() async {
    setState(() => _carregandoImagem = true);

    // Geramos um ID temporário ou usamos o ID do time se já existir
    String idTemporarioTime = DateTime.now().millisecondsSinceEpoch.toString();

    String? url = await _uploadService.selecionarEUpload(pasta: 'escudo', idDocumento: idTemporarioTime);

    if (url != null) {
      setState(() {
        _urlEscudo = url;
      });
    }

    setState(() => _carregandoImagem = false);
  }

  _criarOrganizacao() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true); // Se você tiver um loader

    try {
      // 1. Gerar o código curto (Ex: FG82PL)
      String orgId = gerarCodigoTime();

      // 2. Referência para o documento da organização
      DocumentReference orgRef = FirebaseFirestore.instance.collection('organizacoes').doc(orgId);

      // 3. Salvar os dados da organização (Documento Pai)
      await orgRef.set({
        'nome': _nomeController.text.trim(),
        'codigo_acesso': orgId,
        'criador_uid': user.uid,
        'limite_jogadores': quantidadeSelecionada,
        'tipo_jogo': _tipoJogo.toLowerCase(), // 'fixo' ou 'pelada'
        'data_criacao': FieldValue.serverTimestamp(),
        'vagas_partida': quantidadeSelecionada, // Campo para controlar as vagas restantes
        'abertura_dia': diaAbertura,
        'abertura_hora': "${horaAbertura!.hour}:${horaAbertura!.minute.toString().padLeft(2, '0')}",
        'fechamento_dia': diaFechamento,
        'fechamento_hora': "${horaFechamento!.hour}:${horaFechamento!.minute.toString().padLeft(2, '0')}",
        'urlEscudo': _urlEscudo, // Salva a URL do escudo se tiver sido carregada
      });

      // Dentro de _criarOrganizacao
      var jogadorRoot = await FirebaseFirestore.instance.collection('jogadores').doc(user.uid).get();
      // 4. GRAVAR O JOGADOR (Subcoleção Crítica)
      // Importante: Usamos orgRef.collection(...) para garantir o caminho correto
      await orgRef.collection('jogadores').doc(user.uid).set({
        'nome': jogadorRoot['nome'],
        'posicao': jogadorRoot['posicao'], // Certifique-se de pegar a variável do Dropdown
        'gols_carreira': 0,
        'is_admin': true,
        'criador': true,
        'apelido': jogadorRoot['apelido'],
        'uid': user.uid,
        'urlFotoPerfil': '',
      });

      // 5. Vincular o usuário no mapa global de acesso (users_lookup)
      await FirebaseFirestore.instance.collection('users_lookup').doc(user.uid).set({
        'organizacoes': FieldValue.arrayUnion([orgId]),
        'ultima_org_acessada': orgId,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('jogadores').doc(user.uid).set({'is_admin': true}, SetOptions(merge: true));

      // 6. Navegar para a Home
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => HomePage(orgId: orgId)), (route) => false);
      }
    } catch (e) {
      print("ERRO AO GRAVAR: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int? diaAbertura;
  int? diaFechamento;
  TimeOfDay? horaAbertura;
  TimeOfDay? horaFechamento;

  Future<void> _configurarJanelaRecorrente(BuildContext context) async {
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
    horaAbertura = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
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

    horaFechamento = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (horaFechamento == null) return;

    setState(() {}); // Atualiza a interface para mostrar que está configurado

    // // 4. Salvar no Firebase
    // await FirebaseFirestore.instance.collection('organizacoes').doc(orgId).update({
    //   'abertura_dia': diaAbertura,
    //   'abertura_hora': "${horaAbertura.hour}:${horaAbertura.minute.toString().padLeft(2, '0')}",
    //   'fechamento_dia': diaFechamento,
    //   'fechamento_hora': "${horaFechamento.hour}:${horaFechamento.minute.toString().padLeft(2, '0')}",
    // });
  }

  String gerarCodigoTime() {
    // Definimos os caracteres permitidos (removendo I, O, 1 e 0 por clareza)
    const String caracteres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    // Definimos o tamanho do código (6 caracteres é o padrão ideal para grupos)
    const int tamanho = 6;

    Random random = Random();

    // Gera uma sequência aleatória baseada nos caracteres permitidos
    String codigo = String.fromCharCodes(Iterable.generate(tamanho, (_) => caracteres.codeUnitAt(random.nextInt(caracteres.length))));

    return codigo;
  }

  Widget _buildTipoCard({required String label, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isActive ? Colors.yellow[700] : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isActive ? Colors.yellow[700]! : Colors.white24),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Colors.black : Colors.white54),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(color: isActive ? Colors.black : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D), // Fundo padrão dark do app
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("CRIAR ORGANIZAÇÃO", style: GoogleFonts.bebasNeue(letterSpacing: 2, color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildSectionTitle("Escudo do Time"),
                  GestureDetector(
                    onTap: _carregandoImagem ? null : _atualizarEscudo,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _urlEscudo != null ? NetworkImage(_urlEscudo!) : null,
                          child: _urlEscudo == null ? const Icon(Icons.shield, size: 50, color: Colors.grey) : null,
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
                  const SizedBox(height: 15),
                  // --- SEÇÃO 1: IDENTIDADE ---
                  _buildSectionTitle("Informações Gerais"),
                  _buildField(controller: _nomeController, hint: "Nome do seu Time/Organização", icon: Icons.sports_soccer, onChanged: () => setState(() {})),
                  const SizedBox(height: 25),

                  // --- SEÇÃO 2: REGRAS AUTOMÁTICAS ---
                  _buildSectionTitle("Regras da Lista Semanal"),
                  _buildConfigButton(
                    title: "Janela de Convocação",
                    subtitle: diaAbertura == null ? "Defina os dias e horários de abertura/fechamento" : "Configurado para ${dias[diaAbertura! - 1]}",
                    isConfigured: diaAbertura != null,
                    onTap: () => _configurarJanelaRecorrente(context),
                  ),
                  const SizedBox(height: 25),

                  // --- SEÇÃO 3: FORMATO ---
                  _buildSectionTitle("Formato do Jogo"),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTipoCard(label: "Time Fixo", icon: Icons.groups, isActive: _tipoJogo == 'fixo', onTap: () => setState(() => _tipoJogo = 'fixo')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTipoCard(label: "Pelada / Sorteio", icon: Icons.shuffle, isActive: _tipoJogo == 'pelada', onTap: () => setState(() => _tipoJogo = 'pelada')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // --- SEÇÃO 4: CAPACIDADE E PREÇO ---
                  _buildSectionTitle("Capacidade do Grupo"),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Slider(
                          activeColor: Colors.yellow[700],
                          inactiveColor: Colors.white12,
                          value: quantidadeSelecionada.toDouble(),
                          min: 6,
                          max: 50,
                          divisions: (50 - 6),
                          label: quantidadeSelecionada.toString(),
                          onChanged: (val) => setState(() => quantidadeSelecionada = val.round()),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Vagas: ", style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.white60)),
                            Text("$quantidadeSelecionada", style: GoogleFonts.bebasNeue(fontSize: 28, color: Colors.yellow[700])),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Investimento: ", style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.white60)),
                            Text(quantidadeSelecionada <= 6 ? "GRÁTIS" : "R\$ ${calcularTotal().toStringAsFixed(2)}", style: GoogleFonts.bebasNeue(fontSize: 28, color: Colors.green[400])),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- BOTÃO FINAL ---
                  _buildBottomButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS AUXILIARES PARA O PADRÃO VISUAL ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(title.toUpperCase(), style: GoogleFonts.bebasNeue(fontSize: 18, color: Colors.white70, letterSpacing: 1)),
    );
  }

  Widget _buildConfigButton({required String title, required String subtitle, required bool isConfigured, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isConfigured ? Colors.green.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isConfigured ? Colors.green.withOpacity(0.5) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(isConfigured ? Icons.check_circle : Icons.calendar_month, color: isConfigured ? Colors.green : Colors.yellow[700]),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  void _processarPagamento() async {
    final pixService = OpenPixService();
    final pix = await pixService.gerarCobrancaPix("Meu Time FC", 5000); // R$ 50,00

    if (pix != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1B5E20), // Seu Verde Gramado
          title: Text("PAGAMENTO VIA PIX", style: GoogleFonts.bebasNeue(color: Colors.yellow[700])),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(pix.qrCodeUrl, height: 200), // QR Code da API
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                icon: const Icon(Icons.copy, color: Colors.black),
                label: const Text("COPIAR CHAVE PIX", style: TextStyle(color: Colors.black)),
                onPressed: () {
                  // Clipboard.setData(ClipboardData(text: pix.brCode));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código copiado!")));
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> pagarMensalidadeTime(double preco, String nomeDoTime) async {
    try {
      // 1. Referencia a função
      // HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('gerarCobrancaPixEfi');
      HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'southamerica-east1').httpsCallable('gerarCobrancaPixEfi');

      // 2. Chama a função passando os dados que o TypeScript espera
      final response = await callable.call({'valor': preco, 'nomeTime': nomeDoTime});

      // 3. Extrai os dados do retorno
      if (response.data['success'] == true) {
        String qrCodeBase64 = response.data['qrcode']; // A imagem
        String copiaECola = response.data['copiaECola']; // O texto

        // Agora você chama um Modal para mostrar isso!
        _showPixModal(qrCodeBase64, copiaECola);
      } else {
        print("Erro no retorno: ${response.data['error']}");
      }
    } catch (e) {
      print("Erro ao chamar Cloud Function: $e");
    }
  }

  String? docId; // Variável para armazenar o ID do documento criado

  // Função para "pedir" a geração do Pix
  Future<void> solicitarPix() async {
    DocumentSnapshot config = await FirebaseFirestore.instance.collection('configuracao').doc('ziNL1wNtBbGRWSQHCRzQ').get();
    double valorFinal = 0.01;

    if (config.exists && config.data() != null) {
      final dadosConfig = config.data() as Map<String, dynamic>;
      if (dadosConfig.containsKey('valorPix') && (dadosConfig['valorPix'] as num).toDouble() > 0) {
        valorFinal = (dadosConfig['valorPix'] as num).toDouble();
      } else {
        valorFinal = double.parse(calcularTotal().toStringAsFixed(2));
      }
    } else {
      valorFinal = double.parse(calcularTotal().toStringAsFixed(2));
    }

    final docRef = await FirebaseFirestore.instance.collection('cobrancas').add({
      'valor': valorFinal,
      'nomeTime': 'Galo F.C',
      'status': 'pendente', // A função vai ler isso
      'criadoEm': FieldValue.serverTimestamp(),
    });

    setState(() {
      docId = docRef.id;
    });

    final pagouComSucesso = await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que a modal ocupe mais espaço se necessário
      isDismissible: false, // Impede que o usuário feche a modal clicando fora
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => PagamentoPixModal(docId: docRef.id),
    );

    // 3. Se o usuário clicou em concluir na modal (retornou true)
    if (pagouComSucesso == true) {
      // Chame sua função aqui!
      _criarOrganizacao();

      // Opcional: Mostre um feedback final
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Organização criada com sucesso!")));
    }
    // Navigator.push(context, MaterialPageRoute(builder: (context) => PagamentoPixPage(docId: docId)));
  }

  Widget _buildBottomButton() {
    final bool camposPreenchidos = diaAbertura != null && _nomeController.text.trim().isNotEmpty;
    bool isFree = quantidadeSelecionada <= 6;
    return GestureDetector(
      onTap: !camposPreenchidos
          ? null
          : () async {
              // Adicione async aqui se necessário
              if (isFree) {
                await _criarOrganizacao(); // 👈 Use parênteses e await
              } else {
                await solicitarPix();
              }
            },
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          color: camposPreenchidos ? Colors.yellow[700] : Colors.grey[700],
          borderRadius: BorderRadius.circular(20),
          boxShadow: camposPreenchidos ? [BoxShadow(color: Colors.yellow[700]!.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))] : [],
        ),
        child: Center(
          child: Text(
            isFree ? "CRIAR AGORA (GRÁTIS)" : "PROSSEGUIR PARA PAGAMENTO",
            style: GoogleFonts.bebasNeue(fontSize: 20, color: camposPreenchidos ? Colors.black : Colors.white24, letterSpacing: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, bool isObscure = false, VoidCallback? onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: TextStyle(color: Colors.white),
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          icon: Icon(icon, color: Colors.yellow[700]),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white54),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFieldPos({required TextEditingController controller, required String hint, required IconData icon, bool isObscure = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Selecione o dia do jogo',
          labelStyle: const TextStyle(color: Colors.white70), // Cor da label quando parada
          floatingLabelStyle: const TextStyle(color: Colors.white), // Cor da label quando sobe
          border: InputBorder.none, // Remove a linha padrão para usar a do Container
        ),
        // 2. Estilo do texto selecionado dentro do campo
        style: const TextStyle(color: Colors.white, fontSize: 16),
        // 3. Cor do ícone de seta e do fundo do menu suspenso
        iconEnabledColor: Colors.white,
        dropdownColor: Colors.grey[850],
        value: posicaoSelecionada,
        items: dias
            .map(
              (pos) => DropdownMenuItem(
                value: pos,
                child: Text(pos, style: TextStyle(color: Colors.white)),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => posicaoSelecionada = value),
        validator: (value) => value == null ? 'Selecione um dia' : null,
      ),
    );
  }

  int quantidadeSelecionada = 6;

  double calcularTotal() {
    if (quantidadeSelecionada <= 6) return 0.0; // Gratuito até 6

    return 29.0 + ((quantidadeSelecionada - 7) * 2.00);
  }

  double calcularPreco(int quantidadeDesejada) {
    const int baseJogadores = 6;
    const double precoBase = 29.00;
    const double precoAdicional = 2.00;

    if (quantidadeDesejada <= baseJogadores) {
      return precoBase;
    } else {
      int extras = quantidadeDesejada - baseJogadores;
      return precoBase + (extras * precoAdicional);
    }
  }

  void _showPixModal(String base64String, String copiaECola) {
    // A string da Efí costuma vir com "data:image/png;base64,..."
    // Precisamos remover esse cabeçalho se ele existir
    final String pureBase64 = base64String.contains(',') ? base64String.split(',').last : base64String;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B5E20), // Seu verde gramado
        title: Text("PAGUE COM PIX", style: GoogleFonts.bebasNeue(color: Colors.yellow[700])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Transforma a string Base64 em imagem real
            Image.memory(base64Decode(pureBase64), width: 200, height: 200),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                // Lógica de Clipboard para o Copia e Cola
                Clipboard.setData(ClipboardData(text: copiaECola));
              },
              child: const Text("COPIAR CÓDIGO PIX"),
            ),
          ],
        ),
      ),
    );
  }

  void _exibirModalPix(String codigoPix) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 25),
            Icon(Icons.pix, color: Colors.green[400], size: 50),
            const SizedBox(height: 15),
            Text("QUASE LÁ!", style: GoogleFonts.bebasNeue(fontSize: 28, color: Colors.white)),
            const Text(
              "Copie o código abaixo e pague no app do seu banco para liberar as vagas instantaneamente.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),

            // Campo do Código Copia e Cola
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: codigoPix));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código Pix copiado!")));
              },
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.green[400]!.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        codigoPix,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.copy, color: Colors.green[400]),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Botão de Finalizar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  _criarOrganizacao();
                  Navigator.pop(context);
                  // Aqui você pode colocar o app para "ouvir" o Firestore
                  // esperando o campo 'limite_jogadores' mudar
                },
                child: const Text(
                  "JÁ PAGUEI",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCELAR", style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}
