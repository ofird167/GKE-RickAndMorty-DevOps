import csv
import logging
from pathlib import Path
import requests

# Set up logging to logs/app.log
BASE_DIR = Path(__file__).resolve().parent.parent
LOG_DIR = BASE_DIR / "logs"
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "app.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

API_URL = "https://rickandmortyapi.com/api/character"

def fetch_and_filter_characters():
    """
    Fetches all characters from the Rick and Morty API, paginating through results,
    and filters for characters where:
    - species == 'Human'
    - status == 'Alive'
    - origin.name == 'Earth'
    """
    filtered_characters = []
    url = API_URL
    page = 1

    logger.info("Starting to fetch characters from Rick and Morty API...")
    
    try:
        while url:
            logger.info(f"Fetching page {page} from {url}...")
            response = requests.get(url, timeout=10)
            response.raise_for_status()
            data = response.json()

            results = data.get("results", [])
            for char in results:
                species = char.get("species", "")
                status = char.get("status", "")
                origin_name = char.get("origin", {}).get("name", "")

                # Filtering criteria: Human, Alive, Origin starts with Earth
                if species == "Human" and status == "Alive" and origin_name.startswith("Earth"):
                    filtered_characters.append({
                        "Name": char.get("name"),
                        "Location": char.get("location", {}).get("name", ""),
                        "Image": char.get("image", "")
                    })

            url = data.get("info", {}).get("next")
            page += 1
            
        logger.info(f"Fetch completed. Found {len(filtered_characters)} characters matching the criteria.")
        return filtered_characters

    except requests.RequestException as e:
        logger.error(f"Error occurred while fetching characters: {e}")
        raise

def export_to_csv(characters, filename="results.csv"):
    """
    Exports the list of characters to a CSV file in the root workspace directory.
    """
    filepath = BASE_DIR / filename
    fields = ["Name", "Location", "Image"]

    logger.info(f"Exporting {len(characters)} characters to {filepath}...")
    try:
        with open(filepath, mode="w", newline="", encoding="utf-8") as csv_file:
            writer = csv.DictWriter(csv_file, fieldnames=fields)
            writer.writeheader()
            for char in characters:
                writer.writerow(char)
        logger.info("CSV export completed successfully.")
        return filepath
    except IOError as e:
        logger.error(f"Failed to write to CSV file {filepath}: {e}")
        raise
