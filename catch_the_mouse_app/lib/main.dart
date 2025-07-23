import 'package:flutter/material.dart';
import 'package:catch_the_mouse_app/screens/intro_screen.dart';
import 'package:catch_the_mouse_app/screens/game_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '쥐를 잡자!',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'sans-serif',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const IntroScreen(),
        '/game': (context) => const GameScreen(),
      },
    );
  }
}