import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// --- COR PRINCIPAL DA E.B.D ---
const Color ebdColor = Color.fromARGB(255, 130, 2, 216);

// ==========================================
// TELA PRINCIPAL (CONTROLLER DAS ABAS)
// ==========================================
class EbdScreen extends StatelessWidget {
  const EbdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("E.B.D",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: ebdColor,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.meeting_room), text: "SALAS"),
              Tab(icon: Icon(Icons.bar_chart), text: "RELATÓRIO"),
              Tab(icon: Icon(Icons.people), text: "ALUNOS"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EbdSalasTab(),
            EbdRelatoriosTab(),
            EbdAlunosTab(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ABA 1: GESTÃO DAS SALAS
// ==========================================
class EbdSalasTab extends StatefulWidget {
  const EbdSalasTab({super.key});

  @override
  State<EbdSalasTab> createState() => _EbdSalasTabState();
}

class _EbdSalasTabState extends State<EbdSalasTab> {
  void _showSalaDialog({String? docId, String? nomeAtual}) {
    final controller = TextEditingController(text: nomeAtual);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(docId == null ? "Nova Sala" : "Editar Sala"),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: "Nome da Sala", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ebdColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              if (docId == null) {
                await FirebaseFirestore.instance.collection('ebd_salas').add({
                  'nome': controller.text.trim(),
                  'alunos': [],
                  'criado_em': FieldValue.serverTimestamp(),
                });
              } else {
                await FirebaseFirestore.instance
                    .collection('ebd_salas')
                    .doc(docId)
                    .update({'nome': controller.text.trim()});
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  Future<void> _deleteSala(String docId, String nome) async {
    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text("Excluir Sala"),
                    content: Text("Deseja apagar a sala '$nome'?"),
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

    if (confirm)
      await FirebaseFirestore.instance
          .collection('ebd_salas')
          .doc(docId)
          .delete();
  }

  Future<void> _criarSalasPadrao() async {
    List<String> padroes = ["Mulheres", "Homens", "Crianças", "Adolescentes"];
    for (String nome in padroes) {
      await FirebaseFirestore.instance.collection('ebd_salas').add({
        'nome': nome,
        'alunos': [],
        'criado_em': FieldValue.serverTimestamp()
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          bool canManage = false;
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            String role = userData['role'] ?? 'membro';
            canManage = role == 'admin' || role == 'financeiro';
          }

          return Scaffold(
            backgroundColor: Colors.grey[100],
            floatingActionButton: canManage
                ? FloatingActionButton.extended(
                    heroTag: "btn_nova_sala",
                    onPressed: () => _showSalaDialog(),
                    backgroundColor: ebdColor,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Nova Sala",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                : null,
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ebd_salas')
                  .orderBy('nome')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                final salas = snapshot.data?.docs ?? [];

                if (salas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school_outlined,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text("Nenhuma sala cadastrada.",
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 20),
                        if (canManage)
                          ElevatedButton.icon(
                            onPressed: _criarSalasPadrao,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text("Criar Salas Padrão"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: ebdColor,
                                foregroundColor: Colors.white),
                          )
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: salas.length,
                  itemBuilder: (context, index) {
                    final data = salas[index].data() as Map<String, dynamic>;
                    final docId = salas[index].id;
                    final nome = data['nome'] ?? "Sala";
                    final alunos = List<String>.from(data['alunos'] ?? []);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                            backgroundColor: ebdColor.withOpacity(0.2),
                            child: const Icon(Icons.meeting_room,
                                color: ebdColor)),
                        title: Text(nome,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        subtitle: Text("${alunos.length} alunos matriculados",
                            style: TextStyle(color: Colors.grey[600])),
                        trailing: canManage
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () => _showSalaDialog(
                                          docId: docId, nomeAtual: nome)),
                                  IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _deleteSala(docId, nome)),
                                ],
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => EbdChamadaScreen(
                                    salaId: docId, salaNome: nome))),
                      ),
                    );
                  },
                );
              },
            ),
          );
        });
  }
}

// ==========================================
// ABA 2: RELATÓRIOS (GRÁFICO, SALAS E ALUNOS)
// ==========================================
class EbdRelatoriosTab extends StatefulWidget {
  const EbdRelatoriosTab({super.key});

  @override
  State<EbdRelatoriosTab> createState() => _EbdRelatoriosTabState();
}

class _EbdRelatoriosTabState extends State<EbdRelatoriosTab> {
  bool _isMonthly = false;
  late DateTime _dataSelecionada;

  @override
  void initState() {
    super.initState();
    _dataSelecionada = DateTime.now();
    _dataSelecionada = DateTime(
        _dataSelecionada.year, _dataSelecionada.month, _dataSelecionada.day);
  }

