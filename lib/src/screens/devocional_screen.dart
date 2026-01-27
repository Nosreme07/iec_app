import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DevocionalScreen extends StatefulWidget {
  const DevocionalScreen({super.key});

  @override
  State<DevocionalScreen> createState() => _DevocionalScreenState();
}

class _DevocionalScreenState extends State<DevocionalScreen> {
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _versiculoController = TextEditingController();
  final TextEditingController _textoController = TextEditingController();
  final TextEditingController _autorController = TextEditingController(); // <--- NOVO CONTROLLER
  bool _isSaving = false;

  // --- FUNÇÃO PARA ADICIONAR DEVOCIONAL ---
  void _showAddDialog(BuildContext context) {
    _tituloController.clear();
    _versiculoController.clear();
    _textoController.clear();
    _autorController.clear(); // Limpa o campo autor

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Novo Devocional"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: "Título", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              
              // --- CAMPO MANUAL DE AUTOR ---
              TextField(
                controller: _autorController,
                decoration: const InputDecoration(labelText: "Autor", border: OutlineInputBorder()),
              ),
              
              const SizedBox(height: 10),
              TextField(
                controller: _versiculoController,
                decoration: const InputDecoration(labelText: "Versículo Chave", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _textoController,
                maxLines: 8,
                decoration: const InputDecoration(labelText: "Mensagem", border: OutlineInputBorder(), alignLabelWithHint: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              // Verifica se Autor também foi preenchido
              if (_tituloController.text.isEmpty || _textoController.text.isEmpty || _autorController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha Título, Autor e Mensagem.")));
                return;
              }
              
              Navigator.pop(ctx);
              setState(() => _isSaving = true);

              try {
                final user = FirebaseAuth.instance.currentUser;
                
                await FirebaseFirestore.instance.collection('devocionais').add({
                  'titulo': _tituloController.text.trim(),
                  'versiculo': _versiculoController.text.trim(),
                  'texto': _textoController.text,
                  'data': FieldValue.serverTimestamp(),
                  'autor_uid': user?.uid, // Ainda salvamos o ID de quem postou por segurança
                  'autor_nome': _autorController.text.trim(), // <--- SALVA O QUE FOI DIGITADO
                });
                
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Devocional publicado!")));
                
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("PUBLICAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- TELA DE LEITURA COMPLETA ---
  void _openDetail(Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text("Leitura", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.indigo,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['titulo'] ?? "", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 10),
                
                // EXIBE DATA E AUTOR
                Row(
                  children: [
                    if (data['data'] != null)
                      Text(
                        DateFormat("d 'de' MMMM 'de' y", "pt_BR").format((data['data'] as Timestamp).toDate()),
                        style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    
                    if (data['data'] != null && data['autor_nome'] != null)
                      Text(" • ", style: TextStyle(color: Colors.grey[600])),
                    
                    if (data['autor_nome'] != null)
                      Expanded(
                        child: Text(
                          "Por: ${data['autor_nome']}",
                          style: TextStyle(color: Colors.indigo[800], fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),
                if (data['versiculo'] != null && data['versiculo'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(15),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigo[100]!),
                    ),
                    child: Text(
                      "\"${data['versiculo']}\"",
                      style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.indigo[900]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 25),
                Text(
                  data['texto'] ?? "",
                  style: const TextStyle(fontSize: 18, height: 1.6, color: Colors.black87),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        bool canPost = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
           final userData = userSnapshot.data!.data() as Map<String, dynamic>;
           String role = userData['role'] ?? 'membro';
           // Permite Admin ou Financeiro postar
           canPost = role == 'admin' || role == 'financeiro'; 
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Pão Diário", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.indigo,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.grey[100],
          
          floatingActionButton: canPost 
            ? FloatingActionButton(
                backgroundColor: Colors.indigo,
                onPressed: () => _showAddDialog(context),
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,

          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('devocionais').orderBy('data', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Nenhum devocional postado ainda.", style: TextStyle(color: Colors.grey)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;

                  String dataFormatada = "";
                  if (data['data'] != null) {
                    dataFormatada = DateFormat('dd/MM').format((data['data'] as Timestamp).toDate());
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      onTap: () => _openDetail(data),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                                      child: Text(dataFormatada, style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                    // --- EXIBE AUTOR NO CARD DA LISTA ---
                                    if (data['autor_nome'] != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        "• ${data['autor_nome']}",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                      ),
                                    ]
                                  ],
                                ),
                                if (canPost)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance.collection('devocionais').doc(id).delete();
                                    },
                                  )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data['titulo'] ?? "Sem Título",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                            ),
                            const SizedBox(height: 6),
                            if (data['versiculo'] != null)
                              Text(
                                "\"${data['versiculo']}\"",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]),
                              ),
                            const SizedBox(height: 10),
                            Text(
                              data['texto'] ?? "",
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 10),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text("Ler devocional completo", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                                Icon(Icons.arrow_forward, size: 14, color: Colors.blue)
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}