import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

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
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.brown[900],
          foregroundColor: Colors.white,
          centerTitle: true,
          titleTextStyle: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
      ),
      home: const BibleScreen(),
    );
  }
}

// --- TELA PRINCIPAL (CONTROLE DE ABAS) ---
class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  List<dynamic> _allBooks = [];
  List<dynamic> _filteredBooks = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  // --- CONTROLE DE VERSÃO ---
  String _currentVersion = 'ARA'; // Versão padrão
  final Map<String, String> _versions = {
    'ACF': 'Almeida Corrigida Fiel',
    'ARA': 'Almeida Revista e Atualizada',
    'ARC': 'Almeida Revista e Corrigida',
    'AS21': 'Almeida Século 21',
    'JFAA': 'João Ferreira de Almeida Atualizada',
    'KJA': 'King James Atualizada',
    'KJF': 'King James Fiel',
    'NAA': 'Nova Almeida Atualizada',
    'NBV': 'Nova Bíblia Viva',
    'NTLH': 'Nova Tradução na Linguagem de Hoje',
    'NVI': 'Nova Versão Internacional',
    'NVT': 'Nova Versão Transformadora',
    'TB': 'Tradução Brasileira',
  };

  @override
  void initState() {
    super.initState();
    _loadSavedVersion(); // Alterado para buscar a versão salva primeiro
  }

  // --- NOVA FUNÇÃO PARA BUSCAR A VERSÃO SALVA ---
  Future<void> _loadSavedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVersion = prefs.getString('selected_version');

    if (savedVersion != null && _versions.containsKey(savedVersion)) {
      setState(() {
        _currentVersion = savedVersion;
      });
    }
    
    _loadBible(); 
  }

  // Carrega a Bíblia baseado na versão selecionada
  Future<void> _loadBible() async {
    setState(() => _isLoading = true);
    try {
      // Carrega o arquivo JSON dinamicamente baseado na _currentVersion
      final String response = await rootBundle
          .loadString('assets/json/bible/$_currentVersion.json');
      final data = json.decode(response);

      setState(() {
        _allBooks = data;
        _filteredBooks = data;
        _isLoading = false;
        // Limpa a busca ao trocar de versão para evitar erros de índice
        _searchController.clear();
      });
    } catch (e) {
      debugPrint("Erro ao carregar bíblia ($_currentVersion): $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Erro ao carregar a versão $_currentVersion. Verifique os arquivos.")));
      }
    }
  }

  // Alterado para salvar a nova versão no celular
  void _changeVersion(String? newVersion) async {
    if (newVersion != null && newVersion != _currentVersion) {
      setState(() {
        _currentVersion = newVersion;
      });
      _loadBible();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_version', newVersion);
    }
  }

  // --- Helpers ---
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
    return name.length >= 3
        ? name.substring(0, 3).toUpperCase()
        : name.toUpperCase();
  }

  void _openBook(Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ChaptersScreen(book: book, versionName: _currentVersion)),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        // Título dinâmico: Se na aba de leitura, mostra o seletor. Se não, título fixo.
        title: _selectedIndex == 0
            ? PopupMenuButton<String>(
                initialValue: _currentVersion,
                onSelected: _changeVersion,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Bíblia Sagrada ($_currentVersion)",
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(width: 5),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                  ],
                ),
                itemBuilder: (BuildContext context) {
                  return _versions.entries.map((entry) {
                    return PopupMenuItem<String>(
                      value: entry.key,
                      child: Text("${entry.key} - ${entry.value}"),
                    );
                  }).toList();
                },
              )
            : const Text("Meu Progresso"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                // --- ABA 1: LISTA DE LEITURA ---
                Column(
                  children: [
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
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.7)),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Colors.white),
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
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 20),
                        ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot>(
                          stream: user != null
                              ? FirebaseFirestore.instance
                                  .collection('bible_progress')
                                  .doc(user.uid)
                                  .snapshots()
                              : null,
                          builder: (context, snapshot) {
                            Set<String> readChaptersSet = {};
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              final List<dynamic> rawList =
                                  data['read_chapters'] ?? [];
                              readChaptersSet = Set.from(rawList);
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.only(
                                  top: 10, left: 10, right: 10, bottom: 20),
                              itemCount: _filteredBooks.length,
                              itemBuilder: (context, index) {
                                final book = _filteredBooks[index];
                                final String bookName = book['name'] ?? 'Livro';
                                bool isOT = _isOldTestament(book);
                                Color themeColor = isOT
                                    ? Colors.orange[900]!
                                    : Colors.blue[800]!;
                                Color iconBgColor = isOT
                                    ? Colors.orange[100]!
                                    : Colors.blue[100]!;

                                final int totalCaps =
                                    (book['chapters'] as List).length;
                                int readCapsForThisBook = readChaptersSet
                                    .where(
                                        (key) => key.startsWith("${bookName}_"))
                                    .length;
                                bool isBookCompleted =
                                    readCapsForThisBook >= totalCaps &&
                                        totalCaps > 0;

                                bool showHeader = false;
                                if (index == 0) {
                                  showHeader = true;
                                } else if (_isOldTestament(
                                        _filteredBooks[index - 1]) !=
                                    isOT) {
                                  showHeader = true;
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showHeader)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            8, 15, 8, 10),
                                        child: Row(
                                          children: [
                                            Icon(
                                                isOT
                                                    ? Icons.menu_book
                                                    : Icons.auto_stories,
                                                color: themeColor,
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              isOT
                                                  ? "ANTIGO TESTAMENTO"
                                                  : "NOVO TESTAMENTO",
                                              style: TextStyle(
                                                  color: themeColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  letterSpacing: 1.2),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: Divider(
                                                    color: themeColor
                                                        .withOpacity(0.3))),
                                          ],
                                        ),
                                      ),
                                    Card(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      elevation: 1,
                                      color: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                              color: Colors.grey
                                                  .withOpacity(0.1))),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                        onTap: () => _openBook(book),
                                        leading: CircleAvatar(
                                          radius: 24,
                                          backgroundColor: isBookCompleted
                                              ? Colors.green
                                              : iconBgColor,
                                          child: isBookCompleted
                                              ? const Icon(Icons.check,
                                                  color: Colors.white, size: 20)
                                              : Text(
                                                  _getAbbreviation(bookName),
                                                  style: TextStyle(
                                                      color: themeColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13),
                                                ),
                                        ),
                                        title: Text(bookName,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.grey[800])),
                                        trailing: isBookCompleted
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.green)
                                            : Icon(Icons.arrow_forward_ios,
                                                size: 14,
                                                color: Colors.grey[400]),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          }),
                    ),
                  ],
                ),

                // --- ABA 2: ESTATÍSTICAS E TABELA ---
                BibleStatsView(
                    allBooks: _allBooks, currentVersion: _currentVersion),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Leitura',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Evolução',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.brown[900],
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

