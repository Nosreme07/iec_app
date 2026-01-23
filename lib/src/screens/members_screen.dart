import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_register_screen.dart'; 

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _searchText = "";

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

  // --- POPUP DE DETALHES ---
  void _showMemberDetails(Map<String, dynamic> data, bool canManage) {
    String get(String key) => (data[key] ?? "").toString();
    String nomeDisplay = get('nome_completo');
    if (nomeDisplay.isEmpty) nomeDisplay = get('nome'); 
    String? fotoUrl = data['foto_url'];
    String role = get('role');

    // Configuração visual do Header do Popup
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
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              // FOTO E CABEÇALHO
              CircleAvatar(
                radius: 50,
                backgroundColor: headerColor.withOpacity(0.2),
                backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                child: fotoUrl == null ? Icon(Icons.person, size: 60, color: headerColor) : null,
              ),
              const SizedBox(height: 10),
              Text(nomeDisplay, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              
              // ETIQUETA DE CARGO NO DETALHE
              if (labelRole.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 5), 
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                  decoration: BoxDecoration(color: headerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: headerColor.withOpacity(0.5))), 
                  child: Text(labelRole, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: headerColor))
                ),

              Divider(height: 30, color: Colors.indigo[100]),
              
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionTitle("Informações Gerais"),
                    _buildRow(Icons.bloodtype, "Tipo Sanguíneo", get('grupo_sanguineo')), 
                    _buildRow(Icons.cake, "Nascimento", get('nascimento')),
                    _buildRow(Icons.location_on, "Endereço", "${get('endereco')}, ${get('numero')}"),
                    _buildRow(Icons.map, "Bairro/Comp", "${get('bairro')} - ${get('complemento')}"),
                    _buildRow(Icons.phone_android, "WhatsApp", get('whatsapp')),
                    _buildRow(Icons.phone, "Telefone", get('telefone')),
                    
                    ListTile(
                      leading: const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                      title: const Text("Situação", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      subtitle: Text(get('situacao').toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: get('situacao').toUpperCase() == 'ATIVO' ? Colors.green : Colors.black)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (get('filhos').isNotEmpty) ...[const SizedBox(height: 10), const Text("Filhos:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)), Text(get('filhos'), style: const TextStyle(fontSize: 14))],

                    // DADOS EXTRAS VISÍVEIS APENAS PARA QUEM TEM PERMISSÃO (ADMIN OU FINANCEIRO)
                    if (canManage) ...[
                      const SizedBox(height: 20),
                      Container(padding: const EdgeInsets.all(8), color: Colors.blue[50], child: const Center(child: Text("FICHA COMPLETA (ACESSO RESTRITO)", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))),
                      _buildSectionTitle("Dados Pessoais"),
                      _buildRow(Icons.badge, "CPF", get('cpf')),
                      _buildRow(Icons.face, "Sexo", get('sexo')),
                      _buildRow(Icons.person_outline, "Pai", get('pai')),
                      _buildRow(Icons.person_outline, "Mãe", get('mae')),
                      _buildRow(Icons.school, "Escolaridade", get('escolaridade')),
                      _buildRow(Icons.work, "Profissão", get('profissao')),
                      
                      _buildSectionTitle("Vida Eclesiástica"),
                      _buildRow(Icons.star, "Cargo", get('cargo_atual')),
                      _buildRow(Icons.shield, "Oficial", get('oficial_igreja')),
                      _buildRow(Icons.groups, "Departamento", get('departamento')),
                      _buildRow(Icons.church, "Membro Desde", get('membro_desde')),
                      _buildRow(Icons.water_drop, "Batismo", get('batismo_aguas')),
                      
                      _buildSectionTitle("Família"),
                      _buildRow(Icons.favorite, "Estado Civil", get('estado_civil')),
                      _buildRow(Icons.event, "Casamento", get('data_casamento')),
                      _buildRow(Icons.person_add, "Cônjuge", get('conjuge')),

                      if (get('observacoes').isNotEmpty) ...[const SizedBox(height: 10), _buildSectionTitle("Observações"), Text(get('observacoes'), style: const TextStyle(fontStyle: FontStyle.italic))]
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

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(top: 15, bottom: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.bold, fontSize: 15)), Divider(height: 5, color: Colors.indigo[100])]));
  }

  Widget _buildRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty || value == "null") return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 16, color: Colors.grey[600]), const SizedBox(width: 8), Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 14), children: [TextSpan(text: "$label: ", style: TextStyle(color: Colors.grey[700], fontSize: 12)), TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w500))])))]));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return const Center(child: Text("Erro: Não logado"));

    // 1. STREAM PARA VERIFICAR PERMISSÕES
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
              Padding(padding: const EdgeInsets.all(16.0), child: TextField(onChanged: (value) => setState(() => _searchText = value.toLowerCase()), decoration: InputDecoration(labelText: 'Buscar membro (nome)', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[100]))),
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').orderBy('nome_completo').snapshots(), // Ordenado por nome
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text("Erro ao carregar membros."));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data!.docs;
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final nome = (data['nome_completo'] ?? data['nome'] ?? "").toString().toLowerCase();
                      return nome.contains(_searchText);
                    }).toList();

                    if (filteredDocs.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people_outline, size: 50, color: Colors.grey), SizedBox(height: 10), Text("Nenhum membro encontrado.", style: TextStyle(color: Colors.grey))]));

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        
                        String nome = data['nome_completo'] ?? data['nome'] ?? "Sem Nome";
                        String cargo = data['cargo_atual'] ?? data['role'] ?? "-";
                        String oficial = data['oficial_igreja'] ?? "NENHUM";
                        String subtitulo = cargo;
                        String? fotoUrl = data['foto_url'];
                        String role = data['role'] ?? 'membro';

                        if (oficial != "NENHUM" && oficial.isNotEmpty && oficial != "null") subtitulo += " / $oficial";
                        
                        // --- LÓGICA DE CORES DOS CARDS ---
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
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: avatarBg,
                              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                              child: fotoUrl == null 
                                ? Icon(avatarIcon, color: avatarIconColor) 
                                : null,
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                if (roleBadge != null) ...[
                                  const SizedBox(width: 5),
                                  roleBadge,
                                ]
                              ],
                            ),
                            subtitle: Text(subtitulo, style: TextStyle(color: Colors.grey[700])),
                            
                            // MENU DE AÇÕES
                            trailing: canManage 
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') _editMember(doc.id, data);
                                    if (value == 'delete') _deleteMember(doc.id, nome);
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Editar')])),
                                    const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Excluir')])),
                                  ],
                                )
                              : const Icon(Icons.chevron_right, color: Colors.grey),
                            
                            onTap: () => _showMemberDetails(data, canManage),
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}