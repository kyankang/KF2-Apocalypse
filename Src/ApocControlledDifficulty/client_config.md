# Client-side Configuration

The following options live in the following **KFGame.ini** section:

```
[ControlledDifficulty.CD_PlayerController]
```

These options control preferences and visual tweaks that are
matters of individual choice.  These cannot be set or overridden
by a CD server.

Currently, these options can only be changed by editing KFGame.ini.
Some console commands to get and set them were added to a beta CD
build, but those commands appeared to lead to a rare,
nondeterministic engine crash, so those commands were not released.

### AlphaGlitter=[true|false]

False disables the red visual
particle effects associated with an albino alpha clot's AOE rally ability.
True leaves those effects just as they are in the vanilla game (default).

### ChatCharThreshold=[int]

When CD prints a message
to global chat which exceeds this many characters, the
message will only be printed to the console.  In the chat box, the single
line "(See Console)" will be printed in lieu of the actual message.
This defaults to 340, roughly as many characters as can fit in the chat
box without scrolling (though the true maximum depends on the
particular characters involved, because the font is not monospaced).

### ChatLineThreshold=[int]

When CD prints a message
to global chat which exceeds this many lines (measured by the number of
newlines it contains, not the number of automatically-wrapped lines), the
message will only be printed to the console.  In the chat box, the single
line "(See Console)" will be printed in lieu of the actual message.
This defaults to 7, the number of lines that can fit in the chat box
without scrolling.

### ClientLogging=[true|false]

Controls a few client-side
logging statements.  These are generally uninteresting except when debugging
CD's client-side chat message and console message handling.
