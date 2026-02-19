# ============================================================
# AT2 - Deploiement d'une application en continu (Version Finale sans bugs)
# Deploiement sur CLUSTER EKS (suite logique d'AT1)
# AWS ECR pour les images Docker
# CircleCI pour CI/CD
# ============================================================
param(
    [string]$Action = "all",
    [string]$AwsRegion = "eu-west-3",
    [string]$AwsAccountId = "",
    [string]$EksClusterName = "exam-eks-cluster"
)

$ROOT    = $PSScriptRoot
$SB_DIR  = "$ROOT\springboot-app"
$ANG_DIR = "$ROOT\angular-app"
$K8S_DIR = "$ROOT\k8s"

# ─────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────
function Info  { param($m) Write-Host "[INFO]  $m" -ForegroundColor Cyan    }
function Ok    { param($m) Write-Host "[OK]    $m" -ForegroundColor Green   }
function Err   { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red     }
function Step  { param($m) Write-Host "`n===== $m =====" -ForegroundColor Yellow }
function Warn  { param($m) Write-Host "[WARN]  $m" -ForegroundColor Magenta }

# ─────────────────────────────────────────────────────────────
# ECRITURE UTF-8 SANS BOM
# ─────────────────────────────────────────────────────────────
function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# ─────────────────────────────────────────────────────────────
# PREREQUIS
# ─────────────────────────────────────────────────────────────
function Check-Prerequisites {
    Step "Verification des prerequis"
    $tools = @("aws","docker","kubectl","mvn","node","npm")
    $missing = @()
    foreach ($t in $tools) {
        if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { $missing += $t }
        else { Ok "$t trouve" }
    }
    if ($missing.Count -gt 0) {
        Err "Outils manquants : $($missing -join ', ')"
        exit 1
    }

    # Verification AWS
    try {
        $account = aws sts get-caller-identity --query Account --output text 2>$null
        if ($account) {
            Ok "AWS connecte (Account: $account)"
            if (-not $AwsAccountId) { $script:AwsAccountId = $account }
        }
    } catch {
        Err "AWS CLI non configure. Lancez: aws configure"
        exit 1
    }
}

