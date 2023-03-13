#!/usr/bin/env bash

rdf_type='<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>'
owl_='<http://www.w3.org/2002/07/owl#'
owl='<http://www.w3.org/2002/07/owl#[-_/%a-zA-Z0-9]+>'
orbis='<https://orbis-security.com/pe-malware-ontology#[-_/%a-zA-Z0-9]+>'
orbis_derived_as='<https://orbis-security.com/pe-malware-ontology#derived_as>'
xsd='<http://www.w3.org/2001/XMLSchema#[-_/%a-zA-Z0-9]+>'

set -e

input="$1"
n3="$1.n3"

if [[ ! -e "$n3.xz" ]]; then
python -c 'import owlready2 as or2
import sys
fname = sys.argv[1]
sys.stderr.write("Loading ontology from {}... ".format(fname))
onto = or2.get_ontology("file://{}".format(fname)).load()
sys.stderr.write("Saving ontology to {}.n3...".format(fname))
onto.save(file="{}.n3".format(fname), format="ntriples")
sys.stderr.write("\n")
' "$input"
else
    echo -n "Uncompressing cached $n3... " >&2
    unxz "$n3.xz"
fi

function matching() {
    ggrep -E "$1"
}

function matching_except() {
    ggrep -E "$1" |
    ggrep -E -v "$2"
}

function print() {
    what="$1"
    shift
    printf ',%d' $(( $(cat "$n3" | "$@" | wc -l) ))
}

function print_plus1() {
    what="$1"
    shift
    local -i cnt=$(( $(cat "$n3" | "$@" | wc -l) ))
    printf ',%d' $(( cnt > 0 ? cnt + 1 : 0 ))
}

function print_minus1() {
    what="$1"
    shift
    local -i cnt=$(( $(cat "$n3" | "$@" | wc -l) ))
    printf ',%d' $(( cnt > 0 ? cnt - 1 : 0 ))
}

printf '"%s"' "$input"

print "Classes: " \
    matching \
    " $rdf_type ${owl_}Class> \\."

# +1 for topObjectProperty
print_plus1 "Object properties: " \
    matching \
    " $rdf_type ${owl_}ObjectProperty> \\."

# +1 for topDataProperty
print_plus1 "Data properties: " \
    matching \
    " $rdf_type ${owl_}DatatypeProperty> \\." 

print "Individuals: " \
    matching \
    " $rdf_type ${owl_}NamedIndividual> \\."

print_minus1 "Axioms: " \
    matching \
    "."

print "Class assertions: " \
    matching_except \
    " $rdf_type " \
    " $rdf_type $owl \\."

print "Object property assertions: " \
    matching_except \
    " $orbis $orbis \\." \
    " $orbis_derived_as "

print "Data property assertions: " \
    matching \
    " $orbis \"[^\"]*\"\\^{2}$xsd \\."

echo
echo "Compressing $n3 for caching... " >&2
xz "$n3"

# cat "$n3" |
#     ggrep -Ev " $orbis_derived_as " |
#     ggrep -Ev " $rdf_type " |
#     ggrep -Ev " $orbis \"[^\"]*\"\\^{2}$xsd \\." |
#     ggrep -Ev " $orbis $orbis \\." |
#     less