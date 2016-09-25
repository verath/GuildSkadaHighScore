# Version 1.0.7 (2016-09-25)

* Dropdowns in the gui are now sorted alphabetically.
* Spec names can now be used to filter parses.
* The table header row now says "dps" for dps and "hps" for hps, instead of "dps/hps" for both.

# Version 1.0.6

* Updated zone id for The Emerald Nightmare raid.

# Version 1.0.5

* Updated LibGroupInSpecT dependency.

# Version 1.0.4

* Added an action to remove ALL stored parses (found the in the settings: Interface->GuildSkadaHighScore).
* Made the addon track only the raids of the current expansion.
* Using blizzard's localization for difficulty names (the only noticeable difference should be that "LFR" is now "Looking For Raid").
* Some small performance improvements, via mikk's [FindGlobals](https://www.wowace.com/addons/findglobals/).
* Some minor code cleanup/reorganization.

# Version 1.0.3

**Note:** As of 1.0.3 Recount is no longer supported.

* Version bump for 7.0
* Added zone ids for legion raids (The Nighthold and The Emerald Nightmare)
* Fix incorrect item levels when using upgraded or heirloom items
* Change inspect module to be based on [LibGroupInSpecT](http://www.wowace.com/addons/libgroupinspect/), hopefully improving reliability of inspects
* Some changes to library handling to improve no-lib usage

# Version 1.0.2

* Version bump for 6.2.
* Added Hellfire Citadel to tracked raids. 


# Version 1.0.1

* Fix for lua error on login (Ticket #2).


# Version 1.0.0

* Version bump for patch 6.1


# Version 1.0.0-beta

* Added option (interface -> addons -> GuildSkadaHighScore) to remove old parses when the addon is enabled (usually when logging in).
* Fixed the report window not hiding when escape is pressed.
* Cleanup and minimizing of stored data.
* Cleanup of the code in general.