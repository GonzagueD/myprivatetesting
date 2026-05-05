#!/usr/bin/env bash
# ============================================================================
#  crack_wifi_v2.sh — Hashcat WPA/WPA2 PMKID cracker (mode 22000)
#  Version XXL : 12+ dictionnaires, attaques hybrides & combinatoires
#  Prévu pour RTX 4090 (Vast.ai / Runpod)
# ============================================================================
set -euo pipefail

# ── CONFIG ──────────────────────────────────────────────────────────────────
CAPTURES_DIR="./captures"
DICTS_DIR="./dicts"
RULES_DIR="./rules"
RESULTS_DIR="./results"
HASHCAT_BIN="hashcat"
MODE=22000

# GitHub repo pour les fichiers .22000 (à personnaliser)
GITHUB_REPO=""   # Ex: "https://github.com/GonzagueD/myprivatetesting"

# Optimisation RTX 4090
WORKLOAD=4
OPTIMIZED_KERNELS="--optimized-kernel-enable"

# ── COULEURS ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║   WiFi PMKID Cracker v2 — FR Dictionaries XXL Edition  ║"
    echo "  ║   12+ dicos · hybrides · combinatoires · brute-force   ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${MAGENTA}[i]${NC} $*"; }

# ── HELPERS ─────────────────────────────────────────────────────────────────
dl() {
    # dl <url> <output> — télécharge silencieusement avec fallback curl
    local url="$1" out="$2"
    wget -q --show-progress --timeout=30 -O "$out" "$url" 2>/dev/null \
        || curl -sL --connect-timeout 30 -o "$out" "$url" 2>/dev/null
}

safe_gunzip() {
    local f="$1"
    if file "$f" 2>/dev/null | grep -q gzip; then
        gunzip -f "$f"
    elif [[ "$f" == *.gz ]]; then
        mv "$f" "${f%.gz}"
    fi
}

check_cracked() {
    # Retourne 0 si le hash est cracké
    local capture="$1" potfile="$2"
    $HASHCAT_BIN -m $MODE "$capture" --show --potfile-path "$potfile" 2>/dev/null | grep -q ":" 2>/dev/null
}

show_cracked() {
    local capture="$1" potfile="$2"
    echo -e "  ${GREEN}${BOLD}🎉 MOT DE PASSE TROUVÉ !${NC}"
    $HASHCAT_BIN -m $MODE "$capture" --show --potfile-path "$potfile" 2>/dev/null
    echo ""
}

hc_attack() {
    # hc_attack <capture> <potfile> <outfile> [extra args...]
    local capture="$1" potfile="$2" outfile="$3"
    shift 3
    $HASHCAT_BIN -m $MODE \
        -w "$WORKLOAD" \
        $OPTIMIZED_KERNELS \
        --potfile-path "$potfile" \
        --outfile "$outfile" \
        --outfile-format 2 \
        --status --status-timer 30 \
        "$@" \
        "$capture" \
        2>/dev/null || true
}

# ── CRÉATION DES DOSSIERS ───────────────────────────────────────────────────
setup_dirs() {
    mkdir -p "$CAPTURES_DIR" "$DICTS_DIR" "$RULES_DIR" "$RESULTS_DIR"
}

# ── FETCH CAPTURES DEPUIS GITHUB ───────────────────────────────────────────
fetch_captures_from_github() {
    if [[ -n "$GITHUB_REPO" ]]; then
        log "Récupération des captures depuis GitHub..."
        local tmpdir
        tmpdir=$(mktemp -d)
        git clone --depth 1 "$GITHUB_REPO" "$tmpdir/repo" 2>/dev/null || {
            warn "Clone échoué, tentative wget..."
            # Essaye de télécharger les fichiers .22000 via l'API GitHub
            return 1
        }
        find "$tmpdir/repo" -name "*.22000" -exec cp {} "$CAPTURES_DIR/" \;
        local count
        count=$(find "$CAPTURES_DIR" -name "*.22000" | wc -l)
        log "  → $count fichiers .22000 récupérés"
        rm -rf "$tmpdir"
    fi
}

# ── INSTALLATION ────────────────────────────────────────────────────────────
install_deps() {
    log "Vérification des dépendances..."

    if ! command -v hashcat &>/dev/null; then
        warn "hashcat non trouvé, installation..."
        apt-get update -qq && apt-get install -y -qq hashcat wget curl git p7zip-full
    fi

    if ! command -v nvidia-smi &>/dev/null; then
        err "nvidia-smi non trouvé — vérifie les drivers NVIDIA"
        exit 1
    fi

    log "GPU détecté :"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
    echo ""
}

# ════════════════════════════════════════════════════════════════════════════
#  DICTIONNAIRES — 12+ sources
# ════════════════════════════════════════════════════════════════════════════

