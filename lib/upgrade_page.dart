import 'package:appfute/pagamento/pagamento.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class UpgradePage extends StatefulWidget {
  final String orgId;
  const UpgradePage({super.key, required this.orgId});

  @override
  State<UpgradePage> createState() => _UpgradePageState();
}

class _UpgradePageState extends State<UpgradePage> {
  int _limiteAtual = 6;
  final int _baseJogadores = 6;
  final double _precoBase = 29.00;
  final double _precoAdicional = 2.00;
  bool _carregando = true;
  int _novaQuantidade = 6;

  @override
  void initState() {
    super.initState();
    _buscarLimiteAtual();
  }

  Future<void> _buscarLimiteAtual() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).get();

      if (doc.exists && mounted) {
        setState(() {
          // Busca o limite do Firebase, se não existir, assume o padrão 6
          _limiteAtual = doc.data()?['limite_jogadores'] ?? 6;
          _carregando = false;
          _novaQuantidade = _limiteAtual;
        });
      }
    } catch (e) {
      debugPrint("Erro ao buscar limite: $e");
      if (mounted) setState(() => _carregando = false);
    }
  }

  double _calcularTotal() {
    // Se ele não moveu o slider, o custo é zero
    if (_novaQuantidade <= _limiteAtual) return 0.0;

    // CASO 1: Ele está no Grátis (6) e vai para o Pro (7 ou mais)
    if (_limiteAtual <= 6) {
      double precoBase = 29.00;
      return precoBase + ((_novaQuantidade - 7) * 2.00);
    }
    // CASO 2: Ele já era Pro (ex: tinha 10) e quer aumentar (ex: para 15)
    // Ele paga apenas R$ 2,00 por cada novo jogador adicionado
    else {
      return (_novaQuantidade - _limiteAtual) * 2.00;
    }
  }

  @override
  Widget build(BuildContext context) {
    double total = _calcularTotal();

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text("EXPANDIR TIME", style: GoogleFonts.bebasNeue(color: Colors.white)),
        backgroundColor: Colors.green[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("AUMENTE SEU ELENCO", style: GoogleFonts.bebasNeue(fontSize: 32, color: Colors.white)),
            const Text("Seu time cresceu? Libere mais vagas para novos craques entrarem em campo.", style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 40),

            // Card do Seletor
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("JOGADORES", style: TextStyle(color: Colors.white54)),
                      Text("$_novaQuantidade", style: GoogleFonts.bebasNeue(fontSize: 40, color: Colors.yellow[700])),
                    ],
                  ),
                  Slider(
                    activeColor: Colors.yellow[700],
                    value: _novaQuantidade.toDouble(),
                    min: _limiteAtual.toDouble(),
                    max: 50,
                    divisions: (50 - 6),
                    label: _novaQuantidade.toString(),
                    inactiveColor: Colors.white12,
                    onChanged: (val) => setState(() => _novaQuantidade = val.round()),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("6 (Base)", style: TextStyle(color: Colors.white38, fontSize: 12)),
                      Text("50 (Máx)", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Detalhamento do Preço
            _buildInfoRow("Preço Base (após 6 jogadores)", "R\$ 29,00"),
            if (_novaQuantidade > 6) _buildInfoRow("Jogadores extras (${_novaQuantidade - 6}x)", "R\$ ${((_novaQuantidade - 6) * _precoAdicional).toStringAsFixed(2)}"),

            const Divider(color: Colors.white10, height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TOTAL A PAGAR",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text("R\$ ${total.toStringAsFixed(2)}", style: GoogleFonts.bebasNeue(fontSize: 45, color: Colors.green[400])),
              ],
            ),

            const SizedBox(height: 40),

            // Botão de Pagamento
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () => solicitarPix(total),
                icon: const Icon(Icons.pix, color: Colors.black),
                label: const Text(
                  "GERAR PIX AGORA",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Center(
              child: Text("Liberação instantânea após o pagamento", style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  double calcularTotal() {
    if (_novaQuantidade <= 6) return 0.0; // Gratuito até 6

    return 29.0 + ((_novaQuantidade - 7) * 2.00);
  }

  String? docId;

  // Função para "pedir" a geração do Pix
  Future<void> solicitarPix(double valor) async {
    DocumentSnapshot config = await FirebaseFirestore.instance.collection('configuracao').doc('ziNL1wNtBbGRWSQHCRzQ').get();
    double valorFinal = 0.01;

    if (config.exists && config.data() != null) {
      final dadosConfig = config.data() as Map<String, dynamic>;
      if (dadosConfig.containsKey('valorPix') && (dadosConfig['valorPix'] as num).toDouble() > 0) {
        valorFinal = (dadosConfig['valorPix'] as num).toDouble();
      } else {
        valorFinal = valor;
      }
    } else {
      valorFinal = valor;
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
      await FirebaseFirestore.instance.collection('organizacoes').doc(widget.orgId).set({'limite_jogadores': _novaQuantidade}, SetOptions(merge: true));

      // Opcional: Mostre um feedback final
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Organização atualizada com sucesso!")));
    }
    // Navigator.push(context, MaterialPageRoute(builder: (context) => PagamentoPixPage(docId: docId)));
  }
}
