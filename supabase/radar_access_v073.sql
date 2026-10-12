-- YALog Radar Logístico V073
-- Gestão de usuários vinculados a transportadoras.
-- IMPORTANTE: este SQL cria identidades e vínculos. O portal operacional de
-- TRANSPORTADORA permanece bloqueado no HTML até existir filtro de dados
-- server-side para radar_carregar_dados/radar_salvar_dados.
-- Execute no Supabase SQL Editor após revisar em ambiente de teste.

begin;

create table if not exists public.radar_transportadora_vinculos (
  company_id text not null,
  login text not null,
  transportadora_id text not null,
  created_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint radar_transportadora_vinculos_pk primary key (company_id, login)
);

create index if not exists radar_transportadora_vinculos_carrier_idx
  on public.radar_transportadora_vinculos(company_id, transportadora_id);

alter table public.radar_transportadora_vinculos enable row level security;
revoke all on public.radar_transportadora_vinculos from anon, authenticated;

create or replace function public.radar_listar_usuarios_transportadora(
  p_module_session_token text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao record;
  v_usuarios jsonb;
begin
  select * into v_sessao
    from public.validar_sessao_modulo(
      p_token => p_module_session_token,
      p_modulo => 'radarlogistico'
    )
   limit 1;

  if not found or v_sessao.company_id is null then
    raise exception 'SESSAO_INVALIDA_OU_EXPIRADA' using errcode = '28000';
  end if;

  if upper(coalesce(v_sessao.perfil,'')) not in ('MASTER','LIDERANCA','ADMIN_EMPRESA') then
    raise exception 'PERMISSAO_NEGADA_GESTAO_TRANSPORTADORAS' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'login', u.login,
      'nome', u.nome,
      'ativo', u.ativo,
      'transportadora_id', v.transportadora_id
    ) order by u.nome, u.login), '[]'::jsonb)
    into v_usuarios
    from public.radar_transportadora_vinculos v
    join public.usuarios u
      on u.company_id = v.company_id
     and lower(u.login) = lower(v.login)
    join public.module_users mu
      on mu.company_id = v.company_id
     and lower(mu.login) = lower(v.login)
     and mu.modulo = 'radarlogistico'
     and mu.ativo = true
     and upper(mu.perfil) = 'TRANSPORTADORA'
   where v.company_id = v_sessao.company_id;

  return jsonb_build_object('ok', true, 'usuarios', v_usuarios);
end;
$$;

