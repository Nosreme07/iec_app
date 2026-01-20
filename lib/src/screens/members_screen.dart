import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/admin_config.dart';
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

  void _showMemberDetails(Map<String, dynamic> data, bool isAdmin) {
    String get(String key) => (data[key] ?? "").toString();
    String nomeDisplay = get('nome_completo');
    if (nomeDisplay.isEmpty) nomeDisplay = get('nome'); 
    String? fotoUrl = data['foto_url'];

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
                backgroundColor: Colors.indigo[100],
                backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                child: fotoUrl == null ? const Icon(Icons.person, size: 60, color: Colors.indigo) : null,
              ),
              const SizedBox(height: 10),
              Text(nomeDisplay, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              
              if (get('role') == 'admin')
                Container(margin: const EdgeInsets.only(top: 5), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12)), child: const Text("ADMINISTRADOR DO SISTEMA", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange))),

              Divider(height: 30, color: Colors.indigo[100]),
              
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionTitle("Informações Gerais"),
                    // --- AQUI ESTÁ A MUDANÇA: SANGUE AGORA É PÚBLICO ---
                    _buildRow(Icons.bloodtype, "Tipo Sanguíneo", get('grupo_sanguineo')), 
                    // ---------------------------------------------------
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

                    if (isAdmin) ...[
                      const SizedBox(height: 20),
                      Container(padding: const EdgeInsets.all(8), color: Colors.blue[50], child: const Center(child: Text("FICHA COMPLETA (ADMIN)", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))),
                      _buildSectionTitle("Dados Pessoais"),
                      _buildRow(Icons.badge, "CPF", get('cpf')),
                      _buildRow(Icons.face, "Sexo", get('sexo')),
                      // _buildRow(Icons.bloodtype, "Sangue", get('grupo_sanguineo')), // REMOVIDO DAQUI POIS JÁ ESTÁ LÁ EM CIMA
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
    final bool isAdmin = AdminConfig.isUserAdmin();

    return Scaffold(
      appBar: AppBar(title: const Text("Rol de Membros", style: TextStyle(color: Colors.white)), backgroundColor: Colors.indigo, iconTheme: const IconThemeData(color: Colors.white)),
      floatingActionButton: isAdmin ? FloatingActionButton(onPressed: _addNewMember, backgroundColor: Colors.indigo, child: const Icon(Icons.person_add, color: Colors.white)) : null,
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: TextField(onChanged: (value) => setState(() => _searchText = value.toLowerCase()), decoration: InputDecoration(labelText: 'Buscar membro (nome)', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey[100]))),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
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

                    if (oficial != "NENHUM" && oficial.isNotEmpty && oficial != "null") subtitulo += " / $oficial";
                    bool isThisUserAdmin = data['role'] == 'admin';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isThisUserAdmin ? Colors.orange[100] : Colors.indigo[100],
                          backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                          child: fotoUrl == null 
                            ? Icon(isThisUserAdmin ? Icons.verified_user : Icons.person, color: isThisUserAdmin ? Colors.orange[800] : Colors.indigo[800]) 
                            : null,
                        ),
                        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(subtitulo, style: TextStyle(color: Colors.grey[700])),
                        trailing: isAdmin 
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
                        onTap: () => _showMemberDetails(data, isAdmin),
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