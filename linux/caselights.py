# CaseLights Linux Qt System Tray client
# depends on:
# - python-pyqt5
# - python-pyserial

import sys
import serial, serial.tools, serial.tools.list_ports
from PyQt5 import QtWidgets, QtGui, QtCore
from PyQt5.QtWidgets import QSystemTrayIcon, QAction, QMenu
from PyQt5.QtGui import QIcon, QPixmap
from PyQt5.QtCore import QCoreApplication, QSettings

class CaseLights():
    name = "CaseLights"
    vendor = "xythobuz"
    version = "0.1"

    staticColors = [
        [ "Off",     "0",   "0",   "0", None ],
        [ "Red",   "255",   "0",   "0", None ],
        [ "Green",   "0", "255",   "0", None ],
        [ "Blue",    "0",   "0", "255", None ],
        [ "White", "255", "255", "255", None ],
    ]

    usedPort = None
    serial = None

    menu = None
    portMenu = None
    portActions = None
    refreshAction = None
    quitAction = None

    def __init__(self):
        app = QtWidgets.QApplication(sys.argv)
        QCoreApplication.setApplicationName(self.name)

        if not QSystemTrayIcon.isSystemTrayAvailable():
            print("System Tray is not available on this platform!")
            sys.exit(0)

        self.readSettings()
        if self.usedPort is not None:
            self.connect()

        pic = QPixmap(32, 32)
        pic.load("icon.png")
        icon = QIcon(pic)

        self.menu = QMenu()

        colorMenu = QMenu("&Colors")
        for color in self.staticColors:
            color[4] = QAction(color[0])
            colorMenu.addAction(color[4])
        colorMenu.triggered.connect(self.setStaticColor)
        self.menu.addMenu(colorMenu)

        lightMenu = QMenu("&UV-Light")
        lightOnAction = QAction("O&n")
        lightOnAction.triggered.connect(self.lightsOn)
        lightMenu.addAction(lightOnAction)
        lightOffAction = QAction("O&ff")
        lightOffAction.triggered.connect(self.lightsOff)
        lightMenu.addAction(lightOffAction)
        self.menu.addMenu(lightMenu)

        self.refreshSerialPorts()

        self.quitAction = QAction("&Quit")
        self.quitAction.triggered.connect(self.exit)
        self.menu.addAction(self.quitAction)

        trayIcon = QSystemTrayIcon(icon)
        trayIcon.setToolTip(self.name + " " + self.version)
        trayIcon.setContextMenu(self.menu)
        trayIcon.setVisible(True)
        
        sys.exit(app.exec_())

    def exit(self):
        if self.serial is not None:
            if self.serial.is_open:
                print("turning off lights")
                self.serial.write(b'RGB 0 0 0\n')
                self.serial.write(b'UV 0\n')
                print("closing connection")
                self.serial.close()
        QCoreApplication.quit()

    def readSettings(self):
        settings = QSettings(self.vendor, self.name)
        self.usedPort = settings.value("serial_port")
        if self.usedPort is not None:
            print("serial port stored: " + self.usedPort)
        else:
            print("no serial port stored")

    def writeSettings(self):
        settings = QSettings(self.vendor, self.name)
        settings.setValue("serial_port", self.usedPort)
        if self.usedPort is not None:
            print("storing serial port: " + self.usedPort)
        else:
            print("not storing any serial port")
        del settings

    def refreshSerialPorts(self):
        self.portMenu = QMenu("Port")
        ports = serial.tools.list_ports.comports()
        self.portActions = []
        for port in ports:
            action = QAction(port.device)
            self.portActions.append(action)
            self.portMenu.addAction(action)
        self.portMenu.triggered.connect(self.selectSerialPort)

        if self.refreshAction == None:
            self.refreshAction = QAction("&Refresh")
            self.refreshAction.triggered.connect(self.refreshSerialPorts)
        self.portMenu.addAction(self.refreshAction)
        self.menu.insertMenu(self.quitAction, self.portMenu)

    def selectSerialPort(self, action):
        self.usedPort = action.text()
        self.writeSettings()
        if self.connect():
            self.portMenu.setActiveAction(action)

    def connect(self):
        if self.usedPort is None:
            print("not connecting to any serial port")
            return False

        if self.serial is not None:
            print("closing previous port")
            self.serial.close()

        self.serial = serial.Serial()
        self.serial.port = self.usedPort
        self.serial.baudrate = 115200
        self.serial.open()
        if self.serial.is_open:
            print("connected to: " + self.usedPort)
        else:
            print("error connecting to: " + self.usedPort)
        return self.serial.is_open

    def setStaticColor(self, action):
        for color in self.staticColors:
            if color[4] is action:
                if self.serial.is_open:
                    r = str.encode(color[1])
                    g = str.encode(color[2])
                    b = str.encode(color[3])
                    self.serial.write(b'RGB ' + r + b' ' + g + b' ' + b + b'\n')
                else:
                    print("not connected")
                return True
        print("color not found")
        return False

    def lightsOn(self):
        if self.serial.is_open:
            self.serial.write(b'UV 1\n')
        else:
            print("not connected")

    def lightsOff(self):
        if self.serial.is_open:
            self.serial.write(b'UV 0\n')
        else:
            print("not connected")

if __name__ == "__main__":
    tray = CaseLights()
