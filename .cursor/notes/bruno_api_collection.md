# Bruno API Collection - Construct-X Eclipse Dataspace Connector

## Übersicht

Die Bruno Collection `tx-umbrella` enthält umfassende API-Tests für Eclipse Dataspace Connector (EDC) im Rahmen von Construct-X (Nachfolgeprojekt von Tractus-X). Die Collection demonstriert den vollständigen Datenaustauch-Workflow zwischen Provider und Consumer Connectors.

## Collection-Struktur

### Basis-Konfiguration
- **Collection Name**: `tx-umbrella`
- **Bruno Version**: 1
- **Hauptvariablen** (in `collection.bru`):
  - `providerUrl`: `https://dataprovider-x-controlplane.construct-x.prod-k8s.eecc.de`
  - `consumerUrl`: `https://dataprovider-x-controlplane.construct-x.borrmann.dev`
  - `providerBpn`/`consumerBpn`: `BPNL00000000080L`
  - `providerApiKey`/`consumerApiKey`: `TEST2`

### Externe Services
- **SSI DIM Wallet**: `https://ssi-dim-wallet-stub.e34eabb8a136438fafe9.germanywestcentral.aksapp.io`
- **Central IDP**: `https://centralidp.e34eabb8a136438fafe9.germanywestcentral.aksapp.io`
- **Portal Backend**: `https://portal-backend.e34eabb8a136438fafe9.germanywestcentral.aksapp.io`
- **Submodel Server**: `https://submodelserver.e34eabb8a136438fafe9.germanywestcentral.aksapp.io`

## API-Kategorien und Workflows

### 1. Health Check & Monitoring
- **EDC HealthCheck**: `GET {{consumerUrl}}/api/check/liveness`
- Basis-Verfügbarkeitsprüfung für EDC-Instanzen

### 2. Provider-Seite: Asset & Contract Management

#### Asset Management (`Provider/EDC/Assets/`)
- **Create Asset**: `POST {{providerUrl}}/management/v3/assets`
  - Erstellt neue Datenassets mit DataAddress (HttpData-Typ)
  - Beispiel: Proxy zu `https://jsonplaceholder.typicode.com/todos`
  - Unterstützt Proxy-Features: Path, Method, QueryParams, Body
- **Get Assets**: `GET {{providerUrl}}/management/v3/assets`
- **Get Asset By Id**: `GET {{providerUrl}}/management/v3/assets/{id}`
- **Update/Delete Asset**: Entsprechende CRUD-Operationen

#### Policy Management (`Provider/EDC/Policies/`)
- **Create Policy**: `POST {{providerUrl}}/management/v3/policydefinitions`
  - Verwendet Catena-X Policy Profile (`cx-policy:profile2405`)
  - Business Partner Number (BPN) basierte Zugriffskontrolle
  - ODRL-konforme Policy-Definitionen
- **Get Policies**: Auflisten aller verfügbaren Policies

#### Contract Management (`Provider/EDC/Contracts/`)
- **Create Contract**: `POST {{providerUrl}}/management/v3/contractdefinitions`
  - Verknüpft Assets mit Policies über `assetsSelector`
  - Definiert Access- und Contract-Policies
- **Get Contracts**: Verwaltung von Contract Definitions

#### Agreement Management (`Provider/EDC/Agreements/`)
- **Get Agreements**: `GET {{providerUrl}}/management/v3/contractagreements`
- Überwachung abgeschlossener Verträge

### 3. Consumer-Seite: Discovery & Data Access

#### Catalog Discovery (`Consumer/`)
- **Request Catalog**: `POST {{consumerUrl}}/management/v3/catalog/request`
  - Dataspace Protocol HTTP für Connector-zu-Connector Kommunikation
  - Automatische Extraktion von Offer-IDs und Policy-Details
  - Unterstützt sowohl Objekt- als auch Array-Formate für `dcat:dataset`

#### Contract Negotiation & EDR
- **Init EDR**: `POST {{consumerUrl}}/management/v3/edrs`
  - Endpoint Data Reference (EDR) Initiierung
  - Automatische Contract Request Erstellung
  - Policy-Übertragung vom Catalog Request
- **Query Cached EDR**: Abfrage zwischengespeicherter EDRs
- **Get AuthCode**: Extraktion von Authorization Codes aus EDR

#### Data Access
- **Get data**: `GET {{dataplanePublicEndpoint}}`
  - Direkter Datenzugriff über EDR Authorization
  - Header: `Authorization: {{authCode}}`

### 4. Authentication & Identity

#### Central IDP Integration (`Authentication/`)
- **Get Access Token**: `POST {{centralidpUrl}}/auth/realms/CX-Central/protocol/openid-connect/token`
  - OpenID Connect Client Credentials Flow
  - Client: `satest01` mit entsprechendem Secret

#### SSI DIM Wallet (`SSI DIM Wallet/`)
- **Create a Wallet**: `POST {{walletUrl}}/api/dim/setup-dim`
  - Decentralized Identity Management (DIM) Setup
  - DID Document Location: `did:web:ssi-dim-wallet-stub...`
- **API Credentials/Issuer**: Credential-Management für SSI