# ─────────────────────────────────────────────────────────────
# AWS ECR - AUTHENTIFICATION + REPO
# ─────────────────────────────────────────────────────────────
function Setup-ECR {
    Step "Configuration AWS ECR"

    if (-not $AwsAccountId) {
        Err "AWS Account ID manquant. Impossible de continuer."
        exit 1
    }

    $ecrUri = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
    $script:ECR_REGISTRY = $ecrUri
    Info "Registry ECR : $ecrUri"

    # Authentification Docker vers ECR - FIX
    $token = aws ecr get-login-password --region $AwsRegion
    $token | docker login --username AWS --password-stdin $ecrUri
    if ($LASTEXITCODE -ne 0) { Err "ECR login failed" ; exit 1 }
    Ok "Docker authentifie sur ECR"

    # Creation des repos ECR
    $repos = @("springboot-hello", "angular-hello")
    foreach ($repo in $repos) {
        try {
            aws ecr describe-repositories --repository-names $repo --region $AwsRegion `
                --query 'repositories[0].repositoryUri' --output text | Out-Null
            Info "Repo ECR '$repo' deja present"
        } catch {
            Info "Creation repo ECR '$repo'..."
            aws ecr create-repository --repository-name $repo --region $AwsRegion | Out-Null
            Ok "Repo '$repo' cree"
        }
    }
}

# ─────────────────────────────────────────────────────────────
# 1 & 2  SPRING BOOT HELLO WORLD + DOCKERFILE
# ─────────────────────────────────────────────────────────────
function Setup-SpringBoot {
    Step "Creation du projet Spring Boot Hello World"

    New-Item -ItemType Directory -Force -Path "$SB_DIR\src\main\java\com\helloworld" | Out-Null
    New-Item -ItemType Directory -Force -Path "$SB_DIR\src\main\resources"           | Out-Null
    New-Item -ItemType Directory -Force -Path "$SB_DIR\src\test\java\com\helloworld" | Out-Null

    # ---------- pom.xml ----------
    Write-Utf8 "$SB_DIR\pom.xml" @"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.2.0</version>
  </parent>
  <groupId>com.helloworld</groupId>
  <artifactId>hello-world</artifactId>
  <version>1.0.0</version>
  <properties><java.version>17</java.version></properties>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
"@

    # ---------- Application.java ----------
    Write-Utf8 "$SB_DIR\src\main\java\com\helloworld\Application.java" @"
package com.helloworld;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
"@

    # ---------- HelloController.java ----------
    Write-Utf8 "$SB_DIR\src\main\java\com\helloworld\HelloController.java" @"
package com.helloworld;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/")
    public String hello() {
        return "Hello World depuis Spring Boot ! (port 8080) - Deploye sur EKS";
    }

    @GetMapping("/health")
    public String health() {
        return "UP";
    }

    @GetMapping("/info")
    public String info() {
        return "Spring Boot 3.2.0 - AT2 Exam";
    }
}
"@

    # ---------- HelloControllerTest.java ----------
    Write-Utf8 "$SB_DIR\src\test\java\com\helloworld\HelloControllerTest.java" @"
package com.helloworld;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class HelloControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void helloEndpointReturnsOk() throws Exception {
        mockMvc.perform(get("/"))
               .andExpect(status().isOk())
               .andExpect(content().string(org.hamcrest.Matchers.containsString("Hello")));
    }

    @Test
    void healthEndpointReturnsUp() throws Exception {
        mockMvc.perform(get("/health"))
               .andExpect(status().isOk())
               .andExpect(content().string("UP"));
    }

    @Test
    void infoEndpointReturnsInfo() throws Exception {
        mockMvc.perform(get("/info"))
               .andExpect(status().isOk())
               .andExpect(content().string(org.hamcrest.Matchers.containsString("AT2")));
    }
}
"@

    # ---------- application.properties ----------
    Write-Utf8 "$SB_DIR\src\main\resources\application.properties" @"
server.port=8080
spring.application.name=hello-world
server.servlet.context-path=/api
"@

    # ---------- Dockerfile multi-stage ----------
    Write-Utf8 "$SB_DIR\Dockerfile" @"
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
RUN apk add --no-cache maven
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn clean package -DskipTests -q

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/health || exit 1
CMD ["java", "-jar", "app.jar"]
"@

    Write-Utf8 "$SB_DIR\.dockerignore" "target/`n*.md`n.git`n.gitignore"

    Ok "Projet Spring Boot cree dans $SB_DIR"
}

# ─────────────────────────────────────────────────────────────
# 4  ANGULAR HELLO WORLD (VERSION CORRIGEE)
# ─────────────────────────────────────────────────────────────
function Setup-Angular {
    Step "Creation du projet Angular Hello World"

    # Creer les dossiers
    New-Item -ItemType Directory -Force -Path "$ANG_DIR\src\app" | Out-Null
    New-Item -ItemType Directory -Force -Path "$ANG_DIR\src\environments" | Out-Null
    New-Item -ItemType Directory -Force -Path "$ANG_DIR\src\assets" | Out-Null

    # ---------- package.json ----------
    Write-Utf8 "$ANG_DIR\package.json" @"
{
  "name": "angular-hello",
  "version": "1.0.0",
  "scripts": {
    "ng": "ng",
    "start": "ng serve",
    "build": "ng build --configuration=production",
    "test": "ng test --watch=false --browsers=ChromeHeadless"
  },
  "private": true,
  "dependencies": {
    "@angular/animations": "^17.0.0",
    "@angular/common": "^17.0.0",
    "@angular/compiler": "^17.0.0",
    "@angular/core": "^17.0.0",
    "@angular/forms": "^17.0.0",
    "@angular/platform-browser": "^17.0.0",
    "@angular/platform-browser-dynamic": "^17.0.0",
    "@angular/router": "^17.0.0",
    "rxjs": "~7.8.0",
    "tslib": "^2.3.0",
    "zone.js": "~0.14.2"
  },
  "devDependencies": {
    "@angular-devkit/build-angular": "^17.0.0",
    "@angular/cli": "^17.0.0",
    "@angular/compiler-cli": "^17.0.0",
    "@types/jasmine": "~5.1.0",
    "jasmine-core": "~5.1.0",
    "karma": "~6.4.0",
    "karma-chrome-launcher": "~3.2.0",
    "karma-coverage": "~2.2.0",
    "karma-jasmine": "~5.1.0",
    "karma-jasmine-html-reporter": "~2.1.0",
    "typescript": "~5.2.2"
  }
}
"@

    # ---------- tsconfig.json ----------
    Write-Utf8 "$ANG_DIR\tsconfig.json" @"
{
  "compileOnSave": false,
  "compilerOptions": {
    "baseUrl": "./",
    "outDir": "./dist/out-tsc",
    "forceConsistentCasingInFileNames": true,
    "strict": true,
    "noImplicitOverride": true,
    "noPropertyAccessFromIndexSignature": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "sourceMap": true,
    "declaration": false,
    "downlevelIteration": true,
    "experimentalDecorators": true,
    "moduleResolution": "node",
    "importHelpers": true,
    "target": "ES2022",
    "module": "ES2022",
    "useDefineForClassFields": false,
    "lib": [
      "ES2022",
      "dom"
    ]
  },
  "angularCompilerOptions": {
    "enableI18nLegacyMessageIdFormat": false,
    "strictInjectionParameters": true,
    "strictInputAccessModifiers": true,
    "strictTemplates": true
  }
}
"@

    # ---------- angular.json ----------
    Write-Utf8 "$ANG_DIR\angular.json" @'
{
  "$schema": "./node_modules/@angular/cli/lib/config/schema.json",
  "version": 1,
  "newProjectRoot": "projects",
  "projects": {
    "angular-hello": {
      "projectType": "application",
      "root": "",
      "sourceRoot": "src",
      "prefix": "app",
      "architect": {
        "build": {
          "builder": "@angular-devkit/build-angular:browser",
          "options": {
            "outputPath": "dist/angular-app",
            "index": "src/index.html",
            "main": "src/main.ts",
            "polyfills": ["zone.js"],
            "tsConfig": "tsconfig.app.json",
            "assets": ["src/favicon.ico", "src/assets"],
            "styles": ["src/styles.css"],
            "scripts": []
          },
          "configurations": {
            "production": {"outputHashing": "all"}
          },
          "defaultConfiguration": "production"
        },
        "serve": {
          "builder": "@angular-devkit/build-angular:dev-server",
          "options": {"browserTarget": "angular-hello:build"}
        },
        "test": {
          "builder": "@angular-devkit/build-angular:karma",
          "options": {
            "polyfills": ["zone.js", "zone.js/testing"],
            "tsConfig": "tsconfig.spec.json",
            "assets": ["src/favicon.ico", "src/assets"],
            "styles": ["src/styles.css"],
            "scripts": []
          }
        }
      }
    }
  }
}
'@ | Out-File -FilePath angular.json -Encoding UTF8

    # ---------- tsconfig.app.json ----------
    Write-Utf8 "$ANG_DIR\tsconfig.app.json" @"
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./out-tsc/app",
    "types": []
  },
  "files": [
    "src/main.ts"
  ],
  "include": [
    "src/**/*.d.ts"
  ]
}
"@

    # ---------- tsconfig.spec.json ----------
    Write-Utf8 "$ANG_DIR\tsconfig.spec.json" @"
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./out-tsc/spec",
    "types": [
      "jasmine"
    ]
  },
  "include": [
    "src/**/*.spec.ts",
    "src/**/*.d.ts"
  ]
}
"@

    # ---------- karma.conf.js ----------
    Write-Utf8 "$ANG_DIR\karma.conf.js" @"
