# S23 — Los NPC, con cara y con textos revisados

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** M · **Estado:** ⚪ esbozo · **Depende de:** S22 (cómo queda Servicios)

## Origen

El dueño, 2026-10-24 (texto completo en [S21](./S21-game-loop.md#origen)):
"cuando está hablando Nilo o cualquier NPC no sale la cara ni nada de eso",
"dime o ponme los textos de cada NPC que hay en servicio", y "cuando abrí el
juego me habló un tal Aldebaran, no estoy seguro si eso es un servicio o
parte del tutorial".

## Aldebrán: es el tutorial, no un servicio

Es la introducción del tutorial (S10). Antes se llamaba Adamai; c938f28a le
dio nombre propio (`godot/src/gamedata/npc_rename.gd`). Sale **una sola vez**,
la primera vez que entra la cuenta (`main.gd:743-755`, si falta el criterio
229 "coach creado"), con los escenarios 0 y 1 (`scenarios.gd:35-36`). Te
cuenta que te ha capturado un demonio de las horas y que tienes que reclutar
gladiadores y ganar para ser libre. No vuelve a hablar y no aparece en
Servicios. El problema real: **no se presenta**. Sale un nombre sin cara y
el jugador no sabe quién es.

## Por qué no sale la cara

`talk_panel.gd:27-84` pone el nombre como título, el texto y los botones. No
hay ninguna imagen. `_open_npc` (`main.gd:5577`) ignora además el quinto
campo del desc, que en el retail es el estilo del retrato ("bob", "gostIop"…).

En el retail, `npcTalkDialog.xml` tenía un `animatedElementViewer` con estilo
`npcGuiStyle` (`ni_0.java:32`), y el tema (`gui/theme/default.xml:2420-2460`)
lo ataba a animaciones: `bob_interface.anm` (Nilo), `gostSramette`, `gostIop`,
`gostSacri`, `gostEnu` y `demon1.anm`. Están en
`client/compiled/game/contents/animations.jar → animations/gui/` (7 `.anm` con
sus `.tgam`), **sin exportar a Godot**. Aldebrán tenía `adamai_interface.anm`;
en Godot solo está su atlas suelto
(`assets/gui/images/theme/animations/Atlas/adamai_interface_0.png`).

Arte que **ya está** en Godot y sirve:

- `assets/gui/images/breeds/fightTimeline/` (36 PNG de 100×100) y
  `assets/gui/images/theme/images/breeds/` (102 PNG): retratos por clase y
  sexo → los 12 maestros de clase.
- `assets/gui/images/challenges/illustrations/` (16 PNG de 240×140): Demonio
  III (29–31) y otros retos.
- `assets/anims/npc_*` (24 carpetas de sprites de combate).

## Tareas candidatas

- [ ] Exportar las 7 animaciones `animations/gui/*.anm` y la de Aldebrán
      con el pipeline de `.anm` que ya existe, y montarlas en `talk_panel`.
- [ ] Retrato en cada conversación: animado si existe, el de la clase para
      los maestros, la ilustración del reto para los demonios y un marco
      neutro para el resto (Card Master no tenía).
- [ ] Aldebrán se presenta: retrato, nombre y una línea de quién es.
- [ ] Textos: corregir los grupos en francés (S20 #8) y erratas de los datos
      ("acojedor", el doble espacio, "en falta de"/"falto de"). Quitar lo que
      habla de cosas que ya no existen en el lobby: islas, zaaps, mapa (M),
      F4, gostofos, "camina hasta…".
- [ ] Decidir con el dueño si los textos de Nilo se acortan. Hay respuestas
      de ~350 palabras (fusión, grupo 82).

## Anexo: los textos de cada NPC (2026-10-24)

Sacados de `npcdialogs.json` (`locales.es`; la inglesa si falta), con los
nombres de `npc_rename.gd` ya puestos. La lista de Servicios sale de
`elements.json` (`main.gd:3641`) y la conversación la pinta `talk_panel.gd`.

### Los que no hablan

- **Card Master** (14 botones, uno por set): abre la tienda, sin texto.
- **Buzón**, **Altar de fusión** (6), **Fuegos artificiales**: abren su
  panel, sin texto.

### Nilo (antes Baan), el guía — Aprendizaje

- **7:** «Hola. Me llamo Nilo y estoy aquí para guiarte por el Horamundo, la
  dimensión en la que te encuentras. ¿Qué quieres saber?» → «Soy nuevo,
  enséñame todo lo que necesito saber para sobrevivir aquí.»
- **8:** «Muy bien. ¿En qué estás interesado?» Respuestas: «¿Qué enlace existe
  entre Arena, DOFUS y Wakfu?» · «¿Cuál es mi objetivo en este mundo?» ·
  «¿Dónde están los enemigos? ¿Cómo puedo lanzar un combate?» · «¿Cómo se
  lanza un combate?» · «¿Qué tipos de combate hay?» · «Enséñame las bases del
  combate.» · «¿Puedes enseñarme algunos conceptos avanzados…?» ·
  «¡Explícame las particularidades de mi grimorio de jefe! (inventario)» ·
  «J'ai aussi entendu parler de "tacles" kézaco?» (en francés) · «Háblame de
  las cartas.» · «Gracias. Quizás vuelva más tarde.» (sale dos veces; una
  lleva al grupo 69, en francés).
- **42:** «El Horamundo es un enlace entre diferentes lugares y épocas. Desde
  Arena puedes enviar ciertos objetos a DOFUS o a Wakfu. Si participas en
  torneos, podrás ganar fichas que permiten comprar, por ejemplo, ítems
  DOFUS.»
- **10:** «Vale, dirígete a la arena de entrenamiento. Allí tengo un jalató al
  que le encanta encajar golpes.» → «¡Vamos!» lanza el desafío 46 («Tutorial
  de Nilo»), con la lección de los escenarios 200 y 201 (abajo).
- **44:** «Toma, una carta de zaap que te llevará a la guarida del demonio I
  (…) Él podrá enseñarte tácticas útiles para tus próximos combates.»
- **81:** «En cierto modo, los Kardmasters son vendedores de cartas. Podrás
  encontrarlos diseminados a través del Horamundo.»
- **Largos, en español:** 11 (objetivo, clasificación y cartas), 66 («Es muy
  simple lanzar un combate…», con el botón Gestión de equipo), 12 (modos de
  juego; habla de gostofos en "esta isla"), 84 (el grimorio), 82 (el altar
  de fusión, ~350 palabras).
- **En francés en la tabla española:** 76, 69 (orientación, +40 % de daño por
  la espalda), 83 (placaje), 74, 77, 78, 79, 80, 75 (rarezas).
- **Lección del combate de prueba** (escenarios 200 y 201):
  - «Esto comienza a ponerse serio. Antes de nada, puedes colocar tu yopuka
    durante la fase de colocación.»
  - «Al ser un entrenamiento, no tienes tiempo límite, pero en un combate
    real sólo dispondrás de 30 segundos para colocar a todos los guerreros.»
  - «Para colocar un guerrero, selecciónale haciendo clic izquierdo sobre él
    y después selecciona la casilla a la que quieres desplazarlo. Si otro
    guerrero se encuentra en ella, intercambiarán posiciones (ahora no
    tendrás problema, tu yopuka está solo).»
  - «Una vez que lo hayas entendido todo, haz clic en el botón "Listo".»
  - «Ya te has dado cuenta de que, después de la fase de colocación, hay una
    fase de observación que dura 10 segundos.»
  - «Durante la fase de observación, puedes ver dónde se encuentran los
    enemigos y sus características si haces clic en la barra de orden de
    combate arriba a la izquierda.»
  - «En este entrenamiento, he anulado el cronómetro…»
  - «Una vez que te sientas listo, ataca al jalató. Dispones de 3 PM (Puntos
    de Movimiento)…»
  - «¡Muy bien! ¡Le has dado! Otro golpe con "Presión" y lo habrás vencido…»
  - «Puedes ver el total de tus PA (Puntos de Acción)…»

### Los 12 maestros de clase — Aprendizaje

Botones: «Aceptar» (desafío «Prueba de X»), «Reclutar un guerrero» (abre la
creación con esa clase) y «Rechazar».

- **Lía (Feca):** «¡Saludos aventurero! Se te nota un poco perdido...no te
  preocupes, conmigo no corres ningún riesgo. Soy un feca, ¡defensor sin par!
  Nuestro lema es: ¡Sal siempre protegido!»
- **Teodoro (Osamodas):** «Qué raro, no recuerdo haberte invocado... ¿Eres
  nuevo por aquí? Soy un osamodas, invocador y domador de criaturas. ¡Es muy
  práctico durante un combate! O cuando quiero un nuevo par de botas forradas
  en piel...»
- **Rufo (Sadida):** «¡Bienvenido, joven! Soy un sadida. Cuando no estoy al
  día con mis ungüentos o venenos ¡juego a las muñecas! Adelante ríete todo
  lo que quieras, pero si un día tienes que tratar con ellas, no creo que
  siga pareciéndote divertido...»
- **Elvio (Zurcarák):** «¡Saludos al nuevo! Soy un zurcarák, jugador
  empedernido. ¡Las grandes apuestas no me dan miedo! Cuando la fiebre del
  juego me invade, imposible detenerme...por otro lado, ¿qué me dices de una
  pequeña partida? Amistosa, claro...»
- **Mateo (Ocra):** «¡Hola aventurero! Me ha dicho un pajarito que eres nuevo
  por aquí... Yo soy un ocra, ¡y nadie maneja tan bien los arcos como yo!
  ¿Quieres que te lo demuestre? ¡Da media vuelta y empieza a correr!»
- **Tobías (Xelor):** «Te deseo la bienvenida aventurero. Soy un xelor y
  domino el tiempo. ¿Ralentizar a un enemigo? ¿Teletransportarse? ¡Eso es
  fácil! Y sí, amigo mío... ¡saber pelear es tan importante como pelear a la
  hora!»
- **Zoe (Aniripsa):** «¡Bienvenido aventurero! Tu cara no me dice nada...
  debes ser nuevo por aquí. Soy un aniripsa, mi particularidad es: curar
  mediante la palabra, y de las grandes heridas me ocupo yo. En resumen, soy
  ¡el gran remedio! Como dicen por ahí...»
- **Bombín (Pandawa):** «¡Hola! ¡Hip!...aventu ¡hip!...soy un pandawa
  guerrero y aumento mi fuerza gracias a la ¡hip! Bebida...¡epa! Tó da
  vueltaaaas...pero si quieres ¡hip! Saber un poco más sobre mí, podemos
  conversar con unas copillas de por medio, ¡hip!»
- **Fermín (Anutrof):** «¡Ahí tienes! Un recién llegado...¡Qué hermosa
  sorpresa! ¿Qué me has venido a traer? ¿Cómo que nada? Soy una anutrofita y
  los kamas ¡son mi afición! ¿Te molestaría que eche un ojeada dentro de tu
  bolsa?»
- **Nerea (Sacrógrito):** «¡Hey tú! Bienvenido, soy un sacrógrito, también
  llamado berserker. Cuando mis enemigos me golpean, ¡no hacen más que
  aumentar mis fuerzas! Por otra parte, ¿tú no querrás golpearme verdad? Hoy
  me siento un poco débil...»
- **Aurelio (Yopuka):** «¡Hey tú! ¿Porqué has mirado mi peinado de esa forma?
  Soy un yopuka, ¡guerrero belicoso y sin reproches! Nuestro lema es: ¡Atacar
  y luego reflexionar! O atacar sin reflexionar... no lo sé...»
- **Saeta (Sram):** «¡Buenos días aventurero! Soy un sram, ladrón y asesino.
  Bueno, de acuerdo, no es algo de lo que estar orgulloso... ¡Pero te aseguro
  que puede ser muy útil! Estoy convencido de que el día que desees una joya
  pensarás en mí...»

Todos tienen un texto más que el juego nunca usa: «Mmm... tienes demasiados
luchadores bajo tus órdenes…».

### Demonio III — Aprendizaje (3 desafíos seguidos)

- **La primera vez:**
  - «¡Hola aventurero! Es increíble lo pequeño que eres. ¿Se te ha olvidado
    crecer o qué? Bueno, al menos debes saber quién soy, por las dudas me
    presento, soy el demonio III y estoy buscando jefes, los más fuertes, ¡los
    verdaderos! Demuéstrame que no eres un blandengue...»
  - «Si no quieres quedarte en esta isla por tiempo indefinido, debes realizar
    los 3 desafíos que voy a proponerte. A menos que prefieras quedarte aquí
    hasta el final de tus días, eres tú quien decide... Pero antes que eso,
    debes reclutar a tres guerreros. Si no hay guerreros, no hay desafíos ¿de
    acuerdo? ¿Te ha quedado claro en tu cabeza de chorlito?»
  - «Bueno, ve a ver a los maestros de clase, ellos te ayudarán. Para
    encontrarlos, puedes utilizar tu mapa (clic en M). Si eres muy perezoso
    para caminar, puedes reclutar a los guerreros haciendo clic en la interfaz
    de gestión de equipo (el botón con las dos espadas, F4).»
- **Sin los 3 reclutas:** «¿Te burlas de mi? ¿Y los guerreros que debías
  traerme? ¿Los has perdido en el camino? Te doy una última oportunidad, pero
  ésta vez, ¡trata de no perder de vista tu misión! ¡No estamos aquí para
  divertirnos!»
- **Con ellos:** «Perfecto, parece que tu equipo sabe lo que hace, ahora vas a
  poder intentar superar mis 3 desafíos. ¿Estás listo?» Ofrece el primer,
  segundo y tercer desafío.
- **Al acabar:** «¡Bien hecho pequeñín! Pareces estar listo para enfrentarte a
  los adversarios más tenaces. Ten, una carta de zaap, utilízala en el zaap
  situado al noreste de la isla. ¡Adiós! Si vuelves a Maknala, pasa a verme,
  tendré otros desafíos que proponerte.»

### Retos

- **Demonio III:** «Hummm, me parece que tú llegarás lejos. ¡Enséñame de lo
  que eres capaz en combate! Yo podría enseñarte algunos trucos para que
  sobrevivas... y ¿quién sabe? ¡Quizás algún día puedas luchar para mí en las
  arenas de combate!» Desafíos: Desafío rollo, Los reyes del empuje,
  Paradoja xelórica.
- **Tofu de SuperBidi:** «¡Oye Men! ¿Qué haces ahí? ¿No has oído hablar de los
  Hell's Tofus? ¿Les pido ya que preparen tu ataúd o lo dejamos para más
  tarde?» Desafío: ¡Hell's tofus of the death!

### Retos de demonio

- **Demonio del segundo 37** («Rescatando a Bernabé»):
  - Intro, la primera vez:
    - «¡Mira, ahí está 37! II es uno de los esclavos del demonio del minuto
      12. Seguro que te acuerdas de él: ¡es el demonio al que te enfrentaste
      cuando llegaste al Horamundo!»
    - «Ha construido una prisión en la que está encerrado un detenido de gran
      importancia para su maestro. Según él, es impenetrable. ¿Qué te
      parecería probarle que se equivoca?»
    - «¡No olvides que el tener 100% de resistencia no le hace invulnerable!
      Si tus bonus a los daños son suficientemente altos, tus golpes podrán
      afectar al objetivo.»
  - Oferta: «¿Qué estoy oyendo? ¿Quieres liberar a nuestro prisionero? ¡Ja,
    ja! No tienes ninguna posibilidad de hacerlo, he mejorado el sistema de
    prisión cristalina de mi maestro. ¡Ahora es invulnerable!»
- **Demonio del minuto 46** (intro, la primera vez):
  - «Él es el demonio del minuto 46. Le llamamos el "sniper". Para vencerlo,
    avanza hacia él protegiéndote gracias a los obstáculos y ¡mantente atento
    a tus cartas de eventos!»
  - «Tus cartas de eventos aparecen arriba a la derecha de tu pantalla. La
    primera es aquella que se activa para el turno actual. Ella aportará
    beneficios o perjuicios a todos los guerreros presentes en el combate.»
  - «Las dos otras cartas de eventos se activarán en el próximo turno. ¡El
    secreto de un buen jefe es echarles siempre una ojeada para preparar la
    mejor estrategia!»
  - «Para este desafío, deberás utilizar las cartas de eventos que podrán ser
    de tu beneficio. No olvides esconderte bien cuando las cartas del demonio
    del minuto 46 aparezcan.»
- **Minutos 46, 25, 58 y 52** (la misma oferta): «¿Qué, qué? ¿Realmente crees
  que puedes vencerme? El demonio I debe estar en falta de guerreros como
  para enviarme a mequetrefes como tú... Adelante, ¡muéstrame lo que sabes
  hacer!» (el 58 dice «falto de»). Las intros 111, 112 y 114 no existen.
- **Minuto 12** (pide el logro 278). Si no lo tienes: «No eres digno de
  enfrentarte a mí. Intenta vencer a los otros cuatro demonios de los minutos
  que se encuentran en esta isla. Si regresas, me dignaré a concederte un
  duelo.»

### Demonio I — Demonios

- **Sin el logro 277:**
  - «Entonces, ¿quieres probar fortuna en el gran torneo? Has llegado en el
    momento justo, hemos tenido muchas pérdidas estos últimos tiempos, ¡un
    poco de sangre nueva no nos vendrá nada mal!»
  - «Para validar tu inscripción, debes pasar las pruebas de clasificación.
    ¡Al público no le interesa perder su tiempo con debutantes!»
  - «Si consigues vencer a los otros cinco demonios presentes en la isla,
    podrás irte con el pase al gran torneo en tus manos.»
- **Con él:**
  - «He escuchado decir que has triunfado venciendo a los cinco demonios de
    los minutos, ¡bien hecho! ¡Dame cinco! ¡Ah, pero si ya lo has hecho!
    ¡jajaja!»
  - «Mmm... bueno, has demostrado que eres digno de participar en el gran
    torneo. ¡Te daré el pase en seguida! Toma esta carta de zaap, te permitirá
    entrar en las otras islas.»

### Aldebrán — el tutorial, la primera vez que entra la cuenta

- **Escenario 0:**
  - «¡Ay! ¡Ay! ¡Ay!»
  - «¿Qué es esto? ¿Y tú quién eres?»
  - «¡Aghhh! Ya no se puede dar un paseo dimensional sin meterse en un sitio
    lleno de basura...»
  - «A menos que... ¡Esto tiene que ser un truco de los demonios de las
    horas! No andan muy lejos, ¿verdad?»
  - «Ya veo, no tienes ni idea de qué estoy hablando. Te explico: mi nombre es
    Aldebrán. Te ha capturado un demonio de las horas, ¡estás siendo
    teletransportado hacia su mundo! Una vez allí, tendrás que reclutar una
    tropa de gladiadores que lucharán por ti...»
  - «Si tú y tus guerreros obtenéis un número suficiente de victorias, os
    clasificaréis los primeros y... ¡Seréis libres!»
  - «Si no... en fin... morirás.»
  - «¡Cuidado! ¡Agárrate!»
- **Escenario 1:**
  - «Hay dos o tres cosas que debes saber. Puede que pases un mal rato si no
    te lo cuento.»
  - «Hemos llegado al Horamundo y créeme, no es el lugar más acojedor que
    conozco.»
  - «Corres el riesgo de cruzarte con algunos demonios de las horas en algún
    rincón. Te aconsejo hacer lo que ellos te dicen. No les gusta demasiado
    que se les contradiga.»
  - «Bueno, voy a tener que dejarte, no puedo quedarme por aquí mucho tiempo.»

Los logros 278–281, 284, 454 y 455 disparan otros monólogos (escenarios 115,
116, 105, 106, 107, 118 y 119), con el título genérico «Tutorial».

## Criterio de cierre

Cada NPC que habla tiene cara; Aldebrán se presenta; ningún texto en francés
dentro del español ni que hable de sitios que el lobby ya no tiene. El dueño
lo aprueba en la Ally.
