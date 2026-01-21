import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MonthlyBirthdaysWidget extends StatelessWidget {
  const MonthlyBirthdaysWidget({super.key});

  // Função para mostrar o contato
  void _showContactDialog(BuildContext context, String nome, String whatsapp) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.contact_phone, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(child: Text("Contato de $nome", style: const TextStyle(fontSize: 18))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("WhatsApp / Telefone:"),
              const SizedBox(height: 10),
              SelectableText(
                whatsapp.isEmpty ? "Não cadastrado" : whatsapp,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fechar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    String mesAtual = DateFormat('MMMM', 'pt_BR').format(now);
    mesAtual = mesAtual[0].toUpperCase() + mesAtual.substring(1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erro: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;
        List<Map<String, dynamic>> aniversariantes = [];

        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>;
          String nome = data['nome_completo'] ?? data['nome'] ?? 'Sem Nome';
          
          // --- CAPTURA O WHATSAPP ---
          String whatsapp = data['whatsapp'] ?? data['celular'] ?? data['telefone'] ?? '';

          var rawDate = data['data_nascimento'] ?? data['dataNascimento'] ?? data['nascimento'] ?? data['nasc'];
          if (rawDate == null) continue;

          DateTime? nascimento;
          try {
            if (rawDate is Timestamp) {
              nascimento = rawDate.toDate();
            } else if (rawDate is String) {
              String dateStr = rawDate.trim();
              if (dateStr.contains('/')) {
                nascimento = DateFormat('dd/MM/yyyy').parse(dateStr);
              } else if (dateStr.contains('-')) {
                nascimento = DateTime.parse(dateStr);
              }
            }
          } catch (e) { continue; }

          if (nascimento != null && nascimento.month == now.month) {
            aniversariantes.add({
              'dia': nascimento.day,
              'nome': nome,
              'whatsapp': whatsapp, // Salva para usar no clique
              'foto': data['foto_url'],
            });
          }
        }

        aniversariantes.sort((a, b) => (a['dia'] as int).compareTo(b['dia'] as int));

        if (aniversariantes.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.event_busy, color: Colors.grey),
                SizedBox(width: 10),
                Expanded(child: Text("Nenhum aniversariante neste mês.", style: TextStyle(color: Colors.grey))),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.pink[50], 
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.pink[100]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cake, color: Colors.pink[400], size: 24),
                  const SizedBox(width: 8),
                  Text("Aniversariantes de $mesAtual", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink[800])),
                ],
              ),
              const Divider(color: Colors.pink),
              const SizedBox(height: 5),

              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: aniversariantes.length,
                  separatorBuilder: (c, i) => const Divider(height: 10),
                  itemBuilder: (context, index) {
                    var niver = aniversariantes[index];
                    
                    // --- TORNAR O ITEM CLICÁVEL (INKWELL) ---
                    return InkWell(
                      onTap: () {
                        // Chama a função para mostrar o dialog com o contato
                        _showContactDialog(context, niver['nome'], niver['whatsapp']);
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.pink[100]!),
                            ),
                            child: Text(
                              "${niver['dia'].toString().padLeft(2, '0')}",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink[700]),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(niver['nome'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                // Pequena dica visual que é clicável
                                if (niver['whatsapp'].toString().isNotEmpty)
                                  const Text("Ver contato", style: TextStyle(fontSize: 10, color: Colors.green)),
                              ],
                            ),
                          ),
                          const Icon(Icons.touch_app, size: 16, color: Colors.grey),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}