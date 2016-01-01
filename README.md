# CaseLights

CaseLights is an Arduino based RGB LED controller using a simple MOSFET setup. The lights are controlled with a Mac OS X Menu Bar App that can set static colors, animations, or visualize various computer status values using the included [JSystemInfoKit](https://github.com/jBot-42/JSystemInfoKit).

## Arduino Sketch

You could connect pretty much any hardware. I’m using a N-Channel MOSFET Setup with IRF530 and a 10-piece RGB LED strip as well as an UV light tube.

[![fritzing Schematic](https://i.imgur.com/jWLW22F.png)](https://i.imgur.com/sXAADUs.png)

My finished setup is made with a cheap Arduino Pro Mini clone from China and a [dead simple RS232-TTL converter](http://picprojects.org.uk/projects/simpleSIO/ssio.htm) connected to its serial port. You may need to change `Serial` to `Serial1` in the Sketch if you’re trying to do this with an Arduino Leonardo, as I did at first.

Uncomment the `#define DEBUG` at the beginning of the Sketch to enable very verbose debug messages sent on the serial port. This is not recommended for use with the CaseLights App.

## Mac OS X App

The CaseLights XCode project includes the projects from the submodules in this repository. Just run `xcodebuild` on the command line or open the project in XCode and click `Run` to start the App.

![Screenshot](https://i.imgur.com/K7HuJPK.png)

CaseLights is only visible in the system menu bar. You can enable or disable the fourth channel (used for UV lighting in my case), set the RGB LEDs to static colors or simple animations, and select different visualizations for the RGB LEDs like CPU, GPU and RAM usage or hardware temperatures. The minimum and maximum values for these modes are hardcoded, but can be modified easily.

You can also select one of the displays connected to the Host machine. The CaseLights App will then create a Screenshot of this display 10-times per second and calculate the average color to display it on the RGB LEDs.

## Working with Git Submodules

To clone this repository, enter the following:

    git clone https://xythobuz.de/git/CaseLights.git
    git submodule init
    git submodule update

When pulling changes from this repository, you may need to update the submodule:

    git submodule update

## Licensing

The included [JSystemInfoKit](https://github.com/jBot-42/JSystemInfoKit) project is licensed under the GPLv2. See the LICENSE file in the submodule directory.

The included [EZAudio](https://github.com/syedhali/EZAudio) project is licensed under the MIT license. See the LICENSE file in the submodule directory.

CaseLights itself is made by Thomas Buck <xythobuz@xythobuz.de> and released under a BSD 2-Clause License. See the accompanying COPYING file.

