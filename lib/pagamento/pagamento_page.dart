import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PagamentoPixPage extends StatefulWidget {
  final String? docId;

  const PagamentoPixPage({super.key, this.docId});
  @override
  _PagamentoPixPageState createState() => _PagamentoPixPageState();
}

class _PagamentoPixPageState extends State<PagamentoPixPage> {
  late Stream<DocumentSnapshot> _cobrancaStream;

  @override
  void initState() {
    super.initState();
    // Inicializa o Stream uma única vez quando a tela abre
    _cobrancaStream = FirebaseFirestore.instance.collection('cobrancas').doc(widget.docId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pagamento Pix")),
      body: Center(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _cobrancaStream,
          builder: (context, snapshot) {
            // 1. Erro de conexão (Internet caiu, etc)
            if (snapshot.hasError) {
              return Center(child: Text("Erro de conexão: ${snapshot.error}"));
            }

            // 2. Estado de carregamento inicial
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // 3. Verificação REAL de existência
            // snapshot.data é o DocumentSnapshot. O .exists é a propriedade oficial.
            if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
              return Center(child: Text("Documento não encontrado no banco: ${widget.docId}"));
            }
            // Pega os dados do documento
            var dados = snapshot.data!.data() as Map<String, dynamic>;
            debugPrint("LOG_PIX: Campos no documento: ${dados.keys.toList()}");
            debugPrint("LOG_PIX: Conteúdo do campo pix: ${dados['pix']}");
            final Map<dynamic, dynamic>? pixMap = dados['pix'] as Map?;
            print("DADOS PIXXXX: ${widget.docId} - ${pixMap}");

            if (pixMap == null) {
              return const Text("Aguardando geração do QR Code...");
            }

            // Se deu erro na função
            if (dados['status'] == 'erro') {
              return Text("Erro ao gerar Pix: ${dados['erroLog']}");
            }

            // Se chegou aqui, o Pix existe!
            String base64Image = dados['pix']['qrCodeBase64'];
            String copiaECola = dados['pix']['copiaECola'];
            print(base64Image);

            String cleanBase64 = base64Image.split(',').last;

            // Se deu tudo certo, exibe os dados do Pix
            return Column(
              children: [
                Image.memory(base64Decode(cleanBase64), width: 250, height: 250, fit: BoxFit.contain),
                const SizedBox(height: 20),
                SelectableText(copiaECola),
                ElevatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: copiaECola));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copiado!")));
                  },
                  child: const Text("Copiar Código Pix"),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
