import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necessário para as máscaras
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/admin_config.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final Map<String, TextEditingController> _controllers = {};

  // --- OPÇÕES PARA SELEÇÃO (DROPDOWNS) ---
  final List<String> _sexoOptions = ['Masculino', 'Feminino'];
  
  final List<String> _sangueOptions = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Não sei'];
  
  final List<String> _situacaoOptions = [
    'Ativo', 'Inativo', 'Congregado', 'In Memoriam', 'Criança/Adolescente', 'Cadastro Pendente'
  ];

  final List<String> _escolaridadeOptions = [
    'Analfabeto', 
    'Ensino Fundamental Incompleto', 
    'Ensino Fundamental Completo', 
    'Ensino Médio Incompleto', 
    'Ensino Médio Completo', 
    'Ensino Superior Incompleto', 
    'Ensino Superior Completo', 
    'Acima de Ensino Superior'
  ];

  final List<String> _departamentoOptions = [
    'Nenhum', 'Dep. Infantil', 'UMEC', 'UAF', 'UHCM', 'Min. de Louvor'
  ];

  final List<String> _cargoOptions = [
    'Membro', 'Presidente', 'Vice-Presidente', 'Dir. Patrimônio', 
    'Secretária', '1º Tesoureiro', '2º Tesoureiro', 'Zelador(a)', 'Conselho Fiscal'
  ];

  final List<String> _oficialOptions = [
    'Nenhum', 'Pastor', 'Presbítero', 'Diácono(a)'
  ];

  // Lista de campos de TEXTO LIVRE (Os que viraram Dropdown saíram daqui)
  final List<String> _fields = [
    'nome_completo', 'pai', 'mae', 'nascimento', 
    'profissao', 'habilitacao', 
    'naturalidade', 'nacionalidade',
    'cpf', 'senha', 
    'endereco', 'numero', 'bairro', 'cidade', 'uf', 'cep', 'complemento',
    'whatsapp', 'telefone', 'email',
    'membro_desde', 'tipo_admissao', 'batismo_aguas', 'igreja_anterior',
    'cargo_anterior', 'data_consagracao', 'data_conversao',
    'estado_civil', 'data_casamento', 'conjuge', 'filhos',
    'observacoes'
  ];

  // Variáveis para armazenar o valor selecionado nos Dropdowns
  String? _selectedSexo;
  String? _selectedSangue;
  String? _selectedSituacao;
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
    // Valores padrão iniciais
    _selectedSituacao = "Ativo";
    _selectedCargo = "Membro";
    _selectedOficial = "Nenhum";
    _selectedDepartamento = "Nenhum";
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) controller.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    FirebaseApp? tempApp;

    try {
      final String cpf = _controllers['cpf']!.text.trim();
      final String emailLogin = AdminConfig.getEmailFromCpf(cpf);
      final String senha = _controllers['senha']!.text.trim();
      
      // Converte nome para maiúsculo para exibição nas mensagens
      final String nome = _controllers['nome_completo']!.text.trim().toUpperCase();

      // App secundário para não deslogar o admin
      tempApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      UserCredential userCredential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: emailLogin, password: senha);

      // Prepara os dados, convertendo TUDO para MAIÚSCULO (.toUpperCase())
      Map<String, dynamic> dadosParaSalvar = {
        'uid': userCredential.user!.uid,
        'email_login': emailLogin,
        'role': 'membro',
        'criado_em': FieldValue.serverTimestamp(),
        
        // Dropdowns (Salvando em maiúsculo)
        'sexo': _selectedSexo?.toUpperCase(),
        'grupo_sanguineo': _selectedSangue?.toUpperCase(),
        'situacao': _selectedSituacao?.toUpperCase(),
        'escolaridade': _selectedEscolaridade?.toUpperCase(),
        'departamento': _selectedDepartamento?.toUpperCase(),
        'cargo_atual': _selectedCargo?.toUpperCase(),
        'oficial_igreja': _selectedOficial?.toUpperCase(), // Novo Campo
      };

      // Adiciona os campos de texto (convertendo para maiúsculo)
      _controllers.forEach((key, controller) {
        if (key != 'senha') {
          // Se for email pessoal, geralmente mantemos minúsculo, mas se quiser tudo maiúsculo:
          if (key == 'email') {
             dadosParaSalvar[key] = controller.text.trim().toLowerCase(); // Email pessoal minúsculo é padrão
          } else {
             dadosParaSalvar[key] = controller.text.trim().toUpperCase();
          }
        }
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(dadosParaSalvar);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Membro $nome cadastrado!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = "Erro: ${e.message}";
        if(e.code == 'email-already-in-use') msg = "CPF já cadastrado.";
        if(e.code == 'weak-password') msg = "Senha fraca (min 6 dígitos).";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      await tempApp?.delete();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cadastro Completo", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("1. Dados Pessoais"),
              _buildTextField('nome_completo', "Nome Completo", required: true),
              
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('nascimento', "Data Nasc.", icon: Icons.calendar_today, isDate: true, hint: "dd/mm/aaaa")
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown("Sexo", _sexoOptions, _selectedSexo, (val) => setState(() => _selectedSexo = val))
                  ),
                ],
              ),
              
              _buildTextField('pai', "Nome do Pai"),
              _buildTextField('mae', "Nome da Mãe"),
              
              Row(
                children: [
                  Expanded(child: _buildTextField('cpf', "CPF (Login)", icon: Icons.lock, required: true, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown("Tipo Sangue", _sangueOptions, _selectedSangue, (val) => setState(() => _selectedSangue = val))
                  ),
                ],
              ),
              
              Row(
                children: [
                  Expanded(child: _buildTextField('naturalidade', "Naturalidade")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField('nacionalidade', "Nacionalidade")),
                ],
              ),

              // NOVO: ESCOLARIDADE DROPDOWN
              _buildDropdown("Grau de Escolaridade", _escolaridadeOptions, _selectedEscolaridade, (val) => setState(() => _selectedEscolaridade = val)),
              
              _buildTextField('profissao', "Profissão"),
              _buildTextField('habilitacao', "CNH / Categoria"),

              _buildSectionTitle("2. Endereço e Contato"),
              _buildTextField('cep', "CEP", isNumber: true),
              Row(
                children: [
                  Expanded(flex: 3, child: _buildTextField('endereco', "Endereço (Rua)")),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _buildTextField('numero', "Nº")),
                ],
              ),
              _buildTextField('bairro', "Bairro"),
              Row(
                children: [
                  Expanded(flex: 3, child: _buildTextField('cidade', "Cidade")),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _buildTextField('uf', "UF")),
                ],
              ),
              _buildTextField('complemento', "Complemento"),
              
              _buildTextField('whatsapp', "WhatsApp", icon: Icons.chat, isPhone: true, hint: "(xx) xxxxx-xxxx"),
              _buildTextField('telefone', "Telefone Fixo", icon: Icons.phone, isPhone: true),
              _buildTextField('email', "E-mail Pessoal", icon: Icons.email),

              _buildSectionTitle("3. Dados Eclesiásticos"),
              _buildDropdown("Situação", _situacaoOptions, _selectedSituacao, (val) => setState(() => _selectedSituacao = val)),
              const SizedBox(height: 10),
              
              Row(
                children: [
                  Expanded(child: _buildTextField('membro_desde', "Membro Desde", isDate: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField('batismo_aguas', "Data Batismo", isDate: true)),
                ],
              ),
              
              // NOVOS DROPDOWNS ECLESIÁSTICOS
              _buildDropdown("Cargo Atual", _cargoOptions, _selectedCargo, (val) => setState(() => _selectedCargo = val)),
              _buildDropdown("Oficial da Igreja", _oficialOptions, _selectedOficial, (val) => setState(() => _selectedOficial = val)),
              _buildDropdown("Departamento", _departamentoOptions, _selectedDepartamento, (val) => setState(() => _selectedDepartamento = val)),
              
              _buildTextField('tipo_admissao', "Tipo de Admissão"),
              _buildTextField('data_consagracao', "Data Consagração", isDate: true),
              _buildTextField('data_conversao', "Data Conversão", isDate: true),
              _buildTextField('igreja_anterior', "Veio de qual igreja?"),
              _buildTextField('cargo_anterior', "Cargo Anterior"),

              _buildSectionTitle("4. Família"),
              Row(
                children: [
                  Expanded(child: _buildTextField('estado_civil', "Estado Civil")),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField('data_casamento', "Data Casamento", isDate: true)),
                ],
              ),
              _buildTextField('conjuge', "Nome do Cônjuge"),
              _buildTextField('filhos', "Filhos (Nome e Data Nasc.)", maxLines: 3),

              _buildSectionTitle("5. Segurança (Login)"),
              _buildTextField('senha', "Senha Inicial", icon: Icons.vpn_key, required: true),

              _buildSectionTitle("6. Observações"),
              _buildTextField('observacoes', "Observações Gerais", maxLines: 4),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SALVAR CADASTRO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[900])),
          Divider(color: Colors.blue[900], thickness: 1.5),
        ],
      ),
    );
  }

  Widget _buildTextField(String key, String label, {
    IconData? icon, 
    bool isNumber = false, 
    bool isDate = false,
    bool isPhone = false,
    bool required = false, 
    int maxLines = 1,
    String? hint
  }) {
    List<TextInputFormatter> formatters = [];
    if (isNumber || isDate || isPhone) formatters.add(FilteringTextInputFormatter.digitsOnly);
    if (isDate) formatters.add(DataInputFormatter());
    if (isPhone) formatters.add(TelefoneInputFormatter());
    
    // Força maiúsculo enquanto digita (apenas visual, o salvamento garante também)
    formatters.add(UpperCaseTextFormatter());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: _controllers[key],
        keyboardType: (isNumber || isDate || isPhone) ? TextInputType.number : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        maxLines: maxLines,
        inputFormatters: formatters,
        textCapitalization: TextCapitalization.characters, // Teclado já abre em maiúsculo
        decoration: InputDecoration(
          labelText: label + (required ? " *" : ""),
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey[600]) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: required ? (value) {
          if (value == null || value.isEmpty) return "Campo obrigatório";
          if (key == 'senha' && value.length < 6) return "Mínimo 6 caracteres";
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
          return DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase())); // Exibe em maiúsculo na lista
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

// --- MÁSCARAS E FORMATADORES ---

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class DataInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex <= 2) {
        if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) buffer.write('/');
      } else if (nonZeroIndex <= 4) {
        if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) buffer.write('/');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}

class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 0) buffer.write('(');
      buffer.write(text[i]);
      if (i == 1) buffer.write(') ');
      if (i == 6) buffer.write('-');
    }
    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}