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
- [x] O parâmetro `handoff` é removido da URL e a interface deixa explícito que a validação SSO ainda não está habilitada.
- [ ] Migração SQL aplicada e validada no projeto Supabase real.
- [ ] Tenant e usuário de QA provisionados com permissão para o módulo Radar.
- [ ] RPC de validação/consumo do handoff identificada e confirmada no backend.
- [ ] Testes em navegador concluídos.

## Roteiro funcional — executar somente no tenant isolado de QA

1. **Login válido:** credenciais de QA autorizadas entram; empresa e perfil exibidos correspondem ao cadastro.
2. **Login inválido:** senha incorreta, usuário inativo e empresa inválida são recusados sem carregar dados operacionais.
3. **Isolamento:** a sessão de uma empresa não lê nem altera a base de outra empresa.
4. **Leitura inicial:** o Radar carrega o payload compartilhado e a versão informada pelo servidor.
5. **Gravação:** criar/editar um registro de teste, aguardar confirmação do servidor e atualizar a página; o registro permanece.
6. **Concorrência:** duas sessões alteram dados; conflito de versão é informado sem sobrescrever silenciosamente a atualização mais recente.
7. **Refresh:** F5 e Ctrl+R preservam a sessão válida e recarregam a base do servidor.
8. **Falha de rede:** indisponibilidade não é apresentada como gravação concluída; alterações pendentes não devem ser descartadas silenciosamente.
9. **Logout:** alterações pendentes são sincronizadas antes do logout; a sessão remota é revogada quando o servidor responde; retorno à tela de login.
10. **Sessão expirada/revogada:** operações de leitura/gravação são bloqueadas e o usuário precisa autenticar novamente.
11. **SSO/handoff:** só aprovar após confirmar a RPC real de validação e consumo único do token. Até lá, validar que a interface informa a limitação e não simula login automático.
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
