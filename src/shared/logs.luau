--!native
--!strict
-- USAGE: lightreflector/shared/logs.luau
-- Log ids and URL for the Light Reflector debugger.

return {
	Ids = {
		FatalInit = "Init errored: %s",
		Fatal = "Fatal error: %s",
		AlreadyStarting = "Light Reflector is already starting",
		InvalidType = "Expected type %s; got '%s'",
		InvalidInstance = "Expected type %s; got '%s'",
		Info = "Info: %s",
		Warning = "Warning: %s",
		InitWarning = "Init warning: %s",
		RunContext = "Invalid RunContext: %s",
	},
	URL = "https://codeberg.org/project-roadwork/light-reflector.git"
}
