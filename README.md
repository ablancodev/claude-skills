# Claude Code Skills

Colección personal de [skills](https://docs.claude.com/en/docs/claude-code/skills) para Claude Code, organizadas por stack tecnológico (iOS, WordPress, etc.).

Clonas el repo una vez y, desde cada proyecto, instalas **solo** las skills que ese proyecto necesita. Sin coste de tokens global.

---

## Instalación inicial (una sola vez)

```bash
git clone <url-del-repo> ~/Documents/IA/skills
```

Puedes clonarlo donde quieras; los ejemplos asumen esa ruta.

> Opcional pero cómodo: añade un alias en tu `~/.zshrc` para no repetir la ruta:
> ```bash
> alias skills='~/Documents/IA/skills/install.sh'
> ```
> Así los comandos pasan a ser `skills ios`, `skills --list`, etc.

---

## Uso diario

Todos los comandos se ejecutan **desde la raíz del proyecto donde quieras instalar las skills**.

### Instalar un stack completo

```bash
cd ~/code/mi-app-ios
~/Documents/IA/skills/install.sh ios
```

Esto crea `./.claude/skills/` en el proyecto y enlaza ahí todas las skills declaradas en `stacks/ios.txt`. Claude Code las detectará automáticamente la próxima vez que abras una sesión en ese proyecto.

### Instalar varios stacks

```bash
~/Documents/IA/skills/install.sh ios wordpress
```

Útil cuando un proyecto combina tecnologías (p.ej. headless WordPress + app iOS).

### Instalar una skill suelta (sin stack)

```bash
~/Documents/IA/skills/install.sh --skill apple-intelligence-app-intents
```

### Ver qué hay disponible y qué tienes instalado

```bash
~/Documents/IA/skills/install.sh --list
```

Output de ejemplo:

```
Available stacks:
  • ios (1 skills)
  • wordpress (0 skills)

Available skills:
  • apple-intelligence-app-intents

Currently linked in /Users/.../mi-app-ios/.claude/skills:
  → apple-intelligence-app-intents  (symlink → …/skills/apple-intelligence-app-intents)
```

### Quitar una skill de un proyecto

```bash
~/Documents/IA/skills/install.sh --remove apple-intelligence-app-intents
```

### Copiar en lugar de symlinkear

Por defecto se hacen symlinks (los cambios en el repo se reflejan en todos los proyectos al instante). Si necesitas independencia — p.ej. el proyecto se va a entregar a otra persona que no tiene el repo — usa `--copy`:

```bash
~/Documents/IA/skills/install.sh --copy ios
```

### Ayuda completa

```bash
~/Documents/IA/skills/install.sh --help
```

---

## Comandos a vista de pájaro

| Comando | Qué hace |
|---|---|
| `install.sh <stack>` | Instala todas las skills de `stacks/<stack>.txt` |
| `install.sh <stack1> <stack2>` | Instala varios stacks a la vez |
| `install.sh --skill <nombre>` | Instala una skill concreta |
| `install.sh --list` | Lista stacks, skills disponibles y skills enlazadas en el cwd |
| `install.sh --remove <nombre>` | Elimina una skill del proyecto |
| `install.sh --copy <args>` | Copia archivos en vez de symlinkear |
| `install.sh --target <dir> <args>` | Usa otro destino distinto a `./.claude/skills` |
| `install.sh --help` | Ayuda |

---

## Stacks disponibles

| Stack | Archivo | Skills |
|---|---|---|
| `ios` | `stacks/ios.txt` | `apple-intelligence-app-intents` |
| `wordpress` | `stacks/wordpress.txt` | `wordpress-7-ai-abilities`, `wordpress-gutenberg-php-blocks`, `wordpress-plugin-security` |

Para añadir más, edita el `.txt` correspondiente o crea uno nuevo en `stacks/`.

---

## Estructura del repo

```
.
├── README.md
├── install.sh            ← único script, ejecutable
├── stacks/               ← presets declarativos por stack
│   ├── ios.txt
│   └── wordpress.txt
└── skills/               ← las skills (una carpeta = una skill)
    └── apple-intelligence-app-intents/
        ├── SKILL.md
        └── references/
```

---

## Cómo añadir una skill nueva

1. Crea la carpeta `skills/<nombre-de-tu-skill>/` con su `SKILL.md`:

   ```markdown
   ---
   name: nombre-de-tu-skill
   description: Cuándo debe activarse esta skill. Sé específico — Claude lee esto para decidir si cargar el cuerpo.
   ---

   # Cuerpo de la skill…
   ```

2. (Opcional) Añade material complementario en `skills/<nombre>/references/`. No se carga hasta que la skill se invoca.

3. Añade el nombre a cualquier `stacks/*.txt` que aplique. A partir de ahí, todos los proyectos podrán instalarla con `install.sh <stack>`.

## Cómo añadir un stack nuevo

Crea un archivo `stacks/<nombre>.txt`:

```
# Skills para proyectos React / Next.js
react-server-components
tailwind
```

Una skill por línea. Las líneas que empiezan por `#` se ignoran. A partir de ahí, `install.sh <nombre>` funciona automáticamente.

---

## Notas

- **¿Por qué proyecto y no global?** Si pusieras todas las skills en `~/.claude/skills/`, Claude Code carga la descripción de cada una en el system prompt de toda sesión, en todos los proyectos. Limitándolo a `./.claude/skills/` por proyecto pagas el coste solo donde tiene sentido.
- **`.claude/skills/` debería ir al `.gitignore`** de la mayoría de tus proyectos, salvo que quieras compartir las skills con el equipo. Si las compartes, usa `--copy` en lugar de symlinks para que el repo del proyecto sea autocontenido.
- **Auditoría rápida** de qué skills hay activas en un proyecto: `ls .claude/skills/`.
