import sys
from app.fetch import fetch_and_filter_characters, export_to_csv, logger

def main():
    try:
        characters = fetch_and_filter_characters()
        export_to_csv(characters)
        logger.info("CLI execution completed successfully.")
        sys.exit(0)
    except Exception as e:
        logger.error(f"CLI execution failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
