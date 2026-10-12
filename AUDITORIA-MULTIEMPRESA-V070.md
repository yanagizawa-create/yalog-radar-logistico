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


## 7. Aplicação da regra oficial de licença na branch (11/10/2026)

A migração da branch foi atualizada para aplicar a mesma regra documentada nas funções oficiais `autenticar_ecosystem` e `revalidar_sessao_ecosystem` em quatro operações do Radar:

- Login direto: só emite sessão se existir licença da empresa com `status = 'ATIVA'` e `validade IS NULL OR validade >= current_date`.
- SSO: além da sessão Ecosystem ativa, do módulo correto, do usuário autorizado e do perfil ativo, verifica a licença com a mesma condição.
- Leitura e gravação operacional: repetem a verificação de licença em cada chamada, para que expiração/suspensão bloqueie operações mesmo se o usuário já tiver uma sessão do módulo.

### Bloqueio real detectado nos dados retornados

A consulta ao banco reportou 2 licenças com status `ATIVA`, mas a validade mínima e máxima para esse status é `2026-10-10`. Considerando a data atual `2026-10-11`, essas licenças já não satisfazem a condição existente `validade >= current_date`. Antes de testar login comercial após aplicação da migração no ambiente de QA, verificar/renovar a licença do tenant de QA com o responsável pelo negócio. **Não alterar as licenças via migração de código e não aplicar este SQL diretamente em produção.**

### Instalações: lacuna ainda aberta

A definição fornecida de `autenticar_ecosystem` grava `installation_id = NULL` ao criar a sessão. Por isso não está comprovado o vínculo da sessão SSO a uma instalação específica, mesmo existindo `company_installations`. A branch ainda não modifica o fluxo genérico de login do Ecossistema. É necessário diagnosticar as instalações e sessões reais e definir a integração apropriada antes de declarar atendido o requisito de instalação exclusiva.

### QA adicional requerido

- Licença ATIVA e válida: login direto, SSO, leitura e gravação permitidos.
- Licença SUSPENSA/EXPIRADA ou validade anterior à data atual: login, SSO, leitura e gravação recusados.
- Sessão SSO criada com `installation_id` nulo: comportamento explicitamente decidido, sem fingir vínculo por instalação.


## 8. Resultado do inventário de instalações e licenças (11/10/2026)

Consulta agregada retornada do Supabase:

- `YALOG-CORE`: licença `SUSPENSA`; nenhuma instalação ou sessão ativa.
- `YLG-AFD2BC` (Allas Soluções Logísticas): licença `ATIVA` sem data de validade; 13 instalações; zero sessões ativas no momento da consulta.
- `YLG-FF05B3` (Allas Balsas): licença `ATIVA` com validade `2026-10-10`, portanto expirada em `2026-10-11` pela regra do Ecossistema; nenhuma instalação ou sessão ativa.
- Nenhuma das linhas retornadas mostra sessões ativas, então não há uma sessão em execução que permita validar o percurso real do SSO neste instantâneo.
- Não foi identificado tenant `YLG-RADAR-QA` no resultado anterior de licenças/empresas. Os dados sintéticos de teste não devem ser criados em uma empresa operacional real.

### Interpretação cautelosa

As 13 instalações de Allas provam que existem registros em `company_installations`, mas a consulta não prova que alguma sessão ativa esteja vinculada a uma dessas instalações. A função `autenticar_ecosystem` fornecida insere `installation_id = NULL`; antes de definir um bloqueio estrito no SSO, deve-se confirmar se existe algum trigger no banco que preencha essa coluna ou outro fluxo de instalação em uso. Nenhum tenant nem licença foi alterado.


## 9. Consulta de gatilhos (11/10/2026)

Consulta a `pg_trigger` para gatilhos não internos em `ecosystem_sessions` e `company_installations` retornou **nenhuma linha**. Portanto, não existe trigger nessas tabelas para preencher `installation_id` ou sincronizar instalações automaticamente.

Combinado com o código apresentado de `autenticar_ecosystem`, que insere `installation_id = NULL`, o vínculo precisa ser resolvido explicitamente pelo fluxo de aplicação/RPC; não há automação existente a reaproveitar.

