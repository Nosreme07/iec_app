import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NECESSÁRIO PARA CARREGAR A IMAGEM DOS ASSETS
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_register_screen.dart';

// Importações necessárias para gerar o PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen>
    with SingleTickerProviderStateMixin {
  String _searchText = "";
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- FUNÇÃO AUXILIAR: PEGAR NOME E SOBRENOME ---
  String _obterNomeSobrenome(String nomeCompleto) {
    if (nomeCompleto.trim().isEmpty) return "Sem Nome";
    List<String> partes = nomeCompleto.trim().split(' ');
    if (partes.length <= 1) return partes[0];
    return "${partes.first} ${partes.last}";
  }

  // --- FUNÇÃO: ZERAR SENHA (SENHA PADRÃO 123456) ---
  Future<void> _resetMemberPassword(String docId, String nome) async {
    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text("Zerar Senha"),
                    content: Text(
                        "Deseja resetar a senha de $nome para '123456'?\n\nO membro deverá usar esta senha para acessar o app."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancelar")),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("CONFIRMAR",
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)))
                    ])) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(docId).update({
          'senha_temporaria': '123456',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Senha zerada para 123456 com sucesso!"),
              backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Erro ao zerar senha. Verifique sua permissão.")));
        }
      }
    }
  }

  // --- FUNÇÕES UTILITÁRIAS ---
  void _editMember(String docId, Map<String, dynamic> data) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                AdminRegisterScreen(memberId: docId, memberData: data)));
  }

  void _addNewMember() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const AdminRegisterScreen()));
  }

  Future<void> _deleteMember(String docId, String nome) async {
    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text("Excluir Membro"),
                    content: Text("Tem certeza que deseja remover $nome?"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancelar")),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("EXCLUIR",
                              style: TextStyle(color: Colors.red)))
                    ])) ??
        false;
    if (confirm) {
      await FirebaseFirestore.instance.collection('users').doc(docId).delete();
    }
  }

  Future<void> _openWhatsApp(String phone, {String? message}) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Número de WhatsApp não cadastrado.")));
      return;
    }
    if (!cleanPhone.startsWith('55')) cleanPhone = '55$cleanPhone';

    String urlString = "https://wa.me/$cleanPhone";
    if (message != null && message.isNotEmpty) {
      urlString += "?text=${Uri.encodeComponent(message)}";
    }

    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Não foi possível abrir o WhatsApp")));
    }
  }

  Future<void> _makeCall(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Telefone não cadastrado.")));
      return;
    }
    final Uri url = Uri.parse("tel:$cleanPhone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  bool _isBirthdayMonth(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      List<String> parts = dateStr.split('/');
      if (parts.length >= 2) {
        int month = int.parse(parts[1]);
        return month == DateTime.now().month;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  // --- ORDENAÇÃO CUSTOMIZADA ---
  int _pesoOficiais(String cargo) {
    final c = cargo.toLowerCase();
    if (c.contains('pastor')) return 1;
    if (c.contains('presb')) return 2;
    if (c.contains('diác') || c.contains('diac')) return 3;
    return 99;
  }

  int _pesoDirecao(String cargo) {
    final c = cargo.toLowerCase();
    if (c.contains('presidente') && !c.contains('vice')) return 1;
    if (c.contains('vice')) return 2;
    if (c.contains('patrim')) return 3;
    if (c.contains('secret')) return 4;
    if (c.contains('1º tes') || c.contains('primeiro tes')) return 5;
    if (c.contains('2º tes') || c.contains('segundo tes')) return 6;
    if (c.contains('zelador')) return 7;
    if (c.contains('conselho') || c.contains('fiscal')) return 8;
    return 99;
  }

  // --- GERADOR DE PDF ---
  Future<void> _exportarPDFResumo({
    required int total,
    required int visitantes,
    required int ativos,
    required int inativos,
    required int congregados,
    required int criancas,
    required int inMemoriam,
    required List<Map<String, dynamic>> oficiais,
    required List<Map<String, dynamic>> direcao,
    required List<Map<String, dynamic>> todosMembros, // LISTA DE TODOS
  }) async {
    final pdf = pw.Document();

    // Carrega a imagem do assets
    pw.MemoryImage? imagemCapa;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/capa.png');
      final Uint8List byteList = bytes.buffer.asUint8List();
      imagemCapa = pw.MemoryImage(byteList);
    } catch (e) {
      debugPrint("Erro ao carregar a imagem capa.png: $e");
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
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
              child: pw.Text("Resumo Geral - Gestão de Membros",
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            
            // Tabela de resumo numérico
            pw.Text("Estatísticas:",
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: "Total de Cadastros: $total"),
            pw.Bullet(text: "Visitantes: $visitantes"),
            pw.Bullet(text: "Ativos: $ativos"),
            pw.Bullet(text: "Inativos: $inativos"),
            pw.Bullet(text: "Congregados: $congregados"),
            pw.Bullet(text: "Crianças/Adolescentes: $criancas"),
            pw.Bullet(text: "In Memoriam: $inMemoriam"),
            
            pw.SizedBox(height: 20),
            
            // Lista de Oficiais
            pw.Text("Quadro de Oficiais",
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            ...oficiais.map((m) {
              final nome = m['nome_completo'] ?? m['nome'] ?? 'Sem nome';
              final cargo = m['oficial_igreja'] ?? '';
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text("$cargo: $nome"),
              );
            }).toList(),
            
            pw.SizedBox(height: 20),
            
            // Lista de Direção
            pw.Text("Quadro de Direção",
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            ...direcao.map((m) {
              final nome = m['nome_completo'] ?? m['nome'] ?? 'Sem nome';
              final cargo = m['cargo_atual'] ?? '';
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text("$cargo: $nome"),
              );
            }).toList(),

            pw.SizedBox(height: 30),

            // NOVA SEÇÃO: LISTA DE TODOS OS MEMBROS
            pw.Text("Lista de Membros (Geral)",
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            ...todosMembros.map((m) {
              final nome = m['nome_completo'] ?? m['nome'] ?? 'Sem nome';
              final situacao = (m['situacao'] ?? '').toString().toLowerCase();
              
              String observacao = "";
              // Verifica se está In Memoriam e busca a data de falecimento
              if (situacao.contains('memoriam')) {
                final dataF = m['data_falecimento'] ?? 'Não informada';
                observacao = " (In Memoriam - Falecimento: $dataF)";
              }

              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Text("- $nome$observacao"),
              );
            }).toList(),
          ];
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'resumo_igreja.pdf');
  }

  // --- POPUP DE DETALHES ---
  void _showMemberDetails(Map<String, dynamic> data, bool canManage) {
    String get(String key) => (data[key] ?? "").toString();
    String nomeCompleto =
        get('nome_completo').isEmpty ? get('nome') : get('nome_completo');
    String apelido = get('apelido');
    String nomeExibicaoPrincipal = apelido.isNotEmpty ? apelido : nomeCompleto;
    String nomeParaMensagem =
        apelido.isNotEmpty ? apelido : nomeCompleto.split(' ')[0];

    String? fotoUrl = data['foto_url'];
    String role = get('role');
    String whatsapp = get('whatsapp');
    String telefone = get('telefone');

    Color headerColor = Colors.indigo;
    String labelRole = "";

    if (role == 'admin') {
      headerColor = Colors.deepOrange;
      labelRole = "ADMINISTRADOR";
    } else if (role == 'financeiro') {
      headerColor = Colors.green[700]!;
      labelRole = "FINANCEIRO";
    } else if (role == 'visitante') {
      headerColor = Colors.purple;
      labelRole = "VISITANTE";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: headerColor.withOpacity(0.2),
                    backgroundImage:
                        fotoUrl != null ? NetworkImage(fotoUrl) : null,
                    child: fotoUrl == null
                        ? Icon(Icons.person, size: 60, color: headerColor)
                        : null,
                  ),
                  if (_isBirthdayMonth(get('nascimento')))
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => _openWhatsApp(whatsapp,
                            message:
                                "Graça e Paz, $nomeParaMensagem! Feliz aniversário! 🎉🙏"),
                        child: const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: Text("🎂", style: TextStyle(fontSize: 20))),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 10),
              Text(nomeExibicaoPrincipal,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              if (apelido.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(nomeCompleto,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center)),
              if (labelRole.isNotEmpty)
                Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: headerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: headerColor.withOpacity(0.5))),
                    child: Text(labelRole,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: headerColor))),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (whatsapp.isNotEmpty)
                      _actionButton(Icons.chat, "WhatsApp", Colors.green,
                          () => _openWhatsApp(whatsapp)),
                    if (whatsapp.isNotEmpty && telefone.isNotEmpty)
                      const SizedBox(width: 20),
                    if (telefone.isNotEmpty)
                      _actionButton(Icons.phone, "Ligar", Colors.blue,
                          () => _makeCall(telefone)),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionTitle("Informações Públicas"),
                    _buildRow(Icons.cake, "Nascimento", get('nascimento')),
                    _buildRow(Icons.bloodtype, "Tipo Sanguíneo",
                        get('grupo_sanguineo')),
                    _buildRow(
                        Icons.star, "Cargo Eclesiástico", get('cargo_atual')),
                    _buildRow(Icons.shield, "Oficial", get('oficial_igreja')),
                    _buildRow(
                        Icons.groups, "Departamento", get('departamento')),
                    if (canManage) ...[
                      _buildSectionTitle("Dados Privados"),
                      _buildRow(Icons.badge, "CPF", get('cpf')),
                      _buildRow(Icons.location_on, "Endereço",
                          "${get('endereco')}, ${get('numero')}"),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
        padding: const EdgeInsets.only(top: 15, bottom: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: Colors.indigo[900],
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          Divider(height: 5, color: Colors.indigo[100])
        ]));
  }

  Widget _buildRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty || value == "null") return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
              child: RichText(
                  text: TextSpan(
                      style:
                          const TextStyle(color: Colors.black87, fontSize: 14),
                      children: [
                TextSpan(
                    text: "$label: ",
                    style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w500))
              ])))
        ]));
  }

  // ==========================================
  // WIDGET DA ABA DE RELATÓRIOS 
  // ==========================================
  Widget _buildRelatoriosTab(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> ativos = [];
    List<Map<String, dynamic>> inativos = [];
    List<Map<String, dynamic>> congregados = [];
    List<Map<String, dynamic>> inMemoriam = [];
    List<Map<String, dynamic>> criancasAdolescentes = [];
    List<Map<String, dynamic>> visitantes = [];
    List<Map<String, dynamic>> oficiais = [];
    List<Map<String, dynamic>> direcao = [];

    // Esta lista vai alimentar a relação nominal no PDF
    List<Map<String, dynamic>> todosMembrosData = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      todosMembrosData.add(data);
      
      final role = (data['role'] ?? "").toString().toLowerCase();
      final situacao = (data['situacao'] ?? "").toString().toLowerCase(); 
      final oficial = (data['oficial_igreja'] ?? "").toString();
      final cargoAtual = (data['cargo_atual'] ?? "").toString(); 

      // Separação por Status CORRIGIDA
      if (situacao == 'ativo') ativos.add(data);
      else if (situacao == 'inativo') inativos.add(data);
      else if (situacao == 'congregado') congregados.add(data);
      else if (situacao.contains('memoriam')) inMemoriam.add(data);
      else if (situacao.contains('criança') || situacao.contains('adolesc')) {
        criancasAdolescentes.add(data);
      }

      // Visitantes
      if (role == 'visitante') visitantes.add(data);

      // Oficiais (Garante que visitante não entra)
      if (role != 'visitante' && oficial.isNotEmpty && oficial != "null" && oficial.toUpperCase() != "NENHUM") {
        oficiais.add(data);
      }
      
      // Direção (Garante que visitante e membro comum não entram)
      if (role != 'visitante' &&
          cargoAtual.isNotEmpty && 
          cargoAtual != "null" && 
          cargoAtual.toUpperCase() != "NENHUM" &&
          cargoAtual.toLowerCase() != "membro" &&
          cargoAtual.toLowerCase() != "visitante") {
        direcao.add(data);
      }
    }

    // APLICANDO A ORDENAÇÃO
    oficiais.sort((a, b) => _pesoOficiais(a['oficial_igreja'] ?? "")
        .compareTo(_pesoOficiais(b['oficial_igreja'] ?? "")));
    
    direcao.sort((a, b) => _pesoDirecao(a['cargo_atual'] ?? "")
        .compareTo(_pesoDirecao(b['cargo_atual'] ?? "")));

    // Ordena todos os membros em ordem alfabética para a lista final do PDF
    todosMembrosData.sort((a, b) => (a['nome_completo'] ?? a['nome'] ?? '')
        .toString()
        .compareTo((b['nome_completo'] ?? b['nome'] ?? '').toString()));

    return Scaffold(
      backgroundColor: Colors.transparent,
      // MUDEI AQUI PARA MOVER O BOTÃO PARA A ESQUERDA
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat, 
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'exportPdfFab', 
        onPressed: () => _exportarPDFResumo(
          total: docs.length,
          visitantes: visitantes.length,
          ativos: ativos.length,
          inativos: inativos.length,
          congregados: congregados.length,
          criancas: criancasAdolescentes.length,
          inMemoriam: inMemoriam.length,
          oficiais: oficiais,
          direcao: direcao,
          todosMembros: todosMembrosData, 
        ),
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text("Exportar PDF", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[700],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Resumo Geral", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildClickableCard("Total", docs.length, Icons.groups, Colors.indigo, () => _showListModal("Total de Cadastros", docs.map((d) => d.data() as Map<String, dynamic>).toList())),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildClickableCard("Visitantes", visitantes.length, Icons.emoji_people, Colors.purple, () => _showListModal("Visitantes", visitantes)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text("Membros por Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSmallCard("Ativos", ativos.length, Colors.green, () => _showListModal("Membros Ativos", ativos)),
              _buildSmallCard("Inativos", inativos.length, Colors.red, () => _showListModal("Membros Inativos", inativos)),
              _buildSmallCard("Congregados", congregados.length, Colors.blue, () => _showListModal("Congregados", congregados)),
              _buildSmallCard("Crianças/Adolesc.", criancasAdolescentes.length, Colors.orange, () => _showListModal("Crianças e Adolescentes", criancasAdolescentes)),
              _buildSmallCard("In Memoriam", inMemoriam.length, Colors.grey[700]!, () => _showListModal("In Memoriam", inMemoriam)),
            ],
          ),
          const SizedBox(height: 25),

          const Text("Quadro de Oficiais", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildPhotoList(oficiais, 'oficial_igreja', Colors.orange, Icons.shield),
          const SizedBox(height: 25),

          const Text("Quadro de Direção", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildPhotoList(direcao, 'cargo_atual', Colors.teal, Icons.account_balance), 

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildClickableCard(String title, int count, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(count.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[800]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCard(String title, int count, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: (MediaQuery.of(context).size.width / 3) - 18,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.black87), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoList(List<Map<String, dynamic>> list, String subtitleKey, Color avatarColor, IconData defaultIcon) {
    if (list.isEmpty) {
      return const Text("Nenhum membro cadastrado nesta categoria.", style: TextStyle(color: Colors.grey));
    }

    return Column(
      children: list.map((membro) {
        String nome = membro['nome_completo'] ?? "Sem Nome";
        if (nome.isEmpty) nome = membro['nome'] ?? "";
        String? fotoUrl = membro['foto_url'];

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: avatarColor.withOpacity(0.2),
              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
              child: fotoUrl == null ? Icon(defaultIcon, color: avatarColor, size: 20) : null,
            ),
            title: Text(_obterNomeSobrenome(nome), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(membro[subtitleKey] ?? "Membro"),
          ),
        );
      }).toList(),
    );
  }

  void _showListModal(String title, List<Map<String, dynamic>> membersList) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              Text("$title (${membersList.length})", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const Divider(),
              Expanded(
                child: membersList.isEmpty
                    ? const Center(child: Text("Nenhum membro encontrado.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: membersList.length,
                        itemBuilder: (context, index) {
                          final membro = membersList[index];
                          String nome = membro['nome_completo'] ?? membro['nome'] ?? "Sem nome";
                          String? fotoUrl = membro['foto_url'];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                              child: fotoUrl == null ? const Icon(Icons.person) : null,
                            ),
                            title: Text(_obterNomeSobrenome(nome)),
                            subtitle: Text(membro['cargo_atual'] ?? 'Membro'),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null)
      return const Center(child: Text("Erro: Não logado"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        bool canManage = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          String myRole =
              (userData['role'] ?? 'membro').toString().toLowerCase();
          canManage = myRole == 'admin' || myRole == 'financeiro';
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Gestão", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.indigo,
            iconTheme: const IconThemeData(color: Colors.white),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.orange,
              tabs: const [
                Tab(icon: Icon(Icons.list), text: "Lista"),
                Tab(icon: Icon(Icons.bar_chart), text: "Resumo"),
              ],
            ),
          ),
          // BOTAO ADICIONAR MEMBRO CONTINUA NA DIREITA (PADRÃO)
          floatingActionButton: canManage
              ? FloatingActionButton(
                  onPressed: _addNewMember,
                  backgroundColor: Colors.indigo,
                  child: const Icon(Icons.person_add, color: Colors.white))
              : null,

          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('nome_completo')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());

              final allDocs = snapshot.data!.docs;

              return TabBarView(
                controller: _tabController,
                children: [
                  // --- ABA 1: LISTA DE MEMBROS ---
                  Column(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextField(
                              onChanged: (value) => setState(
                                  () => _searchText = value.toLowerCase()),
                              decoration: InputDecoration(
                                  labelText: 'Buscar membro',
                                  hintText: 'Nome, Apelido, Cargo ou Depto',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey[100]))),
                      Expanded(
                        child: Builder(builder: (context) {
                          final filteredDocs = allDocs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final nome = (data['nome_completo'] ?? "")
                                .toString()
                                .toLowerCase();
                            return nome.contains(_searchText);
                          }).toList();

                          return ListView.builder(
                            itemCount: filteredDocs.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              
                              String nomeCompleto = data['nome_completo'] ?? "";
                              if (nomeCompleto.trim().isEmpty) {
                                nomeCompleto = data['nome'] ?? "Sem Nome";
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                child: ListTile(
                                  onTap: () =>
                                      _showMemberDetails(data, canManage),
                                  leading: CircleAvatar(
                                    backgroundImage: data['foto_url'] != null
                                        ? NetworkImage(data['foto_url'])
                                        : null,
                                    child: data['foto_url'] == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(nomeCompleto,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle:
                                      Text(data['cargo_atual'] ?? "Membro"),
                                  trailing: canManage
                                      ? PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (value) {
                                            if (value == 'edit')
                                              _editMember(doc.id, data);
                                            if (value == 'delete')
                                              _deleteMember(
                                                  doc.id, nomeCompleto);
                                            if (value == 'reset')
                                              _resetMemberPassword(
                                                  doc.id, nomeCompleto);
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(children: [
                                                  Icon(Icons.edit,
                                                      color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text("Editar")
                                                ])),
                                            const PopupMenuItem(
                                                value: 'reset',
                                                child: Row(children: [
                                                  Icon(Icons.lock_reset,
                                                      color: Colors.orange),
                                                  SizedBox(width: 8),
                                                  Text("Zerar Senha")
                                                ])),
                                            const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(children: [
                                                  Icon(Icons.delete,
                                                      color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text("Excluir")
                                                ])),
                                          ],
                                        )
                                      : const Icon(Icons.chevron_right),
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),

                  // --- ABA 2: RELATÓRIOS ---
                  _buildRelatoriosTab(allDocs),
                ],
              );
            },
          ),
        );
      },
    );
  }
}