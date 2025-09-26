# Jupyter Lab Configuration
c = get_config()

# Security settings
c.ServerApp.token = 'portfolio-rag-2025'
c.ServerApp.password = ''
c.ServerApp.open_browser = False
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.allow_root = True

# CORS settings for API access
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_credentials = True

# Disable authentication for local development
c.ServerApp.disable_check_xsrf = True