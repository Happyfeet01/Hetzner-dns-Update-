# Hetzner-dns-Update


Automatische DNS-Updates bei Hetzner per API

Wenn du deine Domains bei Hetzner DNS verwaltest und regelmäßig deren IPs aktualisieren musst, kannst du das mit einem Bash-Skript automatisieren. Das folgende Skript prüft die aktuelle IPv4- und IPv6-Adresse deines Servers und aktualisiert die DNS-Einträge über die Hetzner API.

🔹 Funktionsweise des Skripts:
	1.	Öffentliche IP-Adressen ermitteln
	•	Die aktuelle IPv4-Adresse wird von https://ipv4.icanhazip.com geholt.
	•	Die IPv6-Adresse wird von https://ipv6.icanhazip.com abgerufen.
	2.	Domain- und Subdomain-Verwaltung
	•	Eine Liste aller zu aktualisierenden Domains und Subdomains wird definiert.
	•	Jede Subdomain wird automatisch der richtigen Hauptdomain zugeordnet.
	3.	DNS-Einträge über die API verwalten
	•	Das Skript ruft die Zone-ID für die jeweilige Domain von Hetzner ab.
	•	Es überprüft, ob bereits ein A- oder AAAA-Record existiert.
	•	Falls nötig, wird der DNS-Eintrag mit der aktuellen IP erstellt oder aktualisiert.
	4.	API-Aufrufe mit curl
	•	Die Kommunikation mit der Hetzner API erfolgt über curl mit HTTP-Headern für die Authentifizierung.
	•	jq wird genutzt, um die JSON-Antworten der API zu verarbeiten.

🔹 Voraussetzungen:
	•	Ein Hetzner API-Token, den du im Hetzner DNS-Panel erstellen kannst.
	•	Ein Server mit bash, curl und jq installiert.
	•	Domains müssen bereits in Hetzner DNS angelegt sein.

🔹 Anpassungen für den eigenen Einsatz:
	•	Ersetze den API-Schlüssel in der Variablen HETZNER_API_KEY.
	•	Passe die Domainliste (DOMAINS) an deine eigenen Domains an.
	•	Falls nur IPv4 oder IPv6 aktualisiert werden soll, kann die jeweilige Funktion entfernt oder auskommentiert werden.

Dieses Skript kann per Cronjob regelmäßig ausgeführt werden, um die DNS-Einträge aktuell zu halten.

Beispiel-Cronjob:

Um das Skript alle 10 Minuten auszuführen, füge folgenden Eintrag zur crontab hinzu:

*/10 * * * * /pfad/zum/script.sh

Dadurch werden deine DNS-Einträge automatisch aktuell gehalten.