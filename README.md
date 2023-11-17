# PeakTap

Showing a nice mountain panorama and lets you search for anything in view:
- calculates the panorama and displays it (currently with a flat earth :)
- lets you click in the panorama to link to the map and see what is there
- lets you click in the map to change the viewpoint - visit other places

## Why is this better than other panorama apps?

- Allows you to see all the mountains around you, not only those the app thinks are interesting
- Also shows very far mountains (like the _Mont Blanc_ as seen from _Morges_ in Switzerland),
  which are often omitted in other apps
- You can also zoom in on mountains in the foreground, or villages
- Choose the place from which you want to see the panorama

It uses worldwide elevation data from https://srtm.csi.cgiar.org/

Example screenshot of showing the horizon in the map and as a panorama:

![OpenStreetMaps on top with panorama below](Screenshot_mont_blanc_horizon.png)

Example screenshot of zooming in on Mont Blanc:

![Zoom on Mont Blanc](Screenshot_mont_blanc_zoom.png)

# Next steps

I would like to implement the following:

- remove unused tiles from the cache to decrease memory usage
- display updates
  - add a 360-degree view on the bottom and let the user scroll fast using it
  - add translations
- more progress-info needs:
  - show precision on GPS-lock
  - when downloading map, show that it's decompressing instead of 
   sticking to "99%"
- having some buttons to enable/disable features:
  - make mountains higher (if they're far away) / lower (if you're in the Valais)
  - enable / disable earth curvature
  - showing the panorama in the direction the phone points 
  - height above current point (standard is 10m)
- load tiles from https://map.ineiti.ch for faster loading
- skip "Searching for GPS" by allowing the user to choose the standing point

## Bugs

- In telescope mode, when panning down, it wraps around. Should stop instead.
- correctly place pin (currently it's a bit off)

## Before release

- add paying voting option for next version

Other ideas are welcome...

# Privacy Policy

The app owner is [Linus Gasser](ineiti@gasser.blue), and the app is copyrighted 2023.
The following data is collected by version 1.0.0:
- the SRTM website has access to the tiles you download from their site. Here is their [Disclaimer](https://srtm.csi.cgiar.org/disclaimer/)
- openStreetMap has access to all the places you are connecting to. Here is their [Privacy Policy](https://wiki.osmfoundation.org/wiki/Privacy_Policy)
- no other data is collected by the app

## CHANGELOG

- 2023-11-17 - v1.0.7+12
  - Fix bug where the direction of the view is always initialized to 240˚

- 2023-11-15 - v1.0.6+11
  - Apple-store complaint fixed: when the GPS doesn't give a fix in a reasonable time, show
  a list of pre-defined positions to jump to

- 2023-11-13 - v1.0.5+10
  - BUG: when first started up, the panorama cannot be scrolled

- 2023-11-12 - v1.0.4+9
  - updated screenshots for first startup
  - add lightning to rendering

- 2023-10-17 - v1.0.3+8
  - interpolate heights from other points
  - paint according to inclination of tile

- 2023-10-15 - v1.0.2+7
  - GPS request info update for passing apple-store
  - added intro screen

- 2023-09-07 - rc5 (waiting for iOS approval)
  - display updates
    - when zooming in the panorama view, switch to goggle view

- 2023-08-19 - rc4
  - Added blue sky
  - Even faster drawing of panorama

- 2023-08-10 - rc2
  - Some speed improvements while painting the panorama
  - Showing progress while downloading tiles
  - Showing exceptions in the progress screen
  - Adding INTERNET permission

- 2023-08-09
  - added progress-info for locking to GPS, downloading, and painting

- 2023-08-04
  - changed name to PeakTap

- 2023-08-03
  - add a cross to the binoculars and some info:
    - heading
    - distance
    - height
  - add a button to update GPS
  - make working iOS version

- 2023-07-13
  - when starting up, there is often a moment when the polygon seems to have two points:
  this is because it still shows the old, pre-defined POI
  - when choosing a new POI on the map, also show "creating panorama"

- 2023-07-11
  - avoid loading twice the same tile
  - show "loading" texts
  - when clicking on the panorama, zoom in the top of the chosen area,
  put a cross in the middle, and let the user pan around

- 2023-07-09 
  - using another dataset which covers the whole earth
  - scrolling also adds the POI
  - tapping for a POI also scrolls, and thus hides the zoom