### Estratégia de correção antes de qualquer DDL de produção

Como `company_installations` e `module_sessions` são estruturas existentes e podem ser usadas por outros módulos, não alterar essas tabelas diretamente em produção. Proposta para revisão:

1. Gerar/guardar um UUID de instalação no cliente do Radar (identificador técnico, nunca fonte de autorização nem armazenamento operacional).
2. Criar uma RPC específica do Radar que valide a sessão já autenticada, registre/verifique o UUID contra o `company_id` no servidor, e impeça reaproveitar um UUID associado a outra empresa.
3. Persistir o vínculo `module_session_token → installation_id` em estrutura própria do Radar, evitando modificar o contrato genérico de `module_sessions` ou a autenticação do Ecossistema.
4. Validar o vínculo em cada operação do Radar e no logout, sem interferir em outros módulos.
5. Fazer primeiro backup/snapshot do esquema e dados necessários, aplicar em tenant de QA isolado, verificar login direto + SSO + refresh + isolamento; para rollback, desabilitar as RPCs novas e remover apenas a estrutura exclusiva criada pelo Radar, após exportar qualquer registro de QA necessário. Não apagar linhas de `company_installations` nem dados operacionais existentes.

**Impacto:** adiciona identificador por instalação e vínculo de sessão no escopo do Radar; não deve migrar dados operacionais nem modificar as funções genéricas do Ecossistema. A implantação permanece bloqueada até a criação/validação de um tenant de QA com licença válida.


## 10. Vínculo de instalação isolado implementado na branch

Foram preparadas, sem executar no Supabase, as alterações abaixo:

- Tabela exclusiva `public.radar_installation_sessions`, ligando token da sessão do módulo, empresa, UUID de instalação, data e estado de revogação. A tabela usa FKs para sessões, empresas e instalações existentes, tem RLS ativado e acesso direto revogado para `PUBLIC`, `anon` e `authenticated`.
- RPC `public.radar_vincular_instalacao(p_module_session_token, p_installation_id)`: deriva empresa/usuário da sessão validada; exige licença válida e vínculo ativo de módulo; registra/verifica UUID em `company_installations`; recusa UUID associado a outra empresa; devolve o UUID já associado se a mesma sessão já possuir vínculo.
- O frontend gera e guarda somente o UUID técnico de instalação, numa chave por empresa. Cargas e cadastros operacionais continuam exclusivamente no backend.
- A inicialização autenticada estabelece/revalida sessão e depois chama a RPC de vínculo antes de carregar os dados.
- As RPCs de leitura e gravação passam a exigir vínculo ativo de instalação. O logout revoga o vínculo da sessão do Radar além de revogar o token de módulo.

### Impacto e recuperação

O delta acrescenta uma tabela exclusiva e uma RPC; atualiza a migração e o frontend da branch. Não modifica `module_sessions`, `ecosystem_sessions`, a função genérica de autenticação, nem apaga/transforma cadastros operacionais. A nova tabela tem FK de exclusão em cascata com `module_sessions` e `empresas`, mas a limpeza deve ser feita apenas em QA quando necessário. Rollback de QA: exportar evidências, revogar/desativar o uso das RPCs do Radar e remover a tabela exclusiva após confirmar que não há sessões/QA a preservar; manter intactas as linhas preexistentes de `company_installations`.

### Limitações antes do release

- A migração ainda não foi aplicada nem validada por PostgreSQL no projeto Supabase.
- Não existe tenant `YLG-RADAR-QA` no inventário retornado; é necessário provisionar ambiente e licença válida por procedimento aprovado.
- A instalação agora será criada pelo Radar ao primeiro acesso e associada à empresa da sessão; não altera retroativamente as 13 instalações antigas da Allas.
- O teste estático de JavaScript não equivale a E2E. Não há prova de acesso cruzado, refresh, replay SSO ou persistência até a execução dos testes em ambiente isolado.


## 11. Proteção temporária do perfil TRANSPORTADORA

Foi adicionado um bloqueio no backend das RPCs genéricas de carregar/gravar payload completo para perfis `TRANSPORTADORA`, `CARRIER` e `USUARIO_TRANSPORTADORA`. Até existir o portal restrito com consulta filtrada e vínculo servidor→transportadora→carga, esses perfis não recebem o payload integral da embarcadora nem podem gravá-lo.

