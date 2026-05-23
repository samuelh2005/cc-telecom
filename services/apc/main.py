from fastapi import FastAPI
import yaml

with open("apc.yaml", "r") as f:
    config = yaml.safe_load(f)

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
