# 1. SDK primeiro (é dependência dos outros)
cd agent-sdk
uv sync --group dev
cd ..

# 2. Platform-core (depende do agent-sdk)
cd platform-core
uv sync --group dev
cd ..

# 3. Agente (depende do agent-sdk)
cd google-calendar-agent
uv sync --group dev
cd ..