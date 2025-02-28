# bbpm-svil-automation

*3 archetipi attuali*
1. passthrough-solo-manager-rest
2. passthrough-manager-gateway-rest
3. junit

*lo script gestisce sempre contemporanemente due archetipi (rest + junit) e crea sempre progetto e progetto mock*

## <u>ATTENZIONE</u>

Testare nel proprio Git (per non voler impattare i sources di BPM) modificare/commentare righe de **GITLAB_GROUP_ID=<id_group>**

Inoltre costruire l'indirizzo su misura alla riga commento **Configura il remote origin e fai il push del branch develop** per pushare nei propri progetti.

## Usage (run in bash shell, anche GitBash)
```
./automate.sh usage
```

## Creazione scaffholding
```
./automate.sh <sigla_nomeservizio_versione> <nome_gruppo_git>
```
*nome gruppo Git da verificare in slug (a volte nome maiuscolo, ma nello slug minuscolo)*

#### N.B. in caso di utilizzo di archetipo alternativo (al momento solo quello manager+gateway) usare il seguente comando:
```
./automate.sh <sigla_nomeservizio_versione> <nome_gruppo_git> --archetype <archetipo_alternativo>
```

### Requisiti
- file locale .env con *GITLAB_TOKEN*
- jq command line tool 
  (```pip install jq``` altrimenti (per windows) ```curl -L -o /usr/bin/jq.exe https://github.com/jqlang/jq/releases/latest/download/jq-win64.exe```)
- archetipi correttamente installati

## Installazione archetipi
- aggiornare in base ad esigenza le versioni delle dipendenze
- navigare a livello del pom.xml e lanciare il comando *mvn clean install*
- verificare la corretta installazione nella propria cartella .m2/maven (dentro it.imolainformatica.archetype.<nome_archetipo>)
- fare la stessa cosa con tutti gli archetipi