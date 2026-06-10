# EngajaCRM

CRM da **Engaja Comunicação**, construído sobre o [EspoCRM](https://www.espocrm.com) (AGPLv3) com a identidade visual da empresa:

- Tema **Engaja** (padrão de fábrica): interface escura — preto `#121212`/`#1E1E1F`, amarelo `#F3BA17`, dourado `#CFB22A` nos gráficos;
- Fonte **Mulish** embutida;
- Logo oficial da Engaja no login e na barra de navegação;
- Nome **EngajaCRM** em título, instalação e e-mails;
- Idioma `pt_BR`, moeda `BRL` e fuso `America/Fortaleza` como padrões do deploy.

Imagem Docker pronta (multi-arquitetura AMD64/ARM64):
**[`danielmonteirodc/engajacrm`](https://hub.docker.com/r/danielmonteirodc/engajacrm)** — tags `:9.3.8` e `:latest`.

---

## Deploy em produção (Ubuntu + Docker)

### Requisitos

- Servidor Linux com [Docker e Docker Compose](https://docs.docker.com/engine/install/ubuntu/) instalados;
- Domínio apontando para o servidor (ex.: `crm.engajacomunicacao.com.br`);
- HTTPS via proxy reverso ou CDN na frente do serviço (Nginx, Traefik, Cloudflare etc.).

### Passo a passo

1. Crie a pasta do deploy e copie [`docker-compose.yml`](docker-compose.yml) e [`.env.example`](.env.example) deste repositório:

   ```bash
   mkdir -p ~/engajacrm-docker && cd ~/engajacrm-docker
   # copie os dois arquivos para esta pasta
   cp .env.example .env
   ```

2. Edite o `.env`:

   ```bash
   nano .env
   ```

   - Defina **senhas fortes** em `MARIADB_ROOT_PASSWORD`, `MARIADB_PASSWORD` e `ESPOCRM_ADMIN_PASSWORD`;
   - Ajuste `ESPOCRM_SITE_URL` para o domínio definitivo (ex.: `https://crm.engajacomunicacao.com.br`);
   - Ajuste `WEBSOCKET_URL` para o mesmo domínio (ex.: `wss://crm.engajacomunicacao.com.br/wss`).

3. Suba o stack:

   ```bash
   docker compose up -d
   ```

   Sobem 4 serviços: `engajacrm-db` (MariaDB), `engajacrm` (aplicação, porta 80), `engajacrm-daemon` (jobs/cron) e `engajacrm-websocket` (tempo real, porta 8080).

4. A instalação é **automática** (banco, admin e configurações vêm do `.env`). Acompanhe com:

   ```bash
   docker compose logs -f engajacrm
   ```

5. Acesse o domínio e entre com `ESPOCRM_ADMIN_USERNAME` / `ESPOCRM_ADMIN_PASSWORD`. O tema Engaja e o nome EngajaCRM já estão aplicados.

### Proxy reverso / HTTPS

Encaminhe no proxy:

- `https://SEU_DOMINIO` → `http://servidor:80`;
- `wss://SEU_DOMINIO/wss` → `http://servidor:8080` (websocket).

### Backup

Os dados vivem em dois volumes Docker: `engajacrm-db` (banco) e `engajacrm-data` (uploads, config, customizações). Faça backup de ambos, por exemplo:

```bash
docker run --rm -v engajacrm-docker_engajacrm-db:/data -v $(pwd):/backup alpine \
  tar czf /backup/engajacrm-db-$(date +%F).tar.gz -C /data .
```

### Atualização

```bash
docker compose pull && docker compose up -d
```

---

## Build da imagem (manutenção do fork)

O build compila o fork completo (composer + npm + grunt) e sobrepõe o resultado na imagem oficial `espocrm/espocrm`, herdando o entrypoint de instalação automática, daemon e websocket.

```bash
# builder multi-arch (uma vez por máquina)
docker buildx create --name engaja-multiarch --driver docker-container

# build + push (AMD64 + ARM64)
docker buildx build --builder engaja-multiarch \
  --platform linux/amd64,linux/arm64 \
  -t danielmonteirodc/engajacrm:9.3.8 \
  -t danielmonteirodc/engajacrm:latest \
  --push .
```

Observações:

- Em máquinas com pouca RAM na VM do Docker (< 4GB), rode primeiro cada plataforma sem `--push` para popular o cache, depois o comando completo;
- O `.npmrc` com `ignore-scripts=true` é criado no build para evitar o `phantomjs-prebuilt` (dependência de testes sem binário ARM64).

## Customização do tema

O tema vive em [`frontend/less/engaja/`](frontend/less/engaja/):

- [`variables.less`](frontend/less/engaja/variables.less) — cores e variáveis (a paleta da Engaja está no topo);
- [`custom.less`](frontend/less/engaja/custom.less) — regras extras e fonte Mulish;
- [`Engaja.json`](application/Espo/Resources/metadata/themes/Engaja.json) — logo, cores de gráficos e calendário.

Após alterar, reconstrua e publique a imagem (seção anterior) e rode `docker compose pull && docker compose up -d` no servidor.

## Atualizando a partir do EspoCRM upstream

A branch `engaja-stable` é baseada na **tag estável** do EspoCRM (atualmente `9.3.8`) com os commits de customização por cima. Para acompanhar uma nova release:

```bash
git remote add upstream https://github.com/espocrm/espocrm.git  # uma vez
git fetch upstream --tags
git checkout -b engaja-NOVA_VERSAO NOVA_VERSAO
git cherry-pick <commits de customização da engaja-stable>
```

Atualize também a tag base no [`Dockerfile`](Dockerfile) (`FROM espocrm/espocrm:NOVA_VERSAO`), reconstrua e publique.

## Licença

Este projeto é um fork do [EspoCRM](https://github.com/espocrm/espocrm), licenciado sob [GNU AGPLv3](LICENSE.txt). Em conformidade com a Seção 7(b) da licença, a interface mantém o crédito "powered by EspoCRM" no rodapé. O código-fonte deste fork permanece disponível sob a mesma licença.
