#!/bin/sh

set -eu

echo "Initializing databases..."

# Read all SETUP_DB_* env variables
for i in $(env | grep SETUP_DB_ | awk -F'=' '{print $2}'); do
    # Split the tuple into name, user, and password
    IFS=',' read -r db_name db_user db_password <<EOF
$i
EOF

    # Validate the input
    if [ -z "${db_name:?}" ] || [ -z "${db_user:?}" ] || [ -z "${db_password:?}" ]; then
        echo "Invalid database setup: $i" >&2
        echo "Please provide a comma-separated list of database name, user, and password" >&2
        exit 1
    fi

    echo "Creating database: $db_name with user: $db_user"
    mariadb -u root -p"${MARIADB_ROOT_PASSWORD:?Missing db root pass}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${db_name:?}\`;
CREATE USER IF NOT EXISTS '${db_user:?}'@'%' IDENTIFIED BY '${db_password:?}';
GRANT ALL PRIVILEGES ON \`${db_name:?}\`.* TO '${db_user:?}'@'%';
FLUSH PRIVILEGES;
EOF
done
