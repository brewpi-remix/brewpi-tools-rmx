# <a name="top"></a>![BrewPi Remix Logo](https://raw.githubusercontent.com/brewpi-remix/brewpi-www-rmx/master/images/brewpi_logo.png)

Before we proceed, a huge thank you to [Elco Jacobs](https://github.com/elcojacobs), without whom none of this would be possible.

This is [@LBussy](https://github.com/lbussy)'s forks of the original [BrewPi Project](https://github.com/BrewPi).  This project has a new website, please also visit https://www.brewpiremix.com.

This project contains the tools to setup, update and configure BrewPi Remix which runs on a [Raspberry Pi](https://www.raspberrypi.org/), communicating with an [Arduino](https://www.arduino.cc/en/guide/introduction).  Despite the original creators no longer actively supporting BrewPi on Arduino, and despite the Arduino being arguably one of the least capable [controllers](https://en.wikipedia.org/wiki/Controller_(computing)) on the market, BrewPi on Arduino still has an amazing following among home brewers.  As of March 9, 2019 there are [7628 posts in this thread](https://www.homebrewtalk.com/forum/threads/howto-make-a-brewpi-fermentation-controller-for-cheap.466106/) on [HomeBrewTalk.com](https://www.homebrewtalk.com/) since March 19, 2014 when [@FuzzeWuzze](https://www.homebrewtalk.com/forum/members/fuzzewuzze.123340/) started the thread.

These [forks](https://en.wikipedia.org/wiki/Fork_(software_development)) are intended for the fans of the *original* BrewPi (called "Legacy" in BrewPi circles).  For current [BrewPi Spark 3](https://www.brewpi.com/) information and support, please continue to use and support [the original project](https://github.com/BrewPi).

# <a name="toc"></a>Table of Contents

- [Getting Started](#getting-started)
- [Documentation](#documentation)
- [Upgrades](#upgrades)
- [Support](#support)
- [Scripts in this Repo](#scripts)
- [Assumptions and Proceedings](assumptions-proceedings)
- [Credits](credits)
- [Postscript](#postscript)
- [Security Note](#security-note)
- [FAQ](#faq)
- [Known Issues / Report Issues](#known-issues)

# <a name="getting-started"></a>Getting Started
Check [Assumptions and Proceedings](#assumptions-proceedings) before moving forward if you are not starting with a brand new install of current Raspbian on a dedicated Pi.

If you want to know the who, what, why and when, check out [the documentation](#documentation).

To begin installing BrewPi, you need only issue the following command in a [terminal window](https://www.raspberrypi.org/documentation/usage/terminal/) (or via [ssh](https://www.raspberrypi.org/documentation/remote-access/ssh/)) on your Internet-connected Raspberry Pi:

`curl -L install.brewpiremix.com | sudo bash`

Or, if you must know and type a longer URL (all one line):

`curl -L raw.githubusercontent.com/brewpi-remix/brewpi-tools-rmx/master/bootstrap.sh | sudo bash`

These are the same links, I merely have created a redirect on the [BrewPi Remix domain](https://www.brewpiremix.com) for your convenience to make it shorter and easier to remember.

If you have a broken installation and/or need to run the uninstaller without BrewPi being installed correctly for some reason, you may use (all one line):

`curl -L uninstall.brewpiremix.com | sudo bash`

*or:*

`curl -L https://raw.githubusercontent.com/brewpi-remix/brewpi-tools-rmx/master/uninstall.sh | sudo bash`

Please read the notes in the table below before running the uninstaller.

Security-conscious or just plain curious folks will want to read this [security note](#security-note) before proceeding.

When the installation script completes, you will have a working BrewPi Legacy setup.  I'm a little amazed that the work I've done is summed up in one "run this", but if I've done my work right that should be it. Do [let me know](https://github.com/brewpi-remix/brewpi-tools-rmx/issues) if you find differently.  As my online friend [Thorrak](https://github.com/thorrak) tells me, anything different in the user experience is a bug.

# <a name="documentation"></a>Documentation

Full documentation is provided [at this link](https://docs.brewpiremix.com).

# <a name="upgrades"></a>Upgrades

If you are upgrading from a version previous to 0.5.3.x, please use the online upgrade script:

`curl -L upgrade.brewpiremix.com | sudo bash`

# <a name="getting-started"></a>Support

If you have usage issues or questions not addressed in the documentation, please join us on [Homebrewtalk.com](https://www.homebrewtalk.com) in the [Mega Thread](https://www.homebrewtalk.com/forum/threads/howto-make-a-brewpi-fermentation-controller-for-cheap.466106/).

# <a name="scripts"></a>Scripts in this Repo

Filename | Description
------------ | -------------
bootstrap.sh | This script will handle all *initial* setup and prep of a new Raspberry Pi.  It will clone this repository and kick off the installer proper.  This should be the only touch-point you need to get going.
install.sh | This script will install BrewPi on a Raspbian distro, or add a chamber to a multi-chamber setup.  It is called by the bootstrap script during initial install.  To move an **existing** BrewPi Legacy system to this new fork, you should execute an uninstall (or just make a new system on a fresh SD card.) See uninstall.sh below.
uninstall.sh | This is an uninstaller I created for my own testing.  It may be of use to someone wanting to clean up their Raspberry Pi as they install/uninstall for their own testing.  It has four 'levels' of uninstall, the lowest-level being rather brutal in that it does not care if you previously installed any of the dependencies for some other purpose.  This behavior is *likely* safe (but not tested) if you intend to reinstall BrewPi right away.  It will at minimum remove the original as well as BrewPi Remix Tools, Script and WWW folders. I've also added the ability to uninstall a single chamber if you have a multi-chamber setup.  Uninstallation is tricky in these systems because dependencies overlap.  If you have a particularly "lived in" system, perhaps it's time to get a new SD card?  They are like $6 on Amazon ...

# <a name="assumptions-proceedings"></a>Assumptions and Proceedings

This tool set adds a [bootstrap](https://en.wikipedia.org/wiki/Bootstrapping) to install the BrewPi Remix packages on a completely fresh install of [Raspbian](https://www.raspberrypi.org/documentation/raspbian/) (codename "[Stretch](https://www.raspberrypi.org/blog/raspbian-stretch/)" at the time of this writing).  I have created the bootstrap because some steps required in previous iterations were a little alien to people new to Raspbian/Linux.  I don't think you should have to be a CS major to enjoy better beer.  Additionally, some supporting software (most significantly, PHP) has been deprecated/upgraded which before now made the older BrewPi packages incompatible with contemporary systems.

This bootstrap will:

- Check a few things
- Handle some Raspberry Pi setup steps if/as needed or recommended
- Install some supporting files
- Download and execute the BrewPi-Tools-RMX installation scripts
- Perform some final cleanup

In order to make this work well, I have to make some assumptions about the environment in which this will be run.  Here I'll try to list some, however I am sure someone will find a way to try something I've not considered.  Do not over-think this.  Don't fiddle around with your Pi before running the bootstrap.  Turn it on, connect to your home network, and go.  Here's a list of known assumptions made during this project:

- This has been developed and tested on a Raspberry Pi 3 B+ because that's what I have laying around.  I have absolutely no reason to believe it would not work on a Zero, 2B, or other versions of the Raspberry Pi line.  I've just not tested it.
- This has been developed and tested on the Raspbian OS.  Raspbian is based on Debian so using a Debian (or derivative) OS distribution *may* work, however that's not been tested.  I am **not** at all sure that it would work on a different flavor of Linux.
- This has been developed and tested on the Raspbian Stretch distribution.  If a new distribution for the Raspberry Pi is released it *may* no longer work.  I hope I've future-proofed it, however the original/core code may have some non future-proofed areas waiting to rear their ugly head (or I may not be as good at future-proofing as I believe.)
- I've assumed throughout that this is the only function the Pi will handle.  This is not unique to this remix project.  Some other projects use things (like nginx for example) which have known incompatibilities with packages used by BrewPi. It makes sense when you think about it (having two packages both trying to be the web server on the system) but it gets confusing the first time you hit the errors.
- While I'm semi-paranoid and I have worked on some security related improvements, this will **not** create a BrewPi which is secure enough to connect to *from* the Internet.  There's a whole host of reasons for this, but please, do not do it unless you know what you are doing.  I suggest you consider [Dataplicity](https://www.dataplicity.com) if you really need/want to do this.  If I get bored I might add some thought to this but in general I don't think a poor Raspberry Pi needs to be connected to all those bad actors out there.
- This has been developed and tested using the default user 'pi' which by default has password-less `sudo` rights.  This is how Raspbian is shipped, and this is how I'll continue to test it.  If you know enough to change or disagree with any of this, you know enough to figure out why this process may not work for you.  If you simply MUST change things, I suggest you do it after you get BrewPi Remix running. As I go along I have tried to remove hard dependencies on the pi account for instance, but not all paths have been tested.
- At the very least, you MUST NOT be logged in as (or have used `su` to) `root`.  The script needs to be a real user, not root, and that user needs to have sudo access.  I can't emphasize this enough: You should NEVER log in as root unless there's simply no way around it.  I will not change this; I think it's bad enough that `sudo` has to be used because of the package installs but that's a problem for a different day. 
- You need for your Pi to have access *to* the Internet.  I think this is obvious, but the Pi needs to access GitHub and standard Raspbian repositories to download code.  Generally speaking, plugging your Pi into your home network with an Ethernet cable will do this without any configuration necessary.  Attaching to wireless will take a little more work that's not in scope of this project (but I do have [another project](https://github.com/lbussy/headless-pi) that will help.)
- This has been developed and tested on a bone-stock Raspbian setup, with no user or local customization implemented.  The only things that has been tested which do not inherently work on a fresh setup is wireless connectivity and ssh over wireless.  The bootstrap script will:

  1. Check to make sure the script has executed with `sudo` to `root` (this is how the [instructions above](#getting-started) will work if you follow them)
  2. Provide some rudimentary instructions
  3. Check for the incredibly insecure default pi password of 'raspberry', and prompt to change it if so
  4. Prompt you to set the proper timezone
  5. Prompt to optionally change the host name if it is currently the default 'raspberrypi'
  6. Check network connectivity to GitHub (this part should be a given since it's intended to be run via `curl` but I'm not going to assume someone can't break my plans)
  7. Run an `apt update` if it's not been run within the last week
  8. Install `git` packages via `apt get` to allow the rest of the install to work
  9. Clone the BrewPi Tools RMX into the `~/brewpi-tools-rmx` folder
  10. Execute install.sh which is responsible for the rest of the setup

I am certain that someone will find an important assumption I did not list here.  We'll see how long that takes.  [Let me know](https://github.com/brewpi-remix/brewpi-tools-rmx/issues) what you find.

# <a name="credits"></a>Credits

These scripts were originally a part of [brewpi-tools](https://github.com/BrewPi/brewpi-tools), an installer for the [BrewPi project](https://github.com/BrewPi).  My original intent was to simply make the Legacy branch of BrewPi work again since the original install scripts called for PHP5 explicitly and that's no longer available from the regular repositories.  The project grew from there to address some other opportunities to improve the original, as well as to make it easier for beginners to get started.

All credit for the original [brewpi-tools](https://github.com/BrewPi/brewpi-tools) goes to [@elcojacobs](https://github.com/elcojacobs), [@vanosg](https://github.com/vanosg), [@routhcr](https://github.com/routhcr), [@ajt2](https://github.com/ajt2) and I'm sure many more contributors around the world.  My apologies if I have missed anyone; those were the names listed as contributors on the Legacy branch.

All the original [BrewPi](https://github.com/BrewPi) projects' Legacy branches have been forked to these repositories, you need not (and should not) mix repositories for this project:

Original Repository | Description | Remix Repository
------------ | ------------- | ------------- 
[brewpi-tools](https://github.com/BrewPi/brewpi-tools) | The original version of this tools repository. | [BrewPi Tools Remix](https://github.com/brewpi-remix/brewpi-tools-rmx)
[brewpi-script](https://github.com/BrewPi/brewpi-script) | Scripts which log the data, monitor the temperature profile and communicate with the BrewPi slave and the web server. | [BrewPi Script Remix](https://github.com/brewpi-remix/brewpi-script-rmx)
[firmware](https://github.com/BrewPi/firmware) | Temperature control firmware for the BrewPi Arduino. | [BrewPi Firmware Remix](https://github.com/brewpi-remix/brewpi-firmware-rmx)
[brewpi-www](https://github.com/BrewPi/brewpi-www) | The BrewPi web interface which communicates with the Python script, which will in turn talk to the Arduino - and vice-versa. | [BrewPi WWW Remix](https://github.com/brewpi-remix/brewpi-www-rmx)

# <a name="postscript"></a>Postscript

This project takes us back to the days when Arduino was King, firmware v2.10 was as good as it got, and the world was a happy place.  I hope someone enjoys it.

# <a name="security-note"></a>Security Note

My instructions above tell you to copy and paste a command into your terminal window.  Despite me telling you to do that, I am now going to tell you how unsafe that is.  Many people browse the Internet, find the command they need, and blindly paste it into their terminal window.  This one is blatantly (potentially) dangerous from a non-trusted source:

> `curl -L install.brewpiremix.com | sudo bash`

It's going to download a script to your Raspberry Pi, and pipe (`|`) it through the command `sudo bash`.  When you use `sudo` without any other arguments it will run the command which follows with `root` privileges.  So, you basically found someone on the Internet telling you to run their code as root, without even knowing what it all does.  Despite the inherent risk, installing an application as root is often necessary since some applications have to make global changes to your system.

*This is how bad things happen.*

Even if you think you *completely* understand the command you are reading and copying, there is still an opportunity for a specially crafted web page to make the command look like one thing, but be a completely different command when you paste it.  That would be ***A Bad Thing*&trade;.**  For an example, see [this page which describes this copy/paste vulnerability](https://thejh.net/misc/website-terminal-copy-paste).  Instead of pasting the test lines on that page into a terminal window, you can see the "payload" of the attack by a copy/paste into any text editor.

The lesson to be learned from this is if you are going to copy/paste a command from __*any*__ source, always use an interim paste into a text editor like Notepad to make sure ***A Bad Thing*&trade;** doesn't happen to you.  Now you can join your previously scheduled show: [Getting Started](#getting-started), which is patiently waiting for you above.

Wait.  Now you don't know if you should trust the setup command I provided?  I'm shedding a happy tear.  Security and the Internet is a rabbit hole filled with (justifiable) paranoia and bad actors.  Your choices here however are:

1. Trust me and run it
2. Examine [that script](https://github.com/brewpi-remix/brewpi-tools-rmx/blob/master/bootstrap.sh) carefully and make sure it does nothing bad.  Then, since the first one executes as root you need to follow that to the [next one](https://github.com/brewpi-remix/brewpi-tools-rmx/blob/master/install.sh) because it inherits that security construct.  Ultimately you can drive yourself crazy when you realize the implications, or just accept that whenever you install free code from the Internet you take your chances.  This is the case with any software, not just BrewPi.

[I have listed out the steps to install BrewPi manually](https://www.brewpiremix.com/for-the-masochists/).  The steps may change slightly and to be honest I likely won't maintain that page as religiously as the others.  That's quite frankly not a high priority for me since the goal here is to make BrewPi Remix available to every-day people.  Those of you who would choose the manual steps can probably figure it all out anyway.

Cheers!

# <a name="faq"></a>FAQ:

- "*What about some other scenario, when will you test that?*" - Maybe never.  This is not a commercial venture; chances are once I'm "done enough" making it work on the target system, I'll be done for good.  Who knows though.  The original/current [BrewPi](https://www.brewpi.com) is a far more capable system, with a wider adoption base, and excellent support.  That's probably a better choice for you if you want to venture from this path I've created for you.
- "*Do you plan to create/implement/merge {insert cool idea here} functionality?*" - Probably not.  I'm not a software developer by trade, and this is not a commercial venture so there's probably little reason to implement something I'll never use.  If you can convince me I'd use it, maybe, or you can do it and we can talk about merging it in.  To be embarrassingly and brutally honest, I hardly get a chance to even brew anymore.  I started this initially to make it easier for a friend of mine to get going again after his Pi ate his SD card.  I'll repeat: The original/current [BrewPi](https://www.brewpi.com) is a far more capable system, with a wider adoption base, and excellent support.  That's probably a better choice for you if you want expanded capabilities.
- "*Will you accept pull requests*?" - Maybe.  Here's the honest truth however:  Not being a software developer by trade means that working with typical software development tools in a collaborative environment like GitHub is somewhat alien to me.  If you're willing to work with someone who does not have these skills in order that you may contribute your own work, it's likely best to [contact me directly](https://github.com/lbussy/) before you start so we can work out the details to avoid frustration for both of us (mostly you.)
- "*What about older versions of the Pi or Raspbian Stretch, etc.?*" - I've no reason to believe older versions will not work, but they've not been tested.  In theory it should work fine, but at some point, on a platform like Raspberry Pi, you just need to say "flash a new card and get over it."  These are not desktop machines that accumulate "stuff" over the years which you want to keep, and there's no cost to downloading the new version.  If you have a Pi that's on it's original SD card for more than a couple years you have a rare bird indeed.  I'd be more than happy to discuss why it didn't work if you run into an issue, it would be interesting I think, but it might not be something I choose to address.

# <a name="known-issues"></a>Known Issues

You can view or log new issues via the links below:

| Project | Name | Known Issues |
| ------------ | ------------- | ------------- |
| BrewPi-Tools-RMX | Install and uninstall tools | [Issues List](https://github.com/brewpi-remix/brewpi-tools-rmx/issues) |
| BrewPi-Script-RMX | Python scripts supporting BrewPi website | [Issues List](https://github.com/brewpi-remix/brewpi-script-rmx/issues) |
| BrewPi-WWW-RMX | Website files | [Issues List](https://github.com/brewpi-remix/brewpi-www-rmx/issues) |
| BrewPi-Firmware-RMX | Arduino firmware | [Issues List](https://github.com/brewpi-remix/brewpi-firmware-rmx/issues) |

Back up to [the top](#top).

