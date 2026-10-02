from engineer.models.resources import TrafficStatus


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