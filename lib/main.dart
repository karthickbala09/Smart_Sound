import 'package:flutter/material.dart';
import 'package:sble/blue2.dart';
import 'package:sble/blue3.dart';
import 'package:sble/bluethooth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      home: SmartBLEConnector(),
    );
  }
}

