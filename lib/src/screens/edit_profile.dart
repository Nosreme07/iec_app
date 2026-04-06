import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final Map<String, TextEditingController> _controllers = {};

  final List<String> _sexoOptions = ['Masculino', 'Feminino'];
  final List<String> _sangueOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Não sei'];
  final List<String> _escolaridadeOptions = ['Analfabeto', 'Ensino Fundamental Incompleto', 'Ensino Fundamental Completo', 'Ensino Médio Incompleto', 'Ensino Médio Completo', 'Ensino Superior Incompleto', 'Ensino Superior Completo', 'Acima de Ensino Superior'];
  final List<String> _departamentoOptions = ['Nenhum', 'Dep. Infantil', 'UMEC', 'UAF', 'UHCM', 'Min. de Louvor'];
  final List<String> _cargoOptions = ['Membro', 'Presidente', 'Vice-Presidente', 'Dir. Patrimônio', 'Secretária', '1º Tesoureiro', '2º Tesoureiro', 'Zelador(a)', 'Conselho Fiscal'];
  final List<String> _oficialOptions = ['Nenhum', 'Pastor', 'Presbítero', 'Diácono(a)'];

  final List<String> _fields = [
    'nome_completo', 'apelido', 'pai', 'mae', 'nascimento', 'profissao', 'habilitacao', 
    'naturalidade', 'nacionalidade', 'cpf', 'role', 'situacao',
    'endereco', 'numero', 'bairro', 'cidade', 'uf', 'cep', 'complemento',
    'whatsapp', 'telefone', 'email',
    'membro_desde', 'tipo_admissao', 'batismo_aguas', 'igreja_anterior',
    'cargo_anterior', 'data_consagracao', 'data_conversao',
    'estado_civil', 'data_casamento', 'conjuge', 'filhos', 'observacoes'
  ];

  String? _selectedSexo;
  String? _selectedSangue;
  String? _selectedEscolaridade;
  String? _selectedDepartamento;
  String? _selectedCargo;
  String? _selectedOficial;

  @override
  void initState() {
    super.initState();
    for (var field in _fields) {
      _controllers[field] = TextEditingController();
    }
    _loadExistingData();
  }

  void _loadExistingData() {
    final data = widget.userData;
    
    // Preenche os TextFields
    _controllers.forEach((key, controller) {
      if (data.containsKey(key) && data[key] != null) {
        controller.text = data[key].toString();
      }
    });

    // Ajusta o nome do Role para ficar bonito na tela (campo bloqueado)
    String roleText = 'Membro';
    if (data['role'] == 'admin') roleText = 'Administrador';
    if (data['role'] == 'financeiro') roleText = 'Financeiro';
    if (data['role'] == 'visitante') roleText = 'Visitante';
    _controllers['role']!.text = roleText;

    // Se a situação estiver vazia, preenche com Ativo para visualização
    if (_controllers['situacao']!.text.isEmpty) {
      _controllers['situacao']!.text = 'Ativo';
    }

    String? loadDrop(String key, List<String> options) {
      if (data[key] == null) return null;
      String valorDoBanco = data[key].toString().trim().toUpperCase();
      try {
        return options.firstWhere((e) => e.toUpperCase() == valorDoBanco);
      } catch (e) { return null; }
    }

    setState(() {
      _selectedSexo = loadDrop('sexo', _sexoOptions);
      _selectedSangue = loadDrop('grupo_sanguineo', _sangueOptions);
      _selectedEscolaridade = loadDrop('escolaridade', _escolaridadeOptions);
      _selectedDepartamento = loadDrop('departamento', _departamentoOptions);
      _selectedCargo = loadDrop('cargo_atual', _cargoOptions);
      _selectedOficial = loadDrop('oficial_igreja', _oficialOptions);
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) controller.dispose();
    super.dispose();
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      
      Map<String, dynamic> dadosParaSalvar = {
        'sexo': _selectedSexo?.toUpperCase(),
        'grupo_sanguineo': _selectedSangue?.toUpperCase(),
        'escolaridade': _selectedEscolaridade?.toUpperCase(),
        'departamento': _selectedDepartamento?.toUpperCase(),
        'cargo_atual': _selectedCargo?.toUpperCase(),
        'oficial_igreja': _selectedOficial?.toUpperCase(),
      };

      // ATENÇÃO: Ignora 'cpf', 'role', e 'situacao' (são bloqueados)
      _controllers.forEach((key, controller) {
        if (key != 'cpf' && key != 'role' && key != 'situacao') {
          if (key == 'email') {
             dadosParaSalvar[key] = controller.text.trim().toLowerCase();
          } else {
             dadosParaSalvar[key] = controller.text.trim().toUpperCase();
          }
        }
      });

      await FirebaseFirestore.instance.collection('users').doc(uid).update(dadosParaSalvar);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dados atualizados com sucesso!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Meus Dados", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.withOpacity(0.3))
                ),
                child: const Text("Atualize suas informações pessoais. Alguns campos cruciais (como Nível de Acesso e CPF) estão bloqueados por segurança.", style: TextStyle(color: Colors.indigo)),
              ),

              _buildSectionTitle("1. Dados Restritos"),
              _buildTextField('role', "Nível de Acesso no App", readOnly: true, icon: Icons.lock),
              Row(children: [
                Expanded(child: _buildTextField('cpf', "CPF (Login)", icon: Icons.lock, readOnly: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField('situacao', "Situação Atual", icon: Icons.lock, readOnly: true)),
              ]),

              _buildSectionTitle("2. Dados Pessoais"),
              _buildTextField('nome_completo', "Nome Completo", required: true),
              _buildTextField('apelido', "Como quer ser chamado (Apelido)", icon: Icons.face),

              Row(children: [
                Expanded(child: _buildTextField('nascimento', "Data Nasc.", icon: Icons.calendar_today, isDate: true, hint: "dd/mm/aaaa")),
                const SizedBox(width: 10),
                Expanded(child: _buildDropdown("Sexo", _sexoOptions, _selectedSexo, (val) => setState(() => _selectedSexo = val))),
              ]),
              
              _buildTextField('pai', "Nome do Pai"),
              _buildTextField('mae', "Nome da Mãe"),
              
              Row(children: [
                Expanded(flex: 2, child: _buildDropdown("Tipo Sangue", _sangueOptions, _selectedSangue, (val) => setState(() => _selectedSangue = val))),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: _buildTextField('naturalidade', "Naturalidade")),
              ]),
              
              _buildTextField('nacionalidade', "Nacionalidade"),
              _buildDropdown("Grau de Escolaridade", _escolaridadeOptions, _selectedEscolaridade, (val) => setState(() => _selectedEscolaridade = val)),
              _buildTextField('profissao', "Profissão"),
              _buildTextField('habilitacao', "CNH / Categoria"),

              _buildSectionTitle("3. Endereço e Contato"),
              _buildTextField('cep', "CEP", isNumber: true),
              Row(children: [
                Expanded(flex: 3, child: _buildTextField('endereco', "Endereço (Rua)")),
                const SizedBox(width: 10),
                Expanded(flex: 1, child: _buildTextField('numero', "Nº")),
              ]),
              _buildTextField('bairro', "Bairro"),
              Row(children: [
                Expanded(flex: 3, child: _buildTextField('cidade', "Cidade")),
                const SizedBox(width: 10),
                Expanded(flex: 1, child: _buildTextField('uf', "UF")),
              ]),
              _buildTextField('complemento', "Complemento"),
              _buildTextField('whatsapp', "WhatsApp", icon: Icons.chat, isPhone: true, hint: "(xx) xxxxx-xxxx"),
              _buildTextField('telefone', "Telefone Fixo", icon: Icons.phone, isPhone: true),
              _buildTextField('email', "E-mail Pessoal", icon: Icons.email),

              _buildSectionTitle("4. Dados Eclesiásticos"),
              Row(children: [
                Expanded(child: _buildTextField('membro_desde', "Membro Desde", isDate: true)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField('batismo_aguas', "Data Batismo", isDate: true)),
              ]),
              _buildDropdown("Cargo Atual", _cargoOptions, _selectedCargo, (val) => setState(() => _selectedCargo = val)),
              _buildDropdown("Oficial da Igreja", _oficialOptions, _selectedOficial, (val) => setState(() => _selectedOficial = val)),
              _buildDropdown("Departamento", _departamentoOptions, _selectedDepartamento, (val) => setState(() => _selectedDepartamento = val)),
              _buildTextField('tipo_admissao', "Tipo de Admissão"),
              _buildTextField('data_consagracao', "Data Consagração", isDate: true),
              _buildTextField('data_conversao', "Data Conversão", isDate: true),
              _buildTextField('igreja_anterior', "Veio de qual igreja?"),
              _buildTextField('cargo_anterior', "Cargo Anterior"),

              _buildSectionTitle("5. Família"),
              Row(children: [
                Expanded(child: _buildTextField('estado_civil', "Estado Civil")),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField('data_casamento', "Data Casamento", isDate: true)),
              ]),
              _buildTextField('conjuge', "Nome do Cônjuge"),
              _buildTextField('filhos', "Filhos (Nome e Data Nasc.)", maxLines: 3),

              _buildSectionTitle("6. Observações"),
              _buildTextField('observacoes', "Observações Gerais", maxLines: 4),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMember,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("SALVAR ALTERAÇÕES", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 30, 0, 15), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo[900])), 
          Divider(color: Colors.indigo[200], thickness: 1.5)
        ]
      )
    );
  }

  Widget _buildTextField(String key, String label, {IconData? icon, bool isNumber = false, bool isDate = false, bool isPhone = false, bool required = false, int maxLines = 1, String? hint, bool readOnly = false}) {
    List<TextInputFormatter> formatters = [];
    if (isNumber || isDate || isPhone) formatters.add(FilteringTextInputFormatter.digitsOnly);
    if (isDate) formatters.add(DataInputFormatter());
    if (isPhone) formatters.add(TelefoneInputFormatter());
    if (!readOnly) formatters.add(UpperCaseTextFormatter());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: _controllers[key],
        readOnly: readOnly,
        keyboardType: (isNumber || isDate || isPhone) ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        maxLines: maxLines,
        inputFormatters: formatters,
        textCapitalization: TextCapitalization.characters,
        style: readOnly ? const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold) : null,
        decoration: InputDecoration(
          labelText: label + (required && !readOnly ? " *" : ""),
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 20, color: readOnly ? Colors.grey[500] : Colors.grey[600]) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: readOnly ? BorderSide.none : const BorderSide()),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          filled: true,
          fillColor: readOnly ? Colors.grey[200] : Colors.grey[50],
        ),
        validator: required && !readOnly ? (value) {
          if (value == null || value.isEmpty) return "Campo obrigatório";
          return null;
        } : null,
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> options, String? currentValue, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        items: options.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase()));
        }).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }
}

// FORMATADORES IDÊNTICOS AOS DA TELA DE CADASTRO
class UpperCaseTextFormatter extends TextInputFormatter { @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) { return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection); } }
class DataInputFormatter extends TextInputFormatter { @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) { var text = newValue.text; if (newValue.selection.baseOffset == 0) return newValue; var buffer = StringBuffer(); for (int i = 0; i < text.length; i++) { buffer.write(text[i]); var nonZeroIndex = i + 1; if (nonZeroIndex <= 2) { if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) buffer.write('/'); } else if (nonZeroIndex <= 4) { if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) buffer.write('/'); } } var string = buffer.toString(); return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length)); } }
class TelefoneInputFormatter extends TextInputFormatter { @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) { var text = newValue.text; if (newValue.selection.baseOffset == 0) return newValue; var buffer = StringBuffer(); for (int i = 0; i < text.length; i++) { if (i == 0) buffer.write('('); buffer.write(text[i]); if (i == 1) buffer.write(') '); if (i == 6) buffer.write('-'); } var string = buffer.toString(); return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length)); } }