  void _alterarData(int delta) {
    setState(() {
      if (_isMonthly) {
        _dataSelecionada =
            DateTime(_dataSelecionada.year, _dataSelecionada.month + delta, 1);
      } else {
        _dataSelecionada = _dataSelecionada.add(Duration(days: delta));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime inicioBusca;
    DateTime fimBusca;

    if (_isMonthly) {
      inicioBusca = DateTime(_dataSelecionada.year, _dataSelecionada.month, 1);
      fimBusca = DateTime(
          _dataSelecionada.year, _dataSelecionada.month + 1, 0, 23, 59, 59);
    } else {
      inicioBusca = DateTime(
          _dataSelecionada.year, _dataSelecionada.month, _dataSelecionada.day);
      fimBusca = DateTime(_dataSelecionada.year, _dataSelecionada.month,
          _dataSelecionada.day, 23, 59, 59);
    }

    String textoFiltro = _isMonthly
        ? DateFormat('MMMM yyyy', 'pt_BR')
            .format(_dataSelecionada)
            .toUpperCase()
        : DateFormat('dd/MM/yyyy', 'pt_BR').format(_dataSelecionada);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          Container(
            color: ebdColor.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Diário",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                        value: _isMonthly,
                        activeColor: ebdColor,
                        onChanged: (val) => setState(() => _isMonthly = val)),
                    const Text("Mensal",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 18),
                        onPressed: () => _alterarData(-1)),
                    Text(textoFiltro,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: ebdColor)),
                    IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 18),
                        onPressed: () => _alterarData(1)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
              child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('ebd_salas')
                      .snapshots(),
                  builder: (context, snapshotSalas) {
                    if (!snapshotSalas.hasData)
                      return const Center(child: CircularProgressIndicator());
                    List<DocumentSnapshot> salasDocs = snapshotSalas.data!.docs;

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('ebd_registros')
                          .where('data',
                              isGreaterThanOrEqualTo:
                                  Timestamp.fromDate(inicioBusca))
                          .where('data',
                              isLessThanOrEqualTo: Timestamp.fromDate(fimBusca))
                          .snapshots(),
                      builder: (context, snapshotRegistros) {
                        if (!snapshotRegistros.hasData)
                          return const Center(
                              child: CircularProgressIndicator());

                        final relatorios = snapshotRegistros.data!.docs;

                        int totalPresentes = 0;
                        int totalAusentes = 0;
                        double totalOfertas = 0.0;
                        Set<String> diasLetivos = {};

                        Map<String, Map<String, dynamic>> dadosPorSala = {};
                        for (var s in salasDocs) {
                          dadosPorSala[s.id] = {
                            'nome': s['nome'],
                            'alunos': List<String>.from(s['alunos'] ?? []),
                            'presentes': 0,
                            'faltas': 0,
                            'oferta': 0.0,
                            'aulas_dadas': 0
                          };
                        }

                        for (var doc in relatorios) {
                          var data = doc.data() as Map<String, dynamic>;
                          String sid = data['sala_id'];
                          int p = (data['presentes'] as List?)?.length ?? 0;
                          int a = data['ausentes'] ?? 0;
                          double o = (data['oferta'] ?? 0.0).toDouble();
                          diasLetivos.add(data['data_str']);

                          totalPresentes += p;
                          totalAusentes += a;
                          totalOfertas += o;

                          if (dadosPorSala.containsKey(sid)) {
                            dadosPorSala[sid]!['presentes'] += p;
                            dadosPorSala[sid]!['faltas'] += a;
                            dadosPorSala[sid]!['oferta'] += o;
                            dadosPorSala[sid]!['aulas_dadas'] += 1;
                          }
                        }

                        int totalMatriculadosGlobal =
                            totalPresentes + totalAusentes;
                        double percGeral = totalMatriculadosGlobal > 0
                            ? (totalPresentes / totalMatriculadosGlobal) * 100
                            : 0;

                        return Stack(
                          children: [
                            ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 12, 12, 80),
                              children: [
                                Card(
                                  color: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        const Text(
                                            "MÉDIA DE FREQUÊNCIA DA E.B.D",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        const SizedBox(height: 10),
                                        if (totalMatriculadosGlobal == 0)
                                          const Text(
                                              "Sem aulas registradas no período",
                                              style:
                                                  TextStyle(color: Colors.grey))
                                        else ...[
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                    flex: totalPresentes,
                                                    child: Container(
                                                        height: 20,
                                                        color: Colors.green)),
                                                Expanded(
                                                    flex: totalAusentes,
                                                    child: Container(
                                                        height: 20,
                                                        color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                  "Presenças: ${percGeral.toStringAsFixed(1)}%",
                                                  style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(
                                                  "Faltas: ${(100 - percGeral).toStringAsFixed(1)}%",
                                                  style: const TextStyle(
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                          const SizedBox(height: 15),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceAround,
                                            children: [
                                              _buildMediaItem(
                                                  Icons.people,
                                                  "Presenças",
                                                  totalPresentes.toString()),
                                              _buildMediaItem(
                                                  Icons.person_off,
                                                  "Faltas",
                                                  totalAusentes.toString()),
                                              _buildMediaItem(
                                                  Icons.attach_money,
                                                  "Arrecadado",
                                                  "R\$ ${totalOfertas.toStringAsFixed(2)}"),
                                            ],
                                          )
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text("Salas e Alunos Matriculados:",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87)),
                                const SizedBox(height: 8),
                                ...dadosPorSala.entries.map((entry) {
                                  String sid = entry.key;
                                  var sData = entry.value;

                                  int p = sData['presentes'];
                                  int a = sData['faltas'];
                                  int aulas = sData['aulas_dadas'];
                                  List<String> alunosDaSala = sData['alunos'];

                                  int totalEsperado = p + a;
                                  double percSala = totalEsperado > 0
                                      ? (p / totalEsperado) * 100
                                      : 0;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ExpansionTile(
                                      leading: CircleAvatar(
                                          backgroundColor: ebdColor,
                                          child: Text(
                                              "${percSala.toStringAsFixed(0)}%",
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      title: Text(sData['nome'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                          "${alunosDaSala.length} alunos | $aulas aulas",
                                          style: const TextStyle(fontSize: 12)),
                                      children: [
                                        const Divider(height: 1),
                                        if (alunosDaSala.isEmpty)
                                          const Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Text(
                                                  "Nenhum aluno matriculado nesta sala.",
                                                  style: TextStyle(
                                                      color: Colors.grey))),
                                        ...alunosDaSala.map((nomeAluno) {
                                          return ListTile(
                                            leading: const Icon(Icons.person,
                                                color: Colors.grey, size: 20),
                                            title: Text(nomeAluno,
                                                style: const TextStyle(
                                                    fontSize: 14)),
                                            trailing: const Icon(
                                                Icons.analytics,
                                                color: Colors.blue,
                                                size: 20),
                                            onTap: () =>
                                                EbdStatsHelper.showOptions(
                                                    context, nomeAluno, sid),
                                          );
                                        })
                                      ],
                                    ),
                                  );
                                })
                              ],
                            ),
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton.extended(
                                heroTag: "btn_pdf_relatorio",
                                backgroundColor: Colors.red[700],
                                icon: const Icon(Icons.picture_as_pdf,
                                    color: Colors.white),
                                label: const Text("Exportar PDF",
                                    style: TextStyle(color: Colors.white)),
                                onPressed: () => EbdStatsHelper.opcoesGerarPdf(
                                    context, salasDocs),
                              ),
                            )
                          ],
                        );
                      },
                    );
                  })),
        ],
      ),
    );
  }

  Widget _buildMediaItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: ebdColor, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}

