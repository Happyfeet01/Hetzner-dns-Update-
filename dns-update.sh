#!/usr/bin/env bash
set -euo pipefail

########################################
# Konfiguration
########################################

# Hetzner Cloud API Token (Projekt-Token aus der Cloud Console)
HETZNER_API_TOKEN=""

# Basis-URL der Hetzner Cloud API
HETZNER_API_URL="https://api.hetzner.cloud/v1"

# Debug-Ausgabe aktivieren: DEBUG=1 bash dns-update.sh
DEBUG="${DEBUG:-0}"

# Liste der FQDNs, für die A/AAAA gesetzt werden sollen
DOMAINS=(
  "domain.tld"
  "sub.domain.tld"
)

########################################
# Hilfsfunktionen
########################################

log() {
  echo -e "$*" >&2
}

# ruft die Cloud-API auf und gibt "BODY\nHTTP_CODE" zurück
curl_hcloud() {
  local method=$1
  local path=$2
  local data=${3:-}

  local url="${HETZNER_API_URL}${path}"

  if [[ "$DEBUG" == "1" ]]; then
    log ">>> ${method} ${url}"
    [[ -n "$data" ]] && log ">>> Body: $data"
  fi

  if [[ -n "$data" ]]; then
    curl -sS -X "$method" \
      -H "Authorization: Bearer ${HETZNER_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -w "\n%{http_code}" \
      -d "$data" \
      "$url"
  else
    curl -sS -X "$method" \
      -H "Authorization: Bearer ${HETZNER_API_TOKEN}" \
      -H "Content-Type: application/json" \
      -w "\n%{http_code}" \
      "$url"
  fi
}

# Zone-Name aus FQDN ableiten (letzte zwei Labels, passt für .de/.net/.com/.space/.social etc.)
get_zone_name() {
  local fqdn=$1
  awk -F'.' '{print $(NF-1)"."$NF}' <<< "$fqdn"
}

# RR-Name innerhalb der Zone bestimmen
# apex: "@", sonst Teil vor der Zone
get_rr_name() {
  local fqdn=$1
  local zone=$2

  if [[ "$fqdn" == "$zone" ]]; then
    echo "@"
  else
    local suffix=".$zone"
    echo "${fqdn%$suffix}"
  fi
}

# A/AAAA RRSet setzen (mittels set_records)
update_rrset_ip() {
  local fqdn=$1
  local rr_type=$2   # A oder AAAA
  local ip_value=$3

  local zone rr_name response http_code body rr_count existing_value payload

  zone=$(get_zone_name "$fqdn")
  rr_name=$(get_rr_name "$fqdn" "$zone")
  rr_name=$(tr 'A-Z' 'a-z' <<< "$rr_name")

  log ""
  log "🔎 Prüfe ${fqdn} (Zone: ${zone}, RR-Name: ${rr_name}, Typ: ${rr_type})"

  # 1) RRSet suchen
  response=$(curl_hcloud "GET" "/zones/${zone}/rrsets?name=${rr_name}&type[]=${rr_type}")
  http_code=$(printf '%s\n' "$response" | tail -n1)
  body=$(printf '%s\n' "$response" | sed '$d')

  if [[ "$DEBUG" == "1" ]]; then
    log "<<< HTTP ${http_code}"
    log "<<< Body: $body"
  fi

  if [[ "$http_code" -eq 404 ]]; then
    log "⚠  Zone ${zone} nicht gefunden (HTTP 404) – stimmt Projekt/Token?"
    return
  elif [[ "$http_code" -ge 400 ]]; then
    log "⚠  Fehler beim Abrufen des RRSets (HTTP ${http_code})"
    return
  fi

  rr_count=$(jq '.rrsets | length' <<< "$body" 2>/dev/null || echo 0)

  if [[ "$rr_count" -eq 0 ]]; then
    # RRSet existiert noch nicht → neu anlegen
    log "➕ Kein ${rr_type}-RRSet vorhanden, lege neues an..."

    payload=$(jq -n \
      --arg name "$rr_name" \
      --arg type "$rr_type" \
      --arg value "$ip_value" \
      '{
        name: $name,
        type: $type,
        ttl: 60,
        records: [
          { "value": $value }
        ]
      }')

    response=$(curl_hcloud "POST" "/zones/${zone}/rrsets" "$payload")
    http_code=$(printf '%s\n' "$response" | tail -n1)
    body=$(printf '%s\n' "$response" | sed '$d')

    if [[ "$http_code" -ge 400 ]]; then
      log "❌ Fehler beim Erstellen des ${rr_type}-RRSets (HTTP ${http_code})"
      [[ "$DEBUG" == "1" ]] && log "Antwort: $body"
    else
      log "✅ ${rr_type}-RRSet erstellt: ${fqdn} → ${ip_value}"
      [[ "$DEBUG" == "1" ]] && log "Antwort: $body"
    fi
  else
    # RRSet existiert → aktuelle IP auslesen
    existing_value=$(jq -r '.rrsets[0].records[0].value // empty' <<< "$body")

    if [[ "$existing_value" == "$ip_value" ]]; then
      log "✅ ${rr_type}-RRSet bereits korrekt: ${fqdn} → ${ip_value} (keine Änderung notwendig)"
      return
    fi

    log "🔁 Ändere ${rr_type}-RRSet: ${fqdn} ${existing_value:-"<leer>"} → ${ip_value}"

    payload=$(jq -n --arg value "$ip_value" '{
      records: [
        { "value": $value }
      ]
    }')

    response=$(curl_hcloud "POST" "/zones/${zone}/rrsets/${rr_name}/${rr_type}/actions/set_records" "$payload")
    http_code=$(printf '%s\n' "$response" | tail -n1)
    body=$(printf '%s\n' "$response" | sed '$d')

    if [[ "$http_code" -ge 400 ]]; then
      log "❌ Fehler beim Setzen der Records (HTTP ${http_code})"
      [[ "$DEBUG" == "1" ]] && log "Antwort: $body"
    else
      log "✅ ${rr_type}-RRSet aktualisiert: ${fqdn} → ${ip_value}"
      [[ "$DEBUG" == "1" ]] && log "Antwort: $body"
    fi
  fi
}

########################################
# Start
########################################

CURRENT_IPV4=$(curl -s https://ipv4.icanhazip.com | tr -d '[:space:]')
CURRENT_IPV6=$(curl -s https://ipv6.icanhazip.com | tr -d '[:space:]')

log "🌍 Aktuelle IPv4 (WAN): ${CURRENT_IPV4:-"<keine>"}"
log "🌍 Aktuelle IPv6 (WAN): ${CURRENT_IPV6:-"<keine>"}"
log ""

if [[ -z "$CURRENT_IPV4" && -z "$CURRENT_IPV6" ]]; then
  log "❌ Konnte weder IPv4 noch IPv6 ermitteln – abbrechen."
  exit 1
fi

for DOMAIN in "${DOMAINS[@]}"; do
  if [[ -n "$CURRENT_IPV4" ]]; then
    update_rrset_ip "$DOMAIN" "A" "$CURRENT_IPV4"
  fi

  if [[ -n "$CURRENT_IPV6" ]]; then
    update_rrset_ip "$DOMAIN" "AAAA" "$CURRENT_IPV6"
  fi
done

log ""
log "✅ DNS-Update über Hetzner Cloud DNS abgeschlossen."