module.exports = function (config) {
  config.set({
    basePath: '',
    frameworks: ['jasmine', '@angular-devkit/build-angular'],
    plugins: [
      require('karma-jasmine'),
      require('karma-chrome-launcher'),
      require('karma-jasmine-html-reporter'),
      require('karma-coverage'),
      require('@angular-devkit/build-angular/plugins/karma')
    ],
    client: {
      clearContext: false
    },
    jasmineHtmlReporter: {
      suppressAll: true
    },
    coverageReporter: {
      dir: require('path').join(__dirname, './coverage/angular-hello'),
      subdir: '.',
      reporters: [
        { type: 'html' },
        { type: 'text-summary' }
      ]
    },
    reporters: ['progress', 'kjhtml'],
    port: 9876,
    colors: true,
    logLevel: config.LOG_INFO,
    autoWatch: true,
    browsers: ['Chrome'],
    singleRun: false,
    restartOnFileChange: true
  });
};
"@

    # ---------- src/main.ts ----------
    Write-Utf8 "$ANG_DIR\src\main.ts" @"
import { platformBrowserDynamic } from '@angular/platform-browser-dynamic';
import { AppModule } from './app/app.module';

platformBrowserDynamic().bootstrapModule(AppModule)
  .catch(err => console.error(err));
