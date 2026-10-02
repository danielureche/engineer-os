from dataclasses import dataclass


@dataclass
class SearchResult:
    resource_type: str
    name: str
    namespace: str | None = None
    

class ResourceSearcher:

    def __init__(
        self,
        services,
        deployments,
        istio,
        hpa
    ):
        self.services = services
        self.deployments = deployments
        self.istio = istio
        self.hpa = hpa

    def search(
        self,
        keyword: str,
    ) -> list[SearchResult]:

        keyword = keyword.lower()

        results = []

        results.extend(
            self._search_services(keyword)
        )

        results.extend(
            self._search_deployments(keyword)
        )

        results.extend(
            self._search_destination_rules(keyword)
        )

        results.extend(
            self._search_virtual_services(keyword)
        )
        
        results.extend(
            self._search_hpas(keyword)
        )   

        return results
    
    def _search_services(
        self,
        keyword: str,
    ) -> list[SearchResult]:

        results = []

        for service in self.services.list():

            name = (
                service
                .get("metadata", {})
                .get("name", "")
            )

            if keyword in name.lower():

                results.append(
                    SearchResult(
                        resource_type="Service",
                        name=name,
                    )
                )

        return results
    
    def _search_deployments(
        self,
        keyword: str,
    ) -> list[SearchResult]:

        results = []

        for deployment in self.deployments.list():

            name = (
                deployment
                .get("metadata", {})
                .get("name", "")
            )

            if keyword in name.lower():

                results.append(
                    SearchResult(
                        resource_type="Deployment",
                        name=name,
                    )
                )

        return results
    
    def _search_destination_rules(
        self,
        keyword: str,
    ) -> list[SearchResult]:

        results = []

        for rule in self.istio.destination_rules():

            name = (
                rule
                .get("metadata", {})
                .get("name", "")
            )

            host = (
                rule
                .get("spec", {})
                .get("host", "")
            )

            if (
                keyword in name.lower()
                or keyword in host.lower()
            ):

                results.append(
                    SearchResult(
                        resource_type="DestinationRule",
                        name=name,
                    )
                )

        return results
    
    def _search_virtual_services(
        self,
        keyword: str,
    ) -> list[SearchResult]:

        results = []

        for virtual_service in (
            self.istio.virtual_services()
        ):

            name = (
                virtual_service
                .get("metadata", {})
                .get("name", "")
            )

            if keyword in name.lower():

                results.append(
                    SearchResult(
                        resource_type="VirtualService",
                        name=name,
                    )
                )

        return results
    
    def _search_hpas(self, keyword):

        results = []

        for hpa in self.hpa.list():

            name = (
                hpa
                .get("metadata", {})
                .get("name", "")
            )

            target = (
                hpa
                .get("spec", {})
                .get("scaleTargetRef", {})
                .get("name", "")
            )

            if (
                keyword in name.lower()
                or keyword in target.lower()
            ):
                results.append(
                    SearchResult(
                        resource_type="HPA",
                        name=name,
                    )
                )

        return results