// --- WIDGET DE ESTATÍSTICAS ---
class BibleStatsView extends StatelessWidget {
  final List<dynamic> allBooks;
  final String currentVersion; // Recebe a versão para abrir o livro correto

  const BibleStatsView(
      {super.key, required this.allBooks, required this.currentVersion});

  String _getAbbreviation(String name) {
    if (RegExp(r'^\d').hasMatch(name)) {
      List<String> parts = name.split(' ');
      if (parts.length > 1 && parts[1].length >= 2) {
        return "${parts[0]} ${parts[1].substring(0, 2).toUpperCase()}";
      }
    }
    return name.length >= 3
        ? name.substring(0, 3).toUpperCase()
        : name.toUpperCase();
  }

  bool _isOldTestament(int index) {
    return index < 39;
  }

  void _openBook(BuildContext context, Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ChaptersScreen(book: book, versionName: currentVersion)),
    );
  }

  // --- Função: Iniciar Plano ---
  Future<void> _startPlan(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('bible_progress')
        .doc(user.uid)
        .set({
      'read_chapters': [],
      'marked_verses': [],
      'start_date': FieldValue.serverTimestamp(),
      'last_update': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Plano de leitura iniciado! Boa jornada.")));
    }
  }

  // --- Função: Reiniciar Plano ---
  Future<void> _restartPlan(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text("Reiniciar Plano?"),
                  content: const Text(
                      "Todo o seu progresso será apagado. Tem certeza?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancelar")),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text("Reiniciar")),
                  ],
                )) ??
        false;

    if (confirm) {
      await FirebaseFirestore.instance
          .collection('bible_progress')
          .doc(user.uid)
          .set({
        'read_chapters': [],
        'marked_verses': [],
        'start_date': FieldValue.serverTimestamp(),
        'last_update': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Plano reiniciado com sucesso!")));
      }
    }
  }

  // --- Função: Exportar PDF ---
  Future<void> _exportPlanToPdf(
      BuildContext context,
      Map<String, dynamic> data,
      int total,
      int read,
      int otRead,
      int otTotal,
      int ntRead,
      int ntTotal,
      String userName) async {
    // 1. Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // 2. Buscar nome se necessário (Se a view não tiver o nome completo, buscamos aqui)
    String finalUserName = userName;
    final user = FirebaseAuth.instance.currentUser;

    if (finalUserName == "Usuário" && user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          finalUserName =
              userData['nome_completo'] ?? user.displayName ?? "Membro IEC";
        }
      } catch (e) {
        debugPrint("Erro buscar nome: $e");
      }
    }

    // 3. Carregar Imagem
    pw.MemoryImage? imagemCapa;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/capa.png');
      final Uint8List byteList = bytes.buffer.asUint8List();
      imagemCapa = pw.MemoryImage(byteList);
    } catch (e) {
      debugPrint("Erro ao carregar a imagem capa.png: $e");
    }

    // 4. Gerar PDF
    final pdf = pw.Document();

    Timestamp? startTs = data['start_date'];
    String startDateStr = startTs != null
        ? "${startTs.toDate().day}/${startTs.toDate().month}/${startTs.toDate().year}"
        : "Não definida";

    bool isCompleted = total > 0 && read >= total;
    DateTime now = DateTime.now();
    String endDateStr =
        isCompleted ? "${now.day}/${now.month}/${now.year}" : "Em andamento";

    double percentTotal = total > 0 ? read / total : 0;
    double percentOT = otTotal > 0 ? otRead / otTotal : 0;
    double percentNT = ntTotal > 0 ? ntRead / ntTotal : 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // CABEÇALHO COM A IMAGEM (CENTRALIZADO)
              if (imagemCapa != null)
                pw.Center(
                  child: pw.Container(
                    height: 120, // Altura travada 
                    width: 450, // Largura máxima para não passar da margem e ficar centralizado
                    margin: const pw.EdgeInsets.only(bottom: 20),
                    child: pw.Image(
                      imagemCapa,
                      fit: pw.BoxFit.contain, 
                    ),
                  ),
                ),

              pw.Header(
                level: 0,
                child: pw.Text("Relatório de Leitura Bíblica",
                    style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.brown900)),
              ),
              pw.SizedBox(height: 5),
              pw.Text("Membro: ${finalUserName.toUpperCase()}",
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Data de Início: $startDateStr",
                      style: const pw.TextStyle(fontSize: 14)),
                  pw.Text("Conclusão: $endDateStr",
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: isCompleted
                              ? PdfColors.green900
                              : PdfColors.black)),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),
              if (isCompleted)
                pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(10),
                    margin: const pw.EdgeInsets.only(bottom: 20),
                    decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                        border: pw.Border.all(color: PdfColors.green),
                        borderRadius: pw.BorderRadius.circular(8)),
                    child: pw.Center(
                        child: pw.Text("PARABÉNS! LEITURA DA BÍBLIA CONCLUÍDA!",
                            style: pw.TextStyle(
                                color: PdfColors.green900,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 16)))),
              pw.Text("Progresso Geral",
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                  height: 20,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(5)),
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Container(
                      width: 450 * percentTotal,
                      decoration: pw.BoxDecoration(
                          color: PdfColors.green,
                          borderRadius: pw.BorderRadius.circular(5)),
                    ),
                  )),
              pw.Text(
                  "$read de $total capítulos (${(percentTotal * 100).toStringAsFixed(1)}%)"),
              pw.SizedBox(height: 20),
              pw.Text("Antigo Testamento",
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                  height: 10,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(5)),
                  child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Container(
                          width: 450 * percentOT, color: PdfColors.orange800))),
              pw.Text("$otRead de $otTotal caps"),
              pw.SizedBox(height: 10),
              pw.Text("Novo Testamento",
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                  height: 10,
                  width: double.infinity,
                  decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(5)),
                  child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Container(
                          width: 450 * percentNT, color: PdfColors.blue800))),
              pw.Text("$ntRead de $ntTotal caps"),
              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                  child: pw.Text("Gerado pelo aplicativo IEC App",
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey))),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/relatorio_leitura.pdf");
    await file.writeAsBytes(await pdf.save());

    if (context.mounted) Navigator.pop(context); // Fecha loading

    await Share.shareXFiles([XFile(file.path)],
        text: 'Segue meu relatório de leitura bíblica.');
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("Faça login para ver sua evolução."));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bible_progress')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        Map<String, dynamic> userData = {};
        List<dynamic> readChaptersData = [];
        Timestamp? startDate;

        if (snapshot.data!.exists) {
          userData = snapshot.data!.data() as Map<String, dynamic>;
          readChaptersData = userData['read_chapters'] ?? [];
          startDate = userData['start_date'];
        }

        final Set<String> readChaptersSet = Set.from(readChaptersData);

        int totalChaptersBible = 0;
        int totalChaptersOT = 0;
        int totalChaptersNT = 0;

        for (int i = 0; i < allBooks.length; i++) {
          int caps = (allBooks[i]['chapters'] as List).length;
          totalChaptersBible += caps;
          if (i < 39) {
            totalChaptersOT += caps;
          } else {
            totalChaptersNT += caps;
          }
        }

        int userReadOT = 0;
        int userReadNT = 0;

        for (String key in readChaptersSet) {
          String bookName = key.split('_')[0];
          int bookIndex = allBooks.indexWhere((b) => b['name'] == bookName);
          if (bookIndex != -1) {
            if (bookIndex < 39) {
              userReadOT++;
            } else {
              userReadNT++;
            }
          }
        }

        int userReadTotal = userReadOT + userReadNT;
        double percentTotal =
            totalChaptersBible > 0 ? userReadTotal / totalChaptersBible : 0;
        double percentOT =
            totalChaptersOT > 0 ? userReadOT / totalChaptersOT : 0;
        double percentNT =
            totalChaptersNT > 0 ? userReadNT / totalChaptersNT : 0;

        // SE NÃO TIVER DATA DE INÍCIO, MOSTRA TELA PARA INICIAR O PLANO
        if (startDate == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories, size: 80, color: Colors.brown[300]),
                const SizedBox(height: 20),
                const Text("Bem-vindo ao seu plano de leitura!",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                    "Clique abaixo para começar a registrar sua jornada.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15)),
                    onPressed: () => _startPlan(context),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("INICIAR PLANO DE LEITURA")),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- AVISO DE PARABÉNS SE 100% ---
              if (percentTotal >= 1.0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Colors.amber, Colors.orange]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.orange.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]),
                  child: const Column(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.white, size: 50),
                      SizedBox(height: 10),
                      Text("PARABÉNS!",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      Text("Você concluiu a leitura da Bíblia!",
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Resumo Geral",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'export') {
                        _exportPlanToPdf(
                            context,
                            userData,
                            totalChaptersBible,
                            userReadTotal,
                            userReadOT,
                            totalChaptersOT,
                            userReadNT,
                            totalChaptersNT,
                            user.displayName ?? "Usuário");
                      } else if (value == 'restart') {
                        _restartPlan(context);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        const PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf,
                                  color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Exportar PDF'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'restart',
                          child: Row(
                            children: [
                              Icon(Icons.restart_alt, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Reiniciar Plano',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ];
                    },
                    icon: const Icon(Icons.more_vert, color: Colors.brown),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              _buildProgressCard(
                title: "Bíblia Completa",
                read: userReadTotal,
                total: totalChaptersBible,
                percent: percentTotal,
                color: Colors.green,
                icon: Icons.public,
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildProgressCard(
                        title: "Antigo Test.",
                        read: userReadOT,
                        total: totalChaptersOT,
                        percent: percentOT,
                        color: Colors.orange[800]!,
                        icon: Icons.menu_book,
                        isSmall: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildProgressCard(
                        title: "Novo Test.",
                        read: userReadNT,
                        total: totalChaptersNT,
                        percent: percentNT,
                        color: Colors.blue[800]!,
                        icon: Icons.auto_stories,
                        isSmall: true),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              const Text(
                "Tabela de Livros",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown),
              ),
              const Text(
                "Cinza = Leitura concluída",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 15),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 1.0,
                ),
                itemCount: allBooks.length,
                itemBuilder: (context, index) {
                  final book = allBooks[index];
                  final String bookName = book['name'];
                  final int totalCaps = (book['chapters'] as List).length;

                  int readCapsForThisBook = readChaptersSet
                      .where((key) => key.startsWith("${bookName}_"))
                      .length;

                  bool isBookCompleted =
                      readCapsForThisBook >= totalCaps && totalCaps > 0;
                  bool isOT = _isOldTestament(index);

                  Color boxColor;
                  if (isBookCompleted) {
                    boxColor = Colors.grey;
                  } else {
                    boxColor = isOT ? Colors.orange[800]! : Colors.blue[800]!;
                  }

                  return InkWell(
                    onTap: () => _openBook(context, book),
                    child: Container(
                      decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getAbbreviation(bookName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$readCapsForThisBook/$totalCaps",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
              // Botões de ação no rodapé
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _exportPlanToPdf(
                          context,
                          userData,
                          totalChaptersBible,
                          userReadTotal,
                          userReadOT,
                          totalChaptersOT,
                          userReadNT,
                          totalChaptersNT,
                          user.displayName ?? "Usuário"),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Exportar PDF"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red)),
                      onPressed: () => _restartPlan(context),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text("Reiniciar"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressCard({
    required String title,
    required int read,
    required int total,
    required double percent,
    required Color color,
    required IconData icon,
    bool isSmall = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: isSmall ? 20 : 28),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmall ? 16 : 20,
                        color: Colors.black87)),
              ],
            ),
            SizedBox(height: isSmall ? 15 : 20),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: color.withOpacity(0.1),
              color: color,
              minHeight: isSmall ? 8 : 12,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$read / $total caps",
                    style: const TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.w500)),
                Text("${(percent * 100).toStringAsFixed(1)}%",
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- TELA DE CAPÍTULOS ---
class ChaptersScreen extends StatelessWidget {
  final Map<String, dynamic> book;
  final String versionName;

  const ChaptersScreen(
      {super.key, required this.book, required this.versionName});

  @override
  Widget build(BuildContext context) {
    final List<dynamic> chapters = book['chapters'] ?? [];
    final String bookName = book['name'];
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("$bookName ($versionName)"),
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
                  child: Text("Verde: Capítulo concluído",
                      style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
          Expanded(
            child: user == null
                ? const Center(
                    child: Text("Faça login para salvar seu progresso."))
                : StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bible_progress')
                        .doc(user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      List<dynamic> readChapters = [];
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>;
                        readChapters = data['read_chapters'] ?? [];
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                                    versionName: versionName,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    isRead ? Colors.green[100] : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: isRead
                                        ? Colors.green
                                        : Colors.grey[300]!,
                                    width: isRead ? 2 : 1),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "$chapterNum",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isRead
                                        ? Colors.green[800]
                                        : Colors.grey[800]),
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

// --- TELA DE VERSÍCULOS ---
class VersesScreen extends StatefulWidget {
  final String bookName;
  final int chapterIndex;
  final List<dynamic> verses;
  final String versionName;

  const VersesScreen({
    super.key,
    required this.bookName,
    required this.chapterIndex,
    required this.verses,
    required this.versionName,
  });

  @override
  State<VersesScreen> createState() => _VersesScreenState();
}

class _VersesScreenState extends State<VersesScreen> {
  final Set<int> _selectedVersesBuffer = {};

  DocumentReference get _userDoc {
    final user = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance
        .collection('bible_progress')
        .doc(user!.uid);
  }

  bool get _isSelectionMode => _selectedVersesBuffer.isNotEmpty;

  void _toggleSelection(int verseNum) {
    setState(() {
      if (_selectedVersesBuffer.contains(verseNum)) {
        _selectedVersesBuffer.remove(verseNum);
      } else {
        _selectedVersesBuffer.add(verseNum);
      }
    });
  }

  void _shareSelectedVerses() {
    if (_selectedVersesBuffer.isEmpty) return;

    final sortedList = _selectedVersesBuffer.toList()..sort();
    StringBuffer buffer = StringBuffer();
    buffer.writeln(
        "*${widget.bookName} ${widget.chapterIndex} (${widget.versionName})*");
    buffer.writeln("");

    for (int verseNum in sortedList) {
      String text = widget.verses[verseNum - 1].toString();
      buffer.writeln("$verseNum. $text");
    }

    buffer.writeln("\n_Compartilhado via App IEC Moreno_");
    Share.share(buffer.toString());
  }

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
          SnackBar(
              content: Text("${keysToAdd.length} versículos marcados!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erro ao salvar lote: $e");
    }
  }

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
          const SnackBar(
              content: Text("Marcações removidas."),
              backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      debugPrint("Erro ao remover: $e");
    }
  }

  Future<void> _toggleChapterRead(bool isCurrentlyRead) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String chapterKey = "${widget.bookName}_${widget.chapterIndex}";

    if (isCurrentlyRead) {
      await _userDoc.update({
        'read_chapters': FieldValue.arrayRemove([chapterKey])
      });
    } else {
      await _userDoc.set({
        'read_chapters': FieldValue.arrayUnion([chapterKey]),
        'start_date': FieldValue.serverTimestamp(),
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
              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _selectedVersesBuffer.clear()))
                  : null,
              actions: [
                if (_isSelectionMode) ...[
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: "Compartilhar",
                    onPressed: _shareSelectedVerses,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: "Desmarcar lidos",
                    onPressed: _removeSelectedVersesRead,
                  ),
                ] else ...[
                  IconButton(
                    tooltip: isChapterRead
                        ? "Desmarcar Capítulo"
                        : "Concluir Capítulo",
                    icon: Icon(
                      isChapterRead
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: isChapterRead ? Colors.greenAccent : Colors.white,
                      size: 28,
                    ),
                    onPressed: () => _toggleChapterRead(isChapterRead),
                  ),
                  const SizedBox(width: 8),
                ]
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
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (!_isSelectionMode &&
                    !isChapterRead &&
                    markedVersesDatabase.isEmpty)
                  Container(
                    width: double.infinity,
                    color: Colors.amber[50],
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                      String verseKey =
                          "${widget.bookName}_${widget.chapterIndex}_$verseNum";

                      bool isSavedAsRead =
                          markedVersesDatabase.contains(verseKey);
                      bool isSelectedNow =
                          _selectedVersesBuffer.contains(verseNum);

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
                              _userDoc.update({
                                'marked_verses':
                                    FieldValue.arrayRemove([verseKey])
                              });
                            } else {
                              _userDoc.set({
                                'marked_verses':
                                    FieldValue.arrayUnion([verseKey]),
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
                                : (isSavedAsRead
                                    ? Colors.green[50]
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelectedNow
                                ? Border.all(color: Colors.blue, width: 2)
                                : (isSavedAsRead
                                    ? Border.all(
                                        color: Colors.green.withOpacity(0.3))
                                    : null),
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.black87,
                                  height: 1.5),
                              children: [
                                TextSpan(
                                  text: "$verseNum ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelectedNow
                                        ? Colors.blue[900]
                                        : (isSavedAsRead
                                            ? Colors.green[800]
                                            : Colors.brown[800]),
                                    fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: verseText,
                                  style: TextStyle(
                                      color: isSavedAsRead
                                          ? Colors.green[900]
                                          : Colors.black87,
                                      fontWeight: isSavedAsRead
                                          ? FontWeight.w500
                                          : FontWeight.normal),
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
                    label: Text("Marcar (${_selectedVersesBuffer.length})",
                        style: const TextStyle(color: Colors.white)),
                  )
                : null,
          );
        },
      ),
    );
  }
}