import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:appfute/cadastro/cadastro.dart';
import 'package:appfute/main.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future signIn() async {
    try {
      setState(() => _isLoading = true);
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());

      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      if (e.code == 'user-not-found') {
        errorMessage = "Usuário não encontrado. Verifique seu e-mail.";
      } else if (e.code == 'wrong-password') {
        errorMessage = "Senha incorreta. Tente novamente.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "E-mail inválido. Verifique o formato.";
      } else if (e.code == 'invalid-credential') {
        errorMessage = "Credenciais inválidas. Verifique seu e-mail e senha.";
      } else {
        errorMessage = e.message ?? "Erro ao entrar. Tente novamente.";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _recuperarSenha() {
    final TextEditingController _resetEmailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("RECUPERAR ACESSO", style: GoogleFonts.bebasNeue(fontSize: 25, color: Colors.white)),
            const SizedBox(height: 10),
            const Text(
              "Enviaremos um link de redefinição para o seu e-mail.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),

            // Reaproveitando seu estilo de campo
            _buildModalField(controller: _resetEmailController, hint: "SEU E-MAIL DE CADASTRO", icon: Icons.email_outlined),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700], padding: const EdgeInsets.symmetric(vertical: 15)),
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: _resetEmailController.text.trim());
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-mail enviado! Verifique sua caixa de entrada.")));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: E-mail não encontrado.")));
                  }
                },
                child: const Text(
                  "ENVIAR E-MAIL",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
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
        onChanged: upperCase ? (value) => controller.text = value.toUpperCase() : null,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, colors: [Colors.green[900]!, Colors.green[700]!, Colors.green[400]!]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 80),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("AppFute Login", style: GoogleFonts.bebasNeue(fontSize: 50, color: Colors.white)),
                  Text("Entre em campo para jogar", style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(60), topRight: Radius.circular(60)),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        SizedBox(height: 40),
                        // Campo de E-mail
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: Color.fromRGBO(0, 100, 0, .2), blurRadius: 20, offset: Offset(0, 10))],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  hintText: "E-mail do Jogador",
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.email, color: Colors.green),
                                ),
                              ),
                              Divider(color: Colors.grey[200]),
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  hintText: "Senha Tática",
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.lock, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20),

                        GestureDetector(
                          onTap: () {
                            _recuperarSenha();
                          },
                          child: Container(
                            height: 30,
                            padding: EdgeInsets.symmetric(horizontal: 20),

                            // decoration: BoxDecoration(
                            //   borderRadius: BorderRadius.circular(50),
                            //   color: const Color.fromARGB(255, 235, 42, 29),
                            // ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "Esqueci minha senha",
                                style: TextStyle(color: const Color.fromARGB(255, 83, 83, 83), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        // Botão de Login
                        GestureDetector(
                          onTap: signIn,
                          child: Container(
                            height: 50,
                            margin: EdgeInsets.symmetric(horizontal: 50),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), color: Colors.green[800]),
                            child: Center(
                              child: Text(
                                "ENTRAR",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CadastroPage()));
                          },
                          child: Container(
                            height: 50,
                            margin: EdgeInsets.symmetric(horizontal: 50),

                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), color: const Color.fromARGB(255, 12, 118, 189)),
                            child: Center(
                              child: Text(
                                "Criar conta",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