download_dicts() {
    log "Téléchargement des dictionnaires (12+ sources)..."
    echo ""
    local n=0 total=12

    # ── 1. RockYou (~14M, le classique absolu) ──────────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/rockyou.txt" ]]; then
        log "  [$n/$total] rockyou.txt (~14M lignes, ~140 Mo)"
        dl "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" \
           "$DICTS_DIR/rockyou.txt"
    else
        log "  [$n/$total] rockyou.txt ✓"
    fi

    # ── 2. Richelieu Top 20k (MDP FR réels) ─────────────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/richelieu-french-top20000.txt" ]]; then
        log "  [$n/$total] Richelieu — Top 20k MDP français"
        dl "https://raw.githubusercontent.com/tarraschk/richelieu/master/richelieu-french-top20000.txt" \
           "$DICTS_DIR/richelieu-french-top20000.txt"
    else
        log "  [$n/$total] Richelieu 20k ✓"
    fi

    # ── 3. Richelieu Top 5k ─────────────────────────────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/richelieu-french-top5000.txt" ]]; then
        log "  [$n/$total] Richelieu — Top 5k MDP français"
        dl "https://raw.githubusercontent.com/tarraschk/richelieu/master/richelieu-french-top5000.txt" \
           "$DICTS_DIR/richelieu-french-top5000.txt"
    else
        log "  [$n/$total] Richelieu 5k ✓"
    fi

    # ── 4. Probable-Wordlists Top 95k ───────────────────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/Top95Thousand-probable.txt" ]]; then
        log "  [$n/$total] Probable-Wordlists Top 95k"
        dl "https://raw.githubusercontent.com/berzerk0/Probable-Wordlists/master/Real-Passwords/Top95Thousand-probable-v2.txt" \
           "$DICTS_DIR/Top95Thousand-probable.txt"
    else
        log "  [$n/$total] Probable-Wordlists 95k ✓"
    fi

    # ── 5. Probable-Wordlists Top 1.6M (Real Passwords) ────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/Top1pt6Million-probable.txt" ]]; then
        log "  [$n/$total] Probable-Wordlists Top 1.6M"
        dl "https://raw.githubusercontent.com/berzerk0/Probable-Wordlists/master/Real-Passwords/Top1pt6Million-probable-v2.txt" \
           "$DICTS_DIR/Top1pt6Million-probable.txt" \
            || warn "  1.6M non dispo en téléchargement direct"
    else
        log "  [$n/$total] Probable-Wordlists 1.6M ✓"
    fi

    # ── 6. SecLists Common-Credentials (10M) ────────────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/seclists-10million.txt" ]]; then
        log "  [$n/$total] SecLists 10-million-password-list"
        dl "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/10-million-password-list-top-1000000.txt" \
           "$DICTS_DIR/seclists-10million.txt" \
            || warn "  SecLists 10M non dispo"
    else
        log "  [$n/$total] SecLists 10M ✓"
    fi

    # ── 7. SecLists WiFi / darkc0de ─────────────────────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/darkc0de.txt" ]]; then
        log "  [$n/$total] SecLists darkc0de.txt"
        dl "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/darkc0de.txt" \
           "$DICTS_DIR/darkc0de.txt" \
            || warn "  darkc0de non dispo"
    else
        log "  [$n/$total] darkc0de ✓"
    fi

    # ── 8. Mots du dictionnaire français (lexique) ──────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/french-lexicon.txt" ]]; then
        log "  [$n/$total] Lexique français (mots courants)"
        dl "https://raw.githubusercontent.com/chrplr/openlexicon/master/datasets-info/Liste-de-mots-francais-Gutenberg/liste.de.mots.francais.frgut.txt" \
           "$DICTS_DIR/french-lexicon.txt" 2>/dev/null \
            || dl "https://raw.githubusercontent.com/hbenbel/French-Dictionary/master/frenchwords.txt" \
                  "$DICTS_DIR/french-lexicon.txt" 2>/dev/null \
            || warn "  Lexique français non dispo"
    else
        log "  [$n/$total] French lexicon ✓"
    fi

    # ── 9. Noms de famille FR ───────────────────────────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/french-surnames.txt" ]]; then
        log "  [$n/$total] Noms de famille français (INSEE)"
        dl "https://raw.githubusercontent.com/OpenDataFrance/liste-prenoms-noms-fr/main/noms2008nat_txt.txt" \
           "$DICTS_DIR/french-surnames-raw.txt" 2>/dev/null && {
            # Nettoyer : extraire juste les noms, lowercaser
            awk -F'\t' 'NR>1 && $1!="" {print tolower($1)}' "$DICTS_DIR/french-surnames-raw.txt" \
                | sort -u > "$DICTS_DIR/french-surnames.txt" 2>/dev/null
            rm -f "$DICTS_DIR/french-surnames-raw.txt"
        } || {
            # Fallback : générer une liste de noms courants
            generate_french_surnames
        }
    else
        log "  [$n/$total] French surnames ✓"
    fi

    # ── 10. Prénoms FR (massif) ─────────────────────────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/french-firstnames.txt" ]]; then
        log "  [$n/$total] Prénoms français"
        dl "https://raw.githubusercontent.com/OpenDataFrance/liste-prenoms-noms-fr/main/prenoms2008nat_txt.txt" \
           "$DICTS_DIR/french-firstnames-raw.txt" 2>/dev/null && {
            awk -F'\t' 'NR>1 && $1!="" {print tolower($1)}' "$DICTS_DIR/french-firstnames-raw.txt" \
                | sort -u > "$DICTS_DIR/french-firstnames.txt" 2>/dev/null
            rm -f "$DICTS_DIR/french-firstnames-raw.txt"
        } || {
            generate_french_firstnames
        }
    else
        log "  [$n/$total] French firstnames ✓"
    fi

    # ── 11. WiFi custom FR (générateur intégré, très complet) ───────────
    ((n++))
    log "  [$n/$total] Génération du méga-dictionnaire WiFi FR..."
    generate_wifi_fr_dict_v2

    # ── 12. Kaonashi 14M ────────────────────────────────────────────────
    ((n++))
    if [[ ! -f "$DICTS_DIR/kaonashi14M.txt" ]]; then
        log "  [$n/$total] Kaonashi 14M"
        dl "https://raw.githubusercontent.com/kaonashi-passwords/Kaonashi/master/wordlists/kaonashi14M.txt.gz" \
           "$DICTS_DIR/kaonashi14M.txt.gz" && safe_gunzip "$DICTS_DIR/kaonashi14M.txt.gz" \
            || warn "  Kaonashi non dispo — récupère-le manuellement sur GitHub"
    else
        log "  [$n/$total] Kaonashi 14M ✓"
    fi

    echo ""
    log "Récapitulatif des dictionnaires :"
    echo ""
    local total_lines=0
    for f in "$DICTS_DIR"/*.txt; do
        [[ -f "$f" ]] || continue
        local lines
        lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        total_lines=$((total_lines + lines))
        printf "    %-40s %'10d lignes  (%s)\n" "$(basename "$f")" "$lines" "$(du -h "$f" | cut -f1)"
    done
    echo ""
    printf "    ${BOLD}%-40s %'10d lignes${NC}\n" "TOTAL" "$total_lines"
    echo ""
}

# ── GÉNÉRATEURS FR ──────────────────────────────────────────────────────────

generate_french_surnames() {
    log "    Génération fallback noms de famille FR..."
    cat > "$DICTS_DIR/french-surnames.txt" <<'EOF'
martin
bernard
thomas
petit
robert
richard
durand
dubois
moreau
laurent
simon
michel
lefevre
leroy
roux
david
bertrand
morel
fournier
girard
bonnet
dupont
lambert
fontaine
rousseau
vincent
muller
lefevre
faure
andre
mercier
blanc
guerin
boyer
garnier
chevalier
francois
legrand
gauthier
garcia
perrin
robin
clement
morin
nicolas
henry
roussel
mathieu
gautier
masson
marchand
duval
denis
dumont
marie
lemaire
noel
meyer
dufour
meunier
brun
blanchard
giraud
joly
riviere
lucas
brunet
gaillard
barbier
arnaud
martinez
gerard
roche
renard
schmitt
leroux
colin
vidal
caron
picard
roger
fabre
aubert
lemoine
renaud
dumas
lacroix
olivier
philippe
bourgeois
pierre
benoit
rey
leclerc
payet
rolland
leclercq
guillaume
lecomte
lopez
jean
dupuy
guillot
hubert
berger
carpentier
sanchez
dupuis
moulin
louis
deschamps
huet
vasseur
perez
boucher
fleury
royer
klein
jacquet
adam
paris
poirier
marty
aubry
guyot
carre
charles
renault
charpentier
menard
maillard
baron
bertin
bailly
herve
schneider
fernandez
collet
leger
bouvier
julien
prevost
millet
perrot
daniel
cousin
germain
breton
besson
langlois
remy
pelletier
leveque
perrier
leblanc
barre
lebrun
marchal
weber
mallet
hamon
boulanger
jacob
monnier
michaud
rodriguez
guichard
gillet
etienne
grondin
poulain
ferreira
pereira
chevalier
leonard
coulon
delaunay
lebreton
courtois
gros
bousquet
pasquier
laporte
olive
bouquet
vallee
paul
torres
briand
gay
gomez
becker
navarro
fouquet
levy
evrard
raymond
letellier
salmon
lopes
delmas
camus
ramos
costa
chauvin
hoarau
da silva
goncalves
alves
rodrigues
dias
ferreira
EOF
    sort -u "$DICTS_DIR/french-surnames.txt" -o "$DICTS_DIR/french-surnames.txt"
}

generate_french_firstnames() {
    log "    Génération fallback prénoms FR..."
    cat > "$DICTS_DIR/french-firstnames.txt" <<'EOF'
jean
pierre
marie
nicolas
philippe
laurent
michel
thomas
julien
sophie
nathalie
isabelle
sandrine
caroline
camille
antoine
alexandre
maxime
lucas
hugo
emma
lea
chloe
manon
oceane
nathan
gabriel
raphael
louis
arthur
paul
victor
adam
noah
liam
jules
ethan
leo
maël
aaron
eden
alice
rose
louise
anna
jade
lina
mila
sarah
clara
ines
juliette
elena
agathe
margot
zoe
charlotte
victoria
clemence
ambre
valentin
theo
enzo
mathis
tom
nolan
matteo
gabin
rayan
mohamed
yanis
robin
sacha
axel
baptiste
dylan
matheo
quentin
fabien
sebastien
christophe
stephane
frederic
pascal
olivier
patrick
eric
thierry
alain
bruno
didier
daniel
david
bernard
jacques
francois
dominique
martine
catherine
sylvie
christine
anne
monique
brigitte
nicole
colette
jacqueline
patricia
veronique
elisabeth
celine
aurelie
emilie
laura
marine
pauline
elodie
virginie
jessica
stephanie
melanie
julie
audrey
delphine
karine
angelique
laetitia
sabrina
christelle
helene
mathilde
margaux
oceane
romane
maeva
lola
lily
nina
eva
elisa
noemie
capucine
adele
eloise
anais
clementine
fanny
solene
EOF
    sort -u "$DICTS_DIR/french-firstnames.txt" -o "$DICTS_DIR/french-firstnames.txt"
}

generate_wifi_fr_dict_v2() {
    local out="$DICTS_DIR/wifi-custom-fr-v2.txt"
    > "$out"  # Reset

    log "    Génération du méga-dico WiFi FR..."

    # ── Mots de passe WiFi FR les plus courants ────────────────────────
    cat >> "$out" <<'BASE'
password
motdepasse
internet
wifimaison
maisonduwifi
changez-moi
changez_moi
changemoi
bienvenue
bonjour
bonsoir
salut
coucou
jetaime
iloveyou
amour
bonheur
soleil
lune
etoile
chocolat
fromage
baguette
croissant
champagne
bordeaux
camembert
raclette
fondue
crepes
tartiflette
ratatouille
bretagne
provence
normandie
alsace
corse
cotedazur
montblanc
BASE

    # ── Opérateurs / Box FR ────────────────────────────────────────────
    local operators=(livebox freebox bbox sfr orange bouygues red sosh)
    local prefixes=("${operators[@]}" wifi maison internet home network reseau monwifi mawifi lewifi)

    for prefix in "${prefixes[@]}"; do
        echo "$prefix" >> "$out"
        # + 2 chiffres
        for i in $(seq 0 99); do
            printf '%s%02d\n' "$prefix" "$i" >> "$out"
        done
        # + 3 chiffres
        for i in $(seq 0 999); do
            printf '%s%03d\n' "$prefix" "$i" >> "$out"
        done
        # + 4 chiffres
        for i in $(seq 0 9999); do
            printf '%s%04d\n' "$prefix" "$i" >> "$out"
        done
        # + années
        for year in $(seq 2010 2026); do
            echo "${prefix}${year}" >> "$out"
            echo "${prefix}_${year}" >> "$out"
        done
        # + !
        echo "${prefix}!" >> "$out"
        echo "${prefix}123" >> "$out"
        echo "${prefix}1234" >> "$out"
    done

    # ── Villes françaises (top 100) ────────────────────────────────────
    local cities=(
        paris lyon marseille toulouse nice nantes strasbourg montpellier
        bordeaux lille rennes reims lehavre saintetienne toulon grenoble
        dijon angers nimes villeurbanne clermontferrand lemans
        aixenprovence brest tours amiens limoges perpignan metz besancon
        orleans rouen mulhouse caen nancy argenteuil saintdenis
        montreuil roubaix tourcoing dunkerque avignon nanterre poitiers
        versailles colombes aubervilliers vitry asnieres
        rueilmalmaison calais champigny boulogne courbevoie
        saintmaur antibes beziers cannes colmar merignac saintpierre
        saintdenis laval quimper troyes lorient sarcelles
        chambery niort villeneuvedascq hyeres cholet ajaccio
        vannes levallois epinay issy fontenay ivry cergy
    )

    for city in "${cities[@]}"; do
        echo "$city" >> "$out"
        for year in $(seq 2015 2026); do
            echo "${city}${year}" >> "$out"
        done
        for s in 01 02 06 10 13 17 29 31 33 34 35 44 59 67 69 75 78 83 92 93 94 95; do
            echo "${city}${s}" >> "$out"
        done
    done

    # ── Clubs de foot / sport FR ───────────────────────────────────────
    local clubs=(
        psg ompsg allez allezom alezpsg olympiquemarseille olympiqulyonnais
        om ol asse ogcnice monaco losc rclens staderennais
        fcnantes girondins montpellier auxerre stbrestois
        equipedefrance lesbleus griezmann mbappe benzema zidane
        platini henry ribery pogba dembele
    )
    for club in "${clubs[@]}"; do
        echo "$club" >> "$out"
        echo "${club}!" >> "$out"
        for n in $(seq 0 99); do
            printf '%s%02d\n' "$club" "$n" >> "$out"
        done
    done

    # ── Dates de naissance (DDMMYYYY, DDMMYY, YYYYMMDD) ───────────────
    for y in $(seq 1960 2008); do
        local yy="${y:2:2}"
        for m in 01 02 03 04 05 06 07 08 09 10 11 12; do
            for d in 01 02 05 10 12 14 15 18 20 21 22 25 28 30; do
                echo "${d}${m}${y}" >> "$out"
                echo "${d}${m}${yy}" >> "$out"
                echo "${y}${m}${d}" >> "$out"
                echo "${d}/${m}/${y}" >> "$out"
                echo "${d}-${m}-${y}" >> "$out"
                echo "${d}.${m}.${y}" >> "$out"
            done
        done
    done

    # ── Numéros de téléphone FR (06/07 + 8 chiffres) ──────────────────
    log "    Génération numéros de tél FR (06xx/07xx courants)..."
    for prefix in 06 07; do
        # On ne peut pas générer les 100M combinaisons, mais les patterns courants
        for mid in 00 01 10 11 12 20 21 22 30 31 32 33 40 41 50 51 60 61 70 71 80 81 90 91 99; do
            for end in $(seq -w 0000 100 9999); do
                echo "${prefix}${mid}${end}00" >> "$out"
            done
        done
    done

    # ── Codes postaux français (utilisés comme MDP) ────────────────────
    for cp in $(seq -w 01000 1000 95999); do
        echo "$cp" >> "$out"
    done
    # Les plus courants en entier
    for cp in 75001 75002 75003 75004 75005 75006 75007 75008 75009 75010 \
              75011 75012 75013 75014 75015 75016 75017 75018 75019 75020 \
              13001 13002 13003 13004 13005 13006 13007 13008 \
              69001 69002 69003 69004 69005 69006 69007 69008 69009 \
              31000 33000 34000 35000 44000 59000 67000 92000 93000 94000 95000; do
        echo "$cp" >> "$out"
        echo "${cp}${cp}" >> "$out"  # doublé
    done

    # ── Combos numériques classiques (8-12 chars) ──────────────────────
    cat >> "$out" <<'NUMS'
12345678
123456789
1234567890
12345678910
00000000
11111111
22222222
33333333
44444444
55555555
66666666
77777777
88888888
99999999
12341234
11223344
01234567
87654321
13131313
24682468
11112222
11111234
12121212
20002000
20102010
20152015
20162016
20172017
20182018
20192019
20202020
20212021
20222022
20232023
20242024
20252025
20262026
14071789
06061944
08051945
NUMS

    # ── Expressions / phrases courtes FR ───────────────────────────────
    cat >> "$out" <<'PHRASES'
jetaime
jtm
jaimelafrance
vivlafrance
vivlafrance
liberteegalite
allahuakbar
bismillah
inchallah
hamdoulah
mashallah
moncoeur
mabiche
monsucre
mamour
monchat
monlapin
monange
mapuce
machouette
motdepasse
mdp12345
changermoi
adminadmin
azerty123
azertyuiop
qwertyuiop
aabbccdd
abcdefgh
iloveparis
parisjetaime
PHRASES

    # ── Clés par défaut des box (patterns connus) ──────────────────────
    # Livebox : souvent des clés hex de 26 chars (hors scope dico)
    # Freebox : souvent "clé par défaut" imprimée
    # On cible les gens qui ont changé pour un MDP perso

    # ── Deduplicate + filtre longueur ≥ 8 (WPA minimum) ───────────────
    log "    Déduplication et filtrage (≥8 chars pour WPA)..."
    sort -u "$out" | awk 'length >= 8' > "${out}.tmp"
    mv "${out}.tmp" "$out"

    local count
    count=$(wc -l < "$out")
    log "    → ${BOLD}$count${NC} entrées dans wifi-custom-fr-v2.txt"
}

# ── RÈGLES DE MUTATION ──────────────────────────────────────────────────────
download_rules() {
    log "Préparation des règles de mutation..."

    local hc_rules
    hc_rules=$(find /usr/share/hashcat/rules /usr/local/share/hashcat/rules \
               /opt/hashcat/rules 2>/dev/null | head -1 || true)

    if [[ -d "$hc_rules" ]]; then
        for rule in best64.rule d3ad0ne.rule rockyou-30000.rule toggles1.rule \
                    toggles2.rule dive.rule generated2.rule; do
            [[ -f "$hc_rules/$rule" ]] && cp "$hc_rules/$rule" "$RULES_DIR/" 2>/dev/null || true
        done
        log "  Règles hashcat copiées"
    fi

    # OneRuleToRuleThemAll
    if [[ ! -f "$RULES_DIR/OneRuleToRuleThemAll.rule" ]]; then
        log "  Téléchargement de OneRuleToRuleThemAll..."
        dl "https://raw.githubusercontent.com/NotSoSecure/password_cracking_rules/master/OneRuleToRuleThemAll.rule" \
           "$RULES_DIR/OneRuleToRuleThemAll.rule" \
            || warn "  Téléchargement échoué"
    fi

    # pantagrule (large, efficace)
    if [[ ! -f "$RULES_DIR/pantagrule.rule" ]]; then
        log "  Téléchargement de pantagrule (hashcat-only)..."
        dl "https://raw.githubusercontent.com/rarecoil/pantagrule/master/rules/hashesorg.v6.9k.rule" \
           "$RULES_DIR/pantagrule.rule" \
            || warn "  pantagrule non dispo"
    fi

    # Règle custom FR étendue
    cat > "$RULES_DIR/custom-fr-v2.rule" <<'RULE'
:
l
u
c
t
r
$1
$2
$3
$!
$?
$*
$#
$@
$1$2$3
$1$2$3$4
$1$2$3$!
$!$!
$1$!
$?$!
$0$1
$2$0$2$2
$2$0$2$3
$2$0$2$4
$2$0$2$5
$2$0$2$6
sa@
se3
si1
so0
ss$
sa@ se3
sa@ se3 si1 so0
sa@ se3 si1 so0 ss$
^1
^!
^0
$*
d
f
{ }
] [
$e $r
$e $s
$i $n $g
$m $a $n
$e $u $r
$i $o $n
p
k
K
E
RULE

    echo ""
}

# ════════════════════════════════════════════════════════════════════════════
#  PHASES D'ATTAQUE
# ════════════════════════════════════════════════════════════════════════════

# Phase 1 : Dictionnaires purs (du petit au gros)
attack_phase1_straight() {
    local capture="$1" potfile="$2" outfile="$3"
    info "PHASE 1 — Attaque dictionnaire pure"

    local dicts=(
        "$DICTS_DIR/richelieu-french-top5000.txt"
        "$DICTS_DIR/wifi-custom-fr-v2.txt"
        "$DICTS_DIR/richelieu-french-top20000.txt"
        "$DICTS_DIR/Top95Thousand-probable.txt"
        "$DICTS_DIR/french-lexicon.txt"
        "$DICTS_DIR/darkc0de.txt"
        "$DICTS_DIR/seclists-10million.txt"
        "$DICTS_DIR/Top1pt6Million-probable.txt"
        "$DICTS_DIR/rockyou.txt"
        "$DICTS_DIR/kaonashi14M.txt"
    )

    for dict in "${dicts[@]}"; do
        [[ -f "$dict" ]] || continue
        check_cracked "$capture" "$potfile" && return 0
        log "  Dict: ${YELLOW}$(basename "$dict")${NC}"
        hc_attack "$capture" "$potfile" "$outfile" -a 0 "$dict"
    done
    check_cracked "$capture" "$potfile"
}

# Phase 2 : Dictionnaires + règles
attack_phase2_rules() {
    local capture="$1" potfile="$2" outfile="$3"
    info "PHASE 2 — Dictionnaire + règles de mutation"

    # Dicos prioritaires avec règles
    local dicts=(
        "$DICTS_DIR/richelieu-french-top5000.txt"
        "$DICTS_DIR/richelieu-french-top20000.txt"
        "$DICTS_DIR/french-firstnames.txt"
        "$DICTS_DIR/french-surnames.txt"
        "$DICTS_DIR/Top95Thousand-probable.txt"
        "$DICTS_DIR/wifi-custom-fr-v2.txt"
        "$DICTS_DIR/rockyou.txt"
    )

    local rules=(
        "$RULES_DIR/custom-fr-v2.rule"
        "$RULES_DIR/best64.rule"
        "$RULES_DIR/pantagrule.rule"
    )

    for dict in "${dicts[@]}"; do
        [[ -f "$dict" ]] || continue
        for rule in "${rules[@]}"; do
            [[ -f "$rule" ]] || continue
            check_cracked "$capture" "$potfile" && return 0
            log "  Dict: ${YELLOW}$(basename "$dict")${NC} + $(basename "$rule")"
            hc_attack "$capture" "$potfile" "$outfile" -a 0 -r "$rule" "$dict"
        done
    done
    check_cracked "$capture" "$potfile"
}

# Phase 3 : OneRuleToRuleThemAll (la plus grosse, on la sort à part)
attack_phase3_otrta() {
    local capture="$1" potfile="$2" outfile="$3"
    info "PHASE 3 — OneRuleToRuleThemAll (attaque lourde)"

    [[ -f "$RULES_DIR/OneRuleToRuleThemAll.rule" ]] || return 1

    local dicts=(
        "$DICTS_DIR/richelieu-french-top20000.txt"
        "$DICTS_DIR/french-firstnames.txt"
        "$DICTS_DIR/french-surnames.txt"
        "$DICTS_DIR/Top95Thousand-probable.txt"
    )

    for dict in "${dicts[@]}"; do
        [[ -f "$dict" ]] || continue
        check_cracked "$capture" "$potfile" && return 0
        log "  Dict: ${YELLOW}$(basename "$dict")${NC} + OneRuleToRuleThemAll"
        hc_attack "$capture" "$potfile" "$outfile" -a 0 \
            -r "$RULES_DIR/OneRuleToRuleThemAll.rule" "$dict"
    done
    check_cracked "$capture" "$potfile"
}

# Phase 4 : Attaques combinatoires (2 petits dicos combinés)
attack_phase4_combinator() {
    local capture="$1" potfile="$2" outfile="$3"
    info "PHASE 4 — Attaques combinatoires (prénom+nom, mot+chiffres...)"

    # Prénoms + noms de famille
    if [[ -f "$DICTS_DIR/french-firstnames.txt" && -f "$DICTS_DIR/french-surnames.txt" ]]; then
        log "  Combo: prénoms × noms de famille"
        hc_attack "$capture" "$potfile" "$outfile" -a 1 \
            "$DICTS_DIR/french-firstnames.txt" "$DICTS_DIR/french-surnames.txt"
        check_cracked "$capture" "$potfile" && return 0

        # Inverse
        log "  Combo: noms × prénoms"
        hc_attack "$capture" "$potfile" "$outfile" -a 1 \
            "$DICTS_DIR/french-surnames.txt" "$DICTS_DIR/french-firstnames.txt"
        check_cracked "$capture" "$potfile" && return 0
    fi

    # Mots courants + suffixes numériques (via fichier temporaire)
    local numfile="$DICTS_DIR/_suffixes_num.txt"
    if [[ ! -f "$numfile" ]]; then
        seq -w 0 9999 > "$numfile"
    fi

    if [[ -f "$DICTS_DIR/richelieu-french-top5000.txt" ]]; then
        log "  Combo: Richelieu 5k × suffixes numériques (0000-9999)"
        hc_attack "$capture" "$potfile" "$outfile" -a 1 \
            "$DICTS_DIR/richelieu-french-top5000.txt" "$numfile"
        check_cracked "$capture" "$potfile" && return 0
    fi

    if [[ -f "$DICTS_DIR/french-firstnames.txt" ]]; then
        log "  Combo: prénoms × suffixes numériques"
        hc_attack "$capture" "$potfile" "$outfile" -a 1 \
            "$DICTS_DIR/french-firstnames.txt" "$numfile"
        check_cracked "$capture" "$potfile" && return 0
    fi

    return 1
}

# Phase 5 : Attaques hybrides (dico + masque)
attack_phase5_hybrid() {
    local capture="$1" potfile="$2" outfile="$3"
    info "PHASE 5 — Attaques hybrides (dico+masque / masque+dico)"

    local dicts=(
        "$DICTS_DIR/french-firstnames.txt"
        "$DICTS_DIR/french-surnames.txt"
        "$DICTS_DIR/richelieu-french-top5000.txt"
    )

    # Mode 6 : dico + masque (append)
    local masks_append=(
        '?d?d?d?d'          # mot + 4 chiffres
        '?d?d?d?d?d'        # mot + 5 chiffres
        '?d?d?d?d?d?d'      # mot + 6 chiffres
        '?s?d?d'            # mot + symbole + 2 chiffres
        '?d?d?d?d?s'        # mot + 4 chiffres + symbole
        '?d?d!!'            # mot + 2 chiffres + !!
    )

    for dict in "${dicts[@]}"; do
        [[ -f "$dict" ]] || continue
        for mask in "${masks_append[@]}"; do
            check_cracked "$capture" "$potfile" && return 0
            log "  Hybrid6: ${YELLOW}$(basename "$dict")${NC} + ${mask}"
            hc_attack "$capture" "$potfile" "$outfile" -a 6 "$dict" "$mask"
        done
    done

    # Mode 7 : masque + dico (prepend)
    local masks_prepend=(
        '?d?d?d?d'          # 4 chiffres + mot
        '?u?l?l?l'          # 4 lettres + mot
    )

    for dict in "${dicts[@]}"; do
        [[ -f "$dict" ]] || continue
        for mask in "${masks_prepend[@]}"; do
            check_cracked "$capture" "$potfile" && return 0
            log "  Hybrid7: ${mask} + ${YELLOW}$(basename "$dict")${NC}"
            hc_attack "$capture" "$potfile" "$outfile" -a 7 "$mask" "$dict"
        done
    done

    return 1
}

# Phase 6 : Brute-force par masques
attack_phase6_bruteforce() {
    local capture="$1" potfile="$2" outfile="$3"
    info "PHASE 6 — Brute-force par masques"

    local masks=(
        '?d?d?d?d?d?d?d?d'                     # 8 chiffres (~30 min)
        '?d?d?d?d?d?d?d?d?d'                   # 9 chiffres (~5h)
        '?d?d?d?d?d?d?d?d?d?d'                 # 10 chiffres - tel FR (~50h)
        '?l?l?l?l?l?l?l?l'                     # 8 minuscules (~6h)
        '?u?l?l?l?l?l?l?l'                     # Majuscule + 7 min (~6h)
        '?l?l?l?l?l?l?l?l?l'                   # 9 minuscules (~jours)
        '?l?l?l?l?l?l?d?d?d?d'                 # 6 lettres + 4 chiffres
        '?u?l?l?l?l?l?d?d?d?d'                 # Ucfirst 5 + 4 chiffres
    )

    for mask in "${masks[@]}"; do
        check_cracked "$capture" "$potfile" && return 0
        log "  Mask: ${YELLOW}${mask}${NC} ($(echo -n "$mask" | grep -o '?' | wc -l) chars)"
        hc_attack "$capture" "$potfile" "$outfile" -a 3 "$mask"
    done

    return 1
}

# ── ORCHESTRATEUR ───────────────────────────────────────────────────────────
run_attacks() {
    local capture_files=("$CAPTURES_DIR"/*.22000)

    if [[ ${#capture_files[@]} -eq 0 || ! -f "${capture_files[0]}" ]]; then
        err "Aucun fichier .22000 trouvé dans $CAPTURES_DIR/"
        err "Place tes fichiers PMKID (.22000) dans ce dossier et relance."
        [[ -n "$GITHUB_REPO" ]] && err "Ou configure GITHUB_REPO en haut du script."
        exit 1
    fi

    log "Fichiers .22000 trouvés : ${#capture_files[@]}"
    for f in "${capture_files[@]}"; do
        echo "    → $(basename "$f")"
    done
    echo ""

    local total=${#capture_files[@]}
    local cracked_total=0
    local start_time=$SECONDS

    for capture in "${capture_files[@]}"; do
        local capname
        capname=$(basename "$capture" .22000)
        local potfile="$RESULTS_DIR/${capname}.potfile"
        local outfile="$RESULTS_DIR/${capname}_found.txt"

        echo ""
        echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║  Attaque : ${CYAN}${capname}${NC}${BOLD}$(printf '%*s' $((44 - ${#capname})) '')║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
        echo ""

        local found=false

        for phase in attack_phase1_straight attack_phase2_rules attack_phase3_otrta \
                     attack_phase4_combinator attack_phase5_hybrid attack_phase6_bruteforce; do

            if $phase "$capture" "$potfile" "$outfile"; then
                show_cracked "$capture" "$potfile"
                found=true
                ((cracked_total++))
                break
            fi
        done

        if ! $found; then
            err "Toutes les phases exhaustées pour ${capname}"
            warn "Le MDP est probablement très fort (long, aléatoire, mixte)"
            warn "Options restantes : CrackStation 1.5B (15 Go), ou louer plusieurs GPUs"
        fi
    done

    local elapsed=$(( SECONDS - start_time ))
    local hours=$(( elapsed / 3600 ))
    local minutes=$(( (elapsed % 3600) / 60 ))

    echo ""
    echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  RÉSULTAT FINAL${NC}"
    echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
    log "Crackés : ${GREEN}${BOLD}${cracked_total}${NC} / ${total}"
    log "Durée totale : ${hours}h ${minutes}min"
    echo ""

    # Afficher tous les résultats
    for capture in "${capture_files[@]}"; do
        local capname
        capname=$(basename "$capture" .22000)
        local potfile="$RESULTS_DIR/${capname}.potfile"
        if check_cracked "$capture" "$potfile" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} ${capname} → $($HASHCAT_BIN -m $MODE "$capture" --show --potfile-path "$potfile" 2>/dev/null | tail -1)"
        else
            echo -e "  ${RED}✗${NC} ${capname} → non trouvé"
        fi
    done

    echo ""
    log "Détails dans $RESULTS_DIR/"
}

# ── MAIN ────────────────────────────────────────────────────────────────────
banner
setup_dirs
install_deps
fetch_captures_from_github
download_dicts
download_rules

echo ""
echo -e "${BOLD}Lancement des attaques — 6 phases, du rapide au costaud${NC}"
echo -e "${BOLD}Phase 1: Dicos purs | Phase 2: Dicos+règles | Phase 3: OTRTA${NC}"
echo -e "${BOLD}Phase 4: Combinatoire | Phase 5: Hybride | Phase 6: Brute-force${NC}"
echo ""

run_attacks
