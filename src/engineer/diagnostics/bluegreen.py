from engineer.kubernetes.services import ServiceRepository
from engineer.kubernetes.deployments import DeploymentRepository
from engineer.kubernetes.istio import IstioRepository
from engineer.kubernetes.hpa import HPARepository

from engineer.models.resources import (
    BlueGreenStatus,
    DeploymentStatus,
    HPAStatus,
    TrafficStatus,
)


class BlueGreenDiagnostic:

    def __init__(
        self,
        services: ServiceRepository,
        deployments: DeploymentRepository,
        istio: IstioRepository,
        hpa: HPARepository,
    ):
        self.services = services
        self.deployments = deployments
        self.istio = istio
        self.hpa = hpa

    def diagnose(
        self,
        service_name: str,
    ) -> BlueGreenStatus:

        service = self.services.get(service_name)

        service_selector = (
            service
            .get("spec", {})
            .get("selector", {})
        )

        destination_rule = self._find_destination_rule(
            service_name
        )

        self._validate_destination_rule(
            destination_rule,
            service_name,
        )

        virtual_service = self._find_virtual_service(
            service_name
        )

        traffic = self._extract_traffic(
            virtual_service
        )

        active_version = traffic.active_version

        strategy_version = self._calculate_strategy(
            active_version
        )

        blue_deployment = None
        green_deployment = None

        for deployment in self.deployments.list():

            if not self._matches_service(
                deployment,
                service_selector,
            ):
                continue

            version = (
                deployment
                .get("spec", {})
                .get("template", {})
                .get("metadata", {})
                .get("labels", {})
                .get("version.strategy")
            )

            if version not in ("blue", "green"):
                continue

            status = deployment.get("status", {})

            deployment_status = DeploymentStatus(
                name=deployment["metadata"]["name"],
                version=version,
                ready=status.get(
                    "readyReplicas",
                    0,
                ),
                desired=status.get(
                    "replicas",
                    0,
                ),
            )

            if version == "blue":
                blue_deployment = deployment_status

            if version == "green":
                green_deployment = deployment_status

        hpa = self._find_hpa(
            active_version,
            blue_deployment,
            green_deployment,
        )

        return BlueGreenStatus(
            service=service_name,
            active_version=active_version,
            strategy_version=strategy_version,
            blue_deployment=blue_deployment,
            green_deployment=green_deployment,
            traffic=traffic,
            hpa=hpa,
        )

    def _find_destination_rule(
        self,
        service_name: str,
    ):

        for rule in self.istio.destination_rules():

            host = (
                rule
                .get("spec", {})
                .get("host")
            )

            if host == service_name:
                return rule

        return None

    def _validate_destination_rule(
        self,
        destination_rule,
        service_name: str,
    ) -> None:

        if not destination_rule:
            raise RuntimeError(
                f"DestinationRule not found for service '{service_name}'"
            )

        subsets = (
            destination_rule
            .get("spec", {})
            .get("subsets", [])
        )

        versions = set()

        for subset in subsets:

            name = subset.get("name")

            labels = (
                subset
                .get("labels", {})
            )

            strategy = labels.get(
                "version.strategy"
            )

            if name in ("blue", "green"):
                versions.add(name)

            if name == "blue" and strategy != "blue":
                raise RuntimeError(
                    "Invalid DestinationRule: "
                    "blue subset must use "
                    "version.strategy=blue"
                )

            if name == "green" and strategy != "green":
                raise RuntimeError(
                    "Invalid DestinationRule: "
                    "green subset must use "
                    "version.strategy=green"
                )

        missing = {"blue", "green"} - versions

        if missing:
            missing_versions = ", ".join(
                sorted(missing)
            )

            raise RuntimeError(
                "Invalid DestinationRule: "
                f"missing subset(s): {missing_versions}"
            )

    def _find_virtual_service(
        self,
        service_name: str,
    ):

        for virtual_service in self.istio.virtual_services():

            http_routes = (
                virtual_service
                .get("spec", {})
                .get("http", [])
            )

            for http in http_routes:

                for route in http.get("route", []):

                    destination = (
                        route
                        .get("destination", {})
                    )

                    if destination.get("host") == service_name:
                        return virtual_service

        return None

    def _extract_traffic(
        self,
        virtual_service,
    ) -> TrafficStatus:

        blue = 0
        green = 0

        if not virtual_service:
            return TrafficStatus(
                blue=0,
                green=0,
            )

        http_routes = (
            virtual_service
            .get("spec", {})
            .get("http", [])
        )

        for http in http_routes:

            for route in http.get("route", []):

                destination = (
                    route
                    .get("destination", {})
                )

                subset = destination.get("subset")
                weight = route.get("weight", 0)

                if subset == "blue":
                    blue += weight

                elif subset == "green":
                    green += weight

        return TrafficStatus(
            blue=blue,
            green=green,
        )

    def _calculate_strategy(
        self,
        active_version: str | None,
    ) -> str | None:

        if active_version == "blue":
            return "green"

        if active_version == "green":
            return "blue"

        return None

    def _matches_service(
        self,
        deployment,
        selector,
    ) -> bool:

        labels = (
            deployment
            .get("spec", {})
            .get("template", {})
            .get("metadata", {})
            .get("labels", {})
        )

        for key, value in selector.items():

            if labels.get(key) != value:
                return False

        return True

    def _find_hpa(
        self,
        active_version,
        blue_deployment,
        green_deployment,
    ) -> HPAStatus | None:

        active_deployment = None

        if active_version == "blue":
            active_deployment = blue_deployment

        elif active_version == "green":
            active_deployment = green_deployment

        if not active_deployment:
            return None

        for hpa in self.hpa.list():

            target = (
                hpa
                .get("spec", {})
                .get("scaleTargetRef", {})
                .get("name")
            )

            if target != active_deployment.name:
                continue

            spec = hpa.get("spec", {})
            status = hpa.get("status", {})

            return HPAStatus(
                name=hpa["metadata"]["name"],
                target=target,
                minimum=spec.get("minReplicas"),
                maximum=spec.get("maxReplicas"),
                current=status.get(
                    "currentReplicas"
                ),
            )

        return None