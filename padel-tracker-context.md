# Padel Tracker — Documento de contexto del proyecto

## Visión general

App de tracking de pádel para relojes Garmin con app móvil companion. El objetivo principal es **maximizar la captura de datos con la mínima fricción posible** durante el partido. El registro se hace a nivel de juego (no de punto) para reducir la carga cognitiva.

---

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| App Garmin | Monkey C + Connect IQ SDK |
| App móvil | React Native (iOS + Android) |
| Comunicación reloj → móvil | Connect IQ Communication API |
| Backend | Supabase (tier gratuito) |
| Base de datos | PostgreSQL (via Supabase) |
| Autenticación | Supabase Auth |

---

## App Garmin

### Modelo físico del reloj

Reloj **redondo** con 5 botones físicos:
- **Izquierda** (de arriba a abajo): LIGHT · UP · DOWN
- **Derecha** (de arriba a abajo): START/STOP · BACK/LAP

### Mapeo de botones

| Botón | Posición | Evento |
|---|---|---|
| LIGHT | Izq. arriba | Saque propio |
| UP | Izq. medio | ENF (error no forzado) |
| DOWN | Izq. abajo | Deshacer |
| START/STOP | Der. arriba | Juego ganado |
| BACK/LAP | Der. abajo | Juego perdido |
| START largo | Der. arriba | Menú de edición |

**Nota de compatibilidad:** LIGHT dentro de una actividad activa se puede reasignar en el contexto de la app via Connect IQ SDK. Validar comportamiento en modelos con pantalla MIP siempre encendida (Fenix).

### Modelo de datos por juego

```
juego {
  id: integer
  set: integer
  numero_juego: integer
  saque: boolean          // máx. 1 por juego, via LIGHT
  enf: integer            // contador acumulable, via UP
  resultado: 'ganado' | 'perdido'   // cierra el juego, via START o LAP
  timestamp: datetime
}
```

### Lógica de eventos

- **ENF:** acumulable, indefinidos por juego
- **Saque:** máximo 1 por juego. Se puede marcar en cualquier momento durante el juego. Se "consume" automáticamente al cerrar el juego con resultado
- **Deshacer:** pila LIFO — deshace el último evento registrado del tipo que sea. Si la pila del juego actual está vacía, deshace el resultado del juego anterior y lo reabre
- **Feedback:** cada evento genera una pantalla fullscreen de 1.5 segundos con vibración corta, luego vuelve al dashboard

### Lógica de sets

- Detección **automática** de cambio de set cuando el marcador alcanza los juegos configurados
- Si vosotros sacáis primero, el juego 1 arranca con indicador de saque activo
- Si hay tie-break activo en 6–6, se detecta y gestiona automáticamente
- Si la edición manual del marcador implica un cambio de set no detectado, la app pregunta "¿Iniciar set X?" antes de continuar

### Ajustes configurables del partido

| Ajuste | Valor por defecto |
|---|---|
| Juegos por set | 6 |
| Tie-break | Activado en 6–6 |
| Punto de oro | Desactivado |

---

## Pantallas del reloj — 9 estados

### 1. Inicio

Aparece al iniciar la actividad. Sin pantalla de bienvenida, sin logos.

**Paso 1 — Posición:**
- Pregunta: "¿Tu posición?"
- Opciones navegables con UP/DOWN, confirmar con START: DRIVE / REVÉS

**Paso 2 — ¿Quién saca primero?**
- Misma estructura
- Opciones: NOSOTROS / ELLOS

Tras confirmar arranca directamente el dashboard.

---

### 2. Dashboard principal

Pantalla principal durante el partido. Jerarquía visual en 4 niveles:

**Nivel 1 — Sets:**
- Puntos llenos = sets ganados, puntos vacíos = sets rivales
- Máximo 3 puntos por lado (al mejor de 3 sets)

**Nivel 2 — Marcador de juegos (número más grande):**
- Juegos propios en blanco, juegos rivales en gris
- Subtexto: "set X · juego Y"

**Nivel 3 — Métricas del partido:**
- ENF totales
- % ENF = ENF totales / juegos jugados
- % juegos ganados con saque propio
- % juegos ganados sin saque propio

**Nivel 4 — Estado del juego actual (indicadores pequeños):**
- Rectángulo azul = sacas en este juego
- Puntos naranjas = ENF acumulados en el juego actual

---

