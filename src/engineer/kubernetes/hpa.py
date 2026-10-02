from typing import Any

from .client import KubernetesClient


class HPARepository:

    def __init__(self, client: KubernetesClient):
        self.client = client

    def list(self) -> list[dict[str, Any]]:
        return self.client.get_all(
            "horizontalpodautoscalers"
        )

    def get(self, name: str) -> dict[str, Any]:
        return self.client.get(
            "horizontalpodautoscaler",
            name,
        )