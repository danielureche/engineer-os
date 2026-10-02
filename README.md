# Guía de Instalación y Verificación del Entorno

Esta guía detalla el proceso de instalación, verificación previa del contexto de Kubernetes/Istio y la ejecución de diagnósticos mediante el CLI de la herramienta.

---

## 1. Configuración del Entorno Virtual e Instalación

1. **Crear el entorno virtual:**
   ```bash
   python -m venv .venv
   ```

2. **Activar e instalar el proyecto en modo editable:**
   ```bash
   pip install -e .
   ```

3. **Verificar los paquetes instalados:**
   ```bash
   pip list
   ```

---

## 2. Verificación Básica del CLI

Antes de proceder a diagnósticos complejos, verifica que el CLI está correctamente instalado y accesible:

```bash
# Probar la ejecución directa del módulo
python -m engineer.cli.main --help

# Si el comando anterior funciona, prueba el ejecutable
engineer --help
```

> ⚠️ **IMPORTANTE:** **NO** ejecutes el comando `engineer diagnose ...` todavía.

---

## 3. Verificación de Conectividad con Kubernetes (`kubectl`)

Asegúrate de que la CLI de Kubernetes está apuntando al contexto y namespace adecuados.

1. **Verificar el contexto actual:**
   ```bash
   kubectl config current-context
   ```

2. **Verificar el namespace configurado:**
   ```bash
   kubectl config view --minify --output 'jsonpath={..namespace}'
   ```
   > *Deberías ver un namespace similar a: `canalnegocios-qa`*

3. **Verificar lectura de servicios:**
   ```bash
   kubectl get services
   ```

*Si este comando responde con éxito, Python podrá comunicarse correctamente con el clúster a través de `kubectl`.*

---

## 4. Pruebas Directas del Client de Python (`KubernetesClient`)

Probarás las capacidades del cliente dentro del entorno interactivo de Python antes de lanzar la suite de diagnóstico completa.

Accede a la REPL de Python desde la raíz del proyecto:
```bash
python
```

### A. Prueba de Servicio Individual
```python
from engineer.kubernetes.client import KubernetesClient

client = KubernetesClient()
service = client.get("service", "ch-ms-enrollment-v2")

print(service["metadata"]["name"])
# Resultado esperado: ch-ms-enrollment-v2
```

### B. Prueba de Deployments
```python
from engineer.kubernetes.client import KubernetesClient

client = KubernetesClient()
deployments = client.get_all("deployments")

for deployment in deployments:
    print(deployment["metadata"]["name"])

# Resultado esperado: listado de deployments del namespace actual, por ejemplo:
# ch-ms-enrollment-v2-blue
# ch-ms-enrollment-v2-green
```

### C. Prueba de Recursos Istio (DestinationRules y VirtualServices)
```python
from engineer.kubernetes.client import KubernetesClient

client = KubernetesClient()

# Probar Destination Rules
rules = client.get_all("destinationrules")
for rule in rules:
    print(rule["metadata"]["name"])

# Probar Virtual Services
virtual_services = client.get_all("virtualservices")
for vs in virtual_services:
    print(vs["metadata"]["name"])
```

*Esto confirma que el cliente de Python puede consultar adecuadamente los recursos CRD de Istio requeridos.*

---

## 5. Ejecución del Diagnóstico

Si todas las validaciones anteriores fueron exitosas, procede a ejecutar el diagnóstico sobre el servicio objetivo:

```bash
engineer diagnose ch-ms-enrollment-v2
```

---

## 6. Interpretación de Resultados

### ✅ Caso A — Funciona Correctamente
El sistema arrojará un resumen estructurado del estado Blue/Green, Deployments y HPA:

```text
ENGINEER OS - BLUE/GREEN DIAGNOSTIC

Service         ch-ms-enrollment-v2
Active          blue
Strategy        green
Blue traffic    100%
Green traffic   0%

DEPLOYMENTS

Version   Deployment                 Ready   Desired   Status
blue      ...                        2       2         HEALTHY
green     ...                        2       2         HEALTHY

HPA

Name    ...
Target  ...
Min     2
Max     5
Current 2
```

---

### ❌ Caso B — Presenta Fallos
Si la ejecución arroja un error:

1. **No modifiques código ni configuraciones aún.**
2. Copia el mensaje o traza completa de error emitida por la consola.
3. Presta particular atención si el mensaje indica:
   - `Error: ...`
   - `No resources found`
   - `the server doesn't have a resource type...`
4. Proporciona dicho log para ajustar la especificación del cliente a la versión real de tu Kubernetes e Istio.