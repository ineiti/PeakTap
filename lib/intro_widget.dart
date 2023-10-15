import 'package:flutter/material.dart';
import 'package:intro_slider/intro_slider.dart';

class IntroWidget extends StatefulWidget {
  const IntroWidget(this.sink, {super.key});

  final Sink<void> sink;

  @override
  State<IntroWidget> createState() => _IntroWidget();
}

class _IntroWidget extends State<IntroWidget> {
  List<ContentConfig> listContentConfig = [];

  @override
  void initState() {
    super.initState();

    listContentConfig.add(
      const ContentConfig(
        title: "Draw Panoramas",
        description:
            "Draw wonderful panoramas of the mountains and hills around your. "
            "Or visit other places to see what panorama you saw the day before, "
            "or what you can expect on that trip next week!",
        pathImage: "assets/intro/mont_blanc_1.png",
        backgroundColor: Color(0xffaaaa55),
      ),
    );
    listContentConfig.add(
      const ContentConfig(
        title: "Pan around",
        description:
            "You can pan the panorama view to see a different part of the horizon. "
            "On the map the view of the horizon will be updated. "
            "This allows you to evaluate the distance to the hills and mountains "
            "around you.",
        pathImage: "assets/intro/mont_blanc_2.png",
        backgroundColor: Color(0xff99aa55),
      ),
    );
    listContentConfig.add(
      const ContentConfig(
        title: "Put on the Binoculars",
        description:
            "If you want to know more about a given spot in the panorama, you can "
            "simply tap on it and a magnified view will pop up. "
            "The display will show the heading, distance, and height of the "
            "chosen point in the panorama. "
            "Of course you can still pan around.",
        pathImage: "assets/intro/mont_blanc_3.png",
        backgroundColor: Color(0xff77aa55),
      ),
    );
    listContentConfig.add(
      const ContentConfig(
        title: "Loading the Maps",
        description:
            "The first time you view a panorama in a new geographical zone, the app "
            "will download the elevation-maps. "
            "This takes some time, so please be patient. "
            "Once the maps are loaded, they will be stored for faster "
            "viewing pleasure.",
        pathImage: "assets/intro/loading_map.png",
        backgroundColor: Color(0xff55aa55),
      ),
    );
  }

  void onDonePress() {
    widget.sink.add(null);
  }

  @override
  Widget build(BuildContext context) {
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