### 3. Feedbacks fullscreen — 5 variantes

Duración: 1.5 segundos + vibración corta al aparecer. Luego vuelve al dashboard.

| Variante | Fondo | Icono | Etiqueta | Sublínea |
|---|---|---|---|---|
| Juego ganado | Verde oscuro | ✓ | GANADO | "Juego X · con/sin saque" |
| Juego perdido | Rojo oscuro | ✗ | PERDIDO | "X ENF este juego" o vacío |
| ENF | Naranja oscuro | ! + contador | ENF | "este juego" |
| Saque | Azul oscuro | ◎ | SAQUE | "juego X · drive/revés" |
| Deshacer | Gris neutro | ↩ | DESHECHO | "ENF eliminado" / "saque eliminado" / "juego reabierto" |

---

### 4. Resumen de set

Aparece automáticamente al detectar cambio de set. Duración: 3 segundos + vibración. Desaparece sola.

- Cabecera: "SET X TERMINADO" (o "SET X · TIE-BREAK" si aplica)
- Marcador del set en grande — blanco tú, gris ellos
- Separador
- ENF totales del set
- % juegos ganados con saque en ese set
- % juegos ganados sin saque en ese set
- Marcador de sets actualizado en parte inferior

Tras desaparecer, el dashboard resetea el marcador de juegos a 0–0 manteniendo las métricas acumuladas del partido.

---

### 5. Menú de edición

Acceso: START largo. Salir: BACK/LAP vuelve al dashboard.
Navegación: UP/DOWN para moverse, START para confirmar.

**5 opciones:**

1. **Editar juego anterior** — modifica resultado, saque y ENF del último juego cerrado. Solo el último juego, ediciones más profundas en app móvil
2. **Cambiar posición** — toggle directo Drive/Revés, vuelve al dashboard
3. **Editar marcador** — corrige marcador de juegos del set actual y marcador de sets. Campos en orden: juegos propios → juegos rivales → sets propios → sets rivales. Una pantalla por campo
4. **Ajustes del partido** — tie-break, punto de oro, juegos por set
5. **Terminar partido** — confirmación explícita "START=sí BACK=no", genera resumen final y cierra actividad Garmin

---

### 6–7. Editar juego anterior y Ajustes del partido

Submenús accesibles desde el menú de edición. Ver opciones detalladas en sección 5.

---

### 8. Terminar partido

Pantalla de confirmación: "¿Terminar partido? START=sí BACK=no". Al confirmar genera resumen final.

---

### 9. Resumen final

4 páginas navegables con UP/DOWN. No desaparece sola — el usuario controla cuándo cerrar. Al final de la página 4, START guarda y cierra la actividad.

**Página 1 — Resultado:**
- Ganado/perdido en color (verde/rojo)
- Marcador de sets
- Duración total del partido
- Juegos totales jugados

**Página 2 — Saque:**
- % juegos ganados con saque propio
- % juegos ganados sin saque propio
- Total juegos con saque / sin saque
- Diferencia entre ambos

**Página 3 — Errores no forzados:**
- ENF totales
- % ENF sobre juegos jugados
- Desglose por set
- Mejor set (menos ENF)

**Página 4 — Histórico:**
- Gráfico de línea ENF por partido — últimos 10 partidos, punto actual destacado
- % victorias histórico
- Racha actual

---

## App móvil — React Native

### Estructura — 3 secciones principales

#### Sección 1 — Partido

Si hay partido activo sincronizándose desde el reloj: dashboard en tiempo real.

Si no hay partido activo: botón para iniciar registro manual con:
- Posición inicial
- Quién saca primero
- Ajustes del partido (tie-break, punto de oro, juegos por set)
- Contexto opcional: club, pista, compañero, nivel de rivales

Durante registro manual: interfaz táctil con botones grandes para juego ganado, perdido, ENF, saque. Pensada para usar entre juegos, no en plena jugada.

Al terminar genera resumen equivalente al del reloj.

---

#### Sección 2 — Historial

Lista cronológica de partidos, más reciente primero.

**Vista de lista — cada entrada muestra:**
- Fecha y duración
- Resultado con marcador de sets
- ENF totales
- Contexto si fue registrado

**Vista de detalle de partido:**
- Marcador completo set a set
- Métricas completas por set: ENF, rendimiento con/sin saque
- Si hay compañero conectado y jugasteis juntos: vista combinada con stats cruzadas
- Edición de contexto a posteriori

