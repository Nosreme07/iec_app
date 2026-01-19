import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  // Variáveis para controlar os dados
  List<dynamic> allBooks = [];      // Todos os livros da Bíblia
  List<dynamic> filteredBooks = []; // Livros filtrados pela busca
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBible();
  }

  // Carrega o JSON da Bíblia
  Future<void> _loadBible() async {
    try {
      // Certifique-se que o arquivo ARA.json está na pasta assets/json/
      final String response = await rootBundle.loadString('assets/json/ARA.json');
      final data = json.decode(response);

      setState(() {
        allBooks = data;
        filteredBooks = data; // Começa exibindo tudo
        isLoading = false;
      });
    } catch (e) {
      print("Erro ao carregar Bíblia: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Função de Filtro (Busca)
  void _runFilter(String enteredKeyword) {
    List<dynamic> results = [];
    if (enteredKeyword.isEmpty) {
      // Se não digitou nada, mostra tudo
      results = allBooks;
    } else {
      // Filtra pelo nome do livro (ignorando maiúsculas/minúsculas)
      results = allBooks.where((book) =>
          book["name"].toLowerCase().contains(enteredKeyword.toLowerCase())
      ).toList();
    }

    setState(() {
      filteredBooks = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bíblia Sagrada", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown[700], // Cor temática da Bíblia
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // --- BARRA DE PESQUISA ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => _runFilter(value),
              decoration: InputDecoration(
                labelText: 'Buscar livro (ex: Mateus, Salmos...)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // --- LISTA DE LIVROS ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredBooks.isEmpty
                    ? const Center(child: Text("Nenhum livro encontrado."))
                    : ListView.builder(
                        itemCount: filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = filteredBooks[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.brown[100],
                                child: Text(
                                  // Pega as 2 primeiras letras do livro para o ícone (Ex: Gn, Ex)
                                  book['abbrev'] != null 
                                      ? book['abbrev'].toString().toUpperCase() 
                                      : book['name'].substring(0, 2).toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown[800],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              title: Text(
                                book['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // Navega para a tela de capítulos
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChaptersScreen(book: book),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// --- TELA DE CAPÍTULOS (Sub-tela 1) ---
class ChaptersScreen extends StatelessWidget {
  final dynamic book;

  const ChaptersScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    // A estrutura do JSON da bíblia geralmente é: book['chapters'] que é uma Lista de Listas
    final List<dynamic> chapters = book['chapters'];

    return Scaffold(
      appBar: AppBar(
        title: Text(book['name'], style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5, // 5 capítulos por linha
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
                    chapterNumber: index + 1,
                    verses: chapters[index],
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.brown[200]!),
              ),
              child: Center(
                child: Text(
                  "${index + 1}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[800],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- TELA DE VERSÍCULOS (Sub-tela 2 - Leitura Final) ---
class VersesScreen extends StatelessWidget {
  final String bookName;
  final int chapterNumber;
  final List<dynamic> verses;

  const VersesScreen({
    super.key,
    required this.bookName,
    required this.chapterNumber,
    required this.verses,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$bookName $chapterNumber", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.brown[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
         color: const Color(0xFFFFF8E7), // Cor de papel antigo (confortável para ler)
         child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: verses.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 18, height: 1.5),
                children: [
                  TextSpan(
                    text: "${index + 1} ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.brown[800],
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: verses[index].toString(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}