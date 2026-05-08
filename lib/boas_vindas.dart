import 'package:flutter/material.dart';
import 'package:appfute/cadastro/cadastro_org.dart';
import 'package:appfute/entrar_para_time.dart';
import 'package:google_fonts/google_fonts.dart';

class BoasVindasPage extends StatelessWidget {
  const BoasVindasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Mantendo o fundo escuro padrão de apps de esportes/futebol
      backgroundColor: Colors.grey[900],
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone ou Logo Central
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.sports_soccer, size: 80, color: Colors.greenAccent),
            ),
            const SizedBox(height: 40),

            // Título Principal (Bebas Neue)
            Text(
              "BEM-VINDO AO APPFUTE",
              textAlign: TextAlign.center,
              style: GoogleFonts.bebasNeue(fontSize: 42, color: Colors.white, letterSpacing: 2),
            ),

            // Subtítulo explicativo
            Text(
              "Para começar, você precisa se juntar a um grupo existente ou fundar o seu próprio time.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),

            const SizedBox(height: 60),

            // Botão: CRIAR TIME
            _buildActionButton(
              context: context,
              label: "CRIAR NOVO TIME",
              icon: Icons.add_box_rounded,
              color: Colors.greenAccent,
              textColor: Colors.black,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CadastroOrganizacaoPage()));
              },
            ),

            const SizedBox(height: 20),

            // Botão: ENTRAR EM TIME EXISTENTE
            _buildActionButton(
              context: context,
              label: "ENTRAR EM UM TIME",
              icon: Icons.group_add_rounded,
              color: Colors.transparent,
              textColor: Colors.white,
              isOutlined: true,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EntrarTimePage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper para criar os botões no padrão da tela de cadastro
  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor),
        label: Text(label, style: GoogleFonts.bebasNeue(fontSize: 20, color: textColor, letterSpacing: 1.2)),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : color,
          elevation: isOutlined ? 0 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isOutlined ? const BorderSide(color: Colors.white24, width: 2) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
