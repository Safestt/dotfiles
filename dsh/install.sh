#!/usr/bin/env bash
# One-shot installer: DSH (profile web) + patched opencode provider + models YAML.
# Uso en PC nueva:
#   git clone <tu-repo-dotfiles> ~/dotfiles
#   bash ~/dotfiles/dsh/install.sh
#
# Env vars opcionales:
#   PROFILE=web
#   FORK_REPO="Safestt/Opencode-Provider-fixed"  # github:<usuario>/<repo> del fork
#   USE_LOCAL_FORK=1             # instala desde $LOCAL_FORK en vez de GitHub (para pruebas)
#   DOTFILES_REPO=""        # si está seteado y corres el script fuera del clone: git clone/pull a ~/dotfiles
#   SKIP_DSH_START=""       # si está seteado (cualquier valor): no arranca `dsh web` al final
set -euo pipefail

PROFILE="${PROFILE:-web}"
FORK_REPO="${FORK_REPO:-Safestt/Opencode-Provider-fixed}"
LOCAL_FORK="${LOCAL_FORK:-$HOME/deepseek-harness-opencode-Fork}"
DOTFILES_REPO="${DOTFILES_REPO:-}"
SKIP_DSH_START="${SKIP_DSH_START:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_SRC="$DOTFILES_DIR/dsh/opencode-models.patch.yml"
PATCH_DST="$HOME/.dsh/profiles/$PROFILE/cordis.patch.yml"

echo "==> [1/6] Pre-requisitos: Node.js >= 22 y opencode CLI"
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node no está instalado. Instala Node.js >= 22 primero (https://nodejs.org/)." >&2
  exit 1
fi
NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "ERROR: node $(node --version) < 22. Actualiza Node.js a >= 22." >&2
  exit 1
fi
echo "    node $(node --version) OK"
if command -v opencode >/dev/null 2>&1; then
  echo "    opencode $(opencode --version 2>/dev/null || echo instalado) OK"
else
  echo "    opencode CLI no encontrado. Intentando instalar con el instalador oficial..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://opencode.ai/install | bash
    export PATH="$HOME/.opencode/bin:$PATH"
  else
    echo "ERROR: ni opencode ni curl disponibles. Instala opencode: curl -fsSL https://opencode.ai/install | bash" >&2
    exit 1
  fi
  if ! command -v opencode >/dev/null 2>&1; then
    echo "ERROR: la instalación de opencode no lo dejó en PATH. Revisa ~/.opencode/bin." >&2
    exit 1
  fi
fi

echo "==> [2/6] Dotfiles"
if [ -n "$DOTFILES_REPO" ] && [ "$DOTFILES_DIR" != "$HOME/dotfiles" ]; then
  if [ -d "$HOME/dotfiles/.git" ]; then
    echo "    Actualizando ~/dotfiles..."
    git -C "$HOME/dotfiles" pull --ff-only
    MODELS_SRC="$HOME/dotfiles/dsh/opencode-models.patch.yml"
  else
    echo "    Clonando dotfiles..."
    git clone "$DOTFILES_REPO" "$HOME/dotfiles"
    MODELS_SRC="$HOME/dotfiles/dsh/opencode-models.patch.yml"
  fi
else
  echo "    Usando dotfiles locales: $DOTFILES_DIR"
fi
if [ ! -f "$MODELS_SRC" ]; then
  echo "ERROR: no existe $MODELS_SRC" >&2
  exit 1
fi

echo "==> [3/6] Plugin forkeado"
if [ "${USE_LOCAL_FORK:-}" = "1" ] && [ -d "$LOCAL_FORK/lib" ]; then
  echo "    USE_LOCAL_FORK=1; instalando desde fork local: $LOCAL_FORK"
  DEST="$HOME/.dsh/profiles/$PROFILE/node_modules/dsh-opencode-provider"
  mkdir -p "$DEST/lib/types"
  cp "$LOCAL_FORK/CHANGELOG.md" "$LOCAL_FORK/LICENSE" "$LOCAL_FORK/README.md" \
     "$LOCAL_FORK/THIRD_PARTY_NOTICES.md" "$LOCAL_FORK/cordis.patch.yml" \
     "$LOCAL_FORK/package.json" "$DEST/" 2>/dev/null || true
  cp "$LOCAL_FORK/lib/index.mjs" "$LOCAL_FORK/lib/invariant.mjs" "$DEST/lib/"
  cp "$LOCAL_FORK/lib/types/"* "$DEST/lib/types/" 2>/dev/null || true
  echo "    Copiado a $DEST (instalación local)."
else
  echo "    dsh plugin --profile $PROFILE add github:$FORK_REPO"
  dsh plugin --profile "$PROFILE" add "github:$FORK_REPO"
fi

echo "==> [4/6] Symlink cordis.patch.yml -> models YAML"
mkdir -p "$(dirname "$PATCH_DST")"
if [ -L "$PATCH_DST" ] || [ -f "$PATCH_DST" ]; then
  BACKUP="$PATCH_DST.pre-symlink.$(date +%Y%m%d-%H%M%S).bak"
  echo "    Respaldando existente en $BACKUP"
  mv "$PATCH_DST" "$BACKUP"
fi
ln -s "$MODELS_SRC" "$PATCH_DST"
echo "    $PATCH_DST -> $MODELS_SRC"

echo "==> [5/6] Auth + servidor OpenCode"
echo "    Si es primera vez en esta PC, autentica tu cuenta legítima:"
echo "      opencode auth login"
echo "    Luego (otra terminal, ANTES de DSH):"
echo "      opencode serve --hostname 127.0.0.1 --port 4096"
if curl -sf --max-time 3 http://127.0.0.1:4096/api/config >/dev/null 2>&1; then
  echo "    OK: opencode responde en 127.0.0.1:4096"
else
  echo "    AVISO: opencode NO responde en 127.0.0.1:4096 todavía."
fi

echo "==> [6/6] DSH web (perfil $PROFILE)"
echo "    Modelos esperados: opencode-local/mimo-v2.5-free, nemotron-3-ultra-free,"
echo "      nemotron-3.5-lightning-free, muse-spark-1.3-contributor-free, muse-spark-1.2-contributor-free"
if [ -n "$SKIP_DSH_START" ]; then
  echo "    SKIP_DSH_START seteado; no arranco dsh. Corre: dsh web --profile $PROFILE"
  exit 0
fi
echo "    Arrancando: dsh web --profile $PROFILE"
exec dsh web --profile "$PROFILE"
