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