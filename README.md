# BrewPi Tools Remix
*[@LBussy](https://github.com/lbussy)'s fork of the original [brewpi-tools](https://github.com/BrewPi/brewpi-tools)*

This project contains tools to setup, update and configure [BrewPi](https://www.brewpi.com/this-is-brewpi-0-2/) on [Arduino](https://www.arduino.cc/en/guide/introduction).  Despite the original creators no longer actively supporting BrewPi on Arduino, and despite the Arduino being arguably one of the least capable [controllers](https://en.wikipedia.org/wiki/Controller_(computing)) on the market, BrewPi still has an amazing following among homebrewers.  When I last checked there were [7473 posts in this thread](https://www.homebrewtalk.com/forum/threads/howto-make-a-brewpi-fermentation-controller-for-cheap.466106/) on [HomeBrewTalk.com](https://www.homebrewtalk.com/) since March 19, 2014 when [@FuzzeWuzze](https://www.homebrewtalk.com/forum/members/fuzzewuzze.123340/) started the thread.

This toolset adds a [bootstrap](https://en.wikipedia.org/wiki/Bootstrapping) to install the BrewPi packages on a completely fresh install of [Raspbian](https://www.raspberrypi.org/documentation/raspbian/) (codename "[Stretch](https://www.raspberrypi.org/blog/raspbian-stretch/)" at the time of this writing).  New versions of Raspbian have updated packages which before now made the older BrewPi packages incompatible.  This [fork](https://en.wikipedia.org/wiki/Fork_(software_development)) is intended for the fans of the *original* BrewPi (called "Legacy" in BrewPi circles).  For [BrewPi Spark 3](https://www.brewpi.com/) support, please continue to use and support [the original project](https://github.com/BrewPi).

## <a name="getting-started"></a>Getting Started
To begin installing BrewPi, you need only issue the following command in a [terminal window](https://www.raspberrypi.org/documentation/usage/terminal/) (or via [ssh](https://www.raspberrypi.org/documentation/remote-access/ssh/)) on your Internet connected Raspberry Pi (with wired or [wireless networking](https://www.raspberrypi.org/documentation/configuration/wireless/) according to your wishes and capabilities):

`wget -qO- https://raw.githubusercontent.com/lbussy/brewpi-tools-rmx/master/bootstrap.sh - /| sudo bash`<br> - *or* - <br>`wget -qO- https://tinyurl.com/brewpi-tools-rmx - /| sudo bash`

(Intelligent folks will want to read this [security note](#security-note) before proceeding.)

The bootstrap will:
 * Check a few things
 * Handle some Raspberry Pi setup steps if/as needed
 * Install some supporting files
 * Call the BrewPi-Tools-RMX installation scripts
 * Perform some final cleanup
 
I'm a little amazed that all the work I've done is summed up in those four points, but if I've done my work right that should be it. Do [let me know](https://github.com/lbussy/brewpi-tools-rmx/issues) if you find differently.

## Credits
These scripts were originally a part of [brewpi-tools](https://github.com/BrewPi/brewpi-tools), an installer for the [BrewPi project](https://github.com/BrewPi).  My original intent was to simply make this script work again since the original called for PHP5 explicitly.  It grew from there to address some shortcomings as well as to make it easier for beginners.

All credit for the original [brewpi-tools](https://github.com/BrewPi/brewpi-tools) goes to [@elcojacobs](https://github.com/elcojacobs), [@vanosg](https://github.com/vanosg), [@routhcr](https://github.com/routhcr), [@ajt2](https://github.com/ajt2) and I'm sure many more contributors around the world.  My apologies if I have missed anyone; those were the names listed as contributors on the Legacy branch.

In order that I can assure myself that these scripts will always have access to that which they need to operate, all the [BrewPi](https://github.com/BrewPi) projects' Legacy branches have been forked to my own repos and made 'Master'; including:
* [brewpi-tools](https://github.com/BrewPi/brewpi-tools) - The original version of this repository, now called [BrewPi Tools Remix](https://github.com/lbussy/brewpi-tools-rmx).
* [brewpi-script](https://github.com/BrewPi/brewpi-script) - Scripts which log the data, monitor the temperature profile and communicate with the BrewPi slave and the web server.  The current repository which is compatible with this toolset can be found in [BrewPi Script Remix](https://github.com/lbussy/brewpi-script-rmx).
* [firmware](https://github.com/BrewPi/firmware) - Temperature control firmware for the BrewPi Arduino.  The current repository which is compatible with this toolset can be found in [BrewPi Firmware Remix](https://github.com/lbussy/brewpi-firmware-rmx).
* [brewpi-www](https://github.com/BrewPi/brewpi-www) - The BrewPi web interface which communicates with the Python script, which will in turn talk to the Arduino. The current repository which is compatible with this toolset can be found in [BrewPi WWW Remix](https://github.com/lbussy/brewpi-www-rmx).

## Files in this Repo
Filename | Description
------------ | -------------
bootstrap.sh | This script will handle all setup and prep of a new Pi, primarily tested on "Lite" distros.  It will clone this repository and kick off the installer proper.  This should be the only touch-point you need to get going.
install.sh | This script will install BrewPi on a Raspbian distro.  It is called by the bootstrap script.
uninstall.sh | This is an uninstaller I created for my own testing.  It may be of use to someone wanting to clean up their Raspberry Pi as they install/uninstall for testing.  It is rather brutal in that it does not care if you previously installed any of the packages which BrewPi needs.  It will uninstall all of them in BrewPi's list of dependencies.
updater.py | This script will check for any updates to the entire BrewPi installation, and; upon request, will install them to your Pi.
doCron.sh | Handles setting up the cron jobs that BrewPi depends upon for functionality.  Called by install.sh and updater.py as needed.
doDepends.sh | This script will check for and address missing or out of date packages via apt and pip.  Called by install.sh and updater.py as needed.
doPerms.sh | Sets correct ownership and permissions on BrewPi files.  Called by install.sh and updater.py as needed.
updateToolsRepo.sh | This script will ensure the install tools are up to date.  This is called by updater.py as needed.

## Postscript
This project takes us back to the days when Arduino was King, firmware v2.10 was as good as it got, and the world was a happy place.  I hope someone enjoys it.

## <a name="security-note"></a>Security Note
My instructions above tell you to copy and paste a command into your terminal window.  Despite me telling you to do that, I am now going to tell you how unsafe that is.  Many people browse the Internet, find the command they need, and blindly paste it into their terminal window.  This one is blatantly (potentially) dangerous from an untrusted source:

`wget -qO- https://tinyurl.com/brewpi-tools-rmx - /| sudo bash`

It's going to download a script to your Raspberry Pi, and pipe ("|") it through `sudo bash`.  When you `sudo` without any other arguments it will run the command which follows with `root` privileges.  So, you basically found someone on the Internet telling you to run their code as root, without even knowing what it all does.  

*This is how bad things happen.*

Even if you think you *completely* understand the command you are reading, copying and pasting, there is still an opportunity for a specially crafted web page to make the command look like one thing, but be a completely different command when you paste it.  That would be ***A Bad Thing*&reg;&trade;.**

For an example, see [this page which described this copy/paste vulnerability](https://thejh.net/misc/website-terminal-copy-paste).  Instead of pasting the test lines on that page into a terminal window, you can see the "payload" of the attack by a copy/paste into any text editor.  I tried to figure out a way to demonstrate it here on this page but the markdown implementation on GitHub appears not to support the `<span>` element in a manner which would allow it.  There might be a way, but I have not found it.

*Anyway*, the lesson to be learned from this is **if** you are going to copy/paste from __*any*__ Internet source, always use an interim paste to make sure ***A Bad Thing*&reg;&trade;** doesn't happen to you.  Now you can join your previously scheduled show: [Getting Started](#getting-started), which is patiently waiting for you above.

Wait ... now you don't know if you should trust the command?  I'm shedding a happy tear. :relaxed:  Your choices are:
1. Trust me and run it
2. Examine [that script](https://github.com/lbussy/brewpi-tools-rmx/blob/master/bootstrap.sh) carefully and make sure it does nothing bad.  Then you need to follow that to the next one it calls ... and the next one ... and the next one ... ultimately you can drive yourself crazy, or just accept that whenever you download free code you take your chances

Cheers!

