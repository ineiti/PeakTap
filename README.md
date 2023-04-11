# MountainPanorama

Showing a nice mountain panorama.
Contrary to other panorama programs, this one:
- calculates the panorama and displays it
- lets you click in the panorama to link to the map
- lets you click in the map to change the viewpoint
- shows the view and which mountains are visible

Example screenshot:

![Google maps on top with panorama below](Screenshot_MountainPanorama.png)

## Running it locally

To run it locally, you need a google maps API key.
Unfortunately you have to add it twice: once to `web/index.html`
and once as an environment variable called `MAPS_API_KEY`.