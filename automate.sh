#!/bin/bash

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

# Carica le variabili dal file .env
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "Error: $ENV_FILE file not found. Please create it and add GITLAB_TOKEN."
    exit 1
fi

# Verifica che GITLAB_TOKEN sia impostato
if [ -z "$GITLAB_TOKEN" ]; then
    echo "Error: GITLAB_TOKEN is not set in $ENV_FILE."
    exit 1
fi

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
    exit 1
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
    exit 1
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
    exit 1
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
  exit 1
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
  exit 1
fi
echo "Folder test successfully created"

# Torna alla directory principale del progetto
cd ../../..
ls -la

# Gestione file JSON da copiare (con lo stesso nome del progetto)
SPEC_FILE_NAME="${MAIN_PROJECT_NAME}.json"
SOURCE_SPEC_PATH="$(dirname "$0")/$SPEC_FILE_NAME"
TARGET_SPEC_DIR="Resources/swagger"
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

echo "Current directory: $(pwd)"
ls -la

# Inizializza git, crea branch develop e committa i file per il progetto principale
git init
git checkout -b develop

# Verifica che ci siano cambiamenti da committare
if [ -z "$(git status --porcelain)" ]; then
  echo "No changes to commit. Exiting..."
  exit 1
fi

# Aggiungi e committa i file nel branch develop
git add .
git commit -m "Initial commit for $MAIN_PROJECT_NAME on branch develop"

# Configura il remote origin e fai il push del branch develop (sotto quello del mock)

### MODIFICARE QUI CON PROPRIO URL GIT ###

git remote add origin "https://git.imolinfo.it/bpm-svil-automation/projects/$GITLAB_GROUP_NAME/$SECOND_GROUP_NAME/$MAIN_PROJECT_NAME.git"

######

# URL remoto BancoBPM
#git remote add origin "https://git.imolinfo.it/bancoBPM/Axway-Gateway-Projects/sources/$GITLAB_GROUP_NAME/$SECOND_GROUP_NAME/$MAIN_PROJECT_NAME.git"
git push -u origin develop

# Crea il branch master come orfano con solo README.md
git checkout --orphan master
git rm -rf .  # Rimuove tutti i file dal master
echo "# $MAIN_PROJECT_NAME" > README.md
git add README.md
git commit -m "Initial commit for $MAIN_PROJECT_NAME on branch master"
git push -u origin master

echo "Branches develop and master for project $MAIN_PROJECT_NAME pushed to GitLab successfully."

# Verifica se deve saltare la creazione del progetto mock
if [ "$SKIP_MOCK" = false ]; then
    # Crea progetto parallelo con prefisso "mock" allo stesso livello del progetto principale
    MOCK_PROJECT_NAME=$(echo $MAIN_PROJECT_NAME | sed -r 's/(API_v|Service_v)/Mock\1/')

    # Verifica se il progetto mock esiste già
    MOCK_PROJECT_RESPONSE=$(curl --silent --header "Private-Token: $GITLAB_TOKEN" \
         "https://git.imolinfo.it/api/v4/groups/$SUBGROUP_ID/projects?search=$MOCK_PROJECT_NAME")

    MOCK_PROJECT_ID=$(echo $MOCK_PROJECT_RESPONSE | jq -r '.[0].id')

    if [ "$MOCK_PROJECT_ID" == "null" ] || [ -z "$MOCK_PROJECT_ID" ]; then
      echo "Creating mock project $MOCK_PROJECT_NAME on GitLab under subgroup 'rtc'..."
      MOCK_PROJECT_RESPONSE=$(curl --silent --header "Private-Token: $GITLAB_TOKEN" \
           --data "name=$MOCK_PROJECT_NAME" \
           --data "path=$MOCK_PROJECT_NAME" \
           --data "namespace_id=$SUBGROUP_ID" \
           --data "visibility=private" \
           https://git.imolinfo.it/api/v4/projects)

      MOCK_PROJECT_ID=$(echo $MOCK_PROJECT_RESPONSE | jq -r '.id')

      if [ "$MOCK_PROJECT_ID" == "null" ]; then
        echo "Error creating mock project. Exiting..."
        exit 1
      fi
      echo "Mock project $MOCK_PROJECT_NAME created with ID: $MOCK_PROJECT_ID"
    else
      echo "Mock project $MOCK_PROJECT_NAME already exists with ID: $MOCK_PROJECT_ID"
    fi

    # Creazione di una directory vuota per il progetto mock
    mkdir -p ../$MOCK_PROJECT_NAME
    cd ../$MOCK_PROJECT_NAME

    # Inizializza git nel progetto mock, crea branch develop e committa
    git init
    git checkout -b develop

    # Creazione di un README.md nel progetto mock per il branch develop
    echo "# $MOCK_PROJECT_NAME" > README.md
    git add README.md
    git commit -m "Initial commit for $MOCK_PROJECT_NAME on branch develop"

    # Configura il remote origin e fai il push del branch develop per il progetto mock
    git remote add origin "https://git.imolinfo.it/bancoBPM/Axway-Gateway-Projects/sources/$GITLAB_GROUP_NAME/$SECOND_GROUP_NAME/$MOCK_PROJECT_NAME.git"
    git push -u origin develop

    echo "Branch develop for mock project $MOCK_PROJECT_NAME pushed to GitLab successfully."
else
    echo "Skipping mock project creation as per --no-mock option."
fi

# Opzionale: Unprotect project branches
# Definisci le variabili necessarie
BRANCH_NAME="develop"  # Nome del branch da unprotectare
PROJECT_ID_FINAL=$PROJECT_ID  # Utilizza PROJECT_ID del progetto principale

# Unprotect branch 'develop' del progetto principale
echo "Unprotecting branch '$BRANCH_NAME' for project $MAIN_PROJECT_NAME..."
RESPONSE=$(curl --write-out "%{http_code}" --silent --output /dev/null --request DELETE \
  "https://git.imolinfo.it/api/v4/projects/$PROJECT_ID_FINAL/protected_branches/$BRANCH_NAME" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN")

# Verifica la risposta HTTP
if [ "$RESPONSE" == "204" ] || [ "$RESPONSE" == "200" ] || [ "$RESPONSE" == "202" ]; then
  echo "Branch '$BRANCH_NAME' unprotected successfully."
elif [ "$RESPONSE" == "404" ]; then
  echo "Branch '$BRANCH_NAME' not found or already unprotected (404)."
else
  echo "Failed to unprotect branch '$BRANCH_NAME'. HTTP status: $RESPONSE"
fi

echo "Script completato con successo!"
