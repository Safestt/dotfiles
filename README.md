# dotfiles — DSH + OpenCode local

Setup portable de **DeepSeek Harness (perfil `web`) + servidor local de OpenCode (`127.0.0.1:4096`)**
con el fork parcheado `dsh-opencode-provider-patched` (lee `config.models`, fallback a `mimo-v2.5-free`).

Todo lo relacionado con auth/headers/conexión a OpenCode está intacto del plugin original.
Solo cambió la lógica de registro de modelos desde config. Usa tu cuenta/sesión legítima local.

## Instalación en PC nueva

```bash
git clone <tu-repo-dotfiles> ~/dotfiles
bash ~/dotfiles/dsh/install.sh
```

El script hace, en orden:
1. Verifica Node.js ≥ 22; verifica `opencode` CLI y lo instala (instalador oficial) si falta.
2. Clona/actualiza dotfiles si se pasa `DOTFILES_REPO` (si ya clonaste, usa el checkout local).
3. Instala el fork: `dsh plugin --profile web add github:<FORK_REPO>` (o copia local desde `~/deepseek-harness-opencode-Fork` mientras `FORK_REPO` siga siendo el placeholder).
4. Symlink `~/.dsh/profiles/web/cordis.patch.yml -> ~/dotfiles/dsh/opencode-models.patch.yml` (con backup si ya existía).
5. Recuerda `opencode auth login` (primera vez) + `opencode serve --hostname 127.0.0.1 --port 4096` antes de DSH.
6. Arranca `dsh web --profile web` al final (salta con `SKIP_DSH_START=1`).

Variantes:

```bash
# Fork ya en GitHub:
FORK_REPO=TU-USUARIO/dsh-opencode-provider-patched bash ~/dotfiles/dsh/install.sh
# Otro perfil / sin arrancar DSH:
PROFILE=otro SKIP_DSH_START=1 bash ~/dotfiles/dsh/install.sh
# Correr desde otro lado clonando dotfiles:
DOTFILES_REPO=git@github.com:TU-USUARIO/dotfiles.git bash /tmp/install.sh
```

## Agregar un modelo nuevo

Solo edita el YAML, sin tocar código:

1. Abre `dsh/opencode-models.patch.yml`.
2. Agrega una entrada bajo `config.models`:
   ```yaml
   - id: nuevo-modelo-free
     name: nuevo-modelo-free
     contextWindow: 200000
   ```
   El `id` debe ser el model ID exacto que `opencode` expone (típicamente con sufijo `-free` de Zen).
3. `git add -A && git commit -m "add nuevo-modelo-free" && git push`.
4. En cada PC: `git -C ~/dotfiles pull` + reinicia `dsh web`. El symlink ya apunta al archivo, no hay que reinstalar.

## Quitar un modelo que ya no existe

1. Borra su bloque `- id: ...` (3 líneas) del YAML.
2. Commit + push, luego `git pull` en cada PC + reinicia DSH.

Si quitas todos los modelos (o dejas `models:` vacío), el plugin hace fallback a `mimo-v2.5-free` para no romper nada.

## Archivos

- `dsh/opencode-models.patch.yml` — única fuente de verdad de modelos. Este archivo es a donde apunta el symlink `cordis.patch.yml`.
- `dsh/install.sh` — instalador one-shot (idempotente, verifica Node/opencode, instala fork, symlink, auth/serve, arranca DSH).
- Fork con fuente parcheada (aún local): `~/deepseek-harness-opencode-Fork/` — `src/adapter.ts` + `src/index.ts` corregidos, `lib/` regenerado con build, `typecheck` y `test` (42 tests) verdes.

## Subir el fork a GitHub (pendiente, sin `gh` aquí)

```bash
cd ~/deepseek-harness-opencode-Fork
git init -b main
git add -A
git commit -m "patched fork: config.models works with fallback (upstream goku54477/dsh-opencode-provider v0.1.0)"
# crea el repo vacío en github.com (TU-USUARIO/dsh-opencode-provider-patched) y luego:
git remote add origin git@github.com:TU-USUARIO/dsh-opencode-provider-patched.git
git push -u origin main
```

Luego el plugin queda instalable con:

```bash
dsh plugin --profile web add github:TU-USUARIO/dsh-opencode-provider-patched
```
