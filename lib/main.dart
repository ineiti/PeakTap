import 'dart:async';
import 'package:flutter/material.dart';
import 'package:peak_tap/app_widget.dart';
import 'package:peak_tap/intro_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  runApp(const PeakTap());
}

class PeakTap extends StatelessWidget {
  const PeakTap({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('fr'), // French
        Locale('de'), // German
      ],
      debugShowCheckedModeBanner: false,
      title: 'PeakTap',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

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
        showApp = !showApp;
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
      return AppWidget(showAppChannel.sink);
    } else {
      return IntroWidget(showAppChannel.sink);
    }
  }
}
