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

  String? posicaoSelecionada;
  final List<String> posicoes = ['Goleiro', 'Zagueiro', 'Lateral', 'Meia', 'Atacante'];

  Future signUp() async {
    try {
      // Cria o usuário no Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());

      // Salva dados adicionais no Firestore
      await FirebaseFirestore.instance.collection('jogadores').doc(userCredential.user!.uid).set({
        'nome': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'data_cadastro': DateTime.now(),
        'posicao': posicaoSelecionada,
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false, // Remove todas as telas anteriores da pilha
        );
      }

      // Navigator.pop(context); // Volta para o login após o sucesso
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Erro ao escalar jogador")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Novo Contrato", style: GoogleFonts.bebasNeue(fontSize: 45, color: Colors.white)),
              Text("Preencha seus dados para entrar no time", style: TextStyle(color: Colors.white70, fontSize: 16)),
              SizedBox(height: 40),

              // Campo Nome
              _buildField(controller: _nameController, hint: "Nome Completo", icon: Icons.person),
              SizedBox(height: 20),

              // Campo Email
              _buildField(controller: _emailController, hint: "E-mail de Contato", icon: Icons.email),
              SizedBox(height: 20),

              // Campo Senha
              _buildField(controller: _passwordController, hint: "Senha de Acesso", icon: Icons.lock, isObscure: true),
              SizedBox(height: 20),

              _buildFieldPos(controller: _passwordController, hint: "Posição em Campo", icon: Icons.sports_soccer),

              SizedBox(height: 50),

              // Botão de Cadastro
              GestureDetector(
                onTap: signUp,
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.yellow[700], // Cor de destaque (cartão amarelo/ouro)
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      "ASSINAR CONTRATO",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          labelText: 'Em que posição você joga?',
          labelStyle: const TextStyle(color: Colors.white70), // Cor da label quando parada
          floatingLabelStyle: const TextStyle(color: Colors.white), // Cor da label quando sobe
          border: InputBorder.none, // Remove a linha padrão para usar a do Container
        ),
        // 2. Estilo do texto selecionado dentro do campo
        style: const TextStyle(color: Colors.white, fontSize: 16),
        // 3. Cor do ícone de seta e do fundo do menu suspenso
        iconEnabledColor: Colors.white,
        dropdownColor: Colors.grey[850], // Cor de fundo da lista que abre
        value: posicaoSelecionada,
        items: posicoes
            .map(
              (pos) => DropdownMenuItem(
                value: pos,
                child: Text(pos, style: const TextStyle(color: Colors.white)),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => posicaoSelecionada = value),
        validator: (value) => value == null ? 'Selecione uma posição' : null,
      ),
    );
  }
}
