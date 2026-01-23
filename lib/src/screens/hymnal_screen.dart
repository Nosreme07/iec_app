import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'dart:convert';
import 'package:flutter/services.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 

class HymnalScreen extends StatefulWidget {
  const HymnalScreen({super.key});

  @override
  State<HymnalScreen> createState() => _HymnalScreenState();
}

class _HymnalScreenState extends State<HymnalScreen> {
  String _searchText = "";

  // --- FUNÇÃO DE UPLOAD ---
  Future<void> _uploadHinosDoJsonParaFirebase() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final String response = await rootBundle.loadString(
        'assets/json/hinos.json',
      );
      final List<dynamic> hinos = json.decode(response);

      final batch = FirebaseFirestore.instance.batch();

      for (var hino in hinos) {
        DocumentReference docRef = FirebaseFirestore.instance
            .collection('hinos')
            .doc(hino['numero'].toString());

        batch.set(docRef, {
          "numero": hino['numero'],
          "titulo": hino['titulo'],
          "letra": hino['letra'],
        });
      }

      await batch.commit();

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sucesso! Hinos atualizados!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print("Erro: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Center(child: CircularProgressIndicator());

    // 1. STREAM PARA VERIFICAR PERMISSÕES
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        bool canEdit = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          String role = userData['role'] ?? 'membro';
          
          // --- AQUI ESTÁ A MUDANÇA: Admin OU Financeiro podem editar ---
          canEdit = role == 'admin' || role == 'financeiro';
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              "Salmos e Hinos",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange[800],
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              // BOTÃO DE UPLOAD (Aparece se tiver permissão)
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.cloud_upload),
                  tooltip: "Upload JSON",
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Upload de Hinos"),
                        content: const Text(
                          "Isso vai ler o arquivo 'hinos.json' local e atualizar o banco de dados online.\n\nDeseja continuar?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancelar"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _uploadHinosDoJsonParaFirebase();
                            },
                            child: const Text("ENVIAR AGORA"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              // BARRA DE PESQUISA
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchText = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Buscar hino (nome ou número)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),

              // LISTA DE HINOS (DO FIREBASE)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('hinos')
                      .orderBy('numero')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Center(child: Text("Erro ao carregar."));
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final data = snapshot.data!.docs;

                    // Filtro local
                    final filteredData = data.where((doc) {
                      final hino = doc.data() as Map<String, dynamic>;
                      final titulo = hino['titulo'].toString().toLowerCase();
                      final numero = hino['numero'].toString();
                      return titulo.contains(_searchText) ||
                          numero.contains(_searchText);
                    }).toList();

                    if (filteredData.isEmpty)
                      return const Center(child: Text("Nenhum hino encontrado."));

                    return ListView.builder(
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        final doc = filteredData[index];
                        final hino = doc.data() as Map<String, dynamic>;
                        hino['id'] = doc.id; // Salva ID para edição

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[100],
                              child: Text(
                                "${hino['numero']}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                            title: Text(
                              hino['titulo'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HymnDetailScreen(hino: hino),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

// --- TELA DE LEITURA E EDIÇÃO ---
class HymnDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hino;
  const HymnDetailScreen({super.key, required this.hino});

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  void _editHino() {
    TextEditingController titleController = TextEditingController(
      text: widget.hino['titulo'],
    );
    TextEditingController lyricsController = TextEditingController(
      text: widget.hino['letra'],
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Editar Hino ${widget.hino['numero']}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Título"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lyricsController,
                  decoration: const InputDecoration(labelText: "Letra"),
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('hinos')
                      .doc(widget.hino['id'])
                      .update({
                        'titulo': titleController.text,
                        'letra': lyricsController.text,
                      });

                  if (mounted) Navigator.pop(context);

                  setState(() {
                    widget.hino['titulo'] = titleController.text;
                    widget.hino['letra'] = lyricsController.text;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Salvo com sucesso!")),
                    );
                  }
                } catch (e) {
                  print(e);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Erro ao salvar.")),
                    );
                  }
                }
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Se não estiver logado, mostra apenas a tela sem botão de edição
    if (user == null) {
      return _buildScreenContent(false);
    }

    // STREAM PARA VERIFICAR PERMISSÃO NA TELA DE DETALHES TAMBÉM
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        bool canEdit = false;
        if (snapshot.hasData && snapshot.data!.exists) {
           final userData = snapshot.data!.data() as Map<String, dynamic>;
           String role = userData['role'] ?? 'membro';
           
           // --- AQUI ESTÁ A MUDANÇA ---
           canEdit = role == 'admin' || role == 'financeiro';
        }

        return _buildScreenContent(canEdit);
      }
    );
  }

  Widget _buildScreenContent(bool canEdit) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Hino ${widget.hino['numero']}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange[800],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // EDITAR (Se for admin ou financeiro)
          if (canEdit)
            IconButton(icon: const Icon(Icons.edit), onPressed: _editHino),
        ],
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFFFF8E7),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                widget.hino['titulo'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 30),
              Text(
                widget.hino['letra'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.8,
                  fontFamily: 'Georgia',
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}