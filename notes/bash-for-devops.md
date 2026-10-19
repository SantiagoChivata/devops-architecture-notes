# Bash para DevOps

Notas de referencia sobre scripting Bash orientado a CI/CD. Ejemplo aplicado: [`labs/bash/healthcheck.sh`](../labs/bash/healthcheck.sh).

---

## 1. Strict mode

Todo script que corra en CI empieza así:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

| Flag | Qué hace | Bug que evita |
|---|---|---|
| `-e` | Aborta si un comando devuelve exit ≠ 0 | Seguir desplegando tras un `docker build` fallido |
| `-u` | Error al usar una variable no definida | `rm -rf "$DIR/"` con `DIR` vacío |
| `-o pipefail` | Un pipe falla si falla **cualquier** etapa | `curl ... \| jq` "exitoso" aunque `curl` falló |

**Sin `pipefail`**, el exit code de un pipe es el del **último** comando: `false | true` → 0.

### Cuándo `-e` NO aborta
`-e` se desactiva cuando el fallo está "manejado":

- Dentro de condiciones: `if cmd; then`, `while cmd; do`
- En listas: `cmd || fallback`, `cmd && otro`

Esto permite tolerar fallos de forma **explícita**:

```bash
code=$(curl ... "$url") || code="000"   # el fallo lo manejo yo
```

---

## 2. Variables: defaults y obligatorias

```bash
TIMEOUT="${TIMEOUT:-5}"                    # default si no existe o está vacía
API_URL="${API_URL:?API_URL es requerida}" # aborta con mensaje si falta
```

- `:-` trata igual una variable **no definida** y una **vacía** (`""`).
- En CI la variable se inyecta por entorno: `TIMEOUT=10 ./script.sh`.
- Valida el formato si un valor incorrecto puede causar fallos engañosos:

```bash
if [[ ! "$TIMEOUT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "TIMEOUT debe ser numérico" >&2; exit 2
fi
```

---

## 3. Funciones y logging

```bash
log() {
  local level="$1"; shift
  printf '[%s] [%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$*" >&2
}
```

- `local`: sin él, las variables de una función son **globales**.
- `>&2`: logs a **stderr**; stdout queda libre para datos (`script | jq`).
- `printf` > `echo`: comportamiento consistente entre shells. El texto va como **argumento** (`%s`), nunca como string de formato.
- Timestamps **UTC ISO-8601**: correlacionables entre runners, servidores y Loki/Grafana.

---

## 4. `trap`: cleanup garantizado

`trap` es el `finally` de Bash: se ejecuta al terminar el script, **sin importar si fue éxito o error**.

```bash
TMP_FILE="$(mktemp)"

cleanup() {
  local code=$?          # captura el exit code ANTES de hacer nada más
  rm -f "$TMP_FILE"
  exit "$code"           # preserva el exit code original
}
trap cleanup EXIT
trap 'log ERROR "falló la línea $LINENO"' ERR
```

| Señal | Cuándo se dispara |
|---|---|
| `EXIT` | Siempre al terminar (éxito, error o `exit`) |
| `ERR` | Cuando un comando falla |
| `INT` / `TERM` | Ctrl+C, `docker stop`, cancelación del job en CI |

Usos típicos: borrar temporales, cerrar túneles, `docker compose down` tras tests de integración.

---

## 5. Piezas básicas

```bash
hoy=$(date +%F)                   # command substitution: guarda la salida (sin espacios en =)
if [[ "$code" == 2* ]]; then ...  # [[ ]] con comodín: "empieza por 2"
total=$((total + 1))              # aritmética
[[ $total -gt 0 ]]                # comparación numérica (-eq -ne -lt -le -gt -ge)
```

- Siempre `"$var"` entre comillas, por hábito.
- Un `for`/`if` con el cuerpo **solo con comentarios** es error de sintaxis.

---

## 6. `jq`: parsing de JSON

`aws`, `kubectl -o json`, `terraform show -json` y las APIs hablan JSON. `jq` es el estándar para leerlo en scripts.

| Filtro | Qué hace |
|---|---|
| `.campo` / `.a.b` | Campo / campo anidado |
| `.lista[]` | Itera cada elemento (emite resultados **sueltos**) |
| `select(cond)` | Filtra, como un `WHERE` |
| `[ ... ]` | Recoge resultados sueltos en un array |
| `map(f)` | Aplica `f` a cada elemento y devuelve array |
| `length` | Tamaño de un array / objeto |

| Flag | Uso |
|---|---|
| `-r` | Output sin comillas: úsalo siempre que el valor vaya a una variable |
| `-e` | Exit ≠ 0 si el resultado es `null`/`false`: útil en CI |

```bash
jq -r '.services[] | select(.status == "down") | .name' services.json
jq '[.services[] | select(.status == "up")] | length' services.json
```

### Reglas que evitan el 90% de errores
1. **Filtro siempre entre comillas simples**: si no, Bash interpreta el `|` y los `(`.
2. **Strings de jq entre comillas dobles**: `"down"`. Sin comillas, jq lo trata como función (`down/0 is not defined`).
3. `length` necesita **un** array: `.lista[] | length` cuenta cada elemento, `[.lista[]] | length` cuenta el total.

---

## 7. `curl` en scripts

```bash
code=$(curl -sSL -g -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" -- "$url") || code="000"
```

| Flag | Por qué |
|---|---|
| `-sS` | Oculta la barra de progreso pero **muestra errores** (DNS, TLS, timeout) en stderr |
| `-L` | Sigue redirects (`http` → `https`) |
| `-g` | Desactiva globbing: URLs con `[]` o `{}` no se corrompen |
| `-o /dev/null -w '%{http_code}'` | Descarta el body, imprime solo el status |
| `--max-time` | Evita que un endpoint colgado bloquee el pipeline |
| `--` | Fin de opciones: un argumento que empiece por `-` no se interpreta como flag |

Sin respuesta HTTP, curl devuelve status `000` y un exit code propio (ej. `6` = no resolvió el host).

---

## 8. Exit codes con significado

| Código | Convención usada |
|---|---|
| `0` | Éxito |
| `1` | Fallo de negocio (ej. un servicio DOWN) |
| `2` | Uso o configuración incorrecta |

Un exit ≠ 0 es lo que hace fallar un stage de Jenkins o un step de GitHub Actions. Documentarlos en la cabecera del script.

---

## 9. Gotchas (Git Bash en Windows)

- **`sh script.sh` ignora el shebang** y puede usar otro shell sin `pipefail`. Usar `bash script.sh` o `./script.sh`.
- **Bit de ejecución**: el filesystem de Windows no lo guarda. Registrarlo en Git:
  ```bash
  git add --chmod=+x labs/bash/script.sh   # verificar: git ls-files -s → 100755
  ```
