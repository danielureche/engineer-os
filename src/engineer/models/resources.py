from dataclasses import dataclass


@dataclass
class DeploymentStatus:
    name: str
    version: str
    ready: int
    desired: int

    @property
    def healthy(self) -> bool:
        return self.ready == self.desired


@dataclass
class HPAStatus:
    name: str
    target: str
    minimum: int | None
    maximum: int | None
    current: int | None


@dataclass
class TrafficStatus:
    blue: int
    green: int

    @property
    def active_version(self) -> str | None:

        if self.blue == 100 and self.green == 0:
            return "blue"

        if self.green == 100 and self.blue == 0:
            return "green"

        return None


@dataclass
class BlueGreenStatus:
    service: str
    active_version: str | None
    strategy_version: str | None

    blue_deployment: DeploymentStatus | None
    green_deployment: DeploymentStatus | None

    traffic: TrafficStatus

    hpa: HPAStatus | None