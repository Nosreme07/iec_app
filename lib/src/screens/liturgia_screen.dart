import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
// IMPORTANTE: Ajuste o caminho abaixo para onde está o seu arquivo hymnal.dart
import 'hymnal_screen.dart'; 

class LiturgiaScreen extends StatefulWidget {
  const LiturgiaScreen({super.key});

  @override
  State<LiturgiaScreen> createState() => _LiturgiaScreenState();
}

class _LiturgiaScreenState extends State<LiturgiaScreen> {
  final DateTime _dataFixa = DateTime.now();
  
  List<Map<String, dynamic>> _itensLocais = [];
  String _direcaoLocal = "";
  bool _isLoading = true;

  // --- PERMISSÕES ---
  String _userRole = 'membro';
  bool get _canEdit => _userRole == 'admin' || _userRole == 'financeiro';

  final List<String> _opcoesEventos = [
    'Prelúdio', 'Poslúdio', 'Oração Inicial', 'Oração de Confissão', 'Momento de Intercessão', 'Oração Final',
    'Leitura Bíblica', 'Leitura Bíblica Alternada', 'Louvor','Salmos e Hinos', 'Ofertório', 'Mensagem Bíblica', 'Santa Ceia', 'Outro'
  ];

  @override
  void initState() {
    super.initState();
    _inicializarTela();
  }

  Future<void> _inicializarTela() async {
    await _verificarPermissao();
    await _carregarDadosIniciais();
  }