**Filtros:** por resultado, por compañero, por rango de fechas

---

#### Sección 3 — Progreso

Dos pestañas: **Yo** y **Pareja**

**Pestaña Yo:**
- Gráfico de línea ENF por partido — últimos 20 partidos con tendencia
- Gráfico de línea % victorias
- Rendimiento con saque vs sin saque — evolución histórica de ambos en el mismo gráfico
- Racha actual y mejor racha
- Métricas inferidas:
  - Juegos ganados por partido de media
  - ENF por juego de media (normalizado por duración)
  - Índice de consistencia: ratio de partidos bajo tu media histórica de ENF por juego

Filtros: últimos 10 / 20 / todos, por compañero

**Pestaña Pareja** (solo visible con compañero conectado):
- Solo partidos jugados juntos
- % victorias como pareja
- ENF combinados por partido — evolución
- Comparativa individual: quién acumula más ENF, quién rinde mejor con saque
- Mejor y peor partido juntos
- Racha actual como pareja

---

### Modelo social — v1

**Conexión de pareja:**
- Búsqueda por nombre de usuario o código QR
- El compañero acepta la conexión (opt-in)
- Puede revocarla en cualquier momento
- Al jugar juntos y ambos tener sesión del mismo partido, la app cruza los datos automáticamente por timestamp

**Visibilidad mutua:**
- ENF por partido y evolución histórica
- % victorias
- Rendimiento con/sin saque
- Stats combinadas de pareja

**v2 (roadmap):**
- Escalar a modelo social más amplio tipo Strava — seguir a otros jugadores, feed de progreso, comparativas de grupo
- Integración con Playtomic y PlaybyPoint para contexto automático de partidos

---

## Modelo de datos — PostgreSQL

```sql
-- Usuarios
users {
  id: uuid PK
  username: string
  email: string
  created_at: timestamp
}

-- Conexiones de pareja
partner_connections {
  id: uuid PK
  user_id: uuid FK → users
  partner_id: uuid FK → users
  status: 'pending' | 'accepted' | 'revoked'
  created_at: timestamp
}

-- Partidos
matches {
  id: uuid PK
  user_id: uuid FK → users
  source: 'garmin' | 'manual'
  started_at: timestamp
  ended_at: timestamp
  resultado: 'ganado' | 'perdido'
  sets_propios: integer
  sets_rivales: integer
  -- Ajustes del partido
  juegos_por_set: integer   -- default 6
  tie_break: boolean        -- default true
  punto_de_oro: boolean     -- default false
  -- Contexto opcional
  club: string
  pista: string
  compañero_id: uuid FK → users
  nivel_rivales: string
}

-- Sets
sets {
  id: uuid PK
  match_id: uuid FK → matches
  numero: integer
  juegos_propios: integer
  juegos_rivales: integer
  tie_break: boolean
}

-- Juegos
games {
  id: uuid PK
  match_id: uuid FK → matches
  set_id: uuid FK → sets
  numero: integer
  saque: boolean
  enf: integer
  resultado: 'ganado' | 'perdido'
  timestamp: datetime
}
```

---

## Hoja de ruta — 4 fases

**Fase 1 — Núcleo del reloj**
- App Garmin completa: 5 botones, eventos, dashboard, resumen final
- Validar registro en pista
- Sin app móvil aún

**Fase 2 — App móvil básica**
- Historial de partidos sincronizados desde el reloj
- Visualización de stats individuales
- Registro manual de partidos

**Fase 3 — Progreso y pareja**
- Sección de progreso con gráficos históricos
- Conexión con compañero y stats combinadas

**Fase 4 — Integraciones externas**
- Playtomic y PlaybyPoint para contexto automático
- Modelo social ampliado

---

## Notas para el desarrollo

- Compatibilidad objetivo inicial: Garmin Forerunner 255/265, Fenix, Venu. Validar comportamiento de LIGHT en modelos con pantalla MIP
- El SDK de Garmin Connect IQ permite interceptar LIGHT dentro de una actividad activa
- La comunicación reloj → móvil usa Connect IQ Communication API — los datos se sincronizan al terminar la sesión o en tiempo real con Bluetooth activo
- El histórico en el reloj (página 4 del resumen final) usa datos locales almacenados en el propio reloj — máximo 10 partidos por limitación de memoria
- El histórico completo vive en Supabase y se consulta desde la app móvil
