# Auditoria técnica — Evolução comercial do Radar Logístico

**Branch:** `work-radar-sso-supabase-90d-tests`  
**Escopo:** diagnóstico da versão atual e plano incremental para multiempresa, licenças, permissões e portal de transportadoras.  
**Produção:** não alterada. Este documento não aplica migrações nem muda dados.

## 1. Fontes verificadas

- HTML anexado nesta solicitação: título MVP V042; a persistência operacional usa `localStorage` via `loadData()`/`save()`; a troca embarcadora/transportadora é feita por `D.config.perfilDemo` no frontend. Não deve substituir diretamente a branch V070.
- Branch V070: adiciona login por empresa/usuário, sessão opaca guardada em `sessionStorage`, RPCs de carregar/salvar, tabela compartilhada `radar_logistico_store` por empresa e controle de versão otimista. A sintaxe JavaScript passou pela validação estática reportada no PR; isso não equivale a teste funcional de navegador.
- Supabase, conforme definições fornecidas no SQL Editor: existem `radar_autenticar_usuario`, `radar_carregar_dados`, `radar_salvar_dados`, `validar_sessao_modulo`, `validar_handoff_modulo` e `usuario_autorizado_modulo`.
- PR #1 permanece aberto; não foi mesclado nem publicado pela branch de trabalho.

## 2. Achados e lacunas frente à especificação

| Área | Estado observado | Ação necessária |
|---|---|---|
| Persistência multiempresa | `radar_logistico_store` guarda um payload JSONB por `company_id` e módulo. | Validar isolamento, leitura/gravação, concorrência, backup e recuperação no projeto Supabase real. |
| Login por empresa | RPC verifica usuário/empresa ativos, hash enviado e autorização do módulo; exige vínculo ativo em `module_users`. | Verificar implementação de `usuario_autorizado_modulo`, licenciamento/instalação e política de credenciais antes de aprovar para uso comercial. |
| Sessão e refresh | O token de sessão fica em `sessionStorage` e é revalidado pelo backend ao inicializar. | Testar F5/Ctrl+R, expiração, revogação, múltiplas abas e falhas de rede no navegador. |
| SSO/handoff | A função `validar_handoff_modulo(p_token)` existe no banco, mas a branch V070 ainda não a chama. | Revisar a função antes de chamá-la: na definição fornecida, o token é consultado como não utilizado e a sessão é criada antes da atualização de `used_at`; não há filtro explícito para `modulo='radarlogistico'` nem chamada explícita a `usuario_autorizado_modulo`. Confirmar regra de licença/instalação e evitar consumo concorrente/replay. |
| Permissões internas | O controle de menus ainda usa `D.config.perfilDemo`; isso é um modo de demonstração, não autorização de backend. | Substituir gradualmente pelo perfil retornado/autorizado pelo servidor e verificar permissão em cada operação privilegiada. |
| Usuários da embarcadora | A tela atual de configurações administra parâmetros operacionais e demonstração; não foi identificada tela CRUD integrada de usuários vinculada a permissões de backend. | Reaproveitar cadastros/funções existentes; não inventar uma segunda fonte de identidade. |
| Transportadoras e seus usuários | O modo transportadora filtra partes da interface via `D.config.perfilDemo`; o HTML não contém CRUD integrado de usuários de transportadora nem portal dedicado com escopo próprio. Os dados operacionais são carregados como payload completo da empresa. | Não considerar o filtro visual suficiente. Implementar API/RPC com vínculo transportadora–carga e escopo aplicado no servidor antes de expor o portal a clientes. |
| Licenças e instalações | O fluxo atual chama `usuario_autorizado_modulo`, mas a validação concreta de licença/instalação ainda não foi inspecionada. | Mapear a função e as tabelas atuais antes de adicionar regras ou estruturas. |
| Auditoria | Há dados/indicadores de auditoria no modelo operacional; não está demonstrado um log de backend imutável para eventos críticos. | Definir eventos e persistência server-side, respeitando permissões e retenção, após localizar estruturas existentes. |
| Dados e migração | A branch V070 não importa dados antigos do navegador automaticamente. | Manter essa proteção; qualquer migração precisa de inventário, backup, validação e plano de rollback. |

## 3. Sequência de implementação recomendada

### Fase A — Fechar diagnóstico do backend (bloqueadora)
1. Inspecionar as definições de `gerar_handoff_modulo` e `usuario_autorizado_modulo`.
2. Identificar colunas e vínculos já existentes para instalações, licenças, usuários de módulo, tokens e sessões.
3. Confirmar a representação da empresa, instalação, transportadora e perfil; evitar duplicidade de tabelas.

### Fase B — Corrigir autenticação e SSO
1. Corrigir/validar o consumo de handoff no backend para token de uso único, módulo correto, empresa/usuário autorizados e licença/instalação válidas.
2. Integrar a branch ao contrato real da RPC e bloquear fallbacks permissivos.
3. Testar login direto, SSO, token inválido, expirado, reutilizado e de outro módulo.

