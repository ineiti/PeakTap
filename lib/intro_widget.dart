import 'package:flutter/material.dart';
import 'package:intro_slider/intro_slider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class IntroWidget extends StatefulWidget {
  const IntroWidget(this.sink, {super.key});

  final Sink<void> sink;

  @override
  State<IntroWidget> createState() => _IntroWidget();
}

class _IntroWidget extends State<IntroWidget> {
  List<ContentConfig> listContentConfig = [];
  AppLocalizations? i18n;

  @override
  void initState() {
    super.initState();
  }

  void initListContent() {
    if (listContentConfig.isNotEmpty) {
      return;
    }

    listContentConfig.add(
      ContentConfig(
        title: i18n?.intro_1_title,
        description: i18n?.intro_1_text,
        pathImage: "assets/intro/mont_blanc_1.png",
        backgroundColor: const Color(0xffaaaa55),
      ),
    );
    listContentConfig.add(
      ContentConfig(
        title: i18n?.intro_2_title,
        description: i18n?.intro_2_text,
        pathImage: "assets/intro/mont_blanc_2.png",
        backgroundColor: const Color(0xff99aa55),
      ),
    );
    listContentConfig.add(
      ContentConfig(
        title: i18n?.intro_3_title,
        description: i18n?.intro_3_text,
        pathImage: "assets/intro/mont_blanc_3.png",
        backgroundColor: const Color(0xff77aa55),
      ),
    );
    listContentConfig.add(
      ContentConfig(
        title: i18n?.intro_4_title,
        description: i18n?.intro_4_text,
        pathImage: "assets/intro/loading_map.png",
        backgroundColor: const Color(0xff55aa55),
      ),
    );
  }

  void onDonePress() {
    widget.sink.add(null);
  }

  @override
  Widget build(BuildContext context) {
    i18n ??= AppLocalizations.of(context);
    initListContent();
    return IntroSlider(
      key: UniqueKey(),
      listContentConfig: listContentConfig,
      onDonePress: onDonePress,
      nextButtonStyle: const ButtonStyle(
          foregroundColor: MaterialStatePropertyAll(Color(0xffffffff))),
      skipButtonStyle: const ButtonStyle(
          foregroundColor: MaterialStatePropertyAll(Color(0xffffffff))),
      doneButtonStyle: const ButtonStyle(
          foregroundColor: MaterialStatePropertyAll(Color(0xffffffff))),
    );
  }
}

// class IntroWidget extends StatelessWidget {
//   const IntroWidget(this.sink, {super.key});
//   final Sink<void> sink;
//
//   @override
//   Widget build(BuildContext context) {
//     return ElevatedButton(
//       onPressed: () {
//         sink.add(null);
//       },
//       child: const Text('Update GPS'),
//     );
//   }
// }
