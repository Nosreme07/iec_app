import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'send_notification_screen.dart';

class NoticesHistoryScreen extends StatelessWidget {
  final String userRole;
  const NoticesHistoryScreen({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    // Define se o usuário tem permissão de gestão
    bool hasAdminAccess = userRole == 'admin' || userRole == 'financeiro';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mural de Avisos", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Busca os avisos do Firestore ordenados pelo mais recente
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Erro ao carregar avisos"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum aviso encontrado no mural."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              
              // Trata a data de postagem
              DateTime date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['title'] ?? 'Sem título',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                            ),
                          ),
                          if (hasAdminAccess)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') _confirmarExclusao(context, doc.id);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Excluir")],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(data['body'] ?? '', style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          "Postado em: $formattedDate",
                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // BOTÃO DE ADICIONAR: Só aparece para Admin/Financeiro
      floatingActionButton: hasAdminAccess
          ? FloatingActionButton(
              backgroundColor: Colors.blue[900],
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SendNotificationScreen()),
              ),
              child: const Icon(Icons.add_comment, color: Colors.white),
            )
          : null,
    );
  }

  void _confirmarExclusao(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Aviso?"),
        content: const Text("Isso removerá o aviso do mural para todos os membros."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('notices').doc(id).delete();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("EXCLUIR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}