### Fase C — Modelo de autorização
1. Definir matriz de permissões por recurso e ação: consultar, incluir, editar, aprovar, liberar e excluir.
2. Aplicar autorização no backend/RPC, não somente na navegação.
3. Separar gestão YALog, MASTER embarcadora, perfis internos e usuários de transportadora.

### Fase D — Portal restrito da transportadora
1. Resolver o vínculo autenticado usuário → transportadora → cargas/cotações autorizadas no servidor.
2. Separar as operações necessárias do payload completo da embarcadora.
3. Testar tentativa de acesso cruzado alterando IDs, parâmetros e requisições.

### Fase E — Licença, usuários, auditoria e aceite
1. Integrar gestão comercial às tabelas e funções atuais de licenças/instalações.
2. Implantar telas de gestão somente sobre endpoints seguros já validados.
3. Executar testes com dois tenants de QA, backup/recuperação, refresh, concorrência, bloqueios, auditoria e regressão dos recursos atuais.
4. Somente depois aprovar merge/publicação.

## 4. Correções preparadas na branch após a auditoria

- Adicionada RPC específica `radar_validar_handoff(p_token)` na migração de persistência, sem substituir a RPC genérica do Ecossistema. A nova função exige token ainda válido e não consumido, módulo `radarlogistico`, sessão original do Ecossistema ativa, usuário autorizado e perfil ativo em `module_users`; bloqueia a linha do token durante o consumo para reduzir risco de replay concorrente.
- O frontend agora captura e remove o parâmetro `handoff` da URL, chama a RPC Radar e só abre o módulo se o backend devolver uma sessão para o módulo esperado.
- O boot agora tenta restaurar a sessão da aba após F5/Ctrl+R e revalida o token no backend. Se a validação falhar, remove a sessão local.
- A compilação estática do bloco JavaScript principal passou após as alterações. Isso não substitui teste em navegador/Supabase.
- `radar_carregar_dados` retorna o perfil ativo de `module_users`, em vez de depender do papel genérico de `usuarios`, na definição proposta na migração.

**Limite:** estas são alterações versionadas na branch. A migração ainda precisa ser aplicada e os fluxos verificados no projeto de QA; não houve teste E2E nem publicação.

## 5. Bloqueio atual / próxima evidência necessária

Antes de integrar o SSO ou acrescentar CRUDs, é necessário obter a definição real de `usuario_autorizado_modulo` e `gerar_handoff_modulo), além das colunas das tabelas de instalação/licença e dos tokens. Essa leitura é somente diagnóstica: não executar DDL nem alterar dados operacionais nesta etapa.

**Regra de release:** não mesclar nem publicar enquanto os testes de isolamento, autorização backend, persistência e regressão não estiverem aprovados.


## 6. Inventário do esquema confirmado no Supabase (11/10/2026)

A consulta de `information_schema.columns` retornou as estruturas abaixo:

- `company_installations`: `installation_id` UUID + `company_id`, datas de criação/atualização.
- `ecosystem_sessions`: sessão contém `company_id`, `login`, `installation_id` anulável, expiração e revogação.
- `licencas`: licença por `company_id` com `plano`, `status`, `validade`, limites de usuários e módulos.
- `module_access_tokens`: token liga `company_id`, `login`, `modulo` e `ecosystem_session_token`, expira em data/hora e tem `used_at`.
- `module_sessions`: guarda empresa/usuário/módulo, expiração e revogação, mas não guarda `installation_id`.
- `modulos` e `platform_modules`: o primeiro tem liberação por empresa; o segundo é o catálogo global do módulo.
- `module_users`: vínculo ativo de usuário ao módulo e perfil.

### Implicações

1. A nova RPC do Radar pode validar a instalação do SSO por meio da sessão original e de `company_installations`, mas precisa definir a política para sessões antigas onde `ecosystem_sessions.installation_id` é nulo.
2. A licença pode ser verificada por `licencas.company_id`, mas não é seguro inventar os estados válidos de `licencas.status`; devem ser lidos da lógica já usada pelo Ecossistema antes da implementação.
3. A validação de login direto do Radar ainda depende da regra de licenciamento/instalação a definir com base nas funções oficiais do Ecossistema. Não considerar o módulo comercialmente pronto até que essa validação seja aplicada também no login direto e nas operações relevantes.
4. `module_sessions` não contém `installation_id`; qualquer exigência de auditoria por instalação após o handoff deve ser tratada como evolução de esquema apenas se o diagnóstico provar que o vínculo indireto pela sessão não basta.

### Próxima inspeção de leitura

Obter as definições de `autenticar_ecosystem`, `revalidar_sessao_ecosystem` e `obter_modulos_ecosystem`, junto com a distribuição dos valores de `licencas.status`. Isso permitirá reaproveitar o contrato existente sem duplicar regras.
