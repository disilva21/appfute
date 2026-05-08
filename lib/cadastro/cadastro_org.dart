import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:appfute/home.dart';
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

  void _criarOrganizacao() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true); // Se você tiver um loader

    try {
      // 1. Gerar o código curto (Ex: FG82PL)
      String orgId = gerarCodigoTime();

      // 2. Referência para o documento da organização
      DocumentReference orgRef = FirebaseFirestore.instance.collection('organizacoes').doc(orgId);

      // 3. Salvar os dados da organização (Documento Pai)
      await orgRef.set({'nome': _nomeController.text.trim(), 'dia_semana': posicaoSelecionada, 'codigo_acesso': orgId, 'criador_uid': user.uid, 'data_criacao': FieldValue.serverTimestamp()});

      // Dentro de _criarOrganizacao
      var jogadorRoot = await FirebaseFirestore.instance.collection('jogadores').doc(user.uid).get();
      // 4. GRAVAR O JOGADOR (Subcoleção Crítica)
      // Importante: Usamos orgRef.collection(...) para garantir o caminho correto
      await orgRef.collection('jogadores').doc(user.uid).set({
        'nome': jogadorRoot['nome'],
        'posicao': jogadorRoot['posicao'], // Certifique-se de pegar a variável do Dropdown
        'gols_carreira': 0,
        'is_admin': true,
        'uid': user.uid, // Guardar o UID dentro do doc também ajuda em buscas
      });

      // 5. Vincular o usuário no mapa global de acesso (users_lookup)
      await FirebaseFirestore.instance.collection('users_lookup').doc(user.uid).set({
        'organizacoes': FieldValue.arrayUnion([orgId]),
        'ultima_org_acessada': orgId,
      }, SetOptions(merge: true));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[900],
      appBar: AppBar(title: Text("CRIAR ORGANIZAÇÃO", style: GoogleFonts.bebasNeue())),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Campo Nome
            _buildField(controller: _nomeController, hint: "Nome da Organização", icon: Icons.person),
            SizedBox(height: 20),
            _buildFieldPos(controller: _diaJogoController, hint: "Dia do Jogo", icon: Icons.calendar_today),

            SizedBox(height: 30),
            GestureDetector(
              onTap: _criarOrganizacao,
              child: Container(
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.yellow[700], // Cor de destaque (cartão amarelo/ouro)
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    "CRIAR ORGANIZAÇÃO",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, bool isObscure = false}) {
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
}
