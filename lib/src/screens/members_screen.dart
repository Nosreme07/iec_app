import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_register_screen.dart';

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
    // Inicia o controlador das abas (2 abas: Lista e Relatórios)
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
  // WIDGET DA ABA DE RELATÓRIOS (NOVO)
  // ==========================================
  Widget _buildRelatoriosTab(List<QueryDocumentSnapshot> docs) {
    int totalMembros = 0;
    int totalVisitantes = 0;
    int totalAdmins = 0;
    List<Map<String, dynamic>> oficiais = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final role = (data['role'] ?? "").toString().toLowerCase();
      final oficial = (data['oficial_igreja'] ?? "").toString();

      if (role == 'visitante') {
        totalVisitantes++;
      } else {
        totalMembros++; // Considera admin e financeiro como membros também
      }

      if (role == 'admin') totalAdmins++;

      if (oficial.isNotEmpty && oficial != "null" && oficial != "NENHUM") {
        oficiais.add(data);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Resumo Geral",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _buildInfoCard("Membros", totalMembros.toString(),
                    Icons.people, Colors.blue)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildInfoCard("Visitantes", totalVisitantes.toString(),
                    Icons.emoji_people, Colors.purple)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _buildInfoCard(
                    "Total de Cadastros",
                    docs.length.toString(),
                    Icons.format_list_numbered,
                    Colors.indigo)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildInfoCard("Administradores", totalAdmins.toString(),
                    Icons.admin_panel_settings, Colors.deepOrange)),
          ],
        ),

        const SizedBox(height: 25),
        const Text("Quadro de Oficiais",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        if (oficiais.isEmpty)
          const Text("Nenhum oficial cadastrado.",
              style: TextStyle(color: Colors.grey)),

        ...oficiais.map((oficial) {
          String nome = oficial['nome_completo'] ?? "Sem Nome";
          if (nome.isEmpty) nome = oficial['nome'] ?? "";

          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.shield, color: Colors.white, size: 18)),
              title: Text(_obterNomeSobrenome(nome),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(oficial['oficial_igreja'] ?? ""),
            ),
          );
        }).toList(),

        // Espaço no final para não cobrir nada
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildInfoCard(
      String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(count,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
        ],
      ),
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
            // ADICIONADO: O Título agora tem abas na parte inferior do AppBar
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.orange,
              tabs: const [
                Tab(icon: Icon(Icons.list), text: "Lista"),
                Tab(icon: Icon(Icons.bar_chart), text: "Relatórios"),
              ],
            ),
          ),
          floatingActionButton: canManage
              ? FloatingActionButton(
                  onPressed: _addNewMember,
                  backgroundColor: Colors.indigo,
                  child: const Icon(Icons.person_add, color: Colors.white))
              : null,

          // ADICIONADO: O corpo agora é um TabBarView que alterna entre a lista e os relatórios
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
                            // RESOLVIDO: O PADDING AQUI EVITA QUE O BOTÃO CUBRA O ÚLTIMO ITEM
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              String nomeCompleto =
                                  data['nome_completo'] ?? "Sem Nome";
                              String nomeExibicao = data['apelido'] != null &&
                                      data['apelido'].isNotEmpty
                                  ? data['apelido']
                                  : _obterNomeSobrenome(nomeCompleto);

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
                                  title: Text(nomeExibicao,
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
