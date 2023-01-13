import sys
import csv
import requests
from abc import ABC, abstractmethod
from xml.etree import ElementTree
from rdflib import Graph, URIRef, RDF, RDFS, Literal, SKOS, DC
from functools import lru_cache

DC_TERMS = "http://purl.org/dc/terms/"

DC = "http://purl.org/dc/elements/1.1/"

EUPMC = "http://europepmc.org/abstract/"

RDF_NS = "{http://www.w3.org/1999/02/22-rdf-syntax-ns#}"


class LookupService(ABC):
    """
    Base bibliographic data lookup service.
    """

    @abstractmethod
    def lookup(self, reference):
        """
        Searches given bibliographic reference in the lookup service and retrieves Dublin Core formatted metadata for it.

        Args:
            reference: bibliographic reference (doi (DOI:xxx or https://doi.org/xxx),
            pubmed id (PMID:xxx) etc.) to resolve.
        :return: Dublin Core formatted metadata of the bibliographic reference
        """
        pass


class EuroPMCLookup(LookupService):
    """
    EuroPMC bibliographic data lookup service. Able to resolve DOI and PMID references.
    """

    URL = "https://www.ebi.ac.uk/europepmc/webservices/rest/search?query={reference}&" \
          "resultType=lite&cursorMark=*&pageSize=1&format=dc"

    @lru_cache(maxsize=128)
    def lookup(self, query):
        # print("EuroPMC looking for: " + reference)
        reference = query
        reference = reference.replace("PMID:", "")
        reference = reference.replace("https://doi.org/", "DOI:")

        response = requests.get(url=self.URL.format(reference=reference))
        root = ElementTree.fromstring(response.content)
        hit_count = int(root.find("hitCount").text)

        reference_ontology = Graph()
        biblio_id = None
        if hit_count > 0:
            for rdf_definition in root.findall(RDF_NS + 'RDF'):  # there is only one though
                rdf_as_text = ElementTree.tostring(rdf_definition, encoding="unicode")

                for individual in rdf_definition.findall(RDF_NS + 'Description'):
                    biblio_id = individual.attrib.get(RDF_NS + "about")
                    # print("Found: " + biblio_id)
                    # only the first result
                    break

                graph = Graph()
                graph.parse(data=rdf_as_text, format='xml')

                biblio_indv = URIRef(biblio_id)
                reference_ontology += graph.triples((biblio_indv, None, None))
                reference_ontology.add((biblio_indv, RDF.type, URIRef(DC_TERMS + "BibliographicResource")))
                reference_ontology.add((biblio_indv, SKOS.exactMatch, Literal(str(query))))
                for title in graph.objects(biblio_indv, URIRef(DC + "title")):
                    reference_ontology.add((biblio_indv, RDFS.label, title))
        else:
            print("WARN - Bibliographic data couldn't be found for: " + query)
        return reference_ontology, biblio_id


def lookup_references(xrefs_csv):
    """
    For each bibliographic reference record, searches for the reference and crawls Dublin Core formatted rich metadata.
    Constructs an ontology of dc individuals and binds these individuals to the related classes.
    """
    lookup_service = EuroPMCLookup()
    biblio_graph = Graph()
    biblio_graph.namespace_manager.bind('dc', DC, override=False)
    biblio_graph.namespace_manager.bind('dcterms', DC_TERMS, override=False)
    biblio_graph.namespace_manager.bind('eupmc', EUPMC, override=False)
    biblio_graph.namespace_manager.bind('skos', SKOS.uri, override=False)
    add_europmc_namespaces(biblio_graph)

    count = 0
    with open(xrefs_csv) as csv_file:
        csv_reader = csv.reader(csv_file, delimiter=',')
        for row in csv_reader:
            if str(row[2]).startswith("DOI:") or str(row[2]).startswith("PMID:") \
                    or str(row[2]).startswith("https://doi.org/"):
                dc_data, individual_id = lookup_service.lookup(row[2])
                if individual_id:
                    biblio_graph += dc_data
                    biblio_graph.add(
                        (URIRef(row[0]), URIRef(DC + "source"), URIRef(individual_id)))
                    count += 1

    print("Resolved {} references.".format(count))
    return biblio_graph


def add_europmc_namespaces(biblio_graph):
    namespaces = ["AGR", "CBA", "CTX", "ETH", "HIR", "MED", "NBK", "PAT", "PMC", "PPR"]
    for namespace in namespaces:
        biblio_graph.namespace_manager.bind(namespace.lower(),
                                            "http://europepmc.org/abstract/{}/".format(namespace), override=False)


def save_ontology(biblio_graph, target_ontology):
    """
    Writes ontology to file.
    """
    biblio_graph.serialize(destination=target_ontology, format='turtle')


ontology_file = sys.argv[1]
xrefs_csv = sys.argv[2]
target_ontology_file = sys.argv[3]

biblio_ontology = lookup_references(xrefs_csv)
save_ontology(biblio_ontology, target_ontology_file)
