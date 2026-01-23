import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'bible_screen.dart';
import 'hymnal_screen.dart';
import 'members_screen.dart';
import 'agenda_screen.dart'; 
import 'annual_agenda_screen.dart';
import 'scale_screen.dart';
import 'patrimonio_screen.dart'; 
import 'finance_screen.dart'; 

import '../widgets/home_notices_widget.dart'; 
import '../widgets/monthly_birthdays_widget.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Lista das telas principais (Bottom Navigation)
  final List<Widget> _screens = [
    const HomeContent(),   // Índice 0: Grade de ícones + Avisos + Aniversariantes
    const ProfileScreen(), // Índice 1: Perfil
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("IEC App", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[900],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Início"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[900],
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- CONTEÚDO DA TELA INICIAL (SCROLLABLE) ---
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Se não estiver logado, mostra carregando
    if (user == null) return const Center(child: CircularProgressIndicator());

    // USAMOS STREAMBUILDER PARA LER A "ROLE" DO BANCO EM TEMPO REAL
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        
        // Enquanto carrega ou se der erro, assume que é membro comum por segurança
        String role = 'membro';
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          role = data['role'] ?? 'membro';
        }

        // --- DEFINIÇÃO DE QUEM PODE VER O BOTÃO ---
        bool canViewFinance = role == 'admin' || role == 'financeiro';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Bem-vindo à IEC-Moreno!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // --- GRADE DE ÍCONES ---
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // Layout de 3 colunas
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,

                children: [
                  // 1. BÍBLIA
                  _buildMenuCard(
                    context,
                    icon: Icons.menu_book,
                    label: "Bíblia",
                    color: Colors.brown,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const BibleScreen()));
                    },
                  ),

                  // 2. SALMOS E HINOS
                  _buildMenuCard(
                    context,
                    icon: Icons.library_music,
                    label: "Salmos & Hinos",
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HymnalScreen()));
                    },
                  ),

                  // 3. AGENDA SEMANAL
                  _buildMenuCard(
                    context,
                    icon: Icons.calendar_view_week,
                    label: "Agenda Semanal",
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AgendaScreen()));
                    },
                  ),

                  // 4. AGENDA ANUAL
                  _buildMenuCard(
                    context,
                    icon: Icons.calendar_month,
                    label: "Agenda Anual",
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AnnualAgendaScreen()));
                    },
                  ),

                  // 5. ESCALA
                  _buildMenuCard(
                    context,
                    icon: Icons.view_timeline,
                    label: "Escala",
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ScaleScreen()));
                    },
                  ),

                  // 6. PATRIMÔNIO
                  _buildMenuCard(
                    context,
                    icon: Icons.inventory_2,
                    label: "Patrimônio",
                    color: Colors.blueGrey,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PatrimonioScreen()));
                    },
                  ),

                  // 7. MEMBROS
                  _buildMenuCard(
                    context,
                    icon: Icons.groups,
                    label: "Membros",
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const MembersScreen()));
                    },
                  ),

                  // 8. FINANÇAS (CONDICIONAL: ADMIN OU FINANCEIRO)
                  if (canViewFinance)
                    _buildMenuCard(
                      context,
                      icon: Icons.attach_money,
                      label: "Finanças",
                      color: Colors.green[700]!,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const FinanceScreen()));
                      },
                    ),
                ],
              ),

              const SizedBox(height: 30),

              // --- 1. AVISOS DA SEMANA (LETREIRO) ---
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  "Avisos da Semana",
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.black87
                  ),
                ),
              ),
              const SizedBox(height: 10),
              
              // Carrossel dinâmico
              const WeeklyNoticesWidget(),

              const SizedBox(height: 20),

              // --- 2. ANIVERSARIANTES DO MÊS ---
              const MonthlyBirthdaysWidget(),

              const SizedBox(height: 30), // Espaço final
            ],
          ),
        );
      }
    );
  }

  // --- WIDGET DO BOTÃO DO MENU ---
  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}