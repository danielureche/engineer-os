from typing import Any

from .client import KubernetesClient


class DeploymentRepository:

    def __init__(self, client: KubernetesClient):
        self.client = client

    def get(self, name: str) -> dict[str, Any]:
        return self.client.get(
            "deployment",
            name,
        )

    def list(self) -> list[dict[str, Any]]:
        return self.client.get_all(
            "deployments"
        )