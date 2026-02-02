import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LiturgiaScreen extends StatefulWidget {
  const LiturgiaScreen({super.key});

  @override
  State<LiturgiaScreen> createState() => _LiturgiaScreenState();
}

class _LiturgiaScreenState extends State<LiturgiaScreen> {
  final DateTime _dataFixa = DateTime.now();

  final List<String> _opcoesEventos = [
    'Oração Inicial', 'Oração de Confissão', 'Momento de Intercessão', 'Oração Final',
    'Leitura Bíblica', 'Leitura Bíblica Alternada', 'Louvor', 'Ofertório', 'Mensagem Bíblica', 'Santa Ceia', 'Outro'
  ];

  String _getDocId() {
    return DateFormat('yyyy-MM-dd').format(_dataFixa);
  }

  void _showDirecaoDialog(String? valorAtual) {
    final controller = TextEditingController(text: valorAtual ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Direção do Culto"),
        content: TextField(
          controller: controller, 
          decoration: const InputDecoration(labelText: "Responsável", border: OutlineInputBorder())
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('liturgia').doc(_getDocId()).set({
                'direcao': controller.text,
                'data_referencia': Timestamp.fromDate(_dataFixa), // Importante para o índice do Firebase
              }, SetOptions(merge: true));
              Navigator.pop(context);
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  void _showItemDialog({Map<String, dynamic>? itemExistente, int? index}) {
    String? tipoSelecionado = itemExistente?['titulo'] ?? _opcoesEventos.first;
    final detalhesController = TextEditingController(text: itemExistente?['detalhes'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          
          // LÓGICA DO RÓTULO DINÂMICO
          String labelDinamico = "Detalhes";
          if (tipoSelecionado == 'Leitura Bíblica') {
            labelDinamico = "Versículo";
          } else if (tipoSelecionado == 'Ofertório') {
            labelDinamico = "Hino";
          }

          return AlertDialog(
            title: Text(itemExistente == null ? "Novo Evento" : "Editar Evento"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tipoSelecionado,
                  decoration: const InputDecoration(labelText: "Evento", border: OutlineInputBorder()),
                  items: _opcoesEventos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    setStateDialog(() => tipoSelecionado = val);
                  },
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: detalhesController, 
                  decoration: InputDecoration(
                    labelText: labelDinamico, // Rótulo que muda sozinho
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () async {
                  final novoItem = {'titulo': tipoSelecionado, 'detalhes': detalhesController.text};
                  final docRef = FirebaseFirestore.instance.collection('liturgia').doc(_getDocId());
                  
                  var snap = await docRef.get();
                  List items = snap.exists ? List.from(snap.data()!['itens'] ?? []) : [];
                  
                  if (index == null) {
                    items.add(novoItem);
                  } else {
                    items[index] = novoItem;
                  }
                  
                  await docRef.set({
                    'itens': items,
                    'data_referencia': Timestamp.fromDate(_dataFixa),
                  }, SetOptions(merge: true));
                  Navigator.pop(context);
                },
                child: const Text("Salvar"),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Liturgia", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('liturgia').doc(_getDocId()).snapshots(),
            builder: (context, snapshot) {
              String direcao = "Não informado";
              if (snapshot.hasData && snapshot.data!.exists) {
                direcao = snapshot.data!['direcao'] ?? "Não informado";
              }
              return ListTile(
                title: const Text("DIREÇÃO", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                subtitle: Text(direcao, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.deepOrange), 
                  onPressed: () => _showDirecaoDialog(direcao)
                ),
              );
            },
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('liturgia').doc(_getDocId()).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text("Nenhum evento."));
                List itens = snapshot.data!['itens'] ?? [];

                if (itens.isEmpty) return const Center(child: Text("Lista vazia."));

                return ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, index) {
                    final item = itens[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(item['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item['detalhes'] ?? ""),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showItemDialog(itemExistente: item, index: index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                itens.removeAt(index);
                                await FirebaseFirestore.instance.collection('liturgia').doc(_getDocId()).update({'itens': itens});
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showItemDialog(),
      ),
    );
  }
}