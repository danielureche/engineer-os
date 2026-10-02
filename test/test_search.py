from engineer.search.resources import (
    ResourceSearcher,
)


class FakeServiceRepository:

    def list(self):
        return [
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2",
                },
            },
            {
                "metadata": {
                    "name": "ch-ms-payment-v1",
                },
            },
        ]


class FakeDeploymentRepository:

    def list(self):
        return [
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2-blue",
                },
            },
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2-green",
                },
            },
            {
                "metadata": {
                    "name": "ch-ms-payment-v1-blue",
                },
            },
        ]


class FakeIstioRepository:

    def destination_rules(self):
        return [
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2",
                },
                "spec": {
                    "host": "ch-ms-enrollment-v2",
                },
            },
            {
                "metadata": {
                    "name": "ch-ms-payment-v1",
                },
                "spec": {
                    "host": "ch-ms-payment-v1",
                },
            },
        ]

    def virtual_services(self):
        return [
            {
                "metadata": {
                    "name": "ch-ms-enrollment-v2",
                },
            },
            {
                "metadata": {
                    "name": "ch-ms-payment-v1",
                },
            },
        ]


def create_searcher():

    return ResourceSearcher(
        services=FakeServiceRepository(),
        deployments=FakeDeploymentRepository(),
        istio=FakeIstioRepository(),
    )


def test_find_enrollment():

    searcher = create_searcher()

    results = searcher.search(
        "enrollment"
    )

    assert len(results) == 5

    assert any(
        result.resource_type == "Service"
        and result.name == "ch-ms-enrollment-v2"
        for result in results
    )

    assert any(
        result.resource_type == "Deployment"
        and result.name == "ch-ms-enrollment-v2-blue"
        for result in results
    )

    assert any(
        result.resource_type == "Deployment"
        and result.name == "ch-ms-enrollment-v2-green"
        for result in results
    )

    assert any(
        result.resource_type == "DestinationRule"
        and result.name == "ch-ms-enrollment-v2"
        for result in results
    )

    assert any(
        result.resource_type == "VirtualService"
        and result.name == "ch-ms-enrollment-v2"
        for result in results
    )


def test_find_is_case_insensitive():

    searcher = create_searcher()

    results = searcher.search(
        "ENROLLMENT"
    )

    assert len(results) == 5


def test_find_without_results():

    searcher = create_searcher()

    results = searcher.search(
        "customer"
    )

    assert results == []