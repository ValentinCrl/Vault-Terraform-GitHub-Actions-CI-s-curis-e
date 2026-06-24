# Module Terraform — Harbor sur Hetzner Cloud

Provisionne un serveur Hetzner et y installe **Harbor** (registry OCI privé) avec
TLS **Let's Encrypt**, entièrement via cloud-init. La CI GitHub Actions pourra
ensuite **build → push → signer (cosign)** vers ce Harbor.

```
terraform apply ──► hcloud_server (Ubuntu 24.04)
                      ├─ firewall : 22 (toi), 80 + 443 (monde)
                      └─ cloud-init ─► Docker + certbot + Harbor (docker-compose)
                                        TLS Let's Encrypt (boucle de retry sur le DNS)
```

## Prérequis
- Un **token API Hetzner** (Console → Security → API Tokens, *Read & Write*).
- Une **clé SSH** (`~/.ssh/id_ed25519.pub`).
- Un **domaine** dont tu contrôles le DNS.

## Utilisation

```bash
cd terraform/harbor
cp terraform.tfvars.example terraform.tfvars   # puis remplis les valeurs

terraform init
terraform apply
```

1. Récupère l'IP affichée par la sortie `dns_record_to_create`.
2. **Crée l'enregistrement DNS A** `harbor.tondomaine → IP` chez ton registrar.
3. cloud-init réessaie l'émission du certificat toutes les 60 s : dès que le DNS
   résout, Harbor s'installe tout seul (5–10 min).
4. Suis l'avancement :
   ```bash
   ssh root@<IP>
   tail -f /var/log/harbor-bootstrap.log
   ```
5. Connecte-toi sur `https://harbor.tondomaine` (admin / mot de passe défini dans tfvars).

## Après l'installation (préparer la CI)
Dans l'UI Harbor :
1. Crée un **projet** (ex. `devsecops`).
2. Crée un **robot account** sur ce projet (push/pull) → récupère son nom et son token.
3. Mets ces valeurs dans les **secrets GitHub** `HARBOR_USERNAME` / `HARBOR_PASSWORD`
   (+ `HARBOR_HOST = harbor.tondomaine`) pour le job cosign de la CI.

## Détruire (pense à le faire en fin de projet — facturation à l'heure)
```bash
terraform destroy
```

## Notes
- `server_type = cpx21` (3 vCPU / 4 Go) suffit pour Harbor sans scanner interne.
  Passe à `cpx31` (8 Go) si tu actives Trivy dans Harbor.
- Le renouvellement Let's Encrypt est automatique (timer certbot + hooks
  d'arrêt/relance du proxy Harbor enregistrés à l'émission).
- State et `terraform.tfvars` sont gitignorés (secrets). Ne les committe jamais.
