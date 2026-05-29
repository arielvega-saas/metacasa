# Content Rating (IARC) — Google Play Console · Home Finance

> Sección **Política de la app → Calificación de contenido** del Play Console.
> El cuestionario IARC se completa una vez y genera ratings para todas las regiones
> (ESRB en América, PEGI en Europa, USK, ClassInd Brasil, etc.).
>
> **Categoría a elegir al inicio del cuestionario:** *Utilidad, productividad, comunicación u otra* → la opción correcta es **"Todas las demás categorías de apps"** (NO "Juego"). Home Finance es una app de finanzas/productividad.
>
> **Resultado esperado:** **Everyone / Para todos / PEGI 3 / Livre**. Una app de finanzas personales sin contenido sensible debería calificar para la audiencia más amplia. Lo único que puede mover la aguja es la presencia de **funciones sociales** (invitar miembros) y de **compras digitales** — ambas se declaran abajo con honestidad.

---

## Respuestas al cuestionario

> Formato IARC: mayormente Sí/No. Para Home Finance, **todo "No" salvo dos** ("interacción entre usuarios" y "compras digitales"), justificado a continuación.

### Violencia
| Pregunta | Respuesta | Justificación |
|---|---|---|
| ¿La app contiene violencia (realista, fantástica, sexual, tortura, etc.)? | **No** | App de finanzas. Cero contenido violento. |
| ¿Sangre o gore? | **No** | — |

### Contenido sexual
| Pregunta | Respuesta | Justificación |
|---|---|---|
| ¿Desnudez, contenido sexual o sugestivo? | **No** | — |

### Lenguaje
| Pregunta | Respuesta | Justificación |
|---|---|---|
| ¿Lenguaje grosero / vulgar? | **No** | El copy y el asistente de IA usan lenguaje neutral y profesional. El system prompt del asistente tiene guardrails (no off-topic, tono profesional — ver IOS_AUDIT.md §7). |

### Sustancias controladas
| Pregunta | Respuesta | Justificación |
|---|---|---|
| ¿Referencias a drogas, alcohol o tabaco? | **No** | — |

### Juegos de azar (gambling)
| Pregunta | Respuesta | Justificación |
|---|---|---|
| ¿La app simula juegos de azar? | **No** | — |
| ¿Permite apostar dinero real / es una app de gambling? | **No** | Es gestión de finanzas personales. No hay apuestas, loterías ni casino. |

> ⚠️ Aclaración por las dudas: que sea una app de "dinero" **no** la hace gambling. IARC distingue *gestión financiera* de *apuestas*. Responder **No** con confianza.

### Miedo / Horror
| Pregunta | Respuesta | Justificación |
|---|---|---|
| ¿Contenido que pueda asustar a niños? | **No** | — |

### Interacción entre usuarios / Social
| Pregunta | Respuesta | Justificación |
|---|---|---|
| ¿Los usuarios pueden **interactuar o comunicarse** entre sí? | **Sí (limitado)** | La función de **hogar multi-usuario** permite invitar miembros por email y compartir el mismo presupuesto. **No hay** chat libre, comentarios públicos, ni mensajería abierta entre desconocidos. La interacción se limita a miembros que el usuario invita explícitamente a su hogar privado. |
| ¿La app comparte la **ubicación** del usuario con otros? | **No** | Sin location. |
| ¿Permite compartir contenido generado por el usuario con el público? | **No** | Los datos del hogar son privados (RLS por hogar). No hay feed público ni perfiles públicos. |

> **Por qué importa ser preciso acá:** marcar "interacción entre usuarios = Sí" puede agregar un *interactive elements* descriptor ("Users Interact") pero **no sube** la edad mínima por sí solo. Es honesto y no penaliza. NO marcar funciones que no existen (chat público) para evitar un rating más alto innecesario.

### Compras digitales
| Pregunta | Respuesta | Justificación |
|---|---|---|
| ¿La app ofrece **compras digitales** (in-app purchases)? | **Sí** | Suscripción Premium (mensual/anual) vía Google Play Billing, con prueba de 7 días. Esto agrega el descriptor *"Compras digitales / In-App Purchases"* a la ficha, lo cual es **obligatorio y correcto**. No afecta la calificación de edad base. |

### Otros descriptores
| Pregunta | Respuesta | Justificación |
|---|---|---|
| ¿Contenido que recopila/comparte ubicación con terceros? | **No** | — |
| ¿La app es un navegador o permite acceso sin filtrar a internet? | **No** | Solo abre enlaces legales (política/términos) vía `url_launcher`. No es un navegador. |
| ¿Contenido de noticias o generado por terceros sin moderar? | **No** | El asistente de IA responde sobre las finanzas del propio usuario, con guardrails; no es un feed de contenido de terceros. |

---

## Audiencia objetivo y contenido (Target Audience — sección separada del Play Console)

> Esto es **distinto** del cuestionario IARC, pero relacionado. Google pregunta a qué grupos de edad apunta la app.

| Pregunta | Respuesta recomendada | Justificación |
|---|---|---|
| Grupos de edad objetivo | **18 y más** (o como mínimo 13+) | App de finanzas personales con suscripción de pago y gestión de dinero real → audiencia adulta. **Recomendado: marcar solo 18+** para evitar las obligaciones de la *Families Policy* de Google. NO incluir ningún rango infantil (menores de 13). |
| ¿La app apunta a niños? | **No** | Coherente con privacy-policy.md §7 (no dirigida a menores de 13 COPPA / 16 GDPR). |
| ¿Podría atraer a niños accidentalmente (apariencia, personajes)? | **No** | Diseño "Midnight Sage" sobrio, editorial, orientado a adultos. Sin personajes ni gamificación infantil. |

> **Consecuencia de marcar 18+:** la app **no** entra en Google Play Families, no requiere las divulgaciones extra de Families, y el rating efectivo será "Para mayores de X" según región pero sin fricción de COPPA.

---

## Resumen del rating esperado

| Sistema regional | Rating esperado |
|---|---|
| ESRB (América) | **Everyone** (con descriptores: *In-App Purchases*, *Users Interact*) |
| PEGI (Europa) | **PEGI 3** (+ *In-Game Purchases*) |
| USK (Alemania) | **USK 0** |
| ClassInd (Brasil) | **Livre** |
| Google Play (global) | **Para todos** |

> Si el cuestionario arroja algo más alto, revisar que no se haya marcado por error alguna pregunta de violencia/gambling. El perfil honesto de esta app es: **Para todos + descriptores de compras digitales e interacción de usuarios**, con **target audience 18+** elegido por prudencia financiera/legal.
