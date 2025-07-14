# Procedura esecuzione Maven Archetype Test JUnit (partendo da un progetto completo al netto della cartella test)

1. dalla cartella */Resources* lanciare il comando:
    ```bash
    mvn archetype:generate "-DarchetypeGroupId=it.imolainformatica.archetype" "-DarchetypeArtifactId=test-junit" "-DarchetypeVersion=1.0.0-SNAPSHOT" "-DgroupId=it.imolinfo" "-DartifactId=test"
    ```
1. seguire la procedura interattiva che richiede di valorizzare:
	- **applicationCode** (es. *APIAC*)
	- **serviceName** (es. *AnagrafeClientiService_v1*)
	- **version** (es. *1.0-SNAPSHOT*)
1. modificare nel *pom.xml* generato il valore della property `<nomePackage>` (es. *${project.groupId}.apiac.anagrafeclienti.v1*)
1. inserire valori per **ServiceEndpoint** nei file *.properties*
1. lanciare il comando 
    ```bash
    mvn clean generate-test-sources
    ```
1. lanciare il comando 
    ```bash
    mvn frameworktestjunitgenerator:frameworktestjunitgenerator
    ```
1. valorizzare il file Excel datasources con i dati di test
1. eseguire i test con il comando 
    ```bash
    mvn clean test -P <nome_profilo> 
    ```



**Comandi generazione:**
- mvn archetype:generate "-DarchetypeGroupId=it.imolainformatica.archetype" "-DarchetypeArtifactId=test-junit" "-DarchetypeVersion=1.0.0-SNAPSHOT" "-DgroupId=it.imolinfo" "-DartifactId=test"
- mvn archetype:generate "-DarchetypeGroupId=it.imolainformatica.archetype" "-DarchetypeArtifactId=test-junit" "-DarchetypeVersion=1.0.0-SNAPSHOT"
- mvn archetype:generate "-DarchetypeGroupId=it.imolainformatica.archetype" "-DarchetypeArtifactId=test-junit" "-DarchetypeVersion=1.0.0-SNAPSHOT"
