from fastapi import FastAPI
import yaml

with open("apc.yaml", "r") as f:
    config = yaml.safe_load(f)

# Validate config structure
if "regions" not in config:
    raise ValueError("Config must contain 'regions' key")
if not isinstance(config["regions"], dict):
    raise ValueError("'regions' must be a dictionary")
for region_id, region_data in config["regions"].items():
    if not isinstance(region_data, dict):
        raise ValueError(f"Region '{region_id}' must be a dictionary")
    for service_type, services in region_data.items():
        if not isinstance(services, list):
            raise ValueError(f"Service type '{service_type}' in region '{region_id}' must be a list")
        for service in services:
            if "name" not in service or "address" not in service:
                raise ValueError(f"Each service in region '{region_id}' and service type '{service_type}' must contain 'name' and 'address' keys")
            if not isinstance(service["name"], str) or not isinstance(service["address"], str):
                raise ValueError(f"'name' and 'address' in region '{region_id}' and service type '{service_type}' must be strings")

app = FastAPI()


@app.get("/regions/{region_id}")
def read_region(region_id: str, serviceType: str | None = None):
    region = config["regions"].get(region_id)
    if region is None:
        return {"error": "Region not found"}
    if serviceType:
        region = region.get(serviceType)
        if region is None:
            return {"error": "Service type not found"}
    return region
