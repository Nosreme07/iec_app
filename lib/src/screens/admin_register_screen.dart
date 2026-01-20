import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/admin_config.dart';

class AdminRegisterScreen extends StatefulWidget {
  final String? memberId;
  final Map<String, dynamic>? memberData;

  const AdminRegisterScreen({super.key, this.memberId, this.memberData});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;

  // Variáveis da Imagem
  File? _imageFile;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  final Map<String, TextEditingController> _controllers = {};

  final List<String> _sexoOptions = ['Masculino', 'Feminino'];
  final List<String> _sangueOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Não sei'];
  final List<String> _situacaoOptions = ['Ativo', 'Inativo', 'Congregado', 'In Memoriam', 'Criança/Adolescente', 'Cadastro Pendente'];
  final List<String> _escolaridadeOptions = ['Analfabeto', 'Ensino Fundamental Incompleto', 'Ensino Fundamental Completo', 'Ensino Médio Incompleto', 'Ensino Médio Completo', 'Ensino Superior Incompleto', 'Ensino Superior Completo', 'Acima de Ensino Superior'];
  final List<String> _departamentoOptions = ['Nenhum', 'Dep. Infantil', 'UMEC', 'UAF', 'UHCM', 'Min. de Louvor'];
  final List<String> _cargoOptions = ['Membro', 'Presidente', 'Vice-Presidente', 'Dir. Patrimônio', 'Secretária', '1º Tesoureiro', '2º Tesoureiro', 'Zelador(a)', 'Conselho Fiscal'];
  final List<String> _oficialOptions = ['Nenhum', 'Pastor', 'Presbítero', 'Diácono(a)'];
  final List<String> _acessoOptions = ['Membro Comum', 'Administrador'];

  final List<String> _fields = [
    'nome_completo', 'pai', 'mae', 'nascimento', 'profissao', 'habilitacao', 
    'naturalidade', 'nacionalidade', 'cpf', 'senha', 
    'endereco', 'numero', 'bairro', 'cidade', 'uf', 'cep', 'complemento',
    'whatsapp', 'telefone', 'email',
    'membro_desde', 'tipo_admissao', 'batismo_aguas', 'igreja_anterior',
    'cargo_anterior', 'data_consagracao', 'data_conversao',
    'estado_civil', 'data_casamento', 'conjuge', 'filhos', 'observacoes'
  ];

  String? _selectedSexo;
  String? _selectedSangue;
  String? _selectedSituacao;
  String? _selectedEscolaridade;
  String? _selectedDepartamento;
  String? _selectedCargo;
  String? _selectedOficial;
  String? _selectedAcesso;

  @override
  void initState() {
    super.initState();
    for (var field in _fields) {
      _controllers[field] = TextEditingController();
    }

    if (widget.memberId != null && widget.memberData != null) {
      _isEditing = true;
      _loadExistingData();
    } else {
      _selectedSituacao = "Ativo";
      _selectedCargo = "Membro";
      _selectedOficial = "Nenhum";
      _selectedDepartamento = "Nenhum";
      _selectedAcesso = "Membro Comum";
    }
  }

