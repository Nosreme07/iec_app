import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddEventScreen extends StatefulWidget {
  final String? eventId;
  final Map<String, dynamic>? eventData;
  final DateTime? preSelectedDate;

  const AddEventScreen({super.key, this.eventId, this.eventData, this.preSelectedDate});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // REMOVI O _tituloController
  final _localController = TextEditingController();
  final _dirigenteController = TextEditingController();
  final _pregadorController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  String? _selectedTipo;
  bool _isLoading = false;

  // LISTA ATUALIZADA COM "Culto Residencial"
  final List<String> _tiposEventos = [
    'Culto de Oração',
    'Culto de Oração Online',
    'Culto de Doutrina',
    'Culto Solene',
    'Culto Residencial', // <--- NOVO
    'EBD',
    'Ensaio',
    'Reunião',
    'Assembleia',
    'Evento Especial'
  ];

  @override
  void initState() {
    super.initState();

    if (widget.preSelectedDate != null) {
      _selectedDate = widget.preSelectedDate!;
    }

    if (widget.eventData != null) {
      // Carrega dados na edição
      _localController.text = widget.eventData!['local'] ?? 'Templo Sede';
      _dirigenteController.text = widget.eventData!['dirigente'] ?? '';
      _pregadorController.text = widget.eventData!['pregador'] ?? '';
      _selectedTipo = widget.eventData!['tipo'];
      
      Timestamp ts = widget.eventData!['data_hora'];
      DateTime date = ts.toDate();
      _selectedDate = date;
      _selectedTime = TimeOfDay(hour: date.hour, minute: date.minute);
    } else {
      // Padrão para novo cadastro
      _localController.text = "Templo Sede"; 
    }
  }

  String _formatTime24H(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTipo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione o tipo do evento")));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final DateTime finalDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );

      Map<String, dynamic> data = {
        // NÃO SALVAMOS MAIS O TÍTULO SEPARADO
        'tipo': _selectedTipo,
        'local': _localController.text,
        'dirigente': _dirigenteController.text,
        'pregador': _pregadorController.text,
        'data_hora': Timestamp.fromDate(finalDateTime),
      };

      if (widget.eventId != null) {
        await FirebaseFirestore.instance.collection('agenda').doc(widget.eventId).update(data);
      } else {
        await FirebaseFirestore.instance.collection('agenda').add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Evento Salvo!"), backgroundColor: Colors.green));
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
    String dataFormatada = DateFormat("EEEE, dd/MM", "pt_BR").format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventId != null ? "Editar Evento" : "Novo Evento"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
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
                decoration: BoxDecoration(color: Colors.indigo[50], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.indigo),
                    const SizedBox(width: 10),
                    Text(dataFormatada.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 16)),
                  ],
                ),
              ),

              // CAMPO TÍTULO FOI REMOVIDO DAQUI
              
              DropdownButtonFormField(
                value: _selectedTipo,
                items: _tiposEventos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _selectedTipo = v.toString()),
                decoration: const InputDecoration(labelText: "Tipo de Evento *", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),

              InkWell(
                onTap: _pickTime,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "Horário (24h)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                  child: Text(_formatTime24H(_selectedTime), style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _localController,
                decoration: const InputDecoration(labelText: "Local", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _dirigenteController,
                decoration: const InputDecoration(labelText: "Dirigente", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _pregadorController,
                decoration: const InputDecoration(labelText: "Pregador", border: OutlineInputBorder(), prefixIcon: Icon(Icons.mic)),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEvent,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SALVAR NA AGENDA", style: TextStyle(fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}