import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart'; // <--- PACOTE DE COMPARTILHAMENTO

// --- INICIALIZAÇÃO ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IEC App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
        useMaterial3: true,
      ),
      home: const BibleScreen(),
    );
  }
}

// --- TELA PRINCIPAL: LIVROS ---
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
      debugPrint("Erro ao carregar bíblia: $e");
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
    setState(() => _filteredBooks = results);
  }

  bool _isOldTestament(Map<String, dynamic> book) {
    int originalIndex = _allBooks.indexOf(book);
    if (originalIndex == -1) return true; 
    return originalIndex < 39;
  }

  String _getAbbreviation(String name) {
    if (RegExp(r'^\d').hasMatch(name)) {
      List<String> parts = name.split(' ');
      if (parts.length > 1 && parts[1].length >= 2) {
         return "${parts[0]} ${parts[1].substring(0, 2).toUpperCase()}";
      }
    }
    return name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase();
  }

  void _openBook(Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChaptersScreen(book: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bíblia Sagrada"),
        backgroundColor: Colors.brown[900],
        centerTitle: true,
        elevation: 0,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Barra de Pesquisa Fixa
              Container(
                width: double.infinity,
                color: Colors.brown[900],
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
              
              // Lista de Livros
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 20),
                  itemCount: _filteredBooks.length,
                  itemBuilder: (context, index) {
                    final book = _filteredBooks[index];
                    final String bookName = book['name'] ?? 'Livro';
                    bool isOT = _isOldTestament(book);
                    Color themeColor = isOT ? Colors.orange[900]! : Colors.blue[800]!;
                    Color bgColor = isOT ? Colors.orange[50]! : Colors.blue[50]!;
                    Color iconBgColor = isOT ? Colors.orange[100]! : Colors.blue[100]!;

                    bool showHeader = false;
                    if (index == 0) {
                      showHeader = true;
                    } else if (_isOldTestament(_filteredBooks[index - 1]) != isOT) {
                      showHeader = true;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 15, 8, 10),
                            child: Row(
                              children: [
                                Icon(isOT ? Icons.menu_book : Icons.auto_stories, color: themeColor, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  isOT ? "ANTIGO TESTAMENTO" : "NOVO TESTAMENTO",
                                  style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
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
                            side: BorderSide(color: Colors.grey.withOpacity(0.1))
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            onTap: () => _openBook(book),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: iconBgColor,
                              child: Text(
                                _getAbbreviation(bookName),
                                style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            title: Text(bookName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800])),
                            trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}

// --- TELA DE CAPÍTULOS ---
class ChaptersScreen extends StatelessWidget {
  final Map<String, dynamic> book;

  const ChaptersScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> chapters = book['chapters'] ?? [];
    final String bookName = book['name'];
    final User? user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(bookName),
        backgroundColor: Colors.brown[800],
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
                const Expanded(
                  child: Text("Verde: Capítulo concluído", style: TextStyle(color: Colors.grey)),
                ),
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
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isRead ? Colors.green[100] : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isRead ? Colors.green : Colors.grey[300]!,
                                width: isRead ? 2 : 1
                              ),
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

// --- TELA DE VERSÍCULOS (COM COMPARTILHAMENTO) ---
class VersesScreen extends StatefulWidget {
  final String bookName;
  final int chapterIndex;
  final List<dynamic> verses;

  const VersesScreen({
    super.key, 
    required this.bookName, 
    required this.chapterIndex, 
    required this.verses,
  });

  @override
  State<VersesScreen> createState() => _VersesScreenState();
}

class _VersesScreenState extends State<VersesScreen> {
  // Set para armazenar índices selecionados
  final Set<int> _selectedVersesBuffer = {};
  
  DocumentReference get _userDoc {
    final user = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance.collection('bible_progress').doc(user!.uid);
  }

  bool get _isSelectionMode => _selectedVersesBuffer.isNotEmpty;

  // 1. Lógica de seleção
  void _toggleSelection(int verseNum) {
    setState(() {
      if (_selectedVersesBuffer.contains(verseNum)) {
        _selectedVersesBuffer.remove(verseNum);
      } else {
        _selectedVersesBuffer.add(verseNum);
      }
    });
  }

  // 2. Lógica de COMPARTILHAMENTO
  void _shareSelectedVerses() {
    if (_selectedVersesBuffer.isEmpty) return;

    // Ordena para o texto sair na ordem correta (1, 2, 3...)
    final sortedList = _selectedVersesBuffer.toList()..sort();

    // Constrói o texto
    StringBuffer buffer = StringBuffer();
    buffer.writeln("*${widget.bookName} ${widget.chapterIndex}*"); 
    buffer.writeln(""); 

    for (int verseNum in sortedList) {
      // O índice da lista é verseNum - 1
      String text = widget.verses[verseNum - 1].toString();
      buffer.writeln("$verseNum. $text");
    }

    buffer.writeln("\n_Compartilhado via App IEC Moreno_");

    // Chama o plugin nativo
    Share.share(buffer.toString());
  }

  // 3. Salvar Lote no Firebase
  Future<void> _saveSelectedVersesAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    List<String> keysToAdd = [];
    for (int verseNum in _selectedVersesBuffer) {
      keysToAdd.add("${widget.bookName}_${widget.chapterIndex}_$verseNum");
    }

    try {
      await _userDoc.set({
        'marked_verses': FieldValue.arrayUnion(keysToAdd),
        'last_update': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      setState(() => _selectedVersesBuffer.clear());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${keysToAdd.length} versículos marcados!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erro ao salvar lote: $e");
    }
  }

  // 4. Remover Lote do Firebase
  Future<void> _removeSelectedVersesRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    List<String> keysToRemove = [];
    for (int verseNum in _selectedVersesBuffer) {
      keysToRemove.add("${widget.bookName}_${widget.chapterIndex}_$verseNum");
    }

    try {
      await _userDoc.update({
        'marked_verses': FieldValue.arrayRemove(keysToRemove),
      });

      setState(() => _selectedVersesBuffer.clear());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Marcações removidas."), backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      debugPrint("Erro ao remover: $e");
    }
  }

  // 5. Marcar Capítulo Inteiro
  Future<void> _toggleChapterRead(bool isCurrentlyRead) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String chapterKey = "${widget.bookName}_${widget.chapterIndex}";

    if (isCurrentlyRead) {
      await _userDoc.update({'read_chapters': FieldValue.arrayRemove([chapterKey])});
    } else {
      await _userDoc.set({
        'read_chapters': FieldValue.arrayUnion([chapterKey]),
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() => _selectedVersesBuffer.clear());
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: user != null ? _userDoc.snapshots() : null,
        builder: (context, snapshot) {
          
          List<dynamic> readChapters = [];
          List<dynamic> markedVersesDatabase = [];

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            readChapters = data['read_chapters'] ?? [];
            markedVersesDatabase = data['marked_verses'] ?? [];
          }

          String chapterKey = "${widget.bookName}_${widget.chapterIndex}";
          bool isChapterRead = readChapters.contains(chapterKey);

          return Scaffold(
            appBar: AppBar(
              title: _isSelectionMode 
                ? Text("${_selectedVersesBuffer.length} selecionados")
                : Text("${widget.bookName} ${widget.chapterIndex}"),
              backgroundColor: _isSelectionMode 
                  ? Colors.blueGrey[800] 
                  : (isChapterRead ? Colors.green[700] : Colors.brown[700]),
              foregroundColor: Colors.white,
              leading: _isSelectionMode 
                ? IconButton(
                    icon: const Icon(Icons.close), 
                    onPressed: () => setState(() => _selectedVersesBuffer.clear())
                  )
                : null,
              actions: [
                // --- BOTÕES DE AÇÃO ---
                if (_isSelectionMode) ...[
                   // BOTÃO DE COMPARTILHAR
                   IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: "Compartilhar",
                    onPressed: _shareSelectedVerses,
                   ),
                   // BOTÃO DE DESMARCAR LIDOS (Lixeira)
                   IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: "Desmarcar lidos",
                    onPressed: _removeSelectedVersesRead,
                   ),
                ]
                else if (isChapterRead)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.check_circle, color: Colors.white),
                  )
              ],
            ),
            body: Column(
              children: [
                if (isChapterRead && !_isSelectionMode)
                  Container(
                    width: double.infinity,
                    color: Colors.green[100],
                    padding: const EdgeInsets.all(8),
                    child: const Text(
                      "✓ Capítulo Concluído",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),

                if (!_isSelectionMode && !isChapterRead && markedVersesDatabase.isEmpty)
                   Container(
                    width: double.infinity,
                    color: Colors.amber[50],
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Text(
                      "Toque para marcar um. Segure para selecionar vários.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.amber[900], fontSize: 12),
                    ),
                  ),

                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.verses.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      int verseNum = index + 1;
                      String verseText = widget.verses[index].toString();
                      String verseKey = "${widget.bookName}_${widget.chapterIndex}_$verseNum";
                      
                      bool isSavedAsRead = markedVersesDatabase.contains(verseKey);
                      bool isSelectedNow = _selectedVersesBuffer.contains(verseNum);

                      return InkWell(
                        onLongPress: () {
                          HapticFeedback.mediumImpact(); 
                          _toggleSelection(verseNum);
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(verseNum);
                          } else {
                            if (isSavedAsRead) {
                              _userDoc.update({'marked_verses': FieldValue.arrayRemove([verseKey])});
                            } else {
                              _userDoc.set({
                                'marked_verses': FieldValue.arrayUnion([verseKey]),
                              }, SetOptions(merge: true));
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelectedNow 
                                ? Colors.blue[100] 
                                : (isSavedAsRead ? Colors.green[50] : Colors.transparent),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelectedNow
                                ? Border.all(color: Colors.blue, width: 2)
                                : (isSavedAsRead ? Border.all(color: Colors.green.withOpacity(0.3)) : null),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 18, color: Colors.black87, height: 1.5),
                              children: [
                                TextSpan(
                                  text: "$verseNum ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    color: isSelectedNow ? Colors.blue[900] : (isSavedAsRead ? Colors.green[800] : Colors.brown[800]), 
                                    fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: verseText,
                                  style: TextStyle(
                                     color: isSavedAsRead ? Colors.green[900] : Colors.black87,
                                     fontWeight: isSavedAsRead ? FontWeight.w500 : FontWeight.normal
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            
            floatingActionButton: _isSelectionMode
              ? FloatingActionButton.extended(
                  onPressed: _saveSelectedVersesAsRead,
                  backgroundColor: Colors.blue[800],
                  icon: const Icon(Icons.save_alt, color: Colors.white),
                  label: Text("Marcar (${_selectedVersesBuffer.length})", style: const TextStyle(color: Colors.white)),
                )
              : FloatingActionButton.extended(
                  onPressed: () => _toggleChapterRead(isChapterRead),
                  backgroundColor: isChapterRead ? Colors.grey : Colors.green[700],
                  icon: Icon(isChapterRead ? Icons.close : Icons.check, color: Colors.white),
                  label: Text(
                    isChapterRead ? "Desmarcar Cap." : "Concluir Cap.", 
                    style: const TextStyle(color: Colors.white)
                  ),
                ),
          );
        },
      ),
    );
  }
}