### 5. Portal Backend Integration (`Portal-Backend/`)
- **Register a Connector**: `POST {{portalBackendUrl}}/api/administration/Connectors`
  - Connector-Registrierung im Construct-X Portal
  - Multipart Form Data mit Connector-Details
- **Add Data to Clearing House**: Datenregistrierung
- **Verify Checklist**: Compliance-Prüfungen

### 6. Submodel Server (`Provider/Submodel Server/`)
- **Upload Data**: `POST {{submodelServer}}/test`
  - Digital Product Passport (DPP) Datenstrukturen
  - Umfassende Metadaten: Materialzusammensetzung, Nachhaltigkeit, Handling
  - Catena-X konforme Datenmodelle
- **Get Data**: Abruf von Submodel-Daten

## Technische Details

### API-Authentifizierung
- **API Key Authentication**: `X-Api-Key` Header
- **Bearer Token**: Für Portal Backend APIs
- **EDR Authorization**: Für Dataplane-Zugriff

### Dataspace Protocol
- **Protocol**: `dataspace-protocol-http`
- **DSP Endpoint**: `{{providerUrl}}/api/v1/dsp`
- **Management API**: Version v3 (aktueller Standard)

### Policy Framework
- **ODRL**: Open Digital Rights Language für Policy-Definitionen
- **Catena-X Profile**: `cx-policy:profile2405`
- **BPN-basierte Zugriffskontrolle**: Business Partner Number Validierung

### Datenmodelle
- **JSON-LD Context**: W3C-konforme Linked Data Kontexte
- **EDC Namespace**: `https://w3id.org/edc/v0.0.1/ns/`
- **Catena-X Ontology**: Spezifische Automotive-Datenmodelle

## Workflow-Beispiele

### Vollständiger Provider-Setup
1. **Create Policy** → Policy-Definition mit BPN-Constraint
2. **Create Asset** → Datenasset mit HttpData DataAddress
3. **Create Contract** → Contract Definition verknüpft Asset und Policy
4. **Verify** → Get Assets/Contracts/Policies zur Bestätigung

### Consumer Data Access Flow
1. **Request Catalog** → Discovery verfügbarer Assets
2. **Init EDR** → Contract Negotiation mit automatischer Policy-Übertragung
3. **Query Cached EDR** → Warten auf EDR-Verfügbarkeit
4. **Get AuthCode** → Extraktion des Authorization Codes
5. **Get data** → Direkter Datenzugriff über Dataplane

### Integration mit Construct-X Ecosystem
1. **Authentication** → Central IDP Token für Portal-Zugriff
2. **Register Connector** → Portal Backend Registrierung
3. **Create Wallet** → SSI DIM Wallet für Identity Management
4. **Upload Data** → Submodel Server für strukturierte Daten

## Besonderheiten

### Automatisierte Script-Logik
- **Post-Response Scripts**: Automatische Extraktion von IDs und Tokens
- **Variable Management**: Dynamische Aktualisierung von Collection-Variablen
- **Error Handling**: Robuste Behandlung verschiedener Response-Formate

### Construct-X Spezifika
- **BPN Integration**: Business Partner Number als zentrale Identität
- **Digital Product Passport**: Umfassende Produktdatenmodelle
- **SSI Integration**: Self-Sovereign Identity über DIM Wallet
- **Portal Integration**: Zentrale Connector-Verwaltung

### Development & Testing
- **Flexible Environments**: Verschiedene Deployment-Targets
- **Test Data**: Vorkonfigurierte Beispieldaten für alle Workflows
- **API Key Management**: Einfache Authentifizierung für Development

## DSP Workflow Automation

### Vollautomatisiertes Script
- **`bruno/dsp-workflow.sh`**: Komplettes DSP Workflow Automatisierungsscript
  - **End-to-End Automation**: Vollständiger Workflow von Provider-Setup bis Datenabruf
  - **Resource Management**: Intelligente Wiederverwendung existierender Ressourcen
  - **Dynamic Parsing**: Automatische Extraktion von IDs, Tokens und Endpoints
  - **Environment Configuration**: Flexible Konfiguration über `.env` Datei
  - **Error Handling**: Umfassende Fehlerbehandlung und benutzerfreundliche Ausgabe

### Workflow-Schritte
1. **Provider Setup**: Policy → Asset → Contract Definition (mit Existenz-Checks)
2. **Consumer Workflow**: Catalog Request → EDR Negotiation → Auth Code → Data Access
3. **Health Checks**: Connector-Verfügbarkeit vor Workflow-Start
4. **Success Validation**: Anzeige der erfolgreich abgerufenen Daten

### Konfiguration
```bash
# Kopiere Template und konfiguriere
cp bruno/env.example bruno/.env
# Bearbeite .env mit deinen Connector-URLs und Credentials
./bruno/dsp-workflow.sh
```

## Referenzen zu anderen Notes
- **[current_deployment.md](current_deployment.md)**: Aktuelle EDC-Deployment-Konfiguration
- **[index.md](index.md)**: Projekt-Übersicht und Lifecycle-Management
- **[service_testing.md](service_testing.md)**: Service Testing und Bruno Integration
