-- YALog Radar Logístico — persistência compartilhada por empresa
-- Aplicar primeiro em ambiente de teste/revisão. Não lê nem migra localStorage.
-- A sessão opaca do módulo é validada no servidor em cada leitura/gravação.
-- Controle de versão otimista evita sobrescrita silenciosa entre usuários concorrentes.

CREATE TABLE IF NOT EXISTS public.radar_logistico_store (
    company_id text NOT NULL,
    module_id text NOT NULL DEFAULT 'radarlogistico'
        CHECK (module_id = 'radarlogistico'),
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    version bigint NOT NULL DEFAULT 0 CHECK (version >= 0),
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by text NOT NULL,
    PRIMARY KEY (company_id, module_id)
);

ALTER TABLE public.radar_logistico_store ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.radar_logistico_store FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.radar_autenticar_usuario(
    p_company_id text,
    p_login text,
    p_senha_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_user record;
    v_module_profile text;
    v_token text;
BEGIN
    IF NULLIF(trim(p_company_id), '') IS NULL
       OR NULLIF(trim(p_login), '') IS NULL
       OR NULLIF(p_senha_hash, '') IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Informe empresa, usuário e senha.');
    END IF;

    SELECT u.company_id, u.login, u.nome, u.senha_hash, u.ativo,
           e.ativo AS empresa_ativa
      INTO v_user
      FROM public.usuarios u
      JOIN public.empresas e ON e.company_id = u.company_id
     WHERE upper(u.company_id) = upper(trim(p_company_id))
       AND lower(u.login) = lower(trim(p_login))
     LIMIT 1;

    IF NOT FOUND OR NOT COALESCE(v_user.ativo, false)
       OR NOT COALESCE(v_user.empresa_ativa, false)
       OR v_user.senha_hash IS NULL
       OR v_user.senha_hash <> p_senha_hash THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Credenciais inválidas ou empresa inativa.');
    END IF;

    IF NOT public.usuario_autorizado_modulo(v_user.company_id, v_user.login, 'radarlogistico') THEN
        RETURN jsonb_build_object('ok', false, 'message', 'O Radar não está liberado para esta empresa ou usuário.');
    END IF;

    SELECT mu.perfil
      INTO v_module_profile
      FROM public.module_users mu
     WHERE mu.company_id = v_user.company_id
       AND mu.modulo = 'radarlogistico'
       AND lower(mu.login) = lower(v_user.login)
       AND mu.ativo = true
     LIMIT 1;

    IF v_module_profile IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'message', 'Usuário sem vínculo ativo com o Radar.');
    END IF;

    v_token := encode(gen_random_bytes(32), 'hex');

    INSERT INTO public.module_sessions
        (token, company_id, login, modulo, created_at, expires_at, last_seen_at, revoked_at)
    VALUES
        (v_token, v_user.company_id, v_user.login, 'radarlogistico',
         now(), now() + interval '12 hours', now(), NULL);

    RETURN jsonb_build_object(
        'ok', true,
        'company_id', v_user.company_id,
        'login', v_user.login,
        'nome', COALESCE(v_user.nome, v_user.login),
        'perfil', v_module_profile,
        'modulo', 'radarlogistico',
        'module_session_token', v_token
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.radar_carregar_dados(p_module_session_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_sess record;
    v_payload jsonb;
    v_version bigint;
BEGIN
    SELECT *
      INTO v_sess
      FROM public.validar_sessao_modulo(p_token := p_module_session_token,
                                        p_modulo := 'radarlogistico')
      LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sessão do Radar inválida, expirada ou sem autorização'
            USING ERRCODE = '28000';
    END IF;

    SELECT s.payload, s.version
      INTO v_payload, v_version
      FROM public.radar_logistico_store s
     WHERE s.company_id = v_sess.company_id
       AND s.module_id = 'radarlogistico';

    RETURN jsonb_build_object(
        'ok', true,
        'company_id', v_sess.company_id,
        'login', v_sess.login,
        'nome', v_sess.nome,
        'perfil', v_sess.perfil,
        'version', COALESCE(v_version, 0),
        'payload', COALESCE(v_payload, '{}'::jsonb)
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.radar_salvar_dados(
    p_module_session_token text,
    p_expected_version bigint,
    p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_sess record;
    v_new_version bigint;
BEGIN
    SELECT *
      INTO v_sess
      FROM public.validar_sessao_modulo(p_token := p_module_session_token,
                                        p_modulo := 'radarlogistico')
      LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sessão do Radar inválida, expirada ou sem autorização'
            USING ERRCODE = '28000';
    END IF;

    IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
        RAISE EXCEPTION 'Payload do Radar deve ser um objeto JSON'
            USING ERRCODE = '22023';
    END IF;

    IF p_expected_version IS NULL OR p_expected_version < 0 THEN
        RAISE EXCEPTION 'Versão esperada inválida'
            USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM public.radar_logistico_store s
         WHERE s.company_id = v_sess.company_id
           AND s.module_id = 'radarlogistico'
    ) AND p_expected_version <> 0 THEN
        RETURN jsonb_build_object(
            'ok', false,
            'conflict', true,
            'expected_version', p_expected_version,
            'message', 'A base ainda não existe no servidor. Recarregue os dados antes de gravar.'
        );
    END IF;

    INSERT INTO public.radar_logistico_store
        (company_id, module_id, payload, version, updated_at, updated_by)
    VALUES
        (v_sess.company_id, 'radarlogistico', p_payload, 1, now(), v_sess.login)
    ON CONFLICT (company_id, module_id)
    DO UPDATE SET
        payload = EXCLUDED.payload,
        version = public.radar_logistico_store.version + 1,
        updated_at = now(),
        updated_by = v_sess.login
    WHERE public.radar_logistico_store.version = p_expected_version
    RETURNING version INTO v_new_version;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'ok', false,
            'conflict', true,
            'expected_version', p_expected_version,
            'message', 'Os dados foram alterados por outro usuário. Recarregue antes de gravar novamente.'
        );
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'version', v_new_version,
        'updated_at', now(),
        'updated_by', v_sess.login
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.radar_encerrar_sessao(p_module_session_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_count integer;
BEGIN
    IF NULLIF(p_module_session_token, '') IS NULL THEN
        RETURN jsonb_build_object('ok', true);
    END IF;

    UPDATE public.module_sessions
       SET revoked_at = now()
     WHERE token = p_module_session_token
       AND modulo = 'radarlogistico'
       AND revoked_at IS NULL;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN jsonb_build_object('ok', true, 'revoked', v_count > 0);
END;
$function$;

REVOKE ALL ON FUNCTION public.radar_autenticar_usuario(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.radar_carregar_dados(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.radar_salvar_dados(text, bigint, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.radar_autenticar_usuario(text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.radar_encerrar_sessao(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.radar_carregar_dados(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.radar_salvar_dados(text, bigint, jsonb) TO anon, authenticated;
