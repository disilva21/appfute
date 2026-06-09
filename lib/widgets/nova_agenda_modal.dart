import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class NovaAgendaModal extends StatefulWidget {
  final String organizacaoDonaId; // ID da organização que está criando o jogo

  const NovaAgendaModal({super.key, required this.organizacaoDonaId});

  @override
  State<NovaAgendaModal> createState() => _NovaAgendaModalState();
}

class _NovaAgendaModalState extends State<NovaAgendaModal> {
  final _formKey = GlobalKey<FormState>();
  final _localController = TextEditingController();
  final _nomeManualController = TextEditingController();

  DateTime? _dataSelecionada;
  TimeOfDay? _horaSelecionada;

  String? _organizacaoSelecionadaId;
  bool _adversarioNaoCadastrado = false;
  bool _salvando = false;

  // Selecionar Data e Hora
  Future<void> _selecionarDataHora() async {
    final data = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));

    if (data != null) {
      final hora = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (hora != null) {
        setState(() {
          _dataSelecionada = data;
          _horaSelecionada = hora;
        });
      }
    }
  }

  // Função para salvar no Firestore
  Future<void> _salvarJogo() async {
    if (!_formKey.currentState!.validate() || _dataSelecionada == null || _horaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos e a data/hora!")));
      return;
    }

    setState(() => _salvando = true);

    try {
      final DateTime dataCompleta = DateTime(_dataSelecionada!.year, _dataSelecionada!.month, _dataSelecionada!.day, _horaSelecionada!.hour, _horaSelecionada!.minute);

      String nomeAdversario = "";
      if (_adversarioNaoCadastrado) {
        nomeAdversario = _nomeManualController.text.trim();
      } else {
        // Logica para pegar o nome da organização selecionada no Dropdown se necessário
        nomeAdversario = "Organização Cadastrada";
      }

      // Salvando na SUBCOLLECTION 'agenda' da Organização logada
      await FirebaseFirestore.instance.collection('organizacoes').doc(widget.organizacaoDonaId).collection('agenda').add({
        'nomeTimeAdversario': nomeAdversario,
        'organizacaoAdversariaId': _adversarioNaoCadastrado ? null : _organizacaoSelecionadaId,
        'dataJogo': Timestamp.fromDate(dataCompleta),
        'local': _localController.text.trim(),
        'criadoEm': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
    } catch (e) {
      print("Erro ao agendar: $e");
    } finally {
      setState(() => _salvando = false);
    }
  }

  // Função de Convite via Share
  void _convidarAdversario() {
    final String nome = _nomeManualController.text.trim();
    Share.share(
      "⚽ *Desafio Aceito, $nome!* ⚽\n\n"
      "Nosso jogo foi agendado no *AppFute*. Baixe o aplicativo para acompanhar a tabela, confirmação de elenco e estatísticas da partida!\n"
      "🔗 Link Android: https://play.google.com/store/apps/details?id=com.seuapp.appfute",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Evita o teclado cobrir a modal
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Agendar Novo Jogo",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
              ),
              const SizedBox(height: 20),

              // CHECKBOX: ADVERSÁRIO NÃO CADASTRADO
              CheckboxListTile(
                title: const Text("Se adversário NÃO estiver na lista abaixo, clique aqui"),
                value: _adversarioNaoCadastrado,
                activeColor: Colors.yellow[700],
                onChanged: (val) => setState(() => _adversarioNaoCadastrado = val ?? false),
              ),

              // LISTAGEM OU INPUT MANUAL
              if (!_adversarioNaoCadastrado) ...[
                // StreamBuilder buscando Organizações existentes do Firestore
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('organizacoes').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();

                    var docs = snapshot.data!.docs.where((d) => d.id != widget.organizacaoDonaId).toList();

                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Selecionar Organização Adversária"),
                      items: docs.map((doc) {
                        return DropdownMenuItem(value: doc.id, child: Text(doc['nome'] ?? ''));
                      }).toList(),
                      onChanged: (id) => setState(() => _organizacaoSelecionadaId = id),
                    );
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _nomeManualController,
                  decoration: const InputDecoration(labelText: "Nome do Time Adversário"),
                  onChanged: (text) => setState(() {}), // Atualiza para liberar botão de convite
                  validator: (v) => v!.isEmpty ? "Insira o nome do time" : null,
                ),
                if (_nomeManualController.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextButton.icon(
                      onPressed: _convidarAdversario,
                      icon: const Icon(Icons.share, color: Colors.green),
                      label: const Text("Convidar time para o AppFute", style: TextStyle(color: Colors.green)),
                    ),
                  ),
              ],
              const SizedBox(height: 16),

              // CAMPO LOCAL
              TextFormField(
                controller: _localController,
                decoration: const InputDecoration(labelText: "Local / Quadra / Campo"),
                validator: (v) => v!.isEmpty ? "Insira o local do jogo" : null,
              ),
              const SizedBox(height: 16),

              // BOTÃO DATA E HORA
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(_dataSelecionada == null ? "Selecionar Data e Hora" : "${DateFormat('dd/MM/yyyy').format(_dataSelecionada!)} às ${_horaSelecionada!.format(context)}"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _selecionarDataHora,
              ),
              const SizedBox(height: 30),

              // BOTÃO DE CONFIRMAÇÃO
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvarJogo,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                  child: _salvando
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "CRIAR AGENDA",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
