# C4 Model

## Qué es y qué problema resuelve

El **C4 Model** (creado por Simon Brown) es una forma de diagramar la arquitectura de un sistema de software usando la metáfora de un **mapa con distintos niveles de zoom**: se empieza por la vista más amplia (el sistema entero en su entorno) y se va haciendo zoom hacia el detalle. Su principio rector es la **abstracción antes que la notación**: no requiere UML estricto, lo importante es que cualquier persona entienda el diagrama.

Se llama C4 porque tiene 4 niveles, cada uno con más detalle que el anterior:

1. **Context**
2. **Container**
3. **Component**
4. **Code** (Código)

> Nota: el nivel 4 se llama **Code**, no "Clases". Se suele representar con diagramas UML de clases, pero el nombre del nivel es *Code*.

---

## Nivel 1 — Context

Es la vista más alejada. Muestra el sistema como una **caja negra** (un cuadrado general, sin nada de su interior) **en relación con sus usuarios y los sistemas externos** con los que se comunica.

Elementos:
- **Software System**: tu sistema, una sola caja central.
- **Persons**: usuarios o roles que interactúan con el sistema.
- **External Systems**: otros sistemas con los que el tuyo habla (pasarela de pago, proveedor de email, API de terceros).

Audiencia: **todos**, técnicos y no técnicos. Esconde deliberadamente los detalles internos, la tecnología y los protocolos. Su valor está en mostrar la relación del sistema con el mundo exterior.

---

## Nivel 2 — Container

Primer zoom: se abre la caja del sistema y se muestran las **piezas ejecutables/desplegables** que lo componen.

**Importante:** un *container* en C4 **NO es un contenedor de Docker** y los conceptos no se relacionan directamente. Un container C4 es una **unidad desplegable o ejecutable por separado**:
- Una app de servidor (API service, gateway).
- Un frontend / single-page application.
- Una base de datos.
- Un message broker / cola.
- Un microservicio.

La **tecnología es un atributo del container** (ej: "API Service — Node.js/Express", "Datastore — PostgreSQL"), no el container en sí. Un contenedor Docker puede ser el empaquetado de un container C4, pero el concepto C4 es de límite de despliegue, no de tecnología de empaquetado.

En este nivel las **Persons** y **External Systems** siguen apareciendo, ahora conectados a containers específicos.

**Flechas:** cada conexión debe indicar *qué* información viaja **y el protocolo/mecanismo** por el que viaja (HTTPS/JSON, AMQP, SQL). Eso es lo que la hace útil a nivel técnico.

Audiencia: **técnica** (arquitectos, developers, ops).

---

## Nivel 3 — Component

Zoom dentro de UN container: muestra las **piezas internas** que lo componen y las **responsabilidades** de cada una.

---

## Nivel 4 — Code

Zoom final a la implementación de un componente: **clases, patrones de diseño** y cómo se comporta internamente. Se representa normalmente con diagramas UML de clases.

---

## Cómo se relacionan los niveles

Cada nivel es un zoom-in del anterior, sin agregar conceptos nuevos, solo detalle progresivo:
- **Context** → existe UN sistema y habla con el mundo.
- **Container** → ese sistema por dentro son varias piezas desplegables que se comunican entre sí.
- **Component** → cada pieza desplegable por dentro.
- **Code** → cómo está implementada cada pieza.

---

## Por qué me sirve para mi sistema propio

Para diseñar mi sistema de microservicios, los niveles que realmente voy a usar son **Context** y **Container**:
- El **Context** me deja fijar el alcance: qué es el sistema, quién lo usa y con qué sistemas externos habla.
- El **Container** es donde vivirán mis microservicios: cada servicio, el gateway, el datastore y el message broker serán containers C4, cada uno con su tecnología y sus conexiones etiquetadas con protocolo y propósito.

Component y Code quedan como niveles secundarios para este roadmap.