  Future<void> _verificarPermissao() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          if (mounted) {
            setState(() {
              _userRole = doc.data()?['role'] ?? 'membro';
            });
          }
        }
      }
    } catch (e) {
      print("Erro permissão: $e");
    }
  }

  // MODIFICAÇÃO: Usando um ID fixo para a liturgia nunca sumir, até que seja limpa.
  String _getDocId() => 'liturgia_atual'; 
  String _getDataFormatada() => DateFormat('dd/MM/yyyy').format(_dataFixa);

  // --- NOVA FUNÇÃO: LIMPAR TUDO ---
  void _limparLiturgia() {
    if (!_canEdit) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Limpar Liturgia"),
        content: const Text("Tem certeza que deseja apagar todos os eventos e o dirigente?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _itensLocais.clear();
                _direcaoLocal = ""; // Limpa também o dirigente
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Liturgia limpa! Clique em SALVAR para confirmar."))
              );
            },
            child: const Text("LIMPAR TUDO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _compartilharNoWhatsApp() async {
    if (_itensLocais.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A liturgia está vazia!")));
      return;
    }

    StringBuffer msg = StringBuffer();
    msg.writeln("*🗓️ LITURGIA - IEC MORENO*");
    msg.writeln("📅 Data: ${_getDataFormatada()}");
    if (_direcaoLocal.isNotEmpty) msg.writeln("👤 Dirigente: *$_direcaoLocal*");
    msg.writeln(""); 
    msg.writeln("--------------------------------");
    msg.writeln("");

    for (var item in _itensLocais) {
      final String titulo = (item['titulo'] ?? "Evento").toString();
      final String detalhes = (item['detalhes'] ?? "").toString();
      final String descricao = (item['descricao'] ?? "").toString();
      
      String emoji = "🔹";
      String tituloLower = titulo.toLowerCase();
      
      if (tituloLower.contains("oração") || tituloLower.contains("intercessão")) emoji = "🙏";
      else if (tituloLower.contains("louvor") || tituloLower.contains("ofertório") || tituloLower.contains("hinos")) emoji = "🎵";
      else if (tituloLower.contains("leitura")) emoji = "📖";
      else if (tituloLower.contains("mensagem") || tituloLower.contains("palavra")) emoji = "📢";
      else if (tituloLower.contains("ceia")) emoji = "🍷";

      msg.writeln("$emoji *$titulo*");
      
      if (detalhes.isNotEmpty) {
        msg.writeln("   _${detalhes}_");
      }
      if (descricao.isNotEmpty) {
        msg.writeln("   _${descricao}_");
      }
      msg.writeln(""); 
    }

    msg.writeln("--------------------------------");
    msg.writeln("Te esperamos lá! ⛪");

    String textoCodificado = Uri.encodeComponent(msg.toString());
    final Uri url = Uri.parse("whatsapp://send?text=$textoCodificado");

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        await launchUrl(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir o WhatsApp")));
      }
    }
  }

  String _getImagePath(String titulo) {
    final t = titulo.toLowerCase();
    if (t.contains('oração') || t.contains('intercessão')) return 'assets/images/oração.png';
    else if (t.contains('leitura')) return 'assets/images/leitura.png';
    else if (t.contains('louvor') || t.contains('ofertório') || t.contains('hinos')) return 'assets/images/louvor.png';
    else if (t.contains('mensagem')) return 'assets/images/mensagem.png';
    else if (t.contains('ceia')) return 'assets/images/ceia.png';
    return 'assets/images/outro.png';
  }

  Future<void> _carregarDadosIniciais() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('liturgia').doc(_getDocId()).get();
      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _direcaoLocal = doc.data()!['direcao'] ?? "";
            List dadosBrutos = doc.data()!['itens'] ?? [];
            _itensLocais = dadosBrutos.map((e) => {
              'titulo': e['titulo'] ?? 'Evento',
              'detalhes': e['detalhes'] ?? '',
              'descricao': e['descricao'] ?? '', // Carrega a nova descrição
              'concluido': e['concluido'] ?? false, 
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarTudoNoFirebase() async {
    if (!_canEdit) return;
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      await FirebaseFirestore.instance.collection('liturgia').doc(_getDocId()).set({
        'direcao': _direcaoLocal,
        'itens': _itensLocais,
        'data_referencia': Timestamp.fromDate(_dataFixa), // Registra o momento da última alteração
      }, SetOptions(merge: true));
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Liturgia salva!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar.'), backgroundColor: Colors.red));
      }
    }
  }

  void _showDirecaoDialog() {
    if (!_canEdit) return;
    final controller = TextEditingController(text: _direcaoLocal);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Quem vai dirigir?"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Nome", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () { setState(() => _direcaoLocal = controller.text); Navigator.pop(context); },
            child: const Text("Confirmar"),
          )
        ],
      ),
    );
  }

  void _showItemDialog({Map<String, dynamic>? itemExistente, int? index}) {
    if (!_canEdit) return;
    String? tipoSelecionado = itemExistente?['titulo'] ?? _opcoesEventos.first;
    final detalhesController = TextEditingController(text: itemExistente?['detalhes'] ?? '');
    final descricaoController = TextEditingController(text: itemExistente?['descricao'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final imagePath = _getImagePath(tipoSelecionado!);
          return AlertDialog(
            title: Row(
              children: [
                Image.asset(imagePath, width: 28, height: 28, errorBuilder: (c, o, s) => const Icon(Icons.event)),
                const SizedBox(width: 10),
                Text(itemExistente == null ? "Novo Evento" : "Editar Evento"),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: tipoSelecionado,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Tipo", border: OutlineInputBorder()),
                    items: _opcoesEventos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setStateDialog(() => tipoSelecionado = val),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: detalhesController, 
                    decoration: const InputDecoration(labelText: "Detalhes (Versículo, Hino...)", border: OutlineInputBorder()),
                  ),
                  // MODIFICAÇÃO: Se for 'Outro', exibe também o campo de Descrição
                  if (tipoSelecionado == 'Outro') ...[
                    const SizedBox(height: 15),
                    TextField(
                      controller: descricaoController, 
                      decoration: const InputDecoration(labelText: "Descrição do Evento", border: OutlineInputBorder()),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(
                onPressed: () {
                  final novoItem = {
                    'titulo': tipoSelecionado, 
                    'detalhes': detalhesController.text,
                    'descricao': tipoSelecionado == 'Outro' ? descricaoController.text : '',
                    'concluido': itemExistente?['concluido'] ?? false 
                  };
                  setState(() {
                    if (index == null) _itensLocais.add(novoItem);
                    else _itensLocais[index] = novoItem;
                  });
                  Navigator.pop(context);
                },
                child: const Text("Confirmar"),
              )
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Liturgia", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange[800],
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_canEdit) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white), 
              tooltip: "Limpar Liturgia",
              onPressed: _limparLiturgia,
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              tooltip: "Enviar no WhatsApp",
              onPressed: _compartilharNoWhatsApp,
            ),
          ],
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
        children: [
          InkWell(
            onTap: _canEdit ? _showDirecaoDialog : null,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text("DIRIGENTE DO CULTO", style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.grey)),
                  const SizedBox(height: 5),
                  Text(
                    _direcaoLocal.isEmpty ? "A definir" : _direcaoLocal, 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange[800])
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 80),
              itemCount: _itensLocais.length,
              itemBuilder: (context, index) {
                final item = _itensLocais[index];
                final bool isConcluido = item['concluido'] ?? false;
                final imagePath = _getImagePath(item['titulo']);

                return _canEdit 
                  ? Dismissible(
                      key: UniqueKey(),
                      direction: DismissDirection.endToStart,
                      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                      onDismissed: (_) {
                        setState(() {
                          _itensLocais.removeAt(index);
                        });
                      },
                      child: _buildCardItem(item, isConcluido, imagePath, index),
                    )
                  : _buildCardItem(item, isConcluido, imagePath, index);
              },
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _canEdit 
        ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              FloatingActionButton(heroTag: "btnAdd", backgroundColor: Colors.white, foregroundColor: Colors.deepOrange, onPressed: () => _showItemDialog(), child: const Icon(Icons.add)),
              const SizedBox(width: 15),
              Expanded(child: FloatingActionButton.extended(heroTag: "btnSave", backgroundColor: Colors.deepOrange, onPressed: _salvarTudoNoFirebase, icon: const Icon(Icons.save, color: Colors.white), label: const Text("SALVAR ALTERAÇÕES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ],
          ),
        )
        : null,
    );
  }

  Widget _buildCardItem(Map<String, dynamic> item, bool isConcluido, String imagePath, int index) {
    return Card(
      color: isConcluido ? Colors.grey[200] : Colors.white,
      elevation: isConcluido ? 0 : 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, top: 4, bottom: 4, right: 8),
        leading: Opacity(opacity: isConcluido ? 0.5 : 1.0, child: Image.asset(imagePath, width: 40, height: 40, errorBuilder: (c,o,s) => const Icon(Icons.broken_image))),
        title: Text(item['titulo'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isConcluido ? TextDecoration.lineThrough : null, color: isConcluido ? Colors.grey : Colors.black87)),
        
        // MODIFICAÇÃO: Exibindo Detalhes e Descrição (se houver)
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['detalhes'] != null && item['detalhes'].toString().isNotEmpty)
              Text(item['detalhes'], style: TextStyle(decoration: isConcluido ? TextDecoration.lineThrough : null)),
            if (item['descricao'] != null && item['descricao'].toString().isNotEmpty)
              Text(item['descricao'], style: TextStyle(color: Colors.grey[700], decoration: isConcluido ? TextDecoration.lineThrough : null)),
          ],
        ),

        // MODIFICAÇÃO: Roteamento para página de hinos ou marcar como concluído
        onTap: () {
          if (item['titulo'] == 'Salmos e Hinos') {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const HymnalScreen()));
          } else if (_canEdit) {
            setState(() { item['concluido'] = !isConcluido; });
          }
        },

        // MODIFICAÇÃO: Botões explícitos de Editar e Excluir lado a lado
        trailing: _canEdit 
          ? Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 20), onPressed: () => _showItemDialog(itemExistente: item, index: index), tooltip: "Editar"), 
                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() => _itensLocais.removeAt(index)), tooltip: "Excluir"),
                Icon(isConcluido ? Icons.check_circle : Icons.circle_outlined, color: isConcluido ? Colors.green : Colors.grey, size: 28)
              ])
          : (isConcluido ? const Icon(Icons.check_circle, color: Colors.green, size: 28) : null), 
      ),
    );
  }
}