Esse é um bloqueio preventivo, não a entrega do portal de transportadora. A interface de demonstração baseada em `D.config.perfilDemo` continua sendo apenas uma demonstração visual e não concede autorização real. Nenhuma transportadora deve ser liberada para operação comercial até que os RPCs do portal restrito sejam implementados e testados.


## 12. Revisão estática após vínculo e proteção de transportadora

Após adicionar a RPC de instalação, o bloco JavaScript principal passou novamente pela compilação estática com `new Function`. A migração contém definições únicas para `radar_validar_handoff`, `radar_vincular_instalacao`, `radar_autenticar_usuario`, `radar_carregar_dados`, `radar_salvar_dados` e `radar_encerrar_sessao`; os delimitadores PL/pgSQL estão balanceados. Isso é uma verificação estática preliminar, não análise sintática completa de PostgreSQL nem execução no Supabase.

O módulo não deve ser mesclado até que a migração seja executada em QA, todos os RPCs sejam confirmados e os testes do checklist passem. Ainda estão pendentes gestão de usuários/permissões e portal de transportadora com dados filtrados no backend.


## 13. Modelo de identidade e perfis confirmado (11/10/2026)

Consulta ao esquema do Supabase mostrou:

- `usuarios` guarda a identidade central por empresa: `company_id`, `login`, `nome`, `senha_hash`, `role`, `ativo`, `email` e `obrigar_troca_senha`.
- `module_users` já é o vínculo por módulo: `company_id`, `modulo`, `login`, `perfil`, `ativo` e `created_by`. A gestão do Radar deve reutilizar esse vínculo para habilitar/desabilitar o módulo e definir o perfil Radar.
- `usuarios_operacionais` é uma estrutura diferente, com `origem`, `modulo`, `nivel`, `versao`, datas e credenciais próprias. Não deve ser adotada para o Radar sem confirmar seu contrato e sem provar que ela é o cadastro canônico para esse módulo.
- As três tabelas têm RLS habilitada. Isso, isoladamente, não comprova que as políticas estejam corretas; acesso via RPC `SECURITY DEFINER` precisa validar autorização explicitamente.
- Não apareceu tabela de transportadoras, vínculos usuário-transportadora ou matriz de permissões granulares no resultado enviado. Isso não prova inexistência absoluta de outros objetos, mas essas estruturas ainda não foram identificadas.
- O HTML atual armazena transportadoras/cargas/cotações dentro do payload JSONB da empresa. Enquanto a RPC retorna o payload inteiro, esconder menus ou filtrar itens em JavaScript não isola uma transportadora de outra.

### Consequência de arquitetura

1. Reusar `usuarios` para identidade e `module_users` para vínculo/perfil do Radar.
2. Não fazer CRUD direto nessas tabelas a partir do frontend; criar RPCs com autorização server-side e escopo estrito por empresa.
3. Antes de definir inserção/alteração, revisar chaves únicas e políticas RLS reais para `usuarios` e `module_users`.
4. Para permissões configuráveis e portal de transportadoras, primeiro separar as operações protegidas do payload único ou criar RPCs dedicadas e tabelas relacionais específicas para os vínculos. Não liberar o perfil `TRANSPORTADORA` pelo atual modelo de payload integral.


## 14. Constraints, RLS policies e funções de gestão existentes (11/10/2026)

O resultado recebido confirma:

