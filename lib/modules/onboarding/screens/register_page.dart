import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atos29/modules/main/screens/home_page.dart';
import 'package:atos29/modules/main/screens/main_screen.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controladores para capturar o que o usuário digita
  final _nicknameController = TextEditingController();
  final _chaveController = TextEditingController();
  final _dataController = TextEditingController();

  DateTime? _dataSelecionada;

  // Função para abrir o calendário
  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? dataColhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // Sugere 18 anos atrás
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (dataColhida != null) {
      setState(() {
        _dataSelecionada = dataColhida;
        // Formata a data para o padrão brasileiro
        _dataController.text = "${dataColhida.day.toString().padLeft(2, '0')}/${dataColhida.month.toString().padLeft(2, '0')}/${dataColhida.year}";
      });
    }
  }

// Note que agora tem o 'async' antes da chave {
  void _finalizar() async {
    print("Botão clicado!");
    String nick = _nicknameController.text;
    String chave = _chaveController.text;
    String data = _dataController.text;

    if (nick.isEmpty || chave.length < 6 || data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preencha todos os campos corretamente!"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      // --- INÍCIO DA MÁGICA DE SALVAR ---
      // Isso cria o "caderninho" de notas dentro do celular
      final prefs = await SharedPreferences.getInstance();

      // Salva o Nickname e a Chave para o app não esquecer mais
      await prefs.setString('user_nickname', nick);
      await prefs.setString('user_chave', chave);
      await prefs.setString('user_data_nascimento', data);
      // --- FIM DA MÁGICA ---

      print("Dados salvos com sucesso!");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(nickname: nick),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro Atos 29")),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Campo de Nickname
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: "Crie seu Nickname",
                  prefixText: "@ ",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),

              // Campo de Data (abre o calendário)
              TextField(
                controller: _dataController,
                readOnly: true,
                onTap: () => _selecionarData(context),
                decoration: const InputDecoration(
                  labelText: "Data de Nascimento",
                  suffixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),

              // Campo de Chave de Acesso
              TextField(
                controller: _chaveController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Chave de Acesso (6 dígitos)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),

              // Botão de Finalizar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _finalizar,
                  child: const Text("FINALIZAR CADASTRO"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}