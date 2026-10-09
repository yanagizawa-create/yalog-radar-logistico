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

REVOKE ALL ON FUNCTION public.radar_carregar_dados(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.radar_salvar_dados(text, bigint, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.radar_carregar_dados(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.radar_salvar_dados(text, bigint, jsonb) TO anon, authenticated;
