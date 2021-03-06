-module(rebar_i18n_plugin).

-define(DEBUG(Msg, Args), ?LOG(debug, Msg, Args)).
-define(WARN(Msg, Args), ?LOG(warn, Msg, Args)).
-define(LOG(Lvl, Msg, Args), rebar_log:log(Lvl, Msg, Args)).
-define(ABORT(Msg, Args), rebar_utils:abort(Msg, Args)).

%% standard rebar hooks
-export([preprocess/2]).

%%
%% Plugin API
%%

preprocess(_Config, _AppFile) ->
    Cwd = rebar_utils:get_cwd(),
    %% Cwd is "/home/user/erlang/xapian/deps/proper" or 
    %%        "/home/user/erlang/xapian".
    CwdList = filename:split(Cwd),
    case lists:last(CwdList) of
        "i18n" ->
            set_vars();
        _OtherApp ->
            ok
    end,
    {ok, []}.



%%
%% Internal Functions
%%

set_vars() ->
    case os:getenv("I18N_REBAR") of
    false ->
        ?DEBUG("Set env vars i18n\n", []),
		os:putenv("I18N_REBAR", "true"),

        export_env("CC", "icu-config --cc"),
        export_env("CXX", "icu-config --cxx"),
        export_env("ICU_CFLAGS", "icu-config --cflags"),
        export_env("ICU_CXXFLAGS", "icu-config --cxxflags"),
        export_env("ICU_LDFLAGS", "icu-config --ldflags"),
        export_env("ICU_INC_PATH", "icu-config --cppflags-searchpath",
            fun(X) -> 
                X ++ " -idirafter c_src/include " 
            end),

        case os:getenv("I18N_BUILD_ID") of
        false ->
            {Mega, Secs, _} = os:timestamp(),
            Timestamp = Mega*1000000 + Secs,
            os:putenv("I18N_BUILD_ID", [$.|integer_to_list(Timestamp)]);
        _ -> ok
        end,

        case os:getenv("I18N_REBAR_COVER") of
        "true" ->
            ?DEBUG("Enable coverage for i18n\n", []),
            append_env(" --coverage ", "ICU_CXXFLAGS", ""),
            append_env(" --coverage ", "ICU_CFLAGS", ""),
            append_env(" -lgcov ", "ICU_LDFLAGS", "");
        _ ->
            ?DEBUG("Disable coverage for i18n\n", []),
            ok
        end;
    
    _ -> 
        ?DEBUG("Env vars for i18n already seted.\n", [])
    end,
        
    ok.


export_env(Name, Cmd) ->
    FormatFn = fun(X) -> X end,
    export_env(Name, Cmd, FormatFn).
    

export_env(Name, Cmd, FormatFn) ->
	case os:getenv(Name) of
	false ->
		{0, Value} = eunit_lib:command(Cmd),
		os:putenv(Name, FormatFn(remove_new_string(Value))),
		ok;
	_ -> ok
	end.

append_env(Prefix, Name, Suffix) ->
	case os:getenv(Name) of
	Value when (Value =/= false) -> 
		os:putenv(Name, Prefix ++ Value ++ Suffix),
        true
	end.


remove_new_string(Str) ->
    [C||C <- Str, C =/= $\n].
