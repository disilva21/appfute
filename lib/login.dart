import 'package:appfute/widgets/version_app.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:appfute/cadastro/cadastro.dart';
import 'package:appfute/main.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _obscurePassword = true; // 👁️ Controle de visibilidade da senha
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future signIn() async {
    if (_isLoading) return; // Impede cliques múltiplos se já estiver carregando

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 25, left: 25, right: 25),
        decoration: BoxDecoration(
          color: Colors.grey[950],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "RECUPERAR ACESSO",
              textAlign: TextAlign.center,
              style: GoogleFonts.bebasNeue(fontSize: 28, color: Colors.yellow[700]),
            ),
            const SizedBox(height: 10),
            const Text(
              "Enviaremos um link de redefinição para o seu e-mail de cadastro.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 25),
            _buildModalField(controller: _resetEmailController, hint: "SEU E-MAIL DE CADASTRO", icon: Icons.email_outlined),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow[700],
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: _resetEmailController.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-mail enviado! Verifique sua caixa de entrada."), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: E-mail não encontrado.")));
                  }
                }
              },
              child: const Text(
                "ENVIAR LINK",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildModalField({required TextEditingController controller, required String hint, required IconData icon}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.yellow[700]),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.yellow[700]!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Captura a altura total da tela para fazer o card ocupar o espaço restante de forma elegante
    final double alturaTela = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF051E07), // Garante uma cor de fundo sólida caso o gradiente falhe
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.green[900]!, Colors.green[850] ?? const Color(0xFF0C4B11), const Color(0xFF051E07)]),
        ),
        padding: EdgeInsets.symmetric(horizontal: 25),
        // 🚀 CORREÇÃO CRÍTICA: O Scroll agora protege a tela inteira contra quebras de tamanho
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              // Garante que o container se estique pelo tamanho total da tela do aparelho
              constraints: BoxConstraints(minHeight: alturaTela - MediaQuery.of(context).padding.top),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),

                  // ⚽ Área do Escudo / Logo
                  Center(child: Image.asset('assets/logo/logo_appfute.png', height: 100, fit: BoxFit.contain)),
                  const SizedBox(height: 15),

                  Center(
                    child: Text("ENTRE EM CAMPO PARA JOGAR", style: GoogleFonts.bebasNeue(fontSize: 22, color: Colors.white70, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 30),

                  // 🎴 Card de Formulário Moderno e Fluido (Sem Expanded para não crashar o layout)
                  Container(
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(Radius.circular(45))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 📝 Input de E-mail
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: "E-mail do Jogador",
                              labelStyle: const TextStyle(color: Colors.black45),
                              prefixIcon: const Icon(Icons.email_outlined, color: Colors.green),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.green, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 🔑 Input de Senha com o Olho Ocultor/Visualizador
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: "Senha Tática",
                              labelStyle: const TextStyle(color: Colors.black45),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.green),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black45),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.green, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 🔍 Esqueci Minha Senha Alinhado à Direita
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _recuperarSenha,
                              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                              child: const Text("Esqueci minha senha", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(height: 25),

                          // 💾 BOTÃO 1: Entrar com Loading Integrado
                          ElevatedButton(
                            onPressed: _isLoading ? null : signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text(
                                    "ENTRAR NO TIME",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // 📋 BOTÃO 2: Criar Conta
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CadastroPage()));
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.green[800]!, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: Text(
                              "CRIAR NOVA CONTA",
                              style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(margin: EdgeInsets.only(top: 35), padding: EdgeInsets.only(bottom: 5.0), child: VersaoDoAppWidget(corTexto: null)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
