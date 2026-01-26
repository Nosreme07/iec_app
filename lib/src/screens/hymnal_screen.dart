import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NECESSÁRIO

class HymnalScreen extends StatefulWidget {
  const HymnalScreen({super.key});

  @override
  State<HymnalScreen> createState() => _HymnalScreenState();
}

class _HymnalScreenState extends State<HymnalScreen> {
  String _textoBusca = "";
  List<String> _favoritos = [];
  bool _mostrarApenasFavoritos = false;

  @override
  void initState() {
    super.initState();
    _carregarFavoritos();
  }

  // --- FAVORITOS ---
  Future<void> _carregarFavoritos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoritos = prefs.getStringList('hinos_favoritos') ?? [];
    });
  }

  Future<void> _alternarFavorito(String numeroHino) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoritos.contains(numeroHino)) {
        _favoritos.remove(numeroHino);
      } else {
        _favoritos.add(numeroHino);
      }
    });
    await prefs.setStringList('hinos_favoritos', _favoritos);
  }

  // --- UPLOAD (ADMIN) ---
  Future<void> _uploadHinosDoJsonParaFirebase() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final String response = await rootBundle.loadString('assets/json/hinos.json');
      final List<dynamic> hinos = json.decode(response);
      final batch = FirebaseFirestore.instance.batch();

      for (var hino in hinos) {
        DocumentReference docRef = FirebaseFirestore.instance
            .collection('hinos')
            .doc(hino['numero'].toString());

        batch.set(docRef, {
          "numero": hino['numero'], // Salva como número ou string, vamos tratar na leitura
          "titulo": hino['titulo'],
          "letra": hino['letra'],
        });
      }

      await batch.commit();

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sucesso! Hinos atualizados!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        bool podeEditar = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          String role = userData['role'] ?? 'membro';
          podeEditar = role == 'admin' || role == 'financeiro';
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Salmos e Hinos", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.orange[800],
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(_mostrarApenasFavoritos ? Icons.favorite : Icons.favorite_border),
                tooltip: _mostrarApenasFavoritos ? "Ver Todos" : "Ver Favoritos",
                onPressed: () => setState(() => _mostrarApenasFavoritos = !_mostrarApenasFavoritos),
              ),
              if (podeEditar)
                IconButton(
                  icon: const Icon(Icons.cloud_upload),
                  tooltip: "Fazer Upload (JSON)",
                  onPressed: () {
                     // Confirmação simples
                     _uploadHinosDoJsonParaFirebase();
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
                  onChanged: (value) => setState(() => _textoBusca = value.toLowerCase()),
                  decoration: InputDecoration(
                    labelText: 'Buscar (título, número ou letra)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _textoBusca.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _textoBusca = "")) 
                      : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),

              // LISTA DE HINOS
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // CORREÇÃO: Removemos o .orderBy que causava o erro
                  stream: FirebaseFirestore.instance.collection('hinos').snapshots(),
                  builder: (context, snapshot) {
                    
                    // MOSTRA O ERRO REAL NA TELA SE HOUVER
                    if (snapshot.hasError) {
                      return Center(child: Text("Erro: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                    }
                    
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var docs = snapshot.data!.docs;
                    
                    // ORDENAÇÃO MANUAL (SEGURA)
                    // Convertemos para lista para poder ordenar
                    var listaHinos = docs.toList();
                    listaHinos.sort((a, b) {
                      var dataA = a.data() as Map<String, dynamic>;
                      var dataB = b.data() as Map<String, dynamic>;
                      
                      // Força converter para inteiro para ordenar corretamente (1, 2, 10 e não 1, 10, 2)
                      int numA = int.tryParse(dataA['numero'].toString()) ?? 0;
                      int numB = int.tryParse(dataB['numero'].toString()) ?? 0;
                      
                      return numA.compareTo(numB);
                    });

                    // FILTRAGEM
                    final hinosFiltrados = listaHinos.where((doc) {
                      final hino = doc.data() as Map<String, dynamic>;
                      final titulo = hino['titulo'].toString().toLowerCase();
                      final numero = hino['numero'].toString();
                      final letra = (hino['letra'] ?? '').toString().toLowerCase();
                      
                      bool matchBusca = titulo.contains(_textoBusca) || numero.contains(_textoBusca) || letra.contains(_textoBusca);
                      bool matchFavorito = !_mostrarApenasFavoritos || _favoritos.contains(numero);

                      return matchBusca && matchFavorito;
                    }).toList();

                    if (hinosFiltrados.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_off, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text(
                              docs.isEmpty 
                                ? "Banco de dados vazio.\nClique na nuvem para enviar os hinos." 
                                : "Nenhum hino encontrado.",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: hinosFiltrados.length,
                      itemBuilder: (context, index) {
                        final doc = hinosFiltrados[index];
                        final hino = doc.data() as Map<String, dynamic>;
                        hino['id'] = doc.id;
                        String numeroStr = hino['numero'].toString();
                        bool ehFavorito = _favoritos.contains(numeroStr);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[100],
                              child: Text(numeroStr, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900])),
                            ),
                            title: Text(hino['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: IconButton(
                              icon: Icon(ehFavorito ? Icons.favorite : Icons.favorite_border, color: ehFavorito ? Colors.red : Colors.grey),
                              onPressed: () => _alternarFavorito(numeroStr),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HymnDetailScreen(
                                    hino: hino,
                                    ehFavorito: ehFavorito,
                                    aoAlternarFavorito: () => _alternarFavorito(numeroStr),
                                  ),
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
      },
    );
  }
}

// --- TELA DE LEITURA (COM ZOOM) ---
class HymnDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hino;
  final bool ehFavorito;
  final VoidCallback aoAlternarFavorito;

  const HymnDetailScreen({super.key, required this.hino, required this.ehFavorito, required this.aoAlternarFavorito});

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  double _tamanhoFonte = 18.0;
  late bool _localFavorito;

  @override
  void initState() {
    super.initState();
    _localFavorito = widget.ehFavorito;
  }

  void _cliqueFavorito() {
    widget.aoAlternarFavorito();
    setState(() => _localFavorito = !_localFavorito);
  }

  // Função Editar (Opcional, mantida simples)
  void _editarHino() {
     // Lógica simplificada para Admin editar se necessário
     // (Pode copiar a lógica anterior se precisar editar)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hino ${widget.hino['numero']}", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[800],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_localFavorito ? Icons.favorite : Icons.favorite_border),
            color: _localFavorito ? Colors.redAccent : Colors.white,
            onPressed: _cliqueFavorito,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.orange[50],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.text_fields, size: 20, color: Colors.orange),
                Expanded(
                  child: Slider(
                    value: _tamanhoFonte,
                    min: 14.0, max: 34.0,
                    activeColor: Colors.orange,
                    inactiveColor: Colors.orange[200],
                    onChanged: (v) => setState(() => _tamanhoFonte = v),
                  ),
                ),
                Text("${_tamanhoFonte.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFFFF8E7),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      widget.hino['titulo'],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: _tamanhoFonte + 4, fontWeight: FontWeight.bold, color: Colors.orange[900], fontFamily: 'Georgia'),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      widget.hino['letra'],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: _tamanhoFonte, height: 1.6, fontFamily: 'Georgia', color: Colors.black87),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}