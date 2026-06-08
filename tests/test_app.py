from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient
from app.main import app
from app.fetch import fetch_and_filter_characters

client = TestClient(app)

def test_healthcheck():
    response = client.get("/healthcheck")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

@patch("app.fetch.requests.get")
def test_fetch_and_filter(mock_get):
    # Mock response payload
    mock_response = MagicMock()
    mock_response.json.return_value = {
        "info": {"next": None},
        "results": [
            {
                "id": 1,
                "name": "Rick Sanchez",
                "status": "Alive",
                "species": "Human",
                "origin": {"name": "Earth"},
                "location": {"name": "Earth"},
                "image": "image_url_1"
            },
            {
                "id": 2,
                "name": "Morty Smith",
                "status": "Alive",
                "species": "Human",
                "origin": {"name": "Earth"},
                "location": {"name": "Earth"},
                "image": "image_url_2"
            },
            {
                "id": 3,
                "name": "Alien Bob",
                "status": "Alive",
                "species": "Alien",
                "origin": {"name": "Earth"},
                "location": {"name": "Earth"},
                "image": "image_url_3"
            },
            {
                "id": 4,
                "name": "Dead Human",
                "status": "Dead",
                "species": "Human",
                "origin": {"name": "Earth"},
                "location": {"name": "Earth"},
                "image": "image_url_4"
            },
            {
                "id": 5,
                "name": "Space Human",
                "status": "Alive",
                "species": "Human",
                "origin": {"name": "Mars"},
                "location": {"name": "Earth"},
                "image": "image_url_5"
            }
        ]
    }
    mock_response.raise_for_status.return_value = None
    mock_get.return_value = mock_response

    results = fetch_and_filter_characters()

    # Should only return Rick and Morty (Human, Alive, Earth origin)
    assert len(results) == 2
    assert results[0]["Name"] == "Rick Sanchez"
    assert results[1]["Name"] == "Morty Smith"

@patch("app.main.fetch_and_filter_characters")
def test_api_characters_endpoint(mock_fetch):
    mock_fetch.return_value = [
        {
            "Name": "Rick Sanchez",
            "Location": "Earth",
            "Image": "image_url"
        }
    ]

    response = client.get("/characters")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["count"] == 1
    assert data["results"][0]["Name"] == "Rick Sanchez"
