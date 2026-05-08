import 'package:flutter/material.dart';
import 'package:appfute/home.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EntrarTimePage extends StatefulWidget {
  const EntrarTimePage({super.key});

  @override
  State<EntrarTimePage> createState() => _EntrarTimePageState();
}

class _EntrarTimePageState extends State<EntrarTimePage> {
  final _codigoController = TextEditingController();
  bool _isLoading = false;

  void _processarEntrada() async {
    final user = FirebaseAuth.instance.currentUser;
    final codigo = _codigoController.text.trim().toUpperCase();

    if (user == null || codigo.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // 1. Verifica se a organização com esse código existe
      var orgDoc = await FirebaseFirestore.instance.collection('organizacoes').doc(codigo).get();

      if (!orgDoc.exists) {
        throw "Código não encontrado. Verifique com seu administrador.";
      }

      // 2. Vincula o usuário ao time no users_lookup
      await FirebaseFirestore.instance.collection('users_lookup').doc(user.uid).set({
        'organizacoes': FieldValue.arrayUnion([codigo]),
        'ultima_org_acessada': codigo,
      }, SetOptions(merge: true));

      var jogadorRoot = await FirebaseFirestore.instance.collection('jogadores').doc(user.uid).get();
      // 4. GRAVAR O JOGADOR (Subcoleção Crítica)

      // 3. Cria o perfil do jogador na subcoleção da organização
      await FirebaseFirestore.instance.collection('organizacoes').doc(codigo).collection('jogadores').doc(user.uid).set({
        'nome': jogadorRoot['nome'],
        'posicao': jogadorRoot['posicao'],
        'gols_carreira': 0,
        'is_admin': false,
        'uid': user.uid,
      });

      // 4. Sucesso! Vai para a Home
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => HomePage(orgId: codigo)), (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text("ENTRAR EM UM TIME", style: GoogleFonts.bebasNeue(fontSize: 40, color: Colors.white, letterSpacing: 1.5)),
            Text("Digite o código de 6 dígitos fornecido pelo seu administrador para se juntar ao grupo.", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
            const SizedBox(height: 40),

            // Campo de Entrada do Código
            TextField(
              controller: _codigoController,
              autofocus: true,
              style: GoogleFonts.bebasNeue(fontSize: 32, color: Colors.greenAccent, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "CÓDIGO",
                hintStyle: GoogleFonts.bebasNeue(color: Colors.white10, letterSpacing: 8),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.greenAccent, width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),

            const SizedBox(height: 30),

            // Botão Confirmar
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processarEntrada,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : Text("CONFIRMAR ENTRADA", style: GoogleFonts.bebasNeue(fontSize: 20, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
