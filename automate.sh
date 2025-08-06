#!/bin/bash

# Funzione per mostrare l'uso corretto dello script
usage() {
    echo "Usage: $0 MAIN_PROJECT_NAME GITLAB_GROUP_NAME [--archetype ARCHETYPE_NAME] [--no-mock]"
    echo "Example:"
    echo "  $0 my_project my_group"
    echo "  $0 my_project my_group --archetype alternative-archetype"
    echo "  $0 my_project my_group --no-mock"
    echo "  $0 my_project my_group --archetype alternative-archetype --no-mock"
    #exit 1
}


# Controlla che almeno due argomenti siano stati passati
if [ "$#" -lt 2 ]; then
    usage
fi

# Imposta le variabili da riga di comando
MAIN_PROJECT_NAME=$1    # Nome del progetto principale, utilizzato tale per creazione git project
GITLAB_GROUP_NAME=$2    # Nome del gruppo da creare su GitLab (passato da riga di comando)
SECOND_GROUP_NAME="rtc"  # Nome del sottogruppo sempre uguale (rtc)
GITLAB_GROUP_ID="8477"  # ID del gruppo GitLab dove creare i gruppi e progetti (bbpm-svil-automation/Projects) (personale lrubboli)
#GITLAB_GROUP_ID="434"    # ID del gruppo GitLab BPM (bancoBPM/Axway-Gateway-Projects/sources)

# Imposta l'archetipo Maven (default o alternativo)
ARTECHTYPE_DEFAULT="passthrough-solo-manager-rest"
ARTECHTYPE_ALTERNATIVE="passthrough-manager-gateway-rest"
ARCHETYPE_GROUP_ID="it.imolainformatica.archetype"
ARCHETYPE_VERSION="1.0.0-SNAPSHOT"

# Inizializza variabili opzionali
SELECTED_ARCHETYPE=$ARTECHTYPE_DEFAULT
SKIP_MOCK=false

# Parsing degli argomenti opzionali
shift 2  # Rimuove i primi due argomenti (MAIN_PROJECT_NAME e GITLAB_GROUP_NAME)

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --archetype)
            if [ -n "$2" ]; then
                SELECTED_ARCHETYPE="$2"
                echo "Selezionato archetipo: $SELECTED_ARCHETYPE"
                shift 2
            else
                echo "Error: Missing ARCHETYPE_NAME after --archetype"
                usage
            fi
            ;;
        --no-mock)
            SKIP_MOCK=true
            echo "Opzione --no-mock rilevata: Salto la creazione del progetto mock."
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Stampa i risultati
echo "MAIN_PROJECT_NAME: $MAIN_PROJECT_NAME"
echo "GITLAB_GROUP_NAME: $GITLAB_GROUP_NAME"
echo "Selected Archetype: $SELECTED_ARCHETYPE"
echo "SKIP_MOCK: $SKIP_MOCK"

# Estrai SIGLA (prima parte prima del primo "_")
SIGLA="${MAIN_PROJECT_NAME%%_*}"
# Rimuovi la prima parte e il primo "_" dalla stringa
SERVICE="${MAIN_PROJECT_NAME#*_}"
# Estrai SERVICENAME (seconda parte prima del secondo "_")
SERVICENAME="${SERVICE%%_*}"
# Rimuovi la seconda parte e il secondo "_" dalla stringa
#[[ $SERVICE == *.* ]] && SERVICEVERSION="${SERVICE#*_v}" || SERVICEVERSION="${SERVICE#*_v}.0"
SERVICEVERSION="${SERVICE#*_v}"
# Creo stringa versione snapshot da inserire nel pom
POMVERSION="${SERVICEVERSION}.0.0-SNAPSHOT"
# Versioni minuscole
SIGLALOW="${SIGLA,,}"
SERVICENAMELOW="${SERVICENAME,,}"

# Stampa i risultati
echo "SIGLA: $SIGLA"
echo "SERVICENAME: $SERVICENAME"
echo "SERVICEVERSION: $SERVICEVERSION"
echo "SIGLALOW: $SIGLALOW"
echo "SERVICENAMELOW: $SERVICENAMELOW"

# Funzione per ottenere l'ID del gruppo principale tramite API GitLab
get_group_id() {
    local group_name=$1
    curl --silent --header "Private-Token: $GITLAB_TOKEN" \
        "https://git.imolinfo.it/api/v4/groups?search=$group_name" | jq -r '.[0].id'
}

# Funzione per ottenere l'ID del sottogruppo 'rtc' all'interno del gruppo principale
get_subgroup_id() {
    local parent_group_id=$1
    local subgroup_name=$2
    curl --silent --header "Private-Token: $GITLAB_TOKEN" \
        "https://git.imolinfo.it/api/v4/groups/$parent_group_id/subgroups" | jq -r --arg subgroup_name "$subgroup_name" '.[] | select(.name == $subgroup_name) | .id'
}

# Cerca il gruppo principale
GROUP_ID=$(get_group_id "$GITLAB_GROUP_NAME")

