#!/bin/sh -eu

# Get database connection details from environment variables
DB_HOST="${DB_HOST:-mariadb}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-rootpassword}"

DB_COWFC_USER="${DB_COWFC_USER:-cowfc}"
DB_COWFC_PASS="${DB_COWFC_PASS:-cowfc}"
DB_COWFC_NAME="${DB_COWFC_NAME:-cowfc}"

DB_GTS_USER="${DB_GTS_USER:-gts}"
DB_GTS_PASS="${DB_GTS_PASS:-gts}"
DB_GTS_NAME="${DB_GTS_NAME:-gts}"

ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-opensesame}"

# Update CoWFC config.ini with environment variables
echo "Updating CoWFC configuration..."
cat > /var/www/config.ini <<EOF
; Make sure this file is not public-facing.
; If needed, you can change this ini's path in index.php

[main]
name = 'CoWFC'
debug = 0

[pages]
dwc_db_path = '/var/www/dwc_network_server_emulator/gpcm.db'

[admin]
db_host = ${DB_HOST}
db_user = ${DB_COWFC_USER}
db_pass = ${DB_COWFC_PASS}
db_name = ${DB_COWFC_NAME}

[reCAPTCHA]
recaptcha_enabled = 0
recaptcha_secret = SECRET_KEY_HERE
recaptcha_site = SITE_KEY_HERE
banlog_path = 'bans.log'
EOF
# Create the symbolic link
echo "Linking CoWFC configuration file..."
ln -s /var/www/config.ini /var/www/html/config.ini

# Wait for MariaDB to be ready
echo "Waiting for MariaDB at $DB_HOST..."
until mysqladmin ping -h "$DB_HOST" -u root -p"$DB_ROOT_PASSWORD" --silent 2>/dev/null; do
    echo "MariaDB is unavailable - sleeping"
    sleep 2
done
echo "MariaDB is up!"

# Check if cowfc database exists
DB_EXISTS=$(mysql -h "$DB_HOST" -u root -p"$DB_ROOT_PASSWORD" -e "SHOW DATABASES LIKE '${DB_COWFC_NAME}';" 2>/dev/null | grep -c "${DB_COWFC_NAME}" || true)

if [ "$DB_EXISTS" -eq "0" ]; then
    echo "Initializing CoWFC database..."
    
    # Create cowfc database and user
    mysql -h "$DB_HOST" -u root -p"$DB_ROOT_PASSWORD" <<EOF
CREATE DATABASE ${DB_COWFC_NAME};
CREATE USER '${DB_COWFC_USER}'@'%' IDENTIFIED BY '${DB_COWFC_PASS}';
GRANT ALL PRIVILEGES ON ${DB_COWFC_NAME}.* TO '${DB_COWFC_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    
    # Import cowfc schema
    mysql -h "$DB_HOST" -u root -p"$DB_ROOT_PASSWORD" "${DB_COWFC_NAME}" < /var/www/CoWFC/SQL/cowfc.sql
    
    # Create admin user
    echo "Creating admin user..."
    HASH=$(/var/www/CoWFC/SQL/bcrypt-hash "$ADMIN_PASSWORD")
    mysql -h "$DB_HOST" -u root -p"$DB_ROOT_PASSWORD" "${DB_COWFC_NAME}" <<EOF
INSERT INTO users (Username, Password, Rank) 
VALUES ('${ADMIN_USERNAME}', '${HASH}', '1');
EOF
    
    echo "CoWFC database initialized!"
else
    echo "CoWFC database already exists, skipping initialization."
fi

# Check if gts database exists
DB_EXISTS=$(mysql -h "$DB_HOST" -u root -p"$DB_ROOT_PASSWORD" -e "SHOW DATABASES LIKE '${DB_GTS_NAME}';" 2>/dev/null | grep -c "${DB_GTS_NAME}" || true)

if [ "$DB_EXISTS" -eq "0" ]; then
    echo "Initializing GTS database..."
    
    # Create gts database and user
    mysql -h "$DB_HOST" -u root -p"$DB_ROOT_PASSWORD" <<EOF
CREATE DATABASE ${DB_GTS_NAME};
CREATE USER '${DB_GTS_USER}'@'%' IDENTIFIED BY '${DB_GTS_PASS}';
GRANT ALL PRIVILEGES ON ${DB_GTS_NAME}.* TO '${DB_GTS_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    
    # Import gts dump
    mysql -h "$DB_HOST" -u root -p"$DB_ROOT_PASSWORD" "${DB_GTS_NAME}" < /gts_dump.sql
    
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
echo "Waiting for 'allowed_games' table to be created by DWC Emulator..."

until sqlite3 "$DWC_DB_PATH" "SELECT 1 FROM allowed_games LIMIT 1" >/dev/null 2>&1; do
    echo "SQLite 'allowed_games' table is unavailable - sleeping"
    sleep 2
done
echo "SQLite 'allowed_games' table found!"

echo "Stopping temporary DWC Emulator process (PID: $DWC_PID) to free up ports..."
kill "$DWC_PID" || true
sleep 1

# List of Gamecodes
echo "Checking and adding required DWC game codes..."

GAME_CODES="CPU APA ADA IPK IPG"
echo "Adding required game code: $GAME_CODES"
sleep 5
for CODE in $GAME_CODES; do
    # Check if Gamecodes already exist
    EXISTS=$(sqlite3 "$DWC_DB_PATH" "SELECT COUNT(*) FROM allowed_games WHERE gamecd='$CODE';" || true)

    if [ "$EXISTS" -eq "0" ]; then
        echo "  -> Adding required game code: $CODE"
        # Add Gamecodes
        sqlite3 "$DWC_DB_PATH" "INSERT INTO allowed_games (gamecd) VALUES ('$CODE');"
    else
        echo "  -> Game code $CODE already present."
    fi
done

echo "All initialization complete. Starting DWC Network Server Emulator"
python master_server.py