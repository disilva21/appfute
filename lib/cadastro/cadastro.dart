import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appfute/main.dart';
import 'package:google_fonts/google_fonts.dart';

class CadastroPage extends StatefulWidget {
  @override
  _CadastroPageState createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apelidoController = TextEditingController();

  String? posicaoSelecionada;
  final List<String> posicoes = ['Goleiro', 'Zagueiro', 'Lateral', 'Volante', 'Meia', 'Atacante'];

  // 🌟 VARIÁVEL DE CONTROLE DE LOADING
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Adiciona ouvintes para atualizar o estado do botão dinamicamente ao digitar
    _nameController.addListener(_atualizarEstado);
    _emailController.addListener(_atualizarEstado);
    _passwordController.addListener(_atualizarEstado);
    _apelidoController.addListener(_atualizarEstado);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _apelidoController.dispose();
    super.dispose();
  }

  void _atualizarEstado() {
    setState(() {});
  }

  Future signUp() async {
    // 🛡️ Ativa o loading e trava o clique duplo
    setState(() => _isLoading = true);

    try {
      // Cria o usuário no Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());

      // Salva dados adicionais no Firestore
      await FirebaseFirestore.instance.collection('jogadores').doc(userCredential.user!.uid).set({
        'nome': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'data_cadastro': DateTime.now(),
        'posicao': posicaoSelecionada,
        'apelido': _apelidoController.text.trim(),
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Erro ao escalar jogador")));
      }
    } finally {
      // 🛡️ Desativa o loading caso ocorra um erro para o usuário tentar novamente
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool camposPreenchidos =
        posicaoSelecionada != null &&
        _nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty &&
        _apelidoController.text.trim().isNotEmpty;

    // O botão só fica clicável se todos os campos estiverem preenchidos E não estiver carregando
    final bool botaoHabilitado = camposPreenchidos && !_isLoading;

    return Scaffold(
      backgroundColor: Colors.green[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Novo Contrato", style: GoogleFonts.bebasNeue(fontSize: 45, color: Colors.white)),
              const Text("Preencha seus dados para entrar no time", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 40),

              // Campo Nome
              _buildField(controller: _nameController, hint: "Nome Completo", icon: Icons.person),
              const SizedBox(height: 20),

              // Campo Apelido
              _buildField(controller: _apelidoController, hint: "Apelido", icon: Icons.tag),
              const SizedBox(height: 20),

              // Campo Email
              _buildField(controller: _emailController, hint: "E-mail de Contato", icon: Icons.email),
              const SizedBox(height: 20),

              // Campo Senha
              _buildField(controller: _passwordController, hint: "Senha de Acesso", icon: Icons.lock, isObscure: true),
              const SizedBox(height: 20),

              _buildFieldPos(hint: "Posição em Campo", icon: Icons.sports_soccer),

              const SizedBox(height: 50),

              // ⚽ Botão de Cadastro com Tratamento de Loading
              GestureDetector(
                onTap: botaoHabilitado ? () async => await signUp() : null,
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    color: botaoHabilitado ? Colors.yellow[700] : Colors.grey[700],
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: botaoHabilitado ? [BoxShadow(color: Colors.yellow[700]!.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))] : [],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black, // Combina com o contraste do fundo amarelo
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            "ASSINAR CONTRATO",
                            style: TextStyle(color: botaoHabilitado ? Colors.black : Colors.white24, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, bool isObscure = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
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

  Widget _buildFieldPos({required String hint, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white24),
      ),
      child: DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'Em que posição você joga?',
          labelStyle: TextStyle(color: Colors.white70),
          floatingLabelStyle: TextStyle(color: Colors.white),
          border: InputBorder.none,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        iconEnabledColor: Colors.white,
        dropdownColor: Colors.grey[850],
        value: posicaoSelecionada,
        items: posicoes
            .map(
              (pos) => DropdownMenuItem(
                value: pos,
                child: Text(pos, style: const TextStyle(color: Colors.white)),
              ),
            )
            .toList(),
        onChanged: _isLoading ? null : (value) => setState(() => posicaoSelecionada = value),
        validator: (value) => value == null ? 'Selecione uma posição' : null,
      ),
    );
  }
}