"@

    # ---------- src/index.html ----------
    Write-Utf8 "$ANG_DIR\src\index.html" @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Angular Hello</title>
  <base href="/">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="icon" type="image/x-icon" href="favicon.ico">
</head>
<body>
  <app-root></app-root>
</body>
</html>
"@

    # ---------- src/styles.css ----------
    Write-Utf8 "$ANG_DIR\src\styles.css" @"
body { font-family: Arial, sans-serif; background: #f0f4f8; margin: 0; }
"@

    # ---------- src/app/app.module.ts ----------
    Write-Utf8 "$ANG_DIR\src\app\app.module.ts" @"
import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { AppComponent } from './app.component';

@NgModule({
  declarations: [AppComponent],
  imports: [BrowserModule],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
"@

    # ---------- src/app/app.component.ts ----------
    Write-Utf8 "$ANG_DIR\src\app\app.component.ts" @"
import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent {
  title = 'Hello World Angular';
  version = '1.0.0';
  environment = 'EKS Production';
  buildDate = new Date().toLocaleDateString('fr-FR');
  status = 'RUNNING';
}
"@

    # ---------- src/app/app.component.html ----------
    Write-Utf8 "$ANG_DIR\src\app\app.component.html" @"
<div class="container">
  <header>
    <h1>{{ title }}</h1>
    <p class="subtitle">Application Angular déployée sur EKS</p>
  </header>

  <div class="info-card">
    <h2>Informations</h2>
    <table>
      <tr>
        <td><strong>Version</strong></td>
        <td>{{ version }}</td>
      </tr>
      <tr>
        <td><strong>Environnement</strong></td>
        <td>{{ environment }}</td>
      </tr>
      <tr>
        <td><strong>Build Date</strong></td>
        <td>{{ buildDate }}</td>
      </tr>
      <tr>
        <td><strong>Statut</strong></td>
        <td class="status-ok">{{ status }}</td>
      </tr>
    </table>
  </div>

  <div class="success-badge">
    ✓ Application Angular opérationnelle (AT2)
  </div>

  <footer>
    <p>Exam AT2 - Déploiement d'une application en continu</p>
  </footer>
</div>
"@

    # ---------- src/app/app.component.css ----------
    Write-Utf8 "$ANG_DIR\src\app\app.component.css" @"
:host {
  --primary: #c3002f;
  --success: #2e7d32;
}

.container {
  max-width: 700px;
  margin: 0 auto;
  padding: 40px 20px;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
}

header {
  text-align: center;
  margin-bottom: 40px;
  padding-bottom: 20px;
}

h1 {
  color: var(--primary);
  margin: 0;
  font-size: 2.5em;
}

.subtitle {
  color: #666;
  font-size: 0.95em;
  margin: 10px 0 0 0;
}

.info-card {
  background: white;
  border-radius: 10px;
  padding: 30px;
  margin-bottom: 30px;
}

.info-card h2 {
  color: var(--primary);
  margin-top: 0;
}

table {
  width: 100%;
  border-collapse: collapse;
}

table tr {
  border-bottom: 1px solid #eee;
}

table td {
  padding: 12px;
  text-align: left;
}

table td:first-child {
  font-weight: 600;
  color: #666;
  width: 40%;
}

.status-ok {
  color: var(--success);
  font-weight: bold;
}

.success-badge {
  background: linear-gradient(135deg, var(--success), #1b5e20);
  color: white;
  padding: 20px;
  border-radius: 8px;
  text-align: center;
  font-weight: bold;
  margin-bottom: 30px;
}

footer {
  text-align: center;
  color: #999;
  font-size: 0.9em;
  margin-top: 40px;
  padding-top: 20px;
  border-top: 1px solid #ddd;
}
"@

    # ---------- src/app/app.component.spec.ts ----------
    Write-Utf8 "$ANG_DIR\src\app\app.component.spec.ts" @"
import { TestBed } from '@angular/core/testing';
import { AppComponent } from './app.component';

describe('AppComponent', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [AppComponent],
    }).compileComponents();
  });

  it('should create the app', () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance).toBeTruthy();
  });

  it('should have title Hello World Angular', () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance.title).toBe('Hello World Angular');
  });

  it('should render title in h1', () => {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.querySelector('h1')?.textContent).toContain('Hello World Angular');
  });

  it('should display version 1.0.0', () => {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();
    const compiled = fixture.nativeElement as HTMLElement;
    expect(compiled.textContent).toContain('1.0.0');
  });

  it('should display EKS environment', () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance.environment).toContain('EKS');
  });

  it('should have RUNNING status', () => {
    const fixture = TestBed.createComponent(AppComponent);
    expect(fixture.componentInstance.status).toBe('RUNNING');
  });
});
"@

    # ---------- Dockerfile ----------
    Write-Utf8 "$ANG_DIR\Dockerfile" @"
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --quiet
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist/angular-app /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 4200
CMD ["nginx", "-g", "daemon off;"]
"@

    # ---------- nginx.conf ----------
    Write-Utf8 "$ANG_DIR\nginx.conf" @"
