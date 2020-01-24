# Option Reference

CD's options (also known interchangeably as settings) can be configured three ways.

* Parameters to the `open` command in the client or server console
* Editing KFGame.ini on the client or PCServer-KFGame.ini on the server
* Chat commands (only a subset of settings can be modified this way)

#### Configuring CD via `open`

Whenever you invoke `open <map>?game=ControlledDifficulty.CD_Survival`,
you may append additional "?"-separated key-value pairs of CD setting
names and their values.

For example, to set CohortSize to 6 and SpawnPoll to 0.75 on Outpost:

`open KF-Outpost?game=ControlledDifficulty.CD_Survival?SpawnPoll=0.75?CohortSize=6` 

#### Configuring CD through INI files

Controlled Difficulty automatically saves its settings every time they
are modified.

On the client or in standalone solo mode, this file is usually

```
<My Documents>\My Games\KillingFloor2\KFGame\KFGame\Config\KFGame.ini
```

The exact path is subject to change from one Windows version to the next.

On the server, this file is usually

```
<Server Root>\KFGame\Config\PCServer-KFGame.ini
```

If these files are not writable, then CD cannot and will not write any
of its settings to them.

#### Configuring CD through Chat Commands

Most CD configuration settings may be viewed and changed at runtime by
typing a special string into the game's public chat.  For example,
to show the current value of MaxMonsters, type `!cdmaxmonsters` in chat.
To set it to 24, type `!cdmaxmonsters 24` in chat.

CD can automatically generate a list of every chat commands name,
accepted parameters (if any), and a short description of what it does.
Type `CDChatHelp` in the console (not in the chat window!) to see this
information.  Due to technical limitations, this command currently only
works in the solo console or console of a dedicated server (`admin
CDChatHelp`).  It might become executable on clients of a dedicated
server in a future release.

