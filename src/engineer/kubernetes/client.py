import json
import subprocess
from typing import Any


class KubernetesClient:

    def get(
        self,
        resource: str,
        name: str | None = None,
    ) -> dict[str, Any]:

        command = [
            "kubectl",
            "get",
            resource,
        ]

        if name:
            command.append(name)

        command.extend([
            "-o",
            "json",
        ])

        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
        )

        if result.returncode != 0:
            raise RuntimeError(
                result.stderr.strip()
            )

        return json.loads(result.stdout)

    def get_all(
        self,
        resource: str,
    ) -> list[dict[str, Any]]:

        data = self.get(resource)

        return data.get("items", [])