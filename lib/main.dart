//import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
//
import 'package:chaostours/app_loader.dart';
import 'package:chaostours/globals.dart';
import 'package:chaostours/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Logger.logLevel = LogLevel.log;
  await Future.delayed(const Duration(seconds: 1), AppLoader.preload);
  runApp(Globals.app);
}

/*
void main() {
  runApp(const MaterialApp(
    home: HomeRoute(),
  ));
}
 
class HomeRoute extends StatelessWidget {
  const HomeRoute({Key? key}) : super(key: key);
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geeks for Geeks'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: ElevatedButton(
            child: const Text('Click Me!'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecondRoute()),
              );
            }),
      ),
    );
  }
}
 
class SecondRoute extends StatelessWidget {
  const SecondRoute({Key? key}) : super(key: key);
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Click Me Page"),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Home!'),
        ),
      ),
    );
  }
}
*/
