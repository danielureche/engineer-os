from engineer.search.resources import SearchResult


class ResourceActions:

    def get_actions(
        self,
        resource: SearchResult,
    ) -> list[str]:

        if resource.resource_type == "Service":
            return [
                "Blue/Green status",
                "Diagnose",
                "View YAML",
                "Back",
            ]

        if resource.resource_type == "Deployment":
            return [
                "View YAML",
                "Back",
            ]

        if resource.resource_type == "DestinationRule":
            return [
                "View YAML",
                "Back",
            ]

        if resource.resource_type == "VirtualService":
            return [
                "View YAML",
                "Back",
            ]

        if resource.resource_type == "HPA":
            return [
                "View YAML",
                "Back",
            ]

        return ["Back"]
    
    def get_resource_yaml(
        self,
        resource,
    ):
        resource_map = {
            "Service": "service",
            "Deployment": "deployment",
            "DestinationRule": "destinationrule",
            "VirtualService": "virtualservice",
            "HPA": "horizontalpodautoscaler",
        }

        kubernetes_resource = resource_map.get(
            resource.resource_type
        )

        if not kubernetes_resource:
            raise RuntimeError(
                f"Unsupported resource type: "
                f"{resource.resource_type}"
            )

        return kubernetes_resource