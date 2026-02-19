import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // --- UPLOAD (ADMIN) COM LIMPEZA TOTAL E TRADUÇÃO DAS CHAVES ---
  Future<void> _uploadHinosDoJsonParaFirebase() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      // 1. BUSCAR E DELETAR TODOS OS HINOS ANTIGOS (Limpeza do Banco)
      final querySnapshot =
          await FirebaseFirestore.instance.collection('hinos').get();
      WriteBatch deleteBatch = FirebaseFirestore.instance.batch();
      int deleteCount = 0;

      for (var doc in querySnapshot.docs) {
        deleteBatch.delete(doc.reference);
        deleteCount++;
        // Firebase aceita max 500 operações por lote. Enviamos a cada 400.
        if (deleteCount % 400 == 0) {
          await deleteBatch.commit();
          deleteBatch = FirebaseFirestore.instance.batch();
        }
      }
      if (deleteCount % 400 != 0) {
        await deleteBatch.commit(); // Deleta os restantes
      }

      // 2. CARREGAR E SALVAR OS NOVOS HINOS
      final String response =
          await rootBundle.loadString('assets/json/hymnal/salmos_e_hinos.json');
      final List<dynamic> hinos = json.decode(response);

      WriteBatch uploadBatch = FirebaseFirestore.instance.batch();
      int uploadCount = 0;

      for (var hino in hinos) {
        // Pega o número e tira os zeros à esquerda (ex: "001" -> "1")
        String numeroBruto = (hino['number'] ?? '0').toString();
        // Remove os zeros usando parse para int. Se tiver alguma letra junto, usa replaceFirst como fallback
        String numeroLimpo = int.tryParse(numeroBruto)?.toString() ??
            numeroBruto.replaceFirst(RegExp(r'^0+'), '');

        if (numeroLimpo.isEmpty) numeroLimpo = '0';

        DocumentReference docRef =
            FirebaseFirestore.instance.collection('hinos').doc(numeroLimpo);

        // Salvamos no Firebase em PORTUGUÊS e com o número já limpo
        uploadBatch.set(docRef, {
          "numero": numeroLimpo,
          "titulo": hino['title'] ?? 'Sem Título',
          "letra": hino['lyrics'] ?? '',
        });

        uploadCount++;
        if (uploadCount % 400 == 0) {
          await uploadBatch.commit();
          uploadBatch = FirebaseFirestore.instance.batch();
        }
      }
      if (uploadCount % 400 != 0) {
        await uploadBatch.commit(); // Salva os restantes
      }

      if (mounted) Navigator.pop(context); // Fecha o loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Sucesso! Banco limpo e novos hinos enviados!"),
              backgroundColor: Colors.green),
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
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        bool podeEditar = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          String role = userData['role'] ?? 'membro';
          podeEditar = role == 'admin' || role == 'financeiro';
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Salmos e Hinos",
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.orange[800],
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(_mostrarApenasFavoritos
                    ? Icons.favorite
                    : Icons.favorite_border),
                tooltip:
                    _mostrarApenasFavoritos ? "Ver Todos" : "Ver Favoritos",
                onPressed: () => setState(
                    () => _mostrarApenasFavoritos = !_mostrarApenasFavoritos),
              ),
              if (podeEditar)
                IconButton(
                  icon: const Icon(Icons.cloud_upload),
                  tooltip: "Fazer Upload (JSON)",
                  onPressed: () {
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
                  onChanged: (value) =>
                      setState(() => _textoBusca = value.toLowerCase()),
                  decoration: InputDecoration(
                    labelText: 'Buscar (título, número ou letra)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _textoBusca.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _textoBusca = ""))
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),

              // LISTA DE HINOS
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('hinos')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                          child: Text("Erro: ${snapshot.error}",
                              style: const TextStyle(color: Colors.red)));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var docs = snapshot.data!.docs;

                    // ORDENAÇÃO MANUAL (Com proteção contra nulos)
                    var listaHinos = docs.toList();
                    listaHinos.sort((a, b) {
                      var dataA = a.data() as Map<String, dynamic>;
                      var dataB = b.data() as Map<String, dynamic>;

                      int numA =
                          int.tryParse((dataA['numero'] ?? '0').toString()) ??
                              0;
                      int numB =
                          int.tryParse((dataB['numero'] ?? '0').toString()) ??
                              0;

                      return numA.compareTo(numB);
                    });

                    // FILTRAGEM (Com proteção contra nulos)
                    final hinosFiltrados = listaHinos.where((doc) {
                      final hino = doc.data() as Map<String, dynamic>;
                      final titulo =
                          (hino['titulo'] ?? '').toString().toLowerCase();
                      final numero = (hino['numero'] ?? '').toString();
                      final letra =
                          (hino['letra'] ?? '').toString().toLowerCase();

                      bool matchBusca = titulo.contains(_textoBusca) ||
                          numero.contains(_textoBusca) ||
                          letra.contains(_textoBusca);
                      bool matchFavorito = !_mostrarApenasFavoritos ||
                          _favoritos.contains(numero);

                      return matchBusca && matchFavorito;
                    }).toList();

                    if (hinosFiltrados.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.music_off,
                                size: 60, color: Colors.grey[300]),
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

                        String numeroStr = (hino['numero'] ?? '').toString();
                        String tituloStr =
                            (hino['titulo'] ?? 'Sem Título').toString();
                        bool ehFavorito = _favoritos.contains(numeroStr);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[100],
                              child: Text(numeroStr,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[900])),
                            ),
                            title: Text(tituloStr,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            trailing: IconButton(
                              icon: Icon(
                                  ehFavorito
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: ehFavorito ? Colors.red : Colors.grey),
                              onPressed: () => _alternarFavorito(numeroStr),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HymnDetailScreen(
                                    hino: hino,
                                    ehFavorito: ehFavorito,
                                    aoAlternarFavorito: () =>
                                        _alternarFavorito(numeroStr),
                                    podeEditar: podeEditar, // PASSA A PERMISSÃO
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

// --- TELA DE LEITURA (COM ZOOM E EDIÇÃO) ---
class HymnDetailScreen extends StatefulWidget {
  final Map<String, dynamic> hino;
  final bool ehFavorito;
  final VoidCallback aoAlternarFavorito;
  final bool podeEditar;

  const HymnDetailScreen({
    super.key,
    required this.hino,
    required this.ehFavorito,
    required this.aoAlternarFavorito,
    required this.podeEditar,
  });

  @override
  State<HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends State<HymnDetailScreen> {
  double _tamanhoFonte = 18.0;
  late bool _localFavorito;
  bool _modoEdicao = false;

  // Controladores para edição
  late TextEditingController _tituloController;
  late TextEditingController _letraController;

  @override
  void initState() {
    super.initState();
    _localFavorito = widget.ehFavorito;
    // Proteção contra nulos nos controllers
    _tituloController =
        TextEditingController(text: (widget.hino['titulo'] ?? '').toString());
    _letraController =
        TextEditingController(text: (widget.hino['letra'] ?? '').toString());
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _letraController.dispose();
    super.dispose();
  }

  void _cliqueFavorito() {
    widget.aoAlternarFavorito();
    setState(() => _localFavorito = !_localFavorito);
  }

  // SALVAR EDIÇÃO NO FIREBASE
  Future<void> _salvarEdicao() async {
    try {
      await FirebaseFirestore.instance
          .collection('hinos')
          .doc(widget.hino['id'])
          .update({
        'titulo': _tituloController.text,
        'letra': _letraController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hino atualizado com sucesso!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _modoEdicao = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao salvar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String numeroHino = (widget.hino['numero'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text("Hino $numeroHino",
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.orange[800],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_localFavorito ? Icons.favorite : Icons.favorite_border),
            color: _localFavorito ? Colors.redAccent : Colors.white,
            onPressed: _cliqueFavorito,
          ),
          // BOTÃO DE EDITAR (APENAS PARA ADMIN)
          if (widget.podeEditar)
            IconButton(
              icon: Icon(_modoEdicao ? Icons.check : Icons.edit),
              tooltip: _modoEdicao ? "Salvar" : "Editar",
              onPressed: () {
                if (_modoEdicao) {
                  _salvarEdicao();
                } else {
                  setState(() => _modoEdicao = true);
                }
              },
            ),
          // BOTÃO CANCELAR (APARECE APENAS EM MODO EDIÇÃO)
          if (_modoEdicao)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: "Cancelar",
              onPressed: () {
                setState(() {
                  _modoEdicao = false;
                  _tituloController.text =
                      (widget.hino['titulo'] ?? '').toString();
                  _letraController.text =
                      (widget.hino['letra'] ?? '').toString();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // CONTROLE DE ZOOM
          Container(
            color: Colors.orange[50],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.text_fields, size: 20, color: Colors.orange),
                Expanded(
                  child: Slider(
                    value: _tamanhoFonte,
                    min: 14.0,
                    max: 34.0,
                    activeColor: Colors.orange,
                    inactiveColor: Colors.orange[200],
                    onChanged: (v) => setState(() => _tamanhoFonte = v),
                  ),
                ),
                Text("${_tamanhoFonte.toInt()}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange)),
              ],
            ),
          ),

          // CONTEÚDO (MODO LEITURA OU EDIÇÃO)
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFFFF8E7),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _modoEdicao ? _buildModoEdicao() : _buildModoLeitura(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MODO LEITURA
  Widget _buildModoLeitura() {
    String titulo = (widget.hino['titulo'] ?? 'Sem Título').toString();
    String letra = (widget.hino['letra'] ?? '').toString();

    return Column(
      children: [
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: _tamanhoFonte + 4,
              fontWeight: FontWeight.bold,
              color: Colors.orange[900],
              fontFamily: 'Georgia'),
        ),
        const SizedBox(height: 30),
        Text(
          letra,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: _tamanhoFonte,
              height: 1.6,
              fontFamily: 'Georgia',
              color: Colors.black87),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // MODO EDIÇÃO
  Widget _buildModoEdicao() {
    return Column(
      children: [
        // CAMPO TÍTULO
        TextField(
          controller: _tituloController,
          style: TextStyle(
            fontSize: _tamanhoFonte + 4,
            fontWeight: FontWeight.bold,
            color: Colors.orange[900],
            fontFamily: 'Georgia',
          ),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: 'Título',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),

        // CAMPO LETRA
        TextField(
          controller: _letraController,
          style: TextStyle(
            fontSize: _tamanhoFonte,
            height: 1.6,
            fontFamily: 'Georgia',
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: 'Letra do Hino',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            alignLabelWithHint: true,
          ),
          maxLines: null,
          minLines: 10,
        ),
        const SizedBox(height: 20),

        // BOTÃO SALVAR GRANDE
        ElevatedButton.icon(
          onPressed: _salvarEdicao,
          icon: const Icon(Icons.save),
          label: const Text("Salvar Alterações"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}
