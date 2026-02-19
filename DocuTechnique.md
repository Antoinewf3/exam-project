# Documentation - Solution DevOps - Rendu de l'ECF

**Exercices ECF AT1 + AT2 - Infrastructure Cloud et Déploiement Applications**

---

## 1. Vue d'ensemble

Ce projet démontre comment automatiser le déploiement complet d'applications dans le cloud AWS, en utilisant des outils modernes et des bonnes pratiques DevOps.

**Résultat final** :
-  Une infrastructure cloud automatisée sur AWS
-  Deux applications web (backend + frontend) déployées
-  Accès public via internet

---

## 2. AT1 - Créer l'Infrastructure Cloud

### Ce qui a été créé

**Infrastructure en cloud (AWS)** :
- Un **réseau virtuel** pour isoler les ressources
- Un **cluster Kubernetes** pour exécuter les applications
- Une **base de données serverless** (Lambda) avec une API web
- Un **dépôt d'images Docker** pour stocker les applications

### Pourquoi c'est important

Au lieu de créer les ressources manuellement (fastidieux et source d'erreurs), nous avons utilisé **Terraform** : un outil qui crée tout automatiquement en lisant un fichier de configuration.

**Avantages** :
- Reproductible : réexécuter le même code = même résultat
- Documenté : le code décrit ce qui existe
- Versionné : suivi des modifications
- Rapide : déploiement en moins de 30 minutes

### Fichier clé

**`main.tf`** : Décrit toute l'infrastructure en code

---

## 3. AT2 - Déployer les Applications

### Application 1 : Spring Boot (Backend)

**C'est quoi ?**
- Une API web écrite en Java
- Répond aux requêtes HTTP
- Trois endpoints :
  - `/api/` → affiche "Hello World"
  - `/api/health` → confirme que l'app fonctionne
  - `/api/info` → affiche des infos

**Processus** :
1. Écrire le code Java
2. Tester le code (JUnit)
3. Créer une image Docker
4. Pousser l'image vers AWS ECR (dépôt d'images)
5. Déployer sur Kubernetes

**Dossier** : `springboot-app/`

---

### Application 2 : Angular (Frontend)

**C'est quoi ?**
- Une page web affichée dans le navigateur
- Écrite en TypeScript/Angular
- Affiche des informations (version, environnement, statut)

**Processus** :
1. Écrire le code Angular
2. Tester le code
3. Compiler la page web
4. Créer une image Docker (serveur Nginx)
5. Pousser l'image vers AWS ECR
6. Déployer sur Kubernetes

**Dossier** : `angular-app/`

---

### Déploiement sur Kubernetes

**Kubernetes ?** Un orchestrateur : gère où et comment vos applications s'exécutent.

**Fichiers de configuration)** :
- Fichiers YAML qui décrivent comment lancer les apps
- Où les mettre
- Comment les exposer sur internet

**Dossier** : `k8s/`

---

## 4. Script de Déploiement - AT2DeploiementApps.ps1

### Qu'est-ce que c'est ?

Un script PowerShell qui automatise TOUT le processus :
- Vérifier que les outils sont installés
- Configurer l'accès à AWS
- Créer le code des deux apps
- Builder les images Docker
- Pousser vers AWS ECR
- Déployer sur Kubernetes

### Comment l'utiliser ?

```powershell
# Tout faire d'un coup
.\AT2DeploiementApps.ps1 -Action all

# Ou lancer 1 par 1 (dans ce cas nous utilisions une t3.micro et il n'était pas possible d'avoir les pods Springboot et
                     Angular en "Running" simultanément à cause de la limite "Free-Tier" de la dite t3.micro de AWS).
.\AT2DeploiementApps.ps1 -Action springboot
.\AT2DeploiementApps.ps1 -Action angular
.\AT2DeploiementApps.ps1 -Action deploy
```

### Avantage

Exécuter une seule commande au lieu de 20+ étapes manuelles = gain de temps et moins d'erreurs.

---

## 5. Technologies utilisées

### Backend (Spring Boot)
- **Langage** : Java
- **Framework** : Spring Boot
- **Build** : Maven
- **Container** : Docker

### Frontend (Angular)
- **Langage** : TypeScript
- **Framework** : Angular
- **Build** : npm
- **Serveur web** : Nginx
- **Container** : Docker

### Infrastructure
- **Cloud** : AWS
- **Kubernetes** : EKS
- **Dépôt d'images** : ECR
- **Infrastructure as Code** : Terraform

---

## 6. Résumé du Flux de Création

```
CODE (Java + Angular)
        ↓
    BUILD & TEST
        ↓
   CREATION IMAGE DOCKER
        ↓
   PUSH VERS AWS ECR
        ↓
   DEPLOIEMENTS VERS KUBERNETES
        ↓
   ACCESSIBLE DEPUIS INTERNET 
```

---

## 7. Fichiers/Documents produits/fournits

### Fichiers
-  Code source complet
-  Images Docker
-  Configuration Kubernetes
-  Infrastructure en code (Terraform)
-  Script de déploiement automatisé
-  Tests unitaires
-  Documentation

### Services AWS
-  Réseau virtuel
-  Cluster Kubernetes
-  Dépôt d'images
-  API Lambda
-  Accès internet

### Résultat final
-  Spring Boot accessible via internet
-  Angular accessible via internet
-  Tout automatisé et reproductible

---

## 8. Points Importants

 **Infrastructure as Code** : Tout en fichiers
 **Automatisation** : Un seul script pour déployer tout
 **Conteneurisation** : Apps packagées
 **Orchestration** : Kubernetes gère la disponibilité
 **Tests** : Chaque app a des tests
 **Scalabilité** : Facile d'ajouter plus d'apps

---

## 9. Combien de temps en moyenne cela nous prends :

- **15-20 min** : Créer l'infrastructure AWS
- **5-10 min** : Builder les images Docker
- **2-3 min** : Déployer sur Kubernetes
- **5-10 min** : Attendre les adresses internet

**Total : ~40 minutes**

---

## 10. Conclusion

Cette solution montre comment les équipes DevOps modernes déploient des applications :
- Vite
- Fiable
- Reproductible
- Entièrement automatisé

**Statut** :  Fonctionnel du côté apprenant 

---

**Documentation** : Février 2026