server {
  listen 4200;
  location / {
    root /usr/share/nginx/html;
    index index.html index.htm;
    try_files \$uri \$uri/ /index.html;
  }
}
"@

    Write-Utf8 "$ANG_DIR\.dockerignore" "node_modules`ndist`n.git`n.gitignore`n*.log"

    Ok "Projet Angular cree dans $ANG_DIR"
}

# ─────────────────────────────────────────────────────────────
# 3  KUBERNETES MANIFESTS
# ─────────────────────────────────────────────────────────────
function Setup-K8sManifests {
    Step "Creation des manifests Kubernetes pour EKS"
    New-Item -ItemType Directory -Force -Path $K8S_DIR | Out-Null

    # ---------- Namespace ----------
    Write-Utf8 "$K8S_DIR\namespace.yaml" @"
apiVersion: v1
kind: Namespace
metadata:
  name: app-at2
  labels:
    name: app-at2
"@

    # ---------- Spring Boot Deployment ----------
    Write-Utf8 "$K8S_DIR\springboot-deployment.yaml" @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springboot-hello
  namespace: app-at2
  labels:
    app: springboot-hello
    tier: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: springboot-hello
  template:
    metadata:
      labels:
        app: springboot-hello
        tier: backend
    spec:
      containers:
        - name: springboot-hello
          image: PLACEHOLDER_ECR_URI/springboot-hello:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: ENVIRONMENT
              value: "EKS-Production"
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          readinessProbe:
            httpGet:
              path: /api/health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /api/health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
"@

    # ---------- Spring Boot Service ----------
    Write-Utf8 "$K8S_DIR\springboot-service.yaml" @"
apiVersion: v1
kind: Service
metadata:
  name: springboot-hello-svc
  namespace: app-at2
  labels:
    app: springboot-hello
spec:
  selector:
    app: springboot-hello
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
      name: http
"@

    # ---------- Angular Deployment ----------
    Write-Utf8 "$K8S_DIR\angular-deployment.yaml" @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: angular-hello
  namespace: app-at2
  labels:
    app: angular-hello
    tier: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: angular-hello
  template:
    metadata:
      labels:
        app: angular-hello
        tier: frontend
    spec:
      containers:
        - name: angular-hello
          image: PLACEHOLDER_ECR_URI/angular-hello:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 4200
              name: http
          resources:
            requests:
              memory: "128Mi"
              cpu: "50m"
            limits:
              memory: "256Mi"
              cpu: "250m"
          livenessProbe:
            httpGet:
              path: /
              port: 4200
            initialDelaySeconds: 15
            periodSeconds: 10
"@

    # ---------- Angular Service ----------
    Write-Utf8 "$K8S_DIR\angular-service.yaml" @"
apiVersion: v1
kind: Service
metadata:
  name: angular-hello-svc
  namespace: app-at2
  labels:
    app: angular-hello
spec:
  selector:
    app: angular-hello
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 4200
      name: http
"@

    Ok "Manifests Kubernetes crees dans $K8S_DIR"
}

