#!/bin/sh -eu

# Get database connection details from environment variables
MARIADB_HOST="${MARIADB_HOST:-mariadb}"
MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-rootpassword}"

COWFC_DB_USER="${COWFC_DB_USER:-cowfc}"
COWFC_DB_PASSWORD="${COWFC_DB_PASSWORD:-cowfc}"
COWFC_DB_NAME="${COWFC_DB_NAME:-cowfc}"

GTS_DB_USER="${GTS_DB_USER:-gts}"
GTS_DB_PASSWORD="${GTS_DB_PASSWORD:-gts}"
GTS_DB_NAME="${GTS_DB_NAME:-gts}"

ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-opensesame}"

# Wait for MariaDB to be ready
echo "Waiting for MariaDB at $MARIADB_HOST..."
until mysqladmin ping -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" --silent 2>/dev/null; do
    echo "MariaDB is unavailable - sleeping"
    sleep 2
done
echo "MariaDB is up!"

# Check if cowfc database exists
DB_EXISTS=$(mysql -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" -e "SHOW DATABASES LIKE '${COWFC_DB_NAME}';" 2>/dev/null | grep -c "${COWFC_DB_NAME}" || true)

if [ "$DB_EXISTS" -eq "0" ]; then
    echo "Initializing CoWFC database..."
    
    # Create cowfc database and user
    mysql -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" <<EOF
CREATE DATABASE ${COWFC_DB_NAME};
CREATE USER '${COWFC_DB_USER}'@'%' IDENTIFIED BY '${COWFC_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${COWFC_DB_NAME}.* TO '${COWFC_DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    
    # Import cowfc schema
    mysql -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" "${COWFC_DB_NAME}" < /var/www/CoWFC/SQL/cowfc.sql
    
    # Create admin user
    echo "Creating admin user..."
    HASH=$(/var/www/CoWFC/SQL/bcrypt-hash "$ADMIN_PASSWORD")
    mysql -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" "${COWFC_DB_NAME}" <<EOF
INSERT INTO users (Username, Password, Rank) 
VALUES ('${ADMIN_USERNAME}', '${HASH}', '1');
EOF
    
    echo "CoWFC database initialized!"
else
    echo "CoWFC database already exists, skipping initialization."
fi

# Check if gts database exists
DB_EXISTS=$(mysql -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" -e "SHOW DATABASES LIKE '${GTS_DB_NAME}';" 2>/dev/null | grep -c "${GTS_DB_NAME}" || true)

if [ "$DB_EXISTS" -eq "0" ]; then
    echo "Initializing GTS database..."
    
    # Create gts database and user
    mysql -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" <<EOF
CREATE DATABASE ${GTS_DB_NAME};
CREATE USER '${GTS_DB_USER}'@'%' IDENTIFIED BY '${GTS_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${GTS_DB_NAME}.* TO '${GTS_DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    
    # Import gts dump
    mysql -h "$MARIADB_HOST" -u root -p"$MARIADB_ROOT_PASSWORD" "${GTS_DB_NAME}" < /gts_dump.sql
    
    echo "GTS database initialized!"
else
    echo "GTS database already exists, skipping initialization."
fi

# Start Apache
echo "Starting Apache..."
apachectl start

# Start dwc_network_server_emulator
echo "Starting DWC Network Server Emulator..."
cd /var/www/dwc_network_server_emulator
python master_server.py &
DWC_PID=$!

# SQLite allowed_games Check/Insert
DWC_DB_PATH="/var/www/dwc_network_server_emulator/gpcm.db"
echo "Checking for 'allowed_games' table in DWC database..."

# Check if allowed_games table exists
TABLE_EXISTS=$(sqlite3 "$DWC_DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='allowed_games';" 2>/dev/null || echo "")

if [ -z "$TABLE_EXISTS" ]; then
    echo "⚠️  'allowed_games' table NOT found - creating and populating..."
    
    # Create table and populate with all Pokémon game codes
    sqlite3 "$DWC_DB_PATH" "
    -- Create table if not exists
    CREATE TABLE IF NOT EXISTS allowed_games (
        gameid TEXT PRIMARY KEY,
        gamecd TEXT
    );
    
    -- Clean up any bad entries
    DELETE FROM allowed_games WHERE gameid = '' OR gamecd IS NULL OR gamecd = '';
    
    -- Pokémon Diamond/Pearl/Platinum (Gen 4)
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('ADA', '01'); -- Diamond All
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('ADAE', '01'); -- Diamond USA
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('ADAP', '01'); -- Diamond EUR
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('ADAJ', '01'); -- Diamond JPN
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('APA', '01'); -- Pearl All
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('APAE', '01'); -- Pearl USA
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('APAP', '01'); -- Pearl EUR
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('APAJ', '01'); -- Pearl JPN
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('CPU', '01'); -- Platinum All
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('CPUE', '01'); -- Platinum USA
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('CPUP', '01'); -- Platinum EUR
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('CPUJ', '01'); -- Platinum JPN
    
    -- Pokémon HeartGold/SoulSilver (Gen 4)
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IPK', '01'); -- HeartGold All
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IPKE', '01'); -- HeartGold USA
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IPKP', '01'); -- HeartGold EUR
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IPKJ', '01'); -- HeartGold JPN
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IPG', '01'); -- SoulSilver All
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IPGE', '01'); -- SoulSilver USA
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IPGP', '01'); -- SoulSilver EUR
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IPGJ', '01'); -- SoulSilver JPN
    
    -- Pokémon Black/White (Gen 5)
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRB', '01'); -- Black All
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRBO', '01'); -- Black USA
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRBP', '01'); -- Black EUR
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRBJ', '01'); -- Black JPN
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRA', '01'); -- White All
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRAO', '01'); -- White USA
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRAP', '01'); -- White EUR
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRAJ', '01'); -- White JPN
    
    -- Pokémon Black 2/White 2 (Gen 5)
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRE', '01'); -- Black 2 All
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IREO', '01'); -- Black 2 USA
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IREP', '01'); -- Black 2 EUR
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IREJ', '01'); -- Black 2 JPN
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRD', '01'); -- White 2 All
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRDO', '01'); -- White 2 USA
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRDP', '01'); -- White 2 EUR
    INSERT OR REPLACE INTO allowed_games (gameid, gamecd) VALUES ('IRDJ', '01'); -- White 2 JPN
    "
    
    if [ $? -eq 0 ]; then
        echo "✅ 'allowed_games' table created and populated successfully!"
    else
        echo "❌ ERROR: Failed to create/populate 'allowed_games' table!"
        exit 1
    fi
else
    echo "✅ 'allowed_games' table already exists!"
    
    # Optional: Verify table has entries
    ENTRY_COUNT=$(sqlite3 "$DWC_DB_PATH" "SELECT COUNT(*) FROM allowed_games;" 2>/dev/null || echo "0")
    echo "   Found $ENTRY_COUNT game entries in database."
    
    if [ "$ENTRY_COUNT" -lt 5 ]; then
        echo "⚠️  Warning: Table has fewer than 5 entries - might be incomplete!"
        echo "   Consider repopulating with: DELETE FROM allowed_games; then re-run init"
    fi
fi

# Verify allowed_games table is now accessible
echo "Verifying 'allowed_games' table accessibility..."
if sqlite3 "$DWC_DB_PATH" "SELECT 1 FROM allowed_games LIMIT 1" >/dev/null 2>&1; then
    echo "✅ 'allowed_games' table is accessible and ready!"
else
    echo "❌ ERROR: 'allowed_games' table exists but is not accessible!"
    exit 1
fi

# Optional: Stop temporary DWC process if it was started
if [ ! -z "$DWC_PID" ]; then
    echo "Stopping temporary DWC Emulator process (PID: $DWC_PID)..."
    kill "$DWC_PID" 2>/dev/null || true
    sleep 1
fi

echo "✅ DWC database initialization complete!"

echo "All initialization complete. Starting DWC Network Server Emulator"
python master_server.py