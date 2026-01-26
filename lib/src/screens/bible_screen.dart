import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  List<dynamic> _allBooks = [];
  List<dynamic> _filteredBooks = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBible();
  }

  Future<void> _loadBible() async {
    try {
      final String response = await rootBundle.loadString('assets/json/ARA.json');
      final data = json.decode(response);
      
      setState(() {
        _allBooks = data;
        _filteredBooks = data;
        _isLoading = false;
      });
    } catch (e) {
      print("Erro ao carregar bíblia: $e");
      setState(() => _isLoading = false);
    }
  }

  void _runFilter(String enteredKeyword) {
    List<dynamic> results = [];
    if (enteredKeyword.isEmpty) {
      results = _allBooks;
    } else {
      results = _allBooks
          .where((book) =>
              book["name"].toLowerCase().contains(enteredKeyword.toLowerCase()))
          .toList();
    }

    setState(() {
      _filteredBooks = results;
    });
  }

  // Helper para saber se é antigo testamento (baseado no índice da lista ORIGINAL)
  bool _isOldTestament(Map<String, dynamic> book) {
    int originalIndex = _allBooks.indexOf(book);
    return originalIndex < 39; // Os primeiros 39 livros são do Antigo Testamento
  }

  String _getAbbreviation(String name) {
    if (RegExp(r'^\d').hasMatch(name)) {
      List<String> parts = name.split(' ');
      if (parts.length > 1) {
        String number = parts[0];
        String bookName = parts[1];
        if (bookName.length >= 2) {
           return "$number ${bookName.substring(0, 2).toUpperCase()}";
        }
      }
    }
    if (name.length >= 3) {
      return name.substring(0, 3).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  void _openBook(Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChaptersScreen(book: book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bíblia Sagrada"),
        backgroundColor: Colors.brown[900], // Marrom mais escuro para elegância
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Buscar livro...",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        _searchController.clear();
                        _runFilter('');
                      },
                    )
                  : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _filteredBooks.length,
              itemBuilder: (context, index) {
                final book = _filteredBooks[index];
                final String bookName = book['name'] ?? 'Livro';
                
                // LÓGICA DE DIFERENCIAÇÃO
                bool isOT = _isOldTestament(book);
                
                // Cores: Laranja/Marrom para Antigo, Azul para Novo
                Color themeColor = isOT ? Colors.orange[900]! : Colors.blue[800]!;
                Color bgColor = isOT ? Colors.orange[50]! : Colors.blue[50]!;
                Color iconBgColor = isOT ? Colors.orange[100]! : Colors.blue[100]!;

                // Lógica para Cabeçalho de Seção (Separador)
                bool showHeader = false;
                if (index == 0) {
                  showHeader = true; // Sempre mostra no primeiro item
                } else {
                  // Verifica se o item anterior era de um testamento diferente
                  bool prevIsOT = _isOldTestament(_filteredBooks[index - 1]);
                  if (prevIsOT != isOT) {
                    showHeader = true;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 20, 8, 10),
                        child: Row(
                          children: [
                            Icon(isOT ? Icons.menu_book : Icons.auto_stories, color: themeColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isOT ? "ANTIGO TESTAMENTO" : "NOVO TESTAMENTO",
                              style: TextStyle(
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1.2
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Divider(color: themeColor.withOpacity(0.3))),
                          ],
                        ),
                      ),

                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      elevation: 1,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withOpacity(0.1)) // Borda sutil
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        onTap: () => _openBook(book),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: iconBgColor,
                          child: Text(
                            _getAbbreviation(bookName),
                            style: TextStyle(
                              color: themeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13
                            ),
                          ),
                        ),
                        title: Text(
                          bookName,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800]),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOT ? "Antigo Testamento" : "Novo Testamento",
                                style: TextStyle(
                                  fontSize: 10, 
                                  color: themeColor,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// --- TELA DE CAPÍTULOS (INTEGRADA AO FIREBASE) ---
// (MANTIDA IGUAL À ANTERIOR, PODE COPIAR DO CÓDIGO PASSADO SE PRECISAR, 
// MAS O FOCO DA MUDANÇA ESTÁ ACIMA NO BibleScreen)
class ChaptersScreen extends StatelessWidget {
  final Map<String, dynamic> book;

  const ChaptersScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    // ... Copie o código da ChaptersScreen da resposta anterior aqui ...
    // Vou colocar resumido para caber na resposta, use o completo que você já tem
    // A única mudança visual seria a cor da AppBar
    
    final List<dynamic> chapters = book['chapters'] ?? [];
    final String bookName = book['name'];
    final User? user = FirebaseAuth.instance.currentUser;
    
    // Detecção se é AT ou NT para cor da AppBar
    // Precisaríamos passar isso por parâmetro ou recalcular. 
    // Para simplificar, vou manter Marrom padrão ou você pode passar a cor no construtor.
    
    return Scaffold(
      appBar: AppBar(
        title: Text(bookName),
        backgroundColor: Colors.brown[700], // Pode customizar depois
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
           Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                const Text("Capítulos lidos ficam destacados", style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: user == null 
              ? const Center(child: Text("Faça login para salvar seu progresso."))
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bible_progress')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    List<dynamic> readChapters = [];
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      readChapters = data['read_chapters'] ?? [];
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        int chapterNum = index + 1;
                        String key = "${bookName}_$chapterNum";
                        bool isRead = readChapters.contains(key);

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VersesScreen(
                                  bookName: bookName,
                                  chapterIndex: chapterNum,
                                  verses: chapters[index],
                                  isReadInitial: isRead,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isRead ? Colors.green[100] : Colors.white, // Melhor contraste
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isRead ? Colors.green : Colors.grey[300]!,
                                width: isRead ? 2 : 1
                              ),
                              boxShadow: [
                                if(!isRead) BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 3, offset: const Offset(0, 2))
                              ]
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "$chapterNum",
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold, 
                                color: isRead ? Colors.green[800] : Colors.grey[800]
                              ),
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
    );
  }
}

// --- TELA DE VERSÍCULOS (MANTIDA IGUAL, SÓ COPIAR) ---
class VersesScreen extends StatefulWidget {
  final String bookName;
  final int chapterIndex;
  final List<dynamic> verses;
  final bool isReadInitial;

  const VersesScreen({
    super.key, 
    required this.bookName, 
    required this.chapterIndex, 
    required this.verses,
    required this.isReadInitial,
  });

  @override
  State<VersesScreen> createState() => _VersesScreenState();
}

class _VersesScreenState extends State<VersesScreen> {
  late bool _isRead;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _isRead = widget.isReadInitial;
  }

  Future<void> _toggleReadStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUpdating = true);

    String key = "${widget.bookName}_${widget.chapterIndex}";
    final docRef = FirebaseFirestore.instance.collection('bible_progress').doc(user.uid);

    try {
      if (_isRead) {
        await docRef.update({
          'read_chapters': FieldValue.arrayRemove([key])
        });
        setState(() => _isRead = false);
      } else {
        await docRef.set({
          'read_chapters': FieldValue.arrayUnion([key]),
          'last_update': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        setState(() => _isRead = true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isRead ? "Capítulo marcado como lido!" : "Marcação removida."),
            backgroundColor: _isRead ? Colors.green : Colors.grey,
            duration: const Duration(seconds: 1),
          )
        );
      }
    } catch (e) {
       // Tratamento de erro
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.bookName} ${widget.chapterIndex}"),
        backgroundColor: _isRead ? Colors.green[700] : Colors.brown[700],
        foregroundColor: Colors.white,
        actions: [
          if (_isUpdating)
             const Padding(
               padding: EdgeInsets.all(12.0),
               child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
             )
          else
            IconButton(
              icon: Icon(_isRead ? Icons.check_circle : Icons.check_circle_outline),
              tooltip: "Marcar como lido",
              onPressed: _toggleReadStatus,
            )
        ],
      ),
      body: Column(
        children: [
          if (_isRead)
            Container(
              width: double.infinity,
              color: Colors.green[100],
              padding: const EdgeInsets.all(8),
              child: const Text(
                "✓ Leitura Concluída",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.verses.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.5),
                    children: [
                      TextSpan(
                        text: "${index + 1} ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: Colors.brown[800], 
                          fontSize: 12
                        ),
                      ),
                      TextSpan(text: widget.verses[index].toString()),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUpdating ? null : _toggleReadStatus,
        backgroundColor: _isRead ? Colors.grey : Colors.green[700],
        icon: Icon(_isRead ? Icons.close : Icons.check, color: Colors.white),
        label: Text(_isRead ? "Desmarcar" : "Marcar Lido", style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}