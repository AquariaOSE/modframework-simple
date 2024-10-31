This documents the circuit network feature -- the "cn" nodes scattered around the showcase map.
If you are confused, take a look at how the various networks on the showcase map are set up,
then come back to this document.

The idea behind the CN is that you can automate basic things without writing specialized scripts,
purely by placing nodes on the map and setting their label text.

The original inspiration was this: https://wiki.factorio.com/Circuit_network
So if you've played factorio and used its circuit networks, you know the concept already.

First, the layout rules:
-------------------------

A set of "cn" nodes that connect form a network. A "cn" node is a node whose label
starts with "cn", a space, and then arbitrary text.
(Like the "seting" node that's used to control the contents of a song plant)
Two nodes connect when a tail point of a node is placed inside the area of another node.
To visualize:

    v---- The center point is here
 +-----+
 |     |
 |  O------O----O------O
 |     |
 +-----+   <-----------> - This is the tail (the center point doesn't count)

 <-----> - This is the area

These two nodes are NOT connected:

 +-------------+
 |             |
 |             |
 |    +------------+
 |    | O      |   |
 |    |        |   |
 |    |      O |   |
 |    |        |   |
 +-------------+   |
      +------------+

Even though their areas overlap, their tails (not drawn) do not;
the centerpoints don't count, and so these two nodes will form separate networks.
(This is intentional so that you can span multiple separate networks over a single entity, for example)

How you connect the individual nodes doesn't matter. Or which node's tail
is inside of which node's area. All that matters is that they connect somehow
and they will be lumped together into a network.


Variables and values:
----------------------

Imagine a node with the following label:

    cn a=5

That defines a variable a=5 (constant) for the network.
If you add another node to that network, with this label:

   cn a=1 b=2

Then evaluating the complete network will give two variables,
a=6 and b=2.
Why a=6? Because when variables are assigned multiple times, their values are added.

When a node reads a variable, the value is always evaluated over the entire network.
If a variable is not present or not set, it reads as 0.

Also, all values are integers. That means only whole numbers.
Values are always rounded down, via Lua's math.floor() function.

Variable names can be any length, but for brevity in this document all variable names
are only one character.


Conditions:
-----------

It is possible to conditionally evaluate variables and have something happen if a condition is true.
For example this:

    cn opendoor x

Will open a door when x is true (and close it otherwise).

When is something "true"?
-> When it's strictly larger than zero, ie. 1 and up.

So the same could be written as:

    cn opendoor x>0


Parameters:
-----------

It's always "cn" followed by some more stuff.
Usually parameters are space-separated, but if parentheses '(' and ')' are present
then spaces inside of () will be skipped.
So this label
    cn opendoor x > 1
will be split incorrectly since opendoor expects only one parameter.
When put in (), this is fine:
    cn opendoor (x > 1)

In the same way, you can define a complex expression:
    cn x=m*(a + b*2)
which will be parsed properly because the spaces inside of () don't split the expression.


Function list:
--------------

Definitions:

VAR is a single variable name, eg. 'x'
EXPR is an expression, eg. '42', 'a>5', '(x+3)*4'
COND is a condition; effectively EXPR but it's only checked if it's true (ie. the result of the expression is > 0)
ASSIGN is an assignment (VAR followed by '=' followed by EXPR), eg. 'x=a>5'

Anything in [] is optional.
'...' means any number of
So 'EXPR [EXPR...]' means at least one expr but more may follow


The simplest node is "cn" without parameters. That can be used to connect other cn nodes together
but has no function on its own.

A pure assignment can be done with "cn ASSIGN [ASSIGN...]"
That specifies variables and assigns values. Multiple assignments can be done in a single node.
Some examples:
    cn a=5
    cn a=1 b=a+4
    cn x=5<4 y=a>7
    cn x=(a<3 or a>6)    <-- note the space vs () rules here


The following functions are available:

cn playerin VAR

  Sets VAR to 1 if Naija (ie. the player) is inside of the node, 0 otherwise.

cn count [EXPR...]

  With this node you can count entities inside of the node and assign
  the number to a variable, ie. 'cn count r=rockhead s=songspore' will look
  for songspores and rockheads and assign their counts to the variables r and s.
  For this node each EXPR is handled specially; the variables referenced in EXPR
  are not ACTUAL variables but entity counts.
  You can also do something like 'cn count c=rockhead+songspore' to count both and add their
  counts together into a single variable. You can't use variables from the rest
  of the network in a 'cn count' node; all it sees are its entities.

cn countall

  Counts all entities inside of the node and exports their numbers as variables.

cn opendoor COND

  Opens the nearest door-like entity that is inside of the node when COND is true.
  Beware: For sliding doors like energydoor, put the node over the entire sliding area
          of the door, otherwise the node might lose the door and stop working.

cn readdoor VAR

  Reads status of the nearest door-like entity that is inside of the node
  and puts the value into VAR. The status is one of:
    0 : door is fully closed
    1 : door is closing
    2 : door is opening
    3 : door is fully open


cn latch ASSIGN COND [timeout]

  A latch node evaluates ASSIGN only when COND is true, and keeps the last
  value it has seen when COND is false.
  You can optionally specify a timeout (which is an EXPR) after which the
  stored value resets back to 0. The timer starts ticking when COND is false
  but is reset when it becomes true again before expiry.
  The timeout EXPR is evaluated whenever COND is true.

  Examples:
    cn latch a=x x      <-- This stores the value of x whenever x is > 0, and keeps it
    cn latch a=x x 3    <-- Same, but the value is only stored for 3 seconds, then flips back to 0
    cn latch a=x+1 c>4 t  <-- This fetches the timeout from the variable t whenever c>4 is true

cn save ASSIGN COND

  Similar to latch, but stores the value into the save file and across map loads.
  If you move the node or change its label, the saved value is lost.
  (There's no timeout)

cn countdown ASSIGN COND [speed]

  Performs ASSIGN whenever COND is true and stores the value.
  When COND becomes false, tick the value towards 0.
  The default speed is 1 (ie. one tick per second), higher ticks faster. Accepts non-integers.
  Speed must be a number and can't be an expression.
  (Despire the name, this can also be used to tick negative values up towards 0)

cn countup ASSIGN COND [speed]

  While COND is true, perform ASSIGN and increment an internal counter.
  When COND is false, this is always 0, ASSIGN is ignored, and the counter is reset to 0.
  The default speed is 1 (ie. one tick per second), higher ticks faster. Aceepts non-integers.
  Example:
    cn countup x=3 a>0   <-- Whenever a>0, set x=3, then keep increasing x, until a>0 is no longer true, then reset.

cn maptime VAR [multiplier]

  Puts the map elapsed time into VAR.
  The time is reset to 0 on every map load, then the fade-in starts, and by the time this is 1
  the map is fully visible.
  The multiplier can be a number or EXPR, if it's an EXPR it's continuously evaluated.
  The actually returned number is the sum of all frame tick timediffs times the multiplier at any given tick.
  The default multiplier is 1.

cn readswitch VAR

  Like readdoor, reads the status of the nearest switch-like entity inside of the node
  and puts the result into VAR. 1 if on, 0 if off.

cn setswitch COND [enableCOND]

  Sets the nearest switch-like entity inside of the node to on (1) or off (0),
  ie. to the result of COND.
  You can optionally specify an enable condition, if present then the node is only
  active while enableCOND is true, and doesn't touch the switch if it's false.


More to come!

(See src/aqmodlib/circuitnetwork-modules.lua for the implementation; feel free to add your own)

If you need a feature that's missing or something is unclear, shoot me a message!

-- fgenesis
