# CaseLights

CaseLights is an Arduino based RGB LED controller using a simple MOSFET setup. The lights are controlled with a Mac OS X Menu Bar App that can set static colors, animations, or visualize various computer status values using the included [JSystemInfoKit](https://github.com/jBot-42/JSystemInfoKit).

## Mac OS X App

The CaseLights XCode project includes the JSystemInfoKit project from the submodule in this repository. Just run `xcodebuild` on the command line or open the project in XCode and click `Run` to start the App.

![Screenshot](https://i.imgur.com/N7j7BJV.png)

## Working with Git Submodules

To clone this repository, enter the following:

    git clone https://xythobuz.de/git/CaseLights.git
    git submodule init
    git submodule update

When pulling changes from this repository, you may need to update the submodule:

    git submodule update

## Licensing

The included [JSystemInfoKit](https://github.com/jBot-42/JSystemInfoKit) project is licensed under the GPLv2.

CaseLights itself is made by Thomas Buck <xythobuz@xythobuz.de> and released under a BSD 2-Clause License. See the accompanying COPYING file.

