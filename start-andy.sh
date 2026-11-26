#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  printf '%s\n' "EVREN anahtarını Codespaces secret olarak OPENAI_API_KEY adıyla ekle ve Codespace'i yeniden aç." >&2
  exit 1
fi

read -rp 'Aternos Java adresi (portsuz): ' aternos_host
read -rp 'Aternos Java portu: ' aternos_port
read -rp 'Aternos sunucu sürümü (ör. 1.21.6): ' minecraft_version
read -rp 'Aternos Korsan (Cracked) ayarı açık mı? [e/h]: ' cracked

case "$cracked" in
  e|E)
    auth=offline
    bot_name=andy
    ;;
  h|H)
    auth=microsoft
    read -rp 'Andy için ayrı Microsoft hesabının Minecraft oyuncu adı: ' bot_name
    ;;
  *)
    printf '%s\n' 'Korsan ayarı için e veya h yaz.' >&2
    exit 1
    ;;
esac

SETTINGS_JSON="$(node --input-type=module - "$aternos_host" "$aternos_port" "$minecraft_version" "$auth" "$bot_name" <<'JS'
const [host, portText, minecraftVersion, auth, botName] = process.argv.slice(2);
const port = Number(portText);

function fail(message) {
  console.error(message);
  process.exit(1);
}

if (!/^[a-z0-9.-]+$/i.test(host)) fail('Java adresini http:// ve port olmadan yaz.');
if (!/^\d+$/.test(portText) || port < 1 || port > 65535) fail('Geçerli bir Java portu yaz.');
if (!/^\d+\.\d+(\.\d+)?$/.test(minecraftVersion)) fail('Aternos sunucusunda yazan sürümü gir.');
if (!/^[a-z0-9_]{3,16}$/i.test(botName)) fail('Geçerli bir Minecraft oyuncu adı yaz.');

console.log(JSON.stringify({
  host,
  port,
  minecraft_version: minecraftVersion,
  auth,
  auto_open_ui: false,
  allow_insecure_coding: false
}));
JS
)"
export SETTINGS_JSON

if [[ "$auth" == offline ]]; then
  exec node main.js --profiles ./andy.json
fi

profile_file="$(mktemp)"
trap 'rm -f -- "$profile_file"' EXIT
node --input-type=module - "$profile_file" "$bot_name" <<'JS'
import { readFileSync, writeFileSync } from 'node:fs';
const [profileFile, botName] = process.argv.slice(2);
const profile = JSON.parse(readFileSync('andy.json', 'utf8'));
profile.name = botName;
writeFileSync(profileFile, JSON.stringify(profile));
JS
node main.js --profiles "$profile_file"
