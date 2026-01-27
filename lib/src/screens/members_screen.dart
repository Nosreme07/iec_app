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

class _MembersScreenState extends State<MembersScreen> {
  String _searchText = "";

  // --- FUNÇÕES UTILITÁRIAS ---
  void _editMember(String docId, Map<String, dynamic> data) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => AdminRegisterScreen(memberId: docId, memberData: data)));
  }

  void _addNewMember() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRegisterScreen()));
  }

  Future<void> _deleteMember(String docId, String nome) async {
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Excluir Membro"), content: Text("Tem certeza que deseja remover $nome?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("EXCLUIR", style: TextStyle(color: Colors.red)))])) ?? false;
    if (confirm) await FirebaseFirestore.instance.collection('users').doc(docId).delete();
  }

  Future<void> _openWhatsApp(String phone, {String? message}) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), ''); 
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Número de WhatsApp não cadastrado.")));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir o WhatsApp")));
    }
  }

  Future<void> _makeCall(String phone) async {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Telefone não cadastrado.")));
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
    
    // 1. Pega o Nome Completo e Apelido
    String nomeCompleto = get('nome_completo');
    if (nomeCompleto.isEmpty) nomeCompleto = get('nome'); 
    String apelido = get('apelido');

    // 2. Define o Nome de Exibição Principal (Apelido tem prioridade)
    String nomeExibicaoPrincipal = apelido.isNotEmpty ? apelido : nomeCompleto;
    
    // 3. Define o nome para mensagem do WhatsApp (mais informal se tiver apelido)
    String nomeParaMensagem = apelido.isNotEmpty ? apelido : nomeCompleto.split(' ')[0];

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
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),

              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: headerColor.withOpacity(0.2),
                    backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                    child: fotoUrl == null ? Icon(Icons.person, size: 60, color: headerColor) : null,
                  ),
                  if (_isBirthdayMonth(get('nascimento')))
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        // Usando nomeParaMensagem (Apelido ou 1º Nome)
                        onTap: () => _openWhatsApp(whatsapp, message: "Graça e Paz, $nomeParaMensagem! Feliz aniversário! Que Deus continue te abençoando grandemente! 🎉🙏"),
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Text("🎂", style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 10),
              
              // --- TÍTULO DO POPUP (NOME / APELIDO) ---
              Text(nomeExibicaoPrincipal, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              
              // Se estiver mostrando o apelido em cima, mostra o nome completo embaixo
              if (apelido.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(nomeCompleto, style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
                ),

              if (labelRole.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8), 
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                  decoration: BoxDecoration(color: headerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: headerColor.withOpacity(0.5))), 
                  child: Text(labelRole, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: headerColor))
                ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (whatsapp.isNotEmpty)
                      _actionButton(Icons.chat, "WhatsApp", Colors.green, () => _openWhatsApp(whatsapp)),
                    if (whatsapp.isNotEmpty && telefone.isNotEmpty) const SizedBox(width: 20),
                    if (telefone.isNotEmpty)
                      _actionButton(Icons.phone, "Ligar", Colors.blue, () => _makeCall(telefone)),
                  ],
                ),
              ),

              Divider(height: 10, color: Colors.indigo[100]),
              
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionTitle("Informações Públicas"),
                    
                    // Se não tiver apelido, não mostra campo extra. Se tiver, já está no título.
                    // Mas se quiser reforçar, pode descomentar a linha abaixo:
                    // if (apelido.isNotEmpty) _buildRow(Icons.face, "Apelido", apelido),

                    _buildRow(Icons.cake, "Nascimento", get('nascimento')),
                    _buildRow(Icons.bloodtype, "Tipo Sanguíneo", get('grupo_sanguineo')), 
                    _buildRow(Icons.star, "Cargo Eclesiástico", get('cargo_atual')),
                    _buildRow(Icons.shield, "Oficial", get('oficial_igreja')),
                    _buildRow(Icons.groups, "Departamento", get('departamento')),
                    
                    if (whatsapp.isNotEmpty) _buildRow(Icons.phone_android, "WhatsApp", whatsapp),
                    if (telefone.isNotEmpty) _buildRow(Icons.phone, "Telefone", telefone),

                    if (canManage) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(8), 
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)), 
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_open, size: 16, color: Colors.red[800]),
                            const SizedBox(width: 8),
                            Text("FICHA COMPLETA (ADMIN/FIN)", style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold)),
                          ],
                        )
                      ),
                      
                      _buildSectionTitle("Endereço & Residência"),
                      _buildRow(Icons.location_on, "Endereço", "${get('endereco')}, ${get('numero')}"),
                      _buildRow(Icons.map, "Bairro", get('bairro')),
                      _buildRow(Icons.location_city, "Cidade/UF", "${get('cidade')} - ${get('uf')}"),
                      _buildRow(Icons.markunread_mailbox, "CEP", get('cep')),
                      _buildRow(Icons.home_work, "Complemento", get('complemento')),

                      _buildSectionTitle("Dados Pessoais & Documentos"),
                      ListTile(
                        leading: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                        title: const Text("Situação Cadastral", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        subtitle: Text(get('situacao').toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: get('situacao').toUpperCase() == 'ATIVO' ? Colors.green : Colors.black)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      _buildRow(Icons.badge, "CPF", get('cpf')),
                      _buildRow(Icons.face, "Sexo", get('sexo')),
                      _buildRow(Icons.person_outline, "Pai", get('pai')),
                      _buildRow(Icons.person_outline, "Mãe", get('mae')),
                      _buildRow(Icons.school, "Escolaridade", get('escolaridade')),
                      _buildRow(Icons.work, "Profissão", get('profissao')),
                      
                      _buildSectionTitle("Histórico da Igreja"),
                      _buildRow(Icons.church, "Membro Desde", get('membro_desde')),
                      _buildRow(Icons.water_drop, "Batismo", get('batismo_aguas')),
                      _buildRow(Icons.handshake, "Admissão", get('tipo_admissao')),
                      
                      _buildSectionTitle("Família"),
                      _buildRow(Icons.favorite, "Estado Civil", get('estado_civil')),
                      _buildRow(Icons.event, "Casamento", get('data_casamento')),
                      _buildRow(Icons.person_add, "Cônjuge", get('conjuge')),
                      
                      if (get('filhos').isNotEmpty) ...[
                        const SizedBox(height: 5), 
                        const Text("Filhos:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)), 
                        Text(get('filhos'), style: const TextStyle(fontSize: 14))
                      ],

                      if (get('observacoes').isNotEmpty) ...[
                        const SizedBox(height: 10), 
                        _buildSectionTitle("Observações"), 
                        Text(get('observacoes'), style: const TextStyle(fontStyle: FontStyle.italic))
                      ],
                      
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            (data['autoriza_compartilhamento'] ?? false) ? Icons.check_circle : Icons.cancel,
                            color: (data['autoriza_compartilhamento'] ?? false) ? Colors.green : Colors.red,
                            size: 16
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (data['autoriza_compartilhamento'] ?? false) 
                              ? "Autorizou compartilhamento de dados" 
                              : "NÃO autorizou compartilhamento",
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
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

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(top: 15, bottom: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.bold, fontSize: 15)), Divider(height: 5, color: Colors.indigo[100])]));
  }

  Widget _buildRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty || value == "null") return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: Colors.grey[600]), const SizedBox(width: 10), Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [TextSpan(text: "$label: ", style: TextStyle(color: Colors.grey[700], fontSize: 12)), TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w500))])))]));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return const Center(child: Text("Erro: Não logado"));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
      builder: (context, userSnapshot) {
        
        bool canManage = false; 
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          String myRole = userData['role'] ?? 'membro';
          canManage = myRole == 'admin' || myRole == 'financeiro';
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Rol de Membros", style: TextStyle(color: Colors.white)), backgroundColor: Colors.indigo, iconTheme: const IconThemeData(color: Colors.white)),
          
          floatingActionButton: canManage 
            ? FloatingActionButton(onPressed: _addNewMember, backgroundColor: Colors.indigo, child: const Icon(Icons.person_add, color: Colors.white)) 
            : null,
          
          body: Column(
            children: [
              Padding(padding: const EdgeInsets.all(16.0), child: TextField(onChanged: (value) => setState(() => _searchText = value.toLowerCase()), decoration: InputDecoration(labelText: 'Buscar membro', hintText: 'Nome, Apelido, Cargo ou Depto', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[100]))),
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').orderBy('nome_completo').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("Erro ao carregar membros."));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data!.docs;
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final nome = (data['nome_completo'] ?? data['nome'] ?? "").toString().toLowerCase();
                      final apelido = (data['apelido'] ?? "").toString().toLowerCase();
                      final cargo = (data['cargo_atual'] ?? "").toString().toLowerCase();
                      final depto = (data['departamento'] ?? "").toString().toLowerCase();
                      return nome.contains(_searchText) || apelido.contains(_searchText) || cargo.contains(_searchText) || depto.contains(_searchText);
                    }).toList();

                    if (filteredDocs.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 50, color: Colors.grey), SizedBox(height: 10), Text("Nenhum membro encontrado.", style: TextStyle(color: Colors.grey))]));

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        
                        String nomeCompleto = data['nome_completo'] ?? data['nome'] ?? "Sem Nome";
                        String apelido = data['apelido'] ?? "";
                        
                        // LÓGICA DE EXIBIÇÃO NO CARD (LISTA)
                        String nomeExibicao = apelido.isNotEmpty ? apelido : nomeCompleto;

                        String cargo = data['cargo_atual'] ?? data['role'] ?? "-";
                        String oficial = data['oficial_igreja'] ?? "NENHUM";
                        String subtitulo = cargo;
                        String? fotoUrl = data['foto_url'];
                        String role = data['role'] ?? 'membro';
                        bool isBirthday = _isBirthdayMonth(data['nascimento']);
                        String whatsapp = data['whatsapp'] ?? "";

                        if (oficial != "NENHUM" && oficial.isNotEmpty && oficial != "null") subtitulo += " / $oficial";
                        
                        Color avatarBg = Colors.indigo[100]!;
                        Color avatarIconColor = Colors.indigo[800]!;
                        IconData avatarIcon = Icons.person;
                        Color? cardBorderColor;
                        Widget? roleBadge;

                        if (role == 'admin') {
                          avatarBg = Colors.orange[100]!;
                          avatarIconColor = Colors.deepOrange;
                          avatarIcon = Icons.verified_user;
                          cardBorderColor = Colors.orange.withOpacity(0.3);
                          roleBadge = _buildSmallBadge("ADM", Colors.deepOrange);
                        } else if (role == 'financeiro') {
                          avatarBg = Colors.green[100]!;
                          avatarIconColor = Colors.green[800]!;
                          avatarIcon = Icons.attach_money;
                          cardBorderColor = Colors.green.withOpacity(0.3);
                          roleBadge = _buildSmallBadge("FIN", Colors.green);
                        } else if (role == 'visitante') {
                          avatarBg = Colors.purple[100]!;
                          avatarIconColor = Colors.purple[800]!;
                          avatarIcon = Icons.emoji_people;
                          cardBorderColor = Colors.purple.withOpacity(0.3);
                          roleBadge = _buildSmallBadge("VISITANTE", Colors.purple);
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: cardBorderColor != null ? BorderSide(color: cardBorderColor, width: 1.5) : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () => _showMemberDetails(data, canManage),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: avatarBg,
                                        backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                                        child: fotoUrl == null ? Icon(avatarIcon, color: avatarIconColor) : null,
                                      ),
                                      if (isBirthday)
                                        Positioned(
                                          right: -4,
                                          top: -4,
                                          child: GestureDetector(
                                            // Usando apelido ou primeiro nome na mensagem rápida também
                                            onTap: () => _openWhatsApp(whatsapp, message: "Paz do Senhor, ${apelido.isNotEmpty ? apelido : nomeCompleto.split(' ')[0]}! Feliz aniversário! Que Deus te abençoe! 🎉"),
                                            child: Container(
                                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)]),
                                              padding: const EdgeInsets.all(4),
                                              child: const Text("🎂", style: TextStyle(fontSize: 16)),
                                            ),
                                          ),
                                        )
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(child: Text(nomeExibicao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                            if (roleBadge != null) ...[const SizedBox(width: 5), roleBadge],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(subtitulo, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                      ],
                                    ),
                                  ),

                                  if (canManage)
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                                      onSelected: (value) {
                                        if (value == 'edit') _editMember(doc.id, data);
                                        if (value == 'delete') _deleteMember(doc.id, nomeCompleto);
                                      },
                                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Editar')])),
                                        const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Excluir')])),
                                      ],
                                    )
                                  else
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
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
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.5), width: 0.5)),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}