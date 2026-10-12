# YALog Radar Logístico — Checklist de QA V070

**Objetivo:** autorizar testes funcionais antes de qualquer merge/publicação.  
**Branch:** `work-radar-sso-supabase-90d-tests`  
**Produção:** permanece inalterada enquanto este checklist não for concluído.

## Estado antes dos testes

- [x] Alterações concentradas na branch de trabalho; `main` não alterada.
- [x] Sintaxe JavaScript do bloco de script validada por compilação estática no momento da revisão.
- [x] Fluxo de logout incluído; tenta sincronizar alterações pendentes antes de encerrar a sessão.
- [x] SQL da persistência inclui RPCs de autenticação, leitura, gravação e encerramento de sessão.
- [x] Geração de dados sintéticos condicionada exclusivamente ao tenant `YLG-RADAR-QA`, quando a base estiver vazia.
- [x] SSO implementado na branch por RPC isolada `radar_validar_handoff`; token é removido da URL antes da chamada e a validação é feita no backend.
- [ ] Migração SQL aplicada e validada no projeto Supabase de QA.
- [ ] Tenant/usuário de QA com licença `ATIVA` e validade nula ou >= data corrente confirmados; a consulta atual reportou licenças ATIVAS com validade 2026-10-10, anterior à data 2026-10-11.
- [ ] Tenant e usuário de QA provisionados com licença válida, permissão para o módulo Radar e instalação isolada.
- [x] Contrato da RPC genérica `validar_handoff_modulo` revisado; implementação isolada `radar_validar_handoff` adicionada à migração da branch.
- [ ] Migração que cria `radar_validar_handoff` aplicada e validada no Supabase de QA.
- [x] Restauração automática de sessão por `sessionStorage` adicionada ao boot para F5/Ctrl+R; sessão sempre revalidada no backend.
- [x] V071: removido o seletor de perfil de demonstração do cabeçalho; a interface exibe o perfil retornado pela autenticação do servidor, sem permitir alternância manual de embarcadora/transportadora.
- [ ] Portal de transportadoras permanece bloqueado no backend até existir escopo de cargas validado por transportadora; não liberar usuários de transportadora com base apenas em filtro visual.
- [ ] Testes em navegador concluídos.

## Roteiro funcional — executar somente no tenant isolado de QA

1. **Login válido:** credenciais de QA autorizadas entram; empresa e perfil exibidos correspondem ao cadastro.
2. **Login inválido:** senha incorreta, usuário inativo, empresa inválida e licença suspensa/expirada são recusados sem carregar dados operacionais.
3. **Isolamento:** a sessão de uma empresa não lê nem altera a base de outra empresa.
4. **Leitura inicial:** o Radar carrega o payload compartilhado e a versão informada pelo servidor.
5. **Gravação:** criar/editar um registro de teste, aguardar confirmação do servidor e atualizar a página; o registro permanece.
6. **Concorrência:** duas sessões alteram dados; conflito de versão é informado sem sobrescrever silenciosamente a atualização mais recente.
7. **Refresh:** F5 e Ctrl+R devem revalidar o token de sessão, manter o acesso se estiver válido e recarregar a base do servidor; sessão expirada/revogada deve ser removida e exigir login.
8. **Falha de rede:** indisponibilidade não é apresentada como gravação concluída; alterações pendentes não devem ser descartadas silenciosamente.
9. **Logout:** alterações pendentes são sincronizadas antes do logout; a sessão remota é revogada quando o servidor responde; retorno à tela de login.
10. **Sessão/licença expirada ou revogada:** operações de leitura/gravação são bloqueadas; sessão inválida exige nova autenticação.
11. **SSO/handoff:** aplicar primeiro a migração no ambiente isolado; testar token válido do Radar, token de outro módulo, token expirado, token reutilizado, sessão do Ecossistema revogada e usuário sem liberação. Confirmar consumo único e que falhas retornam à tela de login.
12. **Responsividade:** testar desktop, tablet e celular; login, navegação, tabelas e botão Sair.
13. **Dados de QA:** conferir identificação `[RADAR-TESTE-90D]`; confirmar que nenhum registro sintético foi criado em tenant real.

## Critérios de aprovação

- Nenhuma perda de dados após refresh.
- Nenhum acesso cruzado entre empresas.
- Nenhuma autenticação concedida por token inválido, expirado ou reutilizado.
- Nenhuma confirmação visual de gravação antes da confirmação do servidor.
- Nenhuma alteração na branch de produção antes da aprovação dos testes.

## Limitações conhecidas

O teste estático de sintaxe não prova que as RPCs existem ou que a migração SQL foi aplicada. Não foi possível confirmar, apenas pelo código versionado disponível, a implementação no backend da função que valida/consome o handoff gerado pelo Ecossistema. O QA de navegador e a verificação no Supabase ainda são necessários.


**Instalação:** o contrato atual de `autenticar_ecosystem` insere `installation_id = NULL`. O vínculo da sessão com uma instalação específica precisa ser resolvido e testado antes de aprovar o requisito comercial de instalação individual.


## Identidade de instalação (branch V070; requer migração aplicada em QA)

14. Primeiro acesso: o Radar gera um UUID técnico por empresa no navegador e registra no servidor por `radar_vincular_instalacao`.
15. Repetição na mesma sessão: o servidor devolve o ID de instalação já associado, mesmo que a chave local tenha sido removida e recriada.
16. Tentativa de reutilizar UUID registrado por outra empresa: a RPC deve recusar sem associar a sessão.
17. Leitura e gravação sem linha ativa em `radar_installation_sessions`: devem falhar no backend.
18. Logout: o vínculo Radar da sessão fica revogado; as demais instalações da empresa permanecem intocadas.

**Nota:** os cenários acima são casos de teste a executar; não estão marcados como aprovados.


## Bloqueio preventivo de portal

19. Perfil real `TRANSPORTADORA` chama a RPC genérica `radar_carregar_dados`: deve receber recusa sem o payload integral da embarcadora.
20. Perfil real `TRANSPORTADORA` chama a RPC genérica `radar_salvar_dados`: deve receber recusa e não alterar nenhum dado.
21. A função visual `D.config.perfilDemo` não pode ser tratada como autorização. O portal comercial só será aprovado após RPCs com filtro por vínculo da transportadora no backend.
