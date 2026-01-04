import os

c.ServerApp.ip = "0.0.0.0"
c.ServerApp.port = int(os.environ.get("SVC_PORT", 8888))
c.ServerApp.base_url = os.environ.get("NB_PREFIX", "/")
c.ServerApp.open_browser = False
c.ServerApp.allow_remote_access = True

c.ServerApp.token = ""
c.ServerApp.password = ""
c.ServerApp.disable_check_xsrf = True
c.ServerApp.allow_origin = "*"

c.ServerApp.root_dir = os.environ.get("SERVE_DIR", "/home/jovyan")
c.ServerApp.terminado_settings = {"shell_command": ["/bin/bash"]}

