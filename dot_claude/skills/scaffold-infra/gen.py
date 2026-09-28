#!/usr/bin/env python3
"""gen.py : genere Dockerfiles, manifestes, kustomize et workflows depuis une spec YAML. Zero LLM.
Usage (racine du depot) : gen.py spec.yaml [--force]"""
import sys, pathlib, yaml
from jinja2 import Environment, StrictUndefined
env = Environment(undefined=StrictUndefined, trim_blocks=True, lstrip_blocks=True, keep_trailing_newline=True)
args = [a for a in sys.argv[1:] if not a.startswith("--")]
FORCE = "--force" in sys.argv
if len(args) != 1: sys.exit("Usage : gen.py spec.yaml [--force]")
spec = yaml.safe_load(open(args[0]))
R = spec["ressources"]
UID = 10001
DOCKER = {
 "go": """FROM golang:1.23.4-alpine3.21 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /app .

FROM alpine:3.21.0
COPY --from=build /app /app
USER {{uid}}
{% if port %}EXPOSE {{port}}
{% endif %}ENTRYPOINT ["/app"]
""",
 "python": """FROM python:3.12.8-slim-bookworm
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
USER {{uid}}
{% if port %}EXPOSE {{port}}
{% endif %}CMD ["python", "main.py"]
""",
 "node": """FROM node:22.12.0-alpine3.21
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
USER {{uid}}
{% if port %}EXPOSE {{port}}
{% else %}# PORT MANQUANT : absent du brief, a definir
{% endif %}CMD ["node", "index.js"]
""",
 "nginx": """FROM nginxinc/nginx-unprivileged:1.27.3-alpine3.20
COPY dist/ /usr/share/nginx/html/
USER {{uid}}
EXPOSE 8080
""",
}
DEPLOY = """---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{name}}
  labels: {app: {{name}}}
spec:
  replicas: {{replicas}}
  selector:
    matchLabels: {app: {{name}}}
  template:
    metadata:
      labels: {app: {{name}}}
    spec:
      securityContext: {runAsNonRoot: true, runAsUser: {{uid}}}
      containers:
        - name: {{name}}
          image: relais/{{name}}:0.1.0
{% if cport %}
          ports:
            - containerPort: {{cport}}
{% else %}
          # PORT MANQUANT : absent du brief, a definir
{% endif %}
          resources:
            requests: {cpu: {{R.cpu_req}}, memory: {{R.mem_req}}}
            limits: {cpu: {{R.cpu_lim}}, memory: {{R.mem_lim}}}
"""
SVC = """---
apiVersion: v1
kind: Service
metadata:
  name: {{name}}
spec:
  selector: {app: {{name}}}
{% if port %}
  ports:
    - port: {{port}}
      targetPort: {{cport}}
{% else %}
  # PORT MANQUANT : absent du brief, a definir
  clusterIP: None
{% endif %}
"""
WF = """---
name: {{name}}
"on":
  pull_request:
    paths: ["services/{{name}}/**"]
jobs:
  lint-build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
      - uses: hadolint/hadolint-action@v3.1.0
        with: {dockerfile: services/{{name}}/Dockerfile}
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v6
        with:
          context: services/{{name}}
          push: false
"""
out = pathlib.Path(".")
for n, s in spec["services"].items():
    if s.get("langage") not in DOCKER:
        sys.exit(f"ECHEC : langage '{s.get('langage')}' non gere pour {n} (geres : {', '.join(DOCKER)})")
ecrits, existants = [], []
def w(p, s):
    p = out / p
    if p.exists() and not FORCE: existants.append(str(p)); return
    p.parent.mkdir(parents=True, exist_ok=True); p.write_text(s); ecrits.append(str(p))
prod = {}
for name, s in spec["services"].items():
    port = s.get("port")
    cport = 8080 if s["langage"] == "nginx" else port     # nginx non root ne peut pas ecouter sur 80 : 80 -> 8080
    ctx = dict(name=name, port=port, cport=cport, replicas=s["replicas"], uid=UID, R=R)
    w(f"services/{name}/Dockerfile", env.from_string(DOCKER[s["langage"]]).render(**ctx))
    w(f"services/{name}/k8s/deployment.yaml", env.from_string(DEPLOY).render(**ctx))
    w(f"services/{name}/k8s/service.yaml", env.from_string(SVC).render(**ctx))
    w(f"services/{name}/k8s/kustomization.yaml", "---\nresources:\n  - deployment.yaml\n  - service.yaml\n")
    w(f".github/workflows/{name}.yml", env.from_string(WF).render(**ctx))
    if s.get("replicas_prod"): prod[name] = s["replicas_prod"]
w("k8s/base/kustomization.yaml", "---\nresources:\n" + "".join(f"  - ../../services/{n}/k8s\n" for n in spec["services"]))
w("k8s/kustomization.yaml", "---\nresources:\n  - base\n")
w("k8s/overlays/dev/kustomization.yaml", "---\nresources:\n  - ../../base\n")
patches = "".join(f"  - target: {{kind: Deployment, name: {n}}}\n    patch: |-\n      - op: replace\n        path: /spec/replicas\n        value: {r}\n" for n, r in prod.items())
w("k8s/overlays/prod/kustomization.yaml", "---\nresources:\n  - ../../base\n" + ("patches:\n" + patches if patches else ""))
print(f"OK : {len(ecrits)} fichiers ecrits")
if existants:
    print(f"NON ECRASES ({len(existants)}, relancer avec --force si voulu) : " + " ".join(existants)); sys.exit(3)
