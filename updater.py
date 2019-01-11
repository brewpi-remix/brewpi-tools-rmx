#!/usr/bin/python

# Copyright (C) 2018  Lee C. Bussy (@LBussy)

# This file is part of LBussy's BrewPi Tools Remix (BrewPi-Tools-RMX).
#
# BrewPi Tools RMX is free software: you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# BrewPi Tools RMX is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with BrewPi Tools RMX. If not, see <https://www.gnu.org/licenses/>.

# These scripts were originally a part of brewpi-tools, an installer for
# the BrewPi project. Legacy support (for the very popular Arduino
# controller) seems to have been discontinued in favor of new hardware.

# All credit for the original brewpi-tools goes to @elcojacobs,
# @vanosg, @routhcr, @ajt2 and I'm sure many more contributors around
# the world. My apologies if I have missed anyone; those were the names
# listed as contributors on the Legacy branch.

# See: 'original-license.md' for notes about the original project's
# license and credits.

############
### Init
############

from __future__ import print_function
import subprocess
from time import localtime, strftime
import sys
import os
import urllib2
import getopt

try:
    import git
except ImportError:
    print("This update script requires gitpython, please install it with:\n'sudo pip install gitpython'")
    sys.exit(1)


# Read in command line arguments
try:
    opts, args = getopt.getopt(sys.argv[1:], "a", ['ask'])
except getopt.GetoptError:
    print ("Unknown parameter, available options: \n" + \
          "  updater.py --ask     Do not use default options, but ask me which branches\n" + \
          "                       to check out")
    sys.exit()

userInput = False
for o, a in opts:
    # print help message for command line options
    if o in ('-a', '--ask'):
        print("\nUsing interactive (advanced) update with user input.\n")
        userInput = True


### Quits all running instances of BrewPi
def quitBrewPi(webPath):
    print("\nStopping running instances of BrewPi.")
    try:
        import BrewPiProcess
        allProcesses = BrewPiProcess.BrewPiProcesses()
        allProcesses.stopAll(webPath+"/do_not_run_brewpi")
    except:
        pass  # if we cannot stop running instances of the script, just continue. Might be a very old version

# remove do_not_run file
def startBrewPi(webPath):
    filePath = webPath+"/do_not_run_brewpi"
    if os.path.isfile(filePath):
        os.remove(filePath)