CD's chat commands are controlled by an authentication and authorization
system when CD is running on a dedicated server.  These options are 
listed in this file under the
[Chat Command Authorization](#chat-command-authorization) subsection.

For details about available Chat Commands and how they work, see 
[chat.md](chat.md).

### Spawn Intensity Settings

#### CohortSize

The maximum number of zeds that CD's SpawnManager may spawn simultaneously
(i.e. on one invocation of the SpawnManager's update function).

When CohortSize is positive, CD's spawnmanager spawns as many squads as
necessary until either CohortSize zeds have spawned on that attempt, the
MaxMonsters limit is reached, or the map's available spawnvolumes have been
filled. CD will use as many of the map's spawnvolumes as necessary to spawn
the cohort, iterating from most to least preferred by
spawnvolume-preference-score.  On larger maps (e.g. Outpost), this makes it
possible to spawn something like 64 zeds instantaneously.

For example, let's say CohortSize=12. Let's also say that no zeds are
currently alive, that MaxMonsters=20, and that the SpawnCycle dictates
squads with alternating sizes 4, 5, 4, 5, etc. When the spawnmanager next
wakes up, it will spawn the first squad of 4 zeds at the most-preferred
spawnvolume, the next squad of 5 zeds at the second-most-preferred
spawnvolume, and the first 3 of 4 zeds in the third squad at the
third-most-preferred spawnvolume. The 1 zed leftover from the final squad
goes into LeftoverSpawnSquad and becomes a new singleton squad that attempts
to spawn on the following spawnmanager wakeup, just like in vanilla KF2. All
three squads just described appear to spawn simultaneously from the player
point of view; a "spawnmanager wakeup" is effectively instantaneous to us.
Let's continue the example and consider the next spawnmanager wakeup. Assume
no zeds were killed.  We have 12 alive and MaxMonsters is 20. The single-zed
LeftoverSpawnSquad spawns at the most-preferred spawnvolume. Now we resume
the spawncycle at a squad of size 5.  This spawns at the
second-most-preferred spawnvolume. There are now 12 + 1 + 5 = 18 zeds alive.
The spawnmanager finishes this cohort by spawning 2 of the 4 zeds in the
next squad, putting the 2 other zeds that could not spawn into
LeftoverSpawnSquad. This cohort was only 1 + 5 + 2 = 8 zeds, not 12,
because we reached the MaxMonsters limit of 20.

If this is set to 0, then the cohort spawn logic is inactive, and the game
instead spawns one squad per invocation of the update function.  That
behavior (i.e.  when set to 0) is how unmodded KF2 works: the spawn manager
creates one squad per attempt, no matter how much headroom might exist under
the MaxMonsters limit, or how many eligible spawnvolumes might be available
to accomodate more squads.

#### MaxMonsters

The maximum monsters allowed on the map at one time.  In the vanilla game,
this is 16 when in NM_StandAlone and GetLivingPlayerCount() == 1.   The
vanilla game's default is 32 in any other case (such as when playing alone
on a dedicated server).

If this is set to a nonpositive value, then the vanilla behavior prevails.

If this is set to a positive value, then it is the number of maximum
monsters allowed on the map at one time.

#### SpawnMod

The forced spawn modifier, expressed as a float between 0 and 1.

1.0 is KFGameConductor's player-friendliest state.  0.75 is
KFGameConductor's player-hostile state.

Below 0.75 is spawn intensity unseen in the vanilla game.

Setting zero means the SpawnManager will try to spawn zeds every single time
it is awoken (SpawnPoll controls how often it is awoken).  It will
only fail to spawn zeds if either the MaxMonsters limit is reached, if the
entire wave's worth of zeds has already spawned, or if the map's spawn
volumes are so congested that new zeds physically cannot be spawned without
failing a collision check (zeds inside other zeds).

Setting zero nullifies any spawn interval multiplier built into the map.
It also nullifies the sine-wave delay system TWI built into vanilla KF2,
and any early wave or difficulty-related delays.  When this is zero, the
only timing variables that matter are SpawnMod, and, to a limited extent
during zed time, ZTSpawnSlowdown.

This does not affect SpawnPoll.  SP controls how often the
SpawnManager wakes up.  This setting influences whether the SpawnManager
does or does not attempt to spawn zeds when it wakes up (along with some
other factors, like early wave modifiers, the presence of a leftover spawn
squad, the map's baked in spawn interval modifier, and a sinewave mod that
TWI probably thought would lend some kind of natural "rhythm" to the wave).
Specifically, this goes into calculation of TimeUntilNextSpawn, which is a
bit like SpawnManager marking its calendar with the soonest possible next
spawntime.

#### SpawnPoll

The timer interval, in seconds, for CD's SpawnManager's update function.
The update function first checks several state variables to determine
whether to attempt to spawn more zeds.  If it determines that it should
spawn zeds, the function then starts placing squads on spawner and/or
spawnvolume entities.  In the unmodded game, this is hardcoded to one
second.

#### ZTSpawnMode

Controls how the spawn manager does (or doesn't) react to zed time.

"unmodded" makes it run as it does in the vanilla game.  This means that the
spawn manager wakeup timer is destroyed every time zed time starts or is
extended.  This can result in extremely long spawn lulls after zed time if
SpawnPoll is long (e.g. 20 seconds).

"clockwork" prevents the spawn manager wakeup timer from being destroyed
every time zed time starts.  "clockwork" also applies ZTSpawnSlowdown to the
spawn manager timer's dilation factor.   "clockwork" effectively makes the
spawn manager's timer run ZTSpawnSlowdown times slower than real time.  If
ZTSpawnSlowdown is 1, then the spawn manager's timer is immune to the
effects of zed time.  If ZTSpawnSlowdown is greater than 1, then the spawn
manager runs that many times slower than a real-world clock when zed time is
in effect.

#### ZTSpawnSlowdown

This option is only meaningful when ZTSpawnMode is set to clockwork.  If
ZTSpawnMode is not set to clockwork, then this option is effectively
ignored.

If ZTSpawnSlowdown is 1, then the timer is not dilated, which means that
the spawn manager continues to wakeup every SpawnPoll (in real
seconds).  This means zed time does not slow down or speed up spawns in real
terms at all.

When ZTSpawnSlowdown is greater than 1, the spawn manager wakeup timer is
dilated to make it run that many times slower than a real-world clock.
It takes floating point values.

For example, say ZTSpawnMode is set to clockwork, ZTSpawnSlowdown is set to
2, SpawnPoll is set to 5, and SpawnMod is set to 0.  The spawn manager
wakes up and spawns some zeds.  Zed Time starts one millisecond later.  Zed
Time lasts 4 real seconds.  The spawn manager perceives these 4 real seconds
as only 2 seconds due to ZTSpawnSlowdown=2.  Zed time ends.  An additional
3 seconds elapse in normal time, and the spawn manager wakes up again.  In
all, 7 seconds elapsed between spawn manager wakeups in this example.

### Zed Type and Spawn-Ordering Control

#### AlbinoCrawlers

Controls whether albino crawlers can spawn.

See AlbinoAlphas for details about exactly how this works.

#### AlbinoAlphas

Controls whether albino alphas can spawn.

true allows albino alphas to spawn normally. The meaning of "normally"
depends on the SpawnCycle.  If SpawnCycle=unmodded, the albino alphas spawn
by pure chance, the way TWI does it in vanilla KF2.  If SpawnCycle is not
unmodded, then albino alphas will spawn according to the SpawnCycle.  If the
configured SpawnCycle has no albino alphas, then none will spawn even if
this option is set to true.

false prevents albino alphas from spawning at all.  Even if the SpawnCycle
mandates albino alphas, they will not spawn when this is false.

#### AlbinoGorefasts

Controls whether albino gorefasts can spawn.

See AlbinoAlphas for details about exactly how this works.

#### Boss

Optionally controls which boss spawns, if and when the boss wave arrives.

"hans" or "volter": forces the hans boss to spawn if/when the boss wave
comes

"pat", "patty", "patriarch": forces the patriarch boss to spawn if/when the
boss wave comes

"random" or "unmodded": choose a random boss when the time comes (unmodded
game behavior)

#### FleshpoundRageSpawns

Controls whether fleshpounds and mini fleshpounds can spawn already enraged.

true allows fleshpounds and mini fleshpounds to spawn enraged.  When
SpawnCycle=unmodded, this happens randomly, with a chance that depends on
difficulty, just like in vanilla KF2.  If SpawnCycle is not unmodded, then
fleshpounds and mini fleshpounds spawn according to the SpawnCycle.  If the
configured SpawnCycle has no fleshpounds or mini fleshpounds designated to
spawn enraged (with a trailing ! character), then none will spawn even if
this option is set to true.

false prevents fleshpounds and mini fleshpounds from spawning enraged at.
Even if the SpawnCycle mandates a fleshpound or mini fleshpound that would
spawn enraged, when this is false, it spawns unenraged.

#### SpawnCycle

Says whether to use a SpawnCycle (and if so, which one).

"ini": read info about squads from config and use it to set spawn squads

"unmodded": unmodded game behavior

All other values are reserved for current and future preset names.  Type
CDSpawnPresets to see available preset names.


### Fakes Settings


#### WaveSizeFakes

Increase zed count (but not hp) as though this many additional players were
present.  The game normally increases dosh rewards for each zed at
numplayers >= 3, and faking players this way does the same.  You can always
refrain from buying if you want an extra challenge, but if the mod denied
you that bonus dosh, it could end up being gamebreaking for some runs.  In
short, WaveSizeFakes increases both your budget and the zed count in each
wave.

#### FakesMode

Controls how the values of the WaveSizeFakes, BossHPFakes,
FleshpoundHPFakes, ScrakeHPFakes, and TrashHPFakes settings interact with
the human player count.

If set to "add_with_humans", then the values of various fake options are
added to the human player count value.  For example, playing solo long with
WaveSizeFakes=1 results in the first wave having 85 zeds.

If set to "ignore_humans", then only the value of a specific fakes option is
considered in its context, and the human player count value is ignored.  For
example, setting "ignore_humans" and WaveSizeFakes=2 is equivalent to
setting "add_with_humans" and playing solo with WaveSizeFakes=1.

If this is set to "ignore_humans" and any fake option is set to zero, then
that option is treated as though it had been set to one instead.  

#### BossHPFakes

The fakes modifier applied when scaling boss head and body health.

This is affected by FakesMode.

#### FleshpoundHPFakes

The fakes modifier applied when scaling fleshpound head and body health.

This is affected by FakesMode.

#### ScrakeHPFakes

The fakes modifier applied when scaling scrake head and body health.

This is affected by FakesMode.

#### TrashHPFakes

The fakes modifier applied when scaling trash zed head and body health.  The
trash HP scaling algorithm is a bit screwy compared to the other zed HP
scaling algorithms, and this parameter only generally matters when the net
count exceeds 6.

"Trash" in this context means any zed that is not a boss, a scrake, or a
fleshpound.

This is affected by FakesMode.


### Chat Command Authorization


#### AuthorizedUsers

Defines users always allowed to run any chat command.  This is an array
option.  It can appear on as many lines as you wish.  This is only consulted
when the game is running in server mode.  If the game is running in
standalone mode ("solo"), then the player is always authorized to run any
command, regardless of AuthorizedUsers.

Each AuthorizedUsers line specifies a steamid (in STEAMID2 format) and a
comment.  The comment can be whatever you like.  It's there just to make the
list more manageable.  You might want to put the player's nickname in there
and the date added, for example, but you can put anything in the comment
field that you want.  CD does not read the comment.

These two values are organized in a struct with the following form:

```
  (SteamID="STEAM_0:0:1234567",Comment="Mr Elusive Jan 31 2017")
```

There are many ways to find out a steamid.  Here's one tool that takes the
name or URL of a steam account, then gives the ID for that account:

```
  http://steamidfinder.com (not my website or affiliated with CD)
```

On steamidfinder.com, you want to copy the field called "SteamID" into
AuthorizedUsers.

Here's a sample INI snippet would authorize CD's author and Gabe Newell.

```
  [ControlledDifficulty.CD_Survival]
  DefaultAuthLevel=CDAUTH_READ
  AuthorizedUsers=(SteamID="STEAM_0:0:3691909",Comment="blackout")
  AuthorizedUsers=(SteamID="STEAM_0:0:11101",Comment="gabe newell")
```

#### DefaultAuthLevel

Controls the chat command authorization given to users who are connected to
a server and whose SteamID is not in the AuthorizedUsers array.  For the
rest of this section, we will call these users "anonymous users".

"CDAUTH_READ" means that anonymous users can run any CD chat command that
does not modify the configuration.  This lets players inspect the current
configuration but not change it.

"CDAUTH_WRITE" means that anonymous users can run any CD chat command.
CDAUTH_WRITE effectively makes AuthorizedUsers superfluous, since there is
no effective difference in chat command authority between AuthorizedUsers
and anonymous users with CDAUTH_WRITE.


### Miscellaneous Settings


#### TraderTime

The trader time, in seconds.  if this is zero or negative, its value is
totally ignored, and the difficulty's standard trader time is used instead.

#### WeaponTimeout

Time, in seconds, that dropped weapons remain on the ground before
disappearing.  This must be either a valid integer in string form, or the
string "max".

If set to a negative value, then the game's builtin default value is not
modified.  At the time I wrote this comment, the game's default was 300
seconds (5 minutes), but that could change; setting this to -1 will use
whatever TWI chose as the default, even if they change the default in future
patches.  If set to a positive value, it overrides the TWI default.  All
dropped weapons will remain on the ground for as many seconds as this
variable's value, regardless of whether the weapon was dropped by a dying
player or a live player who pressed his dropweapon key.

If set to zero, CD behaves as though it had been set to 1.

If set to "max", the value 2^31 - 1 is used.

#### ZedsTeleportCloser

Controls whether zeds are allowed to teleport around the map in an effort to
move them closer to human players.  This teleporting is unconditionally
enabled in the vanilla game.

true allows zeds to teleport in exactly the same way they do in the
vanilla game.

false prevents zeds from teleporting closer to players.  A zed can still
teleport if it becomes convinced that it is stuck.  Furthermore, this option
does not affect the way incoming zed squads or cohorts choose spawnpoints,
which means that brand new zeds can still spawn around corners, surrounding
doorways, etc as the team kites.  These "in-your-face" spawns can look quite
a bit like zeds teleporting.  CD has no way to alter that "in-your-face"
spawn behavior (yet).

#### bLogControlledDifficulty

true enables additional CD-specific logging output at runtime.  This option
is one of the earliest added to CD, before a naming convention was established,
and its unusual name is retained today for backwards-compatibility.

# Renamed Options

Most of CD's options remain unchanged in both name and function after introduction.
There are, however, some exceptions.

The FakePlayers option was part of CD at inception.  This option only affected the
number of zeds in the wave, not the HP of zeds.  Options to scale zed HP were added
to CD later.  These HP scaling options were denominated in the same "imaginary friend"
units as FakePlayers, but their names were different:
BossFP, FleshpoundFP, ScrakeFP, and TrashFP.
Some players were understandably confused about how these options did or did not
interact with one another.  They were all independent from each other; for instance,
increasing FakePlayers would not affect zed HP health, and increasing TrashFP would
not change the number of zeds in a wave.

Adding to the confusion, CD acquired an option called FakePlayersMode.  This affected
how all of the preceding options interact with the human player count.  This option's
name was misleading: it intentionally affected both FakePlayers and the four HP
scaling options, even though the name suggests that it would only affect FakePlayers.

Altogether, the result of this nomenclature was widespread confusion.  These options
evolved one piece at a time, rather than being designed as a cohesive unit.

In an attempt to rationalize these options and reduce future confusion, these options
were mass-renamed in CD's July 29 2017 release.
The option functions remain unchanged.  Only their names have changed.
The following table shows a correspondence between old and new option names.

New Name | Old Name
-------- | --------
WaveSizeFakes | FakePlayers
BossHPFakes | BossFP
FleshpoundHPFakes | FleshpoundFP
ScrakeHPFakes | ScrakeFP
TrashHPFakes | TrashFP
FakesMode=add_with_humans or ignore_humans | FakePlayersMode=add or replace

This renaming scheme extends to any dynamic option tables that might have been
defined in KFGame.ini.  For example, a config that had `FakePlayersDefs` lines
before this change should replace the string `FakePlayersDefs` with
`WaveSizeFakesDefs`.  It also extends to chat commands and their shorthands.
For example, `!cdfakeplayers` and `!cdfp` are no longer defined.
`!cdwavesizefakes` and `!cdwsf` are available instead.

Configuration migration must be done by hand.  CD does not maintain any backwards-
compatibility with the old option names.  I realize this is a substantial nuisance,
but the cost of adding and debugging a backwards-compat config layer had to be
weighed against other things I could potentially do in CD.  All of the config options
function the same as before, so if you do have a config you wish to migrate, it
can be done with text search-and-replace on option names and values of 
FakesMode/FakePlayersMode, according to the table above.  The resulting config
will work the same as it did before the rename.
