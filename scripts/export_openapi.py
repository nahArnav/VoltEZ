import json
import sys
import os

# Add services/api to PYTHONPATH so we can import the app
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../services/api"))

from app.main import app
from fastapi.openapi.utils import get_openapi

def export_openapi():
    # Extract the schema
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        openapi_version=app.openapi_version,
        description=app.description,
        routes=app.routes,
    )
    
    # Write it to docs/openapi.json
    output_path = os.path.join(os.path.dirname(__file__), "../docs/openapi.json")
    output_path = os.path.abspath(output_path)
    with open(output_path, "w") as f:
        json.dump(openapi_schema, f, indent=2)
        
    print(f"Successfully exported OpenAPI schema to {output_path}")

if __name__ == "__main__":
    export_openapi()
