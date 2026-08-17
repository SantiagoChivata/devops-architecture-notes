# ADR-001: Arquitectura de microservicios y criterio de división de servicios

## Estado

Aceptada — 2026-08-17

## Contexto

El **DevOps Dashboard** es un sistema propio cuyo objetivo es servir como laboratorio
para aplicar de forma incremental prácticas y tecnologías DevOps (CI/CD, contenedores,
IaC, orquestación, observabilidad). Funcionalmente es sencillo: gestiona y visualiza
servicios/aplicaciones, sus deployments, versiones, historial, health checks y métricas
básicas.

Al definir la arquitectura base surgieron dos decisiones acopladas:

1. **¿Monolito o microservicios?** Un monolito modular sería más simple de construir y
   operar para este dominio, que no tiene alta complejidad de negocio. Sin embargo, uno
   de los objetivos explícitos del proyecto es **demostrar y practicar patrones de
   microservicios** (API Gateway, comunicación entre servicios, database-per-service,
   consistencia eventual), que son competencias esperadas en roles de DevOps/Cloud
   Engineer.

2. **Si se eligen microservicios, ¿por dónde trazar la frontera entre servicios?** Se
   evaluaron dos criterios de división:
   - **Por entidad**: un *Services Service* y un *Deployments Service*. Problema: un
     deployment no existe sin un servicio; ambas entidades se consultan casi siempre
     juntas, lo que genera alto acoplamiento y comunicación excesiva ("chatty") entre
     servicios. Es partir un mismo *bounded context* de forma artificial.
   - **Por capacidad / razón de cambio**: un *Core Service* (dominio: servicios +
     deployments + versiones) y un *Health/Monitoring Service* (health checks y
     métricas). Esta frontera separa componentes que cambian y escalan por razones
     distintas, y habilita un caso de uso asíncrono real.

## Decisión

Se adopta una **arquitectura de microservicios**, priorizando el objetivo de aprendizaje
por encima de la simplicidad operativa que ofrecería un monolito.

Los servicios se dividen **por capacidad y razón de cambio**, no por tipo de entidad:

- **Core Service** (Python/FastAPI) — CRUD del dominio: servicios, deployments, versiones
  e historial, que están fuertemente relacionados y se consultan juntos. Cambia cuando
  cambian las reglas del dominio.
- **Health/Monitoring Service** (Python/FastAPI) — health checks y métricas. Patrón de
  uso distinto (escritura de alta frecuencia, series temporales) y escalado independiente.
  Cambia según las necesidades de observabilidad.

Decisiones de soporte asociadas:

- **API Gateway** como único punto de entrada; el frontend no conoce la topología interna.
- **Database-per-service**: cada microservicio es dueño de sus datos (Core DB y Health
  DB); no hay base de datos compartida.
- **Comunicación mixta**: REST síncrono para el flujo usuario → gateway → servicios;
  mensajería asíncrona (AMQP, RabbitMQ) para eventos entre servicios. Caso de uso
  concreto: cuando el Health/Monitoring Service detecta un health check fallido, emite el
  evento `health.failed`; el Core Service lo consume y actualiza el estado del servicio.

## Alternativas consideradas

- **Monolito modular.** Más simple de construir, desplegar y operar; sin problemas de
  consistencia distribuida. Descartado porque no permite practicar los patrones de
  microservicios que el proyecto busca demostrar. Se documenta como la opción que se
  elegiría si el criterio fuese exclusivamente entregar el producto con el mínimo esfuerzo
  operativo.
- **Microservicios divididos por entidad (Services / Deployments).** Descartado por el
  alto acoplamiento entre ambos servicios (un deployment siempre depende de un servicio) y
  porque el message broker no tendría un caso de uso asíncrono genuino, resultando en
  over-engineering.

## Consecuencias

### Positivas

- Permite practicar patrones reales de sistemas distribuidos: API Gateway, mensajería
  asíncrona, database-per-service.
- La división por capacidad mantiene bajo el acoplamiento entre servicios y da al message
  broker un caso de uso justificado (`health.failed`).
- Cada servicio puede evolucionar, desplegarse y escalar de forma independiente — el
  Health/Monitoring Service es el candidato natural a escalar por su carga de escritura.
- La decisión queda documentada y es defendible en entrevistas: se corta por razón de
  cambio, no por sustantivos.

### Negativas / trade-offs aceptados

- **Mayor complejidad operativa** que un monolito: más piezas que desplegar, observar y
  depurar. Se asume conscientemente como parte del objetivo de aprendizaje.
- **Consistencia eventual**: al no haber transacciones ACID entre servicios, la
  reconciliación de datos entre Core y Health se maneja vía eventos, no de forma atómica.
- **Punto único de falla en el API Gateway**: en producción requeriría múltiples
  instancias tras un balanceador de carga (fuera del alcance del MVP; es detalle de
  deployment, no de arquitectura de aplicación).
- **Autenticación fuera del MVP**: el dashboard se asume en red interna; la auth se
  añadirá más adelante como cross-cutting concern en el gateway.

## Notas

Este ADR corresponde al diseño C4 nivel Container documentado en
`diagrams/c4-container-devops-dashboard.md`. La arquitectura evolucionará en fases
posteriores del roadmap (contenedores, orquestación, CI/CD, observabilidad); decisiones
futuras se registrarán en nuevos ADRs.