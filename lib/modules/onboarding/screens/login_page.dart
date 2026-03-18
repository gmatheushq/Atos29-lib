import 'package:flutter/material.dart';
import 'package:atos29/modules/onboarding/screens/register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atos29/modules/main/screens/home_page.dart';
import 'package:atos29/modules/main/screens/main_screen.dart';

class LoginPage extends StatefulWidget { // Mudamos para StatefulWidget
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para capturar o texto
  final _nicknameController = TextEditingController();
  final _chaveController = TextEditingController();

  // Função lógica do Login
  void _fazerLogin() async {
    String nickDigitado = _nicknameController.text;
    String chaveDigitada = _chaveController.text;

    final prefs = await SharedPreferences.getInstance();

    // Busca os dados que salvamos lá no RegisterPage
    String? nickSalvo = prefs.getString('user_nickname') ?? '';
    String? chaveSalva = prefs.getString('user_chave') ?? '';

    if (nickDigitado.isEmpty || chaveDigitada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos!")),
      );
      return;
    }

    // Compara o que foi digitado com o que está guardado no celular
    if (nickDigitado == nickSalvo && chaveDigitada == chaveSalva) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          // Trocamos HomePage por MainScreen para ativar as abas
          builder: (context) => MainScreen(nickname: nickDigitado),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nickname ou Chave incorretos!"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: SingleChildScrollView( // Evita erro de teclado subindo
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100), // Espaço no topo
              const CircleAvatar(
                radius: 60,
                backgroundColor: Colors.indigoAccent,
                child: Icon(Icons.auto_awesome_mosaic, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                "ATOS 29",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 3),
              ),
              const SizedBox(height: 40),

              // Campo de Nickname
              TextField(
                controller: _nicknameController, // Conectado!
                decoration: const InputDecoration(
                  labelText: "Nickname",
                  prefixText: "@ ",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),

              // Campo de Chave
              TextField(
                controller: _chaveController, // Conectado!
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Chave de Acesso",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 25),

              // Botão Entrar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _fazerLogin, // Chama a função que criamos
                  child: const Text("ENTRAR"),
                ),
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                  );
                },
                child: const Text("Novo por aqui? Crie seu Nickname"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}