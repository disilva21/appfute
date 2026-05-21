import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PagamentoPixModal extends StatelessWidget {
  final String docId;
  const PagamentoPixModal({super.key, required this.docId});

  // Cor principal do tema (Verde Pix/Sucesso)
  final Color primaryGreen = const Color(0xFF00A335);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('cobrancas').doc(docId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator(color: primaryGreen)),
            );
          }

          final dados = snapshot.data!.data() as Map<String, dynamic>;
          final pix = dados['pix'] as Map?;
          final status = dados['status'] ?? 'pendente';

          if (status == 'pago') {
            return _buildSucesso(context);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle (Barrinha cinza de arrastar)
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 20),

              // Título com ícone
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pix, color: primaryGreen, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    "Pagamento Pix",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "Escaneie o QR Code ou copie o código abaixo",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              if (pix == null) ...[
                // Loading elegante enquanto a Function processa
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: primaryGreen),
                      const SizedBox(height: 16),
                      const Text("Gerando cobrança...", style: TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ] else ...[
                // QR Code com borda verde
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: primaryGreen.withOpacity(0.3), width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Image.memory(base64Decode(pix['qrCodeBase64'].toString().split(',').last), width: 220, height: 220),
                ),
                const SizedBox(height: 24),

                // Valor (Se você tiver o campo valor no documento)
                if (dados['valor'] != null) Text("R\$ ${dados['valor'].toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),

                const SizedBox(height: 16),

                // Botão de Copiar Estilizado
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pix['copiaECola']));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: primaryGreen, content: const Text("Código Pix Copiado!")));
                    },
                    icon: const Icon(Icons.copy, color: Colors.white),
                    label: const Text(
                      "COPIAR CÓDIGO PIX",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botão de Voltar/Cancelar
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Fechar", style: TextStyle(color: Colors.grey[600])),
                ),
              ],
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSucesso(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícone Animado ou Grande de Check
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF00A335), // Verde Pix
            size: 100,
          ),
          const SizedBox(height: 20),
          const Text(
            "PAGAMENTO RECEBIDO!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF00A335)),
          ),
          const SizedBox(height: 10),
          const Text(
            "Organização criada com sucesso.\nObrigado pelo pagamento!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A335),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "CONCLUIR",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
