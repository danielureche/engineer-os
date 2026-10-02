import argparse

from rich.console import Console
from rich.table import Table

from engineer.kubernetes.client import KubernetesClient
from engineer.kubernetes.services import ServiceRepository
from engineer.kubernetes.deployments import DeploymentRepository
from engineer.kubernetes.istio import IstioRepository
from engineer.kubernetes.hpa import HPARepository

from engineer.diagnostics.bluegreen import (
    BlueGreenDiagnostic,
)


console = Console()


def create_diagnostic() -> BlueGreenDiagnostic:

    client = KubernetesClient()

    services = ServiceRepository(client)
    deployments = DeploymentRepository(client)
    istio = IstioRepository(client)
    hpa = HPARepository(client)

    return BlueGreenDiagnostic(
        services=services,
        deployments=deployments,
        istio=istio,
        hpa=hpa,
    )


def diagnose(service: str):

    diagnostic = create_diagnostic()

    try:

        result = diagnostic.diagnose(
            service
        )

    except Exception as error:

        console.print(
            f"[red]✗ Error:[/red] {error}"
        )

        raise SystemExit(1)

    console.print()

    console.print(
        "[bold]ENGINEER OS - BLUE/GREEN DIAGNOSTIC[/bold]"
    )

    console.print()

    table = Table()

    table.add_column("Property")
    table.add_column("Value")

    table.add_row(
        "Service",
        result.service,
    )

    table.add_row(
        "Active",
        result.active_version or "UNKNOWN",
    )

    table.add_row(
        "Strategy",
        result.strategy_version or "UNKNOWN",
    )

    table.add_row(
        "Blue traffic",
        f"{result.traffic.blue}%",
    )

    table.add_row(
        "Green traffic",
        f"{result.traffic.green}%",
    )

    console.print(table)

    console.print()

    deployment_table = Table()

    deployment_table.add_column("Version")
    deployment_table.add_column("Deployment")
    deployment_table.add_column("Ready")
    deployment_table.add_column("Desired")
    deployment_table.add_column("Status")

    for deployment in [
        result.blue_deployment,
        result.green_deployment,
    ]:

        if not deployment:
            continue

        status = (
            "HEALTHY"
            if deployment.healthy
            else "NOT READY"
        )

        deployment_table.add_row(
            deployment.version,
            deployment.name,
            str(deployment.ready),
            str(deployment.desired),
            status,
        )

    console.print(
        "[bold]DEPLOYMENTS[/bold]"
    )

    console.print(
        deployment_table
    )

    console.print()

    console.print(
        "[bold]HPA[/bold]"
    )

    if result.hpa:

        console.print(
            f"Name    : {result.hpa.name}"
        )

        console.print(
            f"Target  : {result.hpa.target}"
        )

        console.print(
            f"Min     : {result.hpa.minimum}"
        )

        console.print(
            f"Max     : {result.hpa.maximum}"
        )

        console.print(
            f"Current : {result.hpa.current}"
        )

    else:

        console.print(
            "No HPA found for active deployment."
        )

    console.print()


def main():

    parser = argparse.ArgumentParser(
        prog="engineer",
        description=(
            "Engineering productivity "
            "and diagnostics CLI"
        ),
    )

    subparsers = parser.add_subparsers(
        dest="command"
    )

    diagnose_parser = subparsers.add_parser(
        "diagnose",
        help="Diagnose a service",
    )

    diagnose_parser.add_argument(
        "service",
        help="Kubernetes service name",
    )

    args = parser.parse_args()

    if args.command == "diagnose":

        diagnose(args.service)

        return

    parser.print_help()


if __name__ == "__main__":
    main()