from typing import Any

from .client import KubernetesClient


class ServiceRepository:

    def __init__(self, client: KubernetesClient):
        self.client = client

    def get(self, name: str) -> dict[str, Any]:
        return self.client.get("service", name)

    def list(self) -> list[dict[str, Any]]:
        return self.client.get_all("services")