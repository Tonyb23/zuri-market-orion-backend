# Zuri Market — Backend

## 1. Project Overview

This is a lightweight REST API powering the Zuri Market ecommerce platform. It exposes the product catalog data, store metadata, and a cart validation endpoint consumed by the **[Zuri Market - Frontend](https://github.com/Tonyb23/zuri-market-orion-frontend)**. Built with Node.js and Express, with an in-memory product dataset.  
The API is containerised with Docker and deployed automatically to a k3s Kubernetes cluster on AWS EC2 via a GitHub Actions CI/CD pipeline.

## Related Repositories

**[Zuri Market - Frontend](https://github.com/Tonyb23/zuri-market-orion-frontend)**  
**[Zuri Market - Infrastructure](https://github.com/Tonyb23/zuri-market-orion-infrastructure)**

## Architecture Diagram
![Architecture Diagram](https://raw.githubusercontent.com/Tonyb23/zuri-market-orion-backend/a7d7942981e867e80799ad819e605cd9031f276a/zurimarket-architecture.svg)

## 2. Tech Stack

- **Node.js** 18+ - Javascript runtime
- **Express** ^4.19.2 — Web Server framework
- **cors** ^2.8.5 — Cross-origin request support, so the frontend (running on a different host/port) can call the API
- **dotenv** ^16.4.5 — Loads environment variables from a `.env` file in development
- **nodemon** ^3.1.4 (dev dependency) — Auto-restarts the server on file changes during local development

## 3. Project Structure

```
.
├── data/
│   └── products.js        # In-memory product catalog (id, name, category, price, stock, etc.)
├── k8s/
│   └── deployment.yaml     # Kubernetes Deployment + NodePort Service
├── .github/workflows/
│   └── deploy.yml          # CI/CD: test, audit, scan, build, push, deploy
├── server.js                # Express app: middleware, routes, server startup
├── Dockerfile                # Container build definition
├── package.json
└── .env.example               # Template listing required environment variables
```

### Component Reference

- **`server.js`** — The entire application. Sets up Express, CORS, JSON body parsing, an API-key middleware for protected routes, and all route handlers.
- **`data/products.js`** — A hardcoded array of product objects exported as the "database" for this demo API. No external database is used.
- **`Dockerfile`** — Builds a production image on `node:18-alpine`. (see [Docker](#7-docker) below)
- **`k8s/deployment.yaml`** — Describes how the app runs in Kubernetes, including how `API_SECRET_KEY` and `STORE_NAME` are injected from a cluster Secret.
- **`.github/workflows/deploy.yml`** — The pipeline that builds, scans, pushes, and deploys the app on every push to `main`.

## 4. Environment Variables

All variables are listed in `.env.example`. Copy it to `.env` and fill in real values locally — **never commit actual secrets to the README or the repo.**

| Variable | Description | Required? |
|---|---|---|
| `PORT` | Port the Express server listens on | Optional — defaults to `5000` |
| `API_SECRET_KEY` | Shared secret checked against the `x-api-key` header on protected routes (currently `POST /api/cart/validate`) | **Required** — requests to protected routes fail with `401` if unset or mismatched |
| `STORE_NAME` | Display name returned by `GET /api/store` | Optional — defaults to `"My Store"` |

## 5. Running Locally


```bash
# 1. Clone the repo or create your own bare clone for more flexibility
git clone https://github.com/Tonyb23/zuri-market-orion-backend.git

cd zuri-market-orion-backend

# 2. Install dependencies
npm install

# 3. Set up environment variables
cp .env.example .env
# then edit .env with your own values


# 4. Start the server
npm run dev     # with auto-restart (nodemon), recommended for local dev
# or
npm start       # plain node, closer to how it runs in production
```

The API is available at `http://localhost:5000` (or whatever `PORT` you set).

## 6. API Endpoints

| Method | Path | Auth required? | Description |
|---|---|---|---|
| `GET` | `/api/store` | No | Returns store metadata |
| `GET` | `/api/products` | No | Returns all products. Supports an optional `?category=` query param to filter |
| `GET` | `/api/products/:id` | No | Returns a single product by numeric ID, or `404` if not found |
| `POST` | `/api/cart/validate` | **Yes** — `x-api-key` header must match `API_SECRET_KEY` | Validates a cart payload against current stock/pricing and returns a computed total |

### `GET /api/store`

Example response:
```json
{
  "name": "Zuri Market",
  "totalProducts": 8
}
```

### `GET /api/products`

Example response (truncated):
```json
[
  {
    "id": 1,
    "name": "Merino crew neck",
    "category": "apparel",
    "price": 89,
    "stock": 12,
    "badge": null,
    "description": "Lightweight 100% merino wool. Naturally temperature-regulating and itch-free.",
    "image": "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=500&q=80"
  }
]
```

### `GET /api/products/:id`

Example response:
```json
{
  "id": 2,
  "name": "Ceramic pour-over",
  "category": "home",
  "price": 42,
  "stock": 8,
  "badge": "bestseller",
  "description": "Hand-thrown ceramic dripper. Brews a clean, nuanced cup every time.",
  "image": "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=500&q=80"
}
```

If no product matches the ID:
```json
{ "error": "Product not found" }
```

### `POST /api/cart/validate`

Requires header: `x-api-key: <API_SECRET_KEY>`

Request body:
```json
{
  "items": [
    { "id": 1, "quantity": 2 },
    { "id": 99, "quantity": 1 }
  ]
}
```

Example response:
```json
{
  "items": [
    { "id": 1, "valid": true, "name": "Merino crew neck", "price": 89, "quantity": 2, "subtotal": 178 },
    { "id": 99, "valid": false, "reason": "Product not found" }
  ],
  "total": 178
}
```

Without a valid `x-api-key` header:
```json
{ "error": "Unauthorized: invalid or missing API key" }
```

## 7. Docker

Ensure Docker Desktop is running and Build the image locally:

```bash
docker build -t zuri-market-backend:local .
```

Run the container:

```bash
docker run -d -p 5000:5000 --name zurimarket-backend --env-file .env zuriapp-backend:local
```

Push images to Docker Hub:

```bash
# log in to Docker Hub with your credentials
docker login

# Tag with your Docker Hub username
docker tag zuriapp-backend:local YOUR_DOCKERHUB_USERNAME/zuriapp-backend:latest

# Push
docker push YOUR_DOCKERHUB_USERNAME/zuriapp-backend:latest
```

Example Docker Hub image: **`tonyb23/zuriapp-backend`**

**Tag convention used by the CI/CD pipeline:** every push to `main` builds and pushes two tags — `tonyb23/zuriapp-backend:<git-sha>` (immutable, traceable to the exact commit) and `tonyb23/zuriapp-backend:latest`. The Kubernetes deployment is then updated to reference the specific `<git-sha>` tag for that release, not `latest`.

## 8. Deployment

The underlying k3s cluster and supporting AWS infrastructure (EC2 instance, IAM roles, Secrets Manager entries, etc.) are provisioned with **Terraform**. 

The provisioning code lives in [Zuri Market - Infrastructure](https://github.com/Tonyb23/zuri-market-orion-infrastructure) — refer to it for setup and teardown instructions; this README only covers the application deployment itself.

Deployment is fully automated via **GitHub Actions** (`.github/workflows/deploy.yml`). On every push to `main`, the pipeline installs dependencies, runs tests and `npm audit`, builds the Docker image, scans it with Trivy, and if the scan passes it pushes the image to Docker Hub and rolls it out to the **k3s** cluster running on the EC2 Instance.

Edit this file as well as your **Kubernetes Manifests** (`.k8s/deployment.yaml`) to match your own configurations 

### Push to your remote GitHub Repo

You now have everything in place. Commit the entire application code to your GitHub repo and push everything to main. This is what triggers the first full deployment.

```bash
git add .
git commit -m "Your_Commit_Message"
git push origin main
```
From this point on, every push to main triggers the full pipeline automatically.

Once the pipeline runs successfully, verify the deployment from your EC2 Instance:

```bash
kubectl get pods       
# both backend and frontend pods should show Running
kubectl get services   
# confirm zurimarket-frontend-svc shows nodePort 30080
# and zurimarket-backend-svc shows nodePort 30500
```

## 9. Secrets

Secrets are sourced differently depending on where the app is running:

- **Locally** — secrets come from your own `.env` file (created from `.env.example`), and are never committed to the repo.
- **In the CI/CD pipeline** — secrets used to build, scan, and push the image, and then deploy to the k3s cluster on AWS (e.g. `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `EC2_PUBLIC_IP`, `SSH_PRIVATE_KEY`, `KUBECONFIG`) are stored as **GitHub Actions Secrets** and injected into the workflow at runtime — they're never hardcoded in the YAML.
- **In production** — the actual application secrets (`API_SECRET_KEY`, `STORE_NAME`) are stored in **AWS Secrets Manager**. The deploy job fetches them at deploy time and syncs them into a Kubernetes `Secret` object (`zurimarket-secrets`), which the pod then consumes as environment variables via `secretKeyRef`. The values never appear in the manifest files or the Git history.


## 10. Final Project Expectation

You should be able to Access the live App at `http://YOUR_EC2_IP:30080` as shown below with the products from the backend API visible

![Live App](https://github.com/Tonyb23/zuri-market-orion-frontend/blob/main/zuri_market_final_deployment_image.png?raw=true)

The backend Service is exposed via Kubernetes NodePort on port 30500, making it reachable externally at at `http://YOUR_EC2_IP:30050`


## 11 Future Improvement Opportunities

### Backend 

| Improvement | Why it matters |
|---|---|
| Replace hardcoded product data with a database (DynamoDB or RDS) | Product data hardcoded in the backend means every product change requires a code change and a full redeployment. A database decouples data from code — products can be added, updated, or removed without touching the application. |
| Write a proper test suite (Jest or Mocha) | The current test script is a placeholder that exits with an error. No tests means the CI pipeline has no actual quality gate — a broken endpoint could be deployed without anyone knowing. Unit and integration tests covering the API routes are a minimum for production confidence. |
| Migrate to ECS/EKS or Fargate for container orchestration | Running k3s on a single EC2 instance is a single point of failure with no managed control plane. AWS ECS (Fargate) or EKS provides managed scaling, health replacement, and load distribution without the operational overhead of self-managing a Kubernetes cluster. |

### Overall Project 

| Improvement | Why it matters |
|---|---|
| Multi-environment pipeline with dev, staging, and production | All changes currently go directly to production on every push to main. A dev → staging → prod promotion model with environment-scoped GitHub Secrets means changes are validated in a lower environment before reaching real users. |
| Add HTTPS and TLS across all services end to end | All traffic currently travels over plain HTTP between the user and the frontend, and between the frontend and the backend API. HTTPS is non-negotiable for production: it protects data in transit, is required for modern browser APIs, and is expected by users. |
| Deploy a logging, monitoring, and alerting solution (ELK stack, CloudWatch or Prometheus + Grafana) | There is currently no visibility into pod health, API response times, error rates, or resource usage after deployment. Without monitoring you are blind to problems until users report them. CloudWatch or a Prometheus/Grafana stack surfaces issues proactively. |

This list is not exhaustive but provides some idea on how to move the project toward production readiness and engineering best practices

---

*Author [Anthony Ubani](https://www.linkedin.com/in/anthonyifeanyiubani/)*