### calls updateToolsRepo.sh, which returns 0 if the brewpi-tools repo is up-to-date
def checkForUpdates():
    if os.path.exists(os.path.dirname(os.path.realpath(__file__)) + "/updateToolsRepo.sh"):
        try:
            print("Checking whether the update script is up to date.")
            subprocess.check_call(["sudo", "bash", os.path.dirname(os.path.realpath(__file__)) + "/updateToolsRepo.sh"],
                                  stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError:
            print("This script was not up-to-date and has been automatically updated.\nPlease re-run updater.py.")
            sys.exit(1)
    else:
        print ("The required file updateToolsRepo.sh was not found. This is likely to occur\n" + \
                "if you manually copied updater.py here.  Please run this from the original\n" + \
                "location you installed the brewpi-tools git repo and try again.\n")
        sys.exit(1)


### call installDependencies.sh, so commands are only defined in one place.
def runAfterUpdate(scriptDir):
    try:
        print("Installing dependencies, updating CRON and fixing file permissions.")
        subprocess.check_call(["sudo", "bash", scriptDir + "/utils/runAfterUpdate.sh"], stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError:
        print ("I tried to execute the runAfterUpdate.sh bash script, but an error occurred.\n" + \
               "Try running it from the command line in your <brewpi-script>/utils dir.\n")

### Stash any local repo changes
def stashChanges(repo):
    print ("\nYou have local changes in this repository, that are prevent a successful merge.\n" + \
           "These changes can be stashed to bring your repository back to its original\n" + \
           "state so we can merge.\n" + \
           "Your changes are not lost, but saved on the stash.  You can (optionally) get\n" + \
           "them back later with 'git stash pop'.")
    choice = raw_input("Would you like to stash local changes? (Required to continue) [Y/n]: ")
    if any(choice == x for x in ["", "yes", "Yes", "YES", "yes", "y", "Y"]):
        print("Attempting to stash any changes.\n")
        try:
            repo.git.config('--get', 'user.name')
        except git.GitCommandError as e:
            print("Warning: No user name set for git, which is necessary to stash.")
            print("--> Please enter a global username for git on this system:")
            userName = raw_input()
            repo.git.config('--global', 'user.name', userName)
        try:
            repo.git.config('--get', 'user.email')
        except git.GitCommandError as e:
            print("Warning: No user e-mail address set for git, which is necessary to stash.")
            print("--> Please enter a global user e-mail address for git on this system: ")
            userEmail = raw_input()
            repo.git.config('--global', 'user.email', userEmail)
        try:
            resp = repo.git.stash()
            print("\n" + resp + "\n")
            print("Stash successful.")

            print("##################################################################")
            print("#Your local changes were in conflict with the last update of code.#")
            print("##################################################################")
            print("The conflict was:\n")
            print("-------------------------------------------------------")
            print(repo.git.stash("show", "--full-diff", "stash@{0}"))
            print("-------------------------------------------------------")
            print ("\nTo make merging possible, these changes were stashed.\n" + \
                   "To merge the changes back in, you can use 'git stash pop'.\n" + \
                   "Only do this if you really know what you are doing.  Your\n" + \
                   "changes might be incompatible with the update or could\n" + \
                   "cause a new merge conflict.")

            return True
        except git.GitCommandError as e:
            print(e)
            print("Unable to stash, don't want to overwrite your stuff, aborting this branch\nupdate.")
            return False
    else:
        print("Changes are not stashed, cannot continue without stashing. Aborting update.")
        return False


### Function used to stash local changes and update a branch passed to it
def update_repo(repo, remote, branch):
    stashed = False
    repo.git.fetch(remote, branch)
    try:
        print(repo.git.merge(remote + '/' + branch))
    except git.GitCommandError as e:
        print(e)
        if "Your local changes to the following files would be overwritten by merge" in str(e):
            stashed = stashChanges(repo)
            if not stashed:
                return False

        print("Trying to merge again.")
        try:
            print(repo.git.merge(remote + '/' + branch))
        except git.GitCommandError as e:
            print(e)
            print("Sorry, cannot automatically stash/discard local changes. Aborting.")
            return False


    print(branch + " updated.")
    return True


### Function to be used to check most recent commit date on the repo passed to it
def check_repo(repo):
    updated = False
    localBranch = repo.active_branch.name
    newBranch = localBranch
    remoteRef = None

    print("You are on branch " + localBranch)

    if not localBranch in ["master", "legacy"] and not userInput:
        print("Your checked out branch is not master, our stable release branch.")
        print("It is highly recommended that you switch to the stable master branch.")
        choice = raw_input("Would you like to do that? [Y/n]: ")
        if any(choice == x for x in ["", "yes", "Yes", "YES", "yes", "y", "Y"]):
            print("Switching branch to master.")
            newBranch = "master"


    ### Get available remotes
    remote = repo.remotes[0] # default to first found remote
    if userInput and len(repo.remotes) > 1:
        print("Multiple remotes found in " + repo.working_tree_dir)
        for i, rem in enumerate(repo.remotes):
            print("[%d] %s" % (i, rem.name))
        print("[" + str(len(repo.remotes)) + "] Skip updating this repository.")
        while 1:
            try:
                choice = raw_input("From which remote do you want to update? [%s]:  " % remote)
                if choice == "":
                    print("Updating from default remote %s." % remote)
                    break
                else:
                    selection = int(choice)
            except ValueError:
                print("Use the number!")
                continue
            if selection == len(repo.remotes):
                return False # choice = skip updating
            try:
                remote = repo.remotes[selection]
            except IndexError:
                print("Not a valid selection. Try again.")
                continue
            break

    repo.git.fetch(remote.name, "--prune")

    ### Get available branches on the remote
    try:
        remoteBranches = remote.refs
    except AssertionError as e:
        print("Failed to get references from remote: " + repr(e))
        print("Aborting update of " + repo.working_tree_dir)
        return False

    if userInput:
        print("\nAvailable branches on the remote '%s' for %s: " % (remote.name, repo.working_tree_dir))

    for i, ref in enumerate(remoteBranches):
        remoteRefName = "%s" % ref
        if "/HEAD" in remoteRefName:
            remoteBranches.pop(i)  # remove HEAD from list

    for i, ref in enumerate(remoteBranches):
        remoteRefName = "%s" % ref
        remoteBranchName = remoteRefName.replace(remote.name + "/", "")
        if remoteBranchName == newBranch:
            remoteRef = ref
        if userInput:
            print("[%d] %s" % (i, remoteBranchName))

    if userInput:
        print("[" + str(len(remoteBranches)) + "] Skip updating this repository.")

        while 1:
            try:
                choice = raw_input("Enter the number of the branch you wish to update [%s]: " % localBranch)
                if choice == "":
                    print("Keeping current branch %s" % localBranch)
                    break
                else:
                    selection = int(choice)
            except ValueError:
                print("Please make a valid choice.")
                continue
            if selection == len(remoteBranches):
                return False # choice = skip updating
            try:
                remoteRef = remoteBranches[selection]
            except IndexError:
                print("Not a valid selection. Try again.")
                continue
            break

    if remoteRef is None:
        print("Could not find branch selected branch on remote. Aborting.")
        return False

    remoteBranch = ("%s" % remoteRef).replace(remote.name + "/", "")

    checkedOutDifferentBranch = False
    if localBranch != remoteBranch:
        print("The " + remoteBranch + " branch is not your currently active branch - ")
        choice = raw_input("would you like me to check it out for you now? (Required to continue) [Y/n]: ")
        if any(choice == x for x in ["", "yes", "Yes", "YES", "yes", "y", "Y"]):
            stashedForCheckout = False
            while True:
                try:
                    if remoteBranch in repo.branches:
                        print(repo.git.checkout(remoteBranch))
                    else:
                        print(repo.git.checkout(remoteRef, b=remoteBranch))
                    print("Successfully switched to " + remoteBranch)
                    checkedOutDifferentBranch = True
                    break
                except git.GitCommandError as e:
                    if not stashedForCheckout:
                        if "Your local changes to the following files would be overwritten by checkout" in str(e):
                            print("Local changes exist in your current files that need to be stashed to continue.")
                            if not stashChanges(repo):
                                return
                            print("Trying to checkout again.")
                            stashedForCheckout = True # keep track of stashing, so it is only tried once
                            continue # retry after stash
                    else:
                        print(e)
                        print("I was unable to checkout. Please try it manually from the command line and\nre-run this tool.")
                        return False
        else:
            print("Skipping this branch.")
            return False

    if remoteRef is None:
        print("Error: Could not determine which remote reference to use, aborting.")
        return False

    localDate = repo.head.commit.committed_date
    localDateString = strftime("%a, %d %b %Y %H:%M:%S", localtime(localDate))
    localSha = repo.head.commit.hexsha
    localName = repo.working_tree_dir

    remoteDate = remoteRef.commit.committed_date
    remoteDateString = strftime("%a, %d %b %Y %H:%M:%S", localtime(remoteDate))
    remoteSha = remoteRef.commit.hexsha
    remoteName = remoteRef.name
    alignLength = max(len(localName), len(remoteName))

    print("The latest commit in " + localName.ljust(alignLength) + " is " + localSha + " on " + localDateString)
    print("The latest commit on " + remoteName.ljust(alignLength) + " is " + remoteSha + " on " + remoteDateString)

    if localDate < remoteDate:
        print("*** Updates are available ****")
        choice = raw_input("Would you like to update " + localName + " from " + remoteName + " [Y/n]: ")
        if any(choice == x for x in ["", "yes", "Yes", "YES", "yes", "y", "Y"]):
            updated = update_repo(repo, remote.name, remoteBranch)
    else:
        print("Your local version of " + localName + " is up to date.")
    return updated or checkedOutDifferentBranch


print("######################################################")
print("####                                              ####")
print("####        Welcome to the BrewPi Updater!        ####")
print("####                                              ####")
print("######################################################")
print("")

if os.geteuid() != 0:
    print("This update script should be run as root.")
    print("Try running it again with sudo, exiting.")
    exit(1)

checkForUpdates()
print("")

print("It is not recommended to update during a brew.\n" \
      "If you are actively logging a brew we recommend canceling the the update with ctrl-c.")

changed = False
scriptPath = '/home/brewpi'

# set a first guess for the web path. If files are not found here, the user is asked later
webPath = '/var/www/html' # default since Jessie
if not os.path.isdir('/var/www/html'):
    webPath = '/var/www' # earlier default www dir

print("\n\n*** Updating BrewPi script repository ***")

for i in range(3):
    correctRepo = False
    try:
        scriptRepo = git.Repo(scriptPath)
        gitConfig = open(scriptPath + '/.git/config', 'r')
        for line in gitConfig:
            if "url =" in line and "brewpi-script" in line:
                correctRepo = True
                break
        gitConfig.close()
    except git.NoSuchPathError:
        print("The path '%s' does not exist" % scriptPath)
        scriptPath = raw_input("To which path did you install the BrewPi python scripts?  ")
        continue
    except (git.InvalidGitRepositoryError, IOError):
        print("The path '%s' does not seem to be a valid git repository." % scriptPath)
        scriptPath = raw_input("To which path did you install the BrewPi python scripts?  ")
        continue

    if not correctRepo:
        print("The path '%s' does not seem to be the BrewPi python script git repository." % scriptPath)
        scriptPath = raw_input("To which path did you install the BrewPi python scripts?  ")
        continue
    ### Add BrewPi repo into the sys path, so we can import those modules as needed later
    sys.path.insert(0, scriptPath)
    quitBrewPi(webPath) # exit running instances of BrewPi
    changed = check_repo(scriptRepo) or changed
    break
else:
    print("Maximum number of tries reached, updating BrewPi scripts aborted.")

print("\n\n*** Updating BrewPi web interface repository ***")
for i in range(3):
    correctRepo = False
    try:
        webRepo = git.Repo(webPath)
        gitConfig = open(webPath + '/.git/config', 'r')
        for line in gitConfig:
            if "url =" in line and "brewpi-www" in line:
                correctRepo = True
                break
        gitConfig.close()
    except git.NoSuchPathError:
        print("The path '%s' does not exist" % webPath)
        webPath = raw_input("To which path did you install the BrewPi web application?  ")
        continue
    except (git.InvalidGitRepositoryError, IOError):
        print("The path '%s' does not seem to be a valid git repository." % webPath)
        webPath = raw_input("To which path did you install the BrewPi web application?  ")
        continue
    if not correctRepo:
        print("The path '%s' does not seem to be the BrewPi web interface git repository." % webPath)
        webPath = raw_input("To which path did you install the BrewPi web application?  ")
        continue
    changed = check_repo(webRepo) or changed
    break
else:
    print("Maximum number of tries reached, updating BrewPi web interface aborted.")

if changed:
    print("\nOne our more repositories were updated, running runAfterUpdate.sh from\n%s/utils." % scriptPath)
    runAfterUpdate(scriptPath)
else:
    print("\nNo changes were made, skipping runAfterUpdate.sh.")
    print("If you encounter problems, you can start it manually with:")
    print("'sudo %s/utils/runAfterUpdate.sh'" % scriptPath)

print("\nThe update script can automatically check your controller firmware version\n" + \
      "and program it with the latest release on GitHub, would you like to do this")
choice = raw_input("now? [Y/n]: ")
if any(choice == x for x in ["", "yes", "Yes", "YES", "yes", "y", "Y"]):
    # start as a separate python process, or it will not use the updated modules
    updateScript = os.path.join(scriptPath, 'utils', 'updateFirmware.py')
    if userInput:
        p = subprocess.Popen("python {0} --beta".format(updateScript), shell=True)
    else:
        p = subprocess.Popen("python {0} --silent".format(updateScript), shell=True)
    p.wait()
    result = p.returncode
    if(result == 0):
        print("Firmware update complete.")
else:
    print("Skipping controller update.")

startBrewPi(webPath)
print("\n\n*** Done updating BrewPi ***\n")
print("Please refresh your browser with ctrl-F5 to make sure it is not showing an\nold cached version.")

