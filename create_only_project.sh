#!/bin/bash
# Script minimale per creare il progetto in locale con Maven Archetype

# Funzione per mostrare l'uso corretto dello script
usage() {
    echo "Usage: $0 MAIN_PROJECT_NAME GITLAB_GROUP_NAME [--archetype ARCHETYPE_NAME] [--no-mock]"
    echo "Example:"
    echo "  $0 my_project my_group"
    echo "  $0 my_project my_group --archetype alternative-archetype"
    echo "  $0 my_project my_group --no-mock"
    echo "  $0 my_project my_group --archetype alternative-archetype --no-mock"
    exit 1
}

# Controlla che almeno un argomento sia stato passato
if [ "$#" -lt 1 ]; then
    usage
fi

# Imposta la variabile obbligatoria: il nome del progetto
MAIN_PROJECT_NAME=$1
shift

# Archetipo di default e variabili Maven
DEFAULT_ARCHETYPE="passthrough-solo-manager-rest"
SELECTED_ARCHETYPE=$DEFAULT_ARCHETYPE
ARCHETYPE_GROUP_ID="it.imolainformatica.archetype"
ARCHETYPE_VERSION="1.0.0-SNAPSHOT"

# Altre variabili Maven (modifica secondo le tue esigenze)
GROUP_ID="it.imolinfo"
ARTIFACT_ID="$MAIN_PROJECT_NAME"
POMVERSION="1.0.0-SNAPSHOT"

# Proprietà aggiuntive per la generazione (valori di default)
SERVICENAME="service"
SERVICEVERSION="1"
SERVICE="service"

# Parsing degli argomenti opzionali
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --archetype)
            if [ -n "$2" ]; then
                SELECTED_ARCHETYPE="$2"
                echo "Archetipo selezionato: $SELECTED_ARCHETYPE"
                shift 2
            else
                echo "Errore: manca il nome dell'archetipo dopo --archetype"
                usage
            fi
            ;;
        *)
            echo "Opzione sconosciuta: $1"
            usage
            ;;
    esac
done

# Esecuzione del comando Maven per generare il progetto
echo "Generating project scaffolding with archetype $SELECTED_ARCHETYPE..."
mvn archetype:generate \
  -DarchetypeGroupId=$ARCHETYPE_GROUP_ID \
  -DarchetypeArtifactId=$SELECTED_ARCHETYPE \
  -DarchetypeVersion=$ARCHETYPE_VERSION \
  -DgroupId=$GROUP_ID \
  -DartifactId=$MAIN_PROJECT_NAME \
  -Dversion=$POMVERSION \
  -DserviceName=$SERVICENAME \
  -DserviceVersion=$SERVICEVERSION \
  -Dservice=$SERVICE \
  -DcurrentDate=$(date +%d-%m-%Y) \
  -DinteractiveMode=false

echo "Current directory: $(pwd)"
ls -la
cd Resources/

# Genera la parte di scaffolding tests nella cartella Resources/test
if [ ! -d "test" ]; then
  mkdir test
fi
cd test

echo "Generating tests scaffolding with archetype test-junit..."
yes | mvn archetype:generate \
  -DarchetypeGroupId=$ARCHETYPE_GROUP_ID \
  -DarchetypeArtifactId=test-junit \
  -DarchetypeVersion=$ARCHETYPE_VERSION \
  -DgroupId=it.imolinfo \
  -DartifactId="test" \
  -DprojectName=$MAIN_PROJECT_NAME \
  -DserviceName=$SERVICENAME \
  -DserviceNameLow=$SERVICENAMELOW \
  -DapplicationCodeLow=$SIGLALOW \
  -DapplicationCode=$SIGLA \
  -Dversion=$POMVERSION \
  -DserviceVersion=$SERVICEVERSION

echo "Scaffolding tests creato con successo in Resources/test."
