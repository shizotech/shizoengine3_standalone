
I want to detangle the modules / responsibilities / code:

workspace class (takes in tasks, spawns workspace agent on task, holds task scheduler, executes scheduled tasks)

node class (handles all workspace classes, can take in task and route to workspace, stores information about available workspaces in userspace and loads and instantiates workspace classes for all)

webui and telegram router w/ receptionist are extra connectors which connect to the node class, they just handle communication but no direct task data

Also next to the session the endpoint is also saved in .megamind or .agentspace with the API secret token, which is completely stupid.
There is no need to save the endpoint with each conversation at all, use the default config always (or the worker config passed via command line)