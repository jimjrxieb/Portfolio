# data-dev:mcp-adapter
# Exposes selected FastAPI routes as MCP tools so Jade (via an MCP client) can call them.
from fastapi import APIRouter

# Import your real routes/services
from app.routes.actions import router as actions_router   # action routes

# Create an MCP-aware router
router = APIRouter()
router.include_router(actions_router)

# Note: For full MCP integration, you'd use an MCP adapter library
# For now, this just exposes the routes normally via FastAPI
# The routes tagged "mcp" are intended to be MCP tools