# 📋 Zusammenfassung: MariaDB Separation - Alle Dateien

## 🎯 Hauptänderungen

### Was wurde geändert?
1. **MariaDB** läuft jetzt in einem separaten Container
2. **Alle Konfigurationen** sind zentral in der `.env` Datei
3. **Automatische Initialisierung** der Datenbanken beim ersten Start
4. **Health Checks** stellen sicher, dass MariaDB bereit ist
5. **Persistente Daten** durch Docker Volumes

## 📁 Alle Dateien im Überblick

### Root-Verzeichnis: `/pkmn-wfc-server/`

#### 1. `.env`
```
Pfad: ./env
Inhalt: Alle Umgebungsvariablen (Passwörter, Container-Namen, etc.)
```

#### 2. `docker-compose.yml`
```
Pfad: ./docker-compose.yml
Wichtigste Änderungen:
- Neuer mariadb Service
- Health Check für MariaDB
- Depends_on mit condition: service_healthy
- Shared Network: pkmn-network
- Volume für persistente Daten
```

### MariaDB-Konfiguration: `/pkmn-wfc-server/mariadb/`

#### 3. `mariadb/conf.d/custom.cnf`
```
Pfad: ./mariadb/conf.d/custom.cnf
Zweck: MariaDB Konfiguration (case-insensitive tables)
```

#### 4. `mariadb/init/01-create-databases.sh`
```
Pfad: ./mariadb/init/01-create-databases.sh
Zweck: Erstellt Datenbanken und User beim ersten Start
WICHTIG: chmod +x nicht vergessen!
```

### Pokemon Server: `/pkmn-wfc-server/pkmn-server/`

#### 5. `pkmn-server/Dockerfile`
```
Pfad: ./pkmn-server/Dockerfile
Wichtigste Änderungen:
- MariaDB wird NICHT mehr installiert
- Verwendet mysql-client statt mariadb-server
- Alle localhost/gts werden durch ${MARIADB_HOST} ersetzt
- Entrypoint wartet auf MariaDB
- Datenbank-Befehle verwenden Remote-Host
```

#### 6. `pkmn-server/openssl-1.1.1m.tar.gz`
```
Pfad: ./pkmn-server/openssl-1.1.1m.tar.gz
Status: Unverändert (muss vorhanden sein)
```

### DNS: `/pkmn-wfc-server/dnsmasq/`

#### 7. `dnsmasq/wfc.conf`
```
Pfad: ./dnsmasq/wfc.conf
Status: Unverändert (von dir bereits erstellt)
```

## 🔑 Wichtige Konfigurationspunkte

### Im Dockerfile geändert:

```dockerfile
# VORHER (Build Stage):
find ./ -name *.config | xargs -n 1 sed -i -e 's/connectionString="Server=gts;/connectionString="Server=localhost;/g'

# NACHHER (Build Stage):
find ./ -name *.config | xargs -n 1 sed -i -e "s/connectionString=\"Server=gts;/connectionString=\"Server=${MARIADB_HOST};/g"
find ./ -name *.config | xargs -n 1 sed -i -e "s/connectionString=\"Server=localhost;/connectionString=\"Server=${MARIADB_HOST};/g"
```

### Im Dockerfile geändert (Runtime):

```dockerfile
# VORHER:
service mariadb start
mysql --user=root ...

# NACHHER:
mysql -h${MARIADB_HOST} -uroot -p${MARIADB_ROOT_PASSWORD} ...
```

### Entrypoint-Skript:

```bash
# Neu hinzugefügt: Warten auf MariaDB
until mysql -h${MARIADB_HOST} -uroot -p${MARIADB_ROOT_PASSWORD} -e 'SELECT 1' >/dev/null 2>&1; do
    echo 'MariaDB is unavailable - sleeping'
    sleep 2
done
```

## 🚀 Schnellstart-Checkliste

- [ ] Alle Ordner erstellen: `mkdir -p pkmn-wfc-server/{dnsmasq,mariadb/{conf.d,init},pkmn-server}`
- [ ] `.env` Datei erstellen und anpassen
- [ ] `docker-compose.yml` im Root ablegen
- [ ] `Dockerfile` nach `pkmn-server/` kopieren
- [ ] `openssl-1.1.1m.tar.gz` nach `pkmn-server/` kopieren
- [ ] `custom.cnf` nach `mariadb/conf.d/` kopieren
- [ ] `01-create-databases.sh` nach `mariadb/init/` kopieren
- [ ] `chmod +x mariadb/init/01-create-databases.sh` ausführen
- [ ] `wfc.conf` in `dnsmasq/` erstellen (falls noch nicht vorhanden)
- [ ] `docker-compose up -d` ausführen

