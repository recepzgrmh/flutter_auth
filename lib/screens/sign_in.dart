import 'package:flutter/material.dart';
import 'package:login_page/widgets/text_inputs.dart';

class SignIn extends StatelessWidget {
  const SignIn({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back),
        ),
        toolbarHeight: 100,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            spacing: 20,
            children: [
              SizedBox(height: 100),
              TextInputs(labelText: 'Adınız ve Soyadınızı giriniz'),
              TextInputs(labelText: 'E-mail adresinizi giriniz'),
              TextInputs(labelText: 'Şifrenizi giriniz'),
              ElevatedButton(onPressed: () {}, child: Text("Hesap Oluştur")),
            ],
          ),
        ),
      ),
    );
  }
}
