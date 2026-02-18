#!/usr/bin/env bash

if [[ "$1" == "--help" || "$1" == "-h" ]] ; then
    echo "Usage: $0 [debug]" >&2
    exit 2
fi

set -e
set -o pipefail

data_dir="data"
data_version="$1"
script_dir="$(dirname $0)"

case "$(uname)" in
    FreeBSD)   OS=FreeBSD ;;
    DragonFly) OS=FreeBSD ;;
    OpenBSD)   OS=OpenBSD ;;
    Darwin)    OS=Darwin  ;;
    SunOS)     OS=SunOS   ;;
    *)         OS=Linux   ;;
esac

echo "Detected OS: $OS" >&2

if [[ "$OS" == "Linux" ]] ; then
    # When using Neo4j installed on system (like Ubuntu's packaged version),
    # the current directory must be writable by user "neo4j",
    # and all parent directories must be executable by "other".
    # Every interaction with the database must be done by user "neo4j",
    # and the import will try to write reports in the current directory.
    NEO_USER="sudo -u neo4j"
    # export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
else
    NEO_USER=""
fi

export PYTHONOPTIMIZE="2"  # Optimize = remove asserts and optimize bytecode.
weave_args="--log-level WARNING"
if [[ "$1" == "debug" ]] ; then
    echo "DEBUG MODE" >&2
    export PYTHONOPTIMIZE=""
    weave_args="--log-level INFO --debug"
fi


echo "Activate virtual environment..." >&2
source $(dirname $(uv python find))/activate


if [[ "$1" != "debug" ]] ; then
    echo "Stop Neo4j server..." >&2
    neo_version=$(neo4j-admin --version | cut -d. -f 1)
    if [[ "$neo_version" -eq 4 ]]; then
        server="${NEO_USER} neo4j"
    else
        server="${NEO_USER} neo4j-admin server"
    fi
    $server stop
fi

echo "Weave data..." >&2
rm -f config/extended_schema.yaml

cmd="uv run ontoweave  \
     --biocypher-config config/config.yaml \
     --biocypher-schema config/schema.yaml \
     --auto-schema config/extended_schema.yaml \
     ${weave_args} \
     ${data_dir}/target/*.parquet:adapters/target.yaml \
     "
     # ${data_dir}/drug_mechanism_of_action/*.parquet:adapters/drug_mechanism_of_action.yaml \
     # ${data_dir}/drug_molecule/*.parquet:adapters/drug_molecule.yaml \

echo "Weaving command:" >&2
echo "$cmd" >&2

$cmd > last-import-script-location.sh


if [[ "$1" != "debug" ]] ; then
    echo "Run import script..." >&2
    chmod a+x  $(cat last-import-script-location.sh)
    ${NEO_USER} $SHELL $(cat last-import-script-location.sh)

    echo "Restart Neo4j..." >&2
    $server start
    sleep 5

    echo "Send a test query..." >&2
    ${NEO_USER} cypher-shell --username neo4j --database oncodash --password $(cat neo4j.pass) "MATCH (d:Drug) RETURN d LIMIT 20;"
fi

echo "Done" >&2

