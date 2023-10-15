import 'dart:async';
import 'package:flutter/material.dart';
import 'package:peak_tap/app_widget.dart';
import 'package:peak_tap/intro_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PeakTap());
}

class PeakTap extends StatelessWidget {
  const PeakTap({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PeakTap',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(title: 'Interactive Mountain Panorama'),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.title});

  final String title;

  @override
  State<MainPage> createState() => _MainPage();
}

class _MainPage extends State<MainPage> {
  final showAppChannel = StreamController<void>();
  var showApp = false;

  @override
  void initState() {
    super.initState();

    showAppChannel.stream.listen((event) {
      setState(() {
        showApp = true;
        SharedPreferences.getInstance()
            .then((value) => {value.setBool("showApp", true)});
      });
    });

    SharedPreferences.getInstance().then((value) => {
          if (value.getBool("showApp") ?? false) {showAppChannel.sink.add(null)}
        });
  }

  @override
  Widget build(BuildContext context) {
    if (showApp) {
      return AppWidget(title: widget.title);
    } else {
      return IntroWidget(showAppChannel.sink);
    }
  }
}
