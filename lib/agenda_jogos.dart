import 'package:appfute/widgets/nova_agenda_modal.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AgendaJogosPage extends StatelessWidget {
  final String organizacaoId; // ID da sua Organização ativa
  final bool isAdmin;

  const AgendaJogosPage({super.key, required this.organizacaoId, required this.isAdmin});

  void _abrirModalCadastro(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite ajustar ao tamanho do teclado
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => NovaAgendaModal(organizacaoDonaId: organizacaoId),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, String agendaId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // O usuário precisa clicar em sim ou não
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Excluir Agenda'),
          content: const Text('Tem certeza que deseja excluir este jogo da agenda? Esta ação não pode ser desfeita.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop(); // Fecha o alerta sem fazer nada
              },
            ),
            TextButton(
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onPressed: () {
                // 1. Fecha o modal de confirmação
                Navigator.of(context).pop();

                // 2. Chame aqui a sua lógica para deletar o item!
                _deletarAgenda(agendaId, context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletarAgenda(String id, BuildContext context) async {
    await FirebaseFirestore.instance.collection('organizacoes').doc(organizacaoId).collection('agenda').doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agenda excluída com sucesso!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      appBar: AppBar(
        title: Text("Agenda de Jogos", style: GoogleFonts.bebasNeue(letterSpacing: 1.5).copyWith(color: Colors.white)),
        backgroundColor: Colors.green[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // STREAM DA SUBCOLLECTION AGENDA
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organizacoes')
            .doc(organizacaoId)
            .collection('agenda')
            .orderBy('dataJogo', descending: false) // Próximos jogos primeiro
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Erro ao carregar agenda.", style: TextStyle(color: Colors.white)),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Nenhum jogo agendado.", style: TextStyle(color: Colors.white)),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var jogo = snapshot.data!.docs[index];
              DateTime data = (jogo['dataJogo'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[300],
                child: ListTile(
                  leading: Icon(Icons.sports_soccer, color: Colors.green[900], size: 40),
                  title: Text("VS ${jogo['nomeTimeAdversario']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("📅 ${DateFormat('dd/MM/yyyy - HH:mm').format(data)}\n📍 ${jogo['local']}"),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      // Passa o id da agenda atual para a confirmação
                      _confirmarExclusao(context, jogo.id);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),

      // BOTÃO NOVA AGENDA
      floatingActionButton: !isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirModalCadastro(context),
              backgroundColor: Colors.yellow[700],
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                "Nova Agenda",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}