// ==========================================
// ABA 3: LISTA GLOBAL DE ALUNOS
// ==========================================
class EbdAlunosTab extends StatefulWidget {
  const EbdAlunosTab({super.key});

  @override
  State<EbdAlunosTab> createState() => _EbdAlunosTabState();
}

class _EbdAlunosTabState extends State<EbdAlunosTab> {
  void _addAlunoGlobalDialog(List<QueryDocumentSnapshot> salas) {
    if (salas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Crie uma sala primeiro!")));
      return;
    }

    String? selectedSalaId = salas.first.id;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
                title: const Text("Novo Aluno (Global)"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedSalaId,
                      decoration: const InputDecoration(
                          labelText: "Selecione a Turma",
                          border: OutlineInputBorder()),
                      items: salas
                          .map((s) => DropdownMenuItem(
                              value: s.id, child: Text(s['nome'])))
                          .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedSalaId = val),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: controller,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                          labelText: "Nome Completo",
                          border: OutlineInputBorder()),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar")),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ebdColor,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      if (controller.text.trim().isEmpty ||
                          selectedSalaId == null) return;
                      await FirebaseFirestore.instance
                          .collection('ebd_salas')
                          .doc(selectedSalaId)
                          .update({
                        'alunos':
                            FieldValue.arrayUnion([controller.text.trim()])
                      });
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text("Adicionar"),
                  )
                ],
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ebd_salas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final salas = snapshot.data?.docs ?? [];

          List<Map<String, dynamic>> todosAlunos = [];
          for (var sala in salas) {
            String salaNome = sala['nome'] ?? '';
            String salaId = sala.id;
            List<String> alunosDaSala = List<String>.from(sala['alunos'] ?? []);
            for (var aluno in alunosDaSala) {
              todosAlunos
                  .add({'nome': aluno, 'sala': salaNome, 'salaId': salaId});
            }
          }
          todosAlunos.sort((a, b) =>
              a['nome'].toLowerCase().compareTo(b['nome'].toLowerCase()));

          return Scaffold(
            backgroundColor: Colors.grey[100],
            body: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: ebdColor.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total: ${todosAlunos.length} Matriculados",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: ebdColor)),
                      ElevatedButton.icon(
                        onPressed: () =>
                            EbdStatsHelper.opcoesGerarPdf(context, salas),
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text("PDF"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10)),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                      itemCount: todosAlunos.length,
                      itemBuilder: (context, index) {
                        final aluno = todosAlunos[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ListTile(
                            leading: const CircleAvatar(
                                backgroundColor: ebdColor,
                                child: Icon(Icons.person, color: Colors.white)),
                            title: Text(aluno['nome'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text("Turma: ${aluno['sala']}"),
                            trailing:
                                const Icon(Icons.analytics, color: Colors.blue),
                            onTap: () => EbdStatsHelper.showOptions(
                                context, aluno['nome'], aluno['salaId']),
                          ),
                        );
                      }),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              heroTag: "btn_novo_aluno_global",
              onPressed: () => _addAlunoGlobalDialog(salas),
              backgroundColor: ebdColor,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text("Novo Aluno",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          );
        });
  }
}

