# TechMarket Orders — Pipeline CI/CD Blue/Green

## Descripción General

Este repositorio implementa un pipeline de CI/CD robusto para el microservicio **TechMarket Orders**, utilizando GitHub Actions, Docker Hub y un clúster Kubernetes (k3s sobre EC2 en AWS Learner Lab).

El pipeline implementa una estrategia de despliegue **Blue/Green** con remediación automática mediante rollback, cumpliendo los requisitos de alta disponibilidad y bajo riesgo del caso TechMarket.

---

## Arquitectura
GitHub Actions
│
├── build.yml (Plantilla reutilizable)
│     └── Build imagen Docker → Push Docker Hub
│
├── deploy.yml (Plantilla reutilizable)
│     └── kubectl apply → rollout status → rollback automático
│
└── release.yml (Pipeline principal)
├── Job: build (usa build.yml)
├── Job: deploy-blue (usa deploy.yml)
└── Job: switch-traffic
├── Aplicar Service
├── Validación de salud
└── Switch de tráfico a Blue

**Infraestructura:**
- Clúster: k3s v1.28.5 sobre EC2 (Amazon Linux 2) en AWS Learner Lab
- Registry: Docker Hub (fabian777omg/proyecto-final)
- IP pública: 54.163.58.119
- Puerto de acceso: 30080 (NodePort)

---

## Estrategia de Despliegue: Blue/Green

### ¿Cómo funciona?

La estrategia Blue/Green mantiene dos entornos idénticos en paralelo:

| Entorno | Deployment | Estado |
|---------|-----------|--------|
| **Blue** | api-cliente-blue | Producción activa |
| **Green** | api-cliente-green | Nueva versión en espera |

**Flujo de despliegue:**
1. Se construye y publica la nueva imagen Docker
2. Se despliega en el entorno **Blue** (o Green según corresponda)
3. Se valida que los pods estén `Ready` con `kubectl wait`
4. El Service de Kubernetes cambia su selector para apuntar al entorno nuevo
5. El tráfico se redirige sin downtime

**Control de tráfico mediante Service:**
El Service de Kubernetes usa `selector` para determinar qué pods reciben tráfico:
```yaml
selector:
  app: api-cliente
  version: blue  # ← cambiar a "green" para switch
```
Al hacer `kubectl patch service`, el tráfico cambia instantáneamente sin reiniciar pods.

**Ventajas sobre Rolling Update:**
- Rollback instantáneo (cambiar selector de vuelta)
- Cero downtime durante el switch
- La nueva versión se valida antes de recibir tráfico real
- Entorno anterior disponible como fallback inmediato

---

## Plantillas Reutilizables (Item 1)

### build.yml
Plantilla reutilizable para construcción y publicación de imagen Docker.

**Inputs:**
- `image_tag`: Tag de la imagen (ej: v13.0.7)
- `docker_username`: Usuario de Docker Hub

**Secrets:**
- `DOCKER_PASSWORD`: Token de acceso a Docker Hub

### deploy.yml
Plantilla reutilizable para despliegue en k3s con rollback automático.

**Inputs:**
- `environment`: Entorno a desplegar (blue/green)
- `image_tag`: Tag de la imagen
- `docker_username`: Usuario de Docker Hub

**Secrets:**
- `KUBECONFIG_DATA`: Kubeconfig del clúster k3s

---

## Mecanismo de Remediación Automática (Item 3)

### Flujo de remediación
Health Check (rollout status)
│
├── ✅ OK → Continúa el pipeline
│
└── ❌ FALLO → Rollback automático
│
└── kubectl rollout undo
│
└── ✅ Deployment restaurado

### Implementación

```yaml
- name: Deploy to k3s
  id: deploy
  run: |
    kubectl apply -f k8s/${{ inputs.environment }}-deployment.yaml
    kubectl rollout status deployment/api-cliente-${{ inputs.environment }} --timeout=60s

- name: Rollback automatico
  if: failure()
  run: |
    kubectl rollout undo deployment/api-cliente-${{ inputs.environment }}
    kubectl rollout status deployment/api-cliente-${{ inputs.environment }} --timeout=60s
```

La condición `if: failure()` garantiza que el rollback **solo se ejecuta cuando el deploy falla**, no en condiciones normales. Esto minimiza el MTTR (Mean Time To Recovery) y reduce la intervención humana ante fallos en producción.

---

## Contribución al Negocio

| Beneficio | Impacto en TechMarket |
|-----------|----------------------|
| **Cero downtime** | El switch Blue/Green no interrumpe el servicio Orders |
| **Rollback en segundos** | Ante un fallo, el sistema se recupera automáticamente |
| **Plantillas reutilizables** | Otros microservicios pueden usar los mismos workflows |
| **Trazabilidad** | Cada despliegue queda registrado con tag en Docker Hub y GitHub |
| **Reducción de errores manuales** | El pipeline automatiza build, push y deploy completos |

---

## Estrategias de Despliegue

| Estrategia | Downtime | Rollback | Costo infraestructura | Riesgo |
|-----------|----------|----------|----------------------|--------|
| **All-in-once (Recreate)** | Alto | Lento | Bajo | Alto |
| **Rolling Update** | Ninguno | Rápido (rollout undo) | Bajo | Medio |
| **Canary** | Ninguno | Rápido (scale a 0) | Medio | Bajo |
| **Blue/Green** ✅ | Ninguno | Instantáneo | Alto | Muy bajo |

**¿Por qué Blue/Green para TechMarket Orders?**
El servicio Orders es crítico — maneja transacciones de pago. Cualquier error en producción tiene impacto directo en ingresos. Blue/Green permite validar la nueva versión antes de exponerla al tráfico real, y el rollback es instantáneo ante cualquier anomalía.

---

## Repositorios

- **Repo cliente:** https://github.com/fabian7t/repo-cliente
- **Docker Hub:** https://hub.docker.com/r/fabian777omg/proyecto-final