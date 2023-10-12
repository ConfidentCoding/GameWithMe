# GameWithMe Portal Roblox Web API SDK v2.0

This is a Roblox Lua client for the GameWithMe Portal's web API. It is used by the [GameWithMe Portal Roblox Connect Module](https://github.com/SuperAwesomeLTD/gwm-portal-roblox-connect-module).

## Installation

1. Open the Experience in Roblox Studio.
2. Under Home &rarr; Game Settings &rarr; Security, enable **Allow HTTP Requests** if it is not already on.
3. Insert the model file into the place using one of the following methods:
   - Take the Model on Roblox.com, and insert it using the [Toolbox](https://developer.roblox.com/en-us/resources/studio/Toolbox).
   - Download the model file from the releases section, then right-click ServerScriptService and select **Insert from File...**
4. Using the [Explorer](https://developer.roblox.com/en-us/resources/studio/Explorer), ensure the module is a child of [ServerScriptService](https://developer.roblox.com/en-us/api-reference/class/ServerScriptService).

## Dependencies

The module itself includes all dependencies, which is only [roblox-lua-promise](https://github.com/evaera/roblox-lua-promise).

## Development

- Built using [Rojo](https://github.com/rojo-rbx/rojo) 6. The main project file is [default.project.json](default.project.json).
- [selene](https://github.com/Kampfkarren/selene) is used as a linter. The files [selene.toml](selene.toml) and [roblox.toml](roblox.toml) are used by this.

## Testing

1. Run `make test`/`make test-serve` to build/sync [test.project.json](test.project.json) using Rojo.
2. To ensure the API can load the base URL and main token for testing, do one of the following:
   - Manually set the `DebugBaseUrl` and `DebugMainToken` attributes on the `GameWithMeAPI.Singleton` ModuleScript from within Studio.
   - Publish the place to a universe owned by the [SuperAwesomeGaming](https://www.roblox.com/groups/12478861/SuperAwesomeGaming) group, ideally the [PJ Staging](https://www.roblox.com/games/8785723516) universe under the place [GameWithMe Portal Roblox Web API SDK (Test)](https://www.roblox.com/games/9290950551).
3. Press Run (F8) in Studio.
4. Inspect the Output window for test results.
