import uvicorn
from fastapi import FastAPI, HTTPException
from app.fetch import fetch_and_filter_characters, logger
from app.config import PORT

app = FastAPI(
    title="Rick and Morty Earth Humans API",
    description="API that serves filtered characters from Rick and Morty API (Human, Alive, Origin Earth)",
    version="1.0.0"
)

@app.get("/", tags=["Root"])
@app.get("/characters", tags=["Characters"])
def get_characters():
    """
    Retrieve the filtered list of characters from the Rick and Morty API.
    """
    try:
        characters = fetch_and_filter_characters()
        return {
            "status": "success",
            "count": len(characters),
            "results": characters
        }
    except Exception as e:
        logger.error(f"API characters request failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch characters from upstream API")

@app.get("/healthcheck", tags=["Health"])
def healthcheck():
    """
    Returns 200 OK to indicate the service is running.
    """
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=PORT, reload=False)
