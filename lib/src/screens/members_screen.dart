import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/admin_config.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _searchText = "";

  // Função para excluir membro (Apenas Admin)
  Future<void> _deleteMember(String docId, String nome) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir Membro"),
        content: Text("Tem certeza que deseja remover $nome da lista?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("EXCLUIR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Membro removido.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erro ao excluir.")),
          );
        }
      }
    }
  }

  // --- FUNÇÃO DE DETALHES ---
  void _showMemberDetails(Map<String, dynamic> data, bool isAdmin) {
    String get(String key) => (data[key] ?? "").toString();
    String nomeDisplay = get('nome_completo');
    if (nomeDisplay.isEmpty) nomeDisplay = get('nome'); 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.indigo,
                          child: Icon(Icons.person, size: 50, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          nomeDisplay,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: get('situacao').toLowerCase() == 'ativo' ? Colors.green[50] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: get('situacao').toLowerCase() == 'ativo' ? Colors.green : Colors.grey
                            )
                          ),
                          child: Text(
                            get('situacao').isEmpty ? "Situação não inf." : get('situacao').toUpperCase(),
                            style: TextStyle(
                              color: get('situacao').toLowerCase() == 'ativo' ? Colors.green[800] : Colors.black54, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 12
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 30),

                  // DADOS PÚBLICOS
                  _buildSectionTitle("Informações Gerais"),
                  _buildRow(Icons.cake, "Nascimento", get('nascimento')),
                  const SizedBox(height: 10),
                  _buildRow(Icons.location_on, "Endereço", "${get('endereco')}, ${get('numero')}"),
                  _buildRow(Icons.map, "Comp./Bairro", "${get('complemento')} - ${get('bairro')}"),
                  _buildRow(Icons.location_city, "Cidade/CEP", "${get('cidade')}/${get('uf')} - ${get('cep')}"),
                  const SizedBox(height: 10),
                  _buildRow(Icons.phone_android, "WhatsApp", get('whatsapp')),
                  _buildRow(Icons.phone, "Telefone", get('telefone')),
                  _buildRow(Icons.email, "E-mail", get('email')),

                  if (get('filhos').isNotEmpty) ...[
                    const SizedBox(height: 15),
                    const Text("Filhos:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
                      child: Text(get('filhos')),
                    ),
                  ],

                  // DADOS RESTRITOS (ADMIN)
                  if (isAdmin) ...[
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      color: Colors.red[50],
                      child: Row(
                        children: [
                          Icon(Icons.lock, size: 16, color: Colors.red[800]),
                          const SizedBox(width: 8),
                          Text("ÁREA RESTRITA AO ADMINISTRADOR", style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildSectionTitle("Dados Pessoais Completos"),
                    _buildRow(Icons.badge, "CPF", get('cpf')),
                    _buildRow(Icons.face, "Sexo", get('sexo')),
                    _buildRow(Icons.person_outline, "Pai", get('pai')),
                    _buildRow(Icons.person_outline, "Mãe", get('mae')),
                    _buildRow(Icons.bloodtype, "Sangue", get('grupo_sanguineo')),
                    _buildRow(Icons.school, "Escolaridade", get('escolaridade')),
                    _buildRow(Icons.work, "Profissão", get('profissao')),
                    _buildRow(Icons.drive_eta, "CNH", get('habilitacao')),
                    _buildRow(Icons.flag, "Nacionalidade", "${get('naturalidade')} - ${get('nacionalidade')}"),

                    const SizedBox(height: 10),
                    _buildSectionTitle("Dados Conjugais"),
                    _buildRow(Icons.favorite, "Estado Civil", get('estado_civil')),
                    _buildRow(Icons.event, "Casamento", get('data_casamento')),
                    _buildRow(Icons.person_add, "Cônjuge", get('conjuge')),

                    const SizedBox(height: 10),
                    _buildSectionTitle("Vida Eclesiástica"),
                    _buildRow(Icons.star, "Cargo Atual", get('cargo_atual')),
                    _buildRow(Icons.calendar_month, "Membro Desde", get('membro_desde')),
                    _buildRow(Icons.water_drop, "Batismo", get('batismo_aguas')),
                    _buildRow(Icons.church, "Veio de", get('igreja_anterior')),
                    _buildRow(Icons.star_border, "Cargo Anterior", get('cargo_anterior')),
                    _buildRow(Icons.star, "Consagração", get('data_consagracao')),
                    _buildRow(Icons.groups, "Departamento", get('departamento')),

                    if (get('observacoes').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildSectionTitle("Observações"),
                      Text(get('observacoes'), style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ],

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      child: const Text("FECHAR"),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.bold, fontSize: 16)),
          Divider(color: Colors.indigo[100]),
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty || value == "null") return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(text: "$label: ", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                  TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = AdminConfig.isUserAdmin();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rol de Membros", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // BARRA DE PESQUISA
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchText = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                labelText: 'Buscar membro (nome)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // LISTA DE MEMBROS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erro ao carregar membros."));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final docs = snapshot.data!.docs;

                // Filtragem local
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = (data['nome_completo'] ?? data['nome'] ?? "").toString().toLowerCase();
                  return nome.contains(_searchText);
                }).toList();

                if (filteredDocs.isEmpty) return const Center(child: Text("Nenhum membro encontrado."));

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final String nome = data['nome_completo'] ?? data['nome'] ?? "Sem Nome";
                    final String cargo = data['cargo_atual'] ?? data['role'] ?? "Membro";
                    final String primeiraLetra = nome.isNotEmpty ? nome[0].toUpperCase() : "?";

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo[100],
                          child: Text(
                            primeiraLetra,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[900]),
                          ),
                        ),
                        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(cargo),
                        
                        trailing: isAdmin 
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteMember(doc.id, nome),
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