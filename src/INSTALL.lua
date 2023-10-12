return [[

	GitHub: /ConfidentCoding/GameWithMe

To install the GameWithMe Portal Roblox Connect module, ensure that the folder containing
this ModuleScript is a descendant of ServerScriptService, so that the Main script runs.
That's it! You should now test that the module works.

	Testing

This test process assumes you have installed the module as-is.

1. Test → Start (F7); note that Test → Play (F5) may have some issues (see "Chat Module" below)
2. Type "/gwm setup" in chat. The interface should open.
3. Type an arbitrary 6-character setup code and click submit.
4. The setup code should be rejected for not matching any event - if this is the case, things are working!
5. Publish the place and enter it from a live Roblox Server. Repeat from 2.

Read on for more details on the module and ensuring it works in your game.

	Entry Point & Single-Script Architecture

The entry point of this module is the Main script. If you use single-script architecture,
disable or remove it and call GameWithMeConnect:main() yourself.

	Chat Module

By default, opening the interface is done by typing "/gwm setup", this is controlled via TextChatCommand's using
the new TextChatService. If using chat is not an option, you should create another way for ANY ARBITRARY PLAYER to 
ask the server to call GameWithMeConnect:setupCodePrompt(player)

]]