# ─────────────────────────────────────────────────────────────
# BUILD MAVEN + TESTS SPRINGBOOT
# ─────────────────────────────────────────────────────────────
function Build-SpringBoot {
    Step "Build Maven + Tests Spring Boot"
    Push-Location $SB_DIR

    mvn clean verify
    if ($LASTEXITCODE -ne 0) {
        Err "Maven build/tests echoue"
        Pop-Location
        exit 1
    }
    Ok "Maven build + tests OK"
    Pop-Location
}

# ─────────────────────────────────────────────────────────────
# DOCKER BUILD + PUSH SPRINGBOOT
# ─────────────────────────────────────────────────────────────
function Push-SpringBoot-Image {
    Step "Build Docker + Push Spring Boot vers ECR"
    Push-Location $SB_DIR

    if (-not $ECR_REGISTRY) {
        $script:ECR_REGISTRY = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
    }

    $imageUri = "$ECR_REGISTRY/springboot-hello:latest"
    Info "Building image: $imageUri"
    
    docker build -t $imageUri .
    if ($LASTEXITCODE -ne 0) { Err "Docker build failed" ; Pop-Location ; exit 1 }
    Ok "Image construite : $imageUri"

    docker push $imageUri
    if ($LASTEXITCODE -ne 0) { Err "Docker push failed" ; Pop-Location ; exit 1 }
    Ok "Image pousse vers ECR"
    Pop-Location
}

# ─────────────────────────────────────────────────────────────
# FIND CHROME / EDGE
# ─────────────────────────────────────────────────────────────
function Find-ChromeBin {
    $candidates = @(
        $env:CHROME_BIN,
        "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
        "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
        "$env:LocalAppData\BraveSoftware\Brave-Browser\Application\brave.exe",
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LocalAppData\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return $p }
    }
    return $null
}

# ─────────────────────────────────────────────────────────────
# ANGULAR BUILD + TESTS + DOCKER (VERSION CORRIGEE)
# ─────────────────────────────────────────────────────────────
function Build-Angular {
    Step "Build Angular + Tests + Docker"
    
    if (-not (Test-Path $ANG_DIR)) {
        Err "Dossier Angular n'existe pas: $ANG_DIR"
        exit 1
    }

    Push-Location $ANG_DIR

    try {
        if (-not $ECR_REGISTRY) {
            $script:ECR_REGISTRY = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
        }
        Info "ECR Registry: $ECR_REGISTRY"

        Info "npm install"
        npm install
        if ($LASTEXITCODE -ne 0) { Err "npm install failed" ; throw }

        $chromeBin = Find-ChromeBin
        if (-not $chromeBin) {
            Err "Chrome/Edge introuvable"
            throw
        }
        $env:CHROME_BIN = $chromeBin
        Ok "Chrome detecte : $chromeBin"

        Step "Tests unitaires Angular"
        npm run test
        if ($LASTEXITCODE -ne 0) { Err "Tests Angular echoues" ; throw }
        Ok "Tests OK"

        Step "Build production Angular"
        npm run build
        if ($LASTEXITCODE -ne 0) { Err "Build Angular echoue" ; throw }
        Ok "Build OK"

        Step "Build + Push image Docker Angular vers ECR"
        $imageUri = "$ECR_REGISTRY/angular-hello:latest"
        Info "Building image: $imageUri"
        
        docker build -t $imageUri .
        if ($LASTEXITCODE -ne 0) { Err "Docker build failed" ; throw }
        Ok "Image Docker construite : $imageUri"

        docker push $imageUri
        if ($LASTEXITCODE -ne 0) { Err "Docker push failed" ; throw }
        Ok "Image pousse vers ECR"
    }
    finally {
        Pop-Location
    }
}

