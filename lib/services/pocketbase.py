# app/services/pocketbase.py
import os
from typing import Optional, Dict, Any
import requests
from loguru import logger

class PocketBaseClient:
    def __init__(self, base_url: str = "http://localhost:8091"):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        logger.info(f"PocketBaseClient inicializado: {self.base_url}")

    def _request(self, method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        try:
            response = self.session.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"Error en petición a {url}: {e}")
            raise Exception(f"No se pudo conectar a PocketBase: {e}")

    def list_records(self, collection: str, page: int = 1, per_page: int = 20, sort: str = "-created") -> Dict[str, Any]:
        params = {"page": page, "perPage": per_page, "sort": sort}
        return self._request("GET", f"api/collections/{collection}/records", params=params)

    def create_record(self, collection: str, data: Dict[str, Any]) -> Dict[str, Any]:
        return self._request("POST", f"api/collections/{collection}/records", json=data)

    def get_record(self, collection: str, record_id: str) -> Dict[str, Any]:
        return self._request("GET", f"api/collections/{collection}/records/{record_id}")

    def update_record(self, collection: str, record_id: str, data: Dict[str, Any]) -> Dict[str, Any]:
        return self._request("PATCH", f"api/collections/{collection}/records/{record_id}", json=data)

    def delete_record(self, collection: str, record_id: str) -> bool:
        self._request("DELETE", f"api/collections/{collection}/records/{record_id}")
        return True

    def upload_file(self, collection: str, record_id: str, field_name: str, file_path: str) -> Dict[str, Any]:
        with open(file_path, "rb") as f:
            files = {field_name: (os.path.basename(file_path), f, "video/mp4")}
            return self._request("POST", f"api/collections/{collection}/records/{record_id}", files=files)

    def get_file_url(self, collection: str, record_id: str, filename: str) -> str:
        return f"{self.base_url}/api/files/{collection}/{record_id}/{filename}"

    def health_check(self) -> Dict[str, Any]:
        return self._request("GET", "api/health")


_pb_client: Optional[PocketBaseClient] = None

def get_pocketbase_client() -> PocketBaseClient:
    global _pb_client
    if _pb_client is None:
        _pb_client = PocketBaseClient()
    return _pb_client