Here's a quick & dirty starter pack with a large library of extra scripting functions.

(Why "modframework-simple"? Because i might eventually release an "advanced" mod framework
that is much more complicated but also much more powerful.)

If you're just starting out, you can use this like the aquariatemplate mod as a starting point for your own.

If you have already started working on a mod and want to merge this in,
copy these files/directories to your mod, keeping the directory structure:

- src/
- mod-config.lua
- scripts/node_logic.lua

These are the mandatory files.
(Please modify mod-config.lua to your needs; by default all debug stuff is enabled
and you'll probably want to disable that when you release for the general public.
It also teaches some songs right from the start, remove that if you don't want it)

Optionally, grab any other file from scripts/ you may find useful.
Some are useful scripts from the base game that have been slightly extended,
to fix bugs or add features. Unless indicated, they depend on aqmodlib
and won't work without the extra library functions.
(See comments at the top in each file.)


When you make a new map, base it off maps/template.xml.
This map already comes with a "logic" node, which pulls in all of the new scripting stuff.
It acts as a plugin container that can be extended with extra functionality that need to
be present in the background at all times. There's a selection of plugins to get started.
Even if you don't need them I recommend to keep them.

You MUST make sure that EXACTLY ONE "logic" node exists on all of your maps.
Not zero. Not two. Definitely not three. ONE logic node, and only one.
(The position/size is not important. It just needs to exist.)

maps/template.xml has it already, in the upper left corner. If you use this as a template
to create your own maps from, you're good.

But if you already have maps made that don't have this node, you need to add it.

I recommend you open each of your map xml files in a text editor
and add the XML tag by hand. This is the snippet:

<Path name="logic">
    <Node pos="-20 -20" rect="64 64" shape="0" />
</Path>

Add this to the top of each of your map files.

The reason why I recommend to do this by hand and not just add it in the editor
is because this is the only way to ensure that a node is at the top --
the editor adds new nodes to the bottom of the list.
The scripting framework needs to be loaded as early as possible,
and since the game initializes nodes in the order they appear in the map file,
this is the easiest way to ensure that the framework is loaded early.

If adding the node in the editor is easier for you, do that,
and it might just end up working fine.
But keep this in mind in case problems come up about script functions
or constants not being present when they should be.


Further Aquaria and modding resources are available at:

https://github.com/AquariaOSE/