create or replace function public.radar_gerenciar_usuario_transportadora(
  p_module_session_token text,
  p_action text,
  p_login text,
  p_nome text,
  p_senha_hash text,
  p_transportadora_id text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sessao record;
  v_action text := upper(trim(coalesce(p_action,'')));
  v_login text := lower(trim(coalesce(p_login,'')));
  v_nome text := trim(coalesce(p_nome,''));
  v_carrier text := trim(coalesce(p_transportadora_id,''));
  v_exists boolean;
begin
  select * into v_sessao
    from public.validar_sessao_modulo(
      p_token => p_module_session_token,
      p_modulo => 'radarlogistico'
    )
   limit 1;

  if not found or v_sessao.company_id is null then
    raise exception 'SESSAO_INVALIDA_OU_EXPIRADA' using errcode = '28000';
  end if;

  if upper(coalesce(v_sessao.perfil,'')) not in ('MASTER','LIDERANCA','ADMIN_EMPRESA') then
    raise exception 'PERMISSAO_NEGADA_GESTAO_TRANSPORTADORAS' using errcode = '42501';
  end if;

  if v_login = '' then
    raise exception 'LOGIN_OBRIGATORIO' using errcode = '22023';
  end if;

  if v_action not in ('CRIAR','ATUALIZAR','INATIVAR') then
    raise exception 'ACAO_INVALIDA' using errcode = '22023';
  end if;

  select exists(
    select 1 from public.usuarios
     where company_id = v_sessao.company_id
       and lower(login) = v_login
  ) into v_exists;

  if v_action = 'INATIVAR' then
    if not v_exists then
      raise exception 'USUARIO_NAO_ENCONTRADO' using errcode = 'P0002';
    end if;

    update public.usuarios
       set ativo = false
     where company_id = v_sessao.company_id
       and lower(login) = v_login;

    update public.module_users
       set ativo = false
     where company_id = v_sessao.company_id
       and lower(login) = v_login
       and modulo = 'radarlogistico';

    update public.radar_transportadora_vinculos
       set updated_at = now()
     where company_id = v_sessao.company_id
       and lower(login) = v_login;

    return jsonb_build_object('ok', true, 'message', 'Usuário inativado.');
  end if;

  if v_nome = '' or v_carrier = '' then
    raise exception 'NOME_E_TRANSPORTADORA_OBRIGATORIOS' using errcode = '22023';
  end if;

  if v_action = 'CRIAR' and (p_senha_hash is null or length(p_senha_hash) <> 64) then
    raise exception 'HASH_SENHA_INVALIDO' using errcode = '22023';
  end if;

  if p_senha_hash is not null and length(p_senha_hash) <> 64 then
    raise exception 'HASH_SENHA_INVALIDO' using errcode = '22023';
  end if;

  if v_action = 'CRIAR' and v_exists then
    raise exception 'LOGIN_JA_EXISTE_NA_EMPRESA' using errcode = '23505';
  end if;

  if v_action = 'ATUALIZAR' and not v_exists then
    raise exception 'USUARIO_NAO_ENCONTRADO' using errcode = 'P0002';
  end if;

  if v_action = 'CRIAR' then
    insert into public.usuarios(company_id, login, nome, senha_hash, role, ativo)
    values (v_sessao.company_id, v_login, v_nome, p_senha_hash, 'TRANSPORTADORA', true);
  else
    update public.usuarios
       set nome = v_nome,
           role = 'TRANSPORTADORA',
           senha_hash = coalesce(p_senha_hash, senha_hash),
           ativo = true
     where company_id = v_sessao.company_id
       and lower(login) = v_login;
  end if;

  if exists (
    select 1 from public.module_users
     where company_id = v_sessao.company_id
       and lower(login) = v_login
       and modulo = 'radarlogistico'
  ) then
    update public.module_users
       set perfil = 'TRANSPORTADORA', ativo = true
     where company_id = v_sessao.company_id
       and lower(login) = v_login
       and modulo = 'radarlogistico';
  else
    insert into public.module_users(company_id, modulo, login, perfil, ativo)
    values (v_sessao.company_id, 'radarlogistico', v_login, 'TRANSPORTADORA', true);
  end if;

  insert into public.radar_transportadora_vinculos(
    company_id, login, transportadora_id, created_by, created_at, updated_at
  ) values (
    v_sessao.company_id, v_login, v_carrier, v_sessao.login, now(), now()
  )
  on conflict (company_id, login) do update
    set transportadora_id = excluded.transportadora_id,
        updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'login', v_login,
    'transportadora_id', v_carrier,
    'message', 'Usuário e vínculo salvos.'
  );
end;
$$;

revoke all on function public.radar_listar_usuarios_transportadora(text) from public;
revoke all on function public.radar_gerenciar_usuario_transportadora(text,text,text,text,text,text) from public;
grant execute on function public.radar_listar_usuarios_transportadora(text) to anon, authenticated;
grant execute on function public.radar_gerenciar_usuario_transportadora(text,text,text,text,text,text) to anon, authenticated;

commit;

-- Pós-migração:
-- 1) valide cadastro/listagem/inativação de usuários em empresa de teste;
-- 2) teste que usuários sem perfil autorizado recebem PERMISSAO_NEGADA;
-- 3) mantenha o bloqueio do portal transportadora no HTML até implementar
--    leitura/gravação server-side com filtro por transportadora_id.