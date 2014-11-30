ESP8266 Wifi module SDK and Toolchain
=====================================

Here you can found an integration script to build a complete standalone SW package for [ESP8266 Wifi module](http://www.electrodragon.com/product/esp8266-wifi-board-full-ios-smd/), which is based on highly integrated wireless SoC (ESP8266EX) made by [Espressif](http://espressif.com/en/products/esp8266/).


####SDK is made by Espressif Systems:
* [esp_iot_sdk_v0.9.3_14_11_21.zip](http://bbs.espressif.com/download/file.php?id=72)
* [esp_iot_sdk_v0.9.3_14_11_21_patch1.zip](http://bbs.espressif.com/download/file.php?id=73)

ESP8266 SDK is only partially open source, some libraries are provided as binary blobs.
More details you can found on [bbs.espressif.com](http://bbs.espressif.com/viewforum.php?f=5)


####Toolchain is based on following projects:
* [crosstool-NG](https://github.com/jcmvbkbc/crosstool-NG)
* [lx106-hal](https://github.com/tommie/lx106-hal)
* [esptool-ck](https://github.com/tommie/esptool-ck)
* [esptool](https://github.com/themadinventor/esptool)

ESP8266 Toolchain is fully OpenSource.


## Build OS Requirements

You will need have a PC with Linux Mint OS (or some other Ubuntu based distribution) 
with standard GNU development tools installed, like gcc, binutils, flex, bison, etc.
In Linux Mint run follow commands:

``` bash
  $ sudo apt-get update
  $ sudo apt-get install make unrar autoconf automake libtool gcc g++ gperf flex bison texinfo gawk ncurses-dev libexpat-dev python sed
``` 

## Usage

Clone the project into your local directory

``` bash
  $ git clone git://github.com/molejar/esp-sdk-toolchain.git
```

Go inside `esp-sdk-toolchain` directory and run `./build.sh`. If the build was successful, 
then the ESP8266 SDK and Toolchain is located inside `release` directory.