# ─────────────────────────────────────────────────────────────
# DEPLOY SUR EKS
# ─────────────────────────────────────────────────────────────
function Deploy-To-EKS {
    Step "Deploiement sur cluster EKS"

    # Update kubeconfig
    aws eks update-kubeconfig --region $AwsRegion --name $EksClusterName
    if ($LASTEXITCODE -ne 0) { Err "Failed to update kubeconfig" ; exit 1 }
    Ok "Kubeconfig mise a jour"

    # Determiner l'ECR URI si pas defini
    if (-not $ECR_REGISTRY) {
        $script:ECR_REGISTRY = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
    }

    Info "ECR Registry: $ECR_REGISTRY"

    # Create namespace
    kubectl apply -f "$K8S_DIR\namespace.yaml"
    Ok "Namespace app-at2 cree"

    # Update manifests with ECR URI - AUTOMATIQUE
    Info "Remplacement PLACEHOLDER par ECR URI..."
    
    $sbDeployment = Get-Content "$K8S_DIR\springboot-deployment.yaml" -Raw
    $sbDeployment = $sbDeployment -replace "PLACEHOLDER_ECR_URI", $ECR_REGISTRY
    Set-Content "$K8S_DIR\springboot-deployment.yaml" $sbDeployment
    
    $angDeployment = Get-Content "$K8S_DIR\angular-deployment.yaml" -Raw
    $angDeployment = $angDeployment -replace "PLACEHOLDER_ECR_URI", $ECR_REGISTRY
    Set-Content "$K8S_DIR\angular-deployment.yaml" $angDeployment

    # Deploy
    kubectl apply -f "$K8S_DIR\springboot-deployment.yaml"
    kubectl apply -f "$K8S_DIR\springboot-service.yaml"
    Ok "Spring Boot deploye"

    # Wait for rollout
    Info "Attente du deploiement Spring Boot (2 min max)..."
    kubectl rollout status deployment/springboot-hello -n app-at2 --timeout=120s
    Ok "Spring Boot pret"

    Step "Services Spring Boot"
    $sb_svc = kubectl get svc springboot-hello-svc -n app-at2 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
    if ($sb_svc) { Ok "Spring Boot : http://$sb_svc" }
    else { Warn "Spring Boot LoadBalancer pas encore pret (attendre 5-10 min pour DNS)" }
}

# ─────────────────────────────────────────────────────────────
# NETTOYAGE
# ─────────────────────────────────────────────────────────────
function Clean-All {
    Step "Nettoyage"
    kubectl delete namespace app-at2 --ignore-not-found 2>$null
    if (Test-Path "$SB_DIR\target") { Remove-Item -Recurse -Force "$SB_DIR\target" 2>$null }
    if (Test-Path "$ANG_DIR\dist")  { Remove-Item -Recurse -Force "$ANG_DIR\dist" 2>$null }
    if (Test-Path "$ANG_DIR\node_modules")  { Remove-Item -Recurse -Force "$ANG_DIR\node_modules" 2>$null }
    Ok "Nettoyage termine"
}

# ─────────────────────────────────────────────────────────────
# MAIN FLOW
# ─────────────────────────────────────────────────────────────
Write-Host @"
╔════════════════════════════════════════════════════════════╗
║   AT2 - Deploiement d'une application en continu           ║
║   EKS Cluster + ECR + CircleCI (VERSION Sans bugs)             ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

switch ($Action) {
    "all" {
        Check-Prerequisites
        Setup-ECR
        Setup-SpringBoot
        Setup-Angular
        Setup-K8sManifests
        Build-SpringBoot
        Push-SpringBoot-Image
        Build-Angular
        Deploy-To-EKS
        Step "🎉 PIPELINE COMPLET TERMINE 🎉"
        Warn "Les LoadBalancers peuvent prendre 5-10 min pour obtenir une adresse DNS"
    }
    "springboot" { Check-Prerequisites ; Setup-SpringBoot ; Setup-K8sManifests ; Build-SpringBoot ; Push-SpringBoot-Image }
    "angular"    { Check-Prerequisites ; Setup-Angular ; Setup-K8sManifests ; Build-Angular }
    "deploy"     { Check-Prerequisites ; Setup-ECR ; Deploy-To-EKS }
    "clean"      { Clean-All }
    default {
        Err "Action inconnue : $Action"
        Info "Usage : .\AT2DeploiementApps.ps1 [-Action all|springboot|angular|deploy|clean] [-AwsAccountId xxxxx]"
    }
}