// ==========================================
// TELA DE CHAMADA E OFERTA (DENTRO DA SALA)
// ==========================================
class EbdChamadaScreen extends StatefulWidget {
  final String salaId;
  final String salaNome;

  const EbdChamadaScreen(
      {super.key, required this.salaId, required this.salaNome});

  @override
  State<EbdChamadaScreen> createState() => _EbdChamadaScreenState();
}

class _EbdChamadaScreenState extends State<EbdChamadaScreen> {
  bool _aulaIniciada = false;
  final TextEditingController _professorController = TextEditingController();
  final TextEditingController _ofertaController = TextEditingController();
  Map<String, bool> _presencas = {};
  bool _isSaving = false;

  void _iniciarAula() {
    if (_professorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Digite o nome do professor!")));
      return;
    }
    setState(() => _aulaIniciada = true);
  }

  void _addAlunoDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Novo Aluno"),
        content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: "Nome Completo", border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ebdColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('ebd_salas')
                  .doc(widget.salaId)
                  .update({
                'alunos': FieldValue.arrayUnion([controller.text.trim()])
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Adicionar"),
          )
        ],
      ),
    );
  }

  void _editAlunoDialog(String nomeAntigo) {
    final controller = TextEditingController(text: nomeAntigo);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Aluno"),
        content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: "Nome Completo", border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              if (controller.text.trim().isEmpty ||
                  controller.text.trim() == nomeAntigo) return;
              await FirebaseFirestore.instance
                  .collection('ebd_salas')
                  .doc(widget.salaId)
                  .update({
                'alunos': FieldValue.arrayRemove([nomeAntigo])
              });
              await FirebaseFirestore.instance
                  .collection('ebd_salas')
                  .doc(widget.salaId)
                  .update({
                'alunos': FieldValue.arrayUnion([controller.text.trim()])
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Salvar"),
          )
        ],
      ),
    );
  }

  void _removerAluno(String nomeAluno) async {
    bool confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text("Remover Aluno"),
                    content: Text("Deseja remover $nomeAluno desta classe?"),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancelar")),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("REMOVER",
                              style: TextStyle(color: Colors.red)))
                    ])) ??
        false;
    if (confirm)
      await FirebaseFirestore.instance
          .collection('ebd_salas')
          .doc(widget.salaId)
          .update({
        'alunos': FieldValue.arrayRemove([nomeAluno])
      });
  }

  Future<void> _salvarDados(List<String> listaTotal,
      {required bool isEncerrar}) async {
    setState(() => _isSaving = true);
    try {
      List<String> presentes = [];
      for (String aluno in listaTotal) {
        if (_presencas[aluno] == true) presentes.add(aluno);
      }

      String valorString = _ofertaController.text.replaceAll(',', '.');
      double oferta = double.tryParse(valorString) ?? 0.0;

      String dataHoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String registroId = "${dataHoje}_${widget.salaId}";

      await FirebaseFirestore.instance
          .collection('ebd_registros')
          .doc(registroId)
          .set({
        'sala_id': widget.salaId,
        'sala_nome': widget.salaNome,
        'professor': _professorController.text.trim(),
        'data': FieldValue.serverTimestamp(),
        'data_str': dataHoje,
        'presentes': presentes,
        'ausentes': listaTotal.length - presentes.length,
        'total_matriculados': listaTotal.length,
        'oferta': oferta,
        'registrado_por': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));

      if (mounted) {
        if (isEncerrar) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Aula Encerrada!"), backgroundColor: Colors.green));
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Progresso salvo com sucesso!"),
              backgroundColor: Colors.blue));
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Erro ao salvar: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Sala: ${widget.salaNome}",
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        backgroundColor: ebdColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: _aulaIniciada
            ? [
                IconButton(
                    icon: const Icon(Icons.person_add),
                    tooltip: "Adicionar Aluno",
                    onPressed: _addAlunoDialog)
              ]
            : null,
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ebd_salas')
              .doc(widget.salaId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || !snapshot.data!.exists)
              return const Center(child: Text("Sala não encontrada."));

            final data = snapshot.data!.data() as Map<String, dynamic>;
            List<String> alunos = List<String>.from(data['alunos'] ?? []);
            alunos.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            if (!_aulaIniciada) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school, size: 60, color: ebdColor),
                          const SizedBox(height: 10),
                          Text("Iniciar Aula E.B.D",
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800])),
                          const SizedBox(height: 5),
                          Text(DateFormat('dd/MM/yyyy').format(DateTime.now()),
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _professorController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                                labelText: "Nome do Professor(a)",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person)),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _iniciarAula,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              child: const Text("INICIAR TURMA",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                Container(
                  color: ebdColor.withOpacity(0.1),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Prof: ${_professorController.text}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: ebdColor)),
                      Text("Matriculados: ${alunos.length}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: ebdColor)),
                    ],
                  ),
                ),
                Expanded(
                  child: alunos.isEmpty
                      ? Center(
                          child: Text("Nenhum aluno.\nClique no + lá em cima.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600])))
                      : ListView.builder(
                          itemCount: alunos.length,
                          itemBuilder: (context, index) {
                            String aluno = alunos[index];
                            _presencas.putIfAbsent(aluno, () => false);

                            return Container(
                              decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey.shade300))),
                              child: CheckboxListTile(
                                title: Text(aluno,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                value: _presencas[aluno],
                                activeColor: Colors.green,
                                checkColor: Colors.white,
                                secondary: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue, size: 20),
                                        onPressed: () =>
                                            _editAlunoDialog(aluno)),
                                    IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red, size: 20),
                                        onPressed: () => _removerAluno(aluno)),
                                  ],
                                ),
                                onChanged: (bool? value) {
                                  setState(() {
                                    _presencas[aluno] = value ?? false;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5))
                  ]),
                  child: Column(
                    children: [
                      TextField(
                        controller: _ofertaController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: "Valor Arrecadado (Oferta)",
                          prefixIcon: const Icon(Icons.attach_money,
                              color: Colors.green),
                          hintText: "0.00",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.green[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () =>
                                      _salvarDados(alunos, isEncerrar: false),
                              icon: const Icon(Icons.save,
                                  color: Colors.white, size: 18),
                              label: const Text("SALVAR",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: ebdColor,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () =>
                                      _salvarDados(alunos, isEncerrar: true),
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.white, size: 18),
                              label: const Text("ENCERRAR",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                )
              ],
            );
          }),
    );
  }
}

