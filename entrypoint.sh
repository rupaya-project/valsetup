#!/bin/bash

set -e

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to log errors
error_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >&2
}

# Trap errors
trap 'error_log "An error occurred. Exiting."; exit 1' ERR

# Read secrets
log "Reading secrets..."
PRIVATE_KEY=$(cat /run/secrets/node_private_key)
PASSWORD_FILE=/run/secrets/node_password

# Get external IP
log "Getting external IP..."
EXTERNAL_IP=$(curl -s https://api.ipify.org)
if [ -z "$EXTERNAL_IP" ]; then
    log "Failed to get external IP. Falling back to 0.0.0.0"
    EXTERNAL_IP="0.0.0.0"
fi
log "External IP: $EXTERNAL_IP"

# Check if the genesis block needs to be initialized
if [ ! -d /root/.ethereum/geth/chaindata ]; then
    log "Initializing genesis block..."
    geth init /root/genesis.json
    log "Genesis block initialized."
else
    log "Genesis already initialized."
fi

# Function to get account address
get_account() {
    geth account list | grep -o '[a-fA-F0-9]\{40\}' | head -n1
}

# Check for existing account
ACCOUNT=$(get_account)

# Import private key only if no account exists
if [ -z "$ACCOUNT" ] && [ "$IMPORT_PRIVATE_KEY" = "true" ]; then
    log "No existing account found. Attempting to import private key..."
    IMPORT_OUTPUT=$(geth account import --password $PASSWORD_FILE <(echo $PRIVATE_KEY) 2>&1)
    log "Import output: $IMPORT_OUTPUT"
    ACCOUNT=$(get_account)
fi

if [ -z "$ACCOUNT" ]; then
    error_log "No account found. Cannot proceed."
    exit 1
fi

log "Using account: 0x$ACCOUNT"

# Construct the geth command
log "Constructing geth command..."
CMD="geth --networkid ${NETWORK_ID} \
  --syncmode ${SYNCMODE} \
  --gcmode ${GCMODE} \
  --bootnodes ${BOOTNODES} \
  --mine \
  --miner.etherbase 0x${ACCOUNT} \
  --nat extip:${EXTERNAL_IP} \
  --verbosity ${VERBOSITY}"

# Execute the command
log "Executing geth command..."
exec $CMD