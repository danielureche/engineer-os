from typing import Any

from .client import KubernetesClient


class IstioRepository:

    def __init__(self, client: KubernetesClient):
        self.client = client

    def destination_rules(self) -> list[dict[str, Any]]:
        return self.client.get_all("destinationrules")

    def virtual_services(self) -> list[dict[str, Any]]:
        return self.client.get_all("virtualservices")