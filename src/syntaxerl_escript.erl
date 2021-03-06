-module(syntaxerl_escript).
-author("Dmitry Klionsky <dm.klionsky@gmail.com>").

-behaviour(syntaxerl).

-export([
    check_syntax/2,
    output_error/1,
    output_warning/1
]).

-include("check_syntax_spec.hrl").

%% ===================================================================
%% API
%% ===================================================================

check_syntax(FileName, Debug) ->
    case file:read_file(FileName) of
        {ok, Content} ->
            %% replace shebang line with module definition.
            NewContent = re:replace(Content, <<"#.*">>, <<"-module(fixed_escript).">>),
            %% make a new file name.
            NewFileName = filename:rootname(FileName, ".erl") ++ "_fixed.erl",
            case file:write_file(NewFileName, NewContent) of
                ok ->
                    {InclDirs, DepsDirs, ErlcOpts} = syntaxerl_utils:incls_deps_opts(FileName),
                    syntaxerl_logger:debug(Debug, "Include dirs: ~p", [InclDirs]),
                    syntaxerl_logger:debug(Debug, "Deps dirs: ~p", [DepsDirs]),
                    syntaxerl_logger:debug(Debug, "Erlc opts: ~p", [ErlcOpts]),

                    code:add_paths(DepsDirs),

                    Result = compile:file(NewFileName, ErlcOpts ++ InclDirs),
                    syntaxerl_logger:debug(Debug, "Compile result: ~p", [Result]),

                    file:delete(NewFileName),

                    case Result of
                        {ok, _ModuleName} ->
                            {ok, []};
                        {ok, _ModuleName, Warnings} ->
                            {ok, syntaxerl_format:format_warnings(?MODULE, Warnings)};
                        {error, Errors, Warnings} ->
                            case syntaxerl_format:format_errors(?MODULE, Errors) of
                                [] ->
                                    {ok, syntaxerl_format:format_warnings(?MODULE, Warnings)};
                                Errors2 ->
                                    {error, Errors2 ++ syntaxerl_format:format_warnings(?MODULE, Warnings)}
                            end
                    end;
                {error, Reason} ->
                    {error, [{error, file:format_error(Reason)}]}
            end;
        {error, Reason} ->
            {error, [{error, file:format_error(Reason)}]}
    end.

output_error(_) -> true.

output_warning(_) -> true.
