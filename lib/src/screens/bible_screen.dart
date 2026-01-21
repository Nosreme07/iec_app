import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  List<dynamic> _books = [];
  bool _isLoading = true;

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
        _books = data;
        _isLoading = false;
      });
    } catch (e) {
      print("Erro ao carregar bíblia: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- NOVA LÓGICA DE ABREVIAÇÃO ---
  String _getAbbreviation(String name) {
    // 1. Verifica se começa com número (ex: "1 João", "2 Reis")
    if (RegExp(r'^\d').hasMatch(name)) {
      List<String> parts = name.split(' ');
      if (parts.length > 1) {
        String number = parts[0]; // "1"
        String bookName = parts[1]; // "João"
        
        // Retorna "1 JO"
        if (bookName.length >= 2) {
           return "$number ${bookName.substring(0, 2).toUpperCase()}";
        }
      }
    }
    
    // 2. Se for livro comum, pega as 3 primeiras letras (ex: "APO", "HEB")
    if (name.length >= 3) {
      return name.substring(0, 3).toUpperCase();
    }
    
    // Fallback padrão
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
        backgroundColor: Colors.brown[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _books.length,
              itemBuilder: (context, index) {
                final book = _books[index];
                final String bookName = book['name'] ?? 'Livro';
                
                // Lógica de Cores: Antigo (0-38) vs Novo (39+)
                bool isOldTestament = index < 39;
                Color iconColor = isOldTestament ? Colors.orange[800]! : Colors.blue[800]!;
                Color iconBgColor = isOldTestament ? Colors.orange[100]! : Colors.blue[100]!;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onTap: () => _openBook(book),
                    
                    // --- ÍCONE AJUSTADO ---
                    leading: CircleAvatar(
                      radius: 22, // Levemente maior para caber "1 JO"
                      backgroundColor: iconBgColor,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: FittedBox( // Garante que o texto não corte
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _getAbbreviation(bookName),
                            style: TextStyle(
                              color: iconColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14 // Tamanho base
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    title: Text(
                      bookName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      isOldTestament ? "Antigo Testamento" : "Novo Testamento",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ),
                );
              },
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

    return Scaffold(
      appBar: AppBar(
        title: Text(book['name']),
        backgroundColor: Colors.brown[700],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: chapters.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VersesScreen(
                    bookName: book['name'],
                    chapterIndex: index + 1,
                    verses: chapters[index],
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.brown[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.brown[200]!),
              ),
              alignment: Alignment.center,
              child: Text(
                "${index + 1}",
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.brown[800]
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- TELA DE VERSÍCULOS ---
class VersesScreen extends StatelessWidget {
  final String bookName;
  final int chapterIndex;
  final List<dynamic> verses;

  const VersesScreen({
    super.key, 
    required this.bookName, 
    required this.chapterIndex, 
    required this.verses
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$bookName $chapterIndex"),
        backgroundColor: Colors.brown[700],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: verses.length,
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
                TextSpan(text: verses[index].toString()),
              ],
            ),
          );
        },
      ),
    );
  }
}