// ==========================================
// CLASSE AJUDANTE (EbdStatsHelper) - POPUPS E PDF
// ==========================================
class EbdStatsHelper {
  static void abrirSeletorData(BuildContext context,
      {required String tipo,
      required Function(int ano, int? mes, int? dia) onConfirm}) async {
    if (tipo == 'diario') {
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      if (picked != null) onConfirm(picked.year, picked.month, picked.day);
    } else {
      int selectedYear = DateTime.now().year;
      int selectedMonth = DateTime.now().month;
      List<String> meses = [
        "Janeiro",
        "Fevereiro",
        "Março",
        "Abril",
        "Maio",
        "Junho",
        "Julho",
        "Agosto",
        "Setembro",
        "Outubro",
        "Novembro",
        "Dezembro"
      ];

      showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
              builder: (context, setStateDialog) => AlertDialog(
                    title: Text(
                        tipo == 'anual'
                            ? "Selecione o Ano"
                            : "Selecione Mês e Ano",
                        style: const TextStyle(
                            color: ebdColor, fontWeight: FontWeight.bold)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tipo == 'mensal') ...[
                          DropdownButtonFormField<int>(
                            value: selectedMonth,
                            decoration: const InputDecoration(
                                labelText: "Mês", border: OutlineInputBorder()),
                            items: List.generate(
                                12,
                                (index) => DropdownMenuItem(
                                    value: index + 1,
                                    child: Text(meses[index]))),
                            onChanged: (val) =>
                                setStateDialog(() => selectedMonth = val!),
                          ),
                          const SizedBox(height: 15),
                        ],
                        DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(
                              labelText: "Ano", border: OutlineInputBorder()),
                          items: List.generate(
                              10,
                              (index) => DropdownMenuItem(
                                  value: DateTime.now().year - 5 + index,
                                  child: Text(
                                      "${DateTime.now().year - 5 + index}"))),
                          onChanged: (val) =>
                              setStateDialog(() => selectedYear = val!),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancelar")),
                      ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(backgroundColor: ebdColor),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onConfirm(selectedYear,
                              tipo == 'mensal' ? selectedMonth : null, null);
                        },
                        child: const Text("Buscar",
                            style: TextStyle(color: Colors.white)),
                      )
                    ],
                  )));
    }
  }

  static void showOptions(
      BuildContext context, String nomeAluno, String salaId) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(nomeAluno,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: ebdColor)),
              content: const Text("Deseja ver a frequência de qual período?"),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ebdColor),
                  onPressed: () {
                    Navigator.pop(ctx);
                    abrirSeletorData(context, tipo: 'mensal',
                        onConfirm: (ano, mes, dia) {
                      _mostrarDetalhesMensal(
                          context, nomeAluno, salaId, ano, mes!);
                    });
                  },
                  child: const Text("Mensal",
                      style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () {
                    Navigator.pop(ctx);
                    abrirSeletorData(context, tipo: 'anual',
                        onConfirm: (ano, mes, dia) {
                      _mostrarDetalhesAnual(context, nomeAluno, salaId, ano);
                    });
                  },
                  child: const Text("Anual",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
  }

  static void _mostrarDetalhesMensal(BuildContext context, String nomeAluno,
      String salaId, int ano, int mes) async {
    showDialog(
        context: context,
        builder: (c) => const Center(child: CircularProgressIndicator()));

    DateTime inicioBusca = DateTime(ano, mes, 1);
    DateTime fimBusca = DateTime(ano, mes + 1, 0, 23, 59, 59);

    try {
      var registros = await FirebaseFirestore.instance
          .collection('ebd_registros')
          .where('sala_id', isEqualTo: salaId)
          .where('data',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioBusca))
          .where('data', isLessThanOrEqualTo: Timestamp.fromDate(fimBusca))
          .get();

      List<Map<String, dynamic>> dias = [];
      for (var doc in registros.docs) {
        String dataStr = doc['data_str'];
        List<dynamic> presentes = doc['presentes'] ?? [];
        bool estavaPresente = presentes.contains(nomeAluno);
        dias.add({'data': dataStr, 'presente': estavaPresente});
      }
      dias.sort((a, b) => a['data'].compareTo(b['data']));

      if (context.mounted) Navigator.pop(context);

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(
                    "$nomeAluno - ${DateFormat('MMMM yyyy', 'pt_BR').format(inicioBusca)}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: dias.isEmpty
                      ? const Text("Nenhuma aula registrada neste mês.")
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: dias.length,
                          itemBuilder: (c, i) {
                            DateTime d = DateTime.parse(dias[i]['data']);
                            bool pres = dias[i]['presente'];
                            return ListTile(
                              leading: Icon(Icons.calendar_today,
                                  size: 20, color: Colors.grey[600]),
                              title: Text(
                                  "Dia ${DateFormat('dd/MM/yyyy').format(d)}"),
                              trailing: Text(pres ? "Presente" : "Falta",
                                  style: TextStyle(
                                      color: pres ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold)),
                            );
                          }),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Fechar"))
                ],
              ));
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  static void _mostrarDetalhesAnual(
      BuildContext context, String nomeAluno, String salaId, int ano) async {
    showDialog(
        context: context,
        builder: (c) => const Center(child: CircularProgressIndicator()));

    DateTime inicioBusca = DateTime(ano, 1, 1);
    DateTime fimBusca = DateTime(ano, 12, 31, 23, 59, 59);
    List<String> nomeMeses = [
      "Janeiro",
      "Fevereiro",
      "Março",
      "Abril",
      "Maio",
      "Junho",
      "Julho",
      "Agosto",
      "Setembro",
      "Outubro",
      "Novembro",
      "Dezembro"
    ];

    try {
      var registros = await FirebaseFirestore.instance
          .collection('ebd_registros')
          .where('sala_id', isEqualTo: salaId)
          .where('data',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioBusca))
          .where('data', isLessThanOrEqualTo: Timestamp.fromDate(fimBusca))
          .get();

      List<Map<String, int>> statsMeses =
          List.generate(12, (_) => {'p': 0, 'f': 0, 'aulas': 0});

      for (var doc in registros.docs) {
        DateTime d = DateTime.parse(doc['data_str']);
        int idxMes = d.month - 1;
        List<dynamic> presentes = doc['presentes'] ?? [];

        statsMeses[idxMes]['aulas'] = statsMeses[idxMes]['aulas']! + 1;
        if (presentes.contains(nomeAluno)) {
          statsMeses[idxMes]['p'] = statsMeses[idxMes]['p']! + 1;
        } else {
          statsMeses[idxMes]['f'] = statsMeses[idxMes]['f']! + 1;
        }
      }

      if (context.mounted) Navigator.pop(context);

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text("$nomeAluno - Frequência $ano",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: 12,
                      itemBuilder: (c, i) {
                        var s = statsMeses[i];
                        if (s['aulas'] == 0) return const SizedBox.shrink();
                        return ListTile(
                          title: Text(nomeMeses[i],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              Text("${s['p']} presentes e ${s['f']} faltas"),
                          leading:
                              const Icon(Icons.assessment, color: ebdColor),
                        );
                      }),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Fechar"))
                ],
              ));
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }

  static void opcoesGerarPdf(
      BuildContext context, List<DocumentSnapshot> salasDocs) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Exportar Relatório PDF",
                  style:
                      TextStyle(color: ebdColor, fontWeight: FontWeight.bold)),
              content: const Text("Selecione o período do relatório:"),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.pop(ctx);
                    abrirSeletorData(context, tipo: 'diario',
                        onConfirm: (ano, mes, dia) {
                      _buscarRegistrosEPdf(
                          context, salasDocs, 'diario', ano, mes, dia);
                    });
                  },
                  child: const Text("Diário",
                      style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ebdColor),
                  onPressed: () {
                    Navigator.pop(ctx);
                    abrirSeletorData(context, tipo: 'mensal',
                        onConfirm: (ano, mes, dia) {
                      _buscarRegistrosEPdf(
                          context, salasDocs, 'mensal', ano, mes, null);
                    });
                  },
                  child: const Text("Mensal",
                      style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () {
                    Navigator.pop(ctx);
                    abrirSeletorData(context, tipo: 'anual',
                        onConfirm: (ano, mes, dia) {
                      _buscarRegistrosEPdf(
                          context, salasDocs, 'anual', ano, null, null);
                    });
                  },
                  child: const Text("Anual",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ));
  }

  static void _buscarRegistrosEPdf(
      BuildContext context,
      List<DocumentSnapshot> salasDocs,
      String tipo,
      int ano,
      int? mes,
      int? dia) async {
    showDialog(
        context: context,
        builder: (c) => const Center(child: CircularProgressIndicator()));

    DateTime inicioBusca;
    DateTime fimBusca;
    DateTime dataRef;

    if (tipo == 'diario') {
      inicioBusca = DateTime(ano, mes!, dia!);
      fimBusca = DateTime(ano, mes, dia, 23, 59, 59);
      dataRef = inicioBusca;
    } else if (tipo == 'mensal') {
      inicioBusca = DateTime(ano, mes!, 1);
      fimBusca = DateTime(ano, mes + 1, 0, 23, 59, 59);
      dataRef = DateTime(ano, mes);
    } else {
      inicioBusca = DateTime(ano, 1, 1);
      fimBusca = DateTime(ano, 12, 31, 23, 59, 59);
      dataRef = DateTime(ano);
    }

    try {
      var registros = await FirebaseFirestore.instance
          .collection('ebd_registros')
          .where('data',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioBusca))
          .where('data', isLessThanOrEqualTo: Timestamp.fromDate(fimBusca))
          .get();

      if (context.mounted) Navigator.pop(context);
      PdfEbdGenerator.gerarPdf(context,
          tipo: tipo,
          dataRef: dataRef,
          salas: salasDocs,
          registros: registros.docs);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    }
  }
}