  void _loadExistingData() {
    final data = widget.memberData!;
    _controllers.forEach((key, controller) {
      if (data.containsKey(key)) controller.text = data[key].toString();
    });

    if (data.containsKey('foto_url') && data['foto_url'] != null) {
      _existingImageUrl = data['foto_url'];
    }

    String? loadDrop(String key, List<String> options) {
      if (data[key] == null) return null;
      try {
        return options.firstWhere((e) => e.toUpperCase() == data[key].toString().toUpperCase());
      } catch (e) { return null; }
    }

    setState(() {
      _selectedSexo = loadDrop('sexo', _sexoOptions);
      _selectedSangue = loadDrop('grupo_sanguineo', _sangueOptions);
      _selectedSituacao = loadDrop('situacao', _situacaoOptions);
      _selectedEscolaridade = loadDrop('escolaridade', _escolaridadeOptions);
      _selectedDepartamento = loadDrop('departamento', _departamentoOptions);
      _selectedCargo = loadDrop('cargo_atual', _cargoOptions);
      _selectedOficial = loadDrop('oficial_igreja', _oficialOptions);
      _selectedAcesso = (data['role'] == 'admin') ? 'Administrador' : 'Membro Comum';
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao pegar imagem: $e")));
    }
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageFile == null) return _existingImageUrl;
    try {
      final storageRef = FirebaseStorage.instance.ref().child('profile_photos/$userId.jpg');
      await storageRef.putFile(_imageFile!);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print("Erro no upload: $e");
      return null;
    }
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
      final String systemRole = (_selectedAcesso == 'Administrador') ? 'admin' : 'membro';
      
      Map<String, dynamic> dadosParaSalvar = {
        'role': systemRole,
        'sexo': _selectedSexo?.toUpperCase(),
        'grupo_sanguineo': _selectedSangue?.toUpperCase(),
        'situacao': _selectedSituacao?.toUpperCase(),
        'escolaridade': _selectedEscolaridade?.toUpperCase(),
        'departamento': _selectedDepartamento?.toUpperCase(),
        'cargo_atual': _selectedCargo?.toUpperCase(),
        'oficial_igreja': _selectedOficial?.toUpperCase(),
      };

      _controllers.forEach((key, controller) {
        if (key != 'senha') {
          if (key == 'email') {
             dadosParaSalvar[key] = controller.text.trim().toLowerCase();
          } else {
             dadosParaSalvar[key] = controller.text.trim().toUpperCase();
          }
        }
      });

      String uidFinal = "";

      if (_isEditing) {
        uidFinal = widget.memberId!;
        String? fotoUrl = await _uploadImage(uidFinal);
        if (fotoUrl != null) dadosParaSalvar['foto_url'] = fotoUrl;

        await FirebaseFirestore.instance.collection('users').doc(uidFinal).update(dadosParaSalvar);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dados atualizados!"), backgroundColor: Colors.blue));
          Navigator.pop(context);
        }
      } else {
        final String emailLogin = AdminConfig.getEmailFromCpf(_controllers['cpf']!.text);
        final String senha = _controllers['senha']!.text.trim();
        dadosParaSalvar['email_login'] = emailLogin;
        dadosParaSalvar['criado_em'] = FieldValue.serverTimestamp();

        FirebaseApp? tempApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
        try {
          UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
              .createUserWithEmailAndPassword(email: emailLogin, password: senha);
          
          uidFinal = userCredential.user!.uid;
          dadosParaSalvar['uid'] = uidFinal;

          String? fotoUrl = await _uploadImage(uidFinal);
          if (fotoUrl != null) dadosParaSalvar['foto_url'] = fotoUrl;

          await FirebaseFirestore.instance.collection('users').doc(uidFinal).set(dadosParaSalvar);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Membro cadastrado!"), backgroundColor: Colors.green));
            Navigator.pop(context);
          }
        } finally {
          await tempApp.delete();
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro Auth: ${e.message}"), backgroundColor: Colors.red));
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
        title: Text(_isEditing ? "Editar Membro" : "Novo Cadastro", style: const TextStyle(color: Colors.white)),
        backgroundColor: _isEditing ? Colors.orange[800] : Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // FOTO DE PERFIL
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _imageFile != null 
                          ? FileImage(_imageFile!) as ImageProvider 
                          : (_existingImageUrl != null ? NetworkImage(_existingImageUrl!) : null),
                      child: (_imageFile == null && _existingImageUrl == null) 
                          ? const Icon(Icons.person, size: 60, color: Colors.grey) 
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_isEditing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 20),
                  color: Colors.orange[100],
                  child: const Text("⚠️ Editando membro existente.\nCPF/Login não podem ser alterados.", textAlign: TextAlign.center, style: TextStyle(color: Colors.brown)),
                ),

              _buildSectionTitle("1. Dados Pessoais & Acesso"),
              _buildTextField('nome_completo', "Nome Completo", required: true),
              
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange[200]!)),
                child: _buildDropdown("Nível de Acesso (App)", _acessoOptions, _selectedAcesso, (val) => setState(() => _selectedAcesso = val)),
              ),
              const SizedBox(height: 15),

              Row(children: [
                Expanded(child: _buildTextField('nascimento', "Data Nasc.", icon: Icons.calendar_today, isDate: true, hint: "dd/mm/aaaa")),
                const SizedBox(width: 10),
                Expanded(child: _buildDropdown("Sexo", _sexoOptions, _selectedSexo, (val) => setState(() => _selectedSexo = val))),
              ]),
              
              _buildTextField('pai', "Nome do Pai"),
              _buildTextField('mae', "Nome da Mãe"),
              
              Row(children: [
                Expanded(child: _buildTextField('cpf', "CPF (Login)", icon: Icons.lock, required: true, isNumber: true, readOnly: _isEditing)),
                const SizedBox(width: 10),
                Expanded(child: _buildDropdown("Tipo Sangue", _sangueOptions, _selectedSangue, (val) => setState(() => _selectedSangue = val))),
              ]),
              
              Row(children: [
                Expanded(child: _buildTextField('naturalidade', "Naturalidade")),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField('nacionalidade', "Nacionalidade")),
              ]),

              _buildDropdown("Grau de Escolaridade", _escolaridadeOptions, _selectedEscolaridade, (val) => setState(() => _selectedEscolaridade = val)),
              _buildTextField('profissao', "Profissão"),
              _buildTextField('habilitacao', "CNH / Categoria"),

              _buildSectionTitle("2. Endereço e Contato"),
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

              _buildSectionTitle("3. Dados Eclesiásticos"),
              _buildDropdown("Situação", _situacaoOptions, _selectedSituacao, (val) => setState(() => _selectedSituacao = val)),
              const SizedBox(height: 10),
              
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

              _buildSectionTitle("4. Família"),
              Row(children: [
                Expanded(child: _buildTextField('estado_civil', "Estado Civil")),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField('data_casamento', "Data Casamento", isDate: true)),
              ]),
              _buildTextField('conjuge', "Nome do Cônjuge"),
              _buildTextField('filhos', "Filhos (Nome e Data Nasc.)", maxLines: 3),

              if (!_isEditing) ...[
                _buildSectionTitle("5. Segurança (Login)"),
                // MUDANÇA: CAMPO DE SENHA APENAS NÚMEROS E MIN 6
                _buildTextField('senha', "Senha Inicial (Apenas Números)", icon: Icons.vpn_key, required: true, isNumber: true),
              ],

              _buildSectionTitle("6. Observações"),
              _buildTextField('observacoes', "Observações Gerais", maxLines: 4),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMember,
                  style: ElevatedButton.styleFrom(backgroundColor: _isEditing ? Colors.orange[800] : Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_isEditing ? "SALVAR ALTERAÇÕES" : "SALVAR CADASTRO", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
    return Padding(padding: const EdgeInsets.fromLTRB(0, 30, 0, 15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900])), Divider(color: Colors.blue[900], thickness: 1.5)]));
  }

  Widget _buildTextField(String key, String label, {IconData? icon, bool isNumber = false, bool isDate = false, bool isPhone = false, bool required = false, int maxLines = 1, String? hint, bool readOnly = false}) {
    List<TextInputFormatter> formatters = [];
    if (isNumber || isDate || isPhone) formatters.add(FilteringTextInputFormatter.digitsOnly);
    if (isDate) formatters.add(DataInputFormatter());
    if (isPhone) formatters.add(TelefoneInputFormatter());
    formatters.add(UpperCaseTextFormatter());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: _controllers[key],
        readOnly: readOnly,
        keyboardType: (isNumber || isDate || isPhone) ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        maxLines: maxLines,
        inputFormatters: formatters,
        textCapitalization: TextCapitalization.characters,
        style: readOnly ? const TextStyle(color: Colors.grey) : null,
        decoration: InputDecoration(
          labelText: label + (required ? " *" : ""),
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey[600]) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          filled: true,
          fillColor: readOnly ? Colors.grey[200] : Colors.grey[50],
        ),
        validator: required ? (value) {
          if (value == null || value.isEmpty) return "Campo obrigatório";
          // MUDANÇA: VALIDAÇÃO DE SENHA (6 NÚMEROS)
          if (key == 'senha' && !_isEditing && value.length < 6) return "Mínimo 6 números";
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

// FORMATADORES
class UpperCaseTextFormatter extends TextInputFormatter { @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) { return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection); } }
class DataInputFormatter extends TextInputFormatter { @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) { var text = newValue.text; if (newValue.selection.baseOffset == 0) return newValue; var buffer = StringBuffer(); for (int i = 0; i < text.length; i++) { buffer.write(text[i]); var nonZeroIndex = i + 1; if (nonZeroIndex <= 2) { if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) buffer.write('/'); } else if (nonZeroIndex <= 4) { if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) buffer.write('/'); } } var string = buffer.toString(); return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length)); } }
class TelefoneInputFormatter extends TextInputFormatter { @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) { var text = newValue.text; if (newValue.selection.baseOffset == 0) return newValue; var buffer = StringBuffer(); for (int i = 0; i < text.length; i++) { if (i == 0) buffer.write('('); buffer.write(text[i]); if (i == 1) buffer.write(') '); if (i == 6) buffer.write('-'); } var string = buffer.toString(); return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length)); } }