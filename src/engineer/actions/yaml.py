class ResourceYaml:

    RESOURCE_MAP = {
        "Service": "service",
        "Deployment": "deployment",
        "DestinationRule": "destinationrule",
        "VirtualService": "virtualservice",
        "HPA": "horizontalpodautoscaler",
    }

    def __init__(self, client):
        self.client = client

    def get(self, resource):

        kubernetes_resource = self.RESOURCE_MAP.get(
            resource.resource_type
        )

        if not kubernetes_resource:
            raise RuntimeError(
                f"Unsupported resource type: "
                f"{resource.resource_type}"
            )

        return self.client.get_yaml(
            kubernetes_resource,
            resource.name,
        )