if [ "$GROUP_ID" == "null" ] || [ -z "$GROUP_ID" ]; then
  # Il gruppo non esiste, quindi crealo
  echo "Creating main group on GitLab..."
  GROUP_RESPONSE=$(curl --silent --header "Private-Token: $GITLAB_TOKEN" \
       --data "name=$GITLAB_GROUP_NAME" \
       --data "path=$GITLAB_GROUP_NAME" \
       --data "parent_id=$GITLAB_GROUP_ID" \
       --data "visibility=private" \
       https://git.imolinfo.it/api/v4/groups)

  # Estrai l'ID del gruppo principale creato
  GROUP_ID=$(echo $GROUP_RESPONSE | jq -r '.id')

  if [ "$GROUP_ID" == "null" ]; then
    echo "Error creating main group. Exiting..."
    #exit 1
  fi
  echo "Main group $GITLAB_GROUP_NAME created with ID: $GROUP_ID"
else
  echo "Main group $GITLAB_GROUP_NAME already exists with ID: $GROUP_ID"
fi

# Cerca il sottogruppo rtc all'interno del gruppo principale
SUBGROUP_ID=$(get_subgroup_id "$GROUP_ID" "$SECOND_GROUP_NAME")

if [ "$SUBGROUP_ID" == "null" ] || [ -z "$SUBGROUP_ID" ]; then
  # Il sottogruppo non esiste, quindi crealo
  echo "Creating subgroup 'rtc' under group $GITLAB_GROUP_NAME on GitLab..."
  SUBGROUP_RESPONSE=$(curl --silent --header "Private-Token: $GITLAB_TOKEN" \
       --data "name=$SECOND_GROUP_NAME" \
       --data "path=$SECOND_GROUP_NAME" \
       --data "parent_id=$GROUP_ID" \
       --data "visibility=private" \
       https://git.imolinfo.it/api/v4/groups)

  # Estrai l'ID del sottogruppo creato
  SUBGROUP_ID=$(echo $SUBGROUP_RESPONSE | jq -r '.id')

  if [ "$SUBGROUP_ID" == "null" ]; then
    echo "Error creating subgroup. Exiting..."
    #exit 1
  fi
  echo "Subgroup 'rtc' created with ID: $SUBGROUP_ID"
else
  echo "Subgroup 'rtc' under group $GITLAB_GROUP_NAME already exists with ID: $SUBGROUP_ID"
fi

# Controlla se il progetto esiste già nel sottogruppo 'rtc'
PROJECT_RESPONSE=$(curl --silent --header "Private-Token: $GITLAB_TOKEN" \
     "https://git.imolinfo.it/api/v4/groups/$SUBGROUP_ID/projects?search=$MAIN_PROJECT_NAME")

PROJECT_ID=$(echo $PROJECT_RESPONSE | jq -r '.[0].id')

if [ "$PROJECT_ID" == "null" ] || [ -z "$PROJECT_ID" ]; then
  echo "Creating project on GitLab under subgroup 'rtc'..."
  PROJECT_RESPONSE=$(curl --silent --header "Private-Token: $GITLAB_TOKEN" \
       --data "name=$MAIN_PROJECT_NAME" \
       --data "path=$MAIN_PROJECT_NAME" \
       --data "namespace_id=$SUBGROUP_ID" \
       --data "visibility=private" \
       https://git.imolinfo.it/api/v4/projects)

  PROJECT_ID=$(echo $PROJECT_RESPONSE | jq -r '.id')
  echo $PROJECT_RESPONSE

  if [ "$PROJECT_ID" == "null" ]; then
    echo "Error creating project. Exiting..."
    #exit 1
  fi
  echo "Project $MAIN_PROJECT_NAME created with ID: $PROJECT_ID"
else
  echo "Project $MAIN_PROJECT_NAME already exists with ID: $PROJECT_ID"
fi

# Procedi con la generazione del progetto e il caricamento dei file
echo "Generating project scaffolding with archetype $SELECTED_ARCHETYPE..."
mvn archetype:generate \
  -DarchetypeGroupId=$ARCHETYPE_GROUP_ID \
  -DarchetypeArtifactId=$SELECTED_ARCHETYPE \
  -DarchetypeVersion=$ARCHETYPE_VERSION \
  -DgroupId=it.imolinfo \
  -DartifactId=$MAIN_PROJECT_NAME \
  -Dversion=$POMVERSION \
  -DserviceName=$SERVICENAME \
  -DserviceVersion=$SERVICEVERSION \
  -Dservice=$SERVICE \
  -DcurrentDate=$(date +%d-%m-%Y) \
  -DinteractiveMode=false

# Verifica che la directory sia stata creata correttamente
cd $MAIN_PROJECT_NAME
if [ $? -ne 0 ]; then
  echo "Error: directory $MAIN_PROJECT_NAME not found. Exiting..."
  #exit 1
fi

echo "Current directory: $(pwd)"
ls -la
cd Resources/

# Navigo in cartella Resources/test e creo la parte di scaffolding tests sempre con utilizzo di maven archetype
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

cd test/
if [ $? -ne 0 ]; then
  echo "Error: directory Resources/test not found. Exiting..."
  #exit 1
fi
echo "Folder test successfully created"

echo "Current directory: $(pwd)"
ls -la

# Torna alla directory principale del progetto
cd ..

ls -la

# Gestione file JSON da copiare (con lo stesso nome del progetto)
SPEC_FILE_NAME="${MAIN_PROJECT_NAME}"
SOURCE_SPEC_PATH="$(dirname "$0")/$SPEC_FILE_NAME"
TARGET_SPEC_DIR="${MAIN_PROJECT_NAME}/Resources/swagger"
TARGET_SPEC_PATH="${TARGET_SPEC_DIR}/${SPEC_FILE_NAME}"

# Crea directory swagger se non esiste
mkdir -p "$TARGET_SPEC_DIR"

if [ -f "$SOURCE_SPEC_PATH" ]; then
    cp "$SOURCE_SPEC_PATH" "$TARGET_SPEC_PATH"
    if [ $? -eq 0 ]; then
        echo "File $SPEC_FILE_NAME copiato correttamente in $TARGET_SPEC_DIR"
    else
        echo "Errore nella copia del file $SPEC_FILE_NAME in $TARGET_SPEC_DIR"
        exit 1
    fi
else
    echo "Attenzione: file $SPEC_FILE_NAME non trovato nella directory dello script. Nessun file copiato in $TARGET_SPEC_DIR"
fi

echo "Script completato con successo!"