// ==========================================
// GERADOR DE PDF - MOTOR DE EXPORTAÇÃO
// ==========================================
class PdfEbdGenerator {
  static Future<void> gerarPdf(BuildContext context,
      {required String tipo,
      required DateTime dataRef,
      required List<DocumentSnapshot> salas,
      required List<DocumentSnapshot> registros}) async {
    final pdf = pw.Document();

    String periodoTexto = "";
    if (tipo == 'diario') {
      periodoTexto = DateFormat('dd/MM/yyyy', 'pt_BR').format(dataRef);
    } else if (tipo == 'mensal') {
      periodoTexto =
          "${DateFormat('MMMM', 'pt_BR').format(dataRef).toUpperCase()} de ${dataRef.year}";
    } else {
      periodoTexto = "${dataRef.year}";
    }

    String dataAtual = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    Map<String, Map<String, dynamic>> estatisticasPorSala = {};
    int totalPresentesGeral = 0;
    int totalFaltasGeral = 0;
    double totalOfertasGeral = 0.0;

    for (var s in salas) {
      String sId = s.id;
      estatisticasPorSala[sId] = {
        'nome': s['nome'],
        'alunos': {},
        'total_aulas': 0,
        'oferta_total': 0.0
      };

      for (var aluno in List<String>.from(s['alunos'] ?? [])) {
        estatisticasPorSala[sId]!['alunos']
            [aluno] = {'presencas': 0, 'faltas': 0};
      }
    }

    for (var r in registros) {
      var data = r.data() as Map<String, dynamic>;
      String sId = data['sala_id'];

      int p = (data['presentes'] as List?)?.length ?? 0;
      int a = data['ausentes'] ?? 0;
      double o = (data['oferta'] ?? 0.0).toDouble();

      totalPresentesGeral += p;
      totalFaltasGeral += a;
      totalOfertasGeral += o;

      if (!estatisticasPorSala.containsKey(sId)) continue;

      estatisticasPorSala[sId]!['total_aulas'] += 1;
      estatisticasPorSala[sId]!['oferta_total'] += o;
      List<dynamic> presentes = data['presentes'] ?? [];

      estatisticasPorSala[sId]!['alunos'].forEach((aluno, stats) {
        if (presentes.contains(aluno)) {
          stats['presencas'] += 1;
        } else {
          stats['faltas'] += 1;
        }
      });
    }

    int totalMatriculados = totalPresentesGeral + totalFaltasGeral;
    double percGeral = totalMatriculados > 0
        ? (totalPresentesGeral / totalMatriculados) * 100
        : 0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text("Gerado pelo aplicativo IECM em $dataAtual",
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10)),
          );
        },
        build: (pw.Context context) {
          return [
            // CABEÇALHO OFICIAL EM TEXTO
            pw.Center(
                child: pw.Text("Igreja Evangélica Congregacional em Moreno",
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold))),
            pw.Center(
                child: pw.Text(
                    "Rua Luiz Cavalcante Lins, 353. Alto da Liberada - Moreno/PE",
                    style: const pw.TextStyle(fontSize: 10))),
            pw.Center(
                child: pw.Text("CNPJ: 30.057.670.0001-05",
                    style: const pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 20),

            pw.Center(
                child: pw.Text(
                    "Relatório Escola Bíblica Dominical - EBD ($periodoTexto)",
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),

            // RESUMO GERAL ATUALIZADO
            pw.Text("RESUMO GERAL",
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Text("Número de presenças: $totalPresentesGeral"),
            pw.Text("Número de faltas: $totalFaltasGeral"),
            pw.Text("Frequência média: ${percGeral.toStringAsFixed(1)}%"),
            pw.Text("Arrecadação: R\$ ${totalOfertasGeral.toStringAsFixed(2)}"),
            pw.SizedBox(height: 20),

            // DETALHES POR SALA
            pw.Text("DETALHAMENTO POR SALA",
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            ...estatisticasPorSala.entries.map((entry) {
              var sData = entry.value;
              String nomeTurma = sData['nome'];
              int totalAulas = sData['total_aulas'];
              double ofertaSala = sData['oferta_total'];

              int totalPresencasSala = 0;
              int totalFaltasSala = 0;

              List<pw.Widget> alunosWidgets = [];

              sData['alunos'].forEach((alunoNome, stats) {
                int p = stats['presencas'];
                int f = stats['faltas'];
                totalPresencasSala += p;
                totalFaltasSala += f;

                int totalAluno = p + f;
                double percAluno = totalAluno > 0 ? (p / totalAluno) * 100 : 0;

                alunosWidgets.add(pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Text(
                        "- $alunoNome: $p presenças | $f faltas (${percAluno.toStringAsFixed(1)}%)",
                        style: const pw.TextStyle(fontSize: 12))));
              });

              int totalSala = totalPresencasSala + totalFaltasSala;
              double percSala =
                  totalSala > 0 ? (totalPresencasSala / totalSala) * 100 : 0;

              return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      color: PdfColors.grey300,
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                          "Turma: $nomeTurma | Freq. Turma: ${percSala.toStringAsFixed(1)}% | Aulas: $totalAulas | Arrecadado: R\$ ${ofertaSala.toStringAsFixed(2)}",
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    ),
                    pw.SizedBox(height: 5),
                    if (alunosWidgets.isEmpty)
                      pw.Text("Nenhum aluno matriculado.",
                          style: pw.TextStyle(
                              fontStyle: pw.FontStyle.italic, fontSize: 12)),
                    ...alunosWidgets,
                    pw.SizedBox(height: 20),
                  ]);
            }),
          ];
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'EBD_Relatorio_$periodoTexto.pdf');
  }
}