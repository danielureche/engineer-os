from engineer.models.resources import (
    TrafficStatus,
    DeploymentStatus,
)


def test_blue_is_active():

    traffic = TrafficStatus(
        blue=100,
        green=0,
    )

    assert traffic.active_version == "blue"


def test_green_is_active():

    traffic = TrafficStatus(
        blue=0,
        green=100,
    )

    assert traffic.active_version == "green"


def test_split_traffic_has_no_active_version():

    traffic = TrafficStatus(
        blue=50,
        green=50,
    )

    assert traffic.active_version is None


def test_deployment_is_healthy():

    deployment = DeploymentStatus(
        name="ch-ms-enrollment-v2-blue",
        version="blue",
        ready=3,
        desired=3,
    )

    assert deployment.healthy is True


def test_deployment_is_not_healthy():

    deployment = DeploymentStatus(
        name="ch-ms-enrollment-v2-green",
        version="green",
        ready=2,
        desired=3,
    )

    assert deployment.healthy is False