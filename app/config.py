import os
from pathlib import Path
from dotenv import load_dotenv

# Define base directory of the project
BASE_DIR = Path(__file__).resolve().parent.parent

# Locate the active environment files: secrets/.env or root .env
secrets_env_path = BASE_DIR / "secrets" / ".env"
root_env_path = BASE_DIR / ".env"

if secrets_env_path.exists():
    load_dotenv(dotenv_path=secrets_env_path)
elif root_env_path.exists():
    load_dotenv(dotenv_path=root_env_path)
else:
    load_dotenv()  # Fallback to standard environment lookup

# Port to bind the FastAPI app
PORT = int(os.getenv("PORT", 8080))

# GCP Config
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID", "devops-project")
GCP_REGION = os.getenv("GCP_REGION", "us-central1")
GCP_ZONE = os.getenv("GCP_ZONE", "us-central1-a")

# GCS Bucket Config
GCS_BUCKET_NAME = os.getenv("GCS_BUCKET_NAME", "devops-project-tfstate-bucket")

# Docker Configuration
DOCKER_USERNAME = os.getenv("DOCKER_USERNAME", "devops-user")

# App/Cluster Identifiers
CLUSTER_NAME = os.getenv("CLUSTER_NAME", "devops-gke-cluster")
ENVIRONMENT = os.getenv("ENVIRONMENT", "prod")
OWNER = os.getenv("OWNER", "devops-user")
