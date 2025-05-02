from fastapi import FastAPI, Request
from mangum import Mangum
import logging
import os

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Get stage from environment variable
STAGE = os.getenv("STAGE", "dev")

app = FastAPI()

@app.get("/")
async def read_root(request: Request):
    logger.info(f"Root endpoint called. Path: {request.url.path}, Method: {request.method}")
    return {"Hello": "World"}

@app.get("/hello")
async def read_hello(request: Request):
    logger.info(f"Hello endpoint called. Path: {request.url.path}, Method: {request.method}")
    return {"message": "Hello from FastAPI on AWS Lambda!"}

# Create handler with custom base path
handler = Mangum(app, lifespan="off", api_gateway_base_path=f"/{STAGE}")