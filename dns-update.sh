#!/bin/bash

# API-Key von Hetzner (ersetzen!)
HETZNER_API_KEY="hetzner-API-Key"

# Liste der Domains und Subdomains, die aktualisiert werden sollen
DOMAINS=(
    "domain.tld"
)

# API URL
HETZNER_API_URL="https://dns.hetzner.com/api/v1"

# Aktuelle öffentliche IPv4- und IPv6-Adresse abrufen
CURRENT_IPV4=$(curl -s https://ipv4.icanhazip.com)
CURRENT_IPV6=$(curl -s https://ipv6.icanhazip.com)

# Funktion zum Aktualisieren einer einzelnen Domain für IPv4 & IPv6
update_domain() {
    local DOMAIN=$1
    local MAIN_DOMAIN=$(echo $DOMAIN | awk -F'.' '{print $(NF-1)"."$NF}')  # Hauptdomain extrahieren
    local SUBDOMAIN=${DOMAIN/.$MAIN_DOMAIN/}

    # Falls die Subdomain leer ist (also die Hauptdomain), setze sie explizit auf "@"
    if [[ "$SUBDOMAIN" == "$DOMAIN" ]]; then
        SUBDOMAIN="@"
    fi

    # Zone-ID abrufen
    ZONE_ID=$(curl -s -H "Auth-API-Token: $HETZNER_API_KEY" "$HETZNER_API_URL/zones" | jq -r ".zones[] | select(.name==\"$MAIN_DOMAIN\") | .id")

    if [[ -z "$ZONE_ID" ]]; then
        echo "Fehler: Konnte Zone für $DOMAIN nicht finden!"
        return
    fi

    # Aktuelle DNS-Einträge abrufen
    RECORDS=$(curl -s -H "Auth-API-Token: $HETZNER_API_KEY" "$HETZNER_API_URL/records?zone_id=$ZONE_ID")

    # IPv4-A-Record aktualisieren
    RECORD_ID_A=$(echo "$RECORDS" | jq -r ".records[] | select(.name==\"$SUBDOMAIN\" and .type==\"A\") | .id")
    EXISTING_IPV4=$(echo "$RECORDS" | jq -r ".records[] | select(.name==\"$SUBDOMAIN\" and .type==\"A\") | .value")

    if [[ "$EXISTING_IPV4" == "$CURRENT_IPV4" ]]; then
        echo "[$DOMAIN] IPv4 ist aktuell ($CURRENT_IPV4), kein Update nötig."
    else
        if [[ -z "$RECORD_ID_A" ]]; then
            echo "[$DOMAIN] Erstelle neuen A-Record mit IP $CURRENT_IPV4..."
            curl -s -X POST "$HETZNER_API_URL/records" \
                -H "Auth-API-Token: $HETZNER_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{
                    \"zone_id\": \"$ZONE_ID\",
                    \"type\": \"A\",
                    \"name\": \"$SUBDOMAIN\",
                    \"value\": \"$CURRENT_IPV4\",
                    \"ttl\": 60
                }"
        else
            echo "[$DOMAIN] Aktualisiere A-Record auf $CURRENT_IPV4..."
            curl -s -X PUT "$HETZNER_API_URL/records/$RECORD_ID_A" \
                -H "Auth-API-Token: $HETZNER_API_KEY" \
                -H "Content-Type: application/json" \
                -d "{
                    \"zone_id\": \"$ZONE_ID\",
                    \"type\": \"A\",
                    \"name\": \"$SUBDOMAIN\",
                    \"value\": \"$CURRENT_IPV4\",
                    \"ttl\": 60
                }"
        fi
    fi

    # IPv6-AAAA-Record aktualisieren
    if [[ -n "$CURRENT_IPV6" ]]; then
        RECORD_ID_AAAA=$(echo "$RECORDS" | jq -r ".records[] | select(.name==\"$SUBDOMAIN\" and .type==\"AAAA\") | .id")
        EXISTING_IPV6=$(echo "$RECORDS" | jq -r ".records[] | select(.name==\"$SUBDOMAIN\" and .type==\"AAAA\") | .value")

        if [[ "$EXISTING_IPV6" == "$CURRENT_IPV6" ]]; then
            echo "[$DOMAIN] IPv6 ist aktuell ($CURRENT_IPV6), kein Update nötig."
        else
            if [[ -z "$RECORD_ID_AAAA" ]]; then
                echo "[$DOMAIN] Erstelle neuen AAAA-Record mit IP $CURRENT_IPV6..."
                curl -s -X POST "$HETZNER_API_URL/records" \
                    -H "Auth-API-Token: $HETZNER_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d "{
                        \"zone_id\": \"$ZONE_ID\",
                        \"type\": \"AAAA\",
                        \"name\": \"$SUBDOMAIN\",
                        \"value\": \"$CURRENT_IPV6\",
                        \"ttl\": 60
                    }"
            else
                echo "[$DOMAIN] Aktualisiere AAAA-Record auf $CURRENT_IPV6..."
                curl -s -X PUT "$HETZNER_API_URL/records/$RECORD_ID_AAAA" \
                    -H "Auth-API-Token: $HETZNER_API_KEY" \
                    -H "Content-Type: application/json" \
                    -d "{
                        \"zone_id\": \"$ZONE_ID\",
                        \"type\": \"AAAA\",
                        \"name\": \"$SUBDOMAIN\",
                        \"value\": \"$CURRENT_IPV6\",
                        \"ttl\": 60
                    }"
            fi
        fi
    fi
}

# Script für alle Domains ausführen
for DOMAIN in "${DOMAINS[@]}"; do
    update_domain "$DOMAIN"
done

echo "DNS-Update abgeschlossen!"