## 🔍 Verbindungs-Schema

```
┌─────────────┐
│   dnsmasq   │ (DNS Resolution)
└─────────────┘
       │
       │ Port 53/UDP
       ▼
┌─────────────────────────────────────┐
│          pkmn-server                │
│  ┌─────────────────────────────┐   │
│  │  Apache + Mono (GTS/CoWFC)  │   │
│  │  Python (DWC Server)        │   │
│  └─────────────────────────────┘   │
│              │                      │
│              │ mysql-client         │
│              ▼                      │
│     MariaDB Connection              │
│     Host: mariadb-pkmn             │
└─────────────────────────────────────┘
                │
                │ TCP Connection
                │ (pkmn-network)
                ▼
       ┌─────────────────┐
       │  mariadb-pkmn   │
       │  ┌───────────┐  │
       │  │  cowfc DB │  │
       │  │  gts DB   │  │
       │  └───────────┘  │
       │   Port 3306     │
       └─────────────────┘
```

## 📊 Datenbank-Verbindungen im Detail

### CoWFC Web-Config:
```ini
# In: /var/www/config.ini
db_host = mariadb-pkmn  # (von ${MARIADB_HOST})
db_user = cowfc
db_pass = cowfc
db_name = cowfc
```

### GTS Connection String:
```xml
<!-- In: pkmn-classic-framework *.config files -->
<connectionString>
  Server=mariadb-pkmn;  <!-- Ersetzt: localhost/gts -->
  Database=gts;
  User ID=gts;
  Password=gts;
</connectionString>
```

## ⚙️ Umgebungsvariablen Verwendung

### Build-Zeit (ARG):
- Werden während `docker build` verwendet
- Für statische Konfiguration im Image

### Laufzeit (ENV):
- Werden während `docker run` verwendet
- Für dynamische Verbindungen zur Datenbank

```dockerfile
# Build-Zeit
ARG MARIADB_HOST
# Ersetzt Werte in Konfigurationsdateien

# Laufzeit
ENV MARIADB_HOST=${MARIADB_HOST}
# Verwendet in Entrypoint-Skripten und zur Laufzeit
```

## 🐛 Debugging-Befehle

```bash
# MariaDB Logs
docker-compose logs -f mariadb

# Pokemon Server Logs
docker-compose logs -f pkmn-server

# In MariaDB Container
docker exec -it mariadb-pkmn mysql -uroot -p

# Teste CoWFC DB
docker exec -it mariadb-pkmn mysql -ucowfc -pcowfc cowfc -e "SHOW TABLES;"

# Teste GTS DB
docker exec -it mariadb-pkmn mysql -ugts -pgts gts -e "SHOW TABLES;"

# Netzwerk-Check
docker network inspect pkmn-network

# Verbindungstest vom pkmn-server
docker exec -it pkmn-server mysql -h mariadb-pkmn -uroot -p[PASSWORD] -e "SELECT 1;"
```

## 📝 Wichtige Hinweise

1. **Erste Start dauert länger**: Das GTS-Setup mit Wine kann 5-10 Minuten dauern
2. **Passwörter ändern**: Ändere ALLE Passwörter in der `.env` vor dem ersten Start
3. **Port-Konflikte**: Stelle sicher, dass Port 3306 nicht bereits verwendet wird
4. **Backup**: Die Datenbank liegt im Volume `pkmn-mariadb-data`
5. **Clean Install**: `docker-compose down -v` löscht ALLE Daten!

## ✅ Erfolgs-Indikatoren

Nach `docker-compose up -d` solltest du sehen:

```bash
# Container laufen
docker-compose ps
# Alle sollten "Up" und "healthy" sein

# Logs zeigen
docker-compose logs pkmn-server | grep "Starting DWC"
# Sollte "Starting DWC Network Server..." zeigen

# Datenbanken existieren
docker exec -it mariadb-pkmn mysql -uroot -p[PASSWORD] -e "SHOW DATABASES;"
# Sollte 'cowfc' und 'gts' auflisten
```

## 🎉 Fertig!

Dein Pokemon WiFi Server läuft jetzt mit separater MariaDB!

Admin-Panel: http://[DEINE-IP]/?page=admin&section=Dashboard
