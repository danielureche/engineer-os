import pytest

from engineer.models.resources import (
    TrafficStatus,
    DeploymentStatus,
)

from engineer.diagnostics.bluegreen import (
    BlueGreenDiagnostic,
)


class FakeServiceRepository:

    def get(self, name):
        return {
            "metadata": {
                "name": name,
            },
            "spec": {
                "selector": {
                    "app": "ch-ms-enrollment-v2",
                },
            },
        }


class FakeDeploymentRepository:

    def list(self):
        return [
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2-blue",
                },
                "spec": {
                    "replicas": 3,
                    "template": {
                        "metadata": {
                            "labels": {
                                "app": "ch-ms-enrollment-v2",
                                "version.strategy": "blue",
                            },
                        },
                    },
                },
                "status": {
                    "readyReplicas": 3,
                    "replicas": 3,
                },
            },
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2-green",
                },
                "spec": {
                    "replicas": 3,
                    "template": {
                        "metadata": {
                            "labels": {
                                "app": "ch-ms-enrollment-v2",
                                "version.strategy": "green",
                            },
                        },
                    },
                },
                "status": {
                    "readyReplicas": 3,
                    "replicas": 3,
                },
            },
        ]


class FakeIstioRepository:

    def __init__(self):
        self.destination_rules_data = [
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2",
                },
                "spec": {
                    "host": "ch-ms-enrollment-v2",
                    "subsets": [
                        {
                            "name": "blue",
                            "labels": {
                                "version.strategy": "blue",
                            },
                        },
                        {
                            "name": "green",
                            "labels": {
                                "version.strategy": "green",
                            },
                        },
                    ],
                },
            }
        ]

        self.virtual_services_data = [
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2",
                },
                "spec": {
                    "http": [
                        {
                            "route": [
                                {
                                    "destination": {
                                        "host": "ch-ms-enrollment-v2",
                                        "subset": "blue",
                                    },
                                    "weight": 100,
                                },
                                {
                                    "destination": {
                                        "host": "ch-ms-enrollment-v2",
                                        "subset": "green",
                                    },
                                    "weight": 0,
                                },
                            ],
                        }
                    ],
                },
            }
        ]

    def destination_rules(self):
        return self.destination_rules_data

    def virtual_services(self):
        return self.virtual_services_data


class FakeHPARepository:

    def list(self):
        return [
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2-blue-hpa",
                },
                "spec": {
                    "scaleTargetRef": {
                        "name": "ch-ms-enrollment-v2-blue",
                    },
                    "minReplicas": 2,
                    "maxReplicas": 5,
                },
                "status": {
                    "currentReplicas": 3,
                },
            }
        ]


def create_diagnostic():

    return BlueGreenDiagnostic(
        services=FakeServiceRepository(),
        deployments=FakeDeploymentRepository(),
        istio=FakeIstioRepository(),
        hpa=FakeHPARepository(),
    )


def test_bluegreen_diagnostic():

    diagnostic = create_diagnostic()

    result = diagnostic.diagnose(
        "ch-ms-enrollment-v2"
    )

    assert result.service == "ch-ms-enrollment-v2"

    assert result.active_version == "blue"

    assert result.strategy_version == "green"

    assert result.traffic.blue == 100

    assert result.traffic.green == 0

    assert result.blue_deployment is not None

    assert result.green_deployment is not None

    assert result.blue_deployment.name == (
        "ch-ms-enrollment-v2-blue"
    )

    assert result.green_deployment.name == (
        "ch-ms-enrollment-v2-green"
    )

    assert result.blue_deployment.healthy is True

    assert result.green_deployment.healthy is True

    assert result.hpa is not None

    assert result.hpa.target == (
        "ch-ms-enrollment-v2-blue"
    )

    assert result.hpa.minimum == 2

    assert result.hpa.maximum == 5

    assert result.hpa.current == 3


def test_invalid_destination_rule_fails():

    diagnostic = create_diagnostic()

    diagnostic.istio.destination_rules_data = [
        {
            "metadata": {
                "name": "ch-ms-enrollment-v2",
            },
            "spec": {
                "host": "ch-ms-enrollment-v2",
                "subsets": [
                    {
                        "name": "blue",
                        "labels": {
                            "version.strategy": "blue",
                        },
                    }
                ],
            },
        }
    ]

    with pytest.raises(
        RuntimeError,
        match="green",
    ):
        diagnostic.diagnose(
            "ch-ms-enrollment-v2"
        )