- `usuarios(company_id, login)` tem `UNIQUE`; `module_users(company_id, modulo, login)` também tem `UNIQUE`. Assim, a identidade central e o vínculo por módulo podem ser reaproveitados sem nova tabela de usuários.
- `module_users` tem RLS ativada e não apareceu nenhuma policy para ela na consulta, o que tende a negar acesso direto via PostgREST para roles comuns; as RPCs `SECURITY DEFINER` ainda precisam validar empresa, MASTER e permissões explicitamente.
- `usuarios` tem policies para `anon` incluindo `ALL USING(true) WITH CHECK(true)`, além de policies específicas de SELECT/INSERT/UPDATE. `usuarios_operacionais` tem policies anon para SELECT/INSERT/UPDATE/DELETE com condições permissivas. Isso é um achado de alta prioridade: é necessário investigar grants efetivos e todos os consumidores antes de mudar essas policies, porque a correção pode afetar o Ecossistema e outros módulos. Esta branch do Radar não remove nem altera policies globais.
- O resultado mostrou funções CRUD e permissões do Pátio (`patio_usuarios_listar/criar/editar`, `patio_permissoes_obter/definir`, alterações de senha). Ainda não foram inspecionadas as definições dessas funções; não se presume que sirvam para o Radar sem validar verificações de token, papel MASTER, empresa, hash/senha, limites e auditoria.
- O agrupamento de perfis `module_users` para `radarlogistico` não retornou linhas. Isso indica que ainda não foi confirmado nenhum usuário vinculado a esse módulo no esquema consultado; autenticação V070 exige esse vínculo. Antes de testes, provisionar um usuário de QA autorizado pelo procedimento central, sem modificar usuários operacionais de produção.

### Próxima etapa controlada

Inspecionar as definições completas das funções CRUD/permissões do Pátio, o mapeamento atual de funções de senha e o volume de vínculos por módulo. A partir disso, decidir se há helper seguro reaproveitável ou se o Radar precisa de RPCs próprias. Não revogar policies globais automaticamente nesta sprint.


## 15. Revisão das funções de usuários e permissões do Pátio (12/10/2026)

Com base nas definições SQL recebidas:

- As RPCs de gestão do Pátio validam sessão via `validar_sessao_modulo(..., 'patio')`, operam no `company_id` da sessão e usam `SECURITY DEFINER` com `search_path='public'`. Esse padrão de escopo por sessão é adequado como referência, condicionado à revisão dos helpers e dos privilégios de execução.
- `patio_usuarios_criar` é exclusiva para sessão cujo perfil normalizado seja `MASTER`; ela cria a identidade em `usuarios` e um vínculo em `module_users` com `modulo='patio'`. Não deve ser chamada pelo Radar nem simplesmente duplicada sem ajustar a política de papéis: reutilizá-la concederia acesso ao Pátio, não ao Radar.
- `patio_usuarios_editar` atualiza tanto `usuarios.role/ativo` quanto `module_users.perfil/ativo` para Pátio. Como `usuarios` é identidade central, alterar `role` ou `ativo` por uma configuração de perfil exclusiva do Radar pode afetar outros módulos. O Radar deve distinguir estado global da identidade de acesso/perfil específico do módulo; qualquer desativação global requer ação explícita e regra central.
- `patio_usuarios_listar` lista apenas vínculos com `modulo='patio'`; não atende a tela do Radar sem alteração da lógica de módulo.
- `patio_permissoes_obter` tem uma lista fixa de 10 recursos do Pátio e consulta `patio_permissoes`; `patio_permissoes_definir` também valida sessão do Pátio, usa o recurso administrativo `usuarios`, valida níveis `SEM_ACESSO/VISUALIZAR/EXECUTAR` e grava nessa tabela. São específicas do Pátio e não devem ser usadas para autorizar Radar.
- As funções do Pátio demonstram uma abordagem possível para gestão server-side (sessão, escopo da empresa, papel administrativo, alvo dentro da mesma empresa, validação e upsert), mas ainda falta revisar `patio_verificar_acesso`, normalização de perfis, defaults e restrições/grants da tabela de permissões antes de aprovar o padrão como seguro.
- Não foi feita nenhuma alteração no banco e nenhuma policy global foi removida. O PR segue aberto; testes de banco e QA continuam pendentes.

### Decisão de implementação
Construir gestão de usuários Radar em RPCs próprias e limitadas ao módulo `radarlogistico`, usando `usuarios` apenas para a identidade central e `module_users` para perfil/ativação Radar. Separar de forma explícita: criar identidade global (somente quando não existe), conceder acesso Radar, editar perfil Radar, revogar acesso Radar e bloquear identidade global. A UI não deve receber nem poder alterar `senha_hash` por consultas genéricas. As permissões granulares do Radar precisam de recursos próprios e verificações server-side; os níveis do Pátio não autorizam automaticamente ações de carga, cotação